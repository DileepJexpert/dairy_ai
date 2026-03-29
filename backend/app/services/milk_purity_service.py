"""Milk Purity Checker — scoring engine and business logic.

Scoring weights (from BRD):
  - Fat content accuracy:     20%
  - SNF compliance:           15%
  - Adulteration test:        30%
  - Bacterial count:          20%
  - FSSAI compliance history: 15%

Score bands:
  85-100 Excellent (green)
  70-84  Good (amber)
  50-69  Caution (orange)
  0-49   Poor (red)
"""
import logging
import re
import uuid
from datetime import datetime, date, timedelta

from sqlalchemy import select, func, or_, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.milk_purity import (
    MilkBrand, LabReport, FSSAIViolation, PurityScore,
    PurityWaitlist, BrandRequest, PurityScoreAlert,
    ScoreBand, MilkVariant, ViolationSeverity, LabReportStatus,
    BrandRequestStatus,
)

logger = logging.getLogger("dairy_ai.services.milk_purity")

# ---------------------------------------------------------------------------
# Weight constants
# ---------------------------------------------------------------------------
WEIGHT_FAT = 0.20
WEIGHT_SNF = 0.15
WEIGHT_ADULTERATION = 0.30
WEIGHT_BACTERIAL = 0.20
WEIGHT_FSSAI = 0.15

# FSSAI minimum SNF standard
FSSAI_MIN_SNF = 8.5  # %

# Bacterial count thresholds (per ml)
TPC_EXCELLENT = 30_000
TPC_GOOD = 100_000
TPC_CAUTION = 500_000
COLIFORM_LIMIT = 10  # per ml


def _slugify(name: str) -> str:
    slug = name.lower().strip()
    slug = re.sub(r"[^a-z0-9]+", "-", slug)
    return slug.strip("-")


def _score_band(score: float) -> ScoreBand:
    if score >= 85:
        return ScoreBand.excellent
    elif score >= 70:
        return ScoreBand.good
    elif score >= 50:
        return ScoreBand.caution
    return ScoreBand.poor


def _band_label(band: ScoreBand) -> dict:
    labels = {
        ScoreBand.excellent: {"label": "Excellent", "color": "green", "action": "Highly reliable. Continue purchasing."},
        ScoreBand.good: {"label": "Good", "color": "amber", "action": "Acceptable with minor flags. Monitor updates."},
        ScoreBand.caution: {"label": "Caution", "color": "orange", "action": "Concerns flagged. Consider alternatives."},
        ScoreBand.poor: {"label": "Poor", "color": "red", "action": "Significant issues. Avoid or report."},
    }
    return labels[band]


# ---------------------------------------------------------------------------
# Scoring engine
# ---------------------------------------------------------------------------

def calculate_fat_accuracy_score(brand: MilkBrand, reports: list[LabReport]) -> float:
    """Score fat content accuracy: deviation from label claim."""
    if not reports or brand.label_fat_pct is None:
        return 100.0  # no data — neutral

    fat_readings = [r.actual_fat_pct for r in reports if r.actual_fat_pct is not None]
    if not fat_readings:
        return 100.0

    avg_fat = sum(fat_readings) / len(fat_readings)
    deviation = abs(avg_fat - brand.label_fat_pct)

    # Each 0.5% deviation = −10 points
    penalty = (deviation / 0.5) * 10
    return max(0.0, 100.0 - penalty)


def calculate_snf_compliance_score(reports: list[LabReport]) -> float:
    """Score SNF compliance against FSSAI minimum (8.5%)."""
    snf_readings = [r.actual_snf_pct for r in reports if r.actual_snf_pct is not None]
    if not snf_readings:
        return 100.0

    avg_snf = sum(snf_readings) / len(snf_readings)
    if avg_snf >= FSSAI_MIN_SNF:
        return 100.0

    # Proportional penalty below minimum
    deficit = FSSAI_MIN_SNF - avg_snf
    penalty = min(100.0, (deficit / FSSAI_MIN_SNF) * 200)
    return max(0.0, 100.0 - penalty)


def calculate_adulteration_score(reports: list[LabReport]) -> float:
    """Score based on adulterant detection. Any detection = heavy penalty."""
    if not reports:
        return 100.0

    score = 100.0
    adulterant_flags = []

    for r in reports:
        if r.urea_detected:
            adulterant_flags.append("urea")
        if r.detergent_detected:
            adulterant_flags.append("detergent")
        if r.neutraliser_detected:
            adulterant_flags.append("neutraliser")
        if r.starch_detected:
            adulterant_flags.append("starch")
        if r.hydrogen_peroxide_detected:
            adulterant_flags.append("hydrogen_peroxide")
        if r.antibiotic_residue_detected:
            adulterant_flags.append("antibiotic_residue")

    if not adulterant_flags:
        return 100.0

    # Urea, detergent, neutraliser = −50 each (severe)
    severe = {"urea", "detergent", "neutraliser"}
    # Others = −30 each
    unique_flags = set(adulterant_flags)

    for flag in unique_flags:
        if flag in severe:
            score -= 50.0
        else:
            score -= 30.0

    return max(0.0, score)


def calculate_bacterial_score(reports: list[LabReport]) -> float:
    """Score based on total plate count and coliform count."""
    tpc_readings = [r.total_plate_count for r in reports if r.total_plate_count is not None]
    coliform_readings = [r.coliform_count for r in reports if r.coliform_count is not None]

    if not tpc_readings and not coliform_readings:
        return 100.0

    score = 100.0

    if tpc_readings:
        avg_tpc = sum(tpc_readings) / len(tpc_readings)
        if avg_tpc <= TPC_EXCELLENT:
            pass  # full score
        elif avg_tpc <= TPC_GOOD:
            score -= 15.0
        elif avg_tpc <= TPC_CAUTION:
            score -= 35.0
        else:
            score -= 60.0

    if coliform_readings:
        avg_coliform = sum(coliform_readings) / len(coliform_readings)
        if avg_coliform > COLIFORM_LIMIT:
            excess_ratio = avg_coliform / COLIFORM_LIMIT
            score -= min(40.0, excess_ratio * 10)

    return max(0.0, score)


def calculate_fssai_compliance_score(violations: list[FSSAIViolation]) -> float:
    """Score based on FSSAI violation history (past 3 years)."""
    cutoff = date.today() - timedelta(days=3 * 365)
    recent = [v for v in violations if v.violation_date >= cutoff]

    if not recent:
        return 100.0

    score = 100.0
    for v in recent:
        if v.severity == ViolationSeverity.critical or v.is_recall or v.is_licence_suspension:
            score -= 30.0
        elif v.severity == ViolationSeverity.major:
            score -= 20.0
        else:  # minor
            score -= 10.0

    return max(0.0, score)


def calculate_purity_score(
    brand: MilkBrand,
    reports: list[LabReport],
    violations: list[FSSAIViolation],
) -> dict:
    """Calculate the full weighted purity score for a brand."""
    fat_score = calculate_fat_accuracy_score(brand, reports)
    snf_score = calculate_snf_compliance_score(reports)
    adulteration_score = calculate_adulteration_score(reports)
    bacterial_score = calculate_bacterial_score(reports)
    fssai_score = calculate_fssai_compliance_score(violations)

    overall = (
        fat_score * WEIGHT_FAT
        + snf_score * WEIGHT_SNF
        + adulteration_score * WEIGHT_ADULTERATION
        + bacterial_score * WEIGHT_BACTERIAL
        + fssai_score * WEIGHT_FSSAI
    )
    overall = round(overall, 1)
    band = _score_band(overall)
    data_sources = len(reports) + (1 if violations else 0)

    return {
        "overall_score": overall,
        "band": band,
        "fat_accuracy_score": round(fat_score, 1),
        "snf_compliance_score": round(snf_score, 1),
        "adulteration_score": round(adulteration_score, 1),
        "bacterial_score": round(bacterial_score, 1),
        "fssai_compliance_score": round(fssai_score, 1),
        "data_sources_count": data_sources,
        "has_limited_data": data_sources < 2,
    }


# ---------------------------------------------------------------------------
# DB operations
# ---------------------------------------------------------------------------

async def search_brands(
    db: AsyncSession,
    query: str,
    region: str | None = None,
    state: str | None = None,
    limit: int = 20,
) -> list[dict]:
    """Search brands by name with optional region filter. Public — no auth."""
    stmt = (
        select(MilkBrand)
        .where(MilkBrand.is_active.is_(True))
        .where(MilkBrand.name.ilike(f"%{query}%"))
        .order_by(MilkBrand.name)
        .limit(limit)
    )

    if state:
        stmt = stmt.where(MilkBrand.available_states.contains([state]))

    result = await db.execute(stmt)
    brands = result.scalars().all()

    items = []
    for b in brands:
        # Get latest score
        score_stmt = (
            select(PurityScore)
            .where(PurityScore.brand_id == b.id)
            .order_by(desc(PurityScore.calculated_at))
            .limit(1)
        )
        score_result = await db.execute(score_stmt)
        score = score_result.scalar_one_or_none()

        items.append({
            "id": str(b.id),
            "name": b.name,
            "slug": b.slug,
            "parent_company": b.parent_company,
            "variant": b.variant.value,
            "logo_url": b.logo_url,
            "score": score.overall_score if score else None,
            "band": score.band.value if score else None,
        })
    return items


async def get_brand_score(db: AsyncSession, brand_slug: str) -> dict | None:
    """Get full purity score breakdown for a brand by slug. Public — no auth."""
    stmt = select(MilkBrand).where(MilkBrand.slug == brand_slug)
    result = await db.execute(stmt)
    brand = result.scalar_one_or_none()
    if not brand:
        return None

    # Get lab reports
    reports_stmt = (
        select(LabReport)
        .where(LabReport.brand_id == brand.id)
        .where(LabReport.status == LabReportStatus.completed)
        .order_by(desc(LabReport.report_date))
    )
    reports_result = await db.execute(reports_stmt)
    reports = list(reports_result.scalars().all())

    # Get FSSAI violations
    violations_stmt = select(FSSAIViolation).where(FSSAIViolation.brand_id == brand.id)
    violations_result = await db.execute(violations_stmt)
    violations = list(violations_result.scalars().all())

    # Calculate live score
    score_data = calculate_purity_score(brand, reports, violations)
    band_info = _band_label(score_data["band"])

    return {
        "brand": {
            "id": str(brand.id),
            "name": brand.name,
            "slug": brand.slug,
            "parent_company": brand.parent_company,
            "variant": brand.variant.value,
            "label_fat_pct": brand.label_fat_pct,
            "label_snf_pct": brand.label_snf_pct,
            "fssai_licence_no": brand.fssai_licence_no,
            "logo_url": brand.logo_url,
        },
        "score": {
            "overall": score_data["overall_score"],
            "band": score_data["band"].value,
            "band_label": band_info["label"],
            "band_color": band_info["color"],
            "verdict": band_info["action"],
            "has_limited_data": score_data["has_limited_data"],
            "data_sources_count": score_data["data_sources_count"],
        },
        "parameters": {
            "fat_accuracy": {"score": score_data["fat_accuracy_score"], "weight": "20%", "description": "Deviation of actual fat % from label claim"},
            "snf_compliance": {"score": score_data["snf_compliance_score"], "weight": "15%", "description": "Solids-not-fat measured vs FSSAI minimum"},
            "adulteration": {"score": score_data["adulteration_score"], "weight": "30%", "description": "Presence of urea, detergent, neutralisers, starch, H2O2"},
            "bacterial_count": {"score": score_data["bacterial_score"], "weight": "20%", "description": "Total plate count and coliform count per ml"},
            "fssai_compliance": {"score": score_data["fssai_compliance_score"], "weight": "15%", "description": "Violations, recalls, enforcement orders"},
        },
        "lab_reports_count": len(reports),
        "violations_count": len(violations),
    }


async def get_brand_by_id(db: AsyncSession, brand_id: uuid.UUID) -> dict | None:
    """Get brand score by UUID."""
    stmt = select(MilkBrand).where(MilkBrand.id == brand_id)
    result = await db.execute(stmt)
    brand = result.scalar_one_or_none()
    if not brand:
        return None
    return await get_brand_score(db, brand.slug)


async def compare_brands(db: AsyncSession, slug_a: str, slug_b: str) -> dict | None:
    """Compare two brands side by side."""
    brand_a = await get_brand_score(db, slug_a)
    brand_b = await get_brand_score(db, slug_b)

    if not brand_a or not brand_b:
        return None

    # Calculate deltas
    params_a = brand_a["parameters"]
    params_b = brand_b["parameters"]
    deltas = {}
    for param in params_a:
        delta = round(params_a[param]["score"] - params_b[param]["score"], 1)
        deltas[param] = {
            "brand_a_score": params_a[param]["score"],
            "brand_b_score": params_b[param]["score"],
            "delta": delta,
            "better": "A" if delta > 0 else ("B" if delta < 0 else "tie"),
        }

    return {
        "brand_a": brand_a,
        "brand_b": brand_b,
        "overall_delta": round(brand_a["score"]["overall"] - brand_b["score"]["overall"], 1),
        "parameter_deltas": deltas,
    }


async def get_top_brands(
    db: AsyncSession,
    state: str | None = None,
    limit: int = 10,
) -> list[dict]:
    """Get top-scored brands. Public."""
    stmt = (
        select(PurityScore, MilkBrand)
        .join(MilkBrand, PurityScore.brand_id == MilkBrand.id)
        .where(MilkBrand.is_active.is_(True))
        .order_by(desc(PurityScore.overall_score))
        .limit(limit)
    )
    result = await db.execute(stmt)
    rows = result.all()

    items = []
    seen_brands = set()
    for score, brand in rows:
        if brand.id in seen_brands:
            continue
        seen_brands.add(brand.id)
        band_info = _band_label(score.band)
        items.append({
            "rank": len(items) + 1,
            "brand_name": brand.name,
            "slug": brand.slug,
            "variant": brand.variant.value,
            "score": score.overall_score,
            "band": score.band.value,
            "band_color": band_info["color"],
            "logo_url": brand.logo_url,
        })
    return items


async def get_score_history(db: AsyncSession, brand_slug: str) -> list[dict]:
    """Get historical score versions for a brand."""
    stmt = select(MilkBrand).where(MilkBrand.slug == brand_slug)
    result = await db.execute(stmt)
    brand = result.scalar_one_or_none()
    if not brand:
        return []

    scores_stmt = (
        select(PurityScore)
        .where(PurityScore.brand_id == brand.id)
        .order_by(desc(PurityScore.calculated_at))
    )
    scores_result = await db.execute(scores_stmt)
    scores = scores_result.scalars().all()

    return [
        {
            "version": s.version,
            "overall_score": s.overall_score,
            "band": s.band.value,
            "calculated_at": s.calculated_at.isoformat(),
        }
        for s in scores
    ]


# ---------------------------------------------------------------------------
# Waitlist & alerts
# ---------------------------------------------------------------------------

async def join_waitlist(
    db: AsyncSession,
    email: str,
    name: str | None = None,
    phone: str | None = None,
    city: str | None = None,
    state: str | None = None,
    preferred_brands: list[str] | None = None,
    source: str | None = None,
) -> dict:
    """Add user to waitlist. Public — no auth."""
    # Check duplicate
    existing = await db.execute(
        select(PurityWaitlist).where(PurityWaitlist.email == email)
    )
    if existing.scalar_one_or_none():
        return {"success": True, "already_registered": True, "message": "You're already on the waitlist!"}

    entry = PurityWaitlist(
        email=email,
        name=name,
        phone=phone,
        city=city,
        state=state,
        preferred_brands=preferred_brands,
        source=source or "purity_checker",
    )
    db.add(entry)
    return {"success": True, "already_registered": False, "message": "Welcome! You've joined the waitlist."}


async def subscribe_score_alert(
    db: AsyncSession, email: str, brand_slug: str
) -> dict:
    """Subscribe to score change alerts for a brand. Public."""
    brand_result = await db.execute(
        select(MilkBrand).where(MilkBrand.slug == brand_slug)
    )
    brand = brand_result.scalar_one_or_none()
    if not brand:
        return {"success": False, "message": "Brand not found"}

    existing = await db.execute(
        select(PurityScoreAlert).where(
            PurityScoreAlert.email == email,
            PurityScoreAlert.brand_id == brand.id,
        )
    )
    if existing.scalar_one_or_none():
        return {"success": True, "already_subscribed": True, "message": "Already subscribed to alerts"}

    alert = PurityScoreAlert(email=email, brand_id=brand.id)
    db.add(alert)
    return {"success": True, "already_subscribed": False, "message": "You'll be notified when this brand's score changes"}


async def request_brand(
    db: AsyncSession,
    brand_name: str,
    variant: str | None = None,
    city: str | None = None,
    email: str | None = None,
) -> dict:
    """Request a brand be added to the database. Public."""
    # Check if already requested — increment vote
    existing = await db.execute(
        select(BrandRequest).where(
            func.lower(BrandRequest.brand_name) == brand_name.lower()
        )
    )
    req = existing.scalar_one_or_none()
    if req:
        req.vote_count += 1
        return {"success": True, "new_request": False, "votes": req.vote_count, "message": f"Request upvoted! {req.vote_count} people want this brand."}

    new_req = BrandRequest(
        brand_name=brand_name,
        variant=variant,
        city=city,
        requested_by_email=email,
    )
    db.add(new_req)
    return {"success": True, "new_request": True, "votes": 1, "message": "Brand request submitted! We'll add it soon."}


# ---------------------------------------------------------------------------
# Admin operations
# ---------------------------------------------------------------------------

async def admin_add_brand(db: AsyncSession, data: dict) -> MilkBrand:
    """Add a new brand (admin)."""
    brand = MilkBrand(
        name=data["name"],
        slug=_slugify(data["name"]),
        parent_company=data.get("parent_company"),
        variant=MilkVariant(data.get("variant", "toned")),
        available_regions=data.get("available_regions"),
        available_states=data.get("available_states"),
        price_range_min=data.get("price_range_min"),
        price_range_max=data.get("price_range_max"),
        packaging_type=data.get("packaging_type"),
        label_fat_pct=data.get("label_fat_pct"),
        label_snf_pct=data.get("label_snf_pct"),
        fssai_licence_no=data.get("fssai_licence_no"),
        logo_url=data.get("logo_url"),
    )
    db.add(brand)
    await db.flush()
    return brand


async def admin_add_lab_report(db: AsyncSession, data: dict) -> LabReport:
    """Add a lab report for a brand (admin)."""
    report = LabReport(
        brand_id=uuid.UUID(data["brand_id"]),
        lab_name=data["lab_name"],
        lab_accreditation=data.get("lab_accreditation", "NABL"),
        report_date=date.fromisoformat(data["report_date"]),
        report_pdf_url=data.get("report_pdf_url"),
        actual_fat_pct=data.get("actual_fat_pct"),
        actual_snf_pct=data.get("actual_snf_pct"),
        urea_detected=data.get("urea_detected", False),
        detergent_detected=data.get("detergent_detected", False),
        starch_detected=data.get("starch_detected", False),
        neutraliser_detected=data.get("neutraliser_detected", False),
        hydrogen_peroxide_detected=data.get("hydrogen_peroxide_detected", False),
        total_plate_count=data.get("total_plate_count"),
        coliform_count=data.get("coliform_count"),
        aflatoxin_m1_ppb=data.get("aflatoxin_m1_ppb"),
        antibiotic_residue_detected=data.get("antibiotic_residue_detected", False),
        added_water_pct=data.get("added_water_pct"),
        notes=data.get("notes"),
    )
    db.add(report)
    await db.flush()
    return report


async def admin_add_violation(db: AsyncSession, data: dict) -> FSSAIViolation:
    """Add an FSSAI violation record (admin)."""
    violation = FSSAIViolation(
        brand_id=uuid.UUID(data["brand_id"]),
        violation_date=date.fromisoformat(data["violation_date"]),
        severity=ViolationSeverity(data["severity"]),
        violation_type=data["violation_type"],
        description=data.get("description"),
        order_number=data.get("order_number"),
        penalty_amount=data.get("penalty_amount"),
        is_recall=data.get("is_recall", False),
        is_licence_suspension=data.get("is_licence_suspension", False),
        source_url=data.get("source_url"),
    )
    db.add(violation)
    await db.flush()
    return violation


async def admin_recalculate_score(db: AsyncSession, brand_id: uuid.UUID) -> PurityScore | None:
    """Recalculate and store a new version of the purity score for a brand."""
    brand_result = await db.execute(
        select(MilkBrand).where(MilkBrand.id == brand_id)
    )
    brand = brand_result.scalar_one_or_none()
    if not brand:
        return None

    reports_result = await db.execute(
        select(LabReport)
        .where(LabReport.brand_id == brand_id, LabReport.status == LabReportStatus.completed)
    )
    reports = list(reports_result.scalars().all())

    violations_result = await db.execute(
        select(FSSAIViolation).where(FSSAIViolation.brand_id == brand_id)
    )
    violations = list(violations_result.scalars().all())

    score_data = calculate_purity_score(brand, reports, violations)

    # Get latest version number
    ver_result = await db.execute(
        select(func.max(PurityScore.version)).where(PurityScore.brand_id == brand_id)
    )
    latest_version = ver_result.scalar() or 0

    new_score = PurityScore(
        brand_id=brand_id,
        version=latest_version + 1,
        overall_score=score_data["overall_score"],
        band=score_data["band"],
        fat_accuracy_score=score_data["fat_accuracy_score"],
        snf_compliance_score=score_data["snf_compliance_score"],
        adulteration_score=score_data["adulteration_score"],
        bacterial_score=score_data["bacterial_score"],
        fssai_compliance_score=score_data["fssai_compliance_score"],
        data_sources_count=score_data["data_sources_count"],
        has_limited_data=score_data["has_limited_data"],
    )
    db.add(new_score)
    await db.flush()
    return new_score


async def admin_get_waitlist_stats(db: AsyncSession) -> dict:
    """Get waitlist analytics."""
    total = await db.execute(select(func.count(PurityWaitlist.id)))
    by_source = await db.execute(
        select(PurityWaitlist.source, func.count(PurityWaitlist.id))
        .group_by(PurityWaitlist.source)
    )
    by_city = await db.execute(
        select(PurityWaitlist.city, func.count(PurityWaitlist.id))
        .where(PurityWaitlist.city.isnot(None))
        .group_by(PurityWaitlist.city)
        .order_by(desc(func.count(PurityWaitlist.id)))
        .limit(20)
    )

    return {
        "total_signups": total.scalar() or 0,
        "by_source": {row[0] or "direct": row[1] for row in by_source.all()},
        "top_cities": {row[0]: row[1] for row in by_city.all()},
    }


async def admin_get_brand_requests(db: AsyncSession) -> list[dict]:
    """Get all brand requests sorted by votes."""
    result = await db.execute(
        select(BrandRequest).order_by(desc(BrandRequest.vote_count))
    )
    requests = result.scalars().all()
    return [
        {
            "id": str(r.id),
            "brand_name": r.brand_name,
            "variant": r.variant,
            "city": r.city,
            "votes": r.vote_count,
            "status": r.status.value,
            "requested_by": r.requested_by_email,
            "created_at": r.created_at.isoformat(),
        }
        for r in requests
    ]


# ---------------------------------------------------------------------------
# Seed demo data (top Indian milk brands)
# ---------------------------------------------------------------------------

async def seed_demo_brands(db: AsyncSession) -> int:
    """Seed database with top Indian milk brands and sample data."""
    brands_data = [
        {"name": "Amul Taaza", "parent_company": "GCMMF (Amul)", "variant": "toned", "label_fat_pct": 3.0, "label_snf_pct": 8.5, "available_states": ["Gujarat", "Maharashtra", "Delhi", "Karnataka", "Tamil Nadu"], "fssai_licence_no": "10014011000001"},
        {"name": "Amul Gold", "parent_company": "GCMMF (Amul)", "variant": "full_cream", "label_fat_pct": 6.0, "label_snf_pct": 9.0, "available_states": ["Gujarat", "Maharashtra", "Delhi", "Karnataka"], "fssai_licence_no": "10014011000001"},
        {"name": "Mother Dairy Full Cream", "parent_company": "Mother Dairy", "variant": "full_cream", "label_fat_pct": 6.0, "label_snf_pct": 9.0, "available_states": ["Delhi", "Uttar Pradesh", "Rajasthan", "Haryana"], "fssai_licence_no": "10015011000192"},
        {"name": "Mother Dairy Toned", "parent_company": "Mother Dairy", "variant": "toned", "label_fat_pct": 3.0, "label_snf_pct": 8.5, "available_states": ["Delhi", "Uttar Pradesh", "Rajasthan"], "fssai_licence_no": "10015011000192"},
        {"name": "Nandini Toned Milk", "parent_company": "KMF (Nandini)", "variant": "toned", "label_fat_pct": 3.0, "label_snf_pct": 8.5, "available_states": ["Karnataka"], "fssai_licence_no": "10017011000223"},
        {"name": "Nandini Goodlife", "parent_company": "KMF (Nandini)", "variant": "standardised", "label_fat_pct": 4.5, "label_snf_pct": 8.5, "available_states": ["Karnataka"], "fssai_licence_no": "10017011000223"},
        {"name": "Verka Full Cream", "parent_company": "Milkfed Punjab", "variant": "full_cream", "label_fat_pct": 6.0, "label_snf_pct": 9.0, "available_states": ["Punjab", "Haryana", "Delhi"], "fssai_licence_no": "10018011000334"},
        {"name": "Aavin Toned Milk", "parent_company": "Tamil Nadu Coop", "variant": "toned", "label_fat_pct": 3.0, "label_snf_pct": 8.5, "available_states": ["Tamil Nadu"], "fssai_licence_no": "10019011000445"},
        {"name": "Saras Full Cream", "parent_company": "RCDF (Rajasthan)", "variant": "full_cream", "label_fat_pct": 6.0, "label_snf_pct": 9.0, "available_states": ["Rajasthan", "Delhi"], "fssai_licence_no": "10020011000556"},
        {"name": "Gokul Full Cream", "parent_company": "Kolhapur Coop", "variant": "full_cream", "label_fat_pct": 6.0, "label_snf_pct": 9.0, "available_states": ["Maharashtra"], "fssai_licence_no": "10021011000667"},
        {"name": "Heritage Fresh Milk", "parent_company": "Heritage Foods", "variant": "toned", "label_fat_pct": 3.0, "label_snf_pct": 8.5, "available_states": ["Andhra Pradesh", "Telangana", "Karnataka", "Tamil Nadu"], "fssai_licence_no": "10022011000778"},
        {"name": "Milma Toned Milk", "parent_company": "KCMMF (Kerala)", "variant": "toned", "label_fat_pct": 3.0, "label_snf_pct": 8.5, "available_states": ["Kerala"], "fssai_licence_no": "10023011000889"},
        {"name": "Parag Gowardhan", "parent_company": "Parag Milk Foods", "variant": "full_cream", "label_fat_pct": 6.0, "label_snf_pct": 9.0, "available_states": ["Maharashtra", "Gujarat", "Delhi"], "fssai_licence_no": "10024011000990"},
        {"name": "Nestle a+ Nourish", "parent_company": "Nestle India", "variant": "toned", "label_fat_pct": 3.0, "label_snf_pct": 8.5, "available_states": ["Delhi", "Punjab", "Haryana", "Rajasthan"], "fssai_licence_no": "10025011001101"},
        {"name": "Dodla Full Cream", "parent_company": "Dodla Dairy", "variant": "full_cream", "label_fat_pct": 6.0, "label_snf_pct": 9.0, "available_states": ["Andhra Pradesh", "Telangana", "Karnataka"], "fssai_licence_no": "10026011001212"},
        {"name": "Tirumala Full Cream", "parent_company": "Lactalis India", "variant": "full_cream", "label_fat_pct": 6.0, "label_snf_pct": 9.0, "available_states": ["Andhra Pradesh", "Telangana"], "fssai_licence_no": "10027011001323"},
        {"name": "Prabhat Full Cream", "parent_company": "Prabhat Dairy", "variant": "full_cream", "label_fat_pct": 6.0, "label_snf_pct": 9.0, "available_states": ["Maharashtra"], "fssai_licence_no": "10028011001434"},
        {"name": "Sudha Toned Milk", "parent_company": "COMFED Bihar", "variant": "toned", "label_fat_pct": 3.0, "label_snf_pct": 8.5, "available_states": ["Bihar", "Jharkhand"], "fssai_licence_no": "10029011001545"},
        {"name": "Sanchi Full Cream", "parent_company": "MP State Coop", "variant": "full_cream", "label_fat_pct": 6.0, "label_snf_pct": 9.0, "available_states": ["Madhya Pradesh"], "fssai_licence_no": "10030011001656"},
        {"name": "Country Delight Milk", "parent_company": "Country Delight", "variant": "full_cream", "label_fat_pct": 6.0, "label_snf_pct": 9.0, "available_states": ["Delhi", "Mumbai", "Bangalore", "Hyderabad", "Pune"], "fssai_licence_no": "10031011001767"},
        {"name": "Organic Tattva A2 Milk", "parent_company": "Organic Tattva", "variant": "a2", "label_fat_pct": 3.5, "label_snf_pct": 8.5, "available_states": ["Delhi", "Maharashtra", "Karnataka"], "fssai_licence_no": "10032011001878"},
        {"name": "Akshayakalpa Organic", "parent_company": "Akshayakalpa", "variant": "organic", "label_fat_pct": 3.5, "label_snf_pct": 8.5, "available_states": ["Karnataka", "Tamil Nadu"], "fssai_licence_no": "10033011001989"},
        {"name": "Sid's Farm A2 Milk", "parent_company": "Sid's Farm", "variant": "a2", "label_fat_pct": 4.0, "label_snf_pct": 8.5, "available_states": ["Telangana", "Andhra Pradesh"], "fssai_licence_no": "10034011002090"},
        {"name": "Kwality Walls Milk", "parent_company": "Kwality Ltd", "variant": "toned", "label_fat_pct": 3.0, "label_snf_pct": 8.5, "available_states": ["Delhi", "Uttar Pradesh", "Rajasthan"], "fssai_licence_no": "10035011002101"},
        {"name": "Vita Toned Milk", "parent_company": "Haryana Dairy", "variant": "toned", "label_fat_pct": 3.0, "label_snf_pct": 8.5, "available_states": ["Haryana", "Delhi"], "fssai_licence_no": "10036011002212"},
        {"name": "Mahanand Full Cream", "parent_company": "Mahanand Dairy", "variant": "full_cream", "label_fat_pct": 6.0, "label_snf_pct": 9.0, "available_states": ["Maharashtra"], "fssai_licence_no": "10037011002323"},
        {"name": "Dudhsagar Full Cream", "parent_company": "Mehsana Coop", "variant": "full_cream", "label_fat_pct": 6.0, "label_snf_pct": 9.0, "available_states": ["Gujarat"], "fssai_licence_no": "10038011002434"},
        {"name": "Paras Full Cream", "parent_company": "VRS Foods", "variant": "full_cream", "label_fat_pct": 6.0, "label_snf_pct": 9.0, "available_states": ["Uttar Pradesh", "Delhi", "Bihar"], "fssai_licence_no": "10039011002545"},
        {"name": "Pride of Cows", "parent_company": "Parag Milk Foods", "variant": "full_cream", "label_fat_pct": 6.0, "label_snf_pct": 9.0, "available_states": ["Maharashtra", "Delhi"], "fssai_licence_no": "10040011002656"},
        {"name": "Govardhan Toned Milk", "parent_company": "Parag Milk Foods", "variant": "toned", "label_fat_pct": 3.0, "label_snf_pct": 8.5, "available_states": ["Maharashtra", "Delhi"], "fssai_licence_no": "10041011002767"},
    ]

    count = 0
    for bd in brands_data:
        slug = _slugify(bd["name"])
        existing = await db.execute(select(MilkBrand).where(MilkBrand.slug == slug))
        if existing.scalar_one_or_none():
            continue

        brand = MilkBrand(
            name=bd["name"],
            slug=slug,
            parent_company=bd.get("parent_company"),
            variant=MilkVariant(bd["variant"]),
            available_states=bd.get("available_states"),
            label_fat_pct=bd.get("label_fat_pct"),
            label_snf_pct=bd.get("label_snf_pct"),
            fssai_licence_no=bd.get("fssai_licence_no"),
        )
        db.add(brand)
        count += 1

    await db.flush()
    logger.info(f"Seeded {count} milk brands")
    return count
