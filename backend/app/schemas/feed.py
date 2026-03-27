from pydantic import BaseModel
from typing import Optional
from datetime import date


class FeedIngredient(BaseModel):
    ingredient: str
    quantity_kg: float
    cost_per_kg: float


class FeedPlanResponse(BaseModel):
    id: str
    cattle_id: str
    plan: list[FeedIngredient]
    total_cost_per_day: float
    nutrition_score: Optional[float] = None
    created_by: str
    valid_from: date
    model_config = {"from_attributes": True}
