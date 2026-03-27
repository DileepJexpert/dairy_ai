import uuid
from datetime import datetime, date
from sqlalchemy import String, Float, DateTime, Date, ForeignKey, JSON
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.dialects.postgresql import UUID
from app.database import Base


class FeedPlan(Base):
    __tablename__ = "feed_plans"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    cattle_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("cattle.id"), nullable=False, index=True)
    plan: Mapped[dict] = mapped_column(JSON, nullable=False)  # [{ingredient, quantity_kg, cost_per_kg}]
    total_cost_per_day: Mapped[float] = mapped_column(Float, nullable=False)
    nutrition_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    created_by: Mapped[str] = mapped_column(String(20), default="ai")  # ai or manual
    valid_from: Mapped[date] = mapped_column(Date, nullable=False)
    valid_to: Mapped[date | None] = mapped_column(Date, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
