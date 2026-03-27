import uuid
import pytest
import pytest_asyncio

from app.models.farmer import Farmer
from app.models.notification import Notification

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture
async def some_farmers(db_session):
    for i in range(3):
        from app.models.user import User, UserRole
        user = User(id=uuid.uuid4(), phone=f"888800000{i}", role=UserRole.farmer, is_active=True)
        db_session.add(user)
        await db_session.flush()
        farmer = Farmer(id=uuid.uuid4(), user_id=user.id, name=f"Farmer {i}", district="Anand")
        db_session.add(farmer)
    await db_session.flush()


class TestNotifications:
    async def test_create_notification(self, client, auth_headers, test_user, db_session):
        notif = Notification(
            user_id=test_user.id, type="health_alert",
            title="High Temperature", body="Your cow has fever",
        )
        db_session.add(notif)
        await db_session.flush()
        response = await client.get("/api/v1/notifications", headers=auth_headers)
        assert response.status_code == 200
        assert len(response.json()["data"]) >= 1

    async def test_notification_list_unread(self, client, auth_headers, test_user, db_session):
        db_session.add(Notification(user_id=test_user.id, type="general", title="T1", body="B1", is_read=False))
        db_session.add(Notification(user_id=test_user.id, type="general", title="T2", body="B2", is_read=True))
        await db_session.flush()
        response = await client.get("/api/v1/notifications?unread_only=true", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()["data"]
        assert all(not n["is_read"] for n in data)


class TestAdmin:
    async def test_admin_dashboard_stats(self, client, admin_headers, some_farmers):
        response = await client.get("/api/v1/admin/dashboard", headers=admin_headers)
        assert response.status_code == 200
        data = response.json()["data"]
        assert data["total_farmers"] >= 3

    async def test_admin_requires_admin_role(self, client, auth_headers):
        response = await client.get("/api/v1/admin/dashboard", headers=auth_headers)
        assert response.status_code == 403
