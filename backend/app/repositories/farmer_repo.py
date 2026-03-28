import logging
import uuid
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.farmer import Farmer

logger = logging.getLogger("dairy_ai.repos.farmer")


async def get_by_user_id(db: AsyncSession, user_id: uuid.UUID) -> Farmer | None:
    logger.debug("Querying farmer by user_id=%s", user_id)
    result = await db.execute(select(Farmer).where(Farmer.user_id == user_id))
    farmer = result.scalar_one_or_none()
    if farmer:
        logger.info("Found farmer id=%s for user_id=%s", farmer.id, user_id)
    else:
        logger.info("No farmer found for user_id=%s", user_id)
    return farmer


async def get_by_id(db: AsyncSession, farmer_id: uuid.UUID) -> Farmer | None:
    logger.debug("Querying farmer by id=%s", farmer_id)
    result = await db.execute(select(Farmer).where(Farmer.id == farmer_id))
    farmer = result.scalar_one_or_none()
    if farmer:
        logger.info("Found farmer id=%s, name=%s", farmer.id, farmer.name)
    else:
        logger.info("No farmer found for id=%s", farmer_id)
    return farmer


async def create(db: AsyncSession, user_id: uuid.UUID, **kwargs) -> Farmer:
    logger.info("Creating farmer for user_id=%s with fields=%s", user_id, list(kwargs.keys()))
    farmer = Farmer(user_id=user_id, **kwargs)
    db.add(farmer)
    await db.flush()
    logger.info("Created farmer id=%s for user_id=%s", farmer.id, user_id)
    return farmer


async def update(db: AsyncSession, farmer: Farmer, **kwargs) -> Farmer:
    logger.info("Updating farmer id=%s with fields=%s", farmer.id, {k: v for k, v in kwargs.items() if v is not None})
    for key, value in kwargs.items():
        if value is not None:
            setattr(farmer, key, value)
    await db.flush()
    logger.info("Updated farmer id=%s successfully", farmer.id)
    return farmer


async def list_all(db: AsyncSession, limit: int = 20, offset: int = 0, search: str | None = None):
    logger.debug("Listing farmers: limit=%d, offset=%d, search=%s", limit, offset, search)
    query = select(Farmer)
    if search:
        logger.debug("Applying search filter: name ILIKE '%%%s%%'", search)
        query = query.where(Farmer.name.ilike(f"%{search}%"))
    query = query.offset(offset).limit(limit)
    result = await db.execute(query)
    farmers = result.scalars().all()

    count_query = select(func.count(Farmer.id))
    if search:
        count_query = count_query.where(Farmer.name.ilike(f"%{search}%"))
    total = (await db.execute(count_query)).scalar() or 0

    logger.info("Listed %d farmers (total matching: %d), offset=%d", len(farmers), total, offset)
    return farmers, total
