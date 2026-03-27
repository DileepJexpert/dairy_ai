import uuid
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories import health_repo
from app.schemas.health import HealthRecordCreate, VaccinationCreate, SensorDataCreate


async def add_health_record(db: AsyncSession, cattle_id: uuid.UUID, data: HealthRecordCreate):
    return await health_repo.create_health_record(
        db, cattle_id,
        date=data.date,
        record_type=data.record_type,
        symptoms=data.symptoms,
        diagnosis=data.diagnosis,
        treatment=data.treatment,
        severity=data.severity,
        notes=data.notes,
    )


async def get_health_records(db: AsyncSession, cattle_id: uuid.UUID):
    return await health_repo.get_health_records(db, cattle_id)


async def add_vaccination(db: AsyncSession, cattle_id: uuid.UUID, data: VaccinationCreate):
    return await health_repo.create_vaccination(
        db, cattle_id,
        vaccine_name=data.vaccine_name,
        date_given=data.date_given,
        next_due_date=data.next_due_date,
        batch_number=data.batch_number,
        administered_by=data.administered_by,
        notes=data.notes,
    )


async def get_vaccinations(db: AsyncSession, cattle_id: uuid.UUID):
    return await health_repo.get_vaccinations(db, cattle_id)


async def get_upcoming_vaccinations(db: AsyncSession, cattle_ids: list[uuid.UUID]):
    return await health_repo.get_upcoming_vaccinations(db, cattle_ids)


async def ingest_sensor_data(db: AsyncSession, cattle_id: uuid.UUID, data: SensorDataCreate):
    now = datetime.now(timezone.utc)
    return await health_repo.store_sensor_reading(
        db, cattle_id, time=now,
        temperature=data.temperature,
        heart_rate=data.heart_rate,
        activity_level=data.activity_level,
        rumination_minutes=data.rumination_minutes,
        battery_pct=data.battery_pct,
        rssi=data.rssi,
    )


async def check_anomalies(db: AsyncSession, cattle_id: uuid.UUID) -> list[dict]:
    """Compare latest reading against thresholds. Return alerts if anomaly detected."""
    latest = await health_repo.get_latest_sensor(db, cattle_id)
    if not latest:
        return []

    alerts = []
    if latest.temperature and latest.temperature > 39.5:
        alerts.append({
            "cattle_id": str(cattle_id),
            "alert_type": "high_temperature",
            "message": f"Temperature {latest.temperature}°C is above normal (>39.5°C)",
            "current_value": latest.temperature,
            "threshold": 39.5,
        })
    if latest.heart_rate and latest.heart_rate > 80:
        alerts.append({
            "cattle_id": str(cattle_id),
            "alert_type": "high_heart_rate",
            "message": f"Heart rate {latest.heart_rate} bpm is above normal (>80 bpm)",
            "current_value": float(latest.heart_rate),
            "threshold": 80.0,
        })

    # Check activity drop vs 7-day average
    stats = await health_repo.get_sensor_stats(db, cattle_id, hours=168)  # 7 days
    if stats.get("avg_activity") and latest.activity_level is not None:
        avg = stats["avg_activity"]
        if avg > 0 and latest.activity_level < avg * 0.6:  # 40% drop
            alerts.append({
                "cattle_id": str(cattle_id),
                "alert_type": "activity_drop",
                "message": f"Activity level dropped significantly ({latest.activity_level} vs avg {avg})",
                "current_value": latest.activity_level,
                "threshold": avg * 0.6,
            })

    return alerts


async def get_cattle_health_dashboard(db: AsyncSession, cattle_id: uuid.UUID) -> dict:
    latest = await health_repo.get_latest_sensor(db, cattle_id)
    records = await health_repo.get_health_records(db, cattle_id)
    stats = await health_repo.get_sensor_stats(db, cattle_id, hours=24)
    alerts = await check_anomalies(db, cattle_id)

    return {
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
