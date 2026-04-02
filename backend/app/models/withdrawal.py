import uuid
import enum
from datetime import datetime, date
from sqlalchemy import String, Integer, Date, DateTime, Boolean, Text, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.dialects.postgresql import UUID

from app.database import Base


class AdministrationRoute(str, enum.Enum):
    oral = "oral"
    injection = "injection"
    topical = "topical"
    intramammary = "intramammary"


class WithdrawalRecord(Base):
    __tablename__ = "withdrawal_records"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    cattle_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("cattle.id"), nullable=False, index=True)
    farmer_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("farmers.id"), nullable=False, index=True)
    consultation_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("consultations.id"), nullable=True)
    medicine_name: Mapped[str] = mapped_column(String(200), nullable=False)
    active_ingredient: Mapped[str] = mapped_column(String(200), nullable=False)
    dosage: Mapped[str | None] = mapped_column(String(100), nullable=True)
    route: Mapped[AdministrationRoute] = mapped_column(SAEnum(AdministrationRoute), nullable=False)
    treatment_start_date: Mapped[date] = mapped_column(Date, nullable=False)
    treatment_end_date: Mapped[date] = mapped_column(Date, nullable=False)
    milk_withdrawal_days: Mapped[int] = mapped_column(Integer, nullable=False)
    meat_withdrawal_days: Mapped[int] = mapped_column(Integer, nullable=False)
    milk_safe_date: Mapped[date] = mapped_column(Date, nullable=False)
    meat_safe_date: Mapped[date] = mapped_column(Date, nullable=False)
    is_milk_cleared: Mapped[bool] = mapped_column(Boolean, default=False)
    is_meat_cleared: Mapped[bool] = mapped_column(Boolean, default=False)
    cleared_by: Mapped[str | None] = mapped_column(String(200), nullable=True)
    cleared_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
