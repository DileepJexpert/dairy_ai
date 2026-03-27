from pydantic import BaseModel
from typing import Optional
from datetime import date, datetime


class HealthRecordCreate(BaseModel):
    date: date
    record_type: str
    symptoms: Optional[str] = None
    diagnosis: Optional[str] = None
    treatment: Optional[str] = None
    severity: Optional[int] = None
    notes: Optional[str] = None


class HealthRecordResponse(BaseModel):
    id: str
    cattle_id: str
    date: date
    record_type: str
    symptoms: Optional[str] = None
    diagnosis: Optional[str] = None
    treatment: Optional[str] = None
    severity: Optional[int] = None
    resolved: bool = False
    notes: Optional[str] = None
    model_config = {"from_attributes": True}


class VaccinationCreate(BaseModel):
    vaccine_name: str
    date_given: date
    next_due_date: Optional[date] = None
    batch_number: Optional[str] = None
    administered_by: Optional[str] = None
    notes: Optional[str] = None


class VaccinationResponse(BaseModel):
    id: str
    cattle_id: str
    vaccine_name: str
    date_given: date
    next_due_date: Optional[date] = None
    administered_by: Optional[str] = None
    model_config = {"from_attributes": True}


class SensorDataCreate(BaseModel):
    temperature: Optional[float] = None
    heart_rate: Optional[int] = None
    activity_level: Optional[float] = None
    rumination_minutes: Optional[int] = None
    battery_pct: Optional[int] = None
    rssi: Optional[int] = None


class SensorReadingResponse(BaseModel):
    time: datetime
    cattle_id: str
    temperature: Optional[float] = None
    heart_rate: Optional[int] = None
    activity_level: Optional[float] = None
    rumination_minutes: Optional[int] = None
    battery_pct: Optional[int] = None
    model_config = {"from_attributes": True}


class SensorStats(BaseModel):
    avg_temperature: Optional[float] = None
    min_temperature: Optional[float] = None
    max_temperature: Optional[float] = None
    avg_heart_rate: Optional[float] = None
    avg_activity: Optional[float] = None


class AnomalyAlert(BaseModel):
    cattle_id: str
    alert_type: str
    message: str
    current_value: float
    threshold: float
