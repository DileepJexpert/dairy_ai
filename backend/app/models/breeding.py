import uuid
import enum
from datetime import datetime, date
from sqlalchemy import String, Float, Integer, DateTime, Date, ForeignKey, Text, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.dialects.postgresql import UUID
from app.database import Base


class BreedingEventType(str, enum.Enum):
    heat_detected = "heat_detected"
    ai_done = "ai_done"
    pregnancy_confirmed = "pregnancy_confirmed"
    calving = "calving"
    abortion = "abortion"


class BreedingRecord(Base):
    __tablename__ = "breeding_records"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    cattle_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("cattle.id"), nullable=False, index=True)
    event_type: Mapped[BreedingEventType] = mapped_column(SAEnum(BreedingEventType), nullable=False)
    date: Mapped[date] = mapped_column(Date, nullable=False)
    bull_id: Mapped[str | None] = mapped_column(String(100), nullable=True)
    ai_technician: Mapped[str | None] = mapped_column(String(200), nullable=True)
    semen_batch: Mapped[str | None] = mapped_column(String(100), nullable=True)
    expected_calving_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    actual_calving_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    calf_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
