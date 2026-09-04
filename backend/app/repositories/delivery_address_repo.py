import uuid

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.delivery_address import DeliveryAddress


async def list_for_user(db: AsyncSession, user_id: uuid.UUID) -> list[DeliveryAddress]:
    query = select(DeliveryAddress).where(DeliveryAddress.user_id == user_id).order_by(DeliveryAddress.is_default.desc(), DeliveryAddress.created_at.desc())
    return list((await db.execute(query)).scalars())


async def get_for_user(db: AsyncSession, user_id: uuid.UUID, address_id: uuid.UUID) -> DeliveryAddress | None:
    return (await db.execute(select(DeliveryAddress).where(DeliveryAddress.id == address_id, DeliveryAddress.user_id == user_id))).scalar_one_or_none()


async def clear_default(db: AsyncSession, user_id: uuid.UUID) -> None:
    await db.execute(update(DeliveryAddress).where(DeliveryAddress.user_id == user_id, DeliveryAddress.is_default.is_(True)).values(is_default=False))
