import pytest


pytestmark = pytest.mark.asyncio


async def test_visitor_can_save_concept_feedback(client, admin_headers):
    submitted = await client.post(
        "/api/v1/marketplace/concepts/feed-minera-360-1kg/feedback",
        json={
            "concept_title": "MILTERRA MINERA-360",
            "visitor_name": "Ravi Farmer",
            "phone": "9876543210",
            "message": "I need clear feeding quantity guidance for lactating cows.",
            "wants_updates": False,
        },
    )
    assert submitted.status_code == 201
    assert submitted.json()["data"]["id"]

    admin = await client.get(
        "/api/v1/admin/marketplace/concept-feedback", headers=admin_headers
    )
    assert admin.status_code == 200
    assert admin.json()["total"] == 1
    assert admin.json()["data"][0]["concept_key"] == "feed-minera-360-1kg"


async def test_update_registration_requires_contact(client):
    response = await client.post(
        "/api/v1/marketplace/concepts/feed-minera-360-1kg/feedback",
        json={
            "concept_title": "MILTERRA MINERA-360",
            "visitor_name": "Ravi Farmer",
            "wants_updates": True,
        },
    )
    assert response.status_code == 422
