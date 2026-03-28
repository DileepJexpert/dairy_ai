import logging
from datetime import date, timedelta

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import require_role
from app.models.user import User, UserRole
from app.models.farmer import Farmer
from app.models.cattle import Cattle
from app.models.vet import VetProfile, Consultation
from app.models.milk import MilkRecord
from app.repositories import farmer_repo

logger = logging.getLogger("dairy_ai.api.admin")

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/dashboard")
async def admin_dashboard(
    current_user: User = Depends(require_role(UserRole.admin)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /admin/dashboard called | admin_user_id={current_user.id}")
    logger.debug("Fetching total farmers count")
    total_farmers = (await db.execute(select(func.count(Farmer.id)))).scalar() or 0
    logger.debug(f"Total farmers: {total_farmers}")

    logger.debug("Fetching total cattle count")
    total_cattle = (await db.execute(select(func.count(Cattle.id)))).scalar() or 0
    logger.debug(f"Total cattle: {total_cattle}")

    logger.debug("Fetching total vets count")
    total_vets = (await db.execute(select(func.count(VetProfile.id)))).scalar() or 0
    logger.debug(f"Total vets: {total_vets}")

    today = date.today()
    logger.debug("Fetching active consultations count")
    active_consults = (await db.execute(
        select(func.count(Consultation.id))
        .where(Consultation.status.in_(["requested", "assigned", "in_progress"]))
    )).scalar() or 0
    logger.debug(f"Active consultations: {active_consults}")

    logger.debug("Fetching today's milk production total")
    milk_today = (await db.execute(
        select(func.sum(MilkRecord.quantity_litres))
        .where(MilkRecord.date == today)
    )).scalar() or 0
    logger.debug(f"Milk today (litres): {milk_today}")

    logger.info(f"Admin dashboard retrieved | farmers={total_farmers} | cattle={total_cattle} | vets={total_vets} | active_consults={active_consults} | milk_today={round(float(milk_today), 2)}L")
    return {
        "success": True,
        "data": {
            "total_farmers": total_farmers,
            "total_cattle": total_cattle,
            "total_vets": total_vets,
            "active_consultations": active_consults,
            "milk_today_litres": round(float(milk_today), 2),
        },
        "message": "Admin dashboard",
    }


@router.get("/farmers")
async def list_farmers(
    search: str | None = Query(None),
    limit: int = Query(20, le=100),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(require_role(UserRole.admin)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /admin/farmers called | admin_user_id={current_user.id} | search={search} | limit={limit} | offset={offset}")
    logger.debug(f"Calling farmer_repo.list_all | search={search} | limit={limit} | offset={offset}")
    farmers, total = await farmer_repo.list_all(db, limit=limit, offset=offset, search=search)
    logger.info(f"Farmers list retrieved | total={total} | returned={len(farmers)}")
    return {
        "success": True,
        "data": [
            {
                "id": str(f.id),
                "name": f.name,
                "village": f.village,
                "district": f.district,
                "total_cattle": f.total_cattle,
            }
            for f in farmers
        ],
        "total": total,
        "message": "Farmers list",
    }


@router.get("/vets")
async def list_vets(
    verified: bool | None = Query(None),
    limit: int = Query(20, le=100),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(require_role(UserRole.admin)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /admin/vets called | admin_user_id={current_user.id} | verified={verified} | limit={limit} | offset={offset}")
    query = select(VetProfile)
    if verified is not None:
        query = query.where(VetProfile.is_verified == verified)
    query = query.offset(offset).limit(limit)
    logger.debug(f"Executing vet query | verified_filter={verified}")
    result = await db.execute(query)
    vets = list(result.scalars().all())

    count_query = select(func.count(VetProfile.id))
    if verified is not None:
        count_query = count_query.where(VetProfile.is_verified == verified)
    total = (await db.execute(count_query)).scalar() or 0
    logger.info(f"Vets list retrieved | total={total} | returned={len(vets)}")

    return {
        "success": True,
        "data": [
            {
                "id": str(v.id),
                "license_number": v.license_number,
                "qualification": v.qualification,
                "is_verified": v.is_verified,
                "rating_avg": v.rating_avg,
                "total_consultations": v.total_consultations,
            }
            for v in vets
        ],
        "total": total,
        "message": "Vets list",
    }


@router.get("/consultations")
async def list_consultations(
    status: str | None = Query(None),
    limit: int = Query(20, le=100),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(require_role(UserRole.admin)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /admin/consultations called | admin_user_id={current_user.id} | status={status} | limit={limit} | offset={offset}")
    query = select(Consultation)
    if status:
        query = query.where(Consultation.status == status)
    query = query.order_by(Consultation.created_at.desc()).offset(offset).limit(limit)
    logger.debug(f"Executing consultations query | status_filter={status}")
    result = await db.execute(query)
    consults = list(result.scalars().all())
    logger.info(f"Consultations list retrieved | returned={len(consults)}")
    return {
        "success": True,
        "data": [
            {
                "id": str(c.id),
                "status": c.status.value if hasattr(c.status, 'value') else c.status,
                "consultation_type": c.consultation_type.value if hasattr(c.consultation_type, 'value') else c.consultation_type,
                "triage_severity": c.triage_severity.value if hasattr(c.triage_severity, 'value') else c.triage_severity if c.triage_severity else None,
                "created_at": str(c.created_at),
            }
            for c in consults
        ],
        "message": "Consultations list",
    }


@router.get("/analytics/registrations")
async def registration_analytics(
    days: int = Query(30, le=90),
    current_user: User = Depends(require_role(UserRole.admin)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /admin/analytics/registrations called | admin_user_id={current_user.id} | days={days}")
    cutoff = date.today() - timedelta(days=days)
    logger.debug(f"Fetching registration analytics | cutoff_date={cutoff} | days={days}")
    result = await db.execute(
        select(func.date(User.created_at).label("day"), func.count(User.id).label("count"))
        .where(User.created_at >= str(cutoff))
        .group_by(func.date(User.created_at))
        .order_by(func.date(User.created_at))
    )
    data = [{"date": str(row.day), "count": row.count} for row in result.all()]
    logger.info(f"Registration analytics retrieved | days={days} | data_points={len(data)}")
    return {"success": True, "data": data, "message": "Registration analytics"}
