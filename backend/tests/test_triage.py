import uuid
import pytest
import pytest_asyncio
from datetime import datetime, timezone

from app.models.farmer import Farmer
from app.models.cattle import Cattle
from app.models.health import SensorReading

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture
async def triage_setup(db_session, test_user):
    farmer = Farmer(id=uuid.uuid4(), user_id=test_user.id, name="Triage Farmer")
    db_session.add(farmer)
    await db_session.flush()
    cattle = Cattle(
        id=uuid.uuid4(), farmer_id=farmer.id, tag_id="TRIAGE001",
        name="TriageCow", breed="gir", sex="female", status="active",
    )
    db_session.add(cattle)
    await db_session.flush()
    return farmer, cattle


class TestTriage:
    async def test_triage_low(self, client, auth_headers, triage_setup):
        _, cattle = triage_setup
        response = await client.post(
            "/api/v1/triage",
            json={"cattle_id": str(cattle.id), "symptoms": "slight cough"},
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()["data"]
        assert data["severity_level"] == "low"
        assert data["recommended_action"] == "self_care"

    async def test_triage_high(self, client, auth_headers, triage_setup, db_session):
        _, cattle = triage_setup
        # Add bad sensor data
        reading = SensorReading(
            cattle_id=cattle.id, time=datetime.now(timezone.utc),
            temperature=40.5, heart_rate=95, activity_level=10.0,
        )
        db_session.add(reading)
        await db_session.flush()
        response = await client.post(
            "/api/v1/triage",
            json={"cattle_id": str(cattle.id), "symptoms": "not eating, blood in stool, fever"},
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()["data"]
        assert data["severity"] >= 7
        assert data["severity_level"] in ("high", "emergency")

    async def test_chat_basic(self, client, auth_headers, triage_setup):
        response = await client.post(
            "/api/v1/chat/message",
            json={"message": "What should I feed my cow?"},
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()["data"]
        assert "response" in data
        assert len(data["response"]) > 0
