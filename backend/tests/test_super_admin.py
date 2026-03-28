import uuid
import pytest
import pytest_asyncio

from app.models.user import User, UserRole
from app.models.farmer import Farmer
from app.models.vet import VetProfile

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture
async def seed_data(db_session):
    """Seed some users, farmers, and vets for super admin tests."""
    # Create farmers
    for i in range(3):
        user = User(id=uuid.uuid4(), phone=f"777700000{i}", role=UserRole.farmer, is_active=True)
        db_session.add(user)
        await db_session.flush()
        farmer = Farmer(id=uuid.uuid4(), user_id=user.id, name=f"TestFarmer {i}", district="Anand")
        db_session.add(farmer)

    # Create a vet user + unverified profile
    vet_user = User(id=uuid.uuid4(), phone="7777099999", role=UserRole.vet, is_active=True)
    db_session.add(vet_user)
    await db_session.flush()
    vet_profile = VetProfile(
        id=uuid.uuid4(),
        user_id=vet_user.id,
        license_number="VET-TEST-001",
        qualification="bvsc",
        specializations=["cattle"],
        consultation_fee=200.0,
        is_verified=False,
    )
    db_session.add(vet_profile)
    await db_session.flush()
    return vet_user, vet_profile


class TestSuperAdminDashboard:
    async def test_super_admin_dashboard(self, client, super_admin_headers, seed_data):
        response = await client.get("/api/v1/super-admin/dashboard", headers=super_admin_headers)
        assert response.status_code == 200
        data = response.json()["data"]
        assert "users" in data
        assert "platform" in data
        assert "consultations" in data
        assert "milk" in data
        assert "health" in data
        assert data["platform"]["total_farmers"] >= 3

    async def test_super_admin_requires_super_admin_role(self, client, admin_headers):
        response = await client.get("/api/v1/super-admin/dashboard", headers=admin_headers)
        assert response.status_code == 403

    async def test_farmer_cannot_access_super_admin(self, client, auth_headers):
        response = await client.get("/api/v1/super-admin/dashboard", headers=auth_headers)
        assert response.status_code == 403


class TestSuperAdminUserManagement:
    async def test_list_users(self, client, super_admin_headers, seed_data):
        response = await client.get("/api/v1/super-admin/users", headers=super_admin_headers)
        assert response.status_code == 200
        assert len(response.json()["data"]) >= 3

    async def test_list_users_filter_by_role(self, client, super_admin_headers, seed_data):
        response = await client.get("/api/v1/super-admin/users?role=vet", headers=super_admin_headers)
        assert response.status_code == 200
        for user in response.json()["data"]:
            assert user["role"] == "vet"

    async def test_change_user_role(self, client, super_admin_headers, seed_data):
        vet_user, _ = seed_data
        response = await client.put(
            f"/api/v1/super-admin/users/{vet_user.id}/role?new_role=admin",
            headers=super_admin_headers,
        )
        assert response.status_code == 200
        assert response.json()["data"]["new_role"] == "admin"

    async def test_toggle_user_active(self, client, super_admin_headers, seed_data):
        vet_user, _ = seed_data
        response = await client.put(
            f"/api/v1/super-admin/users/{vet_user.id}/toggle-active",
            headers=super_admin_headers,
        )
        assert response.status_code == 200
        assert response.json()["data"]["is_active"] is False


class TestSuperAdminVetVerification:
    async def test_pending_verifications(self, client, super_admin_headers, seed_data):
        response = await client.get("/api/v1/super-admin/vets/pending-verification", headers=super_admin_headers)
        assert response.status_code == 200
        assert len(response.json()["data"]) >= 1

    async def test_verify_vet(self, client, super_admin_headers, seed_data):
        _, vet_profile = seed_data
        response = await client.put(
            f"/api/v1/super-admin/vets/{vet_profile.id}/verify",
            headers=super_admin_headers,
        )
        assert response.status_code == 200
        assert response.json()["data"]["is_verified"] is True

    async def test_reject_vet(self, client, super_admin_headers, seed_data):
        _, vet_profile = seed_data
        response = await client.put(
            f"/api/v1/super-admin/vets/{vet_profile.id}/reject?reason=Missing+documents",
            headers=super_admin_headers,
        )
        assert response.status_code == 200
        assert response.json()["data"]["is_verified"] is False


class TestSuperAdminAnalytics:
    async def test_platform_analytics(self, client, super_admin_headers, seed_data):
        response = await client.get("/api/v1/super-admin/analytics/overview?days=30", headers=super_admin_headers)
        assert response.status_code == 200
        data = response.json()["data"]
        assert "registrations" in data
        assert "consultations" in data
        assert "revenue" in data


class TestSuperAdminSystem:
    async def test_system_health(self, client, super_admin_headers, seed_data):
        response = await client.get("/api/v1/super-admin/system/health", headers=super_admin_headers)
        assert response.status_code == 200
        data = response.json()["data"]
        assert data["database"] == "connected"
        assert "users" in data["table_counts"]
        assert data["table_counts"]["users"] >= 1

    async def test_create_admin(self, client, super_admin_headers):
        response = await client.post(
            "/api/v1/super-admin/users/create-admin?phone=9999988888&role=admin",
            headers=super_admin_headers,
        )
        assert response.status_code == 200
        assert response.json()["data"]["role"] == "admin"
