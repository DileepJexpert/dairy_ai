import uuid
import pytest
import pytest_asyncio
from datetime import date, timedelta

from app.models.farmer import Farmer
from app.models.cattle import Cattle
from app.models.finance import Transaction

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture
async def setup(db_session, test_user):
    farmer = Farmer(id=uuid.uuid4(), user_id=test_user.id, name="FBF Farmer", district="Anand")
    db_session.add(farmer)
    await db_session.flush()
    cattle = Cattle(
        id=uuid.uuid4(), farmer_id=farmer.id, tag_id="FBF001",
        name="FBFCow", breed="gir", sex="female", status="active", weight_kg=400.0,
    )
    db_session.add(cattle)
    await db_session.flush()
    return farmer, cattle


class TestFeedPlan:
    async def test_generate_feed_plan(self, client, auth_headers, setup):
        _, cattle = setup
        response = await client.post(
            f"/api/v1/cattle/{cattle.id}/feed-plan/generate",
            headers=auth_headers,
        )
        assert response.status_code == 201
        data = response.json()["data"]
        assert data["total_cost_per_day"] > 0
        assert len(data["plan"]) > 0


class TestBreeding:
    async def test_record_breeding_event(self, client, auth_headers, setup):
        _, cattle = setup
        response = await client.post(
            f"/api/v1/cattle/{cattle.id}/breeding",
            json={"event_type": "heat_detected", "date": str(date.today())},
            headers=auth_headers,
        )
        assert response.status_code == 201
        assert response.json()["data"]["event_type"] == "heat_detected"


class TestFinance:
    async def test_profit_loss(self, client, auth_headers, setup, db_session):
        farmer, _ = setup
        # Add income
        db_session.add(Transaction(
            farmer_id=farmer.id, type="income", category="milk_sale",
            amount=5000.0, date=date.today(),
        ))
        # Add expense
        db_session.add(Transaction(
            farmer_id=farmer.id, type="expense", category="feed_purchase",
            amount=2000.0, date=date.today(),
        ))
        await db_session.flush()

        response = await client.get("/api/v1/farmers/me/profit-loss?months=6", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()["data"]
        assert data["total_income"] == 5000.0
        assert data["total_expenses"] == 2000.0
        assert data["net_profit"] == 3000.0
