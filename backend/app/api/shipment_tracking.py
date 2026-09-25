"""Recorded shipments, customer tracking, and opt-in courier automation."""
import asyncio
import logging
import uuid
from datetime import datetime, timedelta
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Response
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import async_session_factory, get_db
from app.dependencies import get_current_user, require_role
from app.integrations.delhivery_shipping import BookingUncertain, CourierUnavailable, DelhiveryShipping
from app.integrations.shipping_policy import configured_providers, select_quote
from app.models.customer_commerce import OrderContact, OrderEvent
from app.models.order import FulfillmentStatus, Order, OrderItem, OrderStatus, PaymentStatus
from app.models.product import Product
from app.models.shipping import Shipment, ShipmentEvent
from app.models.user import User, UserRole
from app.repositories import vendor_repo
from app.services.commerce_admin_service import audit

router = APIRouter(tags=["shipping"])
logger = logging.getLogger(__name__)
seller_only = require_role(UserRole.admin, UserRole.super_admin, UserRole.vendor)


def shipment_data(shipment: Shipment | None) -> dict:
    if not shipment:
        return {"status": "NOT_PREPARED", "mode": None, "carrier": None, "awb": None}
    return {
        "status": shipment.status.upper(), "mode": shipment.mode,
        "carrier": shipment.courier_name, "courier_code": shipment.courier_code, "awb": shipment.awb,
        "quoted_cost": str(shipment.quoted_cost) if shipment.quoted_cost is not None else None,
        "customer_fee": str(shipment.customer_fee), "last_error": shipment.last_error,
        "package": shipment.package,
        "label_available": bool(shipment.awb and shipment.courier_code == "delhivery"),
    }


async def lines_for(db: AsyncSession, order_id: uuid.UUID) -> list[OrderItem]:
    return list((await db.execute(select(OrderItem).where(OrderItem.order_id == order_id))).scalars())


async def cancellation_request_pending(db: AsyncSession, order_id: uuid.UUID) -> bool:
    latest = (await db.execute(select(OrderEvent.status).where(
        OrderEvent.order_id == order_id,
        OrderEvent.status.in_({'CANCEL_REQUESTED', 'CANCEL_REJECTED', 'REFUNDED'}),
    ).order_by(OrderEvent.created_at.desc(), OrderEvent.id.desc()).limit(1))).scalar_one_or_none()
    return latest == 'CANCEL_REQUESTED'


async def require_seller_access(db: AsyncSession, user: User, order_id: uuid.UUID, lines: list[OrderItem] | None = None) -> None:
    if user.role != UserRole.vendor:
        return
    vendor = await vendor_repo.get_by_user_id(db, user.id)
    items = lines if lines is not None else await lines_for(db, order_id)
    if not vendor or not vendor.is_active or not items or any(item.vendor_id != vendor.id for item in items):
        raise HTTPException(404, "Order not found")


def require_shippable(order: Order, lines: list[OrderItem]) -> None:
    cod_ready = order.is_cod and order.status == OrderStatus.confirmed and order.payment_status == PaymentStatus.pending
    if order.is_prelaunch_interest or (order.payment_status != PaymentStatus.paid and not cod_ready) or order.status == OrderStatus.cancelled:
        raise HTTPException(409, "A paid online or confirmed COD order is required before shipping")
    if not lines or len({line.vendor_id for line in lines}) != 1:
        raise HTTPException(409, "This booking flow supports one seller and one parcel per order")
    if any(line.fulfillment_status != FulfillmentStatus.packed for line in lines):
        raise HTTPException(409, "All items must be packed before courier booking")


async def prepare_shipment(db: AsyncSession, order: Order, lines: list[OrderItem], package: dict | None = None) -> Shipment:
    require_shippable(order, lines)
    if await cancellation_request_pending(db, order.id):
        raise HTTPException(409, "Resolve the cancellation request before booking a courier")
    shipment = (await db.execute(select(Shipment).where(Shipment.order_id == order.id).with_for_update())).scalar_one_or_none()
    retry_safe = shipment and shipment.status == "needs_attention" and shipment.courier_code is None
    if shipment and shipment.status not in {"needs_package", "ready"} and not retry_safe:
        raise HTTPException(409, "Shipment is already booked or requires reconciliation")
    if package is None:
        products = {p.id: p for p in (await db.execute(select(Product).where(Product.id.in_([i.product_id for i in lines])))).scalars()}
        known = all(i.product_id in products and products[i.product_id].weight_grams for i in lines)
        package = {
            "weight_grams": sum(products[i.product_id].weight_grams * i.quantity for i in lines) + settings.SHIPPING_PACKAGING_TARE_GRAMS if known else 0,
            "length_cm": settings.SHIPPING_PACKAGE_LENGTH_CM,
            "width_cm": settings.SHIPPING_PACKAGE_WIDTH_CM,
            "height_cm": settings.SHIPPING_PACKAGE_HEIGHT_CM,
            "quantity": sum(i.quantity for i in lines),
        }
    ready = all(isinstance(package.get(k), int) and package[k] > 0 for k in ("weight_grams", "length_cm", "width_cm", "height_cm"))
    if not shipment:
        shipment = Shipment(order_id=order.id, mode="auto", customer_fee=order.delivery_fee)
        db.add(shipment)
    shipment.package = package
    shipment.weight_grams = package.get("weight_grams")
    shipment.status = "ready" if ready else "needs_package"
    shipment.last_error = None if ready else "Enter measured package weight and dimensions"
    shipment.ready_at = datetime.utcnow() if ready else None
    await db.flush()
    return shipment


async def record_manual_dispatch(db: AsyncSession, order: Order, carrier: str, awb: str) -> Shipment:
    shipment = (await db.execute(select(Shipment).where(Shipment.order_id == order.id).with_for_update())).scalar_one_or_none()
    if shipment and shipment.status in {"booked", "in_transit", "out_for_delivery"} and shipment.courier_name == carrier and shipment.awb == awb:
        return shipment
    manual_safe = shipment and shipment.status == "needs_attention" and shipment.courier_code is None
    if shipment and shipment.status not in {"ready", "needs_package", "manual_pending", "manual_shipped"} and not manual_safe:
        raise HTTPException(409, "An automatic booking exists or needs courier reconciliation")
    if shipment and shipment.status == "manual_shipped" and (shipment.courier_name != carrier or shipment.awb != awb):
        raise HTTPException(409, "This order already has a different shipment")
    if not shipment:
        shipment = Shipment(order_id=order.id, customer_fee=order.delivery_fee)
        db.add(shipment)
    shipment.mode, shipment.status = "manual", "manual_shipped"
    shipment.courier_name, shipment.awb = carrier, awb
    shipment.last_error = None
    shipment.booked_at = shipment.booked_at or datetime.utcnow()
    await db.flush()
    return shipment


async def record_manual_milestone(db: AsyncSession, order_id: uuid.UUID, status: str, location: str, remarks: str) -> None:
    """Keep the customer-facing shipment in step with seller-entered milestones."""
    if status not in {"DISPATCHED", "SHIPPED", "OUT_FOR_DELIVERY", "DELIVERED"}:
        return
    shipment = (await db.execute(select(Shipment).where(Shipment.order_id == order_id).with_for_update())).scalar_one_or_none()
    if not shipment or not shipment.awb:
        raise HTTPException(409, "Record a real courier and tracking reference first")
    state = "delivered" if status == "DELIVERED" else "out_for_delivery" if status == "OUT_FOR_DELIVERY" else "manual_shipped" if shipment.mode == "manual" else "in_transit"
    shipment.status = state
    now = datetime.utcnow()
    if state == "delivered":
        shipment.delivered_at = now
    elif state == "out_for_delivery":
        shipment.picked_up_at = shipment.picked_up_at or now
    external_key = f"manual:{status}"
    existing = await db.scalar(select(ShipmentEvent.id).where(
        ShipmentEvent.shipment_id == shipment.id, ShipmentEvent.external_key == external_key))
    if existing is None:
        db.add(ShipmentEvent(
            shipment_id=shipment.id, external_key=external_key, status=status,
            description=remarks or status.replace("_", " ").title(),
            location=location, occurred_at=now,
        ))
    await db.flush()


async def stop_shipment_for_refund(db: AsyncSession, order: Order, *, returned: bool = False) -> None:
    """Prevent a paid order from being refunded while a courier may book it."""
    shipment = (await db.execute(select(Shipment).where(Shipment.order_id == order.id).with_for_update())).scalar_one_or_none()
    if not shipment:
        return
    if shipment.status == "booking" or (shipment.status == "needs_attention" and shipment.courier_code):
        raise HTTPException(409, "Resolve the uncertain courier booking before refunding this order")
    in_flight = {"booked", "in_transit", "out_for_delivery", "manual_shipped", "delivered"}
    if not returned and shipment.status in in_flight:
        raise HTTPException(409, "Resolve the dispatched parcel or process a return before refunding")
    shipment.status = "returned" if returned else "cancelled"
    shipment.claimed_at = None
    await db.flush()


class PackageInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    weight_grams: int = Field(gt=0, le=100000)
    length_cm: int = Field(gt=0, le=200)
    width_cm: int = Field(gt=0, le=200)
    height_cm: int = Field(gt=0, le=200)


@router.post("/marketplace/orders/{order_id}/shipping/prepare")
async def prepare(order_id: uuid.UUID, package: PackageInput, user: User = Depends(seller_only), db: AsyncSession = Depends(get_db)):
    order = (await db.execute(select(Order).where(Order.id == order_id).with_for_update())).scalar_one_or_none()
    if not order:
        raise HTTPException(404, "Order not found")
    lines = await lines_for(db, order.id)
    await require_seller_access(db, user, order_id, lines)
    shipment = await prepare_shipment(db, order, lines, package.model_dump() | {"quantity": sum(line.quantity for line in lines)})
    return {"success": True, "data": shipment_data(shipment)}


@router.get("/marketplace/orders/{order_id}/tracking")
async def tracking(order_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    order = await db.get(Order, order_id)
    if not order or (user.id != order.user_id and user.role not in {UserRole.admin, UserRole.super_admin}):
        raise HTTPException(404, "Order not found")
    shipment = (await db.execute(select(Shipment).where(Shipment.order_id == order_id))).scalar_one_or_none()
    events = []
    if shipment:
        rows = (await db.execute(select(ShipmentEvent).where(ShipmentEvent.shipment_id == shipment.id).order_by(ShipmentEvent.occurred_at))).scalars()
        events = [{"status": row.status, "description": row.description, "location": row.location,
                   "occurred_at": row.occurred_at.isoformat() + "Z"} for row in rows]
    return {"success": True, "data": {"order_id": str(order_id), **shipment_data(shipment), "checkpoints": events}}


async def confirm_booking(db: AsyncSession, shipment: Shipment, awb: str, courier_code: str = "delhivery", courier_name: str = "Delhivery") -> None:
    shipment.awb, shipment.status = awb, "booked"
    shipment.booked_at, shipment.claimed_at, shipment.last_error = datetime.utcnow(), None, None
    shipment.courier_code, shipment.courier_name = courier_code, courier_name
    contact = await db.get(OrderContact, shipment.order_id)
    if not contact:
        contact = OrderContact(order_id=shipment.order_id)
        db.add(contact)
    contact.carrier, contact.tracking_number = courier_name, awb
    db.add(OrderEvent(order_id=shipment.order_id, title="Courier booked", status="BOOKED", remarks=f"{courier_name} AWB {awb}"))
    await db.flush()


@router.post("/marketplace/orders/{order_id}/shipping/reconcile")
async def reconcile(order_id: uuid.UUID, user: User = Depends(seller_only), db: AsyncSession = Depends(get_db)):
    await require_seller_access(db, user, order_id)
    shipment = (await db.execute(select(Shipment).where(Shipment.order_id == order_id).with_for_update())).scalar_one_or_none()
    if not shipment:
        raise HTTPException(404, "Shipment not found")
    if shipment.awb:
        return {"success": True, "data": shipment_data(shipment)}
    if shipment.status != "needs_attention":
        raise HTTPException(409, "No uncertain booking to reconcile")
    if shipment.courier_code is None:
        raise HTTPException(409, "No courier booking was attempted; dispatch manually or correct package and coverage")
    if shipment.courier_code not in {None, "delhivery"}:
        raise HTTPException(409, "Reconcile this carrier in its portal")
    try:
        awb = await DelhiveryShipping().find_existing(str(order_id))
    except (BookingUncertain, CourierUnavailable) as exc:
        raise HTTPException(503, str(exc)) from exc
    if awb:
        await confirm_booking(db, shipment, awb)
    else:
        shipment.status = "needs_attention"
        shipment.last_error = "No matching AWB found. Verify the courier portal before another booking."
    return {"success": True, "data": shipment_data(shipment)}


class ResolutionInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    action: Literal["attach_awb", "no_booking"]
    awb: str = Field(default="", max_length=100)
    note: str = Field(min_length=8, max_length=500)


@router.post("/marketplace/orders/{order_id}/shipping/resolve")
async def resolve_uncertain_booking(order_id: uuid.UUID, data: ResolutionInput,
    user: User = Depends(seller_only), db: AsyncSession = Depends(get_db)):
    """Seller records evidence from the courier portal before manual recovery."""
    await require_seller_access(db, user, order_id)
    shipment = (await db.execute(select(Shipment).where(Shipment.order_id == order_id).with_for_update())).scalar_one_or_none()
    if not shipment or shipment.status != "needs_attention" or not shipment.courier_code or shipment.awb:
        raise HTTPException(409, "There is no unresolved courier booking")
    if data.action == "attach_awb":
        awb = data.awb.strip()
        if not awb:
            raise HTTPException(422, "Enter the AWB shown in the courier portal")
        await confirm_booking(db, shipment, awb, shipment.courier_code, shipment.courier_name or shipment.courier_code)
    else:
        shipment.status, shipment.mode = "manual_pending", "manual"
        shipment.courier_code = shipment.courier_name = None
        shipment.quoted_cost = shipment.claimed_at = None
        shipment.last_error = None
    audit(db, user, "shipment.booking_resolved", "order", order_id, data.model_dump_json())
    db.add(OrderEvent(order_id=order_id, title="Courier booking reviewed", status="REVIEWED", remarks="Shipment details updated by the seller"))
    return {"success": True, "data": shipment_data(shipment)}


@router.get("/marketplace/orders/{order_id}/shipping/label")
async def courier_label(order_id: uuid.UUID, user: User = Depends(seller_only), db: AsyncSession = Depends(get_db)):
    await require_seller_access(db, user, order_id)
    shipment = (await db.execute(select(Shipment).where(Shipment.order_id == order_id))).scalar_one_or_none()
    if not shipment or not shipment.awb or shipment.courier_code != "delhivery":
        raise HTTPException(404, "No courier-issued label is available")
    try:
        content = await DelhiveryShipping().label_pdf(shipment.awb)
    except Exception as exc:
        logger.warning("Courier label unavailable for %s: %s", order_id, exc)
        raise HTTPException(502, "Courier label is unavailable; check the courier portal") from exc
    return Response(content, media_type="application/pdf", headers={"Content-Disposition": f'attachment; filename="{shipment.awb}.pdf"'})


async def process_ready_once(courier: DelhiveryShipping | None = None) -> bool:
    """Claim once; an unknown outcome requires reconciliation instead of retry."""
    if not settings.SHIPPING_AUTO_BOOK_ENABLED or settings.PRELAUNCH_MODE:
        return False
    providers = [courier] if courier is not None else configured_providers()
    if not providers:
        return False
    async with async_session_factory() as db:
        shipment = (await db.execute(select(Shipment).where(Shipment.status == "ready")
                    .order_by(Shipment.ready_at).with_for_update(skip_locked=True).limit(1))).scalar_one_or_none()
        if not shipment:
            return False
        order = await db.get(Order, shipment.order_id)
        try:
            require_shippable(order, await lines_for(db, shipment.order_id))
            if await cancellation_request_pending(db, order.id):
                raise HTTPException(409, "Cancellation review is pending")
        except (HTTPException, AttributeError):
            shipment.status, shipment.last_error = "needs_attention", "Order is no longer eligible for booking"
            await db.commit()
            return True
        shipment.status, shipment.claimed_at = "booking", datetime.utcnow()
        shipment.attempts += 1
        shipment_id = shipment.id
        await db.commit()
    try:
        async with async_session_factory() as db:
            shipment = await db.get(Shipment, shipment_id)
            order = await db.get(Order, shipment.order_id)
            lines = await lines_for(db, shipment.order_id)
            contact = await db.get(OrderContact, shipment.order_id)
            package = shipment.package
        if not order or not contact or not package:
            raise CourierUnavailable("Order package or payment method is missing")
        options = []
        for provider in providers:
            try:
                offer = await provider.quote(str(order.address_snapshot.get("postal_code") or ""), package["weight_grams"], order.is_cod)
                if offer:
                    options.append((provider, offer))
            except Exception:
                logger.exception("Courier quote failed for %s", provider.code)
        selected = select_quote(options)
        if not selected:
            raise CourierUnavailable("No courier rate and serviceability quote available for this pincode")
        courier, quote = selected
        async with async_session_factory() as db:
            shipment = (await db.execute(select(Shipment).where(Shipment.id == shipment_id).with_for_update())).scalar_one()
            shipment.courier_code, shipment.courier_name, shipment.quoted_cost = courier.code, courier.name, quote.cost
            await db.commit()
        async with async_session_factory() as db:
            # Hold the order and shipment locks until the courier result is
            # recorded. Refunds and manual recovery cannot overtake booking.
            locked_order = (await db.execute(select(Order).where(Order.id == order.id).with_for_update())).scalar_one()
            shipment = (await db.execute(select(Shipment).where(Shipment.id == shipment_id).with_for_update())).scalar_one()
            if shipment.status != "booking" or shipment.courier_code != courier.code:
                raise BookingUncertain("Shipment state changed during courier booking")
            require_shippable(locked_order, await lines_for(db, locked_order.id))
            if await cancellation_request_pending(db, locked_order.id):
                raise HTTPException(409, "Cancellation review is pending")
            awb = await courier.book(locked_order, locked_order.address_snapshot,
                                     [line.title for line in lines], package, contact.payment_method)
            await confirm_booking(db, shipment, awb, courier.code, courier.name)
            await db.commit()
        try:
            await courier.request_pickup(1)
        except Exception as exc:
            logger.exception("Courier booked but pickup request failed for %s", shipment_id)
            async with async_session_factory() as db:
                booked = await db.get(Shipment, shipment_id)
                if booked:
                    booked.last_error = "Courier booked; arrange or verify pickup in the courier portal"
                    await db.commit()
        return True
    except Exception as exc:
        logger.warning("Shipping booking needs attention for %s: %s", shipment_id, exc)
        async with async_session_factory() as db:
            shipment = (await db.execute(select(Shipment).where(Shipment.id == shipment_id).with_for_update())).scalar_one_or_none()
            if shipment and shipment.status == "booking":
                shipment.status, shipment.last_error = "needs_attention", str(exc)[:500]
                await db.commit()
        return True


async def poll_tracking_once(courier: DelhiveryShipping | None = None) -> bool:
    if not settings.SHIPPING_AUTO_BOOK_ENABLED or settings.PRELAUNCH_MODE:
        return False
    courier = courier or DelhiveryShipping()
    if not courier.configured:
        return False
    cutoff = datetime.utcnow() - timedelta(minutes=20)
    async with async_session_factory() as db:
        shipment = (await db.execute(select(Shipment).where(
            Shipment.courier_code == "delhivery", Shipment.awb.is_not(None),
            Shipment.status.in_(["booked", "in_transit", "out_for_delivery"]),
            (Shipment.last_tracking_at.is_(None) | (Shipment.last_tracking_at < cutoff)),
        ).order_by(Shipment.last_tracking_at).with_for_update(skip_locked=True).limit(1))).scalar_one_or_none()
        if not shipment:
            return False
        shipment.last_tracking_at = datetime.utcnow()
        shipment_id, awb, order_id = shipment.id, shipment.awb, shipment.order_id
        await db.commit()
    try:
        scans = await courier.track(awb)
    except Exception:
        logger.exception("Courier tracking failed for %s", shipment_id)
        return True
    async with async_session_factory() as db:
        # Acquire locks in consistent global order: Order -> Shipment (prevents deadlocks with admin refunds/returns)
        order = (await db.execute(select(Order).where(Order.id == order_id).with_for_update())).scalar_one_or_none()
        shipment = (await db.execute(select(Shipment).where(Shipment.id == shipment_id).with_for_update())).scalar_one_or_none()
        if not shipment or not order:
            return True
        # Do not advance shipments or orders that were cancelled or returned while tracking was in-flight
        if (order.status == OrderStatus.cancelled or order.return_status in {"RETURN_COMPLETED", "RTO_DELIVERED"}
                or order.payment_status == PaymentStatus.refunded or shipment.status in {"cancelled", "returned", "rto"}):
            return True
        for scan in scans:
            key = str(scan.get("key") or "")[:200]
            if not key or (await db.execute(select(ShipmentEvent.id).where(ShipmentEvent.shipment_id == shipment_id, ShipmentEvent.external_key == key))).first():
                continue
            raw = str(scan.get("status") or "").strip().lower()
            state = "DELIVERED" if raw == "delivered" else "OUT_FOR_DELIVERY" if raw == "out for delivery" else "IN_TRANSIT" if raw in {"in transit", "in-transit", "pickup complete", "picked up"} else "UPDATE"
            try:
                occurred = datetime.fromisoformat(str(scan["occurred_at"]).replace("Z", "+00:00")).replace(tzinfo=None)
            except (ValueError, KeyError):
                continue
            db.add(ShipmentEvent(shipment_id=shipment_id, external_key=key, status=state,
                                 description=str(scan.get("description") or "")[:500],
                                 location=str(scan.get("location") or "")[:200], occurred_at=occurred))
            if state == "DELIVERED" and shipment.status != "delivered":
                shipment.status, shipment.delivered_at = "delivered", occurred
                await advance_order(db, order, FulfillmentStatus.delivered)
            elif state == "OUT_FOR_DELIVERY" and shipment.status not in {"out_for_delivery", "delivered"}:
                shipment.status = "out_for_delivery"
                await advance_order(db, order, FulfillmentStatus.shipped)
            elif state == "IN_TRANSIT" and shipment.status == "booked":
                shipment.status, shipment.picked_up_at = "in_transit", occurred
                await advance_order(db, order, FulfillmentStatus.shipped)
        await db.commit()
    return True


async def advance_order(db: AsyncSession, order_or_id: uuid.UUID | Order, target: FulfillmentStatus) -> None:
    if isinstance(order_or_id, Order):
        order = order_or_id
    else:
        order = (await db.execute(select(Order).where(Order.id == order_or_id).with_for_update())).scalar_one_or_none()
    if not order or order.status == OrderStatus.cancelled or order.return_status in {"RETURN_COMPLETED", "RTO_DELIVERED"} or order.payment_status == PaymentStatus.refunded:
        return
    if order.is_prelaunch_interest or (order.payment_status != PaymentStatus.paid and not (order.is_cod and order.status == OrderStatus.confirmed and order.payment_status == PaymentStatus.pending)):
        return
    for line in await lines_for(db, order.id):
        if line.fulfillment_status == FulfillmentStatus.cancelled:
            continue
        if target == FulfillmentStatus.shipped and line.fulfillment_status == FulfillmentStatus.packed:
            line.fulfillment_status = target
        elif target == FulfillmentStatus.delivered and line.fulfillment_status in {FulfillmentStatus.packed, FulfillmentStatus.shipped}:
            line.fulfillment_status = target
    db.add(OrderEvent(order_id=order.id, title="Courier update", status=target.value, remarks="Confirmed by courier tracking"))


async def shipping_loop() -> None:
    while True:
        try:
            await flag_stale_bookings()
            await process_ready_once()
            await poll_tracking_once()
        except Exception:
            logger.exception("Shipping worker iteration failed")
        await asyncio.sleep(30)


async def flag_stale_bookings() -> None:
    cutoff = datetime.utcnow() - timedelta(minutes=10)
    async with async_session_factory() as db:
        rows = (await db.execute(select(Shipment).where(Shipment.status == "booking", Shipment.claimed_at < cutoff)
                 .with_for_update(skip_locked=True))).scalars()
        for shipment in rows:
            shipment.status = "needs_attention"
            shipment.last_error = "Booking process stopped before AWB confirmation; reconcile in courier portal"
        await db.commit()
