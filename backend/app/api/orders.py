import uuid
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user, require_role
from app.models.cart import CartItem
from app.models.delivery_address import DeliveryAddress
from app.models.order import Order, OrderItem, FulfillmentStatus, PaymentStatus
from app.models.product import Product, ProductInventory
from app.models.user import User, UserRole
from app.repositories import vendor_repo
from app.repositories import cart_repo
from app.schemas.order import CheckoutRequest
from app.services.delivery_address_service import serialize as serialize_address

router = APIRouter(prefix="/marketplace/orders", tags=["orders"])


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
