import pytest
import uuid
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User, UserRole
from app.models.farmer import Farmer
from app.services.auth_service import create_access_token, hash_otp
from datetime import datetime, timedelta, timezone


class TestLoginRoleRouting:
    @pytest.mark.asyncio
    async def test_login_returns_dashboard_url_farmer(self, client: AsyncClient, db_session: AsyncSession):
        user = User(
            id=uuid.uuid4(),
            phone="9999911111",
            role=UserRole.farmer,
            is_active=True,
            otp_hash=hash_otp("123456"),
            otp_expires_at=datetime.now(timezone.utc) + timedelta(minutes=5),
        )
        db_session.add(user)
        await db_session.flush()

        resp = await client.post("/api/v1/auth/verify-otp", json={"phone": "9999911111", "otp": "123456"})
        assert resp.status_code == 200
        data = resp.json()
        assert data["role"] == "farmer"
        assert data["dashboard_url"] == "/api/v1/farmers/me/dashboard"

    @pytest.mark.asyncio
    async def test_login_returns_dashboard_url_vendor(self, client: AsyncClient, db_session: AsyncSession):
        user = User(
            id=uuid.uuid4(),
            phone="9999922222",
            role=UserRole.vendor,
            is_active=True,
            otp_hash=hash_otp("123456"),
            otp_expires_at=datetime.now(timezone.utc) + timedelta(minutes=5),
        )
        db_session.add(user)
        await db_session.flush()

        resp = await client.post("/api/v1/auth/verify-otp", json={"phone": "9999922222", "otp": "123456"})
        assert resp.status_code == 200
        data = resp.json()
        assert data["role"] == "vendor"
        assert data["dashboard_url"] == "/api/v1/vendor/dashboard"

    @pytest.mark.asyncio
    async def test_login_returns_dashboard_url_cooperative(self, client: AsyncClient, db_session: AsyncSession):
        user = User(
            id=uuid.uuid4(),
            phone="9999933333",
            role=UserRole.cooperative,
            is_active=True,
            otp_hash=hash_otp("123456"),
            otp_expires_at=datetime.now(timezone.utc) + timedelta(minutes=5),
        )
        db_session.add(user)
        await db_session.flush()

        resp = await client.post("/api/v1/auth/verify-otp", json={"phone": "9999933333", "otp": "123456"})
        assert resp.status_code == 200
        data = resp.json()
        assert data["role"] == "cooperative"
        assert data["dashboard_url"] == "/api/v1/cooperative/dashboard"


class TestAuthMeDashboardUrl:
    @pytest.mark.asyncio
    async def test_me_returns_dashboard_url(self, client: AsyncClient, auth_headers: dict):
        resp = await client.get("/api/v1/auth/me", headers=auth_headers)
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["role"] == "farmer"
        assert data["dashboard_url"] == "/api/v1/farmers/me/dashboard"

    @pytest.mark.asyncio
    async def test_me_vendor_dashboard_url(self, client: AsyncClient, vendor_headers: dict):
        resp = await client.get("/api/v1/auth/me", headers=vendor_headers)
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["role"] == "vendor"
        assert data["dashboard_url"] == "/api/v1/vendor/dashboard"


class TestFarmerDashboard:
    @pytest.mark.asyncio
    async def test_farmer_dashboard(self, client: AsyncClient, auth_headers: dict, test_user: User, db_session: AsyncSession):
        farmer = Farmer(
            id=uuid.uuid4(),
            user_id=test_user.id,
            name="Test Farmer",
            village="Test Village",
            district="Jaipur",
            state="Rajasthan",
        )
        db_session.add(farmer)
        await db_session.flush()

        resp = await client.get("/api/v1/farmers/me/dashboard", headers=auth_headers)
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["profile"]["name"] == "Test Farmer"
        assert "stats" in data
        assert "total_cattle" in data["stats"]
        assert "milk_today_litres" in data["stats"]

    @pytest.mark.asyncio
    async def test_farmer_dashboard_no_profile(self, client: AsyncClient, auth_headers: dict):
        resp = await client.get("/api/v1/farmers/me/dashboard", headers=auth_headers)
        assert resp.status_code == 404
