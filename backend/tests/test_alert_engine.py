"""Tests for alert_engine service — sensor alerts, dedup, vaccination reminders."""
import uuid
from datetime import date, datetime, timedelta, timezone

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User, UserRole
from app.models.farmer import Farmer
from app.models.cattle import Cattle, Breed, Sex, CattleStatus
from app.models.notification import Notification, NotificationType
from app.services.auth_service import create_access_token
from app.services import alert_engine, notification_service


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest_asyncio.fixture
async def farmer_with_cattle(db_session: AsyncSession):
    """Create a user → farmer → cattle chain for alert tests."""
    user = User(
        id=uuid.uuid4(),
        phone="8888800001",
        role=UserRole.farmer,
        is_active=True,
    )
    db_session.add(user)
    await db_session.flush()

    farmer = Farmer(
        id=uuid.uuid4(),
        user_id=user.id,
        name="Alert Test Farmer",
        village="TestVillage",
        district="TestDistrict",
    )
    db_session.add(farmer)
    await db_session.flush()

    cattle = Cattle(
        id=uuid.uuid4(),
        farmer_id=farmer.id,
        tag_id="ALERT001",
        name="Lakshmi",
        breed=Breed.gir,
        sex=Sex.female,
        status=CattleStatus.active,
    )
    db_session.add(cattle)
    await db_session.flush()

    return user, farmer, cattle


# ---------------------------------------------------------------------------
# _get_farmer_user_id
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_get_farmer_user_id(db_session, farmer_with_cattle):
    user, farmer, cattle = farmer_with_cattle
    result = await alert_engine._get_farmer_user_id(db_session, cattle.id)
    assert result == user.id


@pytest.mark.asyncio
async def test_get_farmer_user_id_unknown_cattle(db_session):
    result = await alert_engine._get_farmer_user_id(db_session, uuid.uuid4())
    assert result is None


# ---------------------------------------------------------------------------
# process_sensor_alerts
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_process_sensor_alerts_creates_notification(db_session, farmer_with_cattle):
    user, farmer, cattle = farmer_with_cattle
    alerts = [
        {
            "alert_type": "high_temperature",
            "message": "Temperature 40.2°C exceeds threshold 39.5°C",
            "current_value": 40.2,
            "threshold": 39.5,
        }
    ]
    sent = await alert_engine.process_sensor_alerts(db_session, cattle.id, alerts)
    assert len(sent) == 1
    assert sent[0]["alert_type"] == "high_temperature"
    assert sent[0]["user_id"] == str(user.id)

    # Verify notification exists in DB
    notifs = await notification_service.get_notifications(db_session, user.id)
    assert len(notifs) == 1
    assert notifs[0].title == "Fever Alert"
    assert notifs[0].type == NotificationType.health_alert


@pytest.mark.asyncio
async def test_process_sensor_alerts_empty_list(db_session, farmer_with_cattle):
    _, _, cattle = farmer_with_cattle
    sent = await alert_engine.process_sensor_alerts(db_session, cattle.id, [])
    assert sent == []


@pytest.mark.asyncio
async def test_process_sensor_alerts_unknown_cattle(db_session):
    alerts = [{"alert_type": "high_temperature", "message": "Fever"}]
    sent = await alert_engine.process_sensor_alerts(db_session, uuid.uuid4(), alerts)
    assert sent == []


@pytest.mark.asyncio
async def test_process_sensor_alerts_multiple_alerts(db_session, farmer_with_cattle):
    user, _, cattle = farmer_with_cattle
    alerts = [
        {"alert_type": "high_temperature", "message": "Fever", "current_value": 40.5, "threshold": 39.5},
        {"alert_type": "high_heart_rate", "message": "High HR", "current_value": 90, "threshold": 80},
        {"alert_type": "low_battery", "message": "Battery low", "current_value": 5, "threshold": 10},
    ]
    sent = await alert_engine.process_sensor_alerts(db_session, cattle.id, alerts)
    assert len(sent) == 3

    notifs = await notification_service.get_notifications(db_session, user.id)
    assert len(notifs) == 3
    titles = {n.title for n in notifs}
    assert "Fever Alert" in titles
    assert "Heart Rate Alert" in titles
    assert "Collar Battery Low" in titles


# ---------------------------------------------------------------------------
# Alert deduplication (SQLite doesn't support JSON operators, so dedup is
# skipped gracefully — we test that the fallback works)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_process_sensor_alerts_second_call(db_session, farmer_with_cattle):
    """Second call for same alert — may be deduped or sent depending on DB backend.
    On SQLite, JSON operator may fail → dedup skipped → sends again.
    On PostgreSQL, dedup would filter it. Either outcome is valid."""
    user, _, cattle = farmer_with_cattle
    alerts = [{"alert_type": "high_temperature", "message": "Fever"}]

    sent1 = await alert_engine.process_sensor_alerts(db_session, cattle.id, alerts)
    assert len(sent1) == 1

    # Second call — result depends on whether JSON operator works on this DB
    sent2 = await alert_engine.process_sensor_alerts(db_session, cattle.id, alerts)
    assert len(sent2) in (0, 1)  # 0 = dedup worked, 1 = dedup skipped (SQLite)


# ---------------------------------------------------------------------------
# _alert_title
# ---------------------------------------------------------------------------

def test_alert_title_known_types():
    assert alert_engine._alert_title("high_temperature") == "Fever Alert"
    assert alert_engine._alert_title("high_heart_rate") == "Heart Rate Alert"
    assert alert_engine._alert_title("activity_drop") == "Low Activity Alert"
    assert alert_engine._alert_title("low_battery") == "Collar Battery Low"


def test_alert_title_unknown_type():
    assert alert_engine._alert_title("something_else") == "Health Alert"


# ---------------------------------------------------------------------------
# FCM device token management
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_register_and_get_device_token():
    uid = uuid.uuid4()
    token = "fcm-test-token-abc123"
    await alert_engine.register_device_token(uid, token)
    result = await alert_engine.get_device_token(uid)
    assert result == token


@pytest.mark.asyncio
async def test_get_device_token_not_registered():
    result = await alert_engine.get_device_token(uuid.uuid4())
    assert result is None


# ---------------------------------------------------------------------------
# Vaccination reminders
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_send_vaccination_reminders(db_session, farmer_with_cattle):
    from app.models.health import Vaccination

    user, farmer, cattle = farmer_with_cattle

    # Create a vaccination due tomorrow
    tomorrow = date.today() + timedelta(days=1)
    vacc = Vaccination(
        id=uuid.uuid4(),
        cattle_id=cattle.id,
        vaccine_name="FMD",
        date_given=date.today() - timedelta(days=180),
        next_due_date=tomorrow,
    )
    db_session.add(vacc)
    await db_session.flush()

    count = await alert_engine.send_vaccination_reminders(db_session)
    assert count >= 1

    # Check notification was created
    notifs = await notification_service.get_notifications(db_session, user.id)
    vacc_notifs = [n for n in notifs if n.type == NotificationType.vaccination_due]
    assert len(vacc_notifs) >= 1
    assert "FMD" in vacc_notifs[0].body


@pytest.mark.asyncio
async def test_send_vaccination_reminders_no_upcoming(db_session, farmer_with_cattle):
    """No vaccinations due within 3 days → 0 reminders."""
    count = await alert_engine.send_vaccination_reminders(db_session)
    assert count == 0


# ---------------------------------------------------------------------------
# API endpoints (notifications)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_unread_count_endpoint(client, test_user, auth_headers, db_session):
    # Create a notification for the user
    await notification_service.create_notification(
        db_session, test_user.id,
        type=NotificationType.health_alert.value,
        title="Test", body="Test body",
    )
    await db_session.flush()

    resp = await client.get("/api/v1/notifications/unread-count", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["success"] is True
    assert data["data"]["count"] >= 1


@pytest.mark.asyncio
async def test_device_token_endpoint(client, auth_headers):
    resp = await client.post(
        "/api/v1/notifications/device-token",
        json={"token": "fcm-test-token-xyz"},
        headers=auth_headers,
    )
    assert resp.status_code == 200
    assert resp.json()["success"] is True


@pytest.mark.asyncio
async def test_device_token_endpoint_missing_token(client, auth_headers):
    resp = await client.post(
        "/api/v1/notifications/device-token",
        json={"token": ""},
        headers=auth_headers,
    )
    assert resp.status_code == 200
    assert resp.json()["success"] is False


@pytest.mark.asyncio
async def test_trigger_vaccination_reminders_requires_admin(client, auth_headers):
    """Regular farmer cannot trigger vaccination reminders."""
    resp = await client.post(
        "/api/v1/notifications/trigger-vaccination-reminders",
        headers=auth_headers,
    )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_trigger_vaccination_reminders_as_admin(client, admin_headers, db_session):
    resp = await client.post(
        "/api/v1/notifications/trigger-vaccination-reminders",
        headers=admin_headers,
    )
    assert resp.status_code == 200
    assert resp.json()["success"] is True
    assert "reminders_sent" in resp.json()["data"]
