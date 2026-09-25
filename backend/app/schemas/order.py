import uuid
from typing import Literal
from decimal import Decimal
from pydantic import BaseModel, Field


class CheckoutPricingInput(BaseModel):
    payment_method: Literal['cod', 'wallet', 'upi', 'card', 'netbanking'] = 'cod'
    delivery_address_id: uuid.UUID
    coupon_code: str | None = Field(default=None, min_length=3, max_length=40)


class CheckoutRequest(CheckoutPricingInput):
    idempotency_key: str = Field(min_length=8, max_length=128)
    expected_total: Decimal | None = Field(default=None, ge=0)
