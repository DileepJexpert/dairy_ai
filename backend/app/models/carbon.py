import uuid
import enum
from datetime import datetime, date
from sqlalchemy import String, Float, Integer, Date, DateTime, Boolean, Text, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.dialects.postgresql import UUID

from app.database import Base


class CarbonActionType(str, enum.Enum):
    biogas_plant = "biogas_plant"
    improved_feed = "improved_feed"
    manure_composting = "manure_composting"
    solar_energy = "solar_energy"
    tree_planting = "tree_planting"
    methane_inhibitor = "methane_inhibitor"


class CarbonRecord(Base):
    __tablename__ = "carbon_records"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    farmer_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("farmers.id"), nullable=False, index=True)
    period_start: Mapped[date] = mapped_column(Date, nullable=False)
    period_end: Mapped[date] = mapped_column(Date, nullable=False)
    total_cattle: Mapped[int] = mapped_column(Integer, nullable=False)
    total_milk_litres: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    enteric_methane_kg: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    manure_methane_kg: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    feed_production_co2_kg: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    energy_co2_kg: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    transport_co2_kg: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    total_co2_equivalent_kg: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    co2_per_litre: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    carbon_credits_potential: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    methodology: Mapped[str] = mapped_column(String(100), nullable=False, default="IPCC_2019")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class CarbonReductionAction(Base):
    __tablename__ = "carbon_reduction_actions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    farmer_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("farmers.id"), nullable=False, index=True)
    action_type: Mapped[CarbonActionType] = mapped_column(SAEnum(CarbonActionType), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    estimated_reduction_kg_co2: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    verified_by: Mapped[str | None] = mapped_column(String(200), nullable=True)
    verified_at: Mapped[date | None] = mapped_column(Date, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
