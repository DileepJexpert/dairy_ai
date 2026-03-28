import uuid
import logging
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.repositories import farmer_repo, cattle_repo, health_repo
from app.services import health_service
from app.schemas.health import HealthRecordCreate, VaccinationCreate, SensorDataCreate

logger = logging.getLogger("dairy_ai.api.health")

router = APIRouter(tags=["health"])


async def _verify_cattle_ownership(db: AsyncSession, user: User, cattle_id_str: str) -> uuid.UUID:
    logger.debug(f"Verifying cattle ownership | user_id={user.id} | cattle_id={cattle_id_str}")
    farmer = await farmer_repo.get_by_user_id(db, user.id)
    if not farmer:
        logger.warning(f"Farmer profile not found during cattle ownership check | user_id={user.id}")
        raise HTTPException(status_code=404, detail="Farmer profile not found")
    cattle_id = uuid.UUID(cattle_id_str)
    cattle = await cattle_repo.get_by_id(db, cattle_id)
    if not cattle or cattle.farmer_id != farmer.id:
        logger.warning(f"Cattle not found or ownership mismatch | cattle_id={cattle_id_str} | farmer_id={farmer.id}")
        raise HTTPException(status_code=404, detail="Cattle not found")
    logger.debug(f"Cattle ownership verified | cattle_id={cattle_id} | farmer_id={farmer.id}")
    return cattle_id


@router.post("/cattle/{cattle_id}/health-records", status_code=201)
async def create_health_record(
    cattle_id: str, data: HealthRecordCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"POST /cattle/{cattle_id}/health-records called | user_id={current_user.id}")
    logger.debug(f"Health record data: record_type={data.record_type} | symptoms={data.symptoms}")
    cid = await _verify_cattle_ownership(db, current_user, cattle_id)
    logger.debug(f"Calling health_service.add_health_record | cattle_id={cid}")
    try:
        record = await health_service.add_health_record(db, cid, data)
        logger.info(f"Health record created | record_id={record.id} | cattle_id={cid}")
        return {"success": True, "data": {"id": str(record.id)}, "message": "Health record created"}
    except Exception as e:
        logger.error(f"Failed to create health record for cattle_id={cid}: {e}")
        raise


@router.get("/cattle/{cattle_id}/health-records")
async def get_health_records(
    cattle_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /cattle/{cattle_id}/health-records called | user_id={current_user.id}")
    cid = await _verify_cattle_ownership(db, current_user, cattle_id)
    logger.debug(f"Calling health_service.get_health_records | cattle_id={cid}")
    records = await health_service.get_health_records(db, cid)
    logger.info(f"Health records retrieved | cattle_id={cid} | count={len(records)}")
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
    logger.info(f"POST /cattle/{cattle_id}/vaccinations called | user_id={current_user.id} | vaccine={data.vaccine_name}")
    cid = await _verify_cattle_ownership(db, current_user, cattle_id)
    logger.debug(f"Calling health_service.add_vaccination | cattle_id={cid} | vaccine_name={data.vaccine_name}")
    try:
        vacc = await health_service.add_vaccination(db, cid, data)
        logger.info(f"Vaccination recorded | vaccination_id={vacc.id} | cattle_id={cid} | vaccine={data.vaccine_name}")
        return {"success": True, "data": {"id": str(vacc.id)}, "message": "Vaccination recorded"}
    except Exception as e:
        logger.error(f"Failed to record vaccination for cattle_id={cid}: {e}")
        raise


@router.get("/cattle/{cattle_id}/vaccinations")
async def get_vaccinations(
    cattle_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /cattle/{cattle_id}/vaccinations called | user_id={current_user.id}")
    cid = await _verify_cattle_ownership(db, current_user, cattle_id)
    logger.debug(f"Calling health_service.get_vaccinations | cattle_id={cid}")
    vaccs = await health_service.get_vaccinations(db, cid)
    logger.info(f"Vaccinations retrieved | cattle_id={cid} | count={len(vaccs)}")
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
    logger.info(f"POST /cattle/{cattle_id}/sensor-data called | user_id={current_user.id}")
    logger.debug(f"Sensor data: temperature={data.temperature} | heart_rate={data.heart_rate} | activity_level={data.activity_level}")
    cid = await _verify_cattle_ownership(db, current_user, cattle_id)
    logger.debug(f"Calling health_service.ingest_sensor_data | cattle_id={cid}")
    try:
        reading = await health_service.ingest_sensor_data(db, cid, data)
        logger.info(f"Sensor data ingested | cattle_id={cid} | time={reading.time}")
        logger.debug(f"Checking for anomalies | cattle_id={cid}")
        alerts = await health_service.check_anomalies(db, cid)
        if alerts:
            logger.warning(f"Anomaly alerts detected for cattle_id={cid}: {alerts}")
        else:
            logger.debug(f"No anomalies detected for cattle_id={cid}")
        return {
            "success": True,
            "data": {"time": str(reading.time), "alerts": alerts},
            "message": "Sensor data recorded",
        }
    except Exception as e:
        logger.error(f"Failed to ingest sensor data for cattle_id={cid}: {e}")
        raise


@router.get("/cattle/{cattle_id}/sensors")
async def get_sensor_history(
    cattle_id: str,
    hours: int = Query(24, le=168),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /cattle/{cattle_id}/sensors called | user_id={current_user.id} | hours={hours}")
    cid = await _verify_cattle_ownership(db, current_user, cattle_id)
    end = datetime.now(timezone.utc)
    start = end - timedelta(hours=hours)
    logger.debug(f"Fetching sensor readings | cattle_id={cid} | from={start} | to={end}")
    readings = await health_repo.get_sensor_readings(db, cid, start, end)
    logger.info(f"Sensor history retrieved | cattle_id={cid} | readings_count={len(readings)}")
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
    logger.info(f"GET /cattle/{cattle_id}/sensors/latest called | user_id={current_user.id}")
    cid = await _verify_cattle_ownership(db, current_user, cattle_id)
    logger.debug(f"Fetching latest sensor reading | cattle_id={cid}")
    latest = await health_repo.get_latest_sensor(db, cid)
    if not latest:
        logger.info(f"No sensor data available for cattle_id={cid}")
        return {"success": True, "data": None, "message": "No sensor data"}
    logger.info(f"Latest sensor reading found | cattle_id={cid} | time={latest.time} | temp={latest.temperature}")
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
    logger.info(f"GET /cattle/{cattle_id}/sensors/stats called | user_id={current_user.id} | hours={hours}")
    cid = await _verify_cattle_ownership(db, current_user, cattle_id)
    logger.debug(f"Fetching sensor stats | cattle_id={cid} | hours={hours}")
    stats = await health_repo.get_sensor_stats(db, cid, hours=hours)
    logger.info(f"Sensor stats retrieved | cattle_id={cid}")
    return {"success": True, "data": stats, "message": "Sensor statistics"}


@router.get("/cattle/{cattle_id}/health-dashboard")
async def get_health_dashboard(
    cattle_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /cattle/{cattle_id}/health-dashboard called | user_id={current_user.id}")
    cid = await _verify_cattle_ownership(db, current_user, cattle_id)
    logger.debug(f"Calling health_service.get_cattle_health_dashboard | cattle_id={cid}")
    dashboard = await health_service.get_cattle_health_dashboard(db, cid)
    logger.info(f"Health dashboard retrieved | cattle_id={cid}")
    return {"success": True, "data": dashboard, "message": "Health dashboard"}
