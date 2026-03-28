from pydantic import BaseModel
from datetime import date
from typing import Optional, List


class PaymentCycleCreate(BaseModel):
    cooperative_id: Optional[str] = None
    cycle_type: str  # weekly / fortnightly / monthly
    period_start: date
    period_end: date


class FarmerPaymentUpdate(BaseModel):
    payment_method: Optional[str] = None
    upi_id: Optional[str] = None
    bank_account: Optional[str] = None
    bank_ifsc: Optional[str] = None


class LoanApply(BaseModel):
    farmer_id: str
    loan_type: str
    principal_amount: float
    tenure_months: int
    purpose: Optional[str] = None


class LoanApprove(BaseModel):
    interest_rate_pct: float
    emi_amount: float
    approved_by: str


class SubsidyApplicationCreate(BaseModel):
    farmer_id: str
    scheme: str
    scheme_name: str
    applied_amount: float
    documents: Optional[List[str]] = None
    notes: Optional[str] = None


class SubsidyStatusUpdate(BaseModel):
    status: str
    approved_amount: Optional[float] = None
    disbursed_amount: Optional[float] = None
    rejection_reason: Optional[str] = None


class InsuranceCreate(BaseModel):
    farmer_id: str
    cattle_id: str
    policy_number: str
    insurer_name: str
    sum_insured: float
    premium_amount: float
    govt_subsidy_pct: float = 0
    farmer_premium: float
    start_date: date
    end_date: date


class InsuranceClaimCreate(BaseModel):
    claim_amount: float
    claim_reason: str
    ear_tag_photo_url: Optional[str] = None
    cattle_photo_url: Optional[str] = None
