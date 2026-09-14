import pytest


pytestmark = pytest.mark.asyncio


async def test_public_product_feedback_is_persisted_and_listed(
    client, vendor_headers
):
    registered = await client.post(
        "/api/v1/vendor/register",
        json={"business_name": "Milterra Review Vendor", "vendor_type": "other"},
        headers=vendor_headers,
    )
    assert registered.status_code == 201

    created = await client.post(
        "/api/v1/vendor/products",
        json={
            "sku": "REVIEW-GHEE-500",
            "title": "Milterra Review Ghee",
            "category": "FEED_NUTRITION",
            "base_price": "799.00",
            "unit": "jar",
            "pack_size": "500 ml",
        },
        headers=vendor_headers,
    )
    assert created.status_code == 201
    product_id = created.json()["data"]["id"]

    submitted = await client.post(
        f"/api/v1/marketplace/products/{product_id}/reviews",
        json={
            "author_name": "Asha Singh",
            "rating": 5,
            "headline": "Interested in the launch",
            "content": "The presentation looks premium and I would try this after launch.",
        },
    )
    assert submitted.status_code == 201
    saved = submitted.json()["data"]
    assert saved["author_name"] == "Asha Singh"
    assert saved["source_label"] == "Visitor feedback"
    assert saved["is_seeded"] is False

    listed = await client.get(
        f"/api/v1/marketplace/products/{product_id}/reviews"
    )
    assert listed.status_code == 200
    assert listed.json()["total"] == 1
    assert listed.json()["data"][0]["headline"] == "Interested in the launch"


async def test_product_feedback_validates_rating_and_product(client):
    invalid_rating = await client.post(
        "/api/v1/marketplace/products/00000000-0000-0000-0000-000000000000/reviews",
        json={
            "author_name": "Test Visitor",
            "rating": 6,
            "headline": "Invalid score",
            "content": "This feedback should never be accepted by the API.",
        },
    )
    assert invalid_rating.status_code == 422

    missing = await client.get(
        "/api/v1/marketplace/products/00000000-0000-0000-0000-000000000000/reviews"
    )
    assert missing.status_code == 404
