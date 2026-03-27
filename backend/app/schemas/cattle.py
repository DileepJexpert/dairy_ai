from pydantic import BaseModel, field_validator
from typing import Optional
from datetime import date


class CattleCreate(BaseModel):
    tag_id: str
    name: Optional[str] = None
    breed: str
    sex: str = "female"
    dob: Optional[date] = None
    weight_kg: Optional[float] = None
    photo_url: Optional[str] = None

    @field_validator("tag_id")
    @classmethod
    def validate_tag(cls, v: str) -> str:
        v = v.strip()
        if len(v) < 1:
            raise ValueError("tag_id is required")
        return v


class CattleUpdate(BaseModel):
    name: Optional[str] = None
    weight_kg: Optional[float] = None
    photo_url: Optional[str] = None
    status: Optional[str] = None
    lactation_number: Optional[int] = None
    last_calving_date: Optional[date] = None


class CattleResponse(BaseModel):
    id: str
    farmer_id: str
    tag_id: str
    name: Optional[str] = None
    breed: str
    sex: str
    dob: Optional[date] = None
    weight_kg: Optional[float] = None
    photo_url: Optional[str] = None
    status: str
    lactation_number: Optional[int] = None

    model_config = {"from_attributes": True}


class CattleListResponse(BaseModel):
    success: bool = True
    data: list[CattleResponse]
    total: int
    message: str = "Cattle list"


class CattleDashboard(BaseModel):
    total: int = 0
    active: int = 0
    dry: int = 0
    sold: int = 0
    dead: int = 0
