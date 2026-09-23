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
from app.models.commerce_admin import OrderCoupon, CommerceCoupon
from app.models.serviceable_pincode import ServiceablePincode
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
            "return_reason": getattr(order, "return_reason", None),
            "return_status": getattr(order, "return_status", None),
            "return_requested_at": order.return_requested_at.isoformat() if getattr(order, "return_requested_at", None) else None,
            "return_processed_at": order.return_processed_at.isoformat() if getattr(order, "return_processed_at", None) else None,
            "return_remarks": getattr(order, "return_remarks", None),
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
    postal_code = (address.postal_code or "").strip()
    pincode_row = (await db.execute(select(ServiceablePincode).where(ServiceablePincode.pincode == postal_code))).scalar_one_or_none()
    delivery_fee = Decimal("0")
    if pincode_row:
        if not pincode_row.is_serviceable:
            raise HTTPException(422, f"Delivery is not currently available for pincode {postal_code}")
        if pincode_row.delivery_fee:
            delivery_fee = Decimal(str(pincode_row.delivery_fee))

    coupon = None
    discount = Decimal("0")
    if data.coupon_code:
        coupon_peek = (await db.execute(select(CommerceCoupon).where(CommerceCoupon.code == data.coupon_code.strip().upper()))).scalar_one_or_none()
        vendor_subtotal = None
        has_vendor_items = True
        if coupon_peek and getattr(coupon_peek, "vendor_id", None) is not None:
            vendor_lines = [p for _, p, _ in lines if p.vendor_id == coupon_peek.vendor_id]
            if not vendor_lines:
                raise HTTPException(422, "Coupon is only valid for products from this seller")
            vendor_subtotal = sum((p.base_price * ci.quantity for ci, p, _ in lines if p.vendor_id == coupon_peek.vendor_id), Decimal("0"))
        coupon, discount = await validate_coupon(db, data.coupon_code, subtotal, lock=True, vendor_subtotal=vendor_subtotal, has_vendor_items=has_vendor_items)
    order = Order(user_id=current_user.id, idempotency_key=data.idempotency_key,
                  is_prelaunch_interest=settings.PRELAUNCH_MODE,
                  address_snapshot=serialize_address(address), subtotal=subtotal,
                  delivery_fee=delivery_fee, total=subtotal - discount + delivery_fee)
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

        # Attach vendor legal and compliance details for packing slip & tax invoice
        order_vendor = vendor
        if not order_vendor and items:
            order_vendor = await vendor_repo.get_by_id(db, items[0].vendor_id)

        if order_vendor:
            data['vendor_info'] = {
                'id': str(order_vendor.id),
                'business_name': order_vendor.business_name,
                'gst_number': order_vendor.gst_number or 'Unregistered',
                'license_number': order_vendor.license_number or 'Applied / Standard',
                'district': order_vendor.district or '',
                'state': order_vendor.state or '',
                'contact_person': order_vendor.contact_person or '',
            }
        else:
            data['vendor_info'] = {
                'business_name': 'Milterra Partner Vendor',
                'gst_number': 'Unregistered',
                'license_number': 'Standard',
                'district': '',
                'state': '',
            }

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
        raise HTTPException(409, 'This order requires staff cancellation and refund review')
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
        if order.payment_status == PaymentStatus.refunded:
            raise HTTPException(400, 'Order has already been refunded')
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


class ReturnCreateRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')
    reason: str = Field(..., max_length=200)
    remarks: str = Field(default='', max_length=800)


@router.post('/{order_id}/return')
async def request_order_return(order_id: uuid.UUID, data: ReturnCreateRequest, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    order = (await db.execute(select(Order).where(Order.id == order_id).with_for_update())).scalar_one_or_none()
    if not order:
        raise HTTPException(404, 'Order not found')
    if order.user_id != user.id and user.role not in (UserRole.admin, UserRole.super_admin):
        raise HTTPException(403, 'Not authorized to request return for this order')
    order.return_reason = data.reason
    order.return_status = 'RETURN_REQUESTED'
    order.return_requested_at = datetime.utcnow()
    order.return_remarks = data.remarks
    event(db, order, f'Return requested: {data.reason}', 'RETURN_REQUESTED', data.remarks)
    await db.flush()
    return {'success': True, 'data': await detail(db, order), 'message': 'Return request submitted successfully'}


@router.get('/admin/returns')
async def admin_returns(user: User = Depends(require_role(UserRole.admin, UserRole.super_admin)), db: AsyncSession = Depends(get_db)):
    query = (
        select(Order, User.phone)
        .join(User, User.id == Order.user_id)
        .where(Order.return_status.is_not(None))
        .order_by(Order.return_requested_at.desc())
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


class ReturnProcessRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')
    action: Literal['approve_pickup', 'reject', 'confirm_received_refund', 'mark_rto']
    refund_reference: str = Field(default='', max_length=100)
    remarks: str = Field(default='', max_length=800)
    restock_inventory: bool = True


@router.post('/admin/returns/{order_id}/process')
async def process_return(order_id: uuid.UUID, data: ReturnProcessRequest, user: User = Depends(require_role(UserRole.admin, UserRole.super_admin)), db: AsyncSession = Depends(get_db)):
    order = (await db.execute(select(Order).where(Order.id == order_id).with_for_update())).scalar_one_or_none()
    if not order:
        raise HTTPException(404, 'Order not found')
    order.return_processed_at = datetime.utcnow()
    items = await _items(db, order.id)

    if data.action == 'approve_pickup':
        order.return_status = 'PICKUP_SCHEDULED'
        event(db, order, 'Return pickup scheduled with courier', 'PICKUP_SCHEDULED', data.remarks)
        audit(db, user, 'order.return_pickup_scheduled', 'order', order.id, data.model_dump_json())
    elif data.action == 'confirm_received_refund':
        if order.return_status == 'RETURN_COMPLETED' or order.payment_status == PaymentStatus.refunded:
            raise HTTPException(400, 'Return refund already completed')
        order.return_status = 'RETURN_COMPLETED'
        order.payment_status = PaymentStatus.refunded
        for item in items:
            item.fulfillment_status = FulfillmentStatus.cancelled
            if data.restock_inventory and not order.is_prelaunch_interest:
                inv = (await db.execute(select(ProductInventory).where(ProductInventory.product_id == item.product_id).with_for_update())).scalar_one_or_none()
                if inv:
                    inv.available_quantity += item.quantity
        event(db, order, f'Item inspected & return refund issued: ₹{order.total}', 'REFUNDED', f'Ref: {data.refund_reference} · {data.remarks}'.strip(' ·'))
        audit(db, user, 'order.return_refunded', 'order', order.id, data.model_dump_json())
    elif data.action == 'mark_rto':
        if order.return_status == 'RTO_DELIVERED' or order.status == OrderStatus.cancelled:
            raise HTTPException(400, 'Order RTO has already been processed')
        order.return_status = 'RTO_DELIVERED'
        order.status = OrderStatus.cancelled
        if data.restock_inventory and not order.is_prelaunch_interest:
            for item in items:
                inv = (await db.execute(select(ProductInventory).where(ProductInventory.product_id == item.product_id).with_for_update())).scalar_one_or_none()
                if inv:
                    inv.available_quantity += item.quantity
        event(db, order, 'Package returned to origin (RTO)', 'RTO_DELIVERED', data.remarks)
        audit(db, user, 'order.rto_processed', 'order', order.id, data.model_dump_json())
    else:
        order.return_status = 'RETURN_REJECTED'
        event(db, order, 'Return request rejected', 'RETURN_REJECTED', data.remarks)
        audit(db, user, 'order.return_rejected', 'order', order.id, data.model_dump_json())

    await db.flush()
    return {'success': True, 'data': await detail(db, order), 'message': f'Return status updated to {order.return_status}'}

