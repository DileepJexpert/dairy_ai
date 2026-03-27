import uuid
import enum
from datetime import datetime, date
from sqlalchemy import String, Float, Integer, DateTime, Date, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID

from app.database import Base


class Breed(str, enum.Enum):
    gir = "gir"
    sahiwal = "sahiwal"
    murrah = "murrah"
    hf_crossbred = "hf_crossbred"
    jersey_crossbred = "jersey_crossbred"
    other = "other"


class Sex(str, enum.Enum):
    female = "female"
    male = "male"


class CattleStatus(str, enum.Enum):
    active = "active"
    sold = "sold"
    dead = "dead"
    dry = "dry"


class Cattle(Base):
    __tablename__ = "cattle"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    farmer_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("farmers.id"), nullable=False, index=True)
    tag_id: Mapped[str] = mapped_column(String(20), unique=True, index=True, nullable=False)
    name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    breed: Mapped[Breed] = mapped_column(SAEnum(Breed), nullable=False)
    sex: Mapped[Sex] = mapped_column(SAEnum(Sex), default=Sex.female)
    dob: Mapped[date | None] = mapped_column(Date, nullable=True)
    weight_kg: Mapped[float | None] = mapped_column(Float, nullable=True)
    photo_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    status: Mapped[CattleStatus] = mapped_column(SAEnum(CattleStatus), default=CattleStatus.active)
    lactation_number: Mapped[int | None] = mapped_column(Integer, nullable=True, default=0)
    last_calving_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    farmer = relationship("Farmer", back_populates="cattle", lazy="selectin")
