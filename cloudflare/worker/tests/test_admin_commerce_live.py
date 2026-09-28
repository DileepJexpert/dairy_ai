"""Commerce acceptance at the public/admin API boundary with transactional D1 mock."""

from __future__ import annotations

import uuid

from api import app
from test_commerce import client, d1_db


BASE = "/api/v1/marketplace"


def _admin(client, db):
    db.conn.execute("UPDATE customers SET role='admin' WHERE id='user-1'")
    app.state.env.TEST_COMMERCE_ENABLED = "true"


def _order(client, db, product_id="live-review-item"):
    db.conn.execute("""INSERT INTO inventory(product_id,title,available_units,price_minor,currency,is_active)
        VALUES(?, 'Review product', 5, 10000, 'INR', 1)""", (product_id,))
    assert client.post(f"{BASE}/cart/items", json={"product_id": product_id, "quantity": 1}).status_code == 201
    result = client.post(f"{BASE}/checkout", json={"idempotency_key": str(uuid.uuid4()),
        "delivery_address_id": "addr-1", "payment_method": "cod"})
    assert result.status_code == 201, result.text
    return result.json()["data"]["id"]


def test_legacy_admin_paths_keep_role_checks(client, d1_db):
    assert client.get("/api/v1/admin/marketplace/reviews").status_code == 403
    _admin(client, d1_db)
    assert client.get("/api/v1/admin/marketplace/reviews").status_code == 200
    assert client.get("/api/v1/vendor/products").status_code == 200


def test_admin_stock_price_coupon_and_public_inventory(client, d1_db):
    _admin(client, d1_db)
    product_id = "admin-edit-product"
    d1_db.conn.execute("""INSERT INTO inventory(product_id,title,available_units,price_minor,currency,is_active)
        VALUES(?, 'Admin product', 5, 10000, 'INR', 1)""", (product_id,))
    saved = client.patch(f"{BASE}/admin/commerce/offers/{product_id}", json={
        "selling_price": 125.50, "mrp": 150, "available_stock": 3})
    assert saved.status_code == 200, saved.text
    assert d1_db.conn.execute("SELECT price_minor,available_units FROM inventory WHERE product_id=?",
        (product_id,)).fetchone() == (12550, 3)
    live = client.get(f"{BASE}/inventory").json()["data"]
    assert next(item for item in live if item["product_id"] == product_id)["price"] == 125.5
    assert client.patch(f"{BASE}/admin/commerce/offers/absent", json={"available_stock": 1}).status_code == 404

    expired = client.post(f"{BASE}/admin/commerce/coupons", json={
        "code": "OLD20", "discount_type": "percentage", "discount_value": 20,
        "valid_until": "2020-01-01T00:00:00Z"})
    assert expired.status_code == 200, expired.text
    assert client.post(f"{BASE}/cart/items", json={"product_id": product_id, "quantity": 1}).status_code == 201
    quote = client.post(f"{BASE}/checkout/quote", json={"delivery_address_id": "addr-1", "coupon_code": "OLD20"})
    assert quote.status_code == 422 and "expired" in quote.text
    row = next(c for c in client.get(f"{BASE}/admin/commerce").json()["data"]["coupons"]
        if c["code"] == "OLD20")
    assert row["id"] == "OLD20" and row["is_active"] is True
    assert client.patch(f"{BASE}/admin/commerce/coupons/OLD20", json={"is_active": False}).status_code == 200
    assert d1_db.conn.execute("SELECT is_active FROM coupons WHERE code='OLD20'").fetchone()[0] == 0
    assert client.post(f"{BASE}/admin/commerce/coupons", json={
        "code": "OVER100", "discount_type": "percentage", "discount_value": 101}).status_code == 422
    assert client.patch(f"{BASE}/admin/commerce/coupons/OLD20", json={
        "discount_value": -1}).status_code == 422
    assert client.patch(f"{BASE}/admin/commerce/coupons/OLD20", json={
        "code": "MILTERRA10"}).status_code == 409


def test_rto_restocks_once_and_blocks_delivery(client, d1_db):
    _admin(client, d1_db)
    order_id = _order(client, d1_db)
    assert client.put(f"{BASE}/orders/operations/{order_id}", json={"status": "PACKED"}).status_code == 200
    assert client.put(f"{BASE}/orders/operations/{order_id}", json={
        "status": "SHIPPED", "carrier": "Manual courier", "tracking_number": "AWB-123"}).status_code == 200
    case = client.post(f"{BASE}/orders/admin/returns/{order_id}/rto", json={"reason": "Courier marked address unreachable"})
    assert case.status_code == 201, case.text
    assert client.put(f"{BASE}/orders/operations/{order_id}", json={"status": "DELIVERED"}).status_code == 409
    assert len(client.get(f"{BASE}/orders/admin/returns").json()["data"]) == 1
    received = client.post(f"{BASE}/orders/admin/returns/{order_id}/process", json={
        "action": "confirm_received", "restock_inventory": True})
    assert received.status_code == 200, received.text
    assert d1_db.conn.execute("SELECT available_units FROM inventory WHERE product_id='live-review-item'").fetchone()[0] == 5
    assert client.post(f"{BASE}/orders/admin/returns/{order_id}/process", json={
        "action": "confirm_received", "restock_inventory": True}).status_code == 409
    assert d1_db.conn.execute("SELECT available_units FROM inventory WHERE product_id='live-review-item'").fetchone()[0] == 5
    assert client.post(f"{BASE}/orders/admin/cod/{order_id}/collect", json={
        "remittance_reference": "COD-123"}).status_code == 409


def test_delivered_review_moderation_and_certificate_persist(client, d1_db):
    _admin(client, d1_db)
    order_id = _order(client, d1_db, product_id="review-item-2")
    for update in ({"status": "PACKED"},
                   {"status": "SHIPPED", "carrier": "Manual", "tracking_number": "AWB-456"},
                   {"status": "DELIVERED"}):
        response = client.put(f"{BASE}/orders/operations/{order_id}", json=update)
        assert response.status_code == 200, response.text
    review = client.post(f"{BASE}/products/review-item-2/reviews", json={
        "order_id": order_id, "rating": 5, "content": "Carefully packed product"})
    assert review.status_code == 201, review.text
    review_id = review.json()["data"]["id"]
    assert client.get(f"{BASE}/products/review-item-2/reviews").json()["data"] == []
    legacy_reviews = client.get("/api/v1/admin/marketplace/reviews")
    assert legacy_reviews.status_code == 200, legacy_reviews.text
    assert any(item["id"] == review_id and item["status"] == "PENDING"
               for item in legacy_reviews.json()["data"])
    assert client.patch(f"/api/v1/admin/marketplace/reviews/{review_id}/moderation",
        json={"is_approved": True}).status_code == 200
    assert len(client.get(f"{BASE}/products/review-item-2/reviews").json()["data"]) == 1
    assert client.patch(f"{BASE}/admin/marketplace/reviews/absent/moderation",
        json={"is_approved": True}).status_code == 404

    certificate = client.post(f"{BASE}/admin/commerce/certificates", json={
        "product_id": "review-item-2", "batch_number": "BATCH-1",
        "test_date": "2026-09-28T00:00:00Z", "laboratory": "Test laboratory",
        "status": "PENDING_REVIEW"})
    assert certificate.status_code == 200, certificate.text
    cert_id = certificate.json()["data"]["id"]
    assert client.get(f"{BASE}/certificates").json()["data"] == []
    assert client.put(f"{BASE}/admin/commerce/certificates/{cert_id}", json={
        "product_id": "review-item-2", "batch_number": "BATCH-1",
        "test_date": "2026-09-28T00:00:00Z", "laboratory": "Test laboratory",
        "status": "CERTIFIED"}).status_code == 200
    assert len(client.get(f"{BASE}/certificates").json()["data"]) == 1


def test_family_stays_unpublished_and_otp_cannot_create_admin(client, d1_db):
    _admin(client, d1_db)
    assert client.post(f"{BASE}/vendor/families", json={
        "title": "Cannot publish", "vendor_id": "vendor-1", "is_published": True}).status_code == 422
    family = client.post(f"{BASE}/vendor/families", json={
        "title": "New oil", "vendor_id": "vendor-1", "is_published": False})
    assert family.status_code == 200, family.text
    family_id = family.json()["data"]["id"]
    assert client.post(f"{BASE}/vendor/families/{family_id}/variants", json={
        "sku": "OIL-PUBLISHED", "pack_size": "1L", "base_price": 300,
        "publication_status": "published"}).status_code == 422
    variant = client.post(f"{BASE}/vendor/families/{family_id}/variants", json={
        "sku": "OIL-NEW", "pack_size": "1L", "base_price": 300,
        "initial_stock": 4, "publication_status": "draft"})
    assert variant.status_code == 200, variant.text
    product_id = variant.json()["data"]["id"]
    assert d1_db.conn.execute("SELECT is_active FROM inventory WHERE product_id=?", (product_id,)).fetchone()[0] == 0
    assert client.get(f"{BASE}/vendor/families").json()["data"][0]["variants"][0]["id"] == product_id
    assert client.post("/api/v1/auth/verify-otp", json={
        "phone": "9839769808", "otp": "123456"}).status_code == 503
    assert client.post("/api/v1/auth/send-otp", json={"phone": "9839769808"}).status_code == 503
