import uuid
import enum
from datetime import datetime, date
from sqlalchemy import String, Float, Integer, DateTime, Date, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.dialects.postgresql import UUID
from app.database import Base


class MilkSession(str, enum.Enum):
    morning = "morning"
    evening = "evening"


class BuyerType(str, enum.Enum):
    cooperative = "cooperative"
    private = "private"
    local = "local"


class MilkRecord(Base):
    __tablename__ = "milk_records"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    cattle_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("cattle.id"), nullable=False, index=True)
    date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    session: Mapped[MilkSession] = mapped_column(SAEnum(MilkSession), nullable=False)
    quantity_litres: Mapped[float] = mapped_column(Float, nullable=False)
    fat_pct: Mapped[float | None] = mapped_column(Float, nullable=True)
    snf_pct: Mapped[float | None] = mapped_column(Float, nullable=True)
    buyer_name: Mapped[str | None] = mapped_column(String(200), nullable=True)
    price_per_litre: Mapped[float | None] = mapped_column(Float, nullable=True)
    total_amount: Mapped[float | None] = mapped_column(Float, nullable=True)
    quality_grade: Mapped[str | None] = mapped_column(String(5), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class MilkPrice(Base):
    __tablename__ = "milk_prices"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    district: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    state: Mapped[str | None] = mapped_column(String(100), nullable=True)
    buyer_name: Mapped[str] = mapped_column(String(200), nullable=False)
    buyer_type: Mapped[BuyerType] = mapped_column(SAEnum(BuyerType), nullable=False)
    price_per_litre: Mapped[float] = mapped_column(Float, nullable=False)
    fat_pct_basis: Mapped[float | None] = mapped_column(Float, nullable=True)
    date: Mapped[date] = mapped_column(Date, nullable=False)
    source: Mapped[str | None] = mapped_column(String(200), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
