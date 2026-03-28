import logging
import uuid

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.cooperative import Cooperative

logger = logging.getLogger("dairy_ai.repositories.cooperative")


async def get_by_id(db: AsyncSession, cooperative_id: uuid.UUID) -> Cooperative | None:
    logger.debug(f"get_by_id called | cooperative_id={cooperative_id}")
    result = await db.execute(select(Cooperative).where(Cooperative.id == cooperative_id))
    coop = result.scalar_one_or_none()
    if coop:
        logger.debug(f"Cooperative found | cooperative_id={coop.id} | name={coop.name}")
    else:
        logger.debug(f"Cooperative not found | cooperative_id={cooperative_id}")
    return coop


async def get_by_user_id(db: AsyncSession, user_id: uuid.UUID) -> Cooperative | None:
    logger.debug(f"get_by_user_id called | user_id={user_id}")
    result = await db.execute(select(Cooperative).where(Cooperative.user_id == user_id))
    coop = result.scalar_one_or_none()
    if coop:
        logger.debug(f"Cooperative found | cooperative_id={coop.id} | user_id={user_id}")
    else:
        logger.debug(f"Cooperative not found for user_id={user_id}")
    return coop


async def create(db: AsyncSession, user_id: uuid.UUID, **kwargs) -> Cooperative:
    logger.info(f"create called | user_id={user_id} | name={kwargs.get('name')}")
    coop = Cooperative(user_id=user_id, **kwargs)
    db.add(coop)
    await db.flush()
    logger.info(f"Cooperative created | cooperative_id={coop.id} | user_id={user_id}")
    return coop


async def update(db: AsyncSession, coop: Cooperative, **kwargs) -> Cooperative:
    logger.info(f"update called | cooperative_id={coop.id} | fields={list(kwargs.keys())}")
    for key, value in kwargs.items():
        if value is not None:
            setattr(coop, key, value)
    await db.flush()
    logger.info(f"Cooperative updated | cooperative_id={coop.id}")
    return coop


async def list_all(
    db: AsyncSession, limit: int = 20, offset: int = 0, search: str | None = None,
) -> tuple[list[Cooperative], int]:
    logger.debug(f"list_all called | limit={limit} | offset={offset} | search={search}")
    query = select(Cooperative)
    count_query = select(func.count(Cooperative.id))

    if search:
        search_filter = Cooperative.name.ilike(f"%{search}%")
        query = query.where(search_filter)
        count_query = count_query.where(search_filter)

    total = (await db.execute(count_query)).scalar() or 0
    query = query.offset(offset).limit(limit)
    result = await db.execute(query)
    cooperatives = list(result.scalars().all())
    logger.debug(f"list_all result | total={total} | returned={len(cooperatives)}")
    return cooperatives, total
