import uuid
from datetime import date, timedelta
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.breeding import BreedingRecord, BreedingEventType
from app.schemas.breeding import BreedingEventCreate


async def record_breeding_event(db: AsyncSession, cattle_id: uuid.UUID, data: BreedingEventCreate) -> BreedingRecord:
    record = BreedingRecord(
        cattle_id=cattle_id,
        event_type=data.event_type,
        date=data.date,
        bull_id=data.bull_id,
        ai_technician=data.ai_technician,
        semen_batch=data.semen_batch,
        expected_calving_date=data.expected_calving_date,
        notes=data.notes,
    )
    db.add(record)
    await db.flush()
    return record


async def get_breeding_timeline(db: AsyncSession, cattle_id: uuid.UUID) -> list[BreedingRecord]:
    result = await db.execute(
        select(BreedingRecord)
        .where(BreedingRecord.cattle_id == cattle_id)
        .order_by(BreedingRecord.date.desc())
    )
    return list(result.scalars().all())


async def get_expected_calvings(db: AsyncSession, cattle_ids: list[uuid.UUID]) -> list[BreedingRecord]:
    if not cattle_ids:
        return []
    cutoff = date.today() + timedelta(days=30)
    result = await db.execute(
        select(BreedingRecord)
        .where(
            and_(
                BreedingRecord.cattle_id.in_(cattle_ids),
                BreedingRecord.expected_calving_date != None,
                BreedingRecord.expected_calving_date <= cutoff,
                BreedingRecord.actual_calving_date == None,
            )
        )
        .order_by(BreedingRecord.expected_calving_date.asc())
    )
    return list(result.scalars().all())
