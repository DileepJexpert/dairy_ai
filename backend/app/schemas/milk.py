from pydantic import BaseModel
from typing import Optional
from datetime import date


class MilkRecordCreate(BaseModel):
    date: date
    session: str  # morning/evening
    quantity_litres: float
    fat_pct: Optional[float] = None
    snf_pct: Optional[float] = None
    buyer_name: Optional[str] = None
    price_per_litre: Optional[float] = None


class MilkRecordResponse(BaseModel):
    id: str
    cattle_id: str
    date: date
    session: str
    quantity_litres: float
    fat_pct: Optional[float] = None
    price_per_litre: Optional[float] = None
    total_amount: Optional[float] = None
    model_config = {"from_attributes": True}


class MilkSummary(BaseModel):
    total_litres: float
    total_income: float
    avg_price: Optional[float] = None
    best_cow_id: Optional[str] = None
    best_cow_name: Optional[str] = None
    best_cow_yield: Optional[float] = None


class MilkPriceResponse(BaseModel):
    buyer_name: str
    buyer_type: str
    price_per_litre: float
    fat_pct_basis: Optional[float] = None
    date: date
    model_config = {"from_attributes": True}
