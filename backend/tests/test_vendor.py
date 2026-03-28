import pytest
import pytest_asyncio
from httpx import AsyncClient


class TestVendorRegistration:
    @pytest.mark.asyncio
    async def test_register_vendor(self, client: AsyncClient, vendor_headers: dict):
        resp = await client.post(
            "/api/v1/vendor/register",
            json={
                "business_name": "Sharma Milk Traders",
                "vendor_type": "milk_buyer",
                "contact_person": "Ramesh Sharma",
                "district": "Jaipur",
                "state": "Rajasthan",
            },
            headers=vendor_headers,
        )
        assert resp.status_code == 201
        data = resp.json()
        assert data["success"] is True
        assert data["data"]["business_name"] == "Sharma Milk Traders"
        assert data["data"]["vendor_type"] == "milk_buyer"
        assert data["data"]["is_verified"] is False

    @pytest.mark.asyncio
    async def test_register_vendor_duplicate(self, client: AsyncClient, vendor_headers: dict):
        await client.post(
            "/api/v1/vendor/register",
            json={"business_name": "Test Vendor", "vendor_type": "feed_supplier"},
            headers=vendor_headers,
        )
        resp = await client.post(
            "/api/v1/vendor/register",
            json={"business_name": "Test Vendor 2", "vendor_type": "feed_supplier"},
            headers=vendor_headers,
        )
        assert resp.status_code == 400

    @pytest.mark.asyncio
    async def test_farmer_cannot_access_vendor_routes(self, client: AsyncClient, auth_headers: dict):
        resp = await client.get("/api/v1/vendor/me", headers=auth_headers)
        assert resp.status_code == 403


class TestVendorProfile:
    @pytest.mark.asyncio
    async def test_get_vendor_profile(self, client: AsyncClient, vendor_headers: dict):
        await client.post(
            "/api/v1/vendor/register",
            json={"business_name": "Profile Test", "vendor_type": "milk_buyer"},
            headers=vendor_headers,
        )
        resp = await client.get("/api/v1/vendor/me", headers=vendor_headers)
        assert resp.status_code == 200
        assert resp.json()["data"]["business_name"] == "Profile Test"

    @pytest.mark.asyncio
    async def test_update_vendor_profile(self, client: AsyncClient, vendor_headers: dict):
        await client.post(
            "/api/v1/vendor/register",
            json={"business_name": "Update Test", "vendor_type": "milk_buyer"},
            headers=vendor_headers,
        )
        resp = await client.put(
            "/api/v1/vendor/me",
            json={"business_name": "Updated Name", "district": "Udaipur"},
            headers=vendor_headers,
        )
        assert resp.status_code == 200
        assert resp.json()["data"]["business_name"] == "Updated Name"
        assert resp.json()["data"]["district"] == "Udaipur"


class TestVendorDashboard:
    @pytest.mark.asyncio
    async def test_vendor_dashboard(self, client: AsyncClient, vendor_headers: dict):
        await client.post(
            "/api/v1/vendor/register",
            json={
                "business_name": "Dashboard Vendor",
                "vendor_type": "milk_buyer",
                "district": "Jaipur",
            },
            headers=vendor_headers,
        )
        resp = await client.get("/api/v1/vendor/dashboard", headers=vendor_headers)
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["profile"]["business_name"] == "Dashboard Vendor"
        assert "stats" in data
        assert "total_orders" in data["stats"]
        assert "total_revenue" in data["stats"]

    @pytest.mark.asyncio
    async def test_vendor_dashboard_no_profile(self, client: AsyncClient, vendor_headers: dict):
        resp = await client.get("/api/v1/vendor/dashboard", headers=vendor_headers)
        assert resp.status_code == 404
