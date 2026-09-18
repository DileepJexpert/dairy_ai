import enum
import uuid
from datetime import datetime
from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base


class RFQStatus(str, enum.Enum):
    pending = "pending"
    routed = "routed"
    contacted = "contacted"
    closed = "closed"


class RFQInquiry(Base):
    __tablename__ = "rfq_inquiries"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    product_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("products.id", ondelete="SET NULL"), nullable=True, index=True)
    product_title: Mapped[str] = mapped_column(String(250), nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, default=1)
    unit: Mapped[str] = mapped_column(String(50), default="units")
    buyer_name: Mapped[str] = mapped_column(String(120), nullable=False)
    buyer_phone: Mapped[str] = mapped_column(String(20), nullable=False, index=True)
    buyer_email: Mapped[str | None] = mapped_column(String(120), nullable=True)
    pincode: Mapped[str | None] = mapped_column(String(10), nullable=True)
    city: Mapped[str | None] = mapped_column(String(100), nullable=True)
    state: Mapped[str | None] = mapped_column(String(100), nullable=True)
    requirement_details: Mapped[str | None] = mapped_column(Text, nullable=True)
    preferred_contact: Mapped[str] = mapped_column(String(30), default="whatsapp")
    status: Mapped[str] = mapped_column(String(30), default="pending", index=True)
    target_vendor_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("vendors.id", ondelete="SET NULL"), nullable=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
