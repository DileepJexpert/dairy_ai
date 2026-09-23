"""Master table for serviceable delivery PIN codes, delivery timelines, and hubs."""
from datetime import datetime
from decimal import Decimal
from sqlalchemy import Boolean, DateTime, Integer, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base


class ServiceablePincode(Base):
    """Master record of locations where Milterra / sellers can deliver products.

    Managed via Admin UI/API. Used by storefront to estimate delivery dates
    and check if doorstep delivery is available for a customer's PIN code.
    """
    __tablename__ = "serviceable_pincodes"

    pincode: Mapped[str] = mapped_column(String(6), primary_key=True, index=True)
    city: Mapped[str] = mapped_column(String(100), nullable=False)
    state: Mapped[str] = mapped_column(String(100), nullable=False)
    is_serviceable: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    delivery_days_min: Mapped[int] = mapped_column(Integer, default=1)
    delivery_days_max: Mapped[int] = mapped_column(Integer, default=2)
    express_available: Mapped[bool] = mapped_column(Boolean, default=True)
    delivery_fee: Mapped[Decimal] = mapped_column(Numeric(8, 2), default=Decimal("0.00"))
    delivery_message: Mapped[str | None] = mapped_column(
        String(250),
        nullable=True,
        comment="Custom delivery note e.g. 'Next-day cold chain delivery available'",
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )
