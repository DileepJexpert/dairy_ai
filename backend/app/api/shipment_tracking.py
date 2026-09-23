"""Recorded shipments, customer tracking, and opt-in courier automation."""
import asyncio
import logging
import uuid
from datetime import datetime, timedelta
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import async_session_factory, get_db
from app.dependencies import get_current_user, require_role
from app.integrations.delhivery_shipping import BookingUncertain, CourierUnavailable, DelhiveryShipping
from app.models.customer_commerce import OrderContact, OrderEvent
from app.models.order import FulfillmentStatus, Order, OrderItem, OrderStatus, PaymentStatus
from app.models.product import Product
from app.models.shipping import Shipment, ShipmentEvent
from app.models.user import User, UserRole

router = APIRouter(tags=["shipping"])
logger = logging.getLogger(__name__)
admin_only = require_role(UserRole.admin, UserRole.super_admin)


def shipment_data(shipment: Shipment | None) -> dict:
    if not shipment:
        return {"status": "NOT_PREPARED", "mode": None, "carrier": None, "awb": None}
    return {
        "status": shipment.status.upper(), "mode": shipment.mode,
        "carrier": shipment.courier_name, "awb": shipment.awb,
        "quoted_cost": str(shipment.quoted_cost) if shipment.quoted_cost is not None else None,
        "customer_fee": str(shipment.customer_fee), "last_error": shipment.last_error,
        "label_available": bool(shipment.awb and shipment.courier_code == "delhivery"),
    }


async def lines_for(db: AsyncSession, order_id: uuid.UUID) -> list[OrderItem]:
    return list((await db.execute(select(OrderItem).where(OrderItem.order_id == order_id))).scalars())


def require_shippable(order: Order, lines: list[OrderItem]) -> None:
    if order.is_prelaunch_interest or order.payment_status != PaymentStatus.paid or order.status == OrderStatus.cancelled:
        raise HTTPException(409, "A paid commercial order is required before shipping")
    if not lines or len({line.vendor_id for line in lines}) != 1:
        raise HTTPException(409, "This booking flow supports one seller and one parcel per order")
    if any(line.fulfillment_status != FulfillmentStatus.packed for line in lines):
        raise HTTPException(409, "All items must be packed before courier booking")


async def prepare_shipment(db: AsyncSession, order: Order, lines: list[OrderItem], package: dict | None = None) -> Shipment:
    require_shippable(order, lines)
    shipment = (await db.execute(select(Shipment).where(Shipment.order_id == order.id).with_for_update())).scalar_one_or_none()
    if shipment and shipment.status not in {"needs_package", "ready"}:
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
    if shipment and shipment.status not in {"ready", "needs_package", "manual_shipped"}:
        raise HTTPException(409, "An automatic booking exists or needs courier reconciliation")
    if shipment and shipment.status == "manual_shipped" and (shipment.courier_name != carrier or shipment.awb != awb):
        raise HTTPException(409, "This order already has a different shipment")
    if not shipment:
        shipment = Shipment(order_id=order.id, customer_fee=order.delivery_fee)
        db.add(shipment)
    shipment.mode, shipment.status = "manual", "manual_shipped"
    shipment.courier_name, shipment.awb = carrier, awb
    shipment.booked_at = shipment.booked_at or datetime.utcnow()
    await db.flush()
    return shipment


class PackageInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    weight_grams: int = Field(gt=0, le=100000)
    length_cm: int = Field(gt=0, le=200)
    width_cm: int = Field(gt=0, le=200)
    height_cm: int = Field(gt=0, le=200)


@router.post("/marketplace/orders/{order_id}/shipping/prepare")
async def prepare(order_id: uuid.UUID, package: PackageInput, user: User = Depends(admin_only), db: AsyncSession = Depends(get_db)):
    order = (await db.execute(select(Order).where(Order.id == order_id).with_for_update())).scalar_one_or_none()
    if not order:
        raise HTTPException(404, "Order not found")
    shipment = await prepare_shipment(db, order, await lines_for(db, order.id), package.model_dump() | {"quantity": 1})
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


async def confirm_booking(db: AsyncSession, shipment: Shipment, awb: str) -> None:
    shipment.awb, shipment.status = awb, "booked"
    shipment.booked_at, shipment.claimed_at, shipment.last_error = datetime.utcnow(), None, None
    shipment.courier_code, shipment.courier_name = "delhivery", "Delhivery"
    contact = await db.get(OrderContact, shipment.order_id)
    if not contact:
        contact = OrderContact(order_id=shipment.order_id)
        db.add(contact)
    contact.carrier, contact.tracking_number = "Delhivery", awb
    db.add(OrderEvent(order_id=shipment.order_id, title="Courier booked", status="BOOKED", remarks=f"Delhivery AWB {awb}"))
    await db.flush()


@router.post("/marketplace/orders/{order_id}/shipping/reconcile")
async def reconcile(order_id: uuid.UUID, user: User = Depends(admin_only), db: AsyncSession = Depends(get_db)):
    shipment = (await db.execute(select(Shipment).where(Shipment.order_id == order_id).with_for_update())).scalar_one_or_none()
    if not shipment:
        raise HTTPException(404, "Shipment not found")
    if shipment.awb:
        return {"success": True, "data": shipment_data(shipment)}
    if shipment.status not in {"booking", "needs_attention"}:
        raise HTTPException(409, "No uncertain booking to reconcile")
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


async def process_ready_once(courier: DelhiveryShipping | None = None) -> bool:
    """Claim once; an unknown outcome requires reconciliation instead of retry."""
    if not settings.SHIPPING_AUTO_BOOK_ENABLED or settings.PRELAUNCH_MODE:
        return False
    courier = courier or DelhiveryShipping()
    if not courier.configured:
        return False
    async with async_session_factory() as db:
        shipment = (await db.execute(select(Shipment).where(Shipment.status == "ready")
                    .order_by(Shipment.ready_at).with_for_update(skip_locked=True).limit(1))).scalar_one_or_none()
        if not shipment:
            return False
        order = await db.get(Order, shipment.order_id)
        try:
            require_shippable(order, await lines_for(db, shipment.order_id))
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
        quote = await courier.quote(str(order.address_snapshot.get("postal_code") or ""), package["weight_grams"], False)
        if not quote:
            raise CourierUnavailable("No courier rate and serviceability quote available for this pincode")
        if settings.SHIPPING_MAX_COURIER_COST > 0 and quote.cost > Decimal(str(settings.SHIPPING_MAX_COURIER_COST)):
            raise CourierUnavailable("Courier price exceeds the configured maximum")
        awb = await courier.book(order, order.address_snapshot, [line.title for line in lines], package, contact.payment_method)
        async with async_session_factory() as db:
            shipment = (await db.execute(select(Shipment).where(Shipment.id == shipment_id).with_for_update())).scalar_one()
            if shipment.status != "booking":
                raise BookingUncertain("Shipment state changed during courier booking")
            shipment.quoted_cost = quote.cost
            await confirm_booking(db, shipment, awb)
            await db.commit()
        try:
            await courier.request_pickup(1)
        except Exception:
            logger.exception("Courier booked but pickup request failed for %s", shipment_id)
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
        shipment_id, awb = shipment.id, shipment.awb
        await db.commit()
    try:
        scans = await courier.track(awb)
    except Exception:
        logger.exception("Courier tracking failed for %s", shipment_id)
        return True
    async with async_session_factory() as db:
        shipment = (await db.execute(select(Shipment).where(Shipment.id == shipment_id).with_for_update())).scalar_one_or_none()
        if not shipment:
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
                await advance_order(db, shipment.order_id, FulfillmentStatus.delivered)
            elif state == "OUT_FOR_DELIVERY" and shipment.status not in {"out_for_delivery", "delivered"}:
                shipment.status = "out_for_delivery"
                await advance_order(db, shipment.order_id, FulfillmentStatus.shipped)
            elif state == "IN_TRANSIT" and shipment.status == "booked":
                shipment.status, shipment.picked_up_at = "in_transit", occurred
                await advance_order(db, shipment.order_id, FulfillmentStatus.shipped)
        await db.commit()
    return True


async def advance_order(db: AsyncSession, order_id: uuid.UUID, target: FulfillmentStatus) -> None:
    order = (await db.execute(select(Order).where(Order.id == order_id).with_for_update())).scalar_one_or_none()
    if not order or order.payment_status != PaymentStatus.paid or order.is_prelaunch_interest:
        return
    for line in await lines_for(db, order_id):
        if target == FulfillmentStatus.shipped and line.fulfillment_status == FulfillmentStatus.packed:
            line.fulfillment_status = target
        elif target == FulfillmentStatus.delivered and line.fulfillment_status in {FulfillmentStatus.packed, FulfillmentStatus.shipped}:
            line.fulfillment_status = target
    db.add(OrderEvent(order_id=order_id, title="Courier update", status=target.value, remarks="Confirmed by courier tracking"))


async def shipping_loop() -> None:
    while True:
        try:
            await process_ready_once()
            await poll_tracking_once()
        except Exception:
            logger.exception("Shipping worker iteration failed")
        await asyncio.sleep(30)
