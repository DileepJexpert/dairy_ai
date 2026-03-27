import uuid
import enum
from datetime import datetime, date

from sqlalchemy import (
    String, Float, Integer, Boolean, DateTime, Date, ForeignKey, Text, JSON,
    Enum as SAEnum,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID

from app.database import Base


class Qualification(str, enum.Enum):
    bvsc = "bvsc"
    mvsc = "mvsc"
    phd = "phd"
    paravet = "paravet"


class ConsultationType(str, enum.Enum):
    video = "video"
    audio = "audio"
    chat = "chat"
    in_person = "in_person"


class TriageSeverity(str, enum.Enum):
    low = "low"
    medium = "medium"
    high = "high"
    emergency = "emergency"


class ConsultationStatus(str, enum.Enum):
    requested = "requested"
    assigned = "assigned"
    in_progress = "in_progress"
    completed = "completed"
    cancelled = "cancelled"
    no_show = "no_show"


class VetProfile(Base):
    __tablename__ = "vet_profiles"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), unique=True, nullable=False
    )
    license_number: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    qualification: Mapped[Qualification] = mapped_column(
        SAEnum(Qualification), nullable=False
    )
    specializations: Mapped[list | None] = mapped_column(JSON, default=list)
    experience_years: Mapped[int] = mapped_column(Integer, default=0)
    languages: Mapped[list | None] = mapped_column(JSON, default=list)
    consultation_fee: Mapped[float] = mapped_column(Float, default=0.0)
    rating_avg: Mapped[float] = mapped_column(Float, default=0.0)
    total_consultations: Mapped[int] = mapped_column(Integer, default=0)
    total_earnings: Mapped[float] = mapped_column(Float, default=0.0)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    is_available: Mapped[bool] = mapped_column(Boolean, default=False)
    availability_start: Mapped[str | None] = mapped_column(String(10), nullable=True)
    availability_end: Mapped[str | None] = mapped_column(String(10), nullable=True)
    bio: Mapped[str | None] = mapped_column(Text, nullable=True)
    photo_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    certificate_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    # Relationships
    consultations = relationship("Consultation", back_populates="vet", lazy="selectin")


class Consultation(Base):
    __tablename__ = "consultations"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    farmer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("farmers.id"), nullable=False, index=True
    )
    cattle_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("cattle.id"), nullable=False
    )
    vet_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("vet_profiles.id"), nullable=True, index=True
    )
    consultation_type: Mapped[ConsultationType] = mapped_column(
        SAEnum(ConsultationType), default=ConsultationType.video
    )
    triage_severity: Mapped[TriageSeverity | None] = mapped_column(
        SAEnum(TriageSeverity), nullable=True
    )
    ai_diagnosis: Mapped[str | None] = mapped_column(Text, nullable=True)
    ai_confidence: Mapped[float | None] = mapped_column(Float, nullable=True)
    vet_diagnosis: Mapped[str | None] = mapped_column(Text, nullable=True)
    vet_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[ConsultationStatus] = mapped_column(
        SAEnum(ConsultationStatus), default=ConsultationStatus.requested
    )
    symptoms: Mapped[str | None] = mapped_column(Text, nullable=True)
    agora_channel_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    agora_token: Mapped[str | None] = mapped_column(String(500), nullable=True)
    started_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    ended_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    duration_seconds: Mapped[int | None] = mapped_column(Integer, nullable=True)
    fee_amount: Mapped[float | None] = mapped_column(Float, nullable=True)
    platform_fee: Mapped[float | None] = mapped_column(Float, nullable=True)
    vet_payout: Mapped[float | None] = mapped_column(Float, nullable=True)
    farmer_rating: Mapped[int | None] = mapped_column(Integer, nullable=True)
    farmer_review: Mapped[str | None] = mapped_column(Text, nullable=True)
    follow_up_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    # Relationships
    vet = relationship("VetProfile", back_populates="consultations", lazy="selectin")
    prescriptions = relationship("Prescription", back_populates="consultation", lazy="selectin")


class Prescription(Base):
    __tablename__ = "prescriptions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    consultation_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("consultations.id"), nullable=False, index=True
    )
    cattle_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("cattle.id"), nullable=False
    )
    vet_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("vet_profiles.id"), nullable=False
    )
    medicines: Mapped[list | None] = mapped_column(JSON, default=list)
    instructions: Mapped[str | None] = mapped_column(Text, nullable=True)
    follow_up_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    is_fulfilled: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # Relationships
    consultation = relationship("Consultation", back_populates="prescriptions", lazy="selectin")
