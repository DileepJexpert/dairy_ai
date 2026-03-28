from pydantic import BaseModel


class CooperativeCreate(BaseModel):
    name: str
    registration_number: str
    cooperative_type: str
    chairman_name: str | None = None
    secretary_name: str | None = None
    address: str | None = None
    village: str | None = None
    district: str | None = None
    state: str | None = None
    milk_price_per_litre: float | None = None
    collection_centers: list[str] | None = None
    services_offered: list[str] | None = None


class CooperativeUpdate(BaseModel):
    name: str | None = None
    chairman_name: str | None = None
    secretary_name: str | None = None
    address: str | None = None
    village: str | None = None
    district: str | None = None
    state: str | None = None
    milk_price_per_litre: float | None = None
    collection_centers: list[str] | None = None
    services_offered: list[str] | None = None
