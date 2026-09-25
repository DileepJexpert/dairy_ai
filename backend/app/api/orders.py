import uuid
import asyncio
import hashlib
import hmac
import json
import logging
from urllib.parse import urlparse
from datetime import datetime, timedelta
from typing import Literal
from pydantic import BaseModel, Field, ConfigDict
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db, async_session_factory
from app.dependencies import get_current_user, require_role
from app.models.cart import CartItem
from app.models.delivery_address import DeliveryAddress
from app.models.order import Order, OrderItem, FulfillmentStatus, PaymentStatus
from app.models.product import Product, ProductInventory
from app.models.user import User, UserRole
from app.config import settings
from app.repositories import vendor_repo
from app.repositories import cart_repo
from app.schemas.order import CheckoutPricingInput, CheckoutRequest
from app.services.delivery_address_service import serialize as serialize_address
from app.services.product_policy import purchase_enabled
from app.models.commerce_admin import OrderCoupon, CommerceCoupon
from app.models.serviceable_pincode import ServiceablePincode
from app.models.customer_commerce import OrderContact, OrderEvent
from app.models.notification import Notification, NotificationType
from app.models.order import OrderStatus
from app.services.commerce_admin_service import audit
from app.services.commerce_admin_service import validate_coupon
from app.models.shipping import Shipment, ShipmentEvent
from app.api.shipment_tracking import (
    prepare_shipment, record_manual_dispatch, record_manual_milestone,
    shipment_data, stop_shipment_for_refund, cancellation_request_pending,
)
from app.integrations.shipping_policy import configured_providers, select_quote
from app.integrations.payment import RazorpayClient

router = APIRouter(prefix="/marketplace/orders", tags=["orders"])
logger = logging.getLogger(__name__)


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


async def release_inventory(db: AsyncSession, order: Order, items: list[OrderItem]) -> None:
    """The caller holds the order lock; return reserved sale units once."""
    if order.inventory_released or order.is_prelaunch_interest:
        return
    for item in sorted(items, key=lambda line: str(line.product_id)):
        inventory = (await db.execute(select(ProductInventory).where(
            ProductInventory.product_id == item.product_id).with_for_update())).scalar_one_or_none()
        if inventory:
            inventory.available_quantity += item.quantity
    order.inventory_released = True
    await db.flush()


async def detail(db, order):
    items = await _items(db, order.id)
    data = serialize(order, items)
    stages = {i.fulfillment_status for i in items}
    if is_fulfillable(order) and len(stages) == 1:
        data['status'] = next(iter(stages)).value
    contact = await db.get(OrderContact, order.id)
    events = list((await db.execute(select(OrderEvent).where(OrderEvent.order_id == order.id).order_by(OrderEvent.created_at, OrderEvent.id))).scalars())
    data['cancellation_status'] = cancellation_status(events)
    data['cancellation_reason'] = next(
        (entry.remarks for entry in reversed(events) if entry.status == 'CANCEL_REQUESTED'), None
    )
    data['payment_method'] = contact.payment_method if contact else 'not specified'
    data['carrier'] = contact.carrier if contact else ''
    data['tracking_number'] = contact.tracking_number if contact else ''
    data['timeline'] = [{'time': e.created_at.isoformat() + 'Z', 'title': e.title, 'status': e.status, 'remarks': e.remarks, 'location': ''} for e in events]
    shipment = (await db.execute(select(Shipment).where(Shipment.order_id == order.id))).scalar_one_or_none()
    data['shipment'] = shipment_data(shipment)
    if shipment:
        scans = (await db.execute(select(ShipmentEvent).where(ShipmentEvent.shipment_id == shipment.id).order_by(ShipmentEvent.occurred_at))).scalars()
        data['timeline'].extend({'time': scan.occurred_at.isoformat() + 'Z', 'title': scan.description,
                                 'status': scan.status, 'remarks': scan.location, 'location': scan.location} for scan in scans)
        data['timeline'].sort(key=lambda item: item['time'])
    return data


def cancellation_status(events: list[OrderEvent]) -> str | None:
    state = None
    for entry in events:
        if entry.status == 'CANCEL_REQUESTED':
            state = 'REQUESTED'
        elif entry.status == 'CANCEL_REJECTED':
            state = 'REJECTED'
        elif entry.status == 'REFUNDED' and state == 'REQUESTED':
            state = 'COMPLETED'
    return state


async def request_paid_cancellation(db: AsyncSession, order: Order, reason: str) -> None:
    events = list((await db.execute(select(OrderEvent).where(OrderEvent.order_id == order.id)
                                    .order_by(OrderEvent.created_at, OrderEvent.id))).scalars())
    if cancellation_status(events) == 'REQUESTED':
        return
    event(db, order, 'Cancellation and refund requested', 'CANCEL_REQUESTED', reason)
    await db.flush()


def event(db, order, title, state, remarks=''):
    db.add(OrderEvent(order_id=order.id, title=title, status=state, remarks=remarks))
    db.add(Notification(user_id=order.user_id, type=NotificationType.general, title=title,
                        body=remarks or title, data={'order_id': str(order.id)}))


def is_fulfillable(order: Order) -> bool:
    return (
        not order.is_prelaunch_interest and order.status != OrderStatus.cancelled
        and (order.payment_status == PaymentStatus.paid
             or (order.is_cod and order.status == OrderStatus.confirmed and order.payment_status == PaymentStatus.pending))
    )


async def checkout_price(db: AsyncSession, user: User, data: CheckoutPricingInput, *, lock: bool):
    """Use the same stock, coverage, courier and coupon rules for quote and purchase."""
    address = (await db.execute(select(DeliveryAddress).where(
        DeliveryAddress.id == data.delivery_address_id,
        DeliveryAddress.user_id == user.id,
    ))).scalar_one_or_none()
    if not address:
        raise HTTPException(404, "Delivery address not found")
    if not settings.PRELAUNCH_MODE:
        if data.payment_method == 'wallet':
            raise HTTPException(422, "Wallet payment is not available for commercial orders")
        if data.payment_method != 'cod' and (not settings.RAZORPAY_KEY_ID or not settings.RAZORPAY_KEY_SECRET):
            raise HTTPException(503, "Online checkout is not configured yet")
    cart = await cart_repo.get_or_create_active_cart(db, user.id)
    cart_items = await cart_repo.items(db, cart.id)
    if not cart_items:
        raise HTTPException(422, "Cart is empty")
    lines: list[tuple[CartItem, Product, ProductInventory]] = []
    subtotal = Decimal("0")
    for cart_item in cart_items:
        product_query = select(Product).where(Product.id == cart_item.product_id, Product.is_active.is_(True))
        inventory_query = select(ProductInventory).where(ProductInventory.product_id == cart_item.product_id)
        if lock:
            product_query = product_query.with_for_update()
            inventory_query = inventory_query.with_for_update()
        product = (await db.execute(product_query)).scalar_one_or_none()
        inventory = (await db.execute(inventory_query)).scalar_one_or_none()
        if not await purchase_enabled(db, product) or not inventory or cart_item.quantity < product.min_order_quantity or cart_item.quantity > inventory.available_quantity - inventory.reserved_quantity:
            raise HTTPException(422, "Cart changed; review price and stock before checkout")
        subtotal += product.base_price * cart_item.quantity
        lines.append((cart_item, product, inventory))
    postal_code = (address.postal_code or "").strip()
    pincode_row = (await db.execute(select(ServiceablePincode).where(ServiceablePincode.pincode == postal_code))).scalar_one_or_none()
    delivery_fee = Decimal("0")
    if pincode_row and pincode_row.delivery_fee:
        delivery_fee = Decimal(str(pincode_row.delivery_fee))
    courier_quote = None
    if not settings.PRELAUNCH_MODE and settings.SHIPPING_AUTO_BOOK_ENABLED:
        providers = configured_providers()
        if providers:
            weights_known = all(product.weight_grams and product.weight_grams > 0 for _, product, _ in lines)
            if weights_known:
                grams = sum(product.weight_grams * cart_item.quantity for cart_item, product, _ in lines) + settings.SHIPPING_PACKAGING_TARE_GRAMS
                options = []
                for provider in providers:
                    offer = await provider.quote(postal_code, grams, data.payment_method == 'cod')
                    if offer:
                        options.append((provider, offer))
                selected = select_quote(options)
                courier_quote = selected[1] if selected else None
                if selected:
                    delivery_fee = courier_quote.cost
    if not settings.PRELAUNCH_MODE and not courier_quote and (not pincode_row or not pincode_row.is_serviceable):
        raise HTTPException(422, f"Delivery is not currently available for pincode {postal_code}")

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
        coupon, discount = await validate_coupon(db, data.coupon_code, subtotal, lock=lock, vendor_subtotal=vendor_subtotal, has_vendor_items=has_vendor_items)
    return address, cart_items, lines, subtotal, delivery_fee, coupon, discount


@router.get("/payment-capabilities")
async def payment_capabilities(current_user: User = Depends(get_current_user)) -> dict:
    return {"success": True, "data": {
        "is_prelaunch_interest": settings.PRELAUNCH_MODE,
        "online_payment_available": bool(settings.RAZORPAY_KEY_ID and settings.RAZORPAY_KEY_SECRET),
    }}


@router.post("/checkout/quote")
async def quote_checkout(data: CheckoutPricingInput, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    _, _, _, subtotal, delivery_fee, coupon, discount = await checkout_price(db, current_user, data, lock=False)
    return {"success": True, "data": {
        "subtotal": str(subtotal), "delivery_fee": str(delivery_fee),
        "discount": str(discount), "total": str(subtotal - discount + delivery_fee),
        "coupon_code": coupon.code if coupon else None,
        "is_prelaunch_interest": settings.PRELAUNCH_MODE,
    }}


@router.post("/checkout", status_code=status.HTTP_201_CREATED)
async def checkout(data: CheckoutRequest, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    existing = (await db.execute(select(Order).where(Order.user_id == current_user.id, Order.idempotency_key == data.idempotency_key))).scalar_one_or_none()
    if existing:
        return {"success": True, "data": await detail(db, existing), "message": "Existing order returned"}
    address, cart_items, lines, subtotal, delivery_fee, coupon, discount = await checkout_price(db, current_user, data, lock=True)
    total = subtotal - discount + delivery_fee
    if data.expected_total is not None and data.expected_total != total:
        raise HTTPException(409, "Checkout total changed; refresh the quote before ordering")
    order = Order(user_id=current_user.id, idempotency_key=data.idempotency_key,
                  is_prelaunch_interest=settings.PRELAUNCH_MODE,
                  is_cod=not settings.PRELAUNCH_MODE and data.payment_method == 'cod',
                  status=OrderStatus.confirmed if not settings.PRELAUNCH_MODE and data.payment_method == 'cod' else OrderStatus.pending_payment,
                  address_snapshot=serialize_address(address), subtotal=subtotal,
                  delivery_fee=delivery_fee, total=total)
    db.add(order)
    await db.flush()
    db.add(OrderContact(order_id=order.id, payment_method=data.payment_method))
    event(db, order, 'Purchase interest recorded' if order.is_prelaunch_interest else 'COD order confirmed' if order.is_cod else 'Order received', order.status.value,
          'No payment was taken. We will contact you before launch.' if order.is_prelaunch_interest else 'Collect payment on delivery' if order.is_cod else 'Online payment pending')
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
        else "COD order confirmed" if order.is_cod else "Order created; online payment is pending"
    )
    return {"success": True, "data": await detail(db, order), "message": message}


async def verify_checkout_payment(db: AsyncSession, order: Order, contact: OrderContact,
                                  *, provider_link: dict | None = None) -> bool:
    """Only a full, provider-confirmed payment may release an online order."""
    if not contact.payment_link_id or order.is_prelaunch_interest or order.is_cod:
        raise HTTPException(409, "This order has no online payment link")
    link = provider_link if provider_link is not None else await RazorpayClient.fetch_checkout_link(contact.payment_link_id)
    if link is None:
        raise HTTPException(503, "Payment provider verification is temporarily unavailable")
    amount = int(order.total * 100)
    if (link.get("id") != contact.payment_link_id or link.get("reference_id") != contact.payment_link_reference
            or link.get("currency") != "INR" or link.get("amount") != amount):
        raise HTTPException(409, "Payment provider details do not match this order")
    if link.get("status") != "paid" or link.get("amount_paid") != amount:
        return False
    payments = link.get("payments") or []
    payment_id = str(payments[0].get("payment_id") or "") if payments else ""
    if not payment_id.startswith("pay_"):
        raise HTTPException(503, "Captured payment reference is not available yet")
    if order.payment_status == PaymentStatus.refunded:
        return True
    if order.status == OrderStatus.cancelled:
        raise HTTPException(409, "Payment arrived for a cancelled order; staff must reconcile it")
    if order.payment_status != PaymentStatus.paid:
        order.payment_status, order.status = PaymentStatus.paid, OrderStatus.confirmed
        contact.payment_reference = payment_id
        event(db, order, "Online payment confirmed", "PAID", f"Provider link {contact.payment_link_id}")
        await db.flush()
    return True


async def require_verified_refund(db: AsyncSession, order: Order, refund_reference: str) -> None:
    contact = await db.get(OrderContact, order.id)
    if not contact or not contact.payment_link_id:
        return  # Legacy/offline payment: staff records the external refund reference.
    refund = await RazorpayClient.fetch_checkout_refund(refund_reference.strip())
    if refund is None:
        raise HTTPException(503, "Verify the Razorpay refund reference before marking this order refunded")
    if (refund.get('id') != refund_reference.strip() or refund.get('payment_id') != contact.payment_reference
            or refund.get('currency') != 'INR' or refund.get('amount') != int(order.total * 100)
            or refund.get('status') != 'processed'):
        raise HTTPException(409, "A processed full refund for this payment is required")


@router.post('/{order_id}/payment-link')
async def checkout_payment_link(order_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    order = (await db.execute(select(Order).where(Order.id == order_id, Order.user_id == user.id).with_for_update())).scalar_one_or_none()
    if not order:
        raise HTTPException(404, "Order not found")
    contact = await db.get(OrderContact, order.id)
    if (order.is_prelaunch_interest or order.is_cod or order.status == OrderStatus.cancelled
            or not contact or contact.payment_method not in {'upi', 'card', 'netbanking'}):
        raise HTTPException(409, "Online payment is unavailable for this order")
    if not settings.RAZORPAY_KEY_ID or not settings.RAZORPAY_KEY_SECRET:
        raise HTTPException(503, "Online checkout is not configured yet")
    if contact.payment_link_id:
        link_state = await RazorpayClient.fetch_checkout_link(contact.payment_link_id)
        if link_state is None:
            raise HTTPException(503, 'Payment provider is temporarily unavailable; retry the same order later')
        if (link_state.get('id') != contact.payment_link_id
                or link_state.get('reference_id') != contact.payment_link_reference
                or link_state.get('currency') != 'INR'
                or link_state.get('amount') != int(order.total * 100)):
            raise HTTPException(409, 'Payment provider details do not match this order')
        state = str(link_state.get('status') or '').lower()
        if state == 'paid':
            if not await verify_checkout_payment(db, order, contact, provider_link=link_state):
                raise HTTPException(409, 'The payment link is paid but the confirmed amount does not match this order')
            return {'success': True, 'data': {'url': contact.payment_link_url or '', 'payment_status': order.payment_status.value}}
        if state in {'expired', 'cancelled'}:
            contact.payment_link_id = None
            contact.payment_link_reference = None
            contact.payment_link_url = None
        elif state == 'created' and contact.payment_link_url:
            return {'success': True, 'data': {'url': contact.payment_link_url, 'payment_status': order.payment_status.value}}
        else:
            raise HTTPException(409, 'This payment link is not available for another payment attempt')
    if order.payment_status != PaymentStatus.pending:
        raise HTTPException(409, "This order no longer needs payment")
    snapshot = order.address_snapshot
    link_reference = order.id.hex + uuid.uuid4().hex[:8]
    link = await RazorpayClient.create_checkout_link(
        int(order.total * 100), link_reference,
        str(snapshot.get('recipient_name') or user.phone),
        str(snapshot.get('phone') or user.phone),
    )
    payment_url = str(link.get('short_url') or '') if link else ''
    parsed_url = urlparse(payment_url)
    if (not link or not str(link.get('id') or '').startswith('plink_')
            or link.get('reference_id') != link_reference or link.get('currency') != 'INR'
            or link.get('amount') != int(order.total * 100)
            or parsed_url.scheme != 'https' or parsed_url.hostname not in {'rzp.io', 'razorpay.com', 'www.razorpay.com'}):
        raise HTTPException(503, "Payment link could not be created; please retry from your order")
    contact.payment_link_id, contact.payment_link_reference, contact.payment_link_url = str(link['id']), link_reference, payment_url
    await db.commit()
    return {'success': True, 'data': {'url': contact.payment_link_url, 'payment_status': order.payment_status.value}}


@router.post('/{order_id}/payment/verify')
async def customer_verify_payment(order_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    order = (await db.execute(select(Order).where(Order.id == order_id, Order.user_id == user.id).with_for_update())).scalar_one_or_none()
    if not order:
        raise HTTPException(404, "Order not found")
    contact = await db.get(OrderContact, order.id)
    confirmed = await verify_checkout_payment(db, order, contact) if contact else False
    return {'success': True, 'data': {'confirmed': confirmed, 'payment_status': order.payment_status.value}}


@router.post('/webhooks/razorpay')
async def razorpay_checkout_webhook(request: Request, db: AsyncSession = Depends(get_db)):
    secret = settings.RAZORPAY_WEBHOOK_SECRET
    if not secret:
        raise HTTPException(503, "Payment webhook is not configured")
    body = await request.body()
    signature = request.headers.get('X-Razorpay-Signature', '')
    expected = hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
    if not hmac.compare_digest(expected, signature):
        raise HTTPException(401, "Invalid payment webhook signature")
    try:
        payload = json.loads(body)
        if payload.get('event') != 'payment_link.paid':
            return {'success': True}
        link_id = payload['payload']['payment_link']['entity']['id']
    except (ValueError, TypeError, KeyError):
        raise HTTPException(422, "Malformed payment webhook")
    contact = (await db.execute(select(OrderContact).where(OrderContact.payment_link_id == str(link_id)))).scalar_one_or_none()
    if not contact:
        return {'success': True}
    order = (await db.execute(select(Order).where(Order.id == contact.order_id).with_for_update())).scalar_one()
    await verify_checkout_payment(db, order, contact)
    return {'success': True}


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
        .where(OrderItem.vendor_id == vendor.id,
               or_(Order.payment_status == PaymentStatus.paid,
                   (Order.is_cod.is_(True) & (Order.status == OrderStatus.confirmed) & (Order.payment_status == PaymentStatus.pending))),
               Order.is_prelaunch_interest.is_(False), Order.status != OrderStatus.cancelled)
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
    order = (await db.execute(select(Order).where(Order.id == item.order_id).with_for_update())).scalar_one()
    if not is_fulfillable(order):
        raise HTTPException(422, "Online payment or COD order confirmation is required before fulfillment")
    if await cancellation_request_pending(db, order.id):
        raise HTTPException(409, 'Resolve the cancellation request before fulfilling this order')
    if fulfillment_status in {FulfillmentStatus.shipped, FulfillmentStatus.delivered}:
        raise HTTPException(409, "Record dispatch with the actual courier and AWB in order operations")
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
    query = select(Order).where(
        or_(Order.payment_status == PaymentStatus.paid,
            (Order.is_cod.is_(True) & (Order.status == OrderStatus.confirmed) & (Order.payment_status == PaymentStatus.pending))),
        Order.is_prelaunch_interest.is_(False), Order.status != OrderStatus.cancelled)
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
    if not is_fulfillable(order):
        raise HTTPException(409, 'Only paid online or confirmed COD orders can be fulfilled')
    if await cancellation_request_pending(db, order.id):
        raise HTTPException(409, 'Resolve the cancellation request before fulfilling this order')
    target = FulfillmentStatus.shipped if data.status in ('DISPATCHED', 'OUT_FOR_DELIVERY') else FulfillmentStatus(data.status)
    allowed = {FulfillmentStatus.pending: FulfillmentStatus.confirmed, FulfillmentStatus.confirmed: FulfillmentStatus.packed, FulfillmentStatus.packed: FulfillmentStatus.shipped, FulfillmentStatus.shipped: FulfillmentStatus.delivered}
    if any(i.fulfillment_status != target and allowed.get(i.fulfillment_status) != target for i in items):
        raise HTTPException(422, 'Invalid fulfillment transition')
    contact = await db.get(OrderContact, order.id)
    if not contact:
        contact = OrderContact(order_id=order.id)
        db.add(contact)
    if data.status == 'OUT_FOR_DELIVERY' and (not contact.carrier or not contact.tracking_number):
        raise HTTPException(422, 'Record the actual courier and AWB before marking out for delivery')
    if all(i.fulfillment_status == target for i in items):
        if target == FulfillmentStatus.shipped and data.status != 'OUT_FOR_DELIVERY' and (data.carrier.strip(), data.tracking_number.strip()) != (contact.carrier, contact.tracking_number):
            raise HTTPException(409, 'This order already has a different courier reference')
        if data.status != 'OUT_FOR_DELIVERY' or (await db.execute(select(OrderEvent.id).where(OrderEvent.order_id == order.id, OrderEvent.status == 'OUT_FOR_DELIVERY'))).first():
            return {'success': True, 'data': {'id': str(order.id), 'fulfillment_status': target.value}}
    if target == FulfillmentStatus.shipped and data.status != 'OUT_FOR_DELIVERY':
        if not data.carrier.strip() or not data.tracking_number.strip():
            raise HTTPException(422, 'Enter the actual courier and tracking reference')
        # Per-seller shipment metadata must not overwrite another seller's shipment.
        if len({i.vendor_id for i in await _items(db, order.id)}) > 1:
            raise HTTPException(409, 'Multi-seller shipment tracking requires separate shipment records')
        await record_manual_dispatch(db, order, data.carrier.strip(), data.tracking_number.strip())
        contact.carrier, contact.tracking_number = data.carrier.strip(), data.tracking_number.strip()
    for item in items:
        item.fulfillment_status = target
    await record_manual_milestone(db, order.id, data.status, data.location, data.remarks)
    if target == FulfillmentStatus.packed:
        all_items = await _items(db, order.id)
        if all(item.fulfillment_status == FulfillmentStatus.packed for item in all_items) and len({item.vendor_id for item in all_items}) == 1:
            await prepare_shipment(db, order, all_items)
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
    if any(i.fulfillment_status not in (FulfillmentStatus.pending, FulfillmentStatus.confirmed) for i in items):
        raise HTTPException(409, 'Shipped or delivered orders require support assistance')
    if order.payment_status == PaymentStatus.paid:
        await request_paid_cancellation(db, order, data.reason)
        return {'success': True, 'data': await detail(db, order),
                'message': 'Cancellation requested; the order remains paid until its refund is verified'}
    contact = await db.get(OrderContact, order.id)
    if contact and contact.payment_link_id:
        link_state = await RazorpayClient.fetch_checkout_link(contact.payment_link_id)
        if link_state:
            state = str(link_state.get('status') or '').lower()
            if state == 'paid':
                if not await verify_checkout_payment(db, order, contact, provider_link=link_state):
                    raise HTTPException(409, 'The payment link is paid but the confirmed amount does not match this order')
                await request_paid_cancellation(db, order, data.reason)
                return {'success': True, 'data': await detail(db, order),
                        'message': 'Payment confirmed; cancellation and refund review requested'}
            elif state in {'expired', 'cancelled'}:
                pass
            elif state == 'created':
                if not await RazorpayClient.cancel_checkout_link(contact.payment_link_id):
                    raise HTTPException(409, 'Payment link could not be cancelled; verify the payment before cancelling')
            else:
                raise HTTPException(409, 'Payment is still processing; check its status before cancelling')
        else:
            if not await RazorpayClient.cancel_checkout_link(contact.payment_link_id):
                raise HTTPException(409, 'Payment link could not be cancelled; verify the payment before cancelling')
    await stop_shipment_for_refund(db, order)
    await release_inventory(db, order, items)
    for item in items:
        item.fulfillment_status = FulfillmentStatus.cancelled
    order.status = OrderStatus.cancelled
    event(db, order, 'Purchase interest withdrawn' if order.is_prelaunch_interest else 'Order cancelled', 'CANCELLED', data.reason)
    await db.flush()
    return {'success': True, 'data': await detail(db, order)}


async def expire_unpaid_order_once(order_id: uuid.UUID | None = None) -> bool:
    """Close one abandoned online order after confirming it cannot still be paid."""
    cutoff = datetime.utcnow() - timedelta(hours=settings.COMMERCE_UNPAID_ORDER_TTL_HOURS)
    async with async_session_factory() as db:
        query = select(Order).where(
            Order.is_prelaunch_interest.is_(False), Order.is_cod.is_(False),
            Order.status == OrderStatus.pending_payment,
            Order.payment_status == PaymentStatus.pending,
            Order.created_at < cutoff,
        )
        if order_id is not None:
            query = query.where(Order.id == order_id)
        order = (await db.execute(query.order_by(Order.created_at)
                                  .with_for_update(skip_locked=True).limit(1))).scalar_one_or_none()
        if order is None:
            return False
        contact = await db.get(OrderContact, order.id)
        if contact and contact.payment_link_id:
            link = await RazorpayClient.fetch_checkout_link(contact.payment_link_id)
            if link is None:
                return False
            if (link.get('id') != contact.payment_link_id
                    or link.get('reference_id') != contact.payment_link_reference
                    or link.get('currency') != 'INR'
                    or link.get('amount') != int(order.total * 100)):
                logger.error('Payment link mismatch while expiring order %s', order.id)
                return False
            state = str(link.get('status') or '').lower()
            if state == 'paid':
                if await verify_checkout_payment(db, order, contact, provider_link=link):
                    await db.commit()
                    return True
                return False
            if state == 'created':
                if not await RazorpayClient.cancel_checkout_link(contact.payment_link_id):
                    return False
            elif state not in {'expired', 'cancelled'}:
                return False
        items = await _items(db, order.id)
        await stop_shipment_for_refund(db, order)
        await release_inventory(db, order, items)
        for item in items:
            item.fulfillment_status = FulfillmentStatus.cancelled
        order.status = OrderStatus.cancelled
        event(db, order, 'Unpaid order expired', 'CANCELLED',
              'No payment was confirmed before the payment deadline')
        await db.commit()
        return True


async def unpaid_order_expiry_loop() -> None:
    while True:
        try:
            cutoff = datetime.utcnow() - timedelta(hours=settings.COMMERCE_UNPAID_ORDER_TTL_HOURS)
            async with async_session_factory() as db:
                order_ids = list((await db.execute(select(Order.id).where(
                    Order.is_prelaunch_interest.is_(False), Order.is_cod.is_(False),
                    Order.status == OrderStatus.pending_payment,
                    Order.payment_status == PaymentStatus.pending,
                    Order.created_at < cutoff,
                ).order_by(Order.created_at).limit(50))).scalars())
            for order_id in order_ids:
                try:
                    await expire_unpaid_order_once(order_id)
                except Exception:
                    logger.exception('Unable to reconcile expired online order %s', order_id)
        except Exception:
            logger.exception('Unable to reconcile an expired online order')
        await asyncio.sleep(60)


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
        if d['cancellation_status'] not in {'REQUESTED', 'COMPLETED'} and order.payment_status != PaymentStatus.refunded:
            continue
        d['customer_phone'] = phone
        contact = await db.get(OrderContact, order.id)
        d['notes'] = contact.notes if contact else ''
        results.append(d)
    return {'success': True, 'data': results}


class CodSettlementRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')
    remittance_reference: str = Field(min_length=3, max_length=100)


@router.post('/admin/cod/{order_id}/collect')
async def confirm_cod_collection(order_id: uuid.UUID, data: CodSettlementRequest,
    user: User = Depends(require_role(UserRole.admin, UserRole.super_admin)), db: AsyncSession = Depends(get_db)):
    order = (await db.execute(select(Order).where(Order.id == order_id).with_for_update())).scalar_one_or_none()
    if not order:
        raise HTTPException(404, 'Order not found')
    if not order.is_cod or order.is_prelaunch_interest or order.status != OrderStatus.confirmed:
        raise HTTPException(409, 'A confirmed COD order is required')
    contact = await db.get(OrderContact, order.id)
    if order.payment_status == PaymentStatus.paid:
        if contact and contact.payment_reference == data.remittance_reference.strip():
            return {'success': True, 'data': await detail(db, order)}
        raise HTTPException(409, 'COD has already been settled with another reference')
    if order.payment_status != PaymentStatus.pending or not all(
        item.fulfillment_status == FulfillmentStatus.delivered for item in await _items(db, order.id)
    ):
        raise HTTPException(409, 'Record courier delivery before COD remittance')
    order.payment_status = PaymentStatus.paid
    contact.payment_reference = data.remittance_reference.strip()
    event(db, order, 'COD remittance recorded', 'PAID', f'Remittance {contact.payment_reference}')
    audit(db, user, 'order.cod_collected', 'order', order.id, data.model_dump_json())
    await db.flush()
    return {'success': True, 'data': await detail(db, order)}


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
        if order.payment_status != PaymentStatus.paid or order.is_prelaunch_interest:
            raise HTTPException(409, 'Only a paid commercial order can be refunded')
        await require_verified_refund(db, order, data.refund_reference)
        await stop_shipment_for_refund(db, order)
        if data.restock_inventory:
            await release_inventory(db, order, items)
        order.payment_status = PaymentStatus.refunded
        order.status = OrderStatus.cancelled
        for item in items:
            item.fulfillment_status = FulfillmentStatus.cancelled
        event(db, order, f'Refund processed: ₹{order.total}', 'REFUNDED', f'Ref: {data.refund_reference} · {data.remarks}'.strip(' ·'))
        audit(db, user, 'order.refund_approved', 'order', order.id, data.model_dump_json())
    else:
        events = list((await db.execute(select(OrderEvent).where(OrderEvent.order_id == order.id)
                                        .order_by(OrderEvent.created_at, OrderEvent.id))).scalars())
        if cancellation_status(events) != 'REQUESTED':
            raise HTTPException(409, 'No pending cancellation request exists')
        event(db, order, 'Cancellation request rejected', 'CANCEL_REJECTED', data.remarks)
        audit(db, user, 'order.refund_rejected', 'order', order.id, data.model_dump_json())
    await db.flush()
    return {'success': True, 'data': await detail(db, order),
            'message': 'Refund recorded' if data.action == 'approve' else 'Cancellation request rejected'}


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
        if order.payment_status != PaymentStatus.paid or order.is_prelaunch_interest:
            raise HTTPException(409, 'Only a paid commercial order can be refunded')
        await require_verified_refund(db, order, data.refund_reference)
        await stop_shipment_for_refund(db, order, returned=True)
        if data.restock_inventory:
            await release_inventory(db, order, items)
        order.return_status = 'RETURN_COMPLETED'
        order.payment_status = PaymentStatus.refunded
        for item in items:
            item.fulfillment_status = FulfillmentStatus.cancelled
        event(db, order, f'Item inspected & return refund issued: ₹{order.total}', 'REFUNDED', f'Ref: {data.refund_reference} · {data.remarks}'.strip(' ·'))
        audit(db, user, 'order.return_refunded', 'order', order.id, data.model_dump_json())
    elif data.action == 'mark_rto':
        if order.return_status == 'RTO_DELIVERED' or order.status == OrderStatus.cancelled:
            raise HTTPException(400, 'Order RTO has already been processed')
        await stop_shipment_for_refund(db, order, returned=True)
        if data.restock_inventory:
            await release_inventory(db, order, items)
        order.return_status = 'RTO_DELIVERED'
        order.status = OrderStatus.cancelled
        event(db, order, 'Package returned to origin (RTO)', 'RTO_DELIVERED', data.remarks)
        audit(db, user, 'order.rto_processed', 'order', order.id, data.model_dump_json())
    else:
        order.return_status = 'RETURN_REJECTED'
        event(db, order, 'Return request rejected', 'RETURN_REJECTED', data.remarks)
        audit(db, user, 'order.return_rejected', 'order', order.id, data.model_dump_json())

    await db.flush()
    return {'success': True, 'data': await detail(db, order), 'message': f'Return status updated to {order.return_status}'}
