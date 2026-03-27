from pydantic import BaseModel
from typing import Optional
from datetime import date


class TransactionCreate(BaseModel):
    type: str  # income/expense
    category: str
    amount: float
    description: Optional[str] = None
    cattle_id: Optional[str] = None
    date: date


class TransactionResponse(BaseModel):
    id: str
    type: str
    category: str
    amount: float
    description: Optional[str] = None
    date: date
    model_config = {"from_attributes": True}


class ProfitLossSummary(BaseModel):
    total_income: float
    total_expenses: float
    net_profit: float
    income_by_category: dict
    expense_by_category: dict
