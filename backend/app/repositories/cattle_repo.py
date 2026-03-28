import logging
import uuid
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.cattle import Cattle, CattleStatus

logger = logging.getLogger("dairy_ai.repos.cattle")


async def get_by_id(db: AsyncSession, cattle_id: uuid.UUID) -> Cattle | None:
    logger.debug("Querying cattle by id=%s", cattle_id)
    result = await db.execute(select(Cattle).where(Cattle.id == cattle_id))
    cattle = result.scalar_one_or_none()
    if cattle:
        logger.info("Found cattle id=%s, tag=%s, farmer_id=%s", cattle.id, cattle.tag_id, cattle.farmer_id)
    else:
        logger.info("No cattle found for id=%s", cattle_id)
    return cattle


async def get_by_tag_id(db: AsyncSession, tag_id: str) -> Cattle | None:
    logger.debug("Querying cattle by tag_id=%s", tag_id)
    result = await db.execute(select(Cattle).where(Cattle.tag_id == tag_id))
    cattle = result.scalar_one_or_none()
    if cattle:
        logger.info("Found cattle id=%s for tag_id=%s", cattle.id, tag_id)
    else:
        logger.info("No cattle found for tag_id=%s", tag_id)
    return cattle


async def get_by_farmer(
    db: AsyncSession, farmer_id: uuid.UUID,
    status: str | None = None, breed: str | None = None,
    limit: int = 50, offset: int = 0,
) -> tuple[list[Cattle], int]:
    logger.debug("Querying cattle by farmer_id=%s, status=%s, breed=%s, limit=%d, offset=%d",
                 farmer_id, status, breed, limit, offset)
    query = select(Cattle).where(Cattle.farmer_id == farmer_id)
    count_query = select(func.count(Cattle.id)).where(Cattle.farmer_id == farmer_id)

    if status:
        logger.debug("Applying status filter: %s", status)
        query = query.where(Cattle.status == status)
        count_query = count_query.where(Cattle.status == status)
    if breed:
        logger.debug("Applying breed filter: %s", breed)
        query = query.where(Cattle.breed == breed)
        count_query = count_query.where(Cattle.breed == breed)

    query = query.offset(offset).limit(limit)
    result = await db.execute(query)
    cattle = list(result.scalars().all())
    total = (await db.execute(count_query)).scalar() or 0
    logger.info("Found %d cattle for farmer %s (total matching: %d)", len(cattle), farmer_id, total)
    return cattle, total


async def create(db: AsyncSession, farmer_id: uuid.UUID, **kwargs) -> Cattle:
    logger.info("Creating cattle for farmer_id=%s with fields=%s", farmer_id, list(kwargs.keys()))
    cattle = Cattle(farmer_id=farmer_id, **kwargs)
    db.add(cattle)
    await db.flush()
    logger.info("Created cattle id=%s, tag=%s for farmer %s", cattle.id, cattle.tag_id, farmer_id)
    return cattle


async def update(db: AsyncSession, cattle: Cattle, **kwargs) -> Cattle:
    logger.info("Updating cattle id=%s with fields=%s", cattle.id, {k: v for k, v in kwargs.items() if v is not None})
    for key, value in kwargs.items():
        if value is not None:
            setattr(cattle, key, value)
    await db.flush()
    logger.info("Updated cattle id=%s successfully", cattle.id)
    return cattle


async def delete(db: AsyncSession, cattle: Cattle) -> None:
    logger.warning("Deleting cattle id=%s, tag=%s, farmer_id=%s", cattle.id, cattle.tag_id, cattle.farmer_id)
    await db.delete(cattle)
    await db.flush()
    logger.info("Deleted cattle id=%s successfully", cattle.id)


async def count_by_farmer(db: AsyncSession, farmer_id: uuid.UUID) -> dict:
    """Return counts grouped by status."""
    logger.debug("Counting cattle by status for farmer_id=%s", farmer_id)
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
    logger.info("Cattle counts for farmer %s: %s", farmer_id, counts)
    return counts
