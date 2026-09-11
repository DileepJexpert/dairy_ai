import uuid
from datetime import datetime
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user, require_role
from app.models.cart import CartItem
from app.models.delivery_address import DeliveryAddress
from app.models.order import Order, OrderItem, OrderStatus, FulfillmentStatus, PaymentStatus
from app.models.product import Product, ProductInventory
from app.models.user import User, UserRole
from app.repositories import vendor_repo
from app.repositories import cart_repo
from app.schemas.order import CheckoutRequest, CourierWebhookPayload, PaymentWebhookPayload
from app.services.delivery_address_service import serialize as serialize_address

router = APIRouter(prefix="/marketplace/orders", tags=["orders"])

# In-memory tracking store for courier telemetry and checkpoint history
_order_tracking_store: dict[str, dict] = {}


def _get_or_init_tracking(order_id: str, current_status: str = "CONFIRMED") -> dict:
    if order_id not in _order_tracking_store:
        now_str = datetime.utcnow().strftime("%d %b %Y, %I:%M %p")
        _order_tracking_store[order_id] = {
            "order_id": order_id,
            "carrier": "DTDC Express Surface",
            "awb_number": f"DTDC-{abs(hash(order_id)) % 9000000 + 1000000}",
            "current_status": current_status,
            "estimated_delivery": "Expected in 1-2 Days",
            "timeline": [
                {
                    "time": now_str,
                    "title": "Order Confirmed & Placed",
                    "location": "Milterra Pure Hub, Karnal",
                    "remarks": "Order verified and queued for temperature-controlled packing.",
                    "status": "CONFIRMED",
                }
            ],
        }
    return _order_tracking_store[order_id]


def serialize(order: Order, items: list[OrderItem]) -> dict:
    return {"id": str(order.id), "status": order.status.value, "payment_status": order.payment_status.value,
            "subtotal": str(order.subtotal), "delivery_fee": str(order.delivery_fee), "total": str(order.total),
            "address": order.address_snapshot, "created_at": order.created_at.isoformat(),
            "items": [{"product_id": str(item.product_id), "title": item.title, "quantity": item.quantity,
                       "unit_price": str(item.unit_price), "line_total": str(item.line_total),
                       "fulfillment_status": item.fulfillment_status.value} for item in items]}


async def _items(db: AsyncSession, order_id: uuid.UUID) -> list[OrderItem]:
    return list((await db.execute(select(OrderItem).where(OrderItem.order_id == order_id))).scalars())


@router.post("/checkout", status_code=status.HTTP_201_CREATED)
async def checkout(data: CheckoutRequest, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    existing = (await db.execute(select(Order).where(Order.user_id == current_user.id, Order.idempotency_key == data.idempotency_key))).scalar_one_or_none()
    if existing:
        return {"success": True, "data": serialize(existing, await _items(db, existing.id)), "message": "Existing order returned"}
    address = (await db.execute(select(DeliveryAddress).where(DeliveryAddress.id == data.delivery_address_id, DeliveryAddress.user_id == current_user.id))).scalar_one_or_none()
    if not address:
        raise HTTPException(404, "Delivery address not found")
    cart = await cart_repo.get_or_create_active_cart(db, current_user.id)
    cart_items = await cart_repo.items(db, cart.id)
    if not cart_items:
        raise HTTPException(422, "Cart is empty")
    lines: list[tuple[CartItem, Product, ProductInventory]] = []
    subtotal = Decimal("0")
    for cart_item in cart_items:
        product = (await db.execute(select(Product).where(Product.id == cart_item.product_id, Product.is_active.is_(True)).with_for_update())).scalar_one_or_none()
        inventory = (await db.execute(select(ProductInventory).where(ProductInventory.product_id == cart_item.product_id).with_for_update())).scalar_one_or_none()
        if not product or not inventory or cart_item.quantity < product.min_order_quantity or cart_item.quantity > inventory.available_quantity - inventory.reserved_quantity:
            raise HTTPException(422, "Cart changed; review price and stock before checkout")
        subtotal += product.base_price * cart_item.quantity
        lines.append((cart_item, product, inventory))
    order = Order(user_id=current_user.id, idempotency_key=data.idempotency_key, address_snapshot=serialize_address(address), subtotal=subtotal, delivery_fee=Decimal("0"), total=subtotal)
    db.add(order)
    await db.flush()
    for cart_item, product, inventory in lines:
        db.add(OrderItem(order_id=order.id, product_id=product.id, vendor_id=product.vendor_id, title=product.title, quantity=cart_item.quantity, unit_price=product.base_price, line_total=product.base_price * cart_item.quantity))
        inventory.available_quantity -= cart_item.quantity
        await db.delete(cart_item)
    await db.flush()
    return {"success": True, "data": serialize(order, await _items(db, order.id)), "message": "Order created; payment is pending"}


@router.get("")
async def list_orders(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    orders = list((await db.execute(select(Order).where(Order.user_id == current_user.id).order_by(Order.created_at.desc()))).scalars())
    return {"success": True, "data": [serialize(order, await _items(db, order.id)) for order in orders], "message": "Orders"}


@router.get("/vendor")
async def vendor_orders(current_user: User = Depends(require_role(UserRole.vendor)), db: AsyncSession = Depends(get_db)) -> dict:
    vendor = await vendor_repo.get_by_user_id(db, current_user.id)
    if not vendor:
        raise HTTPException(404, "Vendor profile not found")
    items = list((await db.execute(
        select(OrderItem)
        .join(Order, Order.id == OrderItem.order_id)
        .where(OrderItem.vendor_id == vendor.id, Order.payment_status == PaymentStatus.paid)
    )).scalars())
    result = []
    for item in items:
        order = (await db.execute(select(Order).where(Order.id == item.order_id))).scalar_one()
        result.append({"order_id": str(order.id), "item_id": str(item.id), "title": item.title, "quantity": item.quantity,
                       "fulfillment_status": item.fulfillment_status.value, "delivery_address": order.address_snapshot,
                       "created_at": order.created_at.isoformat()})
    return {"success": True, "data": result, "message": "Vendor order items"}


@router.get("/admin/all")
async def admin_orders(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    orders = list((await db.execute(select(Order).order_by(Order.created_at.desc()))).scalars())
    return {"success": True, "data": [serialize(order, await _items(db, order.id)) for order in orders], "message": "Admin orders"}


@router.put("/admin/{order_id}/fulfillment")
async def admin_update_fulfillment(order_id: str, fulfillment_status: FulfillmentStatus, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    try:
        order_uuid = uuid.UUID(order_id)
    except ValueError as exc:
        raise HTTPException(422, "Invalid order id") from exc
    order = (await db.execute(select(Order).where(Order.id == order_uuid))).scalar_one_or_none()
    if not order:
        raise HTTPException(404, "Order not found")
    items = await _items(db, order.id)
    for it in items:
        it.fulfillment_status = fulfillment_status
    if fulfillment_status == FulfillmentStatus.delivered:
        order.status = OrderStatus.confirmed
    await db.flush()
    return {"success": True, "data": serialize(order, items), "message": "Order fulfillment updated"}


@router.get("/{order_id}")
async def get_order(order_id: str, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    try:
        order_uuid = uuid.UUID(order_id)
    except ValueError as exc:
        raise HTTPException(422, "Invalid order id") from exc
    order = (await db.execute(select(Order).where(Order.id == order_uuid, Order.user_id == current_user.id))).scalar_one_or_none()
    if not order:
        raise HTTPException(404, "Order not found")
    return {"success": True, "data": serialize(order, await _items(db, order.id)), "message": "Order"}


@router.put("/vendor/items/{item_id}/fulfillment")
async def update_fulfillment(item_id: str, fulfillment_status: FulfillmentStatus, current_user: User = Depends(require_role(UserRole.vendor)), db: AsyncSession = Depends(get_db)) -> dict:
    vendor = await vendor_repo.get_by_user_id(db, current_user.id)
    try:
        item_uuid = uuid.UUID(item_id)
    except ValueError as exc:
        raise HTTPException(422, "Invalid order item id") from exc
    item = (await db.execute(select(OrderItem).where(OrderItem.id == item_uuid))).scalar_one_or_none()
    if not vendor or not item or item.vendor_id != vendor.id:
        raise HTTPException(404, "Order item not found")
    order = (await db.execute(select(Order).where(Order.id == item.order_id))).scalar_one()
    if order.payment_status != PaymentStatus.paid:
        raise HTTPException(422, "Payment must be confirmed before fulfillment")
    allowed = {FulfillmentStatus.pending: {FulfillmentStatus.confirmed, FulfillmentStatus.cancelled}, FulfillmentStatus.confirmed: {FulfillmentStatus.packed, FulfillmentStatus.cancelled}, FulfillmentStatus.packed: {FulfillmentStatus.shipped}, FulfillmentStatus.shipped: {FulfillmentStatus.delivered}}
    if fulfillment_status not in allowed.get(item.fulfillment_status, set()):
        raise HTTPException(422, "Invalid fulfillment transition")
    item.fulfillment_status = fulfillment_status
    await db.flush()
    return {"success": True, "data": {"id": str(item.id), "fulfillment_status": item.fulfillment_status.value}, "message": "Fulfillment updated"}


@router.get("/{order_id}/tracking")
async def get_order_tracking(order_id: str, db: AsyncSession = Depends(get_db)) -> dict:
    """Real-time courier telemetry & milestone tracking."""
    status_hint = "CONFIRMED"
    try:
        order_uuid = uuid.UUID(order_id)
        order = (await db.execute(select(Order).where(Order.id == order_uuid))).scalar_one_or_none()
        if order:
            items = await _items(db, order.id)
            if items and items[0].fulfillment_status:
                status_hint = items[0].fulfillment_status.value
    except ValueError:
        pass

    tracking = _get_or_init_tracking(order_id, status_hint)
    return {
        "success": True,
        "data": tracking,
        "message": f"Courier tracking for {order_id}",
    }


@router.post("/{order_id}/advance-transit")
async def advance_order_transit(order_id: str, db: AsyncSession = Depends(get_db)) -> dict:
    """Advance order through DTDC milestones: CONFIRMED -> PACKED -> DISPATCHED -> OUT_FOR_DELIVERY -> DELIVERED."""
    transitions = {
        "CONFIRMED": "PACKED",
        "PACKED": "DISPATCHED",
        "DISPATCHED": "OUT_FOR_DELIVERY",
        "OUT_FOR_DELIVERY": "DELIVERED",
        "DELIVERED": "DELIVERED",
    }
    tracking = _get_or_init_tracking(order_id)
    current = tracking.get("current_status", "CONFIRMED").upper()
    next_status = transitions.get(current, "PACKED")
    payload = CourierWebhookPayload(
        order_id=order_id,
        carrier=tracking.get("carrier", "DTDC Express Surface"),
        awb_number=tracking.get("awb_number", f"DTDC-{abs(hash(order_id)) % 9000000 + 1000000}"),
        status=next_status,
    )
    return await courier_webhook(payload, db)


@router.post("/webhooks/courier", status_code=status.HTTP_200_OK)
async def courier_webhook(payload: CourierWebhookPayload, db: AsyncSession = Depends(get_db)) -> dict:
    """DTDC / Delhivery Logistics partner webhook for real-time tracking updates."""
    normalized_status = payload.status.upper()
    now_str = payload.timestamp or datetime.utcnow().strftime("%d %b %Y, %I:%M %p")

    # Update tracking store
    tracking = _get_or_init_tracking(payload.order_id, normalized_status)
    tracking["current_status"] = normalized_status
    if payload.carrier:
        tracking["carrier"] = payload.carrier
    if payload.awb_number:
        tracking["awb_number"] = payload.awb_number

    checkpoint_title = {
        "CONFIRMED": "Order Confirmed & Allocated",
        "PACKED": "Packed & Sealed with Quality Hologram",
        "DISPATCHED": f"Picked up by {payload.carrier or 'DTDC Express'}",
        "OUT_FOR_DELIVERY": "Out for Delivery with Courier Executive",
        "DELIVERED": "Delivered to Recipient",
        "CANCELLED": "Delivery Cancelled by Consignee",
    }.get(normalized_status, f"Status updated: {normalized_status}")

    checkpoint_location = payload.location or {
        "CONFIRMED": "Milterra Pure Hub, Karnal",
        "PACKED": "Cold Chain Packaging Unit, Karnal",
        "DISPATCHED": "DTDC Sorting Center, Jaipur Hub",
        "OUT_FOR_DELIVERY": "Local Delivery Van #DL-4821",
        "DELIVERED": "Customer Delivery Address",
        "CANCELLED": "Milterra Customer Care Desk",
    }.get(normalized_status, "Logistics Hub")

    checkpoint_remarks = payload.remarks or f"Milestone update: {normalized_status} recorded by courier partner."

    # Avoid duplicate sequential statuses
    if not tracking["timeline"] or tracking["timeline"][-1].get("status") != normalized_status:
        tracking["timeline"].append({
            "time": now_str,
            "title": checkpoint_title,
            "location": checkpoint_location,
            "remarks": checkpoint_remarks,
            "status": normalized_status,
        })

    # Update DB if order exists
    try:
        order_uuid = uuid.UUID(payload.order_id)
        order = (await db.execute(select(Order).where(Order.id == order_uuid))).scalar_one_or_none()
        if order:
            items = await _items(db, order.id)
            mapping = {
                "CONFIRMED": FulfillmentStatus.confirmed,
                "PACKED": FulfillmentStatus.packed,
                "DISPATCHED": FulfillmentStatus.shipped,
                "OUT_FOR_DELIVERY": FulfillmentStatus.shipped,
                "DELIVERED": FulfillmentStatus.delivered,
                "CANCELLED": FulfillmentStatus.cancelled,
            }
            if normalized_status in mapping:
                for it in items:
                    it.fulfillment_status = mapping[normalized_status]
                if mapping[normalized_status] == FulfillmentStatus.delivered:
                    order.status = OrderStatus.confirmed
                await db.flush()
    except ValueError:
        pass

    return {
        "success": True,
        "data": tracking,
        "message": f"Courier status updated to {normalized_status} for order {payload.order_id}",
    }


@router.post("/webhooks/payment", status_code=status.HTTP_200_OK)
async def payment_webhook(payload: PaymentWebhookPayload, db: AsyncSession = Depends(get_db)) -> dict:
    """Payment gateway webhook (UPI, Razorpay, Wallet)."""
    try:
        order_uuid = uuid.UUID(payload.order_id)
    except ValueError:
        return {"success": True, "message": f"Payment webhook acknowledged for {payload.order_id}"}

    order = (await db.execute(select(Order).where(Order.id == order_uuid))).scalar_one_or_none()
    if not order:
        return {"success": True, "message": f"Order {payload.order_id} recorded in payment log"}

    if payload.payment_status.upper() == "PAID":
        order.payment_status = PaymentStatus.paid
        order.status = OrderStatus.confirmed
    elif payload.payment_status.upper() == "FAILED":
        order.payment_status = PaymentStatus.failed
    await db.flush()

    items = await _items(db, order.id)
    return {
        "success": True,
        "data": serialize(order, items),
        "message": f"Payment status updated to {payload.payment_status}",
    }

