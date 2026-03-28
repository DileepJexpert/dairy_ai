"""
Milk Collection & Cold Chain models for dairy plant automation.
Covers: Collection Centers, Milk Collection entries, Collection Routes,
Cold Chain monitoring, and Quality Testing.
"""
import uuid
import enum
from datetime import datetime, date, time

from sqlalchemy import (
    String, Float, Integer, Boolean, DateTime, Date, Time,
    ForeignKey, Text, JSON, Enum as SAEnum,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID

from app.database import Base


# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

class CenterStatus(str, enum.Enum):
    active = "active"
    inactive = "inactive"
    maintenance = "maintenance"


class CollectionShift(str, enum.Enum):
    morning = "morning"
    evening = "evening"


class MilkGrade(str, enum.Enum):
    A = "A"       # fat >= 4.0, SNF >= 8.5
    B = "B"       # fat >= 3.5, SNF >= 8.0
    C = "C"       # fat >= 3.0, SNF >= 7.5
    rejected = "rejected"  # below minimum


class RouteStatus(str, enum.Enum):
    planned = "planned"
    in_progress = "in_progress"
    completed = "completed"
    cancelled = "cancelled"


class AlertSeverity(str, enum.Enum):
    info = "info"
    warning = "warning"
    critical = "critical"


class AlertStatus(str, enum.Enum):
    active = "active"
    acknowledged = "acknowledged"
    resolved = "resolved"


# ---------------------------------------------------------------------------
# Collection Center (BMC — Bulk Milk Cooler)
# ---------------------------------------------------------------------------

class CollectionCenter(Base):
    __tablename__ = "collection_centers"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    code: Mapped[str] = mapped_column(String(20), unique=True, nullable=False)
    cooperative_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("cooperatives.id"), nullable=True, index=True
    )
    address: Mapped[str | None] = mapped_column(Text, nullable=True)
    village: Mapped[str | None] = mapped_column(String(100), nullable=True)
    district: Mapped[str | None] = mapped_column(String(100), nullable=True, index=True)
    state: Mapped[str | None] = mapped_column(String(100), nullable=True)
    pincode: Mapped[str | None] = mapped_column(String(10), nullable=True)
    lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    capacity_litres: Mapped[float] = mapped_column(Float, default=500.0)
    current_stock_litres: Mapped[float] = mapped_column(Float, default=0.0)
    chilling_temp_celsius: Mapped[float] = mapped_column(Float, default=4.0)
    has_fat_analyzer: Mapped[bool] = mapped_column(Boolean, default=False)
    has_snf_analyzer: Mapped[bool] = mapped_column(Boolean, default=False)
    manager_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    manager_phone: Mapped[str | None] = mapped_column(String(15), nullable=True)
    status: Mapped[CenterStatus] = mapped_column(SAEnum(CenterStatus), default=CenterStatus.active)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    collections = relationship("MilkCollection", back_populates="center", lazy="selectin")


# ---------------------------------------------------------------------------
# Milk Collection (individual farmer pourings at a center)
# ---------------------------------------------------------------------------

class MilkCollection(Base):
    __tablename__ = "milk_collections"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    center_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("collection_centers.id"), nullable=False, index=True
    )
    farmer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("farmers.id"), nullable=False, index=True
    )
    date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    shift: Mapped[CollectionShift] = mapped_column(SAEnum(CollectionShift), nullable=False)
    quantity_litres: Mapped[float] = mapped_column(Float, nullable=False)
    fat_pct: Mapped[float | None] = mapped_column(Float, nullable=True)
    snf_pct: Mapped[float | None] = mapped_column(Float, nullable=True)
    temperature_celsius: Mapped[float | None] = mapped_column(Float, nullable=True)
    milk_grade: Mapped[MilkGrade | None] = mapped_column(SAEnum(MilkGrade), nullable=True)
    rate_per_litre: Mapped[float | None] = mapped_column(Float, nullable=True)
    total_amount: Mapped[float | None] = mapped_column(Float, nullable=True)
    quality_bonus: Mapped[float] = mapped_column(Float, default=0.0)
    deductions: Mapped[float] = mapped_column(Float, default=0.0)
    net_amount: Mapped[float | None] = mapped_column(Float, nullable=True)
    is_rejected: Mapped[bool] = mapped_column(Boolean, default=False)
    rejection_reason: Mapped[str | None] = mapped_column(String(200), nullable=True)
    collected_by: Mapped[str | None] = mapped_column(String(100), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # Relationships
    center = relationship("CollectionCenter", back_populates="collections")


# ---------------------------------------------------------------------------
# Collection Route (milk tanker route optimization)
# ---------------------------------------------------------------------------

class CollectionRoute(Base):
    __tablename__ = "collection_routes"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    shift: Mapped[CollectionShift] = mapped_column(SAEnum(CollectionShift), nullable=False)
    vehicle_number: Mapped[str | None] = mapped_column(String(20), nullable=True)
    driver_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    driver_phone: Mapped[str | None] = mapped_column(String(15), nullable=True)
    # Ordered list of center IDs to visit
    center_ids: Mapped[list | None] = mapped_column(JSON, default=list)
    # Optimized waypoints [{"center_id": "...", "lat": ..., "lng": ..., "order": 1}]
    waypoints: Mapped[list | None] = mapped_column(JSON, default=list)
    total_distance_km: Mapped[float | None] = mapped_column(Float, nullable=True)
    estimated_duration_mins: Mapped[int | None] = mapped_column(Integer, nullable=True)
    actual_start_time: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    actual_end_time: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    total_collected_litres: Mapped[float] = mapped_column(Float, default=0.0)
    status: Mapped[RouteStatus] = mapped_column(SAEnum(RouteStatus), default=RouteStatus.planned)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


# ---------------------------------------------------------------------------
# Cold Chain Monitoring (temperature readings for centers/tankers)
# ---------------------------------------------------------------------------

class ColdChainReading(Base):
    __tablename__ = "cold_chain_readings"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    center_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("collection_centers.id"), nullable=True, index=True
    )
    route_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("collection_routes.id"), nullable=True, index=True
    )
    temperature_celsius: Mapped[float] = mapped_column(Float, nullable=False)
    humidity_pct: Mapped[float | None] = mapped_column(Float, nullable=True)
    recorded_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    device_id: Mapped[str | None] = mapped_column(String(50), nullable=True)
    is_alert: Mapped[bool] = mapped_column(Boolean, default=False)


# ---------------------------------------------------------------------------
# Cold Chain Alert
# ---------------------------------------------------------------------------

class ColdChainAlert(Base):
    __tablename__ = "cold_chain_alerts"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    center_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("collection_centers.id"), nullable=True, index=True
    )
    route_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("collection_routes.id"), nullable=True, index=True
    )
    temperature_celsius: Mapped[float] = mapped_column(Float, nullable=False)
    threshold_celsius: Mapped[float] = mapped_column(Float, default=4.0)
    severity: Mapped[AlertSeverity] = mapped_column(SAEnum(AlertSeverity), default=AlertSeverity.warning)
    status: Mapped[AlertStatus] = mapped_column(SAEnum(AlertStatus), default=AlertStatus.active)
    message: Mapped[str] = mapped_column(String(500), nullable=False)
    acknowledged_by: Mapped[str | None] = mapped_column(String(100), nullable=True)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
