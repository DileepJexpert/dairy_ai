"""Milk Purity Checker API — PUBLIC (no auth required).

All consumer-facing endpoints are open. Admin endpoints require auth.
This is the viral growth engine: anyone can check milk brand purity scores.
"""
import logging
import uuid

from fastapi import APIRouter, Depends, Query, HTTPException
from pydantic import BaseModel, EmailStr
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.services import milk_purity_service

logger = logging.getLogger("dairy_ai.api.milk_purity")
router = APIRouter(tags=["Milk Purity Checker"])

# ---------------------------------------------------------------------------
# Pydantic schemas
# ---------------------------------------------------------------------------


class WaitlistRequest(BaseModel):
    email: str
    name: str | None = None
    phone: str | None = None
    city: str | None = None
    state: str | None = None
    preferred_brands: list[str] | None = None
    source: str | None = None


class AlertSubscribeRequest(BaseModel):
    email: str
    brand_slug: str


class BrandRequestBody(BaseModel):
    brand_name: str
    variant: str | None = None
    city: str | None = None
    email: str | None = None


class AdminBrandCreate(BaseModel):
    name: str
    parent_company: str | None = None
    variant: str = "toned"
    available_states: list[str] | None = None
    available_regions: list[str] | None = None
    price_range_min: float | None = None
    price_range_max: float | None = None
    packaging_type: str | None = None
    label_fat_pct: float | None = None
    label_snf_pct: float | None = None
    fssai_licence_no: str | None = None
    logo_url: str | None = None


class AdminLabReportCreate(BaseModel):
    brand_id: str
    lab_name: str
    lab_accreditation: str | None = "NABL"
    report_date: str
    report_pdf_url: str | None = None
    actual_fat_pct: float | None = None
    actual_snf_pct: float | None = None
    urea_detected: bool = False
    detergent_detected: bool = False
    starch_detected: bool = False
    neutraliser_detected: bool = False
    hydrogen_peroxide_detected: bool = False
    total_plate_count: int | None = None
    coliform_count: int | None = None
    aflatoxin_m1_ppb: float | None = None
    antibiotic_residue_detected: bool = False
    added_water_pct: float | None = None
    notes: str | None = None


class AdminViolationCreate(BaseModel):
    brand_id: str
    violation_date: str
    severity: str
    violation_type: str
    description: str | None = None
    order_number: str | None = None
    penalty_amount: float | None = None
    is_recall: bool = False
    is_licence_suspension: bool = False
    source_url: str | None = None


# ---------------------------------------------------------------------------
# PUBLIC ENDPOINTS (no auth) — available on home page
# ---------------------------------------------------------------------------

@router.get("/purity/search")
async def search_brands(
    q: str = Query(..., min_length=1, description="Brand name to search"),
    state: str | None = None,
    limit: int = Query(20, ge=1, le=50),
    db: AsyncSession = Depends(get_db),
):
    """Search milk brands by name. No login required."""
    results = await milk_purity_service.search_brands(db, q, state=state, limit=limit)
    return {
        "success": True,
        "data": {"brands": results, "count": len(results), "query": q},
        "message": f"Found {len(results)} brands matching '{q}'",
    }


@router.get("/purity/brand/{brand_slug}")
async def get_brand_score(
    brand_slug: str,
    db: AsyncSession = Depends(get_db),
):
    """Get full purity score for a brand. No login required."""
    result = await milk_purity_service.get_brand_score(db, brand_slug)
    if not result:
        raise HTTPException(status_code=404, detail="Brand not found")
    return {
        "success": True,
        "data": result,
        "message": f"Purity score for {result['brand']['name']}",
        "disclaimer": "This score is an informational assessment based on publicly available data and independently commissioned lab reports. It is not a certification. See methodology for details.",
    }


@router.get("/purity/compare")
async def compare_brands(
    brand_a: str = Query(..., description="First brand slug"),
    brand_b: str = Query(..., description="Second brand slug"),
    db: AsyncSession = Depends(get_db),
):
    """Compare two brands side by side. No login required."""
    result = await milk_purity_service.compare_brands(db, brand_a, brand_b)
    if not result:
        raise HTTPException(status_code=404, detail="One or both brands not found")
    return {
        "success": True,
        "data": result,
        "message": f"Comparison: {result['brand_a']['brand']['name']} vs {result['brand_b']['brand']['name']}",
    }


@router.get("/purity/top")
async def get_top_brands(
    state: str | None = None,
    limit: int = Query(10, ge=1, le=50),
    db: AsyncSession = Depends(get_db),
):
    """Get top-scored brands. No login required."""
    results = await milk_purity_service.get_top_brands(db, state=state, limit=limit)
    return {
        "success": True,
        "data": {"brands": results, "count": len(results)},
        "message": f"Top {len(results)} brands by purity score",
    }


@router.get("/purity/brand/{brand_slug}/history")
async def get_score_history(
    brand_slug: str,
    db: AsyncSession = Depends(get_db),
):
    """Get historical score versions for a brand. No login required."""
    history = await milk_purity_service.get_score_history(db, brand_slug)
    return {
        "success": True,
        "data": {"history": history, "count": len(history)},
        "message": "Score history retrieved",
    }


@router.post("/purity/waitlist")
async def join_waitlist(
    body: WaitlistRequest,
    db: AsyncSession = Depends(get_db),
):
    """Join the product waitlist. No login required."""
    result = await milk_purity_service.join_waitlist(
        db,
        email=body.email,
        name=body.name,
        phone=body.phone,
        city=body.city,
        state=body.state,
        preferred_brands=body.preferred_brands,
        source=body.source,
    )
    await db.commit()
    return {"success": True, "data": result, "message": result["message"]}


@router.post("/purity/alerts/subscribe")
async def subscribe_alert(
    body: AlertSubscribeRequest,
    db: AsyncSession = Depends(get_db),
):
    """Subscribe to score change alerts for a brand. No login required."""
    result = await milk_purity_service.subscribe_score_alert(db, body.email, body.brand_slug)
    await db.commit()
    return {"success": True, "data": result, "message": result["message"]}


@router.post("/purity/request-brand")
async def request_brand(
    body: BrandRequestBody,
    db: AsyncSession = Depends(get_db),
):
    """Request a brand be tested and added. No login required."""
    result = await milk_purity_service.request_brand(
        db,
        brand_name=body.brand_name,
        variant=body.variant,
        city=body.city,
        email=body.email,
    )
    await db.commit()
    return {"success": True, "data": result, "message": result["message"]}


# ---------------------------------------------------------------------------
# ADMIN ENDPOINTS (auth required)
# ---------------------------------------------------------------------------

@router.post("/purity/admin/brands")
async def admin_add_brand(
    body: AdminBrandCreate,
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    """Add a new milk brand (admin only)."""
    if user.role.value not in ("admin", "super_admin"):
        raise HTTPException(status_code=403, detail="Admin access required")
    brand = await milk_purity_service.admin_add_brand(db, body.model_dump())
    await db.commit()
    return {
        "success": True,
        "data": {"id": str(brand.id), "name": brand.name, "slug": brand.slug},
        "message": f"Brand '{brand.name}' added",
    }


@router.post("/purity/admin/lab-reports")
async def admin_add_lab_report(
    body: AdminLabReportCreate,
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    """Add a lab report for a brand (admin only)."""
    if user.role.value not in ("admin", "super_admin"):
        raise HTTPException(status_code=403, detail="Admin access required")
    report = await milk_purity_service.admin_add_lab_report(db, body.model_dump())
    await db.commit()
    return {
        "success": True,
        "data": {"id": str(report.id), "brand_id": str(report.brand_id)},
        "message": "Lab report added",
    }


@router.post("/purity/admin/violations")
async def admin_add_violation(
    body: AdminViolationCreate,
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    """Add an FSSAI violation record (admin only)."""
    if user.role.value not in ("admin", "super_admin"):
        raise HTTPException(status_code=403, detail="Admin access required")
    violation = await milk_purity_service.admin_add_violation(db, body.model_dump())
    await db.commit()
    return {
        "success": True,
        "data": {"id": str(violation.id)},
        "message": "FSSAI violation recorded",
    }


@router.post("/purity/admin/recalculate/{brand_id}")
async def admin_recalculate(
    brand_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    """Recalculate purity score for a brand (admin only)."""
    if user.role.value not in ("admin", "super_admin"):
        raise HTTPException(status_code=403, detail="Admin access required")
    score = await milk_purity_service.admin_recalculate_score(db, brand_id)
    if not score:
        raise HTTPException(status_code=404, detail="Brand not found")
    await db.commit()
    return {
        "success": True,
        "data": {
            "brand_id": str(score.brand_id),
            "version": score.version,
            "overall_score": score.overall_score,
            "band": score.band.value,
        },
        "message": f"Score recalculated: {score.overall_score}/100 ({score.band.value})",
    }


@router.get("/purity/admin/waitlist-stats")
async def admin_waitlist_stats(
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    """Get waitlist analytics (admin only)."""
    if user.role.value not in ("admin", "super_admin"):
        raise HTTPException(status_code=403, detail="Admin access required")
    stats = await milk_purity_service.admin_get_waitlist_stats(db)
    return {"success": True, "data": stats, "message": "Waitlist analytics"}


@router.get("/purity/admin/brand-requests")
async def admin_brand_requests(
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    """Get all brand requests (admin only)."""
    if user.role.value not in ("admin", "super_admin"):
        raise HTTPException(status_code=403, detail="Admin access required")
    requests = await milk_purity_service.admin_get_brand_requests(db)
    return {"success": True, "data": {"requests": requests, "count": len(requests)}, "message": "Brand requests"}


@router.post("/purity/admin/seed")
async def admin_seed_brands(
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    """Seed demo brands (admin only)."""
    if user.role.value not in ("admin", "super_admin"):
        raise HTTPException(status_code=403, detail="Admin access required")
    count = await milk_purity_service.seed_demo_brands(db)
    await db.commit()
    return {"success": True, "data": {"seeded": count}, "message": f"Seeded {count} milk brands"}
