import uuid
from datetime import datetime, timedelta, date, timezone
from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.health import HealthRecord, Vaccination, SensorReading


async def create_health_record(db: AsyncSession, cattle_id: uuid.UUID, **kwargs) -> HealthRecord:
    record = HealthRecord(cattle_id=cattle_id, **kwargs)
    db.add(record)
    await db.flush()
    return record


async def get_health_records(db: AsyncSession, cattle_id: uuid.UUID, limit: int = 50) -> list[HealthRecord]:
    result = await db.execute(
        select(HealthRecord)
        .where(HealthRecord.cattle_id == cattle_id)
        .order_by(HealthRecord.date.desc())
        .limit(limit)
    )
    return list(result.scalars().all())


async def create_vaccination(db: AsyncSession, cattle_id: uuid.UUID, **kwargs) -> Vaccination:
    vacc = Vaccination(cattle_id=cattle_id, **kwargs)
    db.add(vacc)
    await db.flush()
    return vacc


async def get_vaccinations(db: AsyncSession, cattle_id: uuid.UUID) -> list[Vaccination]:
    result = await db.execute(
        select(Vaccination)
        .where(Vaccination.cattle_id == cattle_id)
        .order_by(Vaccination.date_given.desc())
    )
    return list(result.scalars().all())


async def get_upcoming_vaccinations(db: AsyncSession, cattle_ids: list[uuid.UUID], days: int = 30) -> list[Vaccination]:
    cutoff = date.today() + timedelta(days=days)
    result = await db.execute(
        select(Vaccination)
        .where(
            and_(
                Vaccination.cattle_id.in_(cattle_ids),
                Vaccination.next_due_date != None,
                Vaccination.next_due_date <= cutoff,
            )
        )
        .order_by(Vaccination.next_due_date.asc())
    )
    return list(result.scalars().all())


async def store_sensor_reading(db: AsyncSession, cattle_id: uuid.UUID, time: datetime, **kwargs) -> SensorReading:
    reading = SensorReading(cattle_id=cattle_id, time=time, **kwargs)
    db.add(reading)
    await db.flush()
    return reading


async def get_sensor_readings(
    db: AsyncSession, cattle_id: uuid.UUID, start_time: datetime, end_time: datetime
) -> list[SensorReading]:
    result = await db.execute(
        select(SensorReading)
        .where(
            and_(
                SensorReading.cattle_id == cattle_id,
                SensorReading.time >= start_time,
                SensorReading.time <= end_time,
            )
        )
        .order_by(SensorReading.time.desc())
    )
    return list(result.scalars().all())


async def get_latest_sensor(db: AsyncSession, cattle_id: uuid.UUID) -> SensorReading | None:
    result = await db.execute(
        select(SensorReading)
        .where(SensorReading.cattle_id == cattle_id)
        .order_by(SensorReading.time.desc())
        .limit(1)
    )
    return result.scalar_one_or_none()


async def get_sensor_stats(db: AsyncSession, cattle_id: uuid.UUID, hours: int = 24) -> dict:
    cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)
    result = await db.execute(
        select(
            func.avg(SensorReading.temperature).label("avg_temperature"),
            func.min(SensorReading.temperature).label("min_temperature"),
            func.max(SensorReading.temperature).label("max_temperature"),
            func.avg(SensorReading.heart_rate).label("avg_heart_rate"),
            func.avg(SensorReading.activity_level).label("avg_activity"),
        )
        .where(
            and_(
                SensorReading.cattle_id == cattle_id,
                SensorReading.time >= cutoff,
            )
        )
    )
    row = result.one()
    return {
        "avg_temperature": round(float(row.avg_temperature), 1) if row.avg_temperature else None,
        "min_temperature": round(float(row.min_temperature), 1) if row.min_temperature else None,
        "max_temperature": round(float(row.max_temperature), 1) if row.max_temperature else None,
        "avg_heart_rate": round(float(row.avg_heart_rate), 1) if row.avg_heart_rate else None,
        "avg_activity": round(float(row.avg_activity), 1) if row.avg_activity else None,
    }
