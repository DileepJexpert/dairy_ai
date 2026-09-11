import uuid
from datetime import datetime
from decimal import Decimal
from pydantic import BaseModel, ConfigDict
from typing import Optional, List, Dict, Any
from app.models.marketplace_models import (
    SellerStatus, DocumentType, FulfillmentType, OfferStatus, DealType, CouponDiscountType, AuditActionType
)

class SellerAccountCreate(BaseModel):
    business_name: str
    trade_name: Optional[str] = None
    gstin: Optional[str] = None
    fssai_license: Optional[str] = None
    contact_email: Optional[str] = None
    contact_phone: Optional[str] = None
    warehouse_city: Optional[str] = None
    warehouse_state: Optional[str] = None
    bank_account_number: Optional[str] = None
    ifsc_code: Optional[str] = None
    upi_id: Optional[str] = None

class SellerAccountResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    user_id: uuid.UUID
    business_name: str
    trade_name: Optional[str] = None
    gstin: Optional[str] = None
    fssai_license: Optional[str] = None
    contact_email: Optional[str] = None
    contact_phone: Optional[str] = None
    warehouse_city: Optional[str] = None
    warehouse_state: Optional[str] = None
    bank_account_number: Optional[str] = None
    ifsc_code: Optional[str] = None
    upi_id: Optional[str] = None
    status: SellerStatus
    commission_rate_percent: Decimal
    rating_score: Decimal
    total_ratings_count: int
    created_at: datetime

class SellerOfferCreate(BaseModel):
    product_id: uuid.UUID
    seller_sku: str
    mrp: Decimal
    selling_price: Decimal
    discount_percent: Optional[Decimal] = Decimal( 0.00)
    available_stock: int
    low_stock_threshold: Optional[int] = 5
    delivery_promise_days: Optional[int] = 2
    fulfillment_type: Optional[FulfillmentType] = FulfillmentType.FULFILLED_BY_MILTERRA

class SellerOfferUpdate(BaseModel):
    selling_price: Optional[Decimal] = None
    mrp: Optional[Decimal] = None
    discount_percent: Optional[Decimal] = None
    available_stock: Optional[int] = None
    low_stock_threshold: Optional[int] = None
    delivery_promise_days: Optional[int] = None
    offer_status: Optional[OfferStatus] = None

class SellerOfferResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    product_id: uuid.UUID
    seller_id: uuid.UUID
    seller_name: Optional[str] = Milterra Direct
    seller_sku: str
    mrp: Decimal
    selling_price: Decimal
    discount_percent: Decimal
    available_stock: int
    low_stock_threshold: int
    delivery_promise_days: int
    fulfillment_type: FulfillmentType
    offer_status: OfferStatus
    is_buy_box_winner: bool
    created_at: datetime

class DealPromotionCreate(BaseModel):
    title: str
    deal_type: DealType
    product_id: uuid.UUID
    offer_id: Optional[uuid.UUID] = None
    deal_price: Decimal
    discount_percent: Decimal
    start_time: datetime
    end_time: datetime

class DealPromotionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    title: str
    deal_type: DealType
    product_id: uuid.UUID
    offer_id: Optional[uuid.UUID] = None
    deal_price: Decimal
    discount_percent: Decimal
    start_time: datetime
    end_time: datetime
    is_active: bool

class PlatformCouponCreate(BaseModel):
    code: str
    description: Optional[str] = None
    discount_type: CouponDiscountType = CouponDiscountType.PERCENTAGE
    discount_value: Decimal
    min_order_value: Decimal = Decimal(0.00)
    max_discount_cap: Optional[Decimal] = None
    valid_until: Optional[datetime] = None

class PlatformCouponResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    code: str
    description: Optional[str] = None
    discount_type: CouponDiscountType
    discount_value: Decimal
    min_order_value: Decimal
    max_discount_cap: Optional[Decimal] = None
    valid_until: Optional[datetime] = None
    usage_count: int
    is_active: bool

class AuditLogResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    user_id: Optional[uuid.UUID] = None
    user_email_or_phone: str
    user_role: str
    action_type: AuditActionType
    entity_type: str
    entity_id: str
    details: str
    diff_payload: Dict[str, Any]
    created_at: datetime
