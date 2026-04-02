import uuid
import enum
from datetime import datetime, date
from sqlalchemy import (
    String, Float, Integer, Boolean, DateTime, Date, Text,
    ForeignKey, Enum as SAEnum, UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID, JSON

from app.database import Base


class SchemeCategory(str, enum.Enum):
    breed_improvement = "breed_improvement"
    dairy_infrastructure = "dairy_infrastructure"
    credit = "credit"
    insurance = "insurance"
    fodder = "fodder"
    biogas = "biogas"
    training = "training"
    cooperative = "cooperative"
    women_empowerment = "women_empowerment"
    organic = "organic"


class SchemeLevel(str, enum.Enum):
    central = "central"
    state = "state"
    district = "district"


class ApplicationStatus(str, enum.Enum):
    draft = "draft"
    submitted = "submitted"
    under_review = "under_review"
    approved = "approved"
    rejected = "rejected"
    disbursed = "disbursed"


class GovernmentScheme(Base):
    __tablename__ = "government_schemes"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(300), nullable=False)
    short_name: Mapped[str] = mapped_column(String(50), nullable=False)
    category: Mapped[SchemeCategory] = mapped_column(SAEnum(SchemeCategory), nullable=False, index=True)
    level: Mapped[SchemeLevel] = mapped_column(SAEnum(SchemeLevel), nullable=False, index=True)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    benefits: Mapped[str] = mapped_column(Text, nullable=False)
    subsidy_amount_max: Mapped[float | None] = mapped_column(Float, nullable=True)
    subsidy_percentage: Mapped[float | None] = mapped_column(Float, nullable=True)
    eligibility_criteria: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    required_documents: Mapped[list | None] = mapped_column(JSON, nullable=True)
    applicable_states: Mapped[list | None] = mapped_column(JSON, nullable=True)
    min_cattle_count: Mapped[int | None] = mapped_column(Integer, nullable=True)
    max_cattle_count: Mapped[int | None] = mapped_column(Integer, nullable=True)
    min_land_acres: Mapped[float | None] = mapped_column(Float, nullable=True)
    gender_specific: Mapped[str | None] = mapped_column(String(10), nullable=True)
    caste_categories: Mapped[list | None] = mapped_column(JSON, nullable=True)
    age_min: Mapped[int | None] = mapped_column(Integer, nullable=True)
    age_max: Mapped[int | None] = mapped_column(Integer, nullable=True)
    application_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    helpline: Mapped[str | None] = mapped_column(String(50), nullable=True)
    nodal_agency: Mapped[str] = mapped_column(String(200), nullable=False)
    implementing_agency: Mapped[str] = mapped_column(String(200), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    last_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    budget_crores: Mapped[float | None] = mapped_column(Float, nullable=True)
    beneficiaries_target: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    applications = relationship("SchemeApplication", back_populates="scheme", lazy="selectin")
    bookmarks = relationship("SchemeBookmark", back_populates="scheme", lazy="selectin")


class SchemeApplication(Base):
    __tablename__ = "scheme_applications"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    scheme_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("government_schemes.id"), nullable=False, index=True)
    farmer_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("farmers.id"), nullable=False, index=True)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    status: Mapped[ApplicationStatus] = mapped_column(SAEnum(ApplicationStatus), default=ApplicationStatus.draft, nullable=False)
    application_ref: Mapped[str | None] = mapped_column(String(100), nullable=True)
    documents_uploaded: Mapped[list | None] = mapped_column(JSON, nullable=True)
    applied_amount: Mapped[float | None] = mapped_column(Float, nullable=True)
    approved_amount: Mapped[float | None] = mapped_column(Float, nullable=True)
    rejection_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    applied_at: Mapped[date] = mapped_column(Date, nullable=False)
    reviewed_at: Mapped[date | None] = mapped_column(Date, nullable=True)
    disbursed_at: Mapped[date | None] = mapped_column(Date, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    scheme = relationship("GovernmentScheme", back_populates="applications", lazy="selectin")


class SchemeBookmark(Base):
    __tablename__ = "scheme_bookmarks"

    __table_args__ = (
        UniqueConstraint("scheme_id", "user_id", name="uq_scheme_bookmark_user"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    scheme_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("government_schemes.id"), nullable=False, index=True)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # Relationships
    scheme = relationship("GovernmentScheme", back_populates="bookmarks", lazy="selectin")
