import enum
import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import Boolean, DateTime, Enum as SAEnum, ForeignKey, Integer, JSON, Numeric, String, Text, TypeDecorator, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class CaseInsensitiveEnum(TypeDecorator):
    impl = SAEnum
    cache_ok = True

    def __init__(self, enum_cls, name, **kwargs):
        self.enum_cls = enum_cls
        super().__init__(
            enum_cls,
            name=name,
            values_callable=lambda obj: [e.value for e in obj],
            validate_strings=False,
            **kwargs,
        )

    def process_bind_param(self, value, dialect):
        if value is None:
            return None
        if isinstance(value, self.enum_cls):
            return value.value
        if isinstance(value, str):
            member = self.enum_cls(value)
            return member.value
        return str(value).upper()

    def process_result_value(self, value, dialect):
        if value is None:
            return None
        return self.enum_cls(value)


class OrderStatus(str, enum.Enum):
    PENDING_PAYMENT = "PENDING_PAYMENT"
    CONFIRMED = "CONFIRMED"
    CANCELLED = "CANCELLED"

    # Lowercase aliases for backward compatibility
    pending_payment = PENDING_PAYMENT
    confirmed = CONFIRMED
    cancelled = CANCELLED

    @classmethod
    def _missing_(cls, value):
        if isinstance(value, str):
            for member in cls:
                if member.value.upper() == value.upper() or member.name.upper() == value.upper():
                    return member
        return super()._missing_(value)


class PaymentStatus(str, enum.Enum):
    PENDING = "PENDING"
    PAID = "PAID"
    FAILED = "FAILED"
    REFUNDED = "REFUNDED"

    # Lowercase aliases for backward compatibility
    pending = PENDING
    paid = PAID
    failed = FAILED
    refunded = REFUNDED

    @classmethod
    def _missing_(cls, value):
        if isinstance(value, str):
            for member in cls:
                if member.value.upper() == value.upper() or member.name.upper() == value.upper():
                    return member
        return super()._missing_(value)


class FulfillmentStatus(str, enum.Enum):
    PENDING = "PENDING"
    CONFIRMED = "CONFIRMED"
    PACKED = "PACKED"
    SHIPPED = "SHIPPED"
    DELIVERED = "DELIVERED"
    CANCELLED = "CANCELLED"

    # Lowercase aliases for backward compatibility
    pending = PENDING
    confirmed = CONFIRMED
    packed = PACKED
    shipped = SHIPPED
    delivered = DELIVERED
    cancelled = CANCELLED

    @classmethod
    def _missing_(cls, value):
        if isinstance(value, str):
            for member in cls:
                if member.value.upper() == value.upper() or member.name.upper() == value.upper():
                    return member
        return super()._missing_(value)


class Order(Base):
    __tablename__ = "orders"
    __table_args__ = (UniqueConstraint("user_id", "idempotency_key", name="uq_order_user_idempotency"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), index=True, nullable=False)
    idempotency_key: Mapped[str] = mapped_column(String(128), nullable=False)
    status: Mapped[OrderStatus] = mapped_column(
        CaseInsensitiveEnum(OrderStatus, name="orderstatus"),
        default=OrderStatus.PENDING_PAYMENT,
        nullable=False,
    )
    payment_status: Mapped[PaymentStatus] = mapped_column(
        CaseInsensitiveEnum(PaymentStatus, name="commerce_payment_status"),
        default=PaymentStatus.PENDING,
        nullable=False,
    )
    is_prelaunch_interest: Mapped[bool] = mapped_column(Boolean, default=False, index=True, nullable=False)
    inventory_released: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_cod: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    address_snapshot: Mapped[dict] = mapped_column(JSON, nullable=False)
    subtotal: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    delivery_fee: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0, nullable=False)
    total: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    return_reason: Mapped[str | None] = mapped_column(String(255), nullable=True)
    return_status: Mapped[str | None] = mapped_column(String(50), nullable=True)
    return_requested_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    return_processed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    return_remarks: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)


class OrderItem(Base):
    __tablename__ = "order_items"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    order_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("orders.id", ondelete="CASCADE"), index=True, nullable=False)
    product_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("products.id"), nullable=False)
    vendor_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("vendors.id"), nullable=False)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)
    unit_price: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    line_total: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    fulfillment_status: Mapped[FulfillmentStatus] = mapped_column(
        CaseInsensitiveEnum(FulfillmentStatus, name="fulfillmentstatus"),
        default=FulfillmentStatus.pending,
        nullable=False,
    )
