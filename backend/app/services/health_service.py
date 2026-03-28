import logging
import uuid
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories import health_repo
from app.schemas.health import HealthRecordCreate, VaccinationCreate, SensorDataCreate

logger = logging.getLogger("dairy_ai.services.health")


async def add_health_record(db: AsyncSession, cattle_id: uuid.UUID, data: HealthRecordCreate):
    logger.info(f"add_health_record called | cattle_id={cattle_id}, type={data.record_type}, severity={data.severity}")
    logger.debug(f"Health record details | symptoms={data.symptoms}, diagnosis={data.diagnosis}")

    record = await health_repo.create_health_record(
        db, cattle_id,
        date=data.date,
        record_type=data.record_type,
        symptoms=data.symptoms,
        diagnosis=data.diagnosis,
        treatment=data.treatment,
        severity=data.severity,
        notes=data.notes,
    )
    logger.info(f"Health record created | record_id={record.id}, cattle_id={cattle_id}, type={data.record_type}")
    return record


async def get_health_records(db: AsyncSession, cattle_id: uuid.UUID):
    logger.debug(f"get_health_records called | cattle_id={cattle_id}")
    records = await health_repo.get_health_records(db, cattle_id)
    logger.debug(f"Health records fetched | cattle_id={cattle_id}, count={len(records)}")
    return records


async def add_vaccination(db: AsyncSession, cattle_id: uuid.UUID, data: VaccinationCreate):
    logger.info(f"add_vaccination called | cattle_id={cattle_id}, vaccine={data.vaccine_name}, date_given={data.date_given}")
    logger.debug(f"Vaccination details | next_due={data.next_due_date}, batch={data.batch_number}, administered_by={data.administered_by}")

    record = await health_repo.create_vaccination(
        db, cattle_id,
        vaccine_name=data.vaccine_name,
        date_given=data.date_given,
        next_due_date=data.next_due_date,
        batch_number=data.batch_number,
        administered_by=data.administered_by,
        notes=data.notes,
    )
    logger.info(f"Vaccination record created | record_id={record.id}, cattle_id={cattle_id}, vaccine={data.vaccine_name}")
    return record


async def get_vaccinations(db: AsyncSession, cattle_id: uuid.UUID):
    logger.debug(f"get_vaccinations called | cattle_id={cattle_id}")
    records = await health_repo.get_vaccinations(db, cattle_id)
    logger.debug(f"Vaccinations fetched | cattle_id={cattle_id}, count={len(records)}")
    return records


async def get_upcoming_vaccinations(db: AsyncSession, cattle_ids: list[uuid.UUID]):
    logger.info(f"get_upcoming_vaccinations called | cattle_count={len(cattle_ids)}")
    records = await health_repo.get_upcoming_vaccinations(db, cattle_ids)
    logger.info(f"Upcoming vaccinations found | count={len(records)}")
    return records


async def ingest_sensor_data(db: AsyncSession, cattle_id: uuid.UUID, data: SensorDataCreate):
    logger.info(f"ingest_sensor_data called | cattle_id={cattle_id}")
    logger.debug(f"Sensor values | temp={data.temperature}, heart_rate={data.heart_rate}, activity={data.activity_level}, rumination={data.rumination_minutes}, battery={data.battery_pct}%, rssi={data.rssi}")

    now = datetime.now(timezone.utc)
    result = await health_repo.store_sensor_reading(
        db, cattle_id, time=now,
        temperature=data.temperature,
        heart_rate=data.heart_rate,
        activity_level=data.activity_level,
        rumination_minutes=data.rumination_minutes,
        battery_pct=data.battery_pct,
        rssi=data.rssi,
    )
    logger.info(f"Sensor data stored | cattle_id={cattle_id}, timestamp={now.isoformat()}")

    if data.battery_pct is not None and data.battery_pct < 20:
        logger.warning(f"Low battery on sensor | cattle_id={cattle_id}, battery={data.battery_pct}%")

    return result


async def check_anomalies(db: AsyncSession, cattle_id: uuid.UUID) -> list[dict]:
    """Compare latest reading against thresholds. Return alerts if anomaly detected."""
    logger.info(f"check_anomalies called | cattle_id={cattle_id}")

    latest = await health_repo.get_latest_sensor(db, cattle_id)
    if not latest:
        logger.debug(f"No sensor data available for cattle_id={cattle_id}, no anomalies to check")
        return []

    logger.debug(f"Latest sensor reading | cattle_id={cattle_id}, temp={latest.temperature}, heart_rate={latest.heart_rate}, activity={latest.activity_level}")

    alerts = []
    if latest.temperature and latest.temperature > 39.5:
        logger.warning(f"HIGH TEMPERATURE detected | cattle_id={cattle_id}, temp={latest.temperature}°C (threshold=39.5°C)")
        alerts.append({
            "cattle_id": str(cattle_id),
            "alert_type": "high_temperature",
            "message": f"Temperature {latest.temperature}°C is above normal (>39.5°C)",
            "current_value": latest.temperature,
            "threshold": 39.5,
        })
    if latest.heart_rate and latest.heart_rate > 80:
        logger.warning(f"HIGH HEART RATE detected | cattle_id={cattle_id}, heart_rate={latest.heart_rate}bpm (threshold=80bpm)")
        alerts.append({
            "cattle_id": str(cattle_id),
            "alert_type": "high_heart_rate",
            "message": f"Heart rate {latest.heart_rate} bpm is above normal (>80 bpm)",
            "current_value": float(latest.heart_rate),
            "threshold": 80.0,
        })

    # Check activity drop vs 7-day average
    logger.debug(f"Checking activity level against 7-day average | cattle_id={cattle_id}")
    stats = await health_repo.get_sensor_stats(db, cattle_id, hours=168)  # 7 days
    if stats.get("avg_activity") and latest.activity_level is not None:
        avg = stats["avg_activity"]
        logger.debug(f"Activity comparison | cattle_id={cattle_id}, current={latest.activity_level}, 7day_avg={avg}, threshold={avg * 0.6}")
        if avg > 0 and latest.activity_level < avg * 0.6:  # 40% drop
            logger.warning(f"ACTIVITY DROP detected | cattle_id={cattle_id}, current={latest.activity_level}, avg={avg}, drop={round((1 - latest.activity_level/avg) * 100, 1)}%")
            alerts.append({
                "cattle_id": str(cattle_id),
                "alert_type": "activity_drop",
                "message": f"Activity level dropped significantly ({latest.activity_level} vs avg {avg})",
                "current_value": latest.activity_level,
                "threshold": avg * 0.6,
            })

    logger.info(f"check_anomalies completed | cattle_id={cattle_id}, alerts_count={len(alerts)}")
    return alerts


async def get_cattle_health_dashboard(db: AsyncSession, cattle_id: uuid.UUID) -> dict:
    logger.info(f"get_cattle_health_dashboard called | cattle_id={cattle_id}")

    logger.debug(f"Fetching latest sensor reading for cattle_id={cattle_id}")
    latest = await health_repo.get_latest_sensor(db, cattle_id)

    logger.debug(f"Fetching health records for cattle_id={cattle_id}")
    records = await health_repo.get_health_records(db, cattle_id)

    logger.debug(f"Fetching 24h sensor stats for cattle_id={cattle_id}")
    stats = await health_repo.get_sensor_stats(db, cattle_id, hours=24)

    logger.debug(f"Running anomaly check for cattle_id={cattle_id}")
    alerts = await check_anomalies(db, cattle_id)

    dashboard = {
        "latest_vitals": {
            "temperature": latest.temperature if latest else None,
            "heart_rate": latest.heart_rate if latest else None,
            "activity_level": latest.activity_level if latest else None,
            "time": str(latest.time) if latest else None,
        },
        "stats_24h": stats,
        "recent_records": [
            {
                "id": str(r.id),
                "date": str(r.date),
                "record_type": r.record_type.value if hasattr(r.record_type, 'value') else r.record_type,
                "diagnosis": r.diagnosis,
                "severity": r.severity,
            }
            for r in records[:5]
        ],
        "alerts": alerts,
    }

    logger.info(f"Health dashboard loaded | cattle_id={cattle_id}, has_vitals={latest is not None}, records_count={len(records)}, alerts_count={len(alerts)}")
    return dashboard
