from pydantic import BaseModel
from datetime import date, datetime
from typing import Optional, List


class CollectionCenterCreate(BaseModel):
    name: str
    code: str
    cooperative_id: Optional[str] = None
    address: Optional[str] = None
    village: Optional[str] = None
    district: Optional[str] = None
    state: Optional[str] = None
    pincode: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    capacity_litres: float = 500.0
    has_fat_analyzer: bool = False
    has_snf_analyzer: bool = False
    manager_name: Optional[str] = None
    manager_phone: Optional[str] = None


class CollectionCenterUpdate(BaseModel):
    name: Optional[str] = None
    code: Optional[str] = None
    cooperative_id: Optional[str] = None
    address: Optional[str] = None
    village: Optional[str] = None
    district: Optional[str] = None
    state: Optional[str] = None
    pincode: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    capacity_litres: Optional[float] = None
    has_fat_analyzer: Optional[bool] = None
    has_snf_analyzer: Optional[bool] = None
    manager_name: Optional[str] = None
    manager_phone: Optional[str] = None


class MilkCollectionCreate(BaseModel):
    center_id: str
    farmer_id: str
    date: date
    shift: str
    quantity_litres: float
    fat_pct: Optional[float] = None
    snf_pct: Optional[float] = None
    temperature_celsius: Optional[float] = None
    collected_by: Optional[str] = None


class CollectionRouteCreate(BaseModel):
    name: str
    date: date
    shift: str
    vehicle_number: Optional[str] = None
    driver_name: Optional[str] = None
    driver_phone: Optional[str] = None
    center_ids: List[str]


class CollectionRouteUpdate(BaseModel):
    status: Optional[str] = None
    actual_start_time: Optional[datetime] = None
    actual_end_time: Optional[datetime] = None
    total_collected_litres: Optional[float] = None


class ColdChainReadingCreate(BaseModel):
    center_id: Optional[str] = None
    route_id: Optional[str] = None
    temperature_celsius: float
    humidity_pct: Optional[float] = None
    device_id: Optional[str] = None
