import pytest
import pytest_asyncio
from httpx import AsyncClient


class TestCooperativeRegistration:
    @pytest.mark.asyncio
    async def test_register_cooperative(self, client: AsyncClient, cooperative_headers: dict):
        resp = await client.post(
            "/api/v1/cooperative/register",
            json={
                "name": "Jaipur Dairy Cooperative",
                "registration_number": "COOP-RAJ-2024-001",
                "cooperative_type": "milk_collection",
                "chairman_name": "Suresh Meena",
                "district": "Jaipur",
                "state": "Rajasthan",
                "milk_price_per_litre": 35.0,
            },
            headers=cooperative_headers,
        )
        assert resp.status_code == 201
        data = resp.json()
        assert data["success"] is True
        assert data["data"]["name"] == "Jaipur Dairy Cooperative"
        assert data["data"]["cooperative_type"] == "milk_collection"
        assert data["data"]["is_verified"] is False

    @pytest.mark.asyncio
    async def test_register_cooperative_duplicate(self, client: AsyncClient, cooperative_headers: dict):
        await client.post(
            "/api/v1/cooperative/register",
            json={
                "name": "Test Coop",
                "registration_number": "COOP-001",
                "cooperative_type": "milk_collection",
            },
            headers=cooperative_headers,
        )
        resp = await client.post(
            "/api/v1/cooperative/register",
            json={
                "name": "Test Coop 2",
                "registration_number": "COOP-002",
                "cooperative_type": "dairy_processing",
            },
            headers=cooperative_headers,
        )
        assert resp.status_code == 400

    @pytest.mark.asyncio
    async def test_farmer_cannot_access_cooperative_routes(self, client: AsyncClient, auth_headers: dict):
        resp = await client.get("/api/v1/cooperative/me", headers=auth_headers)
        assert resp.status_code == 403


class TestCooperativeProfile:
    @pytest.mark.asyncio
    async def test_get_cooperative_profile(self, client: AsyncClient, cooperative_headers: dict):
        await client.post(
            "/api/v1/cooperative/register",
            json={
                "name": "Profile Coop",
                "registration_number": "COOP-PROF-001",
                "cooperative_type": "multi_purpose",
            },
            headers=cooperative_headers,
        )
        resp = await client.get("/api/v1/cooperative/me", headers=cooperative_headers)
        assert resp.status_code == 200
        assert resp.json()["data"]["name"] == "Profile Coop"

    @pytest.mark.asyncio
    async def test_update_cooperative_profile(self, client: AsyncClient, cooperative_headers: dict):
        await client.post(
            "/api/v1/cooperative/register",
            json={
                "name": "Update Coop",
                "registration_number": "COOP-UPD-001",
                "cooperative_type": "milk_collection",
            },
            headers=cooperative_headers,
        )
        resp = await client.put(
            "/api/v1/cooperative/me",
            json={"name": "Updated Coop Name", "district": "Udaipur"},
            headers=cooperative_headers,
        )
        assert resp.status_code == 200
        assert resp.json()["data"]["name"] == "Updated Coop Name"
        assert resp.json()["data"]["district"] == "Udaipur"


class TestCooperativeDashboard:
    @pytest.mark.asyncio
    async def test_cooperative_dashboard(self, client: AsyncClient, cooperative_headers: dict):
        await client.post(
            "/api/v1/cooperative/register",
            json={
                "name": "Dashboard Coop",
                "registration_number": "COOP-DASH-001",
                "cooperative_type": "milk_collection",
                "district": "Jaipur",
            },
            headers=cooperative_headers,
        )
        resp = await client.get("/api/v1/cooperative/dashboard", headers=cooperative_headers)
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["profile"]["name"] == "Dashboard Coop"
        assert "stats" in data
        assert "total_members" in data["stats"]
        assert "milk_today_litres" in data["stats"]
        assert "farmers_in_district" in data["stats"]

    @pytest.mark.asyncio
    async def test_cooperative_dashboard_no_profile(self, client: AsyncClient, cooperative_headers: dict):
        resp = await client.get("/api/v1/cooperative/dashboard", headers=cooperative_headers)
        assert resp.status_code == 404
