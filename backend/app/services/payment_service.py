"""
Payment Service — auto-payment cycles, loans, insurance, subsidies, and farmer ledger.

Covers:
  - PaymentCycle creation and processing (auto-deduction of loan EMIs, quality bonuses)
  - Loan application, EMI calculation, and approval workflow
  - Cattle insurance policy creation and claims
  - Subsidy application creation and status tracking
  - Farmer ledger (earnings, loans, subsidies, recent payments)
"""
import logging
import uuid
import math
from datetime import date, datetime
from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.collection import MilkCollection
from app.models.payment import (
    PaymentCycle, PaymentCycleType, PaymentStatus,
    FarmerPayment, Loan, LoanStatus, LoanType,
    SubsidyApplication, SubsidyStatus,
    CattleInsurance, InsuranceStatus,
)

logger = logging.getLogger("dairy_ai.services.payment")


# ---------------------------------------------------------------------------
# Payment Cycle
# ---------------------------------------------------------------------------

async def create_payment_cycle(db: AsyncSession, data: dict) -> PaymentCycle:
    """Create a new payment cycle record (does not process payments yet)."""
    logger.info(
        "create_payment_cycle called | cooperative_id=%s, cycle_type=%s, period=%s to %s",
        data.get("cooperative_id"),
        data.get("cycle_type"),
        data.get("period_start"),
        data.get("period_end"),
    )

    logger.debug("Validating period_start and period_end from data dict")
    period_start = data.get("period_start")
    period_end = data.get("period_end")

    if isinstance(period_start, str):
        logger.debug("Parsing period_start from string: %s", period_start)
        period_start = date.fromisoformat(period_start)

    if isinstance(period_end, str):
        logger.debug("Parsing period_end from string: %s", period_end)
        period_end = date.fromisoformat(period_end)

    if period_start and period_end and period_start > period_end:
        logger.warning(
            "period_start (%s) is after period_end (%s) — invalid cycle range",
            period_start,
            period_end,
        )

    logger.debug("Building PaymentCycle ORM object")
    cycle = PaymentCycle(
        cooperative_id=data.get("cooperative_id"),
        cycle_type=data.get("cycle_type", PaymentCycleType.weekly),
        period_start=period_start,
        period_end=period_end,
        status=PaymentStatus.pending,
    )

    logger.debug("Adding PaymentCycle to session and flushing")
    db.add(cycle)
    await db.flush()

    logger.info(
        "PaymentCycle created | cycle_id=%s, cycle_type=%s, period=%s to %s, status=%s",
        cycle.id,
        cycle.cycle_type,
        cycle.period_start,
        cycle.period_end,
        cycle.status,
    )
    return cycle


async def process_payment_cycle(db: AsyncSession, cycle_id: uuid.UUID) -> PaymentCycle:
    """
    Core auto-payment engine.

    Steps:
      1. Fetch the PaymentCycle by ID.
      2. Fetch all MilkCollection records for the cycle's period.
      3. Group collections by farmer_id.
      4. For each farmer:
           - Calculate total_litres, avg_fat_pct, avg_snf_pct.
           - base_amount = sum of each collection's net_amount.
           - quality_bonus = +0.50/litre if avg_fat >= 4.0.
           - Check active loans → loan_deduction = min(emi_amount, base_amount * 0.25).
           - net_amount = base_amount + quality_bonus - loan_deduction.
           - Create FarmerPayment record.
      5. Update cycle totals and mark as processing.
    """
    logger.info("process_payment_cycle called | cycle_id=%s", cycle_id)

    # --- Step 1: Fetch cycle ---
    logger.debug("Fetching PaymentCycle from DB | cycle_id=%s", cycle_id)
    cycle_result = await db.execute(
        select(PaymentCycle).where(PaymentCycle.id == cycle_id)
    )
    cycle = cycle_result.scalar_one_or_none()

    if cycle is None:
        logger.error("PaymentCycle not found | cycle_id=%s", cycle_id)
        raise ValueError(f"PaymentCycle {cycle_id} not found")

    logger.info(
        "PaymentCycle fetched | cycle_id=%s, status=%s, period=%s to %s",
        cycle.id,
        cycle.status,
        cycle.period_start,
        cycle.period_end,
    )

    if cycle.status not in (PaymentStatus.pending,):
        logger.warning(
            "PaymentCycle is not in pending status — current status=%s | cycle_id=%s",
            cycle.status,
            cycle_id,
        )

    # --- Step 2: Fetch all MilkCollection records for the period ---
    logger.debug(
        "Querying MilkCollection records | period=%s to %s, cycle_id=%s",
        cycle.period_start,
        cycle.period_end,
        cycle_id,
    )
    collections_result = await db.execute(
        select(MilkCollection).where(
            and_(
                MilkCollection.date >= cycle.period_start,
                MilkCollection.date <= cycle.period_end,
                MilkCollection.is_rejected == False,  # noqa: E712
            )
        )
    )
    collections = list(collections_result.scalars().all())
    logger.info(
        "MilkCollection records fetched | count=%d, period=%s to %s",
        len(collections),
        cycle.period_start,
        cycle.period_end,
    )

    if not collections:
        logger.warning(
            "No milk collections found for cycle period %s to %s — cycle will have zero payouts",
            cycle.period_start,
            cycle.period_end,
        )

    # --- Step 3: Group collections by farmer_id ---
    logger.debug("Grouping %d collections by farmer_id", len(collections))
    farmer_collections: dict[uuid.UUID, list[MilkCollection]] = {}
    for col in collections:
        farmer_collections.setdefault(col.farmer_id, []).append(col)

    logger.info(
        "Collections grouped | distinct_farmers=%d",
        len(farmer_collections),
    )

    # --- Step 4: Process each farmer ---
    cycle_total_litres = 0.0
    cycle_base_amount = 0.0
    cycle_total_bonuses = 0.0
    cycle_total_deductions = 0.0
    cycle_net_payout = 0.0
    farmers_processed = 0

    for farmer_id, farmer_cols in farmer_collections.items():
        logger.debug(
            "Processing farmer | farmer_id=%s, collection_count=%d",
            farmer_id,
            len(farmer_cols),
        )

        # Calculate aggregates
        total_litres = sum(c.quantity_litres for c in farmer_cols)
        logger.debug("Farmer total_litres=%.3f | farmer_id=%s", total_litres, farmer_id)

        fat_values = [c.fat_pct for c in farmer_cols if c.fat_pct is not None]
        snf_values = [c.snf_pct for c in farmer_cols if c.snf_pct is not None]

        avg_fat_pct = sum(fat_values) / len(fat_values) if fat_values else None
        avg_snf_pct = sum(snf_values) / len(snf_values) if snf_values else None

        logger.debug(
            "Farmer quality averages | farmer_id=%s, avg_fat=%.3f (from %d readings), avg_snf=%.3f (from %d readings)",
            farmer_id,
            avg_fat_pct if avg_fat_pct is not None else 0.0,
            len(fat_values),
            avg_snf_pct if avg_snf_pct is not None else 0.0,
            len(snf_values),
        )

        # base_amount = sum of net_amount from each collection
        base_amount = sum(
            float(c.net_amount) for c in farmer_cols if c.net_amount is not None
        )
        # Fallback: if net_amount not set, use total_amount
        if base_amount == 0.0:
            base_amount = sum(
                float(c.total_amount) for c in farmer_cols if c.total_amount is not None
            )
            logger.debug(
                "net_amount not set on collections — using total_amount as base | farmer_id=%s, base_amount=%.2f",
                farmer_id,
                base_amount,
            )
        else:
            logger.debug(
                "base_amount from net_amount sum | farmer_id=%s, base_amount=%.2f",
                farmer_id,
                base_amount,
            )

        # quality_bonus: +₹0.50/litre if avg_fat >= 4.0
        quality_bonus = 0.0
        if avg_fat_pct is not None and avg_fat_pct >= 4.0:
            quality_bonus = round(total_litres * 0.50, 2)
            logger.info(
                "Quality bonus applied | farmer_id=%s, avg_fat=%.3f >= 4.0, total_litres=%.3f, quality_bonus=%.2f",
                farmer_id,
                avg_fat_pct,
                total_litres,
                quality_bonus,
            )
        else:
            logger.debug(
                "No quality bonus | farmer_id=%s, avg_fat=%s (threshold: 4.0)",
                farmer_id,
                f"{avg_fat_pct:.3f}" if avg_fat_pct is not None else "N/A",
            )

        # Loan deduction: find active loans for this farmer
        logger.debug(
            "Querying active loans for farmer | farmer_id=%s",
            farmer_id,
        )
        loans_result = await db.execute(
            select(Loan).where(
                and_(
                    Loan.farmer_id == farmer_id,
                    Loan.status.in_([LoanStatus.approved, LoanStatus.disbursed, LoanStatus.active]),
                )
            )
        )
        active_loans = list(loans_result.scalars().all())
        logger.debug(
            "Active loans found | farmer_id=%s, loan_count=%d",
            farmer_id,
            len(active_loans),
        )

        loan_deduction = 0.0
        if active_loans:
            # Sum up all EMIs across active loans
            total_emi = sum(float(loan.emi_amount) for loan in active_loans)
            max_deductible = round(base_amount * 0.25, 2)  # max 25% of earnings
            loan_deduction = round(min(total_emi, max_deductible), 2)
            logger.info(
                "Loan deduction calculated | farmer_id=%s, total_emi=%.2f, max_deductible=%.2f (25%% of %.2f), loan_deduction=%.2f",
                farmer_id,
                total_emi,
                max_deductible,
                base_amount,
                loan_deduction,
            )
            if loan_deduction < total_emi:
                logger.debug(
                    "Loan deduction capped at 25%% of earnings | farmer_id=%s, emi_requested=%.2f, deduction_applied=%.2f",
                    farmer_id,
                    total_emi,
                    loan_deduction,
                )
        else:
            logger.debug("No active loans for farmer | farmer_id=%s", farmer_id)

        # Final net amount
        net_amount = round(base_amount + quality_bonus - loan_deduction, 2)
        logger.info(
            "Farmer payment summary | farmer_id=%s, base=%.2f, bonus=%.2f, deduction=%.2f, net=%.2f",
            farmer_id,
            base_amount,
            quality_bonus,
            loan_deduction,
            net_amount,
        )

        # Create FarmerPayment record
        logger.debug("Creating FarmerPayment record | farmer_id=%s, cycle_id=%s", farmer_id, cycle_id)
        farmer_payment = FarmerPayment(
            cycle_id=cycle_id,
            farmer_id=farmer_id,
            total_litres=round(total_litres, 3),
            avg_fat_pct=round(avg_fat_pct, 3) if avg_fat_pct is not None else None,
            avg_snf_pct=round(avg_snf_pct, 3) if avg_snf_pct is not None else None,
            base_amount=round(base_amount, 2),
            quality_bonus=quality_bonus,
            loan_deduction=loan_deduction,
            net_amount=net_amount,
            status=PaymentStatus.pending,
        )
        db.add(farmer_payment)
        logger.debug(
            "FarmerPayment added to session | farmer_id=%s, net_amount=%.2f",
            farmer_id,
            net_amount,
        )

        # Accumulate cycle totals
        cycle_total_litres += total_litres
        cycle_base_amount += base_amount
        cycle_total_bonuses += quality_bonus
        cycle_total_deductions += loan_deduction
        cycle_net_payout += net_amount
        farmers_processed += 1

    logger.info(
        "All farmers processed | cycle_id=%s, farmers_count=%d, total_litres=%.3f, base_amount=%.2f, bonuses=%.2f, deductions=%.2f, net_payout=%.2f",
        cycle_id,
        farmers_processed,
        cycle_total_litres,
        cycle_base_amount,
        cycle_total_bonuses,
        cycle_total_deductions,
        cycle_net_payout,
    )

    # --- Step 5: Update cycle totals and mark as processing ---
    logger.debug("Updating PaymentCycle totals | cycle_id=%s", cycle_id)
    cycle.total_litres = round(cycle_total_litres, 3)
    cycle.total_amount = round(cycle_base_amount, 2)
    cycle.total_bonuses = round(cycle_total_bonuses, 2)
    cycle.total_deductions = round(cycle_total_deductions, 2)
    cycle.net_payout = round(cycle_net_payout, 2)
    cycle.farmers_count = farmers_processed
    cycle.status = PaymentStatus.processing
    cycle.processed_at = datetime.utcnow()

    logger.debug("Flushing session after cycle update | cycle_id=%s", cycle_id)
    await db.flush()

    logger.info(
        "PaymentCycle updated to processing | cycle_id=%s, farmers=%d, net_payout=%.2f",
        cycle_id,
        farmers_processed,
        cycle.net_payout,
    )
    return cycle


# ---------------------------------------------------------------------------
# Loans
# ---------------------------------------------------------------------------

async def apply_loan(db: AsyncSession, data: dict) -> Loan:
    """
    Create a loan application and pre-calculate the EMI.

    EMI formula (standard reducing balance):
        EMI = P * r * (1+r)^n / ((1+r)^n - 1)
    where:
        P = principal_amount
        r = monthly interest rate = annual_rate / 12 / 100
        n = tenure_months

    If interest_rate is 0: EMI = principal / tenure (simple equal instalments).
    """
    farmer_id = data.get("farmer_id")
    principal = float(data.get("principal_amount", 0))
    interest_rate_pct = float(data.get("interest_rate_pct", 0.0))
    tenure_months = int(data.get("tenure_months", 1))
    loan_type = data.get("loan_type", LoanType.emergency)
    purpose = data.get("purpose")

    logger.info(
        "apply_loan called | farmer_id=%s, principal=%.2f, interest_rate=%.2f%%, tenure=%d months, type=%s",
        farmer_id,
        principal,
        interest_rate_pct,
        tenure_months,
        loan_type,
    )

    # EMI calculation
    logger.debug(
        "Calculating EMI | P=%.2f, annual_rate=%.2f%%, tenure=%d months",
        principal,
        interest_rate_pct,
        tenure_months,
    )

    if interest_rate_pct == 0.0:
        emi_amount = round(principal / tenure_months, 2)
        logger.info(
            "Zero-interest loan — simple EMI calculation | EMI=%.2f (principal=%.2f / tenure=%d)",
            emi_amount,
            principal,
            tenure_months,
        )
    else:
        monthly_rate = interest_rate_pct / 12.0 / 100.0
        logger.debug("Monthly interest rate r=%.6f", monthly_rate)

        power_factor = math.pow(1 + monthly_rate, tenure_months)
        logger.debug(
            "EMI compound factor (1+r)^n = %.6f | r=%.6f, n=%d",
            power_factor,
            monthly_rate,
            tenure_months,
        )

        denominator = power_factor - 1
        if denominator == 0:
            logger.error(
                "EMI denominator is zero — cannot compute EMI | r=%.6f, n=%d",
                monthly_rate,
                tenure_months,
            )
            raise ValueError("EMI calculation resulted in zero denominator")

        emi_amount = round(principal * monthly_rate * power_factor / denominator, 2)
        logger.info(
            "EMI calculated using reducing balance formula | P=%.2f, r=%.6f, n=%d, (1+r)^n=%.6f, EMI=%.2f",
            principal,
            monthly_rate,
            tenure_months,
            power_factor,
            emi_amount,
        )

    logger.debug("Building Loan ORM object | farmer_id=%s", farmer_id)
    farmer_id_val = uuid.UUID(farmer_id) if isinstance(farmer_id, str) else farmer_id
    loan = Loan(
        farmer_id=farmer_id_val,
        loan_type=loan_type,
        principal_amount=principal,
        interest_rate_pct=interest_rate_pct,
        tenure_months=tenure_months,
        emi_amount=emi_amount,
        outstanding_amount=principal,
        total_paid=0.0,
        status=LoanStatus.applied,
        purpose=purpose,
    )

    logger.debug("Adding Loan to session | farmer_id=%s", farmer_id)
    db.add(loan)
    await db.flush()

    logger.info(
        "Loan application created | loan_id=%s, farmer_id=%s, principal=%.2f, emi=%.2f, tenure=%d, status=%s",
        loan.id,
        farmer_id,
        principal,
        emi_amount,
        tenure_months,
        loan.status,
    )
    return loan


async def approve_loan(db: AsyncSession, loan_id: uuid.UUID, data: dict) -> Loan:
    """
    Approve a loan application.

    Sets:
      - status → approved
      - emi_amount (may be overridden by approver)
      - outstanding_amount = principal_amount (reset to full principal at approval)
      - approved_by
    """
    logger.info("approve_loan called | loan_id=%s", loan_id)

    logger.debug("Fetching Loan from DB | loan_id=%s", loan_id)
    loan_result = await db.execute(
        select(Loan).where(Loan.id == loan_id)
    )
    loan = loan_result.scalar_one_or_none()

    if loan is None:
        logger.error("Loan not found | loan_id=%s", loan_id)
        raise ValueError(f"Loan {loan_id} not found")

    logger.info(
        "Loan fetched | loan_id=%s, farmer_id=%s, current_status=%s, principal=%.2f",
        loan.id,
        loan.farmer_id,
        loan.status,
        loan.principal_amount,
    )

    if loan.status != LoanStatus.applied:
        logger.warning(
            "Loan is not in applied status — current status=%s | loan_id=%s",
            loan.status,
            loan_id,
        )

    # Update status
    previous_status = loan.status
    loan.status = LoanStatus.approved
    logger.debug(
        "Loan status changed | loan_id=%s, %s → %s",
        loan_id,
        previous_status,
        loan.status,
    )

    # Override EMI if provided by approver
    if "emi_amount" in data:
        old_emi = loan.emi_amount
        loan.emi_amount = round(float(data["emi_amount"]), 2)
        logger.info(
            "EMI amount overridden by approver | loan_id=%s, old_emi=%.2f, new_emi=%.2f",
            loan_id,
            old_emi,
            loan.emi_amount,
        )
    else:
        logger.debug(
            "EMI amount unchanged (no override) | loan_id=%s, emi=%.2f",
            loan_id,
            loan.emi_amount,
        )

    # Set outstanding_amount = principal
    loan.outstanding_amount = loan.principal_amount
    logger.debug(
        "outstanding_amount reset to principal | loan_id=%s, outstanding=%.2f",
        loan_id,
        loan.outstanding_amount,
    )

    # Record approver
    approved_by = data.get("approved_by")
    if approved_by:
        loan.approved_by = approved_by
        logger.debug("Loan approved_by set | loan_id=%s, approved_by=%s", loan_id, approved_by)

    logger.debug("Flushing loan approval changes | loan_id=%s", loan_id)
    await db.flush()

    logger.info(
        "Loan approved | loan_id=%s, farmer_id=%s, principal=%.2f, emi=%.2f, outstanding=%.2f, approved_by=%s",
        loan.id,
        loan.farmer_id,
        loan.principal_amount,
        loan.emi_amount,
        loan.outstanding_amount,
        loan.approved_by,
    )
    return loan


# ---------------------------------------------------------------------------
# Cattle Insurance
# ---------------------------------------------------------------------------

async def create_insurance(db: AsyncSession, data: dict) -> CattleInsurance:
    """Create a new cattle insurance policy for a farmer's animal."""
    farmer_id = data.get("farmer_id")
    cattle_id = data.get("cattle_id")
    policy_number = data.get("policy_number")
    insurer_name = data.get("insurer_name")
    sum_insured = float(data.get("sum_insured", 0))
    premium_amount = float(data.get("premium_amount", 0))
    govt_subsidy_pct = float(data.get("govt_subsidy_pct", 0.0))

    logger.info(
        "create_insurance called | farmer_id=%s, cattle_id=%s, policy_number=%s, insurer=%s, sum_insured=%.2f",
        farmer_id,
        cattle_id,
        policy_number,
        insurer_name,
        sum_insured,
    )

    # Calculate farmer's share of premium after government subsidy
    logger.debug(
        "Calculating farmer premium | total_premium=%.2f, govt_subsidy_pct=%.2f%%",
        premium_amount,
        govt_subsidy_pct,
    )
    if govt_subsidy_pct > 0:
        govt_contribution = round(premium_amount * govt_subsidy_pct / 100.0, 2)
        farmer_premium = round(premium_amount - govt_contribution, 2)
        logger.info(
            "Government subsidy applied to insurance | policy=%s, total_premium=%.2f, govt_contribution=%.2f (%.1f%%), farmer_premium=%.2f",
            policy_number,
            premium_amount,
            govt_contribution,
            govt_subsidy_pct,
            farmer_premium,
        )
    else:
        farmer_premium = premium_amount
        logger.debug(
            "No government subsidy on insurance | policy=%s, farmer_premium=%.2f",
            policy_number,
            farmer_premium,
        )

    # Parse dates
    start_date = data.get("start_date")
    end_date = data.get("end_date")
    if isinstance(start_date, str):
        logger.debug("Parsing start_date from string: %s", start_date)
        start_date = date.fromisoformat(start_date)
    if isinstance(end_date, str):
        logger.debug("Parsing end_date from string: %s", end_date)
        end_date = date.fromisoformat(end_date)

    logger.debug(
        "Insurance policy period: %s to %s | policy=%s",
        start_date,
        end_date,
        policy_number,
    )

    logger.debug("Building CattleInsurance ORM object | policy=%s", policy_number)
    farmer_id_val = uuid.UUID(farmer_id) if isinstance(farmer_id, str) else farmer_id
    cattle_id_val = uuid.UUID(cattle_id) if isinstance(cattle_id, str) else cattle_id
    insurance = CattleInsurance(
        farmer_id=farmer_id_val,
        cattle_id=cattle_id_val,
        policy_number=policy_number,
        insurer_name=insurer_name,
        sum_insured=sum_insured,
        premium_amount=premium_amount,
        govt_subsidy_pct=govt_subsidy_pct,
        farmer_premium=farmer_premium,
        start_date=start_date,
        end_date=end_date,
        status=InsuranceStatus.active,
        ear_tag_photo_url=data.get("ear_tag_photo_url"),
        cattle_photo_url=data.get("cattle_photo_url"),
    )

    logger.debug("Adding CattleInsurance to session | policy=%s", policy_number)
    db.add(insurance)
    await db.flush()

    logger.info(
        "CattleInsurance created | insurance_id=%s, farmer_id=%s, cattle_id=%s, policy=%s, sum_insured=%.2f, farmer_premium=%.2f, status=%s",
        insurance.id,
        farmer_id,
        cattle_id,
        policy_number,
        sum_insured,
        farmer_premium,
        insurance.status,
    )
    return insurance


async def file_insurance_claim(
    db: AsyncSession, insurance_id: uuid.UUID, data: dict
) -> CattleInsurance:
    """
    File a claim on an existing cattle insurance policy.

    Sets claim_amount, claim_reason, claim_date and updates status to claim_processing.
    """
    logger.info("file_insurance_claim called | insurance_id=%s", insurance_id)

    logger.debug("Fetching CattleInsurance from DB | insurance_id=%s", insurance_id)
    insurance_result = await db.execute(
        select(CattleInsurance).where(CattleInsurance.id == insurance_id)
    )
    insurance = insurance_result.scalar_one_or_none()

    if insurance is None:
        logger.error("CattleInsurance not found | insurance_id=%s", insurance_id)
        raise ValueError(f"CattleInsurance {insurance_id} not found")

    logger.info(
        "CattleInsurance fetched | insurance_id=%s, farmer_id=%s, cattle_id=%s, policy=%s, current_status=%s",
        insurance.id,
        insurance.farmer_id,
        insurance.cattle_id,
        insurance.policy_number,
        insurance.status,
    )

    if insurance.status != InsuranceStatus.active:
        logger.warning(
            "Insurance policy is not active — current status=%s | insurance_id=%s, policy=%s",
            insurance.status,
            insurance_id,
            insurance.policy_number,
        )

    claim_amount = float(data.get("claim_amount", 0))
    claim_reason = data.get("claim_reason")
    claim_date_raw = data.get("claim_date", date.today())

    if isinstance(claim_date_raw, str):
        logger.debug("Parsing claim_date from string: %s", claim_date_raw)
        claim_date_raw = date.fromisoformat(claim_date_raw)

    # Validate claim amount does not exceed sum insured
    if claim_amount > insurance.sum_insured:
        logger.warning(
            "Claim amount (%.2f) exceeds sum_insured (%.2f) — capping to sum_insured | insurance_id=%s",
            claim_amount,
            insurance.sum_insured,
            insurance_id,
        )
        claim_amount = insurance.sum_insured
    else:
        logger.debug(
            "Claim amount %.2f is within sum_insured %.2f | insurance_id=%s",
            claim_amount,
            insurance.sum_insured,
            insurance_id,
        )

    previous_status = insurance.status
    insurance.claim_amount = claim_amount
    insurance.claim_reason = claim_reason
    insurance.claim_date = claim_date_raw
    insurance.status = InsuranceStatus.claim_processing
    logger.info(
        "Insurance claim filed | insurance_id=%s, policy=%s, claim_amount=%.2f, claim_date=%s, status: %s → %s",
        insurance.id,
        insurance.policy_number,
        claim_amount,
        claim_date_raw,
        previous_status,
        insurance.status,
    )

    logger.debug("Flushing insurance claim update | insurance_id=%s", insurance_id)
    await db.flush()

    logger.info(
        "Insurance claim processed | insurance_id=%s, farmer_id=%s, policy=%s, claim_amount=%.2f, new_status=%s",
        insurance.id,
        insurance.farmer_id,
        insurance.policy_number,
        claim_amount,
        insurance.status,
    )
    return insurance


# ---------------------------------------------------------------------------
# Subsidy Applications
# ---------------------------------------------------------------------------

async def create_subsidy_application(db: AsyncSession, data: dict) -> SubsidyApplication:
    """Create a new subsidy application for a farmer."""
    farmer_id = data.get("farmer_id")
    farmer_id_val = uuid.UUID(farmer_id) if isinstance(farmer_id, str) else farmer_id
    scheme = data.get("scheme")
    scheme_name = data.get("scheme_name")
    applied_amount = float(data.get("applied_amount", 0))

    logger.info(
        "create_subsidy_application called | farmer_id=%s, scheme=%s, scheme_name=%s, applied_amount=%.2f",
        farmer_id,
        scheme,
        scheme_name,
        applied_amount,
    )

    # Parse applied_at date
    applied_at = data.get("applied_at")
    if isinstance(applied_at, str):
        logger.debug("Parsing applied_at from string: %s", applied_at)
        applied_at = date.fromisoformat(applied_at)
    if applied_at is None:
        applied_at = date.today()
        logger.debug("applied_at defaulted to today: %s", applied_at)

    logger.debug(
        "Building SubsidyApplication ORM object | farmer_id=%s, scheme=%s",
        farmer_id,
        scheme,
    )
    subsidy = SubsidyApplication(
        farmer_id=farmer_id_val,
        scheme=scheme,
        scheme_name=scheme_name,
        applied_amount=applied_amount,
        application_ref=data.get("application_ref"),
        documents=data.get("documents", []),
        status=SubsidyStatus.applied,
        applied_at=applied_at,
        notes=data.get("notes"),
    )

    logger.debug("Adding SubsidyApplication to session | farmer_id=%s", farmer_id)
    db.add(subsidy)
    await db.flush()

    logger.info(
        "SubsidyApplication created | subsidy_id=%s, farmer_id=%s, scheme=%s, applied_amount=%.2f, status=%s",
        subsidy.id,
        farmer_id,
        scheme,
        applied_amount,
        subsidy.status,
    )
    return subsidy


async def update_subsidy_status(
    db: AsyncSession, subsidy_id: uuid.UUID, data: dict
) -> SubsidyApplication:
    """Update the status and financial details of a subsidy application."""
    logger.info("update_subsidy_status called | subsidy_id=%s", subsidy_id)

    logger.debug("Fetching SubsidyApplication from DB | subsidy_id=%s", subsidy_id)
    subsidy_result = await db.execute(
        select(SubsidyApplication).where(SubsidyApplication.id == subsidy_id)
    )
    subsidy = subsidy_result.scalar_one_or_none()

    if subsidy is None:
        logger.error("SubsidyApplication not found | subsidy_id=%s", subsidy_id)
        raise ValueError(f"SubsidyApplication {subsidy_id} not found")

    logger.info(
        "SubsidyApplication fetched | subsidy_id=%s, farmer_id=%s, scheme=%s, current_status=%s",
        subsidy.id,
        subsidy.farmer_id,
        subsidy.scheme,
        subsidy.status,
    )

    previous_status = subsidy.status
    new_status = data.get("status")
    if new_status:
        subsidy.status = new_status
        logger.info(
            "SubsidyApplication status changed | subsidy_id=%s, %s → %s",
            subsidy_id,
            previous_status,
            new_status,
        )

        # Handle status-specific field updates
        if new_status == SubsidyStatus.approved:
            approved_amount = data.get("approved_amount")
            if approved_amount is not None:
                subsidy.approved_amount = float(approved_amount)
                logger.info(
                    "Subsidy approved_amount set | subsidy_id=%s, approved_amount=%.2f",
                    subsidy_id,
                    subsidy.approved_amount,
                )
            subsidy.approved_at = data.get("approved_at") or date.today()
            logger.debug(
                "Subsidy approved_at set | subsidy_id=%s, approved_at=%s",
                subsidy_id,
                subsidy.approved_at,
            )

        elif new_status == SubsidyStatus.disbursed:
            disbursed_amount = data.get("disbursed_amount")
            if disbursed_amount is not None:
                subsidy.disbursed_amount = float(disbursed_amount)
                logger.info(
                    "Subsidy disbursed_amount set | subsidy_id=%s, disbursed_amount=%.2f",
                    subsidy_id,
                    subsidy.disbursed_amount,
                )
            subsidy.disbursed_at = data.get("disbursed_at") or date.today()
            logger.debug(
                "Subsidy disbursed_at set | subsidy_id=%s, disbursed_at=%s",
                subsidy_id,
                subsidy.disbursed_at,
            )

        elif new_status == SubsidyStatus.rejected:
            rejection_reason = data.get("rejection_reason")
            if rejection_reason:
                subsidy.rejection_reason = rejection_reason
                logger.info(
                    "Subsidy rejection_reason set | subsidy_id=%s, reason=%s",
                    subsidy_id,
                    rejection_reason,
                )
            else:
                logger.warning(
                    "Subsidy rejected without a rejection_reason | subsidy_id=%s",
                    subsidy_id,
                )

        else:
            logger.debug(
                "No status-specific field updates required for status=%s | subsidy_id=%s",
                new_status,
                subsidy_id,
            )
    else:
        logger.debug("No new status provided — no status change | subsidy_id=%s", subsidy_id)

    # Update notes if provided
    if "notes" in data:
        subsidy.notes = data["notes"]
        logger.debug("Subsidy notes updated | subsidy_id=%s", subsidy_id)

    logger.debug("Flushing subsidy status update | subsidy_id=%s", subsidy_id)
    await db.flush()

    logger.info(
        "SubsidyApplication updated | subsidy_id=%s, farmer_id=%s, scheme=%s, new_status=%s",
        subsidy.id,
        subsidy.farmer_id,
        subsidy.scheme,
        subsidy.status,
    )
    return subsidy


# ---------------------------------------------------------------------------
# Farmer Ledger
# ---------------------------------------------------------------------------

async def get_farmer_ledger(db: AsyncSession, farmer_id: uuid.UUID) -> dict:
    """
    Retrieve a consolidated financial ledger for a farmer.

    Returns:
      - total_earnings: lifetime sum of all net payments received
      - total_loans_outstanding: sum of outstanding_amount across active loans
      - total_subsidies_received: sum of disbursed subsidy amounts
      - recent_payments: last 10 FarmerPayment records
      - active_loans: all non-closed/non-rejected loans
      - insurance_policies: all CattleInsurance records for this farmer
    """
    logger.info("get_farmer_ledger called | farmer_id=%s", farmer_id)

    # --- Total earnings (completed payments) ---
    logger.debug("Querying total_earnings for farmer | farmer_id=%s", farmer_id)
    earnings_result = await db.execute(
        select(func.sum(FarmerPayment.net_amount)).where(
            and_(
                FarmerPayment.farmer_id == farmer_id,
                FarmerPayment.status == PaymentStatus.completed,
            )
        )
    )
    total_earnings = round(float(earnings_result.scalar() or 0.0), 2)
    logger.info("Total earnings fetched | farmer_id=%s, total_earnings=%.2f", farmer_id, total_earnings)

    # --- Total loans outstanding ---
    logger.debug("Querying total_loans_outstanding for farmer | farmer_id=%s", farmer_id)
    loans_outstanding_result = await db.execute(
        select(func.sum(Loan.outstanding_amount)).where(
            and_(
                Loan.farmer_id == farmer_id,
                Loan.status.in_([
                    LoanStatus.approved,
                    LoanStatus.disbursed,
                    LoanStatus.active,
                ]),
            )
        )
    )
    total_loans_outstanding = round(float(loans_outstanding_result.scalar() or 0.0), 2)
    logger.info(
        "Total loans outstanding fetched | farmer_id=%s, outstanding=%.2f",
        farmer_id,
        total_loans_outstanding,
    )

    # --- Total subsidies received (disbursed only) ---
    logger.debug("Querying total_subsidies_received for farmer | farmer_id=%s", farmer_id)
    subsidies_result = await db.execute(
        select(func.sum(SubsidyApplication.disbursed_amount)).where(
            and_(
                SubsidyApplication.farmer_id == farmer_id,
                SubsidyApplication.status == SubsidyStatus.disbursed,
            )
        )
    )
    total_subsidies_received = round(float(subsidies_result.scalar() or 0.0), 2)
    logger.info(
        "Total subsidies received fetched | farmer_id=%s, subsidies=%.2f",
        farmer_id,
        total_subsidies_received,
    )

    # --- Recent payments (last 10 completed or pending) ---
    logger.debug("Querying recent_payments (last 10) for farmer | farmer_id=%s", farmer_id)
    recent_payments_result = await db.execute(
        select(FarmerPayment)
        .where(FarmerPayment.farmer_id == farmer_id)
        .order_by(FarmerPayment.created_at.desc())
        .limit(10)
    )
    recent_payments = list(recent_payments_result.scalars().all())
    logger.info(
        "Recent payments fetched | farmer_id=%s, count=%d",
        farmer_id,
        len(recent_payments),
    )
    logger.debug(
        "Recent payment IDs | farmer_id=%s, ids=%s",
        farmer_id,
        [str(p.id) for p in recent_payments],
    )

    # --- Active loans ---
    logger.debug("Querying active_loans for farmer | farmer_id=%s", farmer_id)
    active_loans_result = await db.execute(
        select(Loan).where(
            and_(
                Loan.farmer_id == farmer_id,
                Loan.status.not_in([LoanStatus.closed, LoanStatus.rejected]),
            )
        ).order_by(Loan.created_at.desc())
    )
    active_loans = list(active_loans_result.scalars().all())
    logger.info(
        "Active loans fetched | farmer_id=%s, count=%d",
        farmer_id,
        len(active_loans),
    )
    for loan in active_loans:
        logger.debug(
            "Active loan detail | loan_id=%s, type=%s, principal=%.2f, outstanding=%.2f, emi=%.2f, status=%s",
            loan.id,
            loan.loan_type,
            loan.principal_amount,
            loan.outstanding_amount,
            loan.emi_amount,
            loan.status,
        )

    # --- Insurance policies ---
    logger.debug("Querying insurance_policies for farmer | farmer_id=%s", farmer_id)
    insurance_result = await db.execute(
        select(CattleInsurance)
        .where(CattleInsurance.farmer_id == farmer_id)
        .order_by(CattleInsurance.created_at.desc())
    )
    insurance_policies = list(insurance_result.scalars().all())
    logger.info(
        "Insurance policies fetched | farmer_id=%s, count=%d",
        farmer_id,
        len(insurance_policies),
    )
    for policy in insurance_policies:
        logger.debug(
            "Insurance policy detail | insurance_id=%s, policy=%s, cattle_id=%s, sum_insured=%.2f, status=%s",
            policy.id,
            policy.policy_number,
            policy.cattle_id,
            policy.sum_insured,
            policy.status,
        )

    def _serialize_payment(p: FarmerPayment) -> dict:
        return {
            "id": str(p.id),
            "cycle_id": str(p.cycle_id) if p.cycle_id else None,
            "farmer_id": str(p.farmer_id),
            "total_litres": p.total_litres,
            "avg_fat_pct": p.avg_fat_pct,
            "avg_snf_pct": p.avg_snf_pct,
            "base_amount": p.base_amount,
            "quality_bonus": p.quality_bonus,
            "loan_deduction": p.loan_deduction,
            "net_amount": p.net_amount,
            "status": p.status.value if p.status else None,
        }

    def _serialize_loan(l: Loan) -> dict:
        return {
            "id": str(l.id),
            "farmer_id": str(l.farmer_id),
            "loan_type": l.loan_type.value if l.loan_type else None,
            "principal_amount": l.principal_amount,
            "outstanding_amount": l.outstanding_amount,
            "emi_amount": l.emi_amount,
            "interest_rate_pct": l.interest_rate_pct,
            "tenure_months": l.tenure_months,
            "status": l.status.value if l.status else None,
        }

    def _serialize_insurance(ins: CattleInsurance) -> dict:
        return {
            "id": str(ins.id),
            "farmer_id": str(ins.farmer_id),
            "cattle_id": str(ins.cattle_id) if ins.cattle_id else None,
            "policy_number": ins.policy_number,
            "insurer_name": ins.insurer_name,
            "sum_insured": ins.sum_insured,
            "premium_amount": ins.premium_amount,
            "farmer_premium": ins.farmer_premium,
            "status": ins.status.value if ins.status else None,
        }

    ledger = {
        "farmer_id": str(farmer_id),
        "total_earnings": total_earnings,
        "total_loans_outstanding": total_loans_outstanding,
        "total_subsidies_received": total_subsidies_received,
        "recent_payments": [_serialize_payment(p) for p in recent_payments],
        "loans": [_serialize_loan(l) for l in active_loans],
        "insurance_policies": [_serialize_insurance(ins) for ins in insurance_policies],
    }

    logger.info(
        "Farmer ledger compiled | farmer_id=%s, earnings=%.2f, loans_outstanding=%.2f, subsidies=%.2f, recent_payments=%d, active_loans=%d, policies=%d",
        farmer_id,
        total_earnings,
        total_loans_outstanding,
        total_subsidies_received,
        len(recent_payments),
        len(active_loans),
        len(insurance_policies),
    )
    return ledger
