import uuid
from datetime import datetime, timezone
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class Input(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class OfferUpdate(Input):
    selling_price: Decimal | None = Field(default=None, gt=0, max_digits=12, decimal_places=2)
    mrp: Decimal | None = Field(default=None, ge=0, max_digits=12, decimal_places=2)
    available_stock: int | None = Field(default=None, ge=0)

    @model_validator(mode="after")
    def values_required(self):
        if not self.model_fields_set or any(getattr(self, key) is None for key in self.model_fields_set):
            raise ValueError("Provide price, MRP or stock; null values are not supported")
        return self


class SellerUpdate(Input):
    status: Literal["approved", "suspended"]
    reason: str = Field(default="", max_length=500)


class OfferCreate(Input):
    source_product_id: uuid.UUID
    seller_sku: str = Field(min_length=1, max_length=100)
    selling_price: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    mrp: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    available_stock: int = Field(ge=0)

    @model_validator(mode="after")
    def price(self):
        if self.mrp < self.selling_price:
            raise ValueError("MRP must be at least the selling price")
        return self


class CouponInput(Input):
    code: str = Field(min_length=3, max_length=40, pattern=r"^[A-Za-z0-9_-]+$")
    description: str = Field(min_length=2, max_length=500)
    discount_type: Literal["percentage", "flat"] = "percentage"
    discount_value: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    min_order_value: Decimal = Field(default=0, ge=0, max_digits=12, decimal_places=2)
    max_discount_cap: Decimal | None = Field(default=None, gt=0, max_digits=12, decimal_places=2)
    valid_until: datetime | None = None
    is_active: bool = True

    @field_validator("code")
    @classmethod
    def uppercase(cls, value):
        return value.upper()

    @field_validator("valid_until")
    @classmethod
    def utc(cls, value):
        if value is not None and value.tzinfo is not None:
            return value.astimezone(timezone.utc).replace(tzinfo=None)
        return value

    @model_validator(mode="after")
    def percentage(self):
        if self.discount_type == "percentage" and self.discount_value > 100:
            raise ValueError("Percentage must not exceed 100")
        return self


class ActiveUpdate(Input):
    is_active: bool


class CouponQuote(Input):
    code: str = Field(min_length=3, max_length=40)


class CertificateInput(Input):
    product_id: uuid.UUID
    batch_number: str = Field(min_length=2, max_length=100)
    test_date: datetime
    laboratory: str = Field(min_length=2, max_length=200)
    fssai_license: str = Field(default="", max_length=100)
    purity_percent: Decimal | None = Field(default=None, ge=0, le=100)
    test_parameters: dict[str, str] = Field(default_factory=dict)
    status: Literal["CERTIFIED", "PENDING_REVIEW", "REJECTED"] = "PENDING_REVIEW"
    certified_by: str = Field(default="", max_length=200)
    remarks: str = Field(default="", max_length=5000)
    report_url: str | None = Field(default=None, max_length=1000)

    @field_validator("test_date")
    @classmethod
    def utc(cls, value):
        return value.astimezone(timezone.utc).replace(tzinfo=None) if value.tzinfo else value

    @field_validator("report_url")
    @classmethod
    def report_link(cls, value):
        from urllib.parse import urlparse
        if value is None or not value.strip():
            return None
        parsed = urlparse(value)
        if parsed.scheme not in {"https", "http"} or not parsed.netloc or parsed.username or parsed.password:
            raise ValueError("Use an http(s) report URL without embedded credentials")
        return value

    @model_validator(mode="after")
    def evidence(self):
        if self.status == "CERTIFIED" and (not self.report_url or not self.certified_by):
            raise ValueError("Certified records require a report URL and certifier name")
        return self
