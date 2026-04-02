import uuid
import enum
from datetime import datetime
from sqlalchemy import String, Float, Integer, DateTime, Boolean, Text, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.dialects.postgresql import UUID

from app.database import Base


class ReportSeverity(str, enum.Enum):
    mild = "mild"
    moderate = "moderate"
    severe = "severe"
    fatal = "fatal"


class ReportSource(str, enum.Enum):
    farmer_report = "farmer_report"
    vet_diagnosis = "vet_diagnosis"
    lab_confirmed = "lab_confirmed"
    sensor_alert = "sensor_alert"


class ReportStatus(str, enum.Enum):
    reported = "reported"
    investigating = "investigating"
    confirmed = "confirmed"
    resolved = "resolved"


class OutbreakSeverityLevel(str, enum.Enum):
    watch = "watch"
    warning = "warning"
    alert = "alert"
    critical = "critical"


class DiseaseReport(Base):
    __tablename__ = "disease_reports"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    cattle_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("cattle.id"), nullable=True, index=True)
    farmer_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("farmers.id"), nullable=False, index=True)
    disease_name: Mapped[str] = mapped_column(String(200), nullable=False, index=True)
    symptoms: Mapped[str | None] = mapped_column(Text, nullable=True)
    severity: Mapped[ReportSeverity] = mapped_column(SAEnum(ReportSeverity), nullable=False)
    lat: Mapped[float] = mapped_column(Float, nullable=False)
    lng: Mapped[float] = mapped_column(Float, nullable=False)
    village: Mapped[str | None] = mapped_column(String(200), nullable=True)
    district: Mapped[str | None] = mapped_column(String(200), nullable=True, index=True)
    state: Mapped[str | None] = mapped_column(String(200), nullable=True, index=True)
    is_confirmed: Mapped[bool] = mapped_column(Boolean, default=False)
    confirmed_by: Mapped[str | None] = mapped_column(String(200), nullable=True)
    source: Mapped[ReportSource] = mapped_column(SAEnum(ReportSource), nullable=False, default=ReportSource.farmer_report)
    status: Mapped[ReportStatus] = mapped_column(SAEnum(ReportStatus), nullable=False, default=ReportStatus.reported)
    reported_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class OutbreakZone(Base):
    __tablename__ = "outbreak_zones"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    disease_name: Mapped[str] = mapped_column(String(200), nullable=False, index=True)
    center_lat: Mapped[float] = mapped_column(Float, nullable=False)
    center_lng: Mapped[float] = mapped_column(Float, nullable=False)
    radius_km: Mapped[float] = mapped_column(Float, nullable=False)
    district: Mapped[str | None] = mapped_column(String(200), nullable=True, index=True)
    state: Mapped[str | None] = mapped_column(String(200), nullable=True, index=True)
    report_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    severity_level: Mapped[OutbreakSeverityLevel] = mapped_column(SAEnum(OutbreakSeverityLevel), nullable=False, default=OutbreakSeverityLevel.watch)
    first_reported: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    last_reported: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    advisory: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
