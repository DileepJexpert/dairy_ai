import uuid
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_product_family_crud_and_draft_gating(client: AsyncClient, vendor_headers: dict, auth_headers: dict, admin_headers: dict):
    # 1. Register vendor first
    reg_resp = await client.post(
        "/api/v1/vendor/register",
        json={"business_name": "Milterra Dairy Artisans", "vendor_type": "milk_buyer"},
        headers=vendor_headers,
    )
    assert reg_resp.status_code == 201

    # 2. Public endpoint cannot post family (unauthenticated / non-vendor)
    unauth_resp = await client.post(
        "/api/v1/vendor/families",
        json={"title": "Unauthorized Ghee Family"},
        headers=auth_headers,
    )
    assert unauth_resp.status_code == 403

    # 3. Create a published product family via vendor endpoint
    create_family_resp = await client.post(
        "/api/v1/vendor/families",
        json={
            "title": "Milterra Bilona Cow Ghee",
            "brand": "MILTERRA",
            "department": "Dairy Foods",
            "collection": "Ghee",
            "milk_source": "Desi Cow Milk",
            "production_method": "Traditional Vedic Bilona",
            "description": "Authentic curd-churned Vedic bilona cow ghee.",
            "is_published": True,
        },
        headers=vendor_headers,
    )
    assert create_family_resp.status_code == 201
    family_data = create_family_resp.json()["data"]
    family_id = family_data["id"]
    family_slug = family_data["slug"]
    assert family_data["title"] == "Milterra Bilona Cow Ghee"
    assert family_data["collection"] == "Ghee"

    # 4. Add sellable pack variant (500 ml)
    var_500_resp = await client.post(
        f"/api/v1/vendor/families/{family_id}/variants",
        json={
            "sku": "MIL-GHEE-TEST-500",
            "pack_size": "500 ml",
            "base_price": "799.00",
            "compare_at_price": "950.00",
            "weight_grams": 460,
            "initial_stock": 45,
            "publication_status": "published",
        },
        headers=vendor_headers,
    )
    assert var_500_resp.status_code == 201
    var_500_data = var_500_resp.json()["data"]
    product_500_id = var_500_data["id"]
    assert var_500_data["sku"] == "MIL-GHEE-TEST-500"
    assert var_500_data["family_id"] == family_id
    assert var_500_data["in_stock"] is True
    assert var_500_data["available_quantity"] == 45

    # 5. Add a draft pack variant (250 ml trial pack)
    var_250_resp = await client.post(
        f"/api/v1/vendor/families/{family_id}/variants",
        json={
            "sku": "MIL-GHEE-TEST-250",
            "pack_size": "250 ml",
            "base_price": "425.00",
            "initial_stock": 20,
            "publication_status": "draft",
        },
        headers=vendor_headers,
    )
    assert var_250_resp.status_code == 201
    var_250_data = var_250_resp.json()["data"]
    assert var_250_data["publication_status"] == "draft"

    # 6. Public family endpoint returns family and published variants only
    pub_fam_resp = await client.get(f"/api/v1/marketplace/families/{family_slug}")
    assert pub_fam_resp.status_code == 200
    pub_fam = pub_fam_resp.json()["data"]
    assert pub_fam["id"] == family_id
    # Ensure draft variant is NOT present in public family variants
    variant_skus = [v["sku"] for v in pub_fam["variants"]]
    assert "MIL-GHEE-TEST-500" in variant_skus
    assert "MIL-GHEE-TEST-250" not in variant_skus

    # 7. Public products search endpoint also excludes draft
    pub_prods_resp = await client.get("/api/v1/marketplace/products", params={"query": "TEST"})
    assert pub_prods_resp.status_code == 200
    pub_items = pub_prods_resp.json()["data"]
    pub_skus = [p["sku"] for p in pub_items]
    assert "MIL-GHEE-TEST-500" in pub_skus
    assert "MIL-GHEE-TEST-250" not in pub_skus

    # 8. Vendor updates variant price
    edit_resp = await client.put(
        f"/api/v1/vendor/products/{product_500_id}",
        json={"base_price": "825.00", "compare_at_price": "990.00"},
        headers=vendor_headers,
    )
    assert edit_resp.status_code == 200
    assert float(edit_resp.json()["data"]["base_price"]) == 825.0

    # 9. Vendor updates inventory
    inv_resp = await client.put(
        f"/api/v1/vendor/products/{product_500_id}/inventory",
        json={"available_quantity": 0},
        headers=vendor_headers,
    )
    assert inv_resp.status_code == 200
    assert inv_resp.json()["data"]["available_quantity"] == 0

    # 10. Admin can manage vendor family as well
    admin_get_resp = await client.get(f"/api/v1/vendor/families/{family_id}", headers=admin_headers)
    assert admin_get_resp.status_code == 200
    assert admin_get_resp.json()["data"]["id"] == family_id

    # 11. Admin writes must target an explicit vendor; they must never attach
    # a new listing to an arbitrary first vendor in the database.
    missing_vendor_resp = await client.post(
        "/api/v1/vendor/families",
        json={"title": "Unscoped admin family"},
        headers=admin_headers,
    )
    assert missing_vendor_resp.status_code == 422

    scoped_admin_resp = await client.post(
        "/api/v1/vendor/families",
        json={"title": "Admin scoped family", "vendor_id": family_data["vendor_id"]},
        headers=admin_headers,
    )
    assert scoped_admin_resp.status_code == 201

    # 12. A concept family remains informational: it cannot create a stock or
    # purchasable variant through the seller API.
    concept_resp = await client.post(
        "/api/v1/vendor/families",
        json={"title": "Future Ghee Concept", "is_concept": True},
        headers=vendor_headers,
    )
    assert concept_resp.status_code == 201
    concept_id = concept_resp.json()["data"]["id"]
    concept_variant_resp = await client.post(
        f"/api/v1/vendor/families/{concept_id}/variants",
        json={"sku": "CONCEPT-GHEE-500", "pack_size": "500 ml", "base_price": "500.00"},
        headers=vendor_headers,
    )
    assert concept_variant_resp.status_code == 422
