"""Tests for milk collection, quality grading, cold chain, and route APIs."""
import uuid
from datetime import date

import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User, UserRole
from app.models.farmer import Farmer
from app.models.cooperative import Cooperative
from app.models.collection import CollectionCenter
from app.services.auth_service import create_access_token
from app.services.collection_service import grade_milk, calculate_rate
from app.models.collection import MilkGrade


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest_asyncio.fixture
async def coop_user_for_collection(db_session: AsyncSession) -> User:
    user = User(id=uuid.uuid4(), phone="9999970001", role=UserRole.cooperative, is_active=True)
    db_session.add(user)
    await db_session.flush()
    return user


@pytest_asyncio.fixture
async def coop_headers_for_collection(coop_user_for_collection: User) -> dict:
    token = create_access_token(str(coop_user_for_collection.id), coop_user_for_collection.role.value)
    return {"Authorization": f"Bearer {token}"}


@pytest_asyncio.fixture
async def farmer_for_collection(db_session: AsyncSession) -> tuple[User, Farmer]:
    user = User(id=uuid.uuid4(), phone="9999970010", role=UserRole.farmer, is_active=True)
    db_session.add(user)
    await db_session.flush()
    farmer = Farmer(id=uuid.uuid4(), user_id=user.id, name="Collection Farmer", district="Jaipur")
    db_session.add(farmer)
    await db_session.flush()
    return user, farmer


@pytest_asyncio.fixture
async def collection_center(db_session: AsyncSession) -> CollectionCenter:
    center = CollectionCenter(
        id=uuid.uuid4(),
        name="Jaipur Central BMC",
        code="JP-BMC-001",
        district="Jaipur",
        state="Rajasthan",
        capacity_litres=1000.0,
        current_stock_litres=0.0,
        lat=26.9124,
        lng=75.7873,
    )
    db_session.add(center)
    await db_session.flush()
    return center


# ---------------------------------------------------------------------------
# Unit Tests: Quality Grading
# ---------------------------------------------------------------------------

class TestQualityGrading:
    def test_grade_a(self):
        assert grade_milk(4.5, 8.8) == MilkGrade.A

    def test_grade_b(self):
        assert grade_milk(3.6, 8.2) == MilkGrade.B

    def test_grade_c(self):
        assert grade_milk(3.1, 7.6) == MilkGrade.C

    def test_grade_rejected(self):
        assert grade_milk(2.5, 7.0) == MilkGrade.rejected

    def test_grade_none_values(self):
        assert grade_milk(None, None) == MilkGrade.C

    def test_rate_high_fat(self):
        rate = calculate_rate(5.0)
        # base 30 + (5.0 - 3.0) * 5 = 30 + 10 = 40
        assert rate == 40.0

    def test_rate_low_fat(self):
        rate = calculate_rate(2.5)
        # base 30 + max(0, -0.5) * 5 = 30
        assert rate == 30.0


# ---------------------------------------------------------------------------
# API Tests: Collection Center
# ---------------------------------------------------------------------------

class TestCollectionCenter:
    @pytest.mark.asyncio
    async def test_create_center(self, client: AsyncClient, coop_headers_for_collection: dict):
        resp = await client.post(
            "/api/v1/collection/centers",
            json={
                "name": "Test BMC",
                "code": "TST-001",
                "district": "Jaipur",
                "state": "Rajasthan",
                "capacity_litres": 500.0,
            },
            headers=coop_headers_for_collection,
        )
        assert resp.status_code == 201
        data = resp.json()["data"]
        assert data["name"] == "Test BMC"
        assert data["code"] == "TST-001"
        assert data["capacity_litres"] == 500.0

    @pytest.mark.asyncio
    async def test_list_centers(self, client: AsyncClient, coop_headers_for_collection: dict, collection_center):
        resp = await client.get(
            "/api/v1/collection/centers",
            headers=coop_headers_for_collection,
        )
        assert resp.status_code == 200
        assert len(resp.json()["data"]) >= 1


# ---------------------------------------------------------------------------
# API Tests: Milk Collection with Auto Grading & Pricing
# ---------------------------------------------------------------------------

class TestMilkCollection:
    @pytest.mark.asyncio
    async def test_record_grade_a_milk(
        self, client: AsyncClient, coop_headers_for_collection: dict,
        collection_center, farmer_for_collection,
    ):
        _, farmer = farmer_for_collection
        resp = await client.post(
            "/api/v1/collection/milk",
            json={
                "center_id": str(collection_center.id),
                "farmer_id": str(farmer.id),
                "date": str(date.today()),
                "shift": "morning",
                "quantity_litres": 10.0,
                "fat_pct": 4.5,
                "snf_pct": 8.8,
                "temperature_celsius": 3.5,
            },
            headers=coop_headers_for_collection,
        )
        assert resp.status_code == 201
        data = resp.json()["data"]
        assert data["milk_grade"] == "A"
        assert data["is_rejected"] is False
        # rate = 30 + (4.5-3.0)*5 = 37.5; total = 10 * 37.5 = 375
        assert data["rate_per_litre"] == 37.5
        assert data["total_amount"] == 375.0
        # grade A bonus = 10 * 2 = 20
        assert data["quality_bonus"] == 20.0
        assert data["net_amount"] == 395.0

    @pytest.mark.asyncio
    async def test_reject_high_temp_milk(
        self, client: AsyncClient, coop_headers_for_collection: dict,
        collection_center, farmer_for_collection,
    ):
        _, farmer = farmer_for_collection
        resp = await client.post(
            "/api/v1/collection/milk",
            json={
                "center_id": str(collection_center.id),
                "farmer_id": str(farmer.id),
                "date": str(date.today()),
                "shift": "morning",
                "quantity_litres": 8.0,
                "fat_pct": 4.0,
                "snf_pct": 8.5,
                "temperature_celsius": 12.0,
            },
            headers=coop_headers_for_collection,
        )
        assert resp.status_code == 201
        data = resp.json()["data"]
        assert data["is_rejected"] is True
        assert "temperature" in data["rejection_reason"].lower()
        assert data["net_amount"] == 0.0

    @pytest.mark.asyncio
    async def test_reject_low_quality_milk(
        self, client: AsyncClient, coop_headers_for_collection: dict,
        collection_center, farmer_for_collection,
    ):
        _, farmer = farmer_for_collection
        resp = await client.post(
            "/api/v1/collection/milk",
            json={
                "center_id": str(collection_center.id),
                "farmer_id": str(farmer.id),
                "date": str(date.today()),
                "shift": "evening",
                "quantity_litres": 5.0,
                "fat_pct": 2.0,
                "snf_pct": 6.5,
                "temperature_celsius": 3.0,
            },
            headers=coop_headers_for_collection,
        )
        assert resp.status_code == 201
        data = resp.json()["data"]
        assert data["milk_grade"] == "rejected"
        assert data["is_rejected"] is True


# ---------------------------------------------------------------------------
# API Tests: Cold Chain Monitoring
# ---------------------------------------------------------------------------

class TestColdChain:
    @pytest.mark.asyncio
    async def test_normal_temp_no_alert(
        self, client: AsyncClient, coop_headers_for_collection: dict, collection_center,
    ):
        resp = await client.post(
            "/api/v1/collection/cold-chain/reading",
            json={
                "center_id": str(collection_center.id),
                "temperature_celsius": 3.5,
                "device_id": "SENSOR-001",
            },
            headers=coop_headers_for_collection,
        )
        assert resp.status_code == 201
        assert resp.json()["data"]["is_alert"] is False

    @pytest.mark.asyncio
    async def test_warning_temp_creates_alert(
        self, client: AsyncClient, coop_headers_for_collection: dict, collection_center,
    ):
        resp = await client.post(
            "/api/v1/collection/cold-chain/reading",
            json={
                "center_id": str(collection_center.id),
                "temperature_celsius": 6.0,
            },
            headers=coop_headers_for_collection,
        )
        assert resp.status_code == 201
        assert resp.json()["data"]["is_alert"] is True

        # Check alert was created
        alerts_resp = await client.get(
            f"/api/v1/collection/cold-chain/alerts?center_id={collection_center.id}",
            headers=coop_headers_for_collection,
        )
        assert alerts_resp.status_code == 200
        alerts = alerts_resp.json()["data"]
        assert len(alerts) >= 1
        assert alerts[0]["severity"] == "warning"

    @pytest.mark.asyncio
    async def test_critical_temp_alert(
        self, client: AsyncClient, coop_headers_for_collection: dict, collection_center,
    ):
        resp = await client.post(
            "/api/v1/collection/cold-chain/reading",
            json={
                "center_id": str(collection_center.id),
                "temperature_celsius": 10.0,
            },
            headers=coop_headers_for_collection,
        )
        assert resp.status_code == 201
        assert resp.json()["data"]["is_alert"] is True


# ---------------------------------------------------------------------------
# API Tests: Center Dashboard
# ---------------------------------------------------------------------------

class TestCenterDashboard:
    @pytest.mark.asyncio
    async def test_center_dashboard(
        self, client: AsyncClient, coop_headers_for_collection: dict, collection_center,
    ):
        resp = await client.get(
            f"/api/v1/collection/centers/{collection_center.id}/dashboard",
            headers=coop_headers_for_collection,
        )
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert "center" in data
        assert "today" in data
        assert "alerts" in data
        assert data["center"]["code"] == "JP-BMC-001"
