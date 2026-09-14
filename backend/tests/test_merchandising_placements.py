from datetime import datetime, timedelta

import pytest


pytestmark = pytest.mark.asyncio


async def _create_product(client, vendor_headers):
    registered = await client.post(
        "/api/v1/vendor/register",
        json={"business_name": "Milterra Campaign Vendor", "vendor_type": "other"},
        headers=vendor_headers,
    )
    assert registered.status_code == 201
    created = await client.post(
        "/api/v1/vendor/products",
        json={
            "sku": "CAMPAIGN-GHEE-500",
            "title": "Milterra Sahiwal Cow Ghee",
            "category": "FEED_NUTRITION",
            "base_price": "799.00",
            "compare_at_price": "899.00",
            "unit": "jar",
            "pack_size": "500 ml",
        },
        headers=vendor_headers,
    )
    assert created.status_code == 201
    return created.json()["data"]["id"]


async def test_admin_can_publish_highlight_to_public_storefront(
    client, vendor_headers, admin_headers
):
    product_id = await _create_product(client, vendor_headers)
    created = await client.post(
        "/api/v1/admin/marketplace/merchandising/placements",
        json={
            "product_id": product_id,
            "placement_type": "new_launch",
            "headline": "New launch: Sahiwal cow ghee",
            "subheadline": "Planned cultured-butter bilona process",
            "badge": "NEW LAUNCH",
            "priority": 250,
        },
        headers=admin_headers,
    )
    assert created.status_code == 201
    placement = created.json()["data"]
    assert placement["product"]["id"] == product_id
    assert placement["placement_type"] == "new_launch"

    public = await client.get("/api/v1/marketplace/merchandising/placements")
    assert public.status_code == 200
    assert public.json()["total"] == 1
    assert public.json()["data"][0]["headline"] == "New launch: Sahiwal cow ghee"


async def test_future_and_expired_placements_are_hidden(
    client, vendor_headers, admin_headers
):
    product_id = await _create_product(client, vendor_headers)
    now = datetime.utcnow()
    for headline, starts_at, ends_at in [
        ("Future", now + timedelta(days=1), now + timedelta(days=2)),
        ("Expired", now - timedelta(days=2), now - timedelta(days=1)),
    ]:
        response = await client.post(
            "/api/v1/admin/marketplace/merchandising/placements",
            json={
                "product_id": product_id,
                "headline": headline,
                "starts_at": starts_at.isoformat(),
                "ends_at": ends_at.isoformat(),
            },
            headers=admin_headers,
        )
        assert response.status_code == 201

    public = await client.get("/api/v1/marketplace/merchandising/placements")
    assert public.status_code == 200
    assert public.json()["data"] == []


async def test_only_admin_can_manage_placements(
    client, vendor_headers, auth_headers
):
    product_id = await _create_product(client, vendor_headers)
    forbidden = await client.post(
        "/api/v1/admin/marketplace/merchandising/placements",
        json={"product_id": product_id, "headline": "Not authorized"},
        headers=auth_headers,
    )
    assert forbidden.status_code == 403
