"""Tests for payment cycles, loans, insurance, subsidies, and farmer ledger."""
import uuid
from datetime import date, timedelta

import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User, UserRole
from app.models.farmer import Farmer
from app.models.cattle import Cattle, Breed, Sex, CattleStatus
from app.models.collection import CollectionCenter, MilkCollection, MilkGrade
from app.models.payment import PaymentCycle, PaymentCycleType, PaymentStatus, Loan, LoanStatus
from app.services.auth_service import create_access_token


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest_asyncio.fixture
async def admin_for_payments(db_session: AsyncSession) -> User:
    user = User(id=uuid.uuid4(), phone="9999980001", role=UserRole.admin, is_active=True)
    db_session.add(user)
    await db_session.flush()
    return user


@pytest_asyncio.fixture
async def admin_pay_headers(admin_for_payments: User) -> dict:
    token = create_access_token(str(admin_for_payments.id), admin_for_payments.role.value)
    return {"Authorization": f"Bearer {token}"}


@pytest_asyncio.fixture
async def farmer_for_payments(db_session: AsyncSession) -> tuple[User, Farmer]:
    user = User(id=uuid.uuid4(), phone="9999980010", role=UserRole.farmer, is_active=True)
    db_session.add(user)
    await db_session.flush()
    farmer = Farmer(id=uuid.uuid4(), user_id=user.id, name="Payment Farmer", district="Jaipur")
    db_session.add(farmer)
    await db_session.flush()
    return user, farmer


@pytest_asyncio.fixture
async def farmer_pay_headers(farmer_for_payments: tuple) -> dict:
    user, _ = farmer_for_payments
    token = create_access_token(str(user.id), user.role.value)
    return {"Authorization": f"Bearer {token}"}


@pytest_asyncio.fixture
async def cattle_for_insurance(db_session: AsyncSession, farmer_for_payments: tuple) -> Cattle:
    _, farmer = farmer_for_payments
    cattle = Cattle(
        id=uuid.uuid4(), farmer_id=farmer.id, tag_id="INS-001",
        name="Lakshmi", breed=Breed.gir, sex=Sex.female, status=CattleStatus.active,
    )
    db_session.add(cattle)
    await db_session.flush()
    return cattle


@pytest_asyncio.fixture
async def milk_collections_for_payment(
    db_session: AsyncSession, farmer_for_payments: tuple,
) -> list:
    _, farmer = farmer_for_payments
    center = CollectionCenter(
        id=uuid.uuid4(), name="Pay Test BMC", code="PAY-BMC-001",
        district="Jaipur", capacity_litres=500.0,
    )
    db_session.add(center)
    await db_session.flush()

    today = date.today()
    collections = []
    for i in range(5):
        mc = MilkCollection(
            id=uuid.uuid4(),
            center_id=center.id,
            farmer_id=farmer.id,
            date=today - timedelta(days=i),
            shift="morning",
            quantity_litres=10.0,
            fat_pct=4.2,
            snf_pct=8.6,
            milk_grade=MilkGrade.A,
            rate_per_litre=36.0,
            total_amount=360.0,
            quality_bonus=20.0,
            net_amount=380.0,
            is_rejected=False,
        )
        db_session.add(mc)
        collections.append(mc)

    await db_session.flush()
    return collections


# ---------------------------------------------------------------------------
# Tests: Payment Cycle
# ---------------------------------------------------------------------------

class TestPaymentCycle:
    @pytest.mark.asyncio
    async def test_create_payment_cycle(self, client: AsyncClient, admin_pay_headers: dict):
        today = date.today()
        resp = await client.post(
            "/api/v1/payments/cycles",
            json={
                "cycle_type": "weekly",
                "period_start": str(today - timedelta(days=7)),
                "period_end": str(today),
            },
            headers=admin_pay_headers,
        )
        assert resp.status_code == 201
        data = resp.json()["data"]
        assert data["cycle_type"] == "weekly"
        assert data["status"] == "pending"

    @pytest.mark.asyncio
    async def test_process_payment_cycle(
        self, client: AsyncClient, admin_pay_headers: dict,
        milk_collections_for_payment, farmer_for_payments,
    ):
        today = date.today()
        # Create cycle
        resp = await client.post(
            "/api/v1/payments/cycles",
            json={
                "cycle_type": "weekly",
                "period_start": str(today - timedelta(days=7)),
                "period_end": str(today),
            },
            headers=admin_pay_headers,
        )
        cycle_id = resp.json()["data"]["id"]

        # Process it
        resp = await client.post(
            f"/api/v1/payments/cycles/{cycle_id}/process",
            headers=admin_pay_headers,
        )
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["status"] == "processing"
        assert data["farmers_count"] >= 1
        assert data["net_payout"] > 0
        assert data["total_litres"] > 0


# ---------------------------------------------------------------------------
# Tests: Loans
# ---------------------------------------------------------------------------

class TestLoans:
    @pytest.mark.asyncio
    async def test_apply_loan(
        self, client: AsyncClient, farmer_pay_headers: dict, farmer_for_payments: tuple,
    ):
        _, farmer = farmer_for_payments
        resp = await client.post(
            "/api/v1/payments/loans/apply",
            json={
                "farmer_id": str(farmer.id),
                "loan_type": "cattle_purchase",
                "principal_amount": 50000.0,
                "tenure_months": 12,
                "purpose": "Buy new cow",
            },
            headers=farmer_pay_headers,
        )
        assert resp.status_code == 201
        data = resp.json()["data"]
        assert data["loan_type"] == "cattle_purchase"
        assert data["principal_amount"] == 50000.0
        assert data["status"] == "applied"

    @pytest.mark.asyncio
    async def test_approve_loan(
        self, client: AsyncClient, admin_pay_headers: dict,
        farmer_pay_headers: dict, farmer_for_payments: tuple,
    ):
        _, farmer = farmer_for_payments
        # Apply
        resp = await client.post(
            "/api/v1/payments/loans/apply",
            json={
                "farmer_id": str(farmer.id),
                "loan_type": "feed_advance",
                "principal_amount": 10000.0,
                "tenure_months": 6,
            },
            headers=farmer_pay_headers,
        )
        loan_id = resp.json()["data"]["id"]

        # Approve
        resp = await client.put(
            f"/api/v1/payments/loans/{loan_id}/approve",
            json={
                "interest_rate_pct": 8.0,
                "emi_amount": 1740.0,
                "approved_by": "Admin User",
            },
            headers=admin_pay_headers,
        )
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["status"] == "approved"
        assert data["emi_amount"] == 1740.0


# ---------------------------------------------------------------------------
# Tests: Insurance
# ---------------------------------------------------------------------------

class TestInsurance:
    @pytest.mark.asyncio
    async def test_create_insurance(
        self, client: AsyncClient, farmer_pay_headers: dict,
        farmer_for_payments: tuple, cattle_for_insurance,
    ):
        _, farmer = farmer_for_payments
        resp = await client.post(
            "/api/v1/payments/insurance",
            json={
                "farmer_id": str(farmer.id),
                "cattle_id": str(cattle_for_insurance.id),
                "policy_number": "POL-2026-001",
                "insurer_name": "National Insurance",
                "sum_insured": 80000.0,
                "premium_amount": 2400.0,
                "govt_subsidy_pct": 50.0,
                "farmer_premium": 1200.0,
                "start_date": str(date.today()),
                "end_date": str(date.today() + timedelta(days=365)),
            },
            headers=farmer_pay_headers,
        )
        assert resp.status_code == 201
        data = resp.json()["data"]
        assert data["policy_number"] == "POL-2026-001"
        assert data["sum_insured"] == 80000.0
        assert data["farmer_premium"] == 1200.0
        assert data["status"] == "active"

    @pytest.mark.asyncio
    async def test_file_insurance_claim(
        self, client: AsyncClient, farmer_pay_headers: dict,
        farmer_for_payments: tuple, cattle_for_insurance,
    ):
        _, farmer = farmer_for_payments
        # Create policy
        resp = await client.post(
            "/api/v1/payments/insurance",
            json={
                "farmer_id": str(farmer.id),
                "cattle_id": str(cattle_for_insurance.id),
                "policy_number": "POL-CLM-001",
                "insurer_name": "United India",
                "sum_insured": 60000.0,
                "premium_amount": 1800.0,
                "govt_subsidy_pct": 0,
                "farmer_premium": 1800.0,
                "start_date": str(date.today()),
                "end_date": str(date.today() + timedelta(days=365)),
            },
            headers=farmer_pay_headers,
        )
        ins_id = resp.json()["data"]["id"]

        # File claim
        resp = await client.post(
            f"/api/v1/payments/insurance/{ins_id}/claim",
            json={
                "claim_amount": 60000.0,
                "claim_reason": "Cattle died due to disease",
            },
            headers=farmer_pay_headers,
        )
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["claim_amount"] == 60000.0
        assert data["status"] == "claim_processing"


# ---------------------------------------------------------------------------
# Tests: Subsidies
# ---------------------------------------------------------------------------

class TestSubsidies:
    @pytest.mark.asyncio
    async def test_apply_subsidy(
        self, client: AsyncClient, farmer_pay_headers: dict, farmer_for_payments: tuple,
    ):
        _, farmer = farmer_for_payments
        resp = await client.post(
            "/api/v1/payments/subsidies",
            json={
                "farmer_id": str(farmer.id),
                "scheme": "nabard_dairy",
                "scheme_name": "NABARD Dairy Entrepreneurship Scheme",
                "applied_amount": 100000.0,
            },
            headers=farmer_pay_headers,
        )
        assert resp.status_code == 201
        data = resp.json()["data"]
        assert data["scheme"] == "nabard_dairy"
        assert data["status"] == "applied"

    @pytest.mark.asyncio
    async def test_update_subsidy_status(
        self, client: AsyncClient, admin_pay_headers: dict,
        farmer_pay_headers: dict, farmer_for_payments: tuple,
    ):
        _, farmer = farmer_for_payments
        # Apply
        resp = await client.post(
            "/api/v1/payments/subsidies",
            json={
                "farmer_id": str(farmer.id),
                "scheme": "state_scheme",
                "scheme_name": "Rajasthan Dairy Scheme",
                "applied_amount": 50000.0,
            },
            headers=farmer_pay_headers,
        )
        sub_id = resp.json()["data"]["id"]

        # Admin approves
        resp = await client.put(
            f"/api/v1/payments/subsidies/{sub_id}/status",
            json={
                "status": "approved",
                "approved_amount": 40000.0,
            },
            headers=admin_pay_headers,
        )
        assert resp.status_code == 200
        assert resp.json()["data"]["status"] == "approved"
        assert resp.json()["data"]["approved_amount"] == 40000.0


# ---------------------------------------------------------------------------
# Tests: Farmer Ledger
# ---------------------------------------------------------------------------

class TestFarmerLedger:
    @pytest.mark.asyncio
    async def test_farmer_ledger(
        self, client: AsyncClient, farmer_pay_headers: dict, farmer_for_payments: tuple,
    ):
        _, farmer = farmer_for_payments
        resp = await client.get(
            f"/api/v1/payments/ledger/{farmer.id}",
            headers=farmer_pay_headers,
        )
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert "total_earnings" in data
        assert "total_loans_outstanding" in data
        assert "total_subsidies_received" in data
        assert "recent_payments" in data
        assert "loans" in data
        assert "insurance_policies" in data
