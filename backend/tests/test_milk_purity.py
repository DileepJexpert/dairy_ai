"""Tests for the Milk Purity Checker — public API (no auth) + scoring engine."""
import pytest
from dataclasses import dataclass, field
from datetime import date, timedelta

from app.services.milk_purity_service import (
    calculate_fat_accuracy_score,
    calculate_snf_compliance_score,
    calculate_adulteration_score,
    calculate_bacterial_score,
    calculate_fssai_compliance_score,
    calculate_purity_score,
    _score_band,
    _slugify,
)
from app.models.milk_purity import ScoreBand, ViolationSeverity


# ---------------------------------------------------------------------------
# Lightweight stub objects for unit tests (avoid SQLAlchemy instrumentation)
# ---------------------------------------------------------------------------

@dataclass
class FakeBrand:
    name: str = "Test Brand"
    slug: str = "test-brand"
    label_fat_pct: float | None = 3.0
    label_snf_pct: float | None = 8.5
    is_active: bool = True


@dataclass
class FakeReport:
    actual_fat_pct: float | None = None
    actual_snf_pct: float | None = None
    urea_detected: bool = False
    detergent_detected: bool = False
    starch_detected: bool = False
    neutraliser_detected: bool = False
    hydrogen_peroxide_detected: bool = False
    antibiotic_residue_detected: bool = False
    total_plate_count: int | None = None
    coliform_count: int | None = None


@dataclass
class FakeViolation:
    violation_date: date = field(default_factory=date.today)
    severity: ViolationSeverity = ViolationSeverity.minor
    is_recall: bool = False
    is_licence_suspension: bool = False


def _make_brand(**kwargs):
    return FakeBrand(**kwargs)


def _make_report(**kwargs):
    return FakeReport(**kwargs)


def _make_violation(**kwargs):
    return FakeViolation(**kwargs)


# ---------------------------------------------------------------------------
# Unit tests — scoring engine
# ---------------------------------------------------------------------------

class TestScoringEngine:
    def test_slugify(self):
        assert _slugify("Amul Taaza") == "amul-taaza"
        assert _slugify("Mother Dairy Full Cream!") == "mother-dairy-full-cream"

    def test_score_band_excellent(self):
        assert _score_band(90) == ScoreBand.excellent
        assert _score_band(85) == ScoreBand.excellent

    def test_score_band_good(self):
        assert _score_band(75) == ScoreBand.good
        assert _score_band(70) == ScoreBand.good

    def test_score_band_caution(self):
        assert _score_band(60) == ScoreBand.caution
        assert _score_band(50) == ScoreBand.caution

    def test_score_band_poor(self):
        assert _score_band(40) == ScoreBand.poor
        assert _score_band(0) == ScoreBand.poor

    # -- Fat accuracy --
    def test_fat_accuracy_perfect(self):
        brand = _make_brand(label_fat_pct=3.0)
        reports = [_make_report(actual_fat_pct=3.0)]
        assert calculate_fat_accuracy_score(brand, reports) == 100.0

    def test_fat_accuracy_deviation(self):
        brand = _make_brand(label_fat_pct=3.0)
        reports = [_make_report(actual_fat_pct=2.0)]
        score = calculate_fat_accuracy_score(brand, reports)
        assert score == 80.0  # 1% deviation = 2 * 10 = 20 penalty

    def test_fat_accuracy_no_data(self):
        brand = _make_brand(label_fat_pct=3.0)
        assert calculate_fat_accuracy_score(brand, []) == 100.0

    # -- SNF compliance --
    def test_snf_compliance_above_minimum(self):
        reports = [_make_report(actual_snf_pct=9.0)]
        assert calculate_snf_compliance_score(reports) == 100.0

    def test_snf_compliance_below_minimum(self):
        reports = [_make_report(actual_snf_pct=7.5)]
        score = calculate_snf_compliance_score(reports)
        assert score < 100.0
        assert score > 0.0

    # -- Adulteration --
    def test_adulteration_clean(self):
        reports = [_make_report()]
        assert calculate_adulteration_score(reports) == 100.0

    def test_adulteration_urea_detected(self):
        reports = [_make_report(urea_detected=True)]
        score = calculate_adulteration_score(reports)
        assert score == 50.0  # urea = −50

    def test_adulteration_multiple(self):
        reports = [_make_report(urea_detected=True, detergent_detected=True)]
        score = calculate_adulteration_score(reports)
        assert score == 0.0  # −50 −50 = 0

    def test_adulteration_starch(self):
        reports = [_make_report(starch_detected=True)]
        score = calculate_adulteration_score(reports)
        assert score == 70.0  # starch = −30

    # -- Bacterial count --
    def test_bacterial_excellent(self):
        reports = [_make_report(total_plate_count=20000)]
        assert calculate_bacterial_score(reports) == 100.0

    def test_bacterial_high_tpc(self):
        reports = [_make_report(total_plate_count=600000)]
        score = calculate_bacterial_score(reports)
        assert score < 65.0  # above caution threshold

    def test_bacterial_high_coliform(self):
        reports = [_make_report(coliform_count=50)]
        score = calculate_bacterial_score(reports)
        assert score < 100.0

    # -- FSSAI compliance --
    def test_fssai_clean(self):
        assert calculate_fssai_compliance_score([]) == 100.0

    def test_fssai_minor_violation(self):
        violations = [_make_violation(severity=ViolationSeverity.minor)]
        score = calculate_fssai_compliance_score(violations)
        assert score == 90.0

    def test_fssai_major_violation(self):
        violations = [_make_violation(severity=ViolationSeverity.major)]
        score = calculate_fssai_compliance_score(violations)
        assert score == 80.0

    def test_fssai_recall(self):
        violations = [_make_violation(is_recall=True)]
        score = calculate_fssai_compliance_score(violations)
        assert score == 70.0

    def test_fssai_old_violations_ignored(self):
        old_date = date.today() - timedelta(days=4 * 365)
        violations = [_make_violation(violation_date=old_date)]
        assert calculate_fssai_compliance_score(violations) == 100.0

    # -- Full score calculation --
    def test_full_score_perfect(self):
        brand = _make_brand(label_fat_pct=3.0)
        reports = [_make_report(actual_fat_pct=3.0, actual_snf_pct=9.0, total_plate_count=20000)]
        result = calculate_purity_score(brand, reports, [])
        assert result["overall_score"] == 100.0
        assert result["band"] == ScoreBand.excellent

    def test_full_score_with_adulterant(self):
        brand = _make_brand(label_fat_pct=3.0)
        reports = [_make_report(actual_fat_pct=3.0, actual_snf_pct=9.0, urea_detected=True)]
        result = calculate_purity_score(brand, reports, [])
        # Adulteration (30% weight) gets 50 → 50 * 0.30 = 15 lost
        assert result["overall_score"] < 90.0
        assert result["adulteration_score"] == 50.0

    def test_full_score_poor_brand(self):
        brand = _make_brand(label_fat_pct=3.0)
        reports = [
            _make_report(
                actual_fat_pct=1.0,  # 2% off = 40 penalty
                actual_snf_pct=6.0,  # way below
                urea_detected=True,
                detergent_detected=True,
                total_plate_count=1_000_000,
            ),
        ]
        violations = [
            _make_violation(severity=ViolationSeverity.critical),
            _make_violation(severity=ViolationSeverity.major),
        ]
        result = calculate_purity_score(brand, reports, violations)
        assert result["overall_score"] < 50.0
        assert result["band"] == ScoreBand.poor

    def test_limited_data_flag(self):
        brand = _make_brand()
        result = calculate_purity_score(brand, [], [])
        assert result["has_limited_data"] is True
        assert result["data_sources_count"] == 0


# ---------------------------------------------------------------------------
# API tests — public endpoints (no auth)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
class TestPurityAPI:
    async def test_search_brands(self, client):
        resp = await client.get("/api/v1/purity/search?q=amul")
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert "brands" in data["data"]

    async def test_search_brands_empty_query(self, client):
        resp = await client.get("/api/v1/purity/search?q=")
        assert resp.status_code == 422  # validation error: min_length=1

    async def test_brand_score_not_found(self, client):
        resp = await client.get("/api/v1/purity/brand/nonexistent-brand")
        assert resp.status_code == 404

    async def test_compare_not_found(self, client):
        resp = await client.get("/api/v1/purity/compare?brand_a=a&brand_b=b")
        assert resp.status_code == 404

    async def test_top_brands(self, client):
        resp = await client.get("/api/v1/purity/top")
        assert resp.status_code == 200
        assert resp.json()["success"] is True

    async def test_waitlist_signup(self, client):
        resp = await client.post("/api/v1/purity/waitlist", json={
            "email": "test@example.com",
            "name": "Test User",
            "city": "Mumbai",
        })
        assert resp.status_code == 200
        assert resp.json()["data"]["success"] is True

    async def test_waitlist_duplicate(self, client):
        await client.post("/api/v1/purity/waitlist", json={"email": "dup@example.com"})
        resp = await client.post("/api/v1/purity/waitlist", json={"email": "dup@example.com"})
        assert resp.status_code == 200
        assert resp.json()["data"]["already_registered"] is True

    async def test_request_brand(self, client):
        resp = await client.post("/api/v1/purity/request-brand", json={
            "brand_name": "New Local Brand",
            "city": "Jaipur",
            "email": "user@example.com",
        })
        assert resp.status_code == 200
        assert resp.json()["data"]["new_request"] is True

    async def test_request_brand_upvote(self, client):
        await client.post("/api/v1/purity/request-brand", json={"brand_name": "Votable Brand"})
        resp = await client.post("/api/v1/purity/request-brand", json={"brand_name": "Votable Brand"})
        assert resp.status_code == 200
        assert resp.json()["data"]["votes"] == 2

    async def test_score_history_not_found(self, client):
        resp = await client.get("/api/v1/purity/brand/nonexistent/history")
        assert resp.status_code == 200
        assert resp.json()["data"]["count"] == 0
