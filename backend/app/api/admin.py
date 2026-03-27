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

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/dashboard")
async def admin_dashboard(
    current_user: User = Depends(require_role(UserRole.admin)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    total_farmers = (await db.execute(select(func.count(Farmer.id)))).scalar() or 0
    total_cattle = (await db.execute(select(func.count(Cattle.id)))).scalar() or 0
    total_vets = (await db.execute(select(func.count(VetProfile.id)))).scalar() or 0

    today = date.today()
    active_consults = (await db.execute(
        select(func.count(Consultation.id))
        .where(Consultation.status.in_(["requested", "assigned", "in_progress"]))
    )).scalar() or 0

    milk_today = (await db.execute(
        select(func.sum(MilkRecord.quantity_litres))
        .where(MilkRecord.date == today)
    )).scalar() or 0

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
    farmers, total = await farmer_repo.list_all(db, limit=limit, offset=offset, search=search)
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
    query = select(VetProfile)
    if verified is not None:
        query = query.where(VetProfile.is_verified == verified)
    query = query.offset(offset).limit(limit)
    result = await db.execute(query)
    vets = list(result.scalars().all())

    count_query = select(func.count(VetProfile.id))
    if verified is not None:
        count_query = count_query.where(VetProfile.is_verified == verified)
    total = (await db.execute(count_query)).scalar() or 0

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
    query = select(Consultation)
    if status:
        query = query.where(Consultation.status == status)
    query = query.order_by(Consultation.created_at.desc()).offset(offset).limit(limit)
    result = await db.execute(query)
    consults = list(result.scalars().all())
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
    cutoff = date.today() - timedelta(days=days)
    result = await db.execute(
        select(func.date(User.created_at).label("day"), func.count(User.id).label("count"))
        .where(User.created_at >= str(cutoff))
        .group_by(func.date(User.created_at))
        .order_by(func.date(User.created_at))
    )
    data = [{"date": str(row.day), "count": row.count} for row in result.all()]
    return {"success": True, "data": data, "message": "Registration analytics"}
