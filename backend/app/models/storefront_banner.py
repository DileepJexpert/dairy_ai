"""Storefront banner cards — fully dynamic, managed from admin panel."""
import uuid
from datetime import datetime
from sqlalchemy import Boolean, DateTime, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base


class StorefrontBanner(Base):
    """A single promotional/category card shown in the storefront carousel.

    Admin creates these via the API. Flutter fetches active banners and renders
    them as a scrollable row of cards. No Flutter code change needed to update
    the homepage.
    """
    __tablename__ = "storefront_banners"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    # --- Content ---
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    subtitle: Mapped[str | None] = mapped_column(String(300), nullable=True)
    image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    icon_name: Mapped[str | None] = mapped_column(
        String(50), nullable=True,
        comment="Flutter Icons name fallback when no image, e.g. 'local_fire_department'"
    )

    # --- Action (what happens when user taps the card) ---
    action_type: Mapped[str] = mapped_column(
        String(20), nullable=False, default="category",
        comment="category | product | url | division"
    )
    action_value: Mapped[str] = mapped_column(
        String(200), nullable=False,
        comment="Category name, product ID, external URL, or division key"
    )

    # --- Visual ---
    bg_color: Mapped[str] = mapped_column(String(9), default="#173f35")
    text_color: Mapped[str] = mapped_column(String(9), default="#ffffff")

    # --- Ordering & visibility ---
    display_order: Mapped[int] = mapped_column(Integer, default=0, index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    starts_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    ends_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    # --- Timestamps ---
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, index=True
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )
