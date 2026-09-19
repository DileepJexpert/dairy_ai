import enum
import uuid
from datetime import date, datetime
from decimal import Decimal
from sqlalchemy import Boolean, CheckConstraint, Date, DateTime, ForeignKey, Integer, JSON, Numeric, String, Text, UniqueConstraint, Enum as SAEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base

class ProductCategory(str, enum.Enum):
    equipment = "EQUIPMENT"
    feed_nutrition = "FEED_NUTRITION"
class MediaType(str, enum.Enum): image = "image"; video = "video"

class ProductFamily(Base):
    __tablename__ = "product_families"
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    vendor_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("vendors.id"), index=True, nullable=False)
    slug: Mapped[str] = mapped_column(String(120), unique=True, nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(200), nullable=False, index=True)
    brand: Mapped[str] = mapped_column(String(100), default="MILTERRA")
    department: Mapped[str] = mapped_column(String(100), default="Dairy Foods")
    collection: Mapped[str | None] = mapped_column(String(100), default="Ghee")
    milk_source: Mapped[str | None] = mapped_column(String(50))
    production_method: Mapped[str | None] = mapped_column(String(100))
    ingredients: Mapped[str | None] = mapped_column(Text)
    description: Mapped[str | None] = mapped_column(Text)
    is_published: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    is_concept: Mapped[bool] = mapped_column(Boolean, default=False)
    supporting_documents: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class Product(Base):
    __tablename__ = "products"
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    vendor_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("vendors.id"), index=True, nullable=False)
    family_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("product_families.id"), nullable=True, index=True)
    sku: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    title: Mapped[str] = mapped_column(String(200), nullable=False, index=True)
    slug: Mapped[str] = mapped_column(String(240), index=True, nullable=False)
    category: Mapped[ProductCategory] = mapped_column(
        SAEnum(ProductCategory, values_callable=lambda members: [member.value for member in members]),
        index=True,
        nullable=False,
    )
    subcategory: Mapped[str | None] = mapped_column(String(100)); brand: Mapped[str | None] = mapped_column(String(100))
    description: Mapped[str | None] = mapped_column(Text); short_description: Mapped[str | None] = mapped_column(String(500))
    base_price: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    compare_at_price: Mapped[Decimal | None] = mapped_column(Numeric(12, 2), nullable=True)
    gst_rate: Mapped[Decimal | None] = mapped_column(Numeric(5, 2)); unit: Mapped[str] = mapped_column(String(30), nullable=False)
    pack_size: Mapped[str | None] = mapped_column(String(100)); weight_grams: Mapped[int | None] = mapped_column(Integer, nullable=True)
    specifications: Mapped[dict] = mapped_column(JSON, default=dict)
    publication_status: Mapped[str] = mapped_column(String(30), default="published", index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True); is_featured: Mapped[bool] = mapped_column(Boolean, default=False)
    is_rentable: Mapped[bool] = mapped_column(Boolean, default=False); rental_rate_per_hour: Mapped[Decimal | None] = mapped_column(Numeric(12, 2)); rental_rate_per_acre: Mapped[Decimal | None] = mapped_column(Numeric(12, 2))
    min_order_quantity: Mapped[int] = mapped_column(Integer, default=1)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True); updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class ProductInventory(Base):
    __tablename__ = "product_inventory"; __table_args__ = (UniqueConstraint("product_id", name="uq_product_inventory"),)
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    product_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("products.id"), index=True, nullable=False)
    available_quantity: Mapped[int] = mapped_column(Integer, default=0); reserved_quantity: Mapped[int] = mapped_column(Integer, default=0); reorder_level: Mapped[int] = mapped_column(Integer, default=0)
    warehouse_location: Mapped[str | None] = mapped_column(String(200)); batch_number: Mapped[str | None] = mapped_column(String(100)); manufacture_date: Mapped[date | None] = mapped_column(Date); expiry_date: Mapped[date | None] = mapped_column(Date); updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class ProductMedia(Base):
    __tablename__ = "product_media"
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4); product_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("products.id"), index=True, nullable=False)
    media_type: Mapped[MediaType] = mapped_column(SAEnum(MediaType), default=MediaType.image); url: Mapped[str] = mapped_column(String(500), nullable=False); sort_order: Mapped[int] = mapped_column(Integer, default=0); is_primary: Mapped[bool] = mapped_column(Boolean, default=False)


class ProductReview(Base):
    """Pre-launch product feedback stored independently from Flutter fixtures."""

    __tablename__ = "product_reviews"
    __table_args__ = (
        CheckConstraint("rating BETWEEN 1 AND 5", name="ck_product_reviews_rating"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    product_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("products.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    author_name: Mapped[str] = mapped_column(String(120), nullable=False)
    rating: Mapped[int] = mapped_column(Integer, nullable=False)
    headline: Mapped[str] = mapped_column(String(160), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    source_label: Mapped[str] = mapped_column(
        String(80), default="Visitor feedback", nullable=False
    )
    is_seeded: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_approved: Mapped[bool] = mapped_column(Boolean, default=True, index=True, nullable=False)
    rejection_reason: Mapped[str | None] = mapped_column(String(255), nullable=True)
    vendor_reply: Mapped[str | None] = mapped_column(Text, nullable=True)
    vendor_replied_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, index=True, nullable=False
    )


class MerchandisingPlacement(Base):
    """Admin-controlled storefront promotion linked to a canonical product."""

    __tablename__ = "merchandising_placements"
    __table_args__ = (
        CheckConstraint(
            "placement_type IN ('highlight', 'deal', 'new_launch', 'festival_offer')",
            name="ck_merchandising_placement_type",
        ),
        CheckConstraint(
            "priority BETWEEN 0 AND 1000",
            name="ck_merchandising_priority",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    product_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("products.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    placement_type: Mapped[str] = mapped_column(
        String(30), default="highlight", index=True, nullable=False
    )
    headline: Mapped[str] = mapped_column(String(180), nullable=False)
    subheadline: Mapped[str | None] = mapped_column(String(300), nullable=True)
    badge: Mapped[str | None] = mapped_column(String(60), nullable=True)
    starts_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    ends_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    priority: Mapped[int] = mapped_column(Integer, default=100, nullable=False)
    is_active: Mapped[bool] = mapped_column(
        Boolean, default=True, index=True, nullable=False
    )
    created_by_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, index=True, nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False
    )


class ConceptFeedback(Base):
    """Interest and feedback for concepts that do not yet have product rows."""

    __tablename__ = "concept_feedback"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    concept_key: Mapped[str] = mapped_column(String(120), index=True, nullable=False)
    concept_title: Mapped[str] = mapped_column(String(200), nullable=False)
    visitor_name: Mapped[str] = mapped_column(String(120), nullable=False)
    email: Mapped[str | None] = mapped_column(String(254), nullable=True)
    phone: Mapped[str | None] = mapped_column(String(15), nullable=True)
    message: Mapped[str | None] = mapped_column(Text, nullable=True)
    wants_updates: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, index=True, nullable=False
    )
