import uuid
from datetime import datetime
from pydantic import BaseModel, Field


class RFQCreate(BaseModel):
    product_id: str | None = None
    product_title: str = Field(..., min_length=2, max_length=250)
    quantity: int = Field(default=1, ge=1)
    unit: str = Field(default="units", max_length=50)
    buyer_name: str = Field(..., min_length=2, max_length=120)
    buyer_phone: str = Field(..., min_length=8, max_length=20)
    buyer_email: str | None = None
    pincode: str | None = None
    city: str | None = None
    state: str | None = None
    requirement_details: str | None = None
    preferred_contact: str = Field(default="whatsapp")


class RFQResponse(BaseModel):
    id: str
    reference_no: str
    product_id: str | None = None
    product_title: str
    quantity: int
    unit: str
    buyer_name: str
    buyer_phone: str
    buyer_email: str | None = None
    pincode: str | None = None
    city: str | None = None
    state: str | None = None
    requirement_details: str | None = None
    preferred_contact: str
    status: str
    created_at: str
