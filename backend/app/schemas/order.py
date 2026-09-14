import uuid
from typing import Literal
from pydantic import BaseModel, Field


class CheckoutRequest(BaseModel):
    payment_method: Literal['cod', 'wallet', 'upi', 'card', 'netbanking'] = 'cod'
    delivery_address_id: uuid.UUID
    idempotency_key: str = Field(min_length=8, max_length=128)
    coupon_code: str | None = Field(default=None, min_length=3, max_length=40)
