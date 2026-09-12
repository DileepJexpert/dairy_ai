import enum
import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class ClickstreamEventType(str, enum.Enum):
    PAGE_VIEW = "PAGE_VIEW"
    PRODUCT_VIEW = "PRODUCT_VIEW"
    ADD_TO_CART = "ADD_TO_CART"
    REMOVE_FROM_CART = "REMOVE_FROM_CART"
    UPDATE_CART = "UPDATE_CART"
    SEARCH_QUERY = "SEARCH_QUERY"
    FILTER_APPLIED = "FILTER_APPLIED"
    BUTTON_CLICK = "BUTTON_CLICK"
    CERTIFICATE_VIEW = "CERTIFICATE_VIEW"
    CHECKOUT_INITIATE = "CHECKOUT_INITIATE"
    COUPON_APPLY = "COUPON_APPLY"


class VisitorSession(Base):
    __tablename__ = "analytics_visitor_sessions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    session_id: Mapped[str] = mapped_column(String(128), unique=True, index=True, nullable=False)
    user_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), index=True, nullable=True)

    ip_address: Mapped[str | None] = mapped_column(String(64), nullable=True)
    country: Mapped[str] = mapped_column(String(64), default="India", nullable=False)
    state: Mapped[str | None] = mapped_column(String(64), nullable=True)
    city: Mapped[str | None] = mapped_column(String(64), nullable=True)

    referrer: Mapped[str | None] = mapped_column(String(512), nullable=True)
    referrer_type: Mapped[str] = mapped_column(String(64), default="direct", nullable=False)  # direct, whatsapp, google, instagram, facebook, referral
    utm_source: Mapped[str | None] = mapped_column(String(128), nullable=True)
    utm_medium: Mapped[str | None] = mapped_column(String(128), nullable=True)
    utm_campaign: Mapped[str | None] = mapped_column(String(128), nullable=True)
    utm_content: Mapped[str | None] = mapped_column(String(128), nullable=True)

    landing_page: Mapped[str] = mapped_column(String(256), default="/shop", nullable=False)
    device_type: Mapped[str] = mapped_column(String(32), default="mobile", nullable=False)  # mobile, desktop, tablet
    browser: Mapped[str | None] = mapped_column(String(64), nullable=True)
    os: Mapped[str | None] = mapped_column(String(64), nullable=True)

    page_views_count: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    is_bounce: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    started_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)


class ClickstreamEvent(Base):
    __tablename__ = "analytics_clickstream_events"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    session_id: Mapped[str] = mapped_column(String(128), index=True, nullable=False)
    user_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), index=True, nullable=True)

    event_type: Mapped[str] = mapped_column(String(64), index=True, nullable=False)
    page_url: Mapped[str] = mapped_column(String(256), nullable=False)
    element_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    element_text: Mapped[str | None] = mapped_column(String(256), nullable=True)
    target_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    metadata_json: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True, nullable=False)
