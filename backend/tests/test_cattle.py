import uuid
import pytest
import pytest_asyncio
from app.models.farmer import Farmer
from app.models.cattle import Cattle

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture
async def farmer(db_session, test_user):
    f = Farmer(
        id=uuid.uuid4(),
        user_id=test_user.id,
        name="Test Farmer",
        village="Test Village",
        district="Anand",
        state="Gujarat",
    )
    db_session.add(f)
    await db_session.flush()
    return f


@pytest_asyncio.fixture
async def other_user_and_farmer(db_session):
    from app.models.user import User, UserRole
    from app.services.auth_service import create_access_token
    user2 = User(id=uuid.uuid4(), phone="9999900099", role=UserRole.farmer, is_active=True)
    db_session.add(user2)
    await db_session.flush()
    farmer2 = Farmer(id=uuid.uuid4(), user_id=user2.id, name="Other Farmer")
    db_session.add(farmer2)
    await db_session.flush()
    token = create_access_token(str(user2.id), "farmer")
    headers = {"Authorization": f"Bearer {token}"}
    return farmer2, headers


class TestCreateCattle:
    async def test_create_cattle(self, client, auth_headers, farmer):
        response = await client.post(
            "/api/v1/cattle",
            json={"tag_id": "IN123456789012", "name": "Lakshmi", "breed": "gir", "sex": "female"},
            headers=auth_headers,
        )
        assert response.status_code == 201
        assert response.json()["data"]["tag_id"] == "IN123456789012"

    async def test_create_cattle_duplicate_tag(self, client, auth_headers, farmer):
        await client.post(
            "/api/v1/cattle",
            json={"tag_id": "DUP001", "name": "Cow1", "breed": "sahiwal"},
            headers=auth_headers,
        )
        response = await client.post(
            "/api/v1/cattle",
            json={"tag_id": "DUP001", "name": "Cow2", "breed": "gir"},
            headers=auth_headers,
        )
        assert response.status_code == 409


class TestListCattle:
    async def test_list_cattle_by_farmer(self, client, auth_headers, farmer):
        await client.post(
            "/api/v1/cattle",
            json={"tag_id": "LIST001", "name": "C1", "breed": "gir"},
            headers=auth_headers,
        )
        response = await client.get("/api/v1/cattle", headers=auth_headers)
        assert response.status_code == 200
        assert len(response.json()["data"]) >= 1


class TestCattleDashboard:
    async def test_cattle_dashboard(self, client, auth_headers, farmer):
        await client.post(
            "/api/v1/cattle",
            json={"tag_id": "DASH001", "name": "D1", "breed": "murrah"},
            headers=auth_headers,
        )
        response = await client.get("/api/v1/cattle/dashboard", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()["data"]
        assert data["total"] >= 1
        assert data["active"] >= 1


class TestUpdateCattle:
    async def test_update_cattle(self, client, auth_headers, farmer):
        create_resp = await client.post(
            "/api/v1/cattle",
            json={"tag_id": "UPD001", "name": "Old", "breed": "gir"},
            headers=auth_headers,
        )
        cattle_id = create_resp.json()["data"]["id"]
        response = await client.put(
            f"/api/v1/cattle/{cattle_id}",
            json={"name": "New Name", "weight_kg": 350.5},
            headers=auth_headers,
        )
        assert response.status_code == 200


class TestUnauthorizedAccess:
    async def test_farmer_cannot_see_other_farmer_cattle(self, client, auth_headers, farmer, other_user_and_farmer):
        _, other_headers = other_user_and_farmer
        # Create cattle as first farmer
        create_resp = await client.post(
            "/api/v1/cattle",
            json={"tag_id": "SEC001", "name": "Secret Cow", "breed": "gir"},
            headers=auth_headers,
        )
        cattle_id = create_resp.json()["data"]["id"]
        # Try to access as other farmer
        response = await client.get(f"/api/v1/cattle/{cattle_id}", headers=other_headers)
        assert response.status_code == 404
