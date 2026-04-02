"""Pashu Aadhaar — unique cattle identification linked to government UID."""
import uuid
import enum
from datetime import datetime, date

from sqlalchemy import String, Float, Boolean, DateTime, Date, ForeignKey, Text, JSON, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.dialects.postgresql import UUID

from app.database import Base


class IdentificationMethod(str, enum.Enum):
    ear_tag = "ear_tag"         # RFID ear tag (standard Pashu Aadhaar)
    muzzle_print = "muzzle_print"  # Dvara E-Dairy style biometric
    photo_id = "photo_id"       # Photo-based identification
    manual = "manual"           # Manual entry of govt UID


class RegistrationStatus(str, enum.Enum):
    pending = "pending"
    registered = "registered"
    verified = "verified"
    rejected = "rejected"


class PashuAadhaar(Base):
    """Cattle identification record linked to government INAPH UID."""
    __tablename__ = "pashu_aadhaar"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    cattle_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("cattle.id"), unique=True, nullable=False, index=True)
    farmer_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("farmers.id"), nullable=False, index=True)

    # Government UID (12-digit Pashu Aadhaar number)
    pashu_aadhaar_number: Mapped[str | None] = mapped_column(String(20), unique=True, index=True)
    ear_tag_number: Mapped[str | None] = mapped_column(String(20), unique=True, index=True)

    # Identification
    identification_method: Mapped[IdentificationMethod] = mapped_column(
        SAEnum(IdentificationMethod), default=IdentificationMethod.ear_tag
    )
    muzzle_print_hash: Mapped[str | None] = mapped_column(String(255))  # biometric hash
    photo_front_url: Mapped[str | None] = mapped_column(Text)
    photo_side_url: Mapped[str | None] = mapped_column(Text)
    ear_tag_photo_url: Mapped[str | None] = mapped_column(Text)

    # Cattle details (synced with govt DB)
    species: Mapped[str] = mapped_column(String(20), default="cattle")  # cattle / buffalo
    breed_govt: Mapped[str | None] = mapped_column(String(100))
    color: Mapped[str | None] = mapped_column(String(50))
    horn_type: Mapped[str | None] = mapped_column(String(50))
    special_marks: Mapped[str | None] = mapped_column(Text)

    # Owner details (as per govt record)
    owner_name_govt: Mapped[str | None] = mapped_column(String(200))
    owner_aadhaar_last4: Mapped[str | None] = mapped_column(String(4))  # last 4 digits only
    village_code: Mapped[str | None] = mapped_column(String(20))
    block_code: Mapped[str | None] = mapped_column(String(20))
    district_code: Mapped[str | None] = mapped_column(String(20))

    # Vaccination history from INAPH
    inaph_vaccinations: Mapped[list | None] = mapped_column(JSON)  # synced from govt
    inaph_ai_records: Mapped[list | None] = mapped_column(JSON)    # AI events from govt

    # Registration
    status: Mapped[RegistrationStatus] = mapped_column(
        SAEnum(RegistrationStatus), default=RegistrationStatus.pending
    )
    registered_at: Mapped[date | None] = mapped_column(Date)
    verified_at: Mapped[date | None] = mapped_column(Date)
    verified_by: Mapped[str | None] = mapped_column(String(200))
    last_synced_at: Mapped[datetime | None] = mapped_column(DateTime)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
