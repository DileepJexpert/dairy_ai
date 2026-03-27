import uuid
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.farmer import Farmer


async def get_by_user_id(db: AsyncSession, user_id: uuid.UUID) -> Farmer | None:
    result = await db.execute(select(Farmer).where(Farmer.user_id == user_id))
    return result.scalar_one_or_none()


async def get_by_id(db: AsyncSession, farmer_id: uuid.UUID) -> Farmer | None:
    result = await db.execute(select(Farmer).where(Farmer.id == farmer_id))
    return result.scalar_one_or_none()


async def create(db: AsyncSession, user_id: uuid.UUID, **kwargs) -> Farmer:
    farmer = Farmer(user_id=user_id, **kwargs)
    db.add(farmer)
    await db.flush()
    return farmer


async def update(db: AsyncSession, farmer: Farmer, **kwargs) -> Farmer:
    for key, value in kwargs.items():
        if value is not None:
            setattr(farmer, key, value)
    await db.flush()
    return farmer


async def list_all(db: AsyncSession, limit: int = 20, offset: int = 0, search: str | None = None):
    query = select(Farmer)
    if search:
        query = query.where(Farmer.name.ilike(f"%{search}%"))
    query = query.offset(offset).limit(limit)
    result = await db.execute(query)
    farmers = result.scalars().all()

    count_query = select(func.count(Farmer.id))
    if search:
        count_query = count_query.where(Farmer.name.ilike(f"%{search}%"))
    total = (await db.execute(count_query)).scalar() or 0

    return farmers, total
