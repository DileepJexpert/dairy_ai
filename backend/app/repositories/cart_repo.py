import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.cart import Cart, CartItem, CartStatus


async def get_active_cart(db: AsyncSession, user_id: uuid.UUID) -> Cart | None:
    return (await db.execute(select(Cart).where(Cart.user_id == user_id, Cart.status == CartStatus.active))).scalar_one_or_none()


async def get_or_create_active_cart(db: AsyncSession, user_id: uuid.UUID) -> Cart:
    cart = await get_active_cart(db, user_id)
    if cart is None:
        cart = Cart(user_id=user_id)
        db.add(cart)
        await db.flush()
    return cart


async def items(db: AsyncSession, cart_id: uuid.UUID) -> list[CartItem]:
    return list((await db.execute(select(CartItem).where(CartItem.cart_id == cart_id).order_by(CartItem.created_at))).scalars())


async def item_for_product(db: AsyncSession, cart_id: uuid.UUID, product_id: uuid.UUID) -> CartItem | None:
    return (await db.execute(select(CartItem).where(CartItem.cart_id == cart_id, CartItem.product_id == product_id))).scalar_one_or_none()


async def item_for_cart(db: AsyncSession, cart_id: uuid.UUID, item_id: uuid.UUID) -> CartItem | None:
    return (await db.execute(select(CartItem).where(CartItem.cart_id == cart_id, CartItem.id == item_id))).scalar_one_or_none()
