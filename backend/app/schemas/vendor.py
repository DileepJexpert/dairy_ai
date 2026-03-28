from pydantic import BaseModel


class VendorCreate(BaseModel):
    business_name: str
    vendor_type: str
    contact_person: str | None = None
    address: str | None = None
    district: str | None = None
    state: str | None = None
    gst_number: str | None = None
    license_number: str | None = None
    description: str | None = None
    products_services: list[str] | None = None
    service_areas: list[str] | None = None


class VendorUpdate(BaseModel):
    business_name: str | None = None
    contact_person: str | None = None
    address: str | None = None
    district: str | None = None
    state: str | None = None
    gst_number: str | None = None
    license_number: str | None = None
    description: str | None = None
    products_services: list[str] | None = None
    service_areas: list[str] | None = None
