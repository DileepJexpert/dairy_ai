import enum
import uuid
from datetime import datetime
from decimal import Decimal
from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, JSON, Numeric, String, Text, Enum as SAEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base

class SellerStatus(str, enum.Enum):
    PENDING_APPROVAL = " PENDING_APPROVAL\
 APPROVED = \APPROVED\
 SUSPENDED = \SUSPENDED\
 REJECTED = \REJECTED\

class DocumentType(str, enum.Enum):
 GST_CERTIFICATE = \GST_CERTIFICATE\
 FSSAI_LICENSE = \FSSAI_LICENSE\
 PAN_CARD = \PAN_CARD\
 CANCELLED_CHEQUE = \CANCELLED_CHEQUE\

class FulfillmentType(str, enum.Enum):
 FULFILLED_BY_MILTERRA = \FULFILLED_BY_MILTERRA\
 SELLER_DIRECT = \SELLER_DIRECT\

class OfferStatus(str, enum.Enum):
 ACTIVE = \ACTIVE\
 PAUSED = \PAUSED\
 OUT_OF_STOCK = \OUT_OF_STOCK\
 MODERATION_REQUIRED = \MODERATION_REQUIRED\

class DealType(str, enum.Enum):
 DEAL_OF_THE_DAY = \DEAL_OF_THE_DAY\
 LIGHTNING_DEAL = \LIGHTNING_DEAL\
 FESTIVAL_SPECIAL = \FESTIVAL_SPECIAL\

class CouponDiscountType(str, enum.Enum):
 PERCENTAGE = \PERCENTAGE\
 FLAT = \FLAT\

class AuditActionType(str, enum.Enum):
 PRICE_CHANGE = \PRICE_CHANGE\
 IMAGE_UPDATE = \IMAGE_UPDATE\
 STOCK_ADJUST = \STOCK_ADJUST\
 DEAL_CREATE = \DEAL_CREATE\
 SELLER_APPROVAL = \SELLER_APPROVAL\
 SELLER_SUSPENSION = \SELLER_SUSPENSION\
 CATALOG_CREATE = \CATALOG_CREATE\
 STATUS_CHANGE = \STATUS_CHANGE\

class SellerAccount(Base):
 __tablename__ = \seller_accounts\

 id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
 user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey(\users.id\), index=True, nullable=False)
 business_name: Mapped[str] = mapped_column(String(200), nullable=False)
 trade_name: Mapped[str | None] = mapped_column(String(200))
 gstin: Mapped[str | None] = mapped_column(String(20), index=True)
 fssai_license: Mapped[str | None] = mapped_column(String(30))
 contact_email: Mapped[str | None] = mapped_column(String(100))
 contact_phone: Mapped[str | None] = mapped_column(String(20))
 warehouse_city: Mapped[str | None] = mapped_column(String(100))
 warehouse_state: Mapped[str | None] = mapped_column(String(100))
 bank_account_number: Mapped[str | None] = mapped_column(String(50))
 ifsc_code: Mapped[str | None] = mapped_column(String(20))
 upi_id: Mapped[str | None] = mapped_column(String(100))
 status: Mapped[SellerStatus] = mapped_column(SAEnum(SellerStatus), default=SellerStatus.PENDING_APPROVAL, index=True)
 commission_rate_percent: Mapped[Decimal] = mapped_column(Numeric(5, 2), default=Decimal(\8.00\))
 rating_score: Mapped[Decimal] = mapped_column(Numeric(3, 2), default=Decimal(\4.80\))
 total_ratings_count: Mapped[int] = mapped_column(Integer, default=0)
 created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
 updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class SellerDocument(Base):
 __tablename__ = \seller_documents\

 id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
 seller_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey(\seller_accounts.id\), index=True, nullable=False)
 doc_type: Mapped[DocumentType] = mapped_column(SAEnum(DocumentType), nullable=False)
 file_url: Mapped[str] = mapped_column(String(500), nullable=False)
 document_number: Mapped[str | None] = mapped_column(String(100))
 is_verified: Mapped[bool] = mapped_column(Boolean, default=False)
 created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class SellerOffer(Base):
 __tablename__ = \seller_offers\

 id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
 product_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey(\products.id\), index=True, nullable=False)
 seller_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey(\seller_accounts.id\), index=True, nullable=False)
 seller_sku: Mapped[str] = mapped_column(String(100), index=True, nullable=False)
 mrp: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
 selling_price: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
 discount_percent: Mapped[Decimal] = mapped_column(Numeric(5, 2), default=Decimal(\0.00\))
 available_stock: Mapped[int] = mapped_column(Integer, default=0)
 low_stock_threshold: Mapped[int] = mapped_column(Integer, default=5)
 delivery_promise_days: Mapped[int] = mapped_column(Integer, default=2)
 fulfillment_type: Mapped[FulfillmentType] = mapped_column(SAEnum(FulfillmentType), default=FulfillmentType.FULFILLED_BY_MILTERRA)
 offer_status: Mapped[OfferStatus] = mapped_column(SAEnum(OfferStatus), default=OfferStatus.ACTIVE, index=True)
 is_buy_box_winner: Mapped[bool] = mapped_column(Boolean, default=False)
 created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
 updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class DealPromotion(Base):
 __tablename__ = \deal_promotions\

 id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
 title: Mapped[str] = mapped_column(String(200), nullable=False)
 deal_type: Mapped[DealType] = mapped_column(SAEnum(DealType), default=DealType.DEAL_OF_THE_DAY)
 product_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey(\products.id\), index=True, nullable=False)
 offer_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey(\seller_offers.id\))
 deal_price: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
 discount_percent: Mapped[Decimal] = mapped_column(Numeric(5, 2), nullable=False)
 start_time: Mapped[datetime] = mapped_column(DateTime, nullable=False)
 end_time: Mapped[datetime] = mapped_column(DateTime, nullable=False)
 is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
 created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class PlatformCoupon(Base):
 __tablename__ = \platform_coupons\

 id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
 code: Mapped[str] = mapped_column(String(50), unique=True, index=True, nullable=False)
 description: Mapped[str | None] = mapped_column(String(255))
 discount_type: Mapped[CouponDiscountType] = mapped_column(SAEnum(CouponDiscountType), default=CouponDiscountType.PERCENTAGE)
 discount_value: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
 min_order_value: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=Decimal(\0.00\))
 max_discount_cap: Mapped[Decimal | None] = mapped_column(Numeric(12, 2))
 valid_until: Mapped[datetime | None] = mapped_column(DateTime)
 usage_count: Mapped[int] = mapped_column(Integer, default=0)
 is_active: Mapped[bool] = mapped_column(Boolean, default=True)
 created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class MarketplaceAuditLog(Base):
 __tablename__ = \marketplace_audit_logs\

 id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
 user_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), index=True)
 user_email_or_phone: Mapped[str] = mapped_column(String(100), default=\system_admin\)
 user_role: Mapped[str] = mapped_column(String(50), default=\SUPER_ADMIN\)
 action_type: Mapped[AuditActionType] = mapped_column(SAEnum(AuditActionType), nullable=False)
 entity_type: Mapped[str] = mapped_column(String(50), nullable=False)
 entity_id: Mapped[str] = mapped_column(String(100), nullable=False)
 details: Mapped[str] = mapped_column(Text, nullable=False)
 diff_payload: Mapped[dict] = mapped_column(JSON, default=dict)
 created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
