import uuid
from datetime import datetime
from typing import Literal
from pydantic import BaseModel, Field, ConfigDict
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user, require_role
from app.models.cart import CartItem
from app.models.delivery_address import DeliveryAddress
from app.models.order import Order, OrderItem, FulfillmentStatus, PaymentStatus
from app.models.product import Product, ProductInventory
from app.models.user import User, UserRole
from app.config import settings
from app.repositories import vendor_repo
from app.repositories import cart_repo
from app.schemas.order import CheckoutRequest
from app.services.delivery_address_service import serialize as serialize_address
from app.services.product_policy import purchase_enabled
from app.models.commerce_admin import OrderCoupon
from app.models.customer_commerce import OrderContact, OrderEvent
from app.models.notification import Notification, NotificationType
from app.models.order import OrderStatus
from app.services.commerce_admin_service import audit
from app.services.commerce_admin_service import validate_coupon

router = APIRouter(prefix="/marketplace/orders", tags=["orders"])


def serialize(order: Order, items: list[OrderItem]) -> dict:
    return {"id": str(order.id), "status": order.status.value, "payment_status": order.payment_status.value,
            "is_prelaunch_interest": order.is_prelaunch_interest,
            "subtotal": str(order.subtotal), "delivery_fee": str(order.delivery_fee), "total": str(order.total),
            "discount": str(order.subtotal + order.delivery_fee - order.total),
            "address": order.address_snapshot, "created_at": order.created_at.isoformat(),
            "items": [{"product_id": str(item.product_id), "title": item.title, "quantity": item.quantity,
                       "unit_price": str(item.unit_price), "line_total": str(item.line_total),
                       "fulfillment_status": item.fulfillment_status.value} for item in items]}


async def _items(db: AsyncSession, order_id: uuid.UUID) -> list[OrderItem]:
    return list((await db.execute(select(OrderItem).where(OrderItem.order_id == order_id))).scalars())


async def detail(db, order):
    items = await _items(db, order.id)
    data = serialize(order, items)
    stages = {i.fulfillment_status for i in items}
    if order.payment_status == PaymentStatus.paid and order.status != OrderStatus.cancelled and len(stages) == 1:
        data['status'] = next(iter(stages)).value
    contact = await db.get(OrderContact, order.id)
    events = (await db.execute(select(OrderEvent).where(OrderEvent.order_id == order.id).order_by(OrderEvent.created_at))).scalars()
    data['payment_method'] = contact.payment_method if contact else 'not specified'
    data['carrier'] = contact.carrier if contact else ''
    data['tracking_number'] = contact.tracking_number if contact else ''
    data['timeline'] = [{'time': e.created_at.isoformat() + 'Z', 'title': e.title, 'status': e.status, 'remarks': e.remarks, 'location': ''} for e in events]
    return data


def event(db, order, title, state, remarks=''):
    db.add(OrderEvent(order_id=order.id, title=title, status=state, remarks=remarks))
    db.add(Notification(user_id=order.user_id, type=NotificationType.general, title=title,
                        body=remarks or title, data={'order_id': str(order.id)}))


@router.post("/checkout", status_code=status.HTTP_201_CREATED)
async def checkout(data: CheckoutRequest, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    existing = (await db.execute(select(Order).where(Order.user_id == current_user.id, Order.idempotency_key == data.idempotency_key))).scalar_one_or_none()
    if existing:
        return {"success": True, "data": await detail(db, existing), "message": "Existing order returned"}
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
        if not await purchase_enabled(db, product) or not inventory or cart_item.quantity < product.min_order_quantity or cart_item.quantity > inventory.available_quantity - inventory.reserved_quantity:
            raise HTTPException(422, "Cart changed; review price and stock before checkout")
        subtotal += product.base_price * cart_item.quantity
        lines.append((cart_item, product, inventory))
    coupon = None
    discount = Decimal("0")
    if data.coupon_code:
        coupon, discount = await validate_coupon(db, data.coupon_code, subtotal, lock=True)
    order = Order(user_id=current_user.id, idempotency_key=data.idempotency_key,
                  is_prelaunch_interest=settings.PRELAUNCH_MODE,
                  address_snapshot=serialize_address(address), subtotal=subtotal,
                  delivery_fee=Decimal("0"), total=subtotal-discount)
    db.add(order)
    await db.flush()
    db.add(OrderContact(order_id=order.id, payment_method=data.payment_method))
    event(db, order, 'Purchase interest recorded' if order.is_prelaunch_interest else 'Order received', order.status.value,
          'No payment was taken. We will contact you before launch.' if order.is_prelaunch_interest else 'Payment pending')
    if coupon:
        db.add(OrderCoupon(order_id=order.id, coupon_id=coupon.id, code=coupon.code, discount=discount))
    for cart_item, product, inventory in lines:
        db.add(OrderItem(order_id=order.id, product_id=product.id, vendor_id=product.vendor_id, title=product.title, quantity=cart_item.quantity, unit_price=product.base_price, line_total=product.base_price * cart_item.quantity))
        if not settings.PRELAUNCH_MODE:
            inventory.available_quantity -= cart_item.quantity
        await db.delete(cart_item)
    await db.flush()
    message = (
        "Pre-launch purchase interest recorded; no payment was taken"
        if settings.PRELAUNCH_MODE
        else "Order created; payment is pending"
    )
    return {"success": True, "data": await detail(db, order), "message": message}


@router.get("")
async def list_orders(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    orders = list((await db.execute(select(Order).where(Order.user_id == current_user.id).order_by(Order.created_at.desc()))).scalars())
    return {"success": True, "data": [await detail(db, order) for order in orders], "message": "Orders"}


@router.get("/admin/interests")
async def admin_purchase_interests(
    current_user: User = Depends(require_role(UserRole.admin, UserRole.super_admin)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    rows = (await db.execute(
        select(Order, User.phone)
        .join(User, User.id == Order.user_id)
        .where(Order.is_prelaunch_interest.is_(True))
        .order_by(Order.created_at.desc())
        .limit(500)
    )).all()
    data = []
    for order, phone in rows:
        item_data = await detail(db, order)
        item_data["customer_phone"] = phone
        contact = await db.get(OrderContact, order.id)
        item_data["interest_status"] = contact.interest_status if contact else "NEW"
        item_data["followup_notes"] = contact.notes if contact else ""
        data.append(item_data)
    return {
        "success": True,
        "data": data,
        "total": len(data),
        "message": "Pre-launch purchase interests",
    }


@router.get("/vendor")
async def vendor_orders(current_user: User = Depends(require_role(UserRole.vendor)), db: AsyncSession = Depends(get_db)) -> dict:
    vendor = await vendor_repo.get_by_user_id(db, current_user.id)
    if not vendor or not vendor.is_active:
        raise HTTPException(404, "Vendor profile not found")
    items = list((await db.execute(
        select(OrderItem)
        .join(Order, Order.id == OrderItem.order_id)
        .where(OrderItem.vendor_id == vendor.id, Order.payment_status == PaymentStatus.paid, Order.is_prelaunch_interest.is_(False), Order.status != OrderStatus.cancelled)
    )).scalars())
    result = []
    for item in items:
        order = (await db.execute(select(Order).where(Order.id == item.order_id))).scalar_one()
        result.append({"order_id": str(order.id), "item_id": str(item.id), "title": item.title, "quantity": item.quantity,
                       "fulfillment_status": item.fulfillment_status.value, "delivery_address": order.address_snapshot,
                       "created_at": order.created_at.isoformat()})
    return {"success": True, "data": result, "message": "Vendor order items"}


@router.put("/vendor/items/{item_id}/fulfillment")
async def update_fulfillment(item_id: str, fulfillment_status: FulfillmentStatus, current_user: User = Depends(require_role(UserRole.vendor)), db: AsyncSession = Depends(get_db)) -> dict:
    vendor = await vendor_repo.get_by_user_id(db, current_user.id)
    try:
        item_uuid = uuid.UUID(item_id)
    except ValueError as exc:
        raise HTTPException(422, "Invalid order item id") from exc
    item = (await db.execute(select(OrderItem).where(OrderItem.id == item_uuid))).scalar_one_or_none()
    if not vendor or not vendor.is_active or not item or item.vendor_id != vendor.id:
        raise HTTPException(404, "Order item not found")
    order = (await db.execute(select(Order).where(Order.id == item.order_id))).scalar_one()
    if order.payment_status != PaymentStatus.paid or order.is_prelaunch_interest or order.status == OrderStatus.cancelled:
        raise HTTPException(422, "Payment must be confirmed before fulfillment")
    allowed = {FulfillmentStatus.pending: {FulfillmentStatus.confirmed, FulfillmentStatus.cancelled}, FulfillmentStatus.confirmed: {FulfillmentStatus.packed, FulfillmentStatus.cancelled}, FulfillmentStatus.packed: {FulfillmentStatus.shipped}, FulfillmentStatus.shipped: {FulfillmentStatus.delivered}}
    if fulfillment_status not in allowed.get(item.fulfillment_status, set()):
        raise HTTPException(422, "Invalid fulfillment transition")
    item.fulfillment_status = fulfillment_status
    event(db, order, f'{item.title}: {fulfillment_status.value.lower()}', fulfillment_status.value)
    await db.flush()
    return {"success": True, "data": {"id": str(item.id), "fulfillment_status": item.fulfillment_status.value}, "message": "Fulfillment updated"}


class FollowupUpdate(BaseModel):
    model_config = ConfigDict(extra='forbid')
    interest_status: Literal['NEW', 'CONTACTED', 'WAITLISTED', 'CLOSED']
    notes: str = Field(default='', max_length=4000)


@router.patch('/admin/interests/{order_id}')
async def followup(order_id: uuid.UUID, data: FollowupUpdate, user: User = Depends(require_role(UserRole.admin, UserRole.super_admin)), db: AsyncSession = Depends(get_db)):
    order = (await db.execute(select(Order).where(Order.id == order_id, Order.is_prelaunch_interest.is_(True)).with_for_update())).scalar_one_or_none()
    if not order:
        raise HTTPException(404, 'Purchase interest not found')
    contact = await db.get(OrderContact, order.id)
    if not contact:
        contact = OrderContact(order_id=order.id)
        db.add(contact)
    contact.interest_status = data.interest_status
    contact.notes = data.notes
    contact.updated_at = datetime.utcnow()
    audit(db, user, 'interest.followup', 'order', order.id, data.model_dump_json())
    await db.flush()
    return {'success': True, 'data': {'interest_status': contact.interest_status, 'followup_notes': contact.notes}}


@router.get('/operations')
async def operations(user: User = Depends(require_role(UserRole.admin, UserRole.super_admin, UserRole.vendor)), db: AsyncSession = Depends(get_db)):
    query = select(Order).where(Order.payment_status == PaymentStatus.paid, Order.is_prelaunch_interest.is_(False))
    vendor = await vendor_repo.get_by_user_id(db, user.id) if user.role == UserRole.vendor else None
    if user.role == UserRole.vendor:
        if not vendor or not vendor.is_active:
            raise HTTPException(403, 'Active vendor profile required')
        query = query.where(Order.id.in_(select(OrderItem.order_id).where(OrderItem.vendor_id == vendor.id)))
    result = []
    for order in (await db.execute(query.order_by(Order.created_at.desc()))).scalars():
        items = await _items(db, order.id)
        if vendor:
            items = [item for item in items if item.vendor_id == vendor.id]
        data = await detail(db, order)
        data['items'] = serialize(order, items)['items']
        # Seller sees their lines and revenue, not another seller's basket.
        if vendor:
            data['subtotal'] = data['total'] = str(sum((i.line_total for i in items), Decimal('0')))
            data['discount'] = data['delivery_fee'] = '0'
            data['timeline'] = []  # Account-wide timeline can mention other sellers' lines.
        stages = {i.fulfillment_status for i in items}
        if len(stages) == 1:
            data['status'] = next(iter(stages)).value
        result.append(data)
    return {'success': True, 'data': result}


class FulfillmentUpdate(BaseModel):
    model_config = ConfigDict(extra='forbid')
    status: Literal['CONFIRMED', 'PACKED', 'DISPATCHED', 'SHIPPED', 'OUT_FOR_DELIVERY', 'DELIVERED']
    carrier: str = Field(default='', max_length=100)
    tracking_number: str = Field(default='', max_length=100)
    location: str = Field(default='', max_length=200)
    remarks: str = Field(default='', max_length=800)


@router.put('/operations/{order_id}')
async def operation_update(order_id: uuid.UUID, data: FulfillmentUpdate, user: User = Depends(require_role(UserRole.admin, UserRole.super_admin, UserRole.vendor)), db: AsyncSession = Depends(get_db)):
    order = (await db.execute(select(Order).where(Order.id == order_id).with_for_update())).scalar_one_or_none()
    if not order:
        raise HTTPException(404, 'Order not found')
    items = await _items(db, order.id)
    if user.role == UserRole.vendor:
        vendor = await vendor_repo.get_by_user_id(db, user.id)
        items = [i for i in items if vendor and vendor.is_active and i.vendor_id == vendor.id]
        if not items:
            raise HTTPException(404, 'Order not found')
    if order.is_prelaunch_interest or order.payment_status != PaymentStatus.paid or order.status == OrderStatus.cancelled:
        raise HTTPException(409, 'Only confirmed paid commercial orders can be fulfilled')
    target = FulfillmentStatus.shipped if data.status in ('DISPATCHED', 'OUT_FOR_DELIVERY') else FulfillmentStatus(data.status)
    allowed = {FulfillmentStatus.pending: FulfillmentStatus.confirmed, FulfillmentStatus.confirmed: FulfillmentStatus.packed, FulfillmentStatus.packed: FulfillmentStatus.shipped, FulfillmentStatus.shipped: FulfillmentStatus.delivered}
    if any(i.fulfillment_status != target and allowed.get(i.fulfillment_status) != target for i in items):
        raise HTTPException(422, 'Invalid fulfillment transition')
    if all(i.fulfillment_status == target for i in items):
        if data.status != 'OUT_FOR_DELIVERY' or (await db.execute(select(OrderEvent.id).where(OrderEvent.order_id == order.id, OrderEvent.status == 'OUT_FOR_DELIVERY'))).first():
            return {'success': True, 'data': {'id': str(order.id), 'fulfillment_status': target.value}}
    contact = await db.get(OrderContact, order.id)
    if not contact:
        contact = OrderContact(order_id=order.id)
        db.add(contact)
    if target == FulfillmentStatus.shipped and data.status != 'OUT_FOR_DELIVERY':
        if not data.carrier.strip() or not data.tracking_number.strip():
            raise HTTPException(422, 'Enter the actual courier and tracking reference')
        # Per-seller shipment metadata must not overwrite another seller's shipment.
        if len({i.vendor_id for i in await _items(db, order.id)}) > 1:
            raise HTTPException(409, 'Multi-seller shipment tracking requires separate shipment records')
        contact.carrier, contact.tracking_number = data.carrier.strip(), data.tracking_number.strip()
    for item in items:
        item.fulfillment_status = target
    event(db, order, f'Fulfillment: {data.status.lower()}', data.status, ' · '.join(x for x in (data.location, data.remarks) if x))
    audit(db, user, 'order.fulfillment', 'order', order.id, data.model_dump_json())
    await db.flush()
    return {'success': True, 'data': {'id': str(order.id), 'fulfillment_status': target.value}}


@router.get('/{order_id}')
async def customer_order(order_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    order = (await db.execute(select(Order).where(Order.id == order_id, Order.user_id == user.id))).scalar_one_or_none()
    if not order:
        raise HTTPException(404, 'Order not found')
    return {'success': True, 'data': await detail(db, order)}


class CancelRequest(BaseModel):
    reason: str = Field(default='', max_length=1000)


@router.post('/{order_id}/cancel')
async def cancel_order(order_id: uuid.UUID, data: CancelRequest, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    order = (await db.execute(select(Order).where(Order.id == order_id, Order.user_id == user.id).with_for_update())).scalar_one_or_none()
    if not order:
        raise HTTPException(404, 'Order not found')
    if order.status == OrderStatus.cancelled:
        return {'success': True, 'data': await detail(db, order)}
    items = await _items(db, order.id)
    if order.payment_status == PaymentStatus.paid:
        contact = await db.get(OrderContact, order.id)
        if not contact:
            contact = OrderContact(order_id=order.id)
            db.add(contact)
        contact.notes = f"Cancellation requested: {data.reason}".strip()
        event(db, order, 'Cancellation & refund requested by customer', 'CANCEL_REQUESTED', data.reason)
        audit(db, user, 'order.cancel_request', 'order', order.id, data.model_dump_json())
        await db.flush()
        return {'success': True, 'data': await detail(db, order), 'message': 'Cancellation request submitted for staff review and refund'}
    if any(i.fulfillment_status not in (FulfillmentStatus.pending, FulfillmentStatus.confirmed) for i in items):
        raise HTTPException(409, 'Shipped or delivered orders require support assistance')
    for item in sorted(items, key=lambda i: str(i.product_id)):
        if not order.is_prelaunch_interest:
            inventory = (await db.execute(select(ProductInventory).where(ProductInventory.product_id == item.product_id).with_for_update())).scalar_one_or_none()
            if inventory:
                inventory.available_quantity += item.quantity
        item.fulfillment_status = FulfillmentStatus.cancelled
    order.status = OrderStatus.cancelled
    event(db, order, 'Purchase interest withdrawn' if order.is_prelaunch_interest else 'Order cancelled', 'CANCELLED', data.reason)
    await db.flush()
    return {'success': True, 'data': await detail(db, order)}


@router.get('/admin/cancellations')
async def admin_cancellations(user: User = Depends(require_role(UserRole.admin, UserRole.super_admin)), db: AsyncSession = Depends(get_db)):
    query = (
        select(Order, User.phone)
        .join(User, User.id == Order.user_id)
        .where(
            or_(
                Order.payment_status == PaymentStatus.refunded,
                Order.id.in_(
                    select(OrderEvent.order_id).where(OrderEvent.status == 'CANCEL_REQUESTED')
                ),
            )
        )
        .order_by(Order.created_at.desc())
        .limit(100)
    )
    rows = (await db.execute(query)).all()
    results = []
    for order, phone in rows:
        d = await detail(db, order)
        d['customer_phone'] = phone
        contact = await db.get(OrderContact, order.id)
        d['notes'] = contact.notes if contact else ''
        results.append(d)
    return {'success': True, 'data': results}


class RefundProcessRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')
    action: Literal['approve', 'reject']
    refund_reference: str = Field(default='', max_length=100)
    remarks: str = Field(default='', max_length=800)
    restock_inventory: bool = True


@router.post('/admin/refunds/{order_id}')
async def process_refund(order_id: uuid.UUID, data: RefundProcessRequest, user: User = Depends(require_role(UserRole.admin, UserRole.super_admin)), db: AsyncSession = Depends(get_db)):
    order = (await db.execute(select(Order).where(Order.id == order_id).with_for_update())).scalar_one_or_none()
    if not order:
        raise HTTPException(404, 'Order not found')
    items = await _items(db, order.id)
    if data.action == 'approve':
        order.payment_status = PaymentStatus.refunded
        order.status = OrderStatus.cancelled
        for item in items:
            item.fulfillment_status = FulfillmentStatus.cancelled
            if data.restock_inventory and not order.is_prelaunch_interest:
                inv = (await db.execute(select(ProductInventory).where(ProductInventory.product_id == item.product_id).with_for_update())).scalar_one_or_none()
                if inv:
                    inv.available_quantity += item.quantity
        event(db, order, f'Refund processed: ₹{order.total}', 'REFUNDED', f'Ref: {data.refund_reference} · {data.remarks}'.strip(' ·'))
        audit(db, user, 'order.refund_approved', 'order', order.id, data.model_dump_json())
    else:
        event(db, order, 'Cancellation request rejected', 'CONFIRMED', data.remarks)
        audit(db, user, 'order.refund_rejected', 'order', order.id, data.model_dump_json())
    await db.flush()
    return {'success': True, 'data': await detail(db, order), 'message': f'Refund {data.action}d successfully'}
