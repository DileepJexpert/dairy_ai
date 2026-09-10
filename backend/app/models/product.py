import enum
import uuid
from datetime import date, datetime
from decimal import Decimal
from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Integer, JSON, Numeric, String, Text, UniqueConstraint, Enum as SAEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base

class ProductCategory(str, enum.Enum):
    equipment = "EQUIPMENT"
    feed_nutrition = "FEED_NUTRITION"
class MediaType(str, enum.Enum): image = "image"; video = "video"

class Product(Base):
    __tablename__ = "products"
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    vendor_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("vendors.id"), index=True, nullable=False)
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
    gst_rate: Mapped[Decimal | None] = mapped_column(Numeric(5, 2)); unit: Mapped[str] = mapped_column(String(30), nullable=False)
    pack_size: Mapped[str | None] = mapped_column(String(100)); specifications: Mapped[dict] = mapped_column(JSON, default=dict)
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
