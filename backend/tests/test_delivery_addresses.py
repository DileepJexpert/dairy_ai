import uuid
from datetime import datetime, timedelta, timezone

import pytest

from app.models.user import User, UserRole
from app.services.auth_service import create_access_token
from app.api import delivery_pincode
from app.models.serviceable_pincode import ServiceablePincode


def address(**overrides) -> dict:
    data = {
        "recipient_name": "Ramesh Patel", "phone": "9999900001",
        "address_line1": "12 Dairy Road", "village_or_city": "Jaipur",
        "district": "Jaipur", "state": "Rajasthan", "postal_code": "302001",
    }
    data.update(overrides)
    return data


@pytest.mark.asyncio
async def test_first_address_becomes_default_and_can_be_listed(client, auth_headers):
    created = await client.post("/api/v1/marketplace/addresses", headers=auth_headers, json=address())
    assert created.status_code == 201
    assert created.json()["data"]["is_default"] is True
    listed = await client.get("/api/v1/marketplace/addresses", headers=auth_headers)
    assert len(listed.json()["data"]) == 1
    assert listed.json()["data"][0]["postal_code"] == "302001"


@pytest.mark.asyncio
async def test_new_default_replaces_existing_default(client, auth_headers):
    first = (await client.post("/api/v1/marketplace/addresses", headers=auth_headers, json=address())).json()["data"]
    second = (await client.post("/api/v1/marketplace/addresses", headers=auth_headers, json=address(recipient_name="Lakshmi Devi", postal_code="302002", is_default=True))).json()["data"]
    listed = (await client.get("/api/v1/marketplace/addresses", headers=auth_headers)).json()["data"]
    assert second["is_default"] is True
    assert next(item for item in listed if item["id"] == first["id"])["is_default"] is False


@pytest.mark.asyncio
async def test_update_delete_and_user_isolation(client, db_session, auth_headers):
    created = (await client.post("/api/v1/marketplace/addresses", headers=auth_headers, json=address())).json()["data"]
    updated = await client.put(f"/api/v1/marketplace/addresses/{created['id']}", headers=auth_headers, json={"landmark": "Near the dairy"})
    assert updated.status_code == 200
    assert updated.json()["data"]["landmark"] == "Near the dairy"
    other = User(id=uuid.uuid4(), phone="9999988888", role=UserRole.farmer, is_active=True, otp_expires_at=datetime.now(timezone.utc) + timedelta(minutes=5))
    db_session.add(other)
    await db_session.flush()
    other_headers = {"Authorization": f"Bearer {create_access_token(str(other.id), other.role.value)}"}
    assert (await client.delete(f"/api/v1/marketplace/addresses/{created['id']}", headers=other_headers)).status_code == 404
    assert (await client.delete(f"/api/v1/marketplace/addresses/{created['id']}", headers=auth_headers)).status_code == 200


@pytest.mark.asyncio
async def test_delivery_address_validation(client, auth_headers):
    assert (await client.post("/api/v1/marketplace/addresses", headers=auth_headers, json=address(postal_code="123"))).status_code == 422
    assert (await client.put("/api/v1/marketplace/addresses/not-a-uuid", headers=auth_headers, json={})).status_code == 400


@pytest.mark.asyncio
async def test_location_master_contains_all_states_and_state_districts(client):
    response = await client.get("/api/v1/marketplace/locations")
    assert response.status_code == 200
    states = {row["name"]: row["districts"] for row in response.json()["states"]}
    assert len(states) == 36
    assert "Gautam Buddha Nagar" in states["Uttar Pradesh"]
    assert "Jaipur" in states["Rajasthan"]


@pytest.mark.asyncio
async def test_pin_lookup_falls_back_to_delivery_master(client, db_session, monkeypatch):
    async def unavailable(pin):
        return None
    monkeypatch.setattr(delivery_pincode, "lookup_india_post_pincode", unavailable)
    db_session.add(ServiceablePincode(
        pincode="201305", city="Noida", state="Uttar Pradesh",
        is_serviceable=True,
    ))
    await db_session.flush()
    response = await client.get("/api/v1/marketplace/pincode/lookup?pincode=201305")
    assert response.status_code == 200
    assert response.json()["state"] == "Uttar Pradesh"
    assert response.json()["district"] == ""
    assert (await client.get("/api/v1/marketplace/pincode/lookup?pincode=123" )).status_code == 422
