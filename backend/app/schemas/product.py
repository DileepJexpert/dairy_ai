import uuid
from typing import Literal
from datetime import date, datetime, timezone
from decimal import Decimal
from pydantic import BaseModel, Field, model_validator, field_validator
from app.models.product import ProductCategory, MediaType
class ProductFamilyCreate(BaseModel):
    title: str = Field(min_length=2, max_length=200)
    slug: str | None = None
    brand: str = "MILTERRA"
    department: str = "Dairy Foods"
    collection: str | None = "Ghee"
    milk_source: str | None = None
    production_method: str | None = Field(default=None, max_length=100)
    ingredients: str | None = None
    description: str | None = None
    is_published: bool = True
    is_concept: bool = False
    supporting_documents: dict = Field(default_factory=dict)
    # Only admins may set this. Vendor requests are always scoped to their own
    # profile by the endpoint.
    vendor_id: uuid.UUID | None = None
    category_id: uuid.UUID | None = None

class ProductFamilyUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=2, max_length=200)
    brand: str | None = None
    department: str | None = None
    collection: str | None = None
    category_id: uuid.UUID | None = None
    milk_source: str | None = None
    production_method: str | None = Field(default=None, max_length=100)
    ingredients: str | None = None
    description: str | None = None
    is_published: bool | None = None
    is_concept: bool | None = None
    supporting_documents: dict | None = None

class FamilyVariantCreate(BaseModel):
    sku: str = Field(min_length=1, max_length=100)
    pack_size: str = Field(min_length=1, max_length=100)
    base_price: Decimal = Field(gt=0)
    compare_at_price: Decimal | None = Field(default=None, gt=0)
    unit: str = "pack"
    weight_grams: int | None = Field(default=None, gt=0)
    initial_stock: int = Field(default=0, ge=0)
    publication_status: Literal["draft", "pending_review", "published", "rejected"] = "published"

class ProductCreate(BaseModel):
    sku: str = Field(min_length=1, max_length=100); title: str = Field(min_length=2, max_length=200); category: ProductCategory | str = ProductCategory.feed_nutrition; base_price: Decimal = Field(gt=0); unit: str = Field(min_length=1, max_length=30)
    category_id: uuid.UUID | None = None
    family_id: uuid.UUID | None = None
    vendor_id: uuid.UUID | None = None
    compare_at_price: Decimal | None = Field(default=None, gt=0)
    weight_grams: int | None = Field(default=None, gt=0)
    initial_stock: int = Field(default=0, ge=0)
    publication_status: Literal["draft", "pending_review", "published", "rejected"] = "published"
    subcategory: str|None=None; brand:str|None=None; description:str|None=None; short_description:str|None=None; gst_rate:Decimal|None=Field(default=None,ge=0,le=100); pack_size:str|None=None; specifications:dict=Field(default_factory=dict); is_featured:bool=False; is_rentable:bool=False; rental_rate_per_hour:Decimal|None=Field(default=None,gt=0); rental_rate_per_acre:Decimal|None=Field(default=None,gt=0); min_order_quantity:int=Field(default=1,ge=1)
    @model_validator(mode="after")
    def rent_rules(self):
        if self.is_rentable and not (self.rental_rate_per_hour or self.rental_rate_per_acre): raise ValueError("Rentable products need a rental rate")
        if self.category != ProductCategory.equipment and self.is_rentable: raise ValueError("Only equipment can be rentable")
        return self

class ProductUpdate(BaseModel):
    title:str|None=Field(default=None,min_length=2,max_length=200); subcategory:str|None=None; brand:str|None=None; description:str|None=None; short_description:str|None=None; base_price:Decimal|None=Field(default=None,gt=0); gst_rate:Decimal|None=Field(default=None,ge=0,le=100); unit:str|None=None; pack_size:str|None=None; specifications:dict|None=None; is_active:bool|None=None; is_featured:bool|None=None; is_rentable:bool|None=None; rental_rate_per_hour:Decimal|None=Field(default=None,gt=0); rental_rate_per_acre:Decimal|None=Field(default=None,gt=0); min_order_quantity:int|None=Field(default=None,ge=1)
    category_id: uuid.UUID | None = None
    category: ProductCategory | str | None = None
    family_id: uuid.UUID | None = None
    compare_at_price: Decimal | None = Field(default=None, gt=0)
    weight_grams: int | None = Field(default=None, gt=0)
    publication_status: Literal["draft", "pending_review", "published", "rejected"] | None = None

class InventoryUpdate(BaseModel): available_quantity:int=Field(ge=0); reserved_quantity:int=Field(default=0,ge=0); reorder_level:int=Field(default=0,ge=0); warehouse_location:str|None=None; batch_number:str|None=None; manufacture_date:date|None=None; expiry_date:date|None=None
class ProductMediaCreate(BaseModel):
    url: str = Field(min_length=1, max_length=500)
    media_type: MediaType = MediaType.image
    sort_order: int = Field(default=0, ge=0)
    is_primary: bool = False

    @field_validator('url')
    @classmethod
    def reserved_upload_path(cls, value):
        if value.startswith('/api/v1/marketplace/media/'):
            raise ValueError('Local image references are assigned by the upload endpoint')
        return value


class ProductReviewCreate(BaseModel):
    author_name: str = Field(min_length=2, max_length=120)
    rating: int = Field(ge=1, le=5)
    headline: str = Field(min_length=3, max_length=160)
    content: str = Field(min_length=10, max_length=2000)


class PlacementWindow(BaseModel):
    @field_validator('starts_at', 'ends_at', check_fields=False)
    @classmethod
    def utc_dates(cls, value):
        return value.astimezone(timezone.utc).replace(tzinfo=None) if value and value.tzinfo else value


class MerchandisingPlacementCreate(PlacementWindow):
    product_id: uuid.UUID
    placement_type: Literal[
        "highlight", "deal", "new_launch", "festival_offer"
    ] = "highlight"
    headline: str = Field(min_length=3, max_length=180)
    subheadline: str | None = Field(default=None, max_length=300)
    badge: str | None = Field(default=None, max_length=60)
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    priority: int = Field(default=100, ge=0, le=1000)
    is_active: bool = True

    @model_validator(mode="after")
    def valid_window(self):
        if self.starts_at and self.ends_at and self.ends_at <= self.starts_at:
            raise ValueError("ends_at must be after starts_at")
        return self


class MerchandisingPlacementUpdate(PlacementWindow):
    placement_type: Literal[
        "highlight", "deal", "new_launch", "festival_offer"
    ] | None = None
    headline: str | None = Field(default=None, min_length=3, max_length=180)
    subheadline: str | None = Field(default=None, max_length=300)
    badge: str | None = Field(default=None, max_length=60)
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    priority: int | None = Field(default=None, ge=0, le=1000)
    is_active: bool | None = None

    @model_validator(mode="after")
    def valid_window(self):
        if self.starts_at and self.ends_at and self.ends_at <= self.starts_at:
            raise ValueError("ends_at must be after starts_at")
        return self


class ConceptFeedbackCreate(BaseModel):
    concept_title: str = Field(min_length=2, max_length=200)
    visitor_name: str = Field(min_length=2, max_length=120)
    email: str | None = Field(default=None, max_length=254)
    phone: str | None = Field(default=None, max_length=15)
    message: str | None = Field(default=None, max_length=2000)
    wants_updates: bool = False

    @model_validator(mode="after")
    def has_contact_and_content(self):
        if not (self.email and self.email.strip()) and not (self.phone and self.phone.strip()):
            raise ValueError("Provide an email or phone number")
        if not self.wants_updates and not (self.message and len(self.message.strip()) >= 5):
            raise ValueError("Feedback must contain at least 5 characters")
        return self


class ProductModerationUpdate(BaseModel):
    publication_status: Literal["draft", "pending_review", "published", "rejected"]
    is_active: bool | None = None
    is_featured: bool | None = None
    rejection_reason: str | None = None
    category_id: uuid.UUID | None = None
