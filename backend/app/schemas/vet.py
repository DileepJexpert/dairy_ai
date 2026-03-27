from datetime import date
from typing import Optional

from pydantic import BaseModel, Field


class VetRegister(BaseModel):
    license_number: str
    qualification: str  # bvsc/mvsc/phd/paravet
    specializations: list[str] = []
    experience_years: int = 0
    languages: list[str] = []
    consultation_fee: float = 0.0
    bio: Optional[str] = None


class VetUpdate(BaseModel):
    license_number: Optional[str] = None
    qualification: Optional[str] = None
    specializations: Optional[list[str]] = None
    experience_years: Optional[int] = None
    languages: Optional[list[str]] = None
    consultation_fee: Optional[float] = None
    bio: Optional[str] = None
    photo_url: Optional[str] = None
    certificate_url: Optional[str] = None
    availability_start: Optional[str] = None
    availability_end: Optional[str] = None


class VetSearchFilters(BaseModel):
    specialization: Optional[str] = None
    language: Optional[str] = None
    available: Optional[bool] = None


class ConsultationCreate(BaseModel):
    cattle_id: str
    symptoms: str
    consultation_type: str = "video"


class ConsultationUpdate(BaseModel):
    vet_diagnosis: Optional[str] = None
    vet_notes: Optional[str] = None


class MedicineItem(BaseModel):
    name: str
    dosage: str
    frequency: str
    duration_days: int


class PrescriptionCreate(BaseModel):
    medicines: list[MedicineItem]
    instructions: Optional[str] = None
    follow_up_date: Optional[date] = None


class RatingCreate(BaseModel):
    rating: int = Field(ge=1, le=5)
    review: Optional[str] = None


class AvailabilityUpdate(BaseModel):
    is_available: bool
