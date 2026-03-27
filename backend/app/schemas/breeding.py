from pydantic import BaseModel
from typing import Optional
from datetime import date


class BreedingEventCreate(BaseModel):
    event_type: str
    date: date
    bull_id: Optional[str] = None
    ai_technician: Optional[str] = None
    semen_batch: Optional[str] = None
    expected_calving_date: Optional[date] = None
    notes: Optional[str] = None


class BreedingEventResponse(BaseModel):
    id: str
    cattle_id: str
    event_type: str
    date: date
    bull_id: Optional[str] = None
    expected_calving_date: Optional[date] = None
    model_config = {"from_attributes": True}
