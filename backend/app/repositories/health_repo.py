import logging
import uuid
from datetime import datetime, timedelta, date, timezone
from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.health import HealthRecord, Vaccination, SensorReading

logger = logging.getLogger("dairy_ai.repos.health")


async def create_health_record(db: AsyncSession, cattle_id: uuid.UUID, **kwargs) -> HealthRecord:
    logger.info("Creating health record for cattle_id=%s, fields=%s", cattle_id, list(kwargs.keys()))
    record = HealthRecord(cattle_id=cattle_id, **kwargs)
    db.add(record)
    await db.flush()
    logger.info("Created health record id=%s for cattle %s, type=%s", record.id, cattle_id, kwargs.get("type"))
    return record


async def get_health_records(db: AsyncSession, cattle_id: uuid.UUID, limit: int = 50) -> list[HealthRecord]:
    logger.debug("Querying health records for cattle_id=%s, limit=%d", cattle_id, limit)
    result = await db.execute(
        select(HealthRecord)
        .where(HealthRecord.cattle_id == cattle_id)
        .order_by(HealthRecord.date.desc())
        .limit(limit)
    )
    records = list(result.scalars().all())
    logger.info("Found %d health records for cattle %s", len(records), cattle_id)
    return records


async def create_vaccination(db: AsyncSession, cattle_id: uuid.UUID, **kwargs) -> Vaccination:
    logger.info("Creating vaccination for cattle_id=%s, vaccine=%s", cattle_id, kwargs.get("vaccine_name"))
    vacc = Vaccination(cattle_id=cattle_id, **kwargs)
    db.add(vacc)
    await db.flush()
    logger.info("Created vaccination id=%s for cattle %s, vaccine=%s, next_due=%s",
                vacc.id, cattle_id, kwargs.get("vaccine_name"), kwargs.get("next_due_date"))
    return vacc


async def get_vaccinations(db: AsyncSession, cattle_id: uuid.UUID) -> list[Vaccination]:
    logger.debug("Querying vaccinations for cattle_id=%s", cattle_id)
    result = await db.execute(
        select(Vaccination)
        .where(Vaccination.cattle_id == cattle_id)
        .order_by(Vaccination.date_given.desc())
    )
    vaccinations = list(result.scalars().all())
    logger.info("Found %d vaccinations for cattle %s", len(vaccinations), cattle_id)
    return vaccinations


async def get_upcoming_vaccinations(db: AsyncSession, cattle_ids: list[uuid.UUID], days: int = 30) -> list[Vaccination]:
    cutoff = date.today() + timedelta(days=days)
    logger.debug("Querying upcoming vaccinations for %d cattle within %d days (cutoff=%s)",
                 len(cattle_ids), days, cutoff)
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
    vaccinations = list(result.scalars().all())
    logger.info("Found %d upcoming vaccinations due within %d days for %d cattle",
                len(vaccinations), days, len(cattle_ids))
    return vaccinations


async def store_sensor_reading(db: AsyncSession, cattle_id: uuid.UUID, time: datetime, **kwargs) -> SensorReading:
    logger.debug("Storing sensor reading for cattle_id=%s at time=%s: temp=%s, hr=%s, activity=%s",
                 cattle_id, time, kwargs.get("temperature"), kwargs.get("heart_rate"), kwargs.get("activity_level"))
    reading = SensorReading(cattle_id=cattle_id, time=time, **kwargs)
    db.add(reading)
    await db.flush()
    logger.info("Stored sensor reading for cattle %s at %s", cattle_id, time)
    return reading


async def get_sensor_readings(
    db: AsyncSession, cattle_id: uuid.UUID, start_time: datetime, end_time: datetime
) -> list[SensorReading]:
    logger.debug("Querying sensor readings for cattle_id=%s from %s to %s", cattle_id, start_time, end_time)
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
    readings = list(result.scalars().all())
    logger.info("Found %d sensor readings for cattle %s in time range [%s, %s]",
                len(readings), cattle_id, start_time, end_time)
    return readings


async def get_latest_sensor(db: AsyncSession, cattle_id: uuid.UUID) -> SensorReading | None:
    logger.debug("Querying latest sensor reading for cattle_id=%s", cattle_id)
    result = await db.execute(
        select(SensorReading)
        .where(SensorReading.cattle_id == cattle_id)
        .order_by(SensorReading.time.desc())
        .limit(1)
    )
    reading = result.scalar_one_or_none()
    if reading:
        logger.info("Latest sensor for cattle %s: time=%s, temp=%s, hr=%s",
                     cattle_id, reading.time, reading.temperature, reading.heart_rate)
    else:
        logger.info("No sensor readings found for cattle %s", cattle_id)
    return reading


async def get_sensor_stats(db: AsyncSession, cattle_id: uuid.UUID, hours: int = 24) -> dict:
    cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)
    logger.debug("Computing sensor stats for cattle_id=%s over last %d hours (since %s)", cattle_id, hours, cutoff)
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
    stats = {
        "avg_temperature": round(float(row.avg_temperature), 1) if row.avg_temperature else None,
        "min_temperature": round(float(row.min_temperature), 1) if row.min_temperature else None,
        "max_temperature": round(float(row.max_temperature), 1) if row.max_temperature else None,
        "avg_heart_rate": round(float(row.avg_heart_rate), 1) if row.avg_heart_rate else None,
        "avg_activity": round(float(row.avg_activity), 1) if row.avg_activity else None,
    }
    logger.info("Sensor stats for cattle %s (last %dh): avg_temp=%s, avg_hr=%s, avg_activity=%s",
                cattle_id, hours, stats["avg_temperature"], stats["avg_heart_rate"], stats["avg_activity"])
    return stats
