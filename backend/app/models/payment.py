"""
Farmer Payment, Loan, and Subsidy models for dairy plant automation.
Covers: Payment cycles, payment line items, loans, EMIs, subsidies.
"""
import uuid
import enum
from datetime import datetime, date

from sqlalchemy import (
    String, Float, Integer, Boolean, DateTime, Date,
    ForeignKey, Text, JSON, Enum as SAEnum,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID

from app.database import Base


# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

class PaymentCycleType(str, enum.Enum):
    weekly = "weekly"
    fortnightly = "fortnightly"
    monthly = "monthly"


class PaymentStatus(str, enum.Enum):
    pending = "pending"
    processing = "processing"
    completed = "completed"
    failed = "failed"


class PaymentMethod(str, enum.Enum):
    upi = "upi"
    bank_transfer = "bank_transfer"
    cash = "cash"
    cheque = "cheque"


class LoanStatus(str, enum.Enum):
    applied = "applied"
    approved = "approved"
    disbursed = "disbursed"
    active = "active"
    closed = "closed"
    defaulted = "defaulted"
    rejected = "rejected"


class LoanType(str, enum.Enum):
    cattle_purchase = "cattle_purchase"
    feed_advance = "feed_advance"
    equipment = "equipment"
    emergency = "emergency"
    dairy_infra = "dairy_infra"


class SubsidyStatus(str, enum.Enum):
    identified = "identified"
    applied = "applied"
    documents_submitted = "documents_submitted"
    under_review = "under_review"
    approved = "approved"
    disbursed = "disbursed"
    rejected = "rejected"


class SubsidyScheme(str, enum.Enum):
    nabard_dairy = "nabard_dairy"
    ndp_ii = "ndp_ii"             # National Dairy Plan II
    didf = "didf"                 # Dairy Infrastructure Development Fund
    state_scheme = "state_scheme"
    pmmsy = "pmmsy"               # PM Matsya Sampada Yojana (related)
    other = "other"


class InsuranceStatus(str, enum.Enum):
    active = "active"
    expired = "expired"
    claimed = "claimed"
    claim_processing = "claim_processing"
    claim_approved = "claim_approved"
    claim_rejected = "claim_rejected"


# ---------------------------------------------------------------------------
# Payment Cycle (weekly/fortnightly payout schedule)
# ---------------------------------------------------------------------------

class PaymentCycle(Base):
    __tablename__ = "payment_cycles"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    cooperative_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("cooperatives.id"), nullable=True, index=True
    )
    cycle_type: Mapped[PaymentCycleType] = mapped_column(SAEnum(PaymentCycleType), nullable=False)
    period_start: Mapped[date] = mapped_column(Date, nullable=False)
    period_end: Mapped[date] = mapped_column(Date, nullable=False)
    total_litres: Mapped[float] = mapped_column(Float, default=0.0)
    total_amount: Mapped[float] = mapped_column(Float, default=0.0)
    total_deductions: Mapped[float] = mapped_column(Float, default=0.0)
    total_bonuses: Mapped[float] = mapped_column(Float, default=0.0)
    net_payout: Mapped[float] = mapped_column(Float, default=0.0)
    farmers_count: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[PaymentStatus] = mapped_column(SAEnum(PaymentStatus), default=PaymentStatus.pending)
    processed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    line_items = relationship("FarmerPayment", back_populates="cycle", lazy="selectin")


# ---------------------------------------------------------------------------
# Farmer Payment (individual farmer payout within a cycle)
# ---------------------------------------------------------------------------

class FarmerPayment(Base):
    __tablename__ = "farmer_payments"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    cycle_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("payment_cycles.id"), nullable=False, index=True
    )
    farmer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("farmers.id"), nullable=False, index=True
    )
    total_litres: Mapped[float] = mapped_column(Float, default=0.0)
    avg_fat_pct: Mapped[float | None] = mapped_column(Float, nullable=True)
    avg_snf_pct: Mapped[float | None] = mapped_column(Float, nullable=True)
    base_amount: Mapped[float] = mapped_column(Float, default=0.0)
    quality_bonus: Mapped[float] = mapped_column(Float, default=0.0)
    loan_deduction: Mapped[float] = mapped_column(Float, default=0.0)
    other_deductions: Mapped[float] = mapped_column(Float, default=0.0)
    net_amount: Mapped[float] = mapped_column(Float, default=0.0)
    payment_method: Mapped[PaymentMethod | None] = mapped_column(SAEnum(PaymentMethod), nullable=True)
    upi_id: Mapped[str | None] = mapped_column(String(100), nullable=True)
    bank_account: Mapped[str | None] = mapped_column(String(20), nullable=True)
    bank_ifsc: Mapped[str | None] = mapped_column(String(15), nullable=True)
    transaction_ref: Mapped[str | None] = mapped_column(String(100), nullable=True)
    status: Mapped[PaymentStatus] = mapped_column(SAEnum(PaymentStatus), default=PaymentStatus.pending)
    paid_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # Relationships
    cycle = relationship("PaymentCycle", back_populates="line_items")


# ---------------------------------------------------------------------------
# Loan
# ---------------------------------------------------------------------------

class Loan(Base):
    __tablename__ = "loans"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    farmer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("farmers.id"), nullable=False, index=True
    )
    loan_type: Mapped[LoanType] = mapped_column(SAEnum(LoanType), nullable=False)
    principal_amount: Mapped[float] = mapped_column(Float, nullable=False)
    interest_rate_pct: Mapped[float] = mapped_column(Float, default=0.0)
    tenure_months: Mapped[int] = mapped_column(Integer, nullable=False)
    emi_amount: Mapped[float] = mapped_column(Float, default=0.0)
    total_paid: Mapped[float] = mapped_column(Float, default=0.0)
    outstanding_amount: Mapped[float] = mapped_column(Float, default=0.0)
    disbursed_at: Mapped[date | None] = mapped_column(Date, nullable=True)
    next_emi_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    status: Mapped[LoanStatus] = mapped_column(SAEnum(LoanStatus), default=LoanStatus.applied)
    purpose: Mapped[str | None] = mapped_column(Text, nullable=True)
    approved_by: Mapped[str | None] = mapped_column(String(100), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


# ---------------------------------------------------------------------------
# Subsidy Tracking
# ---------------------------------------------------------------------------

class SubsidyApplication(Base):
    __tablename__ = "subsidy_applications"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    farmer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("farmers.id"), nullable=False, index=True
    )
    scheme: Mapped[SubsidyScheme] = mapped_column(SAEnum(SubsidyScheme), nullable=False)
    scheme_name: Mapped[str] = mapped_column(String(200), nullable=False)
    applied_amount: Mapped[float] = mapped_column(Float, nullable=False)
    approved_amount: Mapped[float | None] = mapped_column(Float, nullable=True)
    disbursed_amount: Mapped[float | None] = mapped_column(Float, nullable=True)
    application_ref: Mapped[str | None] = mapped_column(String(100), nullable=True)
    documents: Mapped[list | None] = mapped_column(JSON, default=list)
    status: Mapped[SubsidyStatus] = mapped_column(SAEnum(SubsidyStatus), default=SubsidyStatus.identified)
    applied_at: Mapped[date | None] = mapped_column(Date, nullable=True)
    approved_at: Mapped[date | None] = mapped_column(Date, nullable=True)
    disbursed_at: Mapped[date | None] = mapped_column(Date, nullable=True)
    rejection_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


# ---------------------------------------------------------------------------
# Cattle Insurance
# ---------------------------------------------------------------------------

class CattleInsurance(Base):
    __tablename__ = "cattle_insurance"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    farmer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("farmers.id"), nullable=False, index=True
    )
    cattle_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("cattle.id"), nullable=False, index=True
    )
    policy_number: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    insurer_name: Mapped[str] = mapped_column(String(200), nullable=False)
    sum_insured: Mapped[float] = mapped_column(Float, nullable=False)
    premium_amount: Mapped[float] = mapped_column(Float, nullable=False)
    govt_subsidy_pct: Mapped[float] = mapped_column(Float, default=0.0)
    farmer_premium: Mapped[float] = mapped_column(Float, default=0.0)
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date] = mapped_column(Date, nullable=False)
    status: Mapped[InsuranceStatus] = mapped_column(SAEnum(InsuranceStatus), default=InsuranceStatus.active)
    claim_amount: Mapped[float | None] = mapped_column(Float, nullable=True)
    claim_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    claim_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    claim_approved_amount: Mapped[float | None] = mapped_column(Float, nullable=True)
    ear_tag_photo_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    cattle_photo_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
