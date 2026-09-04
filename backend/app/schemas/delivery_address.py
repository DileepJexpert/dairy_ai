from pydantic import BaseModel, Field


class DeliveryAddressCreate(BaseModel):
    recipient_name: str = Field(min_length=1, max_length=120)
    phone: str = Field(pattern=r"^[0-9+ -]{8,20}$")
    address_line1: str = Field(min_length=3, max_length=250)
    address_line2: str | None = Field(default=None, max_length=250)
    landmark: str | None = Field(default=None, max_length=160)
    village_or_city: str = Field(min_length=2, max_length=120)
    district: str = Field(min_length=2, max_length=120)
    state: str = Field(min_length=2, max_length=120)
    postal_code: str = Field(pattern=r"^[0-9]{6}$")
    is_default: bool = False


class DeliveryAddressUpdate(BaseModel):
    recipient_name: str | None = Field(default=None, min_length=1, max_length=120)
    phone: str | None = Field(default=None, pattern=r"^[0-9+ -]{8,20}$")
    address_line1: str | None = Field(default=None, min_length=3, max_length=250)
    address_line2: str | None = Field(default=None, max_length=250)
    landmark: str | None = Field(default=None, max_length=160)
    village_or_city: str | None = Field(default=None, min_length=2, max_length=120)
    district: str | None = Field(default=None, min_length=2, max_length=120)
    state: str | None = Field(default=None, min_length=2, max_length=120)
    postal_code: str | None = Field(default=None, pattern=r"^[0-9]{6}$")
    is_default: bool | None = None
