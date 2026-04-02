from pydantic import BaseModel, field_validator
from typing import Optional
from datetime import datetime


# ── Listing Schemas ──────────────────────────────────────────────────────────


class ListingCreate(BaseModel):
    cattle_id: Optional[str] = None
    category: str
    breed: str
    age_months: Optional[int] = None
    weight_kg: Optional[float] = None
    milk_yield_litres: Optional[float] = None
    fat_pct: Optional[float] = None
    lactation_number: Optional[int] = None
    is_pregnant: bool = False
    months_pregnant: Optional[int] = None
    title: str
    description: Optional[str] = None
    price: float
    is_negotiable: bool = True
    photos: Optional[list[str]] = None
    video_url: Optional[str] = None
    location_village: Optional[str] = None
    location_district: Optional[str] = None
    location_state: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    status: str = "active"

    @field_validator("title")
    @classmethod
    def validate_title(cls, v: str) -> str:
        v = v.strip()
        if len(v) < 5:
            raise ValueError("Title must be at least 5 characters")
        if len(v) > 200:
            raise ValueError("Title must be at most 200 characters")
        return v

    @field_validator("price")
    @classmethod
    def validate_price(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("Price must be greater than zero")
        return v

    @field_validator("category")
    @classmethod
    def validate_category(cls, v: str) -> str:
        allowed = {"cow", "buffalo", "bull", "calf", "heifer"}
        if v not in allowed:
            raise ValueError(f"Category must be one of: {', '.join(sorted(allowed))}")
        return v


class ListingUpdate(BaseModel):
    category: Optional[str] = None
    breed: Optional[str] = None
    age_months: Optional[int] = None
    weight_kg: Optional[float] = None
    milk_yield_litres: Optional[float] = None
    fat_pct: Optional[float] = None
    lactation_number: Optional[int] = None
    is_pregnant: Optional[bool] = None
    months_pregnant: Optional[int] = None
    title: Optional[str] = None
    description: Optional[str] = None
    price: Optional[float] = None
    is_negotiable: Optional[bool] = None
    photos: Optional[list[str]] = None
    video_url: Optional[str] = None
    location_village: Optional[str] = None
    location_district: Optional[str] = None
    location_state: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    status: Optional[str] = None


class ListingResponse(BaseModel):
    id: str
    seller_id: str
    cattle_id: Optional[str] = None
    category: str
    breed: str
    age_months: Optional[int] = None
    weight_kg: Optional[float] = None
    milk_yield_litres: Optional[float] = None
    fat_pct: Optional[float] = None
    lactation_number: Optional[int] = None
    is_pregnant: bool = False
    months_pregnant: Optional[int] = None
    health_verified: bool = False
    vaccination_verified: bool = False
    title: str
    description: Optional[str] = None
    price: float
    is_negotiable: bool = True
    photos: Optional[list[str]] = None
    video_url: Optional[str] = None
    location_village: Optional[str] = None
    location_district: Optional[str] = None
    location_state: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    views_count: int = 0
    inquiries_count: int = 0
    status: str
    featured: bool = False
    expires_at: Optional[datetime] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    seller_name: Optional[str] = None
    seller_phone: Optional[str] = None
    is_favorited: bool = False

    model_config = {"from_attributes": True}


class ListingListResponse(BaseModel):
    success: bool = True
    data: list[ListingResponse]
    total: int
    page: int
    per_page: int
    message: str = "Listings"


# ── Inquiry Schemas ──────────────────────────────────────────────────────────


class InquiryCreate(BaseModel):
    message: str
    offered_price: Optional[float] = None
    phone_shared: bool = False

    @field_validator("message")
    @classmethod
    def validate_message(cls, v: str) -> str:
        v = v.strip()
        if len(v) < 5:
            raise ValueError("Message must be at least 5 characters")
        return v


class InquiryResponse(BaseModel):
    id: str
    listing_id: str
    buyer_id: str
    message: str
    offered_price: Optional[float] = None
    phone_shared: bool = False
    status: str
    seller_response: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    buyer_phone: Optional[str] = None
    listing_title: Optional[str] = None

    model_config = {"from_attributes": True}


class InquiryRespondRequest(BaseModel):
    response: str
    status: str

    @field_validator("status")
    @classmethod
    def validate_status(cls, v: str) -> str:
        allowed = {"accepted", "rejected"}
        if v not in allowed:
            raise ValueError(f"Status must be one of: {', '.join(sorted(allowed))}")
        return v


# ── Search Params ────────────────────────────────────────────────────────────


class ListingSearchParams(BaseModel):
    category: Optional[str] = None
    breed: Optional[str] = None
    min_price: Optional[float] = None
    max_price: Optional[float] = None
    district: Optional[str] = None
    state: Optional[str] = None
    is_pregnant: Optional[bool] = None
    health_verified: Optional[bool] = None
    sort_by: str = "created_at"
    page: int = 1
    per_page: int = 20

    @field_validator("sort_by")
    @classmethod
    def validate_sort_by(cls, v: str) -> str:
        allowed = {"created_at", "price_asc", "price_desc", "distance", "views"}
        if v not in allowed:
            raise ValueError(f"sort_by must be one of: {', '.join(sorted(allowed))}")
        return v

    @field_validator("per_page")
    @classmethod
    def validate_per_page(cls, v: int) -> int:
        if v < 1 or v > 100:
            raise ValueError("per_page must be between 1 and 100")
        return v
