import uuid
import pytest
import pytest_asyncio
from datetime import date, timedelta

from app.models.farmer import Farmer
from app.models.cattle import Cattle
from app.models.milk import MilkRecord, MilkPrice

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture
async def milk_setup(db_session, test_user):
    farmer = Farmer(id=uuid.uuid4(), user_id=test_user.id, name="Milk Farmer", district="Anand")
    db_session.add(farmer)
    await db_session.flush()
    cattle = Cattle(
        id=uuid.uuid4(), farmer_id=farmer.id, tag_id="MILK001",
        name="MilkCow", breed="gir", sex="female", status="active",
    )
    db_session.add(cattle)
    await db_session.flush()
    return farmer, cattle


@pytest_asyncio.fixture
async def milk_prices(db_session):
    prices = [
        MilkPrice(district="Anand", buyer_name="Amul", buyer_type="cooperative",
                   price_per_litre=35.0, fat_pct_basis=3.5, date=date.today()),
        MilkPrice(district="Anand", buyer_name="Private Dairy", buyer_type="private",
                   price_per_litre=38.0, fat_pct_basis=4.0, date=date.today()),
        MilkPrice(district="Anand", buyer_name="Local Shop", buyer_type="local",
                   price_per_litre=40.0, fat_pct_basis=4.5, date=date.today()),
    ]
    for p in prices:
        db_session.add(p)
    await db_session.flush()
    return prices


class TestMilkRecords:
    async def test_record_milk(self, client, auth_headers, milk_setup):
        _, cattle = milk_setup
        response = await client.post(
            f"/api/v1/cattle/{cattle.id}/milk-records",
            json={
                "date": str(date.today()),
                "session": "morning",
                "quantity_litres": 8.5,
                "price_per_litre": 35.0,
            },
            headers=auth_headers,
        )
        assert response.status_code == 201
        data = response.json()["data"]
        assert data["total_amount"] == 297.5  # 8.5 * 35.0


class TestMilkSummary:
    async def test_milk_summary(self, client, auth_headers, milk_setup, db_session):
        _, cattle = milk_setup
        # Add records
        for i in range(3):
            record = MilkRecord(
                cattle_id=cattle.id, date=date.today() - timedelta(days=i),
                session="morning", quantity_litres=8.0, price_per_litre=35.0, total_amount=280.0,
            )
            db_session.add(record)
        await db_session.flush()
        response = await client.get("/api/v1/farmers/me/milk-summary?days=30", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()["data"]
        assert data["total_litres"] == 24.0
        assert data["total_income"] == 840.0


class TestMilkPrices:
    async def test_district_prices(self, client, auth_headers, milk_prices):
        response = await client.get("/api/v1/milk-prices?district=Anand", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()["data"]
        assert len(data) == 3
        # Should be sorted by price desc
        assert data[0]["price_per_litre"] >= data[1]["price_per_litre"]

    async def test_best_buyer(self, client, auth_headers, milk_prices):
        response = await client.get(
            "/api/v1/milk-prices/best-buyer?district=Anand&fat_pct=4.5",
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()["data"]
        assert data["buyer_name"] == "Local Shop"
        assert data["price_per_litre"] == 40.0


class TestYieldPrediction:
    async def test_yield_prediction(self, client, auth_headers, milk_setup, db_session):
        _, cattle = milk_setup
        for i in range(7):
            record = MilkRecord(
                cattle_id=cattle.id, date=date.today() - timedelta(days=i),
                session="morning", quantity_litres=8.0 + i * 0.1,
            )
            db_session.add(record)
        await db_session.flush()
        response = await client.get(f"/api/v1/cattle/{cattle.id}/yield-prediction", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()["data"]
        assert data["predicted_yield"] > 0
        assert data["confidence"] > 0
