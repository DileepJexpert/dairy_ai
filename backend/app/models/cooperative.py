import uuid
import enum
from datetime import datetime

from sqlalchemy import String, Float, Integer, Boolean, DateTime, ForeignKey, Text, JSON, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.dialects.postgresql import UUID

from app.database import Base


class CooperativeType(str, enum.Enum):
    milk_collection = "milk_collection"
    dairy_processing = "dairy_processing"
    multi_purpose = "multi_purpose"
    marketing = "marketing"


class Cooperative(Base):
    __tablename__ = "cooperatives"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    registration_number: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    cooperative_type: Mapped[CooperativeType] = mapped_column(SAEnum(CooperativeType), nullable=False)
    chairman_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    secretary_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    address: Mapped[str | None] = mapped_column(Text, nullable=True)
    village: Mapped[str | None] = mapped_column(String(100), nullable=True)
    district: Mapped[str | None] = mapped_column(String(100), nullable=True)
    state: Mapped[str | None] = mapped_column(String(100), nullable=True)
    total_members: Mapped[int] = mapped_column(Integer, default=0)
    total_milk_collected_litres: Mapped[float] = mapped_column(Float, default=0.0)
    total_revenue: Mapped[float] = mapped_column(Float, default=0.0)
    total_payouts: Mapped[float] = mapped_column(Float, default=0.0)
    milk_price_per_litre: Mapped[float] = mapped_column(Float, default=0.0)
    collection_centers: Mapped[list | None] = mapped_column(JSON, default=list)
    services_offered: Mapped[list | None] = mapped_column(JSON, default=list)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
