"""Milk Purity Checker models — brand scores, lab reports, FSSAI violations."""
import uuid
import enum
from datetime import datetime, date

from sqlalchemy import (
    String, Float, Integer, Boolean, DateTime, Date, Text,
    ForeignKey, Enum as SAEnum, UniqueConstraint, Index,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID, JSON

from app.database import Base


# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

class ScoreBand(str, enum.Enum):
    excellent = "excellent"   # 85-100
    good = "good"             # 70-84
    caution = "caution"       # 50-69
    poor = "poor"             # 0-49


class MilkVariant(str, enum.Enum):
    full_cream = "full_cream"
    toned = "toned"
    double_toned = "double_toned"
    standardised = "standardised"
    organic = "organic"
    a2 = "a2"
    flavoured = "flavoured"
    skimmed = "skimmed"


class ViolationSeverity(str, enum.Enum):
    minor = "minor"
    major = "major"
    critical = "critical"


class LabReportStatus(str, enum.Enum):
    pending = "pending"
    completed = "completed"
    disputed = "disputed"


class BrandRequestStatus(str, enum.Enum):
    pending = "pending"
    in_progress = "in_progress"
    completed = "completed"
    rejected = "rejected"


# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------

class MilkBrand(Base):
    """Packaged milk brand master data."""
    __tablename__ = "milk_brands"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    name: Mapped[str] = mapped_column(String(200), nullable=False, index=True)
    slug: Mapped[str] = mapped_column(String(200), nullable=False, unique=True, index=True)
    parent_company: Mapped[str | None] = mapped_column(String(200), nullable=True)
    variant: Mapped[MilkVariant] = mapped_column(
        SAEnum(MilkVariant), default=MilkVariant.toned, nullable=False
    )
    available_regions: Mapped[list | None] = mapped_column(JSON, nullable=True)
    available_states: Mapped[list | None] = mapped_column(JSON, nullable=True)
    price_range_min: Mapped[float | None] = mapped_column(Float, nullable=True)
    price_range_max: Mapped[float | None] = mapped_column(Float, nullable=True)
    packaging_type: Mapped[str | None] = mapped_column(String(50), nullable=True)
    label_fat_pct: Mapped[float | None] = mapped_column(Float, nullable=True)
    label_snf_pct: Mapped[float | None] = mapped_column(Float, nullable=True)
    fssai_licence_no: Mapped[str | None] = mapped_column(String(50), nullable=True)
    logo_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    # Relationships
    lab_reports = relationship("LabReport", back_populates="brand", lazy="selectin")
    fssai_violations = relationship("FSSAIViolation", back_populates="brand", lazy="selectin")
    scores = relationship("PurityScore", back_populates="brand", lazy="selectin")


class LabReport(Base):
    """Independent lab test results for a brand."""
    __tablename__ = "lab_reports"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    brand_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("milk_brands.id"), nullable=False, index=True
    )
    lab_name: Mapped[str] = mapped_column(String(200), nullable=False)
    lab_accreditation: Mapped[str | None] = mapped_column(String(100), nullable=True)
    report_date: Mapped[date] = mapped_column(Date, nullable=False)
    report_pdf_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    status: Mapped[LabReportStatus] = mapped_column(
        SAEnum(LabReportStatus), default=LabReportStatus.completed, nullable=False
    )

    # Test results
    actual_fat_pct: Mapped[float | None] = mapped_column(Float, nullable=True)
    actual_snf_pct: Mapped[float | None] = mapped_column(Float, nullable=True)
    urea_detected: Mapped[bool] = mapped_column(Boolean, default=False)
    detergent_detected: Mapped[bool] = mapped_column(Boolean, default=False)
    starch_detected: Mapped[bool] = mapped_column(Boolean, default=False)
    neutraliser_detected: Mapped[bool] = mapped_column(Boolean, default=False)
    hydrogen_peroxide_detected: Mapped[bool] = mapped_column(Boolean, default=False)
    total_plate_count: Mapped[int | None] = mapped_column(Integer, nullable=True)
    coliform_count: Mapped[int | None] = mapped_column(Integer, nullable=True)
    aflatoxin_m1_ppb: Mapped[float | None] = mapped_column(Float, nullable=True)
    antibiotic_residue_detected: Mapped[bool] = mapped_column(Boolean, default=False)
    added_water_pct: Mapped[float | None] = mapped_column(Float, nullable=True)

    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    brand = relationship("MilkBrand", back_populates="lab_reports")


class FSSAIViolation(Base):
    """FSSAI enforcement records for a brand."""
    __tablename__ = "fssai_violations"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    brand_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("milk_brands.id"), nullable=False, index=True
    )
    violation_date: Mapped[date] = mapped_column(Date, nullable=False)
    severity: Mapped[ViolationSeverity] = mapped_column(
        SAEnum(ViolationSeverity), nullable=False
    )
    violation_type: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    order_number: Mapped[str | None] = mapped_column(String(100), nullable=True)
    penalty_amount: Mapped[float | None] = mapped_column(Float, nullable=True)
    is_recall: Mapped[bool] = mapped_column(Boolean, default=False)
    is_licence_suspension: Mapped[bool] = mapped_column(Boolean, default=False)
    source_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    brand = relationship("MilkBrand", back_populates="fssai_violations")


class PurityScore(Base):
    """Versioned purity scores for brands."""
    __tablename__ = "purity_scores"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    brand_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("milk_brands.id"), nullable=False, index=True
    )
    version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    overall_score: Mapped[float] = mapped_column(Float, nullable=False)
    band: Mapped[ScoreBand] = mapped_column(SAEnum(ScoreBand), nullable=False)

    # Parameter scores (0-100 each)
    fat_accuracy_score: Mapped[float] = mapped_column(Float, nullable=False, default=100.0)
    snf_compliance_score: Mapped[float] = mapped_column(Float, nullable=False, default=100.0)
    adulteration_score: Mapped[float] = mapped_column(Float, nullable=False, default=100.0)
    bacterial_score: Mapped[float] = mapped_column(Float, nullable=False, default=100.0)
    fssai_compliance_score: Mapped[float] = mapped_column(Float, nullable=False, default=100.0)

    data_sources_count: Mapped[int] = mapped_column(Integer, default=0)
    has_limited_data: Mapped[bool] = mapped_column(Boolean, default=True)
    calculation_details: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    calculated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    brand = relationship("MilkBrand", back_populates="scores")


class PurityWaitlist(Base):
    """Waitlist signups from the purity checker."""
    __tablename__ = "purity_waitlist"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    email: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    name: Mapped[str | None] = mapped_column(String(200), nullable=True)
    phone: Mapped[str | None] = mapped_column(String(15), nullable=True)
    preferred_brands: Mapped[list | None] = mapped_column(JSON, nullable=True)
    city: Mapped[str | None] = mapped_column(String(100), nullable=True)
    state: Mapped[str | None] = mapped_column(String(100), nullable=True)
    source: Mapped[str | None] = mapped_column(String(50), nullable=True)
    referral_code: Mapped[str | None] = mapped_column(String(50), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        UniqueConstraint("email", name="uq_purity_waitlist_email"),
    )


class BrandRequest(Base):
    """User requests to add/test a brand not in database."""
    __tablename__ = "brand_requests"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    brand_name: Mapped[str] = mapped_column(String(200), nullable=False)
    variant: Mapped[str | None] = mapped_column(String(100), nullable=True)
    city: Mapped[str | None] = mapped_column(String(100), nullable=True)
    requested_by_email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    status: Mapped[BrandRequestStatus] = mapped_column(
        SAEnum(BrandRequestStatus), default=BrandRequestStatus.pending, nullable=False
    )
    vote_count: Mapped[int] = mapped_column(Integer, default=1)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )


class PurityScoreAlert(Base):
    """Alerts for users tracking brand score changes."""
    __tablename__ = "purity_score_alerts"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    email: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    brand_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("milk_brands.id"), nullable=False, index=True
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    last_notified_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        UniqueConstraint("email", "brand_id", name="uq_purity_alert_email_brand"),
    )
