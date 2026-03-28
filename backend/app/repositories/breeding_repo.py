"""Repository for breeding records."""
import uuid
from datetime import date
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.breeding import BreedingRecord, BreedingEventType


async def create(db: AsyncSession, cattle_id: uuid.UUID, data: dict) -> BreedingRecord:
    record = BreedingRecord(cattle_id=cattle_id, **data)
    db.add(record)
    await db.flush()
    return record


async def get_by_id(db: AsyncSession, record_id: uuid.UUID) -> BreedingRecord | None:
    result = await db.execute(select(BreedingRecord).where(BreedingRecord.id == record_id))
    return result.scalar_one_or_none()


async def get_by_cattle(
    db: AsyncSession, cattle_id: uuid.UUID, limit: int = 50
) -> list[BreedingRecord]:
    result = await db.execute(
        select(BreedingRecord)
        .where(BreedingRecord.cattle_id == cattle_id)
        .order_by(BreedingRecord.date.desc())
        .limit(limit)
    )
    return list(result.scalars().all())


async def get_expected_calvings(
    db: AsyncSession, farmer_cattle_ids: list[uuid.UUID], from_date: date | None = None
) -> list[BreedingRecord]:
    """Get cattle with expected calving dates (pregnancy confirmed, no actual calving yet)."""
    query = select(BreedingRecord).where(
        and_(
            BreedingRecord.cattle_id.in_(farmer_cattle_ids),
            BreedingRecord.event_type == BreedingEventType.pregnancy_confirmed,
            BreedingRecord.expected_calving_date.isnot(None),
            BreedingRecord.actual_calving_date.is_(None),
        )
    )
    if from_date:
        query = query.where(BreedingRecord.expected_calving_date >= from_date)
    query = query.order_by(BreedingRecord.expected_calving_date.asc())
    result = await db.execute(query)
    return list(result.scalars().all())


async def get_last_event(
    db: AsyncSession, cattle_id: uuid.UUID, event_type: BreedingEventType | None = None
) -> BreedingRecord | None:
    query = select(BreedingRecord).where(BreedingRecord.cattle_id == cattle_id)
    if event_type:
        query = query.where(BreedingRecord.event_type == event_type)
    query = query.order_by(BreedingRecord.date.desc()).limit(1)
    result = await db.execute(query)
    return result.scalar_one_or_none()
