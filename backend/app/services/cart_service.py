import uuid
from decimal import Decimal

from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.cart import Cart, CartItem
from app.models.product import Product, ProductInventory
from app.repositories import cart_repo, product_repo, vendor_repo


def _available(inventory: ProductInventory | None) -> int:
    return max(0, inventory.available_quantity - inventory.reserved_quantity) if inventory else 0


async def _product_or_error(db: AsyncSession, product_id: uuid.UUID) -> tuple[Product, ProductInventory | None]:
    product = await product_repo.get(db, product_id)
    if product is None or not product.is_active:
        raise HTTPException(404, "Product unavailable")
    return product, await product_repo.inventory(db, product_id)


def _check_quantity(product: Product, inventory: ProductInventory | None, quantity: int) -> None:
    if quantity < product.min_order_quantity:
        raise HTTPException(422, f"Minimum order quantity is {product.min_order_quantity}")
    if inventory is None:
        raise HTTPException(422, "Product inventory is unavailable")
    if _available(inventory) == 0:
        raise HTTPException(422, "Product is out of stock")
    if quantity > _available(inventory):
        raise HTTPException(422, f"Only {_available(inventory)} units are available")


async def add_item(db: AsyncSession, user_id: uuid.UUID, product_id: uuid.UUID, quantity: int) -> CartItem:
    product, inventory = await _product_or_error(db, product_id)
    cart = await cart_repo.get_or_create_active_cart(db, user_id)
    item = await cart_repo.item_for_product(db, cart.id, product_id)
    target_quantity = quantity + (item.quantity if item else 0)
    _check_quantity(product, inventory, target_quantity)
    if item is None:
        item = CartItem(cart_id=cart.id, product_id=product_id, quantity=quantity, price_when_added=product.base_price)
        db.add(item)
    else:
        item.quantity = target_quantity
    await db.flush()
    return item


async def update_item(db: AsyncSession, user_id: uuid.UUID, item_id: uuid.UUID, quantity: int) -> CartItem:
    cart = await cart_repo.get_or_create_active_cart(db, user_id)
    item = await cart_repo.item_for_cart(db, cart.id, item_id)
    if item is None:
        raise HTTPException(404, "Cart item not found")
    product, inventory = await _product_or_error(db, item.product_id)
    _check_quantity(product, inventory, quantity)
    item.quantity = quantity
    await db.flush()
    return item


async def remove_item(db: AsyncSession, user_id: uuid.UUID, item_id: uuid.UUID) -> None:
    cart = await cart_repo.get_or_create_active_cart(db, user_id)
    item = await cart_repo.item_for_cart(db, cart.id, item_id)
    if item is None:
        raise HTTPException(404, "Cart item not found")
    await db.delete(item)
    await db.flush()


async def clear(db: AsyncSession, user_id: uuid.UUID) -> None:
    cart = await cart_repo.get_or_create_active_cart(db, user_id)
    for item in await cart_repo.items(db, cart.id):
        await db.delete(item)
    await db.flush()


async def item_data(db: AsyncSession, item: CartItem) -> dict:
    product = await product_repo.get(db, item.product_id)
    inventory = await product_repo.inventory(db, item.product_id) if product else None
    current_price = product.base_price if product else None
    available = _available(inventory)
    media = await product_repo.media(db, item.product_id) if product else []
    vendor = await vendor_repo.get_by_id(db, product.vendor_id) if product else None
    return {
        "id": str(item.id), "product_id": str(item.product_id), "title": product.title if product else "Product no longer available",
        "category": product.category.value if product else None, "vendor_id": str(product.vendor_id) if product else None,
        "vendor_name": vendor.business_name if vendor else None, "primary_image": next((x.url for x in media if x.is_primary), media[0].url if media else None),
        "quantity": item.quantity, "unit": product.unit if product else None, "price_when_added": str(item.price_when_added),
        "current_price": str(current_price) if current_price is not None else None,
        "price_changed": current_price is not None and current_price != item.price_when_added,
        "available_quantity": available, "in_stock": bool(product and product.is_active and available >= item.quantity),
        "line_total": str((current_price or Decimal("0")) * item.quantity),
    }


async def cart_data(db: AsyncSession, user_id: uuid.UUID) -> dict:
    cart = await cart_repo.get_or_create_active_cart(db, user_id)
    data = [await item_data(db, item) for item in await cart_repo.items(db, cart.id)]
    subtotal = sum((Decimal(x["line_total"]) for x in data), Decimal("0"))
    return {"id": str(cart.id), "item_count": sum(x["quantity"] for x in data), "subtotal": str(subtotal), "items": data}


async def validate(db: AsyncSession, user_id: uuid.UUID) -> dict:
    cart = await cart_repo.get_or_create_active_cart(db, user_id)
    issues: list[dict] = []
    for item in await cart_repo.items(db, cart.id):
        product = await product_repo.get(db, item.product_id)
        inventory = await product_repo.inventory(db, item.product_id) if product else None
        base = {"cart_item_id": str(item.id), "product_id": str(item.product_id)}
        if product is None:
            issues.append(base | {"type": "PRODUCT_NOT_FOUND", "message": "Product no longer exists"})
        elif not product.is_active:
            issues.append(base | {"type": "PRODUCT_INACTIVE", "message": "Product is inactive"})
        elif inventory is None:
            issues.append(base | {"type": "INVENTORY_MISSING", "message": "Product inventory is unavailable"})
        elif _available(inventory) == 0:
            issues.append(base | {"type": "ZERO_STOCK", "message": "Product is out of stock"})
        elif item.quantity > _available(inventory):
            issues.append(base | {"type": "INSUFFICIENT_STOCK", "message": "Insufficient stock", "available_quantity": _available(inventory)})
        elif item.quantity < product.min_order_quantity:
            issues.append(base | {"type": "BELOW_MINIMUM_QUANTITY", "message": f"Minimum order quantity is {product.min_order_quantity}"})
        if product is not None and product.base_price != item.price_when_added:
            issues.append(base | {"type": "PRICE_CHANGED", "message": "Product price changed", "old_price": str(item.price_when_added), "current_price": str(product.base_price)})
    return {"valid": not issues, "issues": issues}
