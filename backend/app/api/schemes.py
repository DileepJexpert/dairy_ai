"""Government Scheme Navigator API."""
import logging
import uuid
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.services import scheme_service

logger = logging.getLogger("dairy_ai.api.schemes")
router = APIRouter(prefix="/schemes", tags=["Government Schemes"])


@router.get("")
async def list_schemes(
    category: str | None = None,
    level: str | None = None,
    state: str | None = None,
    is_active: bool = True,
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    """List all government schemes with optional filters."""
    schemes = await scheme_service.get_all_schemes(db, category, level, state, is_active)
    data = [
        {
            "id": str(s.id), "name": s.name, "short_name": s.short_name,
            "category": s.category.value, "level": s.level.value,
            "description": s.description, "subsidy_amount_max": s.subsidy_amount_max,
            "subsidy_percentage": s.subsidy_percentage, "nodal_agency": s.nodal_agency,
            "is_active": s.is_active, "last_date": str(s.last_date) if s.last_date else None,
        }
        for s in schemes
    ]
    return {"success": True, "data": {"schemes": data, "count": len(data)}, "message": "Schemes retrieved"}


@router.get("/{scheme_id}")
async def get_scheme(
    scheme_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    """Get full details of a scheme."""
    scheme = await scheme_service.get_scheme_detail(db, scheme_id)
    if not scheme:
        return {"success": False, "data": None, "message": "Scheme not found"}
    return {
        "success": True,
        "data": {
            "id": str(scheme.id), "name": scheme.name, "short_name": scheme.short_name,
            "category": scheme.category.value, "level": scheme.level.value,
            "description": scheme.description, "benefits": scheme.benefits,
            "subsidy_amount_max": scheme.subsidy_amount_max,
            "subsidy_percentage": scheme.subsidy_percentage,
            "required_documents": scheme.required_documents,
            "applicable_states": scheme.applicable_states,
            "min_cattle_count": scheme.min_cattle_count,
            "max_cattle_count": scheme.max_cattle_count,
            "nodal_agency": scheme.nodal_agency,
            "implementing_agency": scheme.implementing_agency,
            "is_active": scheme.is_active,
            "last_date": str(scheme.last_date) if scheme.last_date else None,
            "application_url": scheme.application_url,
            "helpline": scheme.helpline,
        },
        "message": f"Scheme: {scheme.name}",
    }


@router.get("/{scheme_id}/eligibility/{farmer_id}")
async def check_eligibility(
    scheme_id: uuid.UUID,
    farmer_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    """Check if a farmer is eligible for a scheme."""
    result = await scheme_service.check_eligibility(db, farmer_id, scheme_id)
    return {"success": True, "data": result, "message": "Eligibility checked"}


@router.get("/recommendations/{farmer_id}")
async def get_recommendations(
    farmer_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    """Get recommended schemes for a farmer based on eligibility."""
    recommended = await scheme_service.get_recommended_schemes(db, farmer_id)
    return {
        "success": True,
        "data": {"schemes": recommended, "count": len(recommended)},
        "message": f"Found {len(recommended)} eligible schemes",
    }


@router.post("/{scheme_id}/apply/{farmer_id}")
async def apply_for_scheme(
    scheme_id: uuid.UUID,
    farmer_id: uuid.UUID,
    documents: list | None = None,
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    """Submit a scheme application for a farmer."""
    app = await scheme_service.apply_for_scheme(db, farmer_id, user.id, scheme_id, documents)
    await db.commit()
    return {
        "success": True,
        "data": {
            "id": str(app.id), "scheme_id": str(app.scheme_id),
            "farmer_id": str(app.farmer_id), "status": app.status,
            "applied_at": str(app.applied_at),
        },
        "message": "Application submitted successfully",
    }


@router.get("/applications/my")
async def get_my_applications(
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    """Get all scheme applications for the current user."""
    apps = await scheme_service.get_my_applications(db, user.id)
    data = [
        {
            "id": str(a.id), "scheme_id": str(a.scheme_id),
            "farmer_id": str(a.farmer_id), "status": a.status,
            "applied_at": str(a.applied_at),
            "reviewed_at": str(a.reviewed_at) if a.reviewed_at else None,
            "disbursed_at": str(a.disbursed_at) if a.disbursed_at else None,
            "notes": a.notes,
        }
        for a in apps
    ]
    return {"success": True, "data": {"applications": data, "count": len(data)}, "message": "Applications retrieved"}


@router.patch("/applications/{application_id}")
async def update_application_status(
    application_id: uuid.UUID,
    status: str = Query(...),
    notes: str | None = None,
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    """Update application status (admin/vet only)."""
    app = await scheme_service.update_application_status(db, application_id, status, notes)
    if not app:
        return {"success": False, "data": None, "message": "Application not found"}
    await db.commit()
    return {
        "success": True,
        "data": {"id": str(app.id), "status": app.status},
        "message": f"Application status updated to {status}",
    }


@router.post("/{scheme_id}/bookmark")
async def toggle_bookmark(
    scheme_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    """Toggle bookmark on a scheme."""
    bookmarked = await scheme_service.toggle_bookmark(db, scheme_id, user.id)
    await db.commit()
    return {
        "success": True,
        "data": {"bookmarked": bookmarked, "scheme_id": str(scheme_id)},
        "message": "Scheme bookmarked" if bookmarked else "Bookmark removed",
    }


@router.get("/bookmarks/my")
async def get_my_bookmarks(
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    """Get all bookmarked schemes for the current user."""
    schemes = await scheme_service.get_my_bookmarks(db, user.id)
    data = [
        {
            "id": str(s.id), "name": s.name, "short_name": s.short_name,
            "category": s.category.value, "level": s.level.value,
            "subsidy_amount_max": s.subsidy_amount_max,
        }
        for s in schemes
    ]
    return {"success": True, "data": {"schemes": data, "count": len(data)}, "message": "Bookmarks retrieved"}


@router.post("/seed")
async def seed_schemes(
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    """Admin: seed government schemes data."""
    if user.role.value not in ("admin", "super_admin"):
        return {"success": False, "data": None, "message": "Admin access required"}
    count = await scheme_service.seed_schemes(db)
    await db.commit()
    return {"success": True, "data": {"seeded": count}, "message": f"Seeded {count} government schemes"}
