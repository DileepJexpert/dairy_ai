import uuid
import enum
from datetime import datetime
from sqlalchemy import (
    String, Float, Integer, DateTime, Boolean, Text,
    ForeignKey, Enum as SAEnum, JSON, UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID

from app.database import Base


class ListingStatus(str, enum.Enum):
    draft = "draft"
    active = "active"
    sold = "sold"
    expired = "expired"
    cancelled = "cancelled"


class ListingCategory(str, enum.Enum):
    cow = "cow"
    buffalo = "buffalo"
    bull = "bull"
    calf = "calf"
    heifer = "heifer"


class InquiryStatus(str, enum.Enum):
    pending = "pending"
    accepted = "accepted"
    rejected = "rejected"
    completed = "completed"


class CattleListing(Base):
    __tablename__ = "cattle_listings"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4,
    )
    seller_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True,
    )
    cattle_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("cattle.id"), nullable=True, index=True,
    )
    category: Mapped[ListingCategory] = mapped_column(
        SAEnum(ListingCategory), nullable=False,
    )
    breed: Mapped[str] = mapped_column(String(100), nullable=False)
    age_months: Mapped[int | None] = mapped_column(Integer, nullable=True)
    weight_kg: Mapped[float | None] = mapped_column(Float, nullable=True)
    milk_yield_litres: Mapped[float | None] = mapped_column(Float, nullable=True)
    fat_pct: Mapped[float | None] = mapped_column(Float, nullable=True)
    lactation_number: Mapped[int | None] = mapped_column(Integer, nullable=True)
    is_pregnant: Mapped[bool] = mapped_column(Boolean, default=False)
    months_pregnant: Mapped[int | None] = mapped_column(Integer, nullable=True)
    health_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    vaccination_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    price: Mapped[float] = mapped_column(Float, nullable=False)
    is_negotiable: Mapped[bool] = mapped_column(Boolean, default=True)
    photos: Mapped[list | None] = mapped_column(JSON, nullable=True)
    video_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    location_village: Mapped[str | None] = mapped_column(String(100), nullable=True)
    location_district: Mapped[str | None] = mapped_column(String(100), nullable=True)
    location_state: Mapped[str | None] = mapped_column(String(100), nullable=True)
    lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    views_count: Mapped[int] = mapped_column(Integer, default=0)
    inquiries_count: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[ListingStatus] = mapped_column(
        SAEnum(ListingStatus), default=ListingStatus.active,
    )
    featured: Mapped[bool] = mapped_column(Boolean, default=False)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow,
    )

    # Relationships
    seller = relationship("User", foreign_keys=[seller_id], lazy="selectin")
    cattle = relationship("Cattle", foreign_keys=[cattle_id], lazy="selectin")
    inquiries = relationship("ListingInquiry", back_populates="listing", lazy="selectin")
    favorites = relationship("ListingFavorite", back_populates="listing", lazy="selectin")


class ListingInquiry(Base):
    __tablename__ = "listing_inquiries"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4,
    )
    listing_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("cattle_listings.id"), nullable=False, index=True,
    )
    buyer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True,
    )
    message: Mapped[str] = mapped_column(Text, nullable=False)
    offered_price: Mapped[float | None] = mapped_column(Float, nullable=True)
    phone_shared: Mapped[bool] = mapped_column(Boolean, default=False)
    status: Mapped[InquiryStatus] = mapped_column(
        SAEnum(InquiryStatus), default=InquiryStatus.pending,
    )
    seller_response: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow,
    )

    # Relationships
    listing = relationship("CattleListing", back_populates="inquiries", lazy="selectin")
    buyer = relationship("User", foreign_keys=[buyer_id], lazy="selectin")


class ListingFavorite(Base):
    __tablename__ = "listing_favorites"
    __table_args__ = (
        UniqueConstraint("listing_id", "user_id", name="uq_listing_favorite"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4,
    )
    listing_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("cattle_listings.id"), nullable=False, index=True,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # Relationships
    listing = relationship("CattleListing", back_populates="favorites", lazy="selectin")
    user = relationship("User", foreign_keys=[user_id], lazy="selectin")
