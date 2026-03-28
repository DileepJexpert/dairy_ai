import logging
import uuid

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.vendor import Vendor

logger = logging.getLogger("dairy_ai.repositories.vendor")


async def get_by_id(db: AsyncSession, vendor_id: uuid.UUID) -> Vendor | None:
    logger.debug(f"get_by_id called | vendor_id={vendor_id}")
    result = await db.execute(select(Vendor).where(Vendor.id == vendor_id))
    vendor = result.scalar_one_or_none()
    if vendor:
        logger.debug(f"Vendor found | vendor_id={vendor.id} | business_name={vendor.business_name}")
    else:
        logger.debug(f"Vendor not found | vendor_id={vendor_id}")
    return vendor


async def get_by_user_id(db: AsyncSession, user_id: uuid.UUID) -> Vendor | None:
    logger.debug(f"get_by_user_id called | user_id={user_id}")
    result = await db.execute(select(Vendor).where(Vendor.user_id == user_id))
    vendor = result.scalar_one_or_none()
    if vendor:
        logger.debug(f"Vendor found | vendor_id={vendor.id} | user_id={user_id}")
    else:
        logger.debug(f"Vendor not found for user_id={user_id}")
    return vendor


async def create(db: AsyncSession, user_id: uuid.UUID, **kwargs) -> Vendor:
    logger.info(f"create called | user_id={user_id} | business_name={kwargs.get('business_name')}")
    vendor = Vendor(user_id=user_id, **kwargs)
    db.add(vendor)
    await db.flush()
    logger.info(f"Vendor created | vendor_id={vendor.id} | user_id={user_id}")
    return vendor


async def update(db: AsyncSession, vendor: Vendor, **kwargs) -> Vendor:
    logger.info(f"update called | vendor_id={vendor.id} | fields={list(kwargs.keys())}")
    for key, value in kwargs.items():
        if value is not None:
            setattr(vendor, key, value)
    await db.flush()
    logger.info(f"Vendor updated | vendor_id={vendor.id}")
    return vendor


async def list_all(
    db: AsyncSession, limit: int = 20, offset: int = 0, search: str | None = None,
) -> tuple[list[Vendor], int]:
    logger.debug(f"list_all called | limit={limit} | offset={offset} | search={search}")
    query = select(Vendor)
    count_query = select(func.count(Vendor.id))

    if search:
        search_filter = Vendor.business_name.ilike(f"%{search}%")
        query = query.where(search_filter)
        count_query = count_query.where(search_filter)

    total = (await db.execute(count_query)).scalar() or 0
    query = query.offset(offset).limit(limit)
    result = await db.execute(query)
    vendors = list(result.scalars().all())
    logger.debug(f"list_all result | total={total} | returned={len(vendors)}")
    return vendors, total
