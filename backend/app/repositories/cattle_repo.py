import uuid
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.cattle import Cattle, CattleStatus


async def get_by_id(db: AsyncSession, cattle_id: uuid.UUID) -> Cattle | None:
    result = await db.execute(select(Cattle).where(Cattle.id == cattle_id))
    return result.scalar_one_or_none()


async def get_by_tag_id(db: AsyncSession, tag_id: str) -> Cattle | None:
    result = await db.execute(select(Cattle).where(Cattle.tag_id == tag_id))
    return result.scalar_one_or_none()


async def get_by_farmer(
    db: AsyncSession, farmer_id: uuid.UUID,
    status: str | None = None, breed: str | None = None,
    limit: int = 50, offset: int = 0,
) -> tuple[list[Cattle], int]:
    query = select(Cattle).where(Cattle.farmer_id == farmer_id)
    count_query = select(func.count(Cattle.id)).where(Cattle.farmer_id == farmer_id)

    if status:
        query = query.where(Cattle.status == status)
        count_query = count_query.where(Cattle.status == status)
    if breed:
        query = query.where(Cattle.breed == breed)
        count_query = count_query.where(Cattle.breed == breed)

    query = query.offset(offset).limit(limit)
    result = await db.execute(query)
    cattle = list(result.scalars().all())
    total = (await db.execute(count_query)).scalar() or 0
    return cattle, total


async def create(db: AsyncSession, farmer_id: uuid.UUID, **kwargs) -> Cattle:
    cattle = Cattle(farmer_id=farmer_id, **kwargs)
    db.add(cattle)
    await db.flush()
    return cattle


async def update(db: AsyncSession, cattle: Cattle, **kwargs) -> Cattle:
    for key, value in kwargs.items():
        if value is not None:
            setattr(cattle, key, value)
    await db.flush()
    return cattle


async def delete(db: AsyncSession, cattle: Cattle) -> None:
    await db.delete(cattle)
    await db.flush()


async def count_by_farmer(db: AsyncSession, farmer_id: uuid.UUID) -> dict:
    """Return counts grouped by status."""
    result = await db.execute(
        select(Cattle.status, func.count(Cattle.id))
        .where(Cattle.farmer_id == farmer_id)
        .group_by(Cattle.status)
    )
    counts = {"total": 0, "active": 0, "dry": 0, "sold": 0, "dead": 0}
    for status, count in result.all():
        status_val = status.value if hasattr(status, 'value') else status
        counts[status_val] = count
        counts["total"] += count
    return counts
