import logging
import uuid
from datetime import date, timedelta
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.breeding import BreedingRecord, BreedingEventType
from app.schemas.breeding import BreedingEventCreate

logger = logging.getLogger("dairy_ai.services.breeding")


async def record_breeding_event(db: AsyncSession, cattle_id: uuid.UUID, data: BreedingEventCreate) -> BreedingRecord:
    logger.info(f"record_breeding_event called | cattle_id={cattle_id}, event_type={data.event_type}, date={data.date}")
    logger.debug(f"Breeding event details | bull_id={data.bull_id}, ai_technician={data.ai_technician}, semen_batch={data.semen_batch}, expected_calving={data.expected_calving_date}")

    logger.debug(f"Creating breeding record in database | cattle_id={cattle_id}")
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

    logger.info(f"Breeding event recorded | record_id={record.id}, cattle_id={cattle_id}, event_type={data.event_type}")
    if data.expected_calving_date:
        logger.info(f"Expected calving date set | cattle_id={cattle_id}, expected_date={data.expected_calving_date}")
    return record


async def get_breeding_timeline(db: AsyncSession, cattle_id: uuid.UUID) -> list[BreedingRecord]:
    logger.debug(f"get_breeding_timeline called | cattle_id={cattle_id}")
    result = await db.execute(
        select(BreedingRecord)
        .where(BreedingRecord.cattle_id == cattle_id)
        .order_by(BreedingRecord.date.desc())
    )
    records = list(result.scalars().all())
    logger.debug(f"Breeding timeline fetched | cattle_id={cattle_id}, events_count={len(records)}")
    return records


async def get_expected_calvings(db: AsyncSession, cattle_ids: list[uuid.UUID]) -> list[BreedingRecord]:
    logger.info(f"get_expected_calvings called | cattle_count={len(cattle_ids)}")
    if not cattle_ids:
        logger.debug("No cattle IDs provided, returning empty list")
        return []

    cutoff = date.today() + timedelta(days=30)
    logger.debug(f"Searching for expected calvings within 30 days (cutoff={cutoff})")

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
    records = list(result.scalars().all())
    logger.info(f"Expected calvings found | count={len(records)}, within_30_days=True")
    for r in records:
        logger.debug(f"  - cattle_id={r.cattle_id}, expected_date={r.expected_calving_date}")
    return records
