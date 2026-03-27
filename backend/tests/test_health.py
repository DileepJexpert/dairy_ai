import uuid
import pytest
import pytest_asyncio
from datetime import date, datetime, timedelta, timezone

from app.models.farmer import Farmer
from app.models.cattle import Cattle
from app.models.health import SensorReading

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture
async def farmer_and_cattle(db_session, test_user):
    farmer = Farmer(id=uuid.uuid4(), user_id=test_user.id, name="Health Farmer")
    db_session.add(farmer)
    await db_session.flush()
    cattle = Cattle(
        id=uuid.uuid4(), farmer_id=farmer.id, tag_id="HEALTH001",
        name="HealthCow", breed="gir", sex="female", status="active",
    )
    db_session.add(cattle)
    await db_session.flush()
    return farmer, cattle


class TestHealthRecords:
    async def test_create_health_record(self, client, auth_headers, farmer_and_cattle):
        _, cattle = farmer_and_cattle
        response = await client.post(
            f"/api/v1/cattle/{cattle.id}/health-records",
            json={"date": "2026-03-27", "record_type": "illness", "symptoms": "Fever, not eating", "severity": 7},
            headers=auth_headers,
        )
        assert response.status_code == 201
        assert response.json()["success"] is True


class TestVaccinations:
    async def test_vaccination_upcoming(self, client, auth_headers, farmer_and_cattle, db_session):
        _, cattle = farmer_and_cattle
        from app.models.health import Vaccination
        vacc = Vaccination(
            cattle_id=cattle.id, vaccine_name="FMD",
            date_given=date.today() - timedelta(days=180),
            next_due_date=date.today() + timedelta(days=10),
        )
        db_session.add(vacc)
        await db_session.flush()
        response = await client.get(
            f"/api/v1/cattle/{cattle.id}/vaccinations",
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()["data"]
        assert len(data) >= 1
        assert data[0]["vaccine_name"] == "FMD"


class TestSensorData:
    async def test_sensor_ingest(self, client, auth_headers, farmer_and_cattle):
        _, cattle = farmer_and_cattle
        response = await client.post(
            f"/api/v1/cattle/{cattle.id}/sensor-data",
            json={"temperature": 38.5, "heart_rate": 65, "activity_level": 55.0},
            headers=auth_headers,
        )
        assert response.status_code == 201
        assert response.json()["success"] is True

    async def test_sensor_stats(self, client, auth_headers, farmer_and_cattle, db_session):
        _, cattle = farmer_and_cattle
        # Add some sensor readings
        now = datetime.now(timezone.utc)
        for i in range(5):
            reading = SensorReading(
                cattle_id=cattle.id, time=now - timedelta(hours=i),
                temperature=38.0 + i * 0.3, heart_rate=60 + i * 2, activity_level=50.0,
            )
            db_session.add(reading)
        await db_session.flush()
        response = await client.get(
            f"/api/v1/cattle/{cattle.id}/sensors/stats?hours=24",
            headers=auth_headers,
        )
        assert response.status_code == 200
        stats = response.json()["data"]
        assert stats["avg_temperature"] is not None

    async def test_anomaly_detection(self, client, auth_headers, farmer_and_cattle, db_session):
        _, cattle = farmer_and_cattle
        # Ingest a high-temp reading
        response = await client.post(
            f"/api/v1/cattle/{cattle.id}/sensor-data",
            json={"temperature": 40.5, "heart_rate": 90, "activity_level": 20.0},
            headers=auth_headers,
        )
        assert response.status_code == 201
        alerts = response.json()["data"]["alerts"]
        alert_types = [a["alert_type"] for a in alerts]
        assert "high_temperature" in alert_types
        assert "high_heart_rate" in alert_types


class TestHealthDashboard:
    async def test_health_dashboard(self, client, auth_headers, farmer_and_cattle, db_session):
        _, cattle = farmer_and_cattle
        # Add sensor reading
        reading = SensorReading(
            cattle_id=cattle.id, time=datetime.now(timezone.utc),
            temperature=38.5, heart_rate=65, activity_level=55.0,
        )
        db_session.add(reading)
        await db_session.flush()
        response = await client.get(
            f"/api/v1/cattle/{cattle.id}/health-dashboard",
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()["data"]
        assert "latest_vitals" in data
        assert "stats_24h" in data
        assert "alerts" in data
