"""Persistent commerce administration; offers reuse Product/ProductInventory."""
import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import Boolean, DateTime, ForeignKey, JSON, Numeric, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class CommerceCoupon(Base):
    __tablename__ = "commerce_coupons"
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    vendor_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("vendors.id"), nullable=True, index=True)
    code: Mapped[str] = mapped_column(String(40), unique=True, nullable=False)
    description: Mapped[str] = mapped_column(String(500), nullable=False)
    discount_type: Mapped[str] = mapped_column(String(20), nullable=False)
    discount_value: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    min_order_value: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0, nullable=False)
    max_discount_cap: Mapped[Decimal | None] = mapped_column(Numeric(12, 2))
    valid_until: Mapped[datetime | None] = mapped_column(DateTime)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)


class OrderCoupon(Base):
    """Immutable redemption snapshot; one coupon per order, retries do not redeem twice."""
    __tablename__ = "order_coupons"
    order_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("orders.id", ondelete="CASCADE"), primary_key=True)
    coupon_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("commerce_coupons.id"), index=True)
    code: Mapped[str] = mapped_column(String(40), nullable=False)
    discount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)


class CommerceCertificate(Base):
    __tablename__ = "commerce_certificates"
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    product_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("products.id"), index=True, nullable=False)
    batch_number: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    test_date: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    laboratory: Mapped[str] = mapped_column(String(200), nullable=False)
    fssai_license: Mapped[str] = mapped_column(String(100), default="", nullable=False)
    purity_percent: Mapped[Decimal | None] = mapped_column(Numeric(5, 2))
    test_parameters: Mapped[dict] = mapped_column(JSON, default=dict, nullable=False)
    status: Mapped[str] = mapped_column(String(30), default="PENDING_REVIEW", nullable=False)
    certified_by: Mapped[str] = mapped_column(String(200), default="", nullable=False)
    remarks: Mapped[str] = mapped_column(Text, default="", nullable=False)
    report_url: Mapped[str | None] = mapped_column(String(1000))


class CommerceAudit(Base):
    __tablename__ = "commerce_audit"
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    actor_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    user_role: Mapped[str] = mapped_column(String(40), nullable=False)
    action: Mapped[str] = mapped_column(String(40), nullable=False)
    entity_type: Mapped[str] = mapped_column(String(60), nullable=False)
    entity_id: Mapped[str] = mapped_column(String(100), nullable=False)
    details: Mapped[str] = mapped_column(Text, nullable=False)
    timestamp: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)
