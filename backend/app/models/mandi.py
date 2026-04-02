"""Mandi (market) price models for feed ingredients and cattle trading."""
import uuid
import enum
from datetime import datetime, date

from sqlalchemy import String, Float, Integer, DateTime, Date, ForeignKey, Text, JSON, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.dialects.postgresql import UUID

from app.database import Base


class MandiCategory(str, enum.Enum):
    green_fodder = "green_fodder"
    dry_fodder = "dry_fodder"
    concentrate = "concentrate"
    mineral = "mineral"
    cattle_feed = "cattle_feed"
    supplement = "supplement"


class MandiPrice(Base):
    """Daily feed ingredient prices from local mandis / eNAM."""
    __tablename__ = "mandi_prices"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    ingredient_name: Mapped[str] = mapped_column(String(200), nullable=False, index=True)
    category: Mapped[MandiCategory] = mapped_column(SAEnum(MandiCategory), nullable=False)
    price_per_kg: Mapped[float] = mapped_column(Float, nullable=False)
    unit: Mapped[str] = mapped_column(String(20), default="kg")
    mandi_name: Mapped[str | None] = mapped_column(String(200))
    district: Mapped[str | None] = mapped_column(String(100), index=True)
    state: Mapped[str | None] = mapped_column(String(100))
    date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    source: Mapped[str | None] = mapped_column(String(200))  # eNAM, manual, API
    min_price: Mapped[float | None] = mapped_column(Float)
    max_price: Mapped[float | None] = mapped_column(Float)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class CattleMarketPrice(Base):
    """Cattle trading prices from local markets."""
    __tablename__ = "cattle_market_prices"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    breed: Mapped[str] = mapped_column(String(50), nullable=False, index=True)
    category: Mapped[str] = mapped_column(String(50), nullable=False)  # cow, buffalo, bull, calf, heifer
    age_range: Mapped[str | None] = mapped_column(String(30))  # e.g., "2-4 years"
    milk_yield_range: Mapped[str | None] = mapped_column(String(30))  # e.g., "8-12 litres"
    avg_price: Mapped[float] = mapped_column(Float, nullable=False)
    min_price: Mapped[float | None] = mapped_column(Float)
    max_price: Mapped[float | None] = mapped_column(Float)
    mandi_name: Mapped[str | None] = mapped_column(String(200))
    district: Mapped[str | None] = mapped_column(String(100), index=True)
    state: Mapped[str | None] = mapped_column(String(100))
    date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    sample_count: Mapped[int] = mapped_column(Integer, default=1)
    source: Mapped[str | None] = mapped_column(String(200))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
