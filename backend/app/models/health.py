import uuid
import enum
from datetime import datetime, date
from sqlalchemy import String, Float, Integer, DateTime, Date, Boolean, Text, ForeignKey, Enum as SAEnum, JSON
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.dialects.postgresql import UUID
from app.database import Base


class RecordType(str, enum.Enum):
    checkup = "checkup"
    illness = "illness"
    treatment = "treatment"
    surgery = "surgery"
    observation = "observation"


class HealthRecord(Base):
    __tablename__ = "health_records"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    cattle_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("cattle.id"), nullable=False, index=True)
    date: Mapped[date] = mapped_column(Date, nullable=False)
    record_type: Mapped[RecordType] = mapped_column(SAEnum(RecordType), nullable=False)
    symptoms: Mapped[str | None] = mapped_column(Text, nullable=True)
    diagnosis: Mapped[str | None] = mapped_column(Text, nullable=True)
    treatment: Mapped[str | None] = mapped_column(Text, nullable=True)
    vet_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    severity: Mapped[int | None] = mapped_column(Integer, nullable=True)  # 1-10
    resolved: Mapped[bool] = mapped_column(Boolean, default=False)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class Vaccination(Base):
    __tablename__ = "vaccinations"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    cattle_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("cattle.id"), nullable=False, index=True)
    vaccine_name: Mapped[str] = mapped_column(String(200), nullable=False)
    batch_number: Mapped[str | None] = mapped_column(String(100), nullable=True)
    date_given: Mapped[date] = mapped_column(Date, nullable=False)
    next_due_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    administered_by: Mapped[str | None] = mapped_column(String(200), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class SensorReading(Base):
    __tablename__ = "sensor_readings"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    time: Mapped[datetime] = mapped_column(DateTime, nullable=False, index=True)
    cattle_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("cattle.id"), nullable=False, index=True)
    temperature: Mapped[float | None] = mapped_column(Float, nullable=True)
    heart_rate: Mapped[int | None] = mapped_column(Integer, nullable=True)
    activity_level: Mapped[float | None] = mapped_column(Float, nullable=True)  # 0-100
    rumination_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    battery_pct: Mapped[int | None] = mapped_column(Integer, nullable=True)
    rssi: Mapped[int | None] = mapped_column(Integer, nullable=True)
