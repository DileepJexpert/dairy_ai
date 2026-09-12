import uuid
from pydantic import BaseModel, Field


class CheckoutRequest(BaseModel):
    delivery_address_id: uuid.UUID
    idempotency_key: str = Field(min_length=8, max_length=128)
