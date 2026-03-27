from pydantic import BaseModel
from typing import Optional


class FarmerCreate(BaseModel):
    name: str
    village: Optional[str] = None
    district: Optional[str] = None
    state: Optional[str] = None
    language: str = "hi"
    lat: Optional[float] = None
    lng: Optional[float] = None


class FarmerUpdate(BaseModel):
    name: Optional[str] = None
    village: Optional[str] = None
    district: Optional[str] = None
    state: Optional[str] = None
    language: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    profile_photo_url: Optional[str] = None


class FarmerResponse(BaseModel):
    id: str
    user_id: str
    name: str
    village: Optional[str] = None
    district: Optional[str] = None
    state: Optional[str] = None
    language: str
    total_cattle: int

    model_config = {"from_attributes": True}
