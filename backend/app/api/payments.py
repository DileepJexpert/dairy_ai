"""
Farmer Payment, Loan, Insurance, and Subsidy APIs.
Covers: auto-payment cycles, farmer ledger, loans, cattle insurance, govt subsidies.
"""
import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from datetime import date

from app.database import get_db
from app.dependencies import get_current_user, require_role
from app.models.user import User, UserRole
from app.models.payment import (
    PaymentCycle, FarmerPayment, Loan, SubsidyApplication, CattleInsurance,
)
from app.schemas.payment import (
    PaymentCycleCreate, FarmerPaymentUpdate,
    LoanApply, LoanApprove,
    SubsidyApplicationCreate, SubsidyStatusUpdate,
    InsuranceCreate, InsuranceClaimCreate,
)
from app.services import payment_service

logger = logging.getLogger("dairy_ai.api.payments")

router = APIRouter(prefix="/payments", tags=["payments"])


# ---------------------------------------------------------------------------
# Payment Cycle Endpoints
# ---------------------------------------------------------------------------

@router.post("/cycles", status_code=201)
async def create_payment_cycle(
    data: PaymentCycleCreate,
    current_user: User = Depends(require_role(UserRole.admin, UserRole.super_admin, UserRole.cooperative)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(
        f"POST /payments/cycles called | user_id={current_user.id} | "
        f"type={data.cycle_type} | period={data.period_start} to {data.period_end}"
    )
    cycle = await payment_service.create_payment_cycle(db, data.model_dump())
    logger.info(f"Payment cycle created | cycle_id={cycle.id}")
    return {
        "success": True,
        "data": {
            "id": str(cycle.id),
            "cycle_type": cycle.cycle_type.value if hasattr(cycle.cycle_type, "value") else cycle.cycle_type,
            "period_start": str(cycle.period_start),
            "period_end": str(cycle.period_end),
            "status": cycle.status.value if hasattr(cycle.status, "value") else cycle.status,
        },
        "message": "Payment cycle created",
    }


@router.post("/cycles/{cycle_id}/process")
async def process_payment_cycle(
    cycle_id: str,
    current_user: User = Depends(require_role(UserRole.admin, UserRole.super_admin, UserRole.cooperative)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"POST /payments/cycles/{cycle_id}/process called | user_id={current_user.id}")
    try:
        cycle = await payment_service.process_payment_cycle(db, uuid.UUID(cycle_id))
        logger.info(
            f"Payment cycle processed | cycle_id={cycle.id} | "
            f"farmers={cycle.farmers_count} | net_payout=₹{cycle.net_payout}"
        )
        return {
            "success": True,
            "data": {
                "id": str(cycle.id),
                "status": cycle.status.value if hasattr(cycle.status, "value") else cycle.status,
                "total_litres": cycle.total_litres,
                "total_amount": cycle.total_amount,
                "total_deductions": cycle.total_deductions,
                "total_bonuses": cycle.total_bonuses,
                "net_payout": cycle.net_payout,
                "farmers_count": cycle.farmers_count,
            },
            "message": f"Payment cycle processed — ₹{cycle.net_payout} to {cycle.farmers_count} farmers",
        }
    except ValueError as e:
        logger.warning(f"Payment cycle processing failed: {e}")
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/cycles")
async def list_cycles(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /payments/cycles called | user_id={current_user.id}")
    result = await db.execute(
        select(PaymentCycle).order_by(PaymentCycle.created_at.desc()).limit(20)
    )
    cycles = list(result.scalars().all())
    logger.info(f"Listed {len(cycles)} payment cycles")
    return {
        "success": True,
        "data": [
            {
                "id": str(c.id),
                "cycle_type": c.cycle_type.value if hasattr(c.cycle_type, "value") else c.cycle_type,
                "period_start": str(c.period_start),
                "period_end": str(c.period_end),
                "net_payout": c.net_payout,
                "farmers_count": c.farmers_count,
                "status": c.status.value if hasattr(c.status, "value") else c.status,
            }
            for c in cycles
        ],
        "message": f"Found {len(cycles)} cycles",
    }


# ---------------------------------------------------------------------------
# Farmer Ledger
# ---------------------------------------------------------------------------

@router.get("/ledger/{farmer_id}")
async def farmer_ledger(
    farmer_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /payments/ledger/{farmer_id} called | user_id={current_user.id}")
    ledger = await payment_service.get_farmer_ledger(db, uuid.UUID(farmer_id))
    logger.info(f"Farmer ledger retrieved | farmer_id={farmer_id}")
    return {"success": True, "data": ledger, "message": "Farmer ledger"}


# ---------------------------------------------------------------------------
# Loan Endpoints
# ---------------------------------------------------------------------------

@router.post("/loans/apply", status_code=201)
async def apply_for_loan(
    data: LoanApply,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(
        f"POST /payments/loans/apply called | user_id={current_user.id} | "
        f"type={data.loan_type} | amount=₹{data.principal_amount} | tenure={data.tenure_months}m"
    )
    loan = await payment_service.apply_loan(db, data.model_dump())
    logger.info(f"Loan application created | loan_id={loan.id} | emi=₹{loan.emi_amount}")
    return {
        "success": True,
        "data": {
            "id": str(loan.id),
            "farmer_id": str(loan.farmer_id),
            "loan_type": loan.loan_type.value if hasattr(loan.loan_type, "value") else loan.loan_type,
            "principal_amount": loan.principal_amount,
            "emi_amount": loan.emi_amount,
            "tenure_months": loan.tenure_months,
            "status": loan.status.value if hasattr(loan.status, "value") else loan.status,
        },
        "message": "Loan application submitted",
    }


@router.put("/loans/{loan_id}/approve")
async def approve_loan(
    loan_id: str,
    data: LoanApprove,
    current_user: User = Depends(require_role(UserRole.admin, UserRole.super_admin, UserRole.cooperative)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"PUT /payments/loans/{loan_id}/approve called | user_id={current_user.id}")
    try:
        loan = await payment_service.approve_loan(db, uuid.UUID(loan_id), data.model_dump())
        logger.info(f"Loan approved | loan_id={loan.id} | emi=₹{loan.emi_amount}")
        return {
            "success": True,
            "data": {
                "id": str(loan.id),
                "status": loan.status.value if hasattr(loan.status, "value") else loan.status,
                "emi_amount": loan.emi_amount,
                "outstanding_amount": loan.outstanding_amount,
            },
            "message": "Loan approved",
        }
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/loans")
async def list_loans(
    farmer_id: str | None = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /payments/loans called | farmer_id={farmer_id}")
    query = select(Loan)
    if farmer_id:
        query = query.where(Loan.farmer_id == uuid.UUID(farmer_id))
    query = query.order_by(Loan.created_at.desc()).limit(20)
    result = await db.execute(query)
    loans = list(result.scalars().all())
    logger.info(f"Listed {len(loans)} loans")
    return {
        "success": True,
        "data": [
            {
                "id": str(l.id),
                "farmer_id": str(l.farmer_id),
                "loan_type": l.loan_type.value if hasattr(l.loan_type, "value") else l.loan_type,
                "principal_amount": l.principal_amount,
                "emi_amount": l.emi_amount,
                "outstanding_amount": l.outstanding_amount,
                "status": l.status.value if hasattr(l.status, "value") else l.status,
            }
            for l in loans
        ],
        "message": f"Found {len(loans)} loans",
    }


# ---------------------------------------------------------------------------
# Insurance Endpoints
# ---------------------------------------------------------------------------

@router.post("/insurance", status_code=201)
async def create_insurance(
    data: InsuranceCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(
        f"POST /payments/insurance called | user_id={current_user.id} | "
        f"cattle_id={data.cattle_id} | insurer={data.insurer_name} | sum=₹{data.sum_insured}"
    )
    insurance = await payment_service.create_insurance(db, data.model_dump())
    logger.info(f"Insurance policy created | id={insurance.id} | policy={insurance.policy_number}")
    return {
        "success": True,
        "data": {
            "id": str(insurance.id),
            "policy_number": insurance.policy_number,
            "insurer_name": insurance.insurer_name,
            "sum_insured": insurance.sum_insured,
            "premium_amount": insurance.premium_amount,
            "farmer_premium": insurance.farmer_premium,
            "start_date": str(insurance.start_date),
            "end_date": str(insurance.end_date),
            "status": insurance.status.value if hasattr(insurance.status, "value") else insurance.status,
        },
        "message": "Cattle insurance policy created",
    }


@router.post("/insurance/{insurance_id}/claim")
async def file_claim(
    insurance_id: str,
    data: InsuranceClaimCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"POST /payments/insurance/{insurance_id}/claim called | amount=₹{data.claim_amount}")
    try:
        insurance = await payment_service.file_insurance_claim(db, uuid.UUID(insurance_id), data.model_dump())
        logger.info(f"Insurance claim filed | id={insurance.id} | claim_amount=₹{insurance.claim_amount}")
        return {
            "success": True,
            "data": {
                "id": str(insurance.id),
                "policy_number": insurance.policy_number,
                "claim_amount": insurance.claim_amount,
                "claim_reason": insurance.claim_reason,
                "status": insurance.status.value if hasattr(insurance.status, "value") else insurance.status,
            },
            "message": "Insurance claim filed",
        }
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/insurance")
async def list_insurance(
    farmer_id: str | None = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /payments/insurance called | farmer_id={farmer_id}")
    query = select(CattleInsurance)
    if farmer_id:
        query = query.where(CattleInsurance.farmer_id == uuid.UUID(farmer_id))
    query = query.order_by(CattleInsurance.created_at.desc()).limit(20)
    result = await db.execute(query)
    policies = list(result.scalars().all())
    logger.info(f"Listed {len(policies)} insurance policies")
    return {
        "success": True,
        "data": [
            {
                "id": str(p.id),
                "policy_number": p.policy_number,
                "cattle_id": str(p.cattle_id),
                "insurer_name": p.insurer_name,
                "sum_insured": p.sum_insured,
                "farmer_premium": p.farmer_premium,
                "start_date": str(p.start_date),
                "end_date": str(p.end_date),
                "status": p.status.value if hasattr(p.status, "value") else p.status,
            }
            for p in policies
        ],
        "message": f"Found {len(policies)} policies",
    }


# ---------------------------------------------------------------------------
# Subsidy Endpoints
# ---------------------------------------------------------------------------

@router.post("/subsidies", status_code=201)
async def apply_subsidy(
    data: SubsidyApplicationCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(
        f"POST /payments/subsidies called | user_id={current_user.id} | "
        f"scheme={data.scheme} | amount=₹{data.applied_amount}"
    )
    subsidy = await payment_service.create_subsidy_application(db, data.model_dump())
    logger.info(f"Subsidy application created | id={subsidy.id}")
    return {
        "success": True,
        "data": {
            "id": str(subsidy.id),
            "scheme": subsidy.scheme.value if hasattr(subsidy.scheme, "value") else subsidy.scheme,
            "scheme_name": subsidy.scheme_name,
            "applied_amount": subsidy.applied_amount,
            "status": subsidy.status.value if hasattr(subsidy.status, "value") else subsidy.status,
        },
        "message": "Subsidy application submitted",
    }


@router.put("/subsidies/{subsidy_id}/status")
async def update_subsidy(
    subsidy_id: str,
    data: SubsidyStatusUpdate,
    current_user: User = Depends(require_role(UserRole.admin, UserRole.super_admin)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"PUT /payments/subsidies/{subsidy_id}/status called | new_status={data.status}")
    try:
        subsidy = await payment_service.update_subsidy_status(db, uuid.UUID(subsidy_id), data.model_dump())
        logger.info(f"Subsidy status updated | id={subsidy.id} | status={subsidy.status}")
        return {
            "success": True,
            "data": {
                "id": str(subsidy.id),
                "status": subsidy.status.value if hasattr(subsidy.status, "value") else subsidy.status,
                "approved_amount": subsidy.approved_amount,
                "disbursed_amount": subsidy.disbursed_amount,
            },
            "message": "Subsidy status updated",
        }
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/subsidies")
async def list_subsidies(
    farmer_id: str | None = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /payments/subsidies called | farmer_id={farmer_id}")
    query = select(SubsidyApplication)
    if farmer_id:
        query = query.where(SubsidyApplication.farmer_id == uuid.UUID(farmer_id))
    query = query.order_by(SubsidyApplication.created_at.desc()).limit(20)
    result = await db.execute(query)
    subsidies = list(result.scalars().all())
    logger.info(f"Listed {len(subsidies)} subsidy applications")
    return {
        "success": True,
        "data": [
            {
                "id": str(s.id),
                "farmer_id": str(s.farmer_id),
                "scheme": s.scheme.value if hasattr(s.scheme, "value") else s.scheme,
                "scheme_name": s.scheme_name,
                "applied_amount": s.applied_amount,
                "approved_amount": s.approved_amount,
                "status": s.status.value if hasattr(s.status, "value") else s.status,
            }
            for s in subsidies
        ],
        "message": f"Found {len(subsidies)} applications",
    }
