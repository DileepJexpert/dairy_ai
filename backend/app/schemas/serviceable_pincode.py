"""Pydantic schemas for pincode delivery checks and admin management."""
from datetime import datetime
from decimal import Decimal
from typing import Optional
from pydantic import BaseModel, Field


class PincodeCheckResponse(BaseModel):
    is_serviceable: bool
    pincode: str
    city: Optional[str] = None
    state: Optional[str] = None
    delivery_days_min: Optional[int] = None
    delivery_days_max: Optional[int] = None
    expected_delivery_text: Optional[str] = None
    express_available: bool = False
    delivery_fee: Optional[str] = "0.00"
    message: Optional[str] = None


class PincodeCreate(BaseModel):
    pincode: str = Field(..., min_length=6, max_length=6, pattern=r"^\d{6}$")
    city: str = Field(..., max_length=100)
    state: str = Field(..., max_length=100)
    is_serviceable: bool = True
    delivery_days_min: int = Field(1, ge=0, le=30)
    delivery_days_max: int = Field(2, ge=0, le=30)
    express_available: bool = True
    delivery_fee: Decimal = Decimal("0.00")
    delivery_message: Optional[str] = Field(None, max_length=250)


class PincodeUpdate(BaseModel):
    city: Optional[str] = Field(None, max_length=100)
    state: Optional[str] = Field(None, max_length=100)
    is_serviceable: Optional[bool] = None
    delivery_days_min: Optional[int] = Field(None, ge=0, le=30)
    delivery_days_max: Optional[int] = Field(None, ge=0, le=30)
    express_available: Optional[bool] = None
    delivery_fee: Optional[Decimal] = None
    delivery_message: Optional[str] = Field(None, max_length=250)


class PincodeBulkItem(BaseModel):
    pincode: str = Field(..., min_length=6, max_length=6, pattern=r"^\d{6}$")
    city: str
    state: str
    delivery_days_min: int = 1
    delivery_days_max: int = 2
    express_available: bool = True
    delivery_message: Optional[str] = None


class PincodeBulkCreate(BaseModel):
    pincodes: list[PincodeBulkItem]


class PincodeResponse(BaseModel):
    pincode: str
    city: str
    state: str
    is_serviceable: bool
    delivery_days_min: int
    delivery_days_max: int
    express_available: bool
    delivery_fee: str
    delivery_message: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
