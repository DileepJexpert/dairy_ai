"""Customer-owned commerce state. No payment instruments or invented balances."""
import uuid
from datetime import datetime
from decimal import Decimal
from sqlalchemy import DateTime, ForeignKey, Integer, Numeric, String, JSON
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base


class WishlistEntry(Base):
    __tablename__ = "commerce_wishlist"
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), primary_key=True)
    product_key: Mapped[str] = mapped_column(String(80), primary_key=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class SavedCartItem(Base):
    __tablename__ = "commerce_saved_items"
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), primary_key=True)
    product_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("products.id"), primary_key=True)
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), default=uuid.uuid4)
    quantity: Mapped[int] = mapped_column(Integer)
    price_when_added: Mapped[Decimal] = mapped_column(Numeric(12, 2))


class OrderContact(Base):
    __tablename__ = "commerce_order_contact"
    order_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("orders.id", ondelete="CASCADE"), primary_key=True)
    payment_method: Mapped[str] = mapped_column(String(30), default="not specified")
    carrier: Mapped[str] = mapped_column(String(100), default="")
    tracking_number: Mapped[str] = mapped_column(String(100), default="")
    interest_status: Mapped[str] = mapped_column(String(30), default="NEW")
    notes: Mapped[str] = mapped_column(String(4000), default="")
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class OrderEvent(Base):
    __tablename__ = "commerce_order_events"
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    order_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("orders.id", ondelete="CASCADE"), index=True)
    title: Mapped[str] = mapped_column(String(200))
    status: Mapped[str] = mapped_column(String(30))
    remarks: Mapped[str] = mapped_column(String(1000), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class StoreHelp(Base):
    __tablename__ = 'commerce_store_help'
    key: Mapped[str] = mapped_column(String(30), primary_key=True)
    content: Mapped[dict] = mapped_column(JSON)


class CustomerPreferences(Base):
    __tablename__ = 'commerce_customer_preferences'
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey('users.id'), primary_key=True)
    content: Mapped[dict] = mapped_column(JSON)


class SupportTicket(Base):
    __tablename__ = 'commerce_support_tickets'
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey('users.id'), index=True)
    subject: Mapped[str] = mapped_column(String(200))
    message: Mapped[str] = mapped_column(String(4000))
    status: Mapped[str] = mapped_column(String(30), default='OPEN')
    reply: Mapped[str] = mapped_column(String(4000), default='')
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
