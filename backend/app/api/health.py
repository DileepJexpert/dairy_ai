import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.repositories import farmer_repo, cattle_repo, health_repo
from app.services import health_service
from app.schemas.health import HealthRecordCreate, VaccinationCreate, SensorDataCreate

router = APIRouter(tags=["health"])


async def _verify_cattle_ownership(db: AsyncSession, user: User, cattle_id_str: str) -> uuid.UUID:
    farmer = await farmer_repo.get_by_user_id(db, user.id)
    if not farmer:
        raise HTTPException(status_code=404, detail="Farmer profile not found")
    cattle_id = uuid.UUID(cattle_id_str)
    cattle = await cattle_repo.get_by_id(db, cattle_id)
    if not cattle or cattle.farmer_id != farmer.id:
        raise HTTPException(status_code=404, detail="Cattle not found")
    return cattle_id


@router.post("/cattle/{cattle_id}/health-records", status_code=201)
async def create_health_record(
    cattle_id: str, data: HealthRecordCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    cid = await _verify_cattle_ownership(db, current_user, cattle_id)
    record = await health_service.add_health_record(db, cid, data)
    return {"success": True, "data": {"id": str(record.id)}, "message": "Health record created"}


@router.get("/cattle/{cattle_id}/health-records")
async def get_health_records(
    cattle_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    cid = await _verify_cattle_ownership(db, current_user, cattle_id)
    records = await health_service.get_health_records(db, cid)
    return {
        "success": True,
        "data": [
            {
                "id": str(r.id),
                "cattle_id": str(r.cattle_id),
                "date": str(r.date),
                "record_type": r.record_type.value if hasattr(r.record_type, 'value') else r.record_type,
                "symptoms": r.symptoms,
                "diagnosis": r.diagnosis,
                "severity": r.severity,
                "resolved": r.resolved,
            }
            for r in records
        ],
        "message": "Health records",
    }


@router.post("/cattle/{cattle_id}/vaccinations", status_code=201)
async def create_vaccination(
    cattle_id: str, data: VaccinationCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    cid = await _verify_cattle_ownership(db, current_user, cattle_id)
    vacc = await health_service.add_vaccination(db, cid, data)
    return {"success": True, "data": {"id": str(vacc.id)}, "message": "Vaccination recorded"}


@router.get("/cattle/{cattle_id}/vaccinations")
async def get_vaccinations(
    cattle_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    cid = await _verify_cattle_ownership(db, current_user, cattle_id)
    vaccs = await health_service.get_vaccinations(db, cid)
    return {
        "success": True,
        "data": [
            {
                "id": str(v.id),
                "vaccine_name": v.vaccine_name,
                "date_given": str(v.date_given),
                "next_due_date": str(v.next_due_date) if v.next_due_date else None,
            }
            for v in vaccs
        ],
        "message": "Vaccinations",
    }


@router.post("/cattle/{cattle_id}/sensor-data", status_code=201)
async def ingest_sensor_data(
    cattle_id: str, data: SensorDataCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    cid = await _verify_cattle_ownership(db, current_user, cattle_id)
    reading = await health_service.ingest_sensor_data(db, cid, data)
    alerts = await health_service.check_anomalies(db, cid)
    return {
        "success": True,
        "data": {"time": str(reading.time), "alerts": alerts},
        "message": "Sensor data recorded",
    }


@router.get("/cattle/{cattle_id}/sensors")
async def get_sensor_history(
    cattle_id: str,
    hours: int = Query(24, le=168),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    cid = await _verify_cattle_ownership(db, current_user, cattle_id)
    end = datetime.now(timezone.utc)
    start = end - timedelta(hours=hours)
    readings = await health_repo.get_sensor_readings(db, cid, start, end)
    return {
        "success": True,
        "data": [
            {
                "time": str(r.time),
                "temperature": r.temperature,
                "heart_rate": r.heart_rate,
                "activity_level": r.activity_level,
            }
            for r in readings
        ],
        "message": "Sensor history",
    }


@router.get("/cattle/{cattle_id}/sensors/latest")
async def get_latest_sensor(
    cattle_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    cid = await _verify_cattle_ownership(db, current_user, cattle_id)
    latest = await health_repo.get_latest_sensor(db, cid)
    if not latest:
        return {"success": True, "data": None, "message": "No sensor data"}
    return {
        "success": True,
        "data": {
            "time": str(latest.time),
            "temperature": latest.temperature,
            "heart_rate": latest.heart_rate,
            "activity_level": latest.activity_level,
            "battery_pct": latest.battery_pct,
        },
        "message": "Latest sensor reading",
    }


@router.get("/cattle/{cattle_id}/sensors/stats")
async def get_sensor_stats(
    cattle_id: str,
    hours: int = Query(24, le=168),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    cid = await _verify_cattle_ownership(db, current_user, cattle_id)
    stats = await health_repo.get_sensor_stats(db, cid, hours=hours)
    return {"success": True, "data": stats, "message": "Sensor statistics"}


@router.get("/cattle/{cattle_id}/health-dashboard")
async def get_health_dashboard(
    cattle_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    cid = await _verify_cattle_ownership(db, current_user, cattle_id)
    dashboard = await health_service.get_cattle_health_dashboard(db, cid)
    return {"success": True, "data": dashboard, "message": "Health dashboard"}
