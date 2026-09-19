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
    bank_name: str | None = None
    account_number: str | None = None
    ifsc_code: str | None = None
    account_holder_name: str | None = None
    upi_id: str | None = None
    description: str | None = None
    logo_url: str | None = None
    banner_url: str | None = None
    support_phone: str | None = None
    support_email: str | None = None
    return_policy: str | None = None
    products_services: list[str] | None = None
    service_areas: list[str] | None = None
    commission_rate: float | None = 5.0


class VendorUpdate(BaseModel):
    business_name: str | None = None
    contact_person: str | None = None
    address: str | None = None
    district: str | None = None
    state: str | None = None
    gst_number: str | None = None
    license_number: str | None = None
    bank_name: str | None = None
    account_number: str | None = None
    ifsc_code: str | None = None
    account_holder_name: str | None = None
    upi_id: str | None = None
    description: str | None = None
    logo_url: str | None = None
    banner_url: str | None = None
    support_phone: str | None = None
    support_email: str | None = None
    return_policy: str | None = None
    products_services: list[str] | None = None
    service_areas: list[str] | None = None
    commission_rate: float | None = None


class VendorPayoutCreate(BaseModel):
    amount: float
    gross_amount: float | None = None
    commission_amount: float | None = None
    payment_reference: str | None = None
    bank_name: str | None = None
    account_number: str | None = None
    remarks: str | None = None


class VendorCommissionUpdate(BaseModel):
    commission_rate: float

