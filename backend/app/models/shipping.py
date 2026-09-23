"""One physical parcel per order for the current single-origin storefront."""
import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import DateTime, ForeignKey, Integer, JSON, Numeric, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Shipment(Base):
    __tablename__ = "commerce_shipments"
    __table_args__ = (
        UniqueConstraint("order_id", name="uq_commerce_shipment_order"),
        UniqueConstraint("courier_name", "awb", name="uq_commerce_shipment_carrier_awb"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    order_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("orders.id", ondelete="CASCADE"), nullable=False, index=True)
    mode: Mapped[str] = mapped_column(String(12), default="auto", nullable=False)
    status: Mapped[str] = mapped_column(String(32), default="awaiting_payment", nullable=False, index=True)
    courier_code: Mapped[str | None] = mapped_column(String(40))
    courier_name: Mapped[str | None] = mapped_column(String(100))
    awb: Mapped[str | None] = mapped_column(String(100))
    provider_order_id: Mapped[str | None] = mapped_column(String(100))
    label_url: Mapped[str | None] = mapped_column(String(1000))
    quoted_cost: Mapped[Decimal | None] = mapped_column(Numeric(10, 2))
    customer_fee: Mapped[Decimal] = mapped_column(Numeric(10, 2), default=0, nullable=False)
    weight_grams: Mapped[int | None] = mapped_column(Integer)
    package: Mapped[dict] = mapped_column(JSON, default=dict, nullable=False)
    attempts: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    last_error: Mapped[str | None] = mapped_column(Text)
    next_attempt_at: Mapped[datetime | None] = mapped_column(DateTime)
    claimed_at: Mapped[datetime | None] = mapped_column(DateTime)
    ready_at: Mapped[datetime | None] = mapped_column(DateTime)
    booked_at: Mapped[datetime | None] = mapped_column(DateTime)
    picked_up_at: Mapped[datetime | None] = mapped_column(DateTime)
    delivered_at: Mapped[datetime | None] = mapped_column(DateTime)
    last_tracking_at: Mapped[datetime | None] = mapped_column(DateTime)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)


class ShipmentEvent(Base):
    __tablename__ = "commerce_shipment_events"
    __table_args__ = (UniqueConstraint("shipment_id", "external_key", name="uq_shipment_event_external"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    shipment_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("commerce_shipments.id", ondelete="CASCADE"), index=True, nullable=False)
    external_key: Mapped[str] = mapped_column(String(200), nullable=False)
    status: Mapped[str] = mapped_column(String(40), nullable=False)
    description: Mapped[str] = mapped_column(String(500), default="", nullable=False)
    location: Mapped[str] = mapped_column(String(200), default="", nullable=False)
    occurred_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)
