import uuid
from pydantic import BaseModel, Field


class CheckoutRequest(BaseModel):
    delivery_address_id: uuid.UUID
    idempotency_key: str = Field(min_length=8, max_length=128)


class CourierWebhookPayload(BaseModel):
    order_id: str
    carrier: str = "DTDC Express"
    awb_number: str | None = None
    status: str
    location: str | None = None
    remarks: str | None = None
    timestamp: str | None = None


class PaymentWebhookPayload(BaseModel):
    order_id: str
    payment_id: str | None = None
    payment_status: str = "PAID"
    amount: float | None = None
    payment_method: str | None = "wallet"
