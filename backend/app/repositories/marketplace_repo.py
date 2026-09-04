import uuid
from datetime import datetime
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.marketplace import CattleListing, ListingFavorite, ListingInquiry, ListingStatus


async def get_listing(db: AsyncSession, listing_id: uuid.UUID) -> CattleListing | None:
    return (await db.execute(select(CattleListing).where(CattleListing.id == listing_id))).scalar_one_or_none()


async def search(db: AsyncSession, *, filters: dict, limit: int, offset: int) -> tuple[list[CattleListing], int]:
    query = select(CattleListing).where(CattleListing.status == ListingStatus.active)
    query = query.where((CattleListing.expires_at.is_(None)) | (CattleListing.expires_at > datetime.utcnow()))
    for field, value in filters.items():
        if value is not None:
            query = query.where(getattr(CattleListing, field) == value)
    total = (await db.execute(select(func.count()).select_from(query.subquery()))).scalar_one()
    items = list((await db.execute(query.order_by(CattleListing.created_at.desc()).offset(offset).limit(limit))).scalars())
    return items, total

async def favorites(db: AsyncSession, farmer_id: uuid.UUID) -> list[CattleListing]:
    return list((await db.execute(select(CattleListing).join(ListingFavorite).where(ListingFavorite.farmer_id == farmer_id))).scalars())

async def add_favorite(db: AsyncSession, listing_id: uuid.UUID, farmer_id: uuid.UUID) -> bool:
    row = (await db.execute(select(ListingFavorite).where(ListingFavorite.listing_id == listing_id, ListingFavorite.farmer_id == farmer_id))).scalar_one_or_none()
    if row:
        await db.delete(row); await db.flush(); return False
    db.add(ListingFavorite(listing_id=listing_id, farmer_id=farmer_id)); await db.flush(); return True
