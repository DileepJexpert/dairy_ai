from pydantic import BaseModel
from typing import Optional
from datetime import date, datetime


class SchemeFilter(BaseModel):
    category: Optional[str] = None
    level: Optional[str] = None
    state: Optional[str] = None
    is_active: bool = True


class SchemeResponse(BaseModel):
    id: str
    name: str
    short_name: str
    category: str
    level: str
    description: str
    benefits: str
    subsidy_amount_max: Optional[float] = None
    subsidy_percentage: Optional[float] = None
    eligibility_criteria: Optional[dict] = None
    required_documents: Optional[list] = None
    applicable_states: Optional[list] = None
    min_cattle_count: Optional[int] = None
    max_cattle_count: Optional[int] = None
    min_land_acres: Optional[float] = None
    gender_specific: Optional[str] = None
    caste_categories: Optional[list] = None
    age_min: Optional[int] = None
    age_max: Optional[int] = None
    application_url: Optional[str] = None
    helpline: Optional[str] = None
    nodal_agency: str
    implementing_agency: str
    is_active: bool
    last_date: Optional[date] = None
    budget_crores: Optional[float] = None
    beneficiaries_target: Optional[int] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class SchemeListItem(BaseModel):
    id: str
    name: str
    short_name: str
    category: str
    level: str
    description: str
    subsidy_amount_max: Optional[float] = None
    subsidy_percentage: Optional[float] = None
    nodal_agency: str
    is_active: bool
    last_date: Optional[date] = None

    model_config = {"from_attributes": True}


class EligibilityCriterion(BaseModel):
    criterion: str
    met: bool
    detail: str


class EligibilityResult(BaseModel):
    eligible: bool
    scheme_id: str
    scheme_name: str
    criteria_results: list[EligibilityCriterion]
    missing_documents: list[str]
    message: str


class SchemeApplyRequest(BaseModel):
    documents: Optional[list[dict]] = None
    applied_amount: Optional[float] = None
    notes: Optional[str] = None


class ApplicationResponse(BaseModel):
    id: str
    scheme_id: str
    scheme_name: str
    farmer_id: str
    status: str
    application_ref: Optional[str] = None
    documents_uploaded: Optional[list] = None
    applied_amount: Optional[float] = None
    approved_amount: Optional[float] = None
    rejection_reason: Optional[str] = None
    notes: Optional[str] = None
    applied_at: Optional[date] = None
    reviewed_at: Optional[date] = None
    disbursed_at: Optional[date] = None
    created_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class ApplicationStatusUpdate(BaseModel):
    status: str
    notes: Optional[str] = None
    approved_amount: Optional[float] = None
    rejection_reason: Optional[str] = None


class RecommendedScheme(BaseModel):
    id: str
    name: str
    short_name: str
    category: str
    level: str
    description: str
    benefits: str
    subsidy_amount_max: Optional[float] = None
    subsidy_percentage: Optional[float] = None
    eligibility_match_score: float
    nodal_agency: str

    model_config = {"from_attributes": True}


class BookmarkResponse(BaseModel):
    bookmarked: bool
    scheme_id: str
