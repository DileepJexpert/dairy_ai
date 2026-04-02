import uuid
import logging

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user, require_role
from app.models.user import User, UserRole
from app.models.outbreak import ReportStatus
from app.repositories import farmer_repo
from app.services import outbreak_service

logger = logging.getLogger("dairy_ai.api.outbreak")

router = APIRouter(prefix="/outbreak", tags=["Disease Outbreak"])


async def _get_farmer_id(db: AsyncSession, user: User) -> uuid.UUID:
    farmer = await farmer_repo.get_by_user_id(db, user.id)
    if not farmer:
        raise HTTPException(status_code=404, detail="Farmer profile not found. Create profile first.")
    return farmer.id


async def _get_farmer(db: AsyncSession, user: User):
    farmer = await farmer_repo.get_by_user_id(db, user.id)
    if not farmer:
        raise HTTPException(status_code=404, detail="Farmer profile not found. Create profile first.")
    return farmer


@router.post("/report", status_code=201)
async def report_disease(
    data: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Farmer reports a disease occurrence."""
    logger.info(f"POST /outbreak/report called | user_id={current_user.id}")
    farmer_id = await _get_farmer_id(db, current_user)

    required_fields = ["disease_name", "severity", "lat", "lng"]
    for field in required_fields:
        if field not in data:
            logger.warning(f"Missing required field: {field}")
            raise HTTPException(status_code=422, detail=f"Missing required field: {field}")

    try:
        report = await outbreak_service.report_disease(db, farmer_id, data)
        logger.info(f"Disease report created | report_id={report.id}")
        return {
            "success": True,
            "data": {
                "id": str(report.id),
                "disease_name": report.disease_name,
                "severity": report.severity.value,
                "status": report.status.value,
                "reported_at": str(report.reported_at),
            },
            "message": "Disease report submitted successfully",
        }
    except Exception as e:
        logger.error(f"Failed to create disease report: {e}")
        raise HTTPException(status_code=500, detail="Failed to submit disease report")


@router.get("/map")
async def get_outbreak_map(
    state: str | None = Query(None, description="Filter by state"),
    district: str | None = Query(None, description="Filter by district"),
    radius_km: float = Query(50.0, ge=1, le=500, description="Search radius in km"),
    lat: float | None = Query(None, description="Center latitude"),
    lng: float | None = Query(None, description="Center longitude"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Get outbreak zones and recent reports for map display."""
    logger.info(f"GET /outbreak/map called | user_id={current_user.id} | state={state} | district={district}")
    try:
        map_data = await outbreak_service.get_outbreak_map(
            db, state=state, district=district, radius_km=radius_km, lat=lat, lng=lng,
        )
        logger.info(f"Outbreak map retrieved | zones={len(map_data['zones'])} | reports={len(map_data['reports'])}")
        return {
            "success": True,
            "data": map_data,
            "message": "Outbreak map data retrieved",
        }
    except Exception as e:
        logger.error(f"Failed to get outbreak map: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve outbreak map")


@router.get("/nearby")
async def get_nearby_alerts(
    lat: float = Query(..., description="Farmer latitude"),
    lng: float = Query(..., description="Farmer longitude"),
    radius_km: float = Query(30.0, ge=1, le=200, description="Search radius in km"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Get active outbreak alerts near farmer's location."""
    logger.info(f"GET /outbreak/nearby called | user_id={current_user.id} | lat={lat} | lng={lng}")
    try:
        alerts = await outbreak_service.get_nearby_alerts(db, lat, lng, radius_km)
        logger.info(f"Nearby alerts retrieved | count={len(alerts)}")
        return {
            "success": True,
            "data": alerts,
            "message": f"Found {len(alerts)} nearby outbreak alerts",
        }
    except Exception as e:
        logger.error(f"Failed to get nearby alerts: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve nearby alerts")


@router.get("/trends")
async def get_disease_trends(
    district: str = Query(..., description="District name"),
    months: int = Query(6, ge=1, le=24, description="Number of months to look back"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Get disease trends by district."""
    logger.info(f"GET /outbreak/trends called | user_id={current_user.id} | district={district} | months={months}")
    try:
        trends = await outbreak_service.get_disease_trends(db, district, months)
        logger.info(f"Disease trends retrieved | district={district} | data_points={len(trends)}")
        return {
            "success": True,
            "data": trends,
            "message": f"Disease trends for {district} over last {months} months",
        }
    except Exception as e:
        logger.error(f"Failed to get disease trends: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve disease trends")


@router.put("/reports/{report_id}/confirm")
async def confirm_report(
    report_id: str,
    data: dict,
    current_user: User = Depends(require_role(UserRole.vet, UserRole.admin)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Vet or admin confirms a disease report."""
    logger.info(f"PUT /outbreak/reports/{report_id}/confirm called | user_id={current_user.id}")

    status_str = data.get("status", "confirmed")
    confirmed_by = data.get("confirmed_by", current_user.phone)

    try:
        report_status = ReportStatus(status_str)
    except ValueError:
        raise HTTPException(status_code=422, detail=f"Invalid status: {status_str}. Must be one of: {[s.value for s in ReportStatus]}")

    try:
        report = await outbreak_service.update_report_status(
            db, uuid.UUID(report_id), report_status, confirmed_by,
        )
        logger.info(f"Report confirmed | report_id={report.id} | status={report.status.value}")
        return {
            "success": True,
            "data": {
                "id": str(report.id),
                "disease_name": report.disease_name,
                "status": report.status.value,
                "is_confirmed": report.is_confirmed,
                "confirmed_by": report.confirmed_by,
            },
            "message": "Disease report status updated",
        }
    except ValueError as e:
        logger.warning(f"Report not found: {e}")
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        logger.error(f"Failed to confirm report: {e}")
        raise HTTPException(status_code=500, detail="Failed to update report status")


@router.get("/zones")
async def list_active_zones(
    state: str | None = Query(None),
    district: str | None = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """List all active outbreak zones."""
    logger.info(f"GET /outbreak/zones called | user_id={current_user.id} | state={state} | district={district}")
    try:
        # Reuse get_outbreak_map but only return zones
        map_data = await outbreak_service.get_outbreak_map(
            db, state=state, district=district,
        )
        zones = map_data["zones"]
        logger.info(f"Active zones retrieved | count={len(zones)}")
        return {
            "success": True,
            "data": zones,
            "message": f"Found {len(zones)} active outbreak zones",
        }
    except Exception as e:
        logger.error(f"Failed to list outbreak zones: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve outbreak zones")
