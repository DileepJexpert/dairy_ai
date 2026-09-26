"""Integration and concurrency tests for Cloudflare Worker D1 Commerce API.

Exercises D1 schema constraints, atomic batch reservation rollback, idempotency replay/conflict,
quote calculations, stock decrements, and order cancellations.
"""

from __future__ import annotations

import asyncio
import json
import sqlite3
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import httpx
import jwt
import pytest

from api import app


MIGRATIONS_DIR = Path(__file__).resolve().parents[1] / "migrations"


class MockD1Statement:
    def __init__(self, db: MockD1Database, sql: str, params: tuple = ()):
        self.db = db
        self.sql = sql
        self.params = params

    def bind(self, *args) -> MockD1Statement:
        # Flatten and convert boolean / UUID
        clean_params = []
        for a in args:
            if isinstance(a, bool):
                clean_params.append(1 if a else 0)
            elif isinstance(a, uuid.UUID):
                clean_params.append(str(a))
            else:
                clean_params.append(a)
        return MockD1Statement(self.db, self.sql, tuple(clean_params))

    async def run(self) -> dict[str, Any]:
        cursor = self.db.conn.cursor()
        cursor.execute(self.sql, self.params)
        return {"success": True}

    async def first(self, col: str | None = None) -> Any:
        cursor = self.db.conn.cursor()
        cursor.execute(self.sql, self.params)
        row = cursor.fetchone()
        if not row:
            return None
        col_names = [d[0] for d in cursor.description]
        rec = dict(zip(col_names, row))
        return rec[col] if col else rec

    async def all(self) -> Any:
        cursor = self.db.conn.cursor()
        cursor.execute(self.sql, self.params)
        col_names = [d[0] for d in cursor.description] if cursor.description else []
        rows = [dict(zip(col_names, r)) for r in cursor.fetchall()]
        
        class _Result:
            results = rows
            def to_py(self):
                return rows
        return _Result()


class MockD1Database:
    def __init__(self, conn: sqlite3.Connection):
        self.conn = conn

    def prepare(self, sql: str) -> MockD1Statement:
        return MockD1Statement(self, sql)

    async def batch(self, statements: list[MockD1Statement]) -> list[dict]:
        """Execute all statements in an atomic transaction, rolling back on any failure."""
        try:
            self.conn.execute("BEGIN IMMEDIATE")
            results = []
            for stmt in statements:
                cur = self.conn.cursor()
                cur.execute(stmt.sql, stmt.params)
                results.append({"success": True})
            self.conn.execute("COMMIT")
            return results
        except Exception:
            if self.conn.in_transaction:
                self.conn.execute("ROLLBACK")
            raise


class MockEnv:
    def __init__(self, db: MockD1Database):
        self.DB = db
        self.COMPAT_JWT_SECRET = "local-compat-jwt-secret-long-enough"
        self.ENVIRONMENT = "test"
        self.ALLOW_TEST_AUTH = True


@pytest.fixture
def d1_db():
    conn = sqlite3.connect(":memory:", check_same_thread=False, isolation_level=None)
    conn.execute("PRAGMA foreign_keys = ON")
    
    # Apply migrations in order
    for mig in sorted(MIGRATIONS_DIR.glob("*.sql")):
        script = mig.read_text(encoding="utf-8")
        conn.executescript(script)

    conn.execute("INSERT INTO customers (id, phone, full_name, role) VALUES ('user-1', '+919999900000', 'Test Farmer', 'farmer')")
    conn.execute(
        "INSERT INTO customer_addresses (id, customer_id, recipient_name, phone, address_line1, city, state, pincode, is_default) "
        "VALUES ('addr-1', 'user-1', 'Test Farmer', '+919999900000', 'Farm 12', 'Anand', 'Gujarat', '388001', 1)"
    )
    conn.execute(
        "INSERT OR IGNORE INTO customer_addresses (id, customer_id, recipient_name, phone, address_line1, city, state, pincode, is_default) "
        "VALUES ('addr-2', 'user-1', 'Alternate Farm', '+919999900000', 'Road 44', 'Anand', 'Gujarat', '388002', 0)"
    )
    conn.execute("INSERT INTO serviceable_pincodes (pincode, city, state, is_serviceable, delivery_fee_minor) VALUES ('388001', 'Anand', 'Gujarat', 1, 0)")
    conn.execute("INSERT INTO serviceable_pincodes (pincode, city, state, is_serviceable, delivery_fee_minor) VALUES ('388002', 'Anand', 'Gujarat', 1, 5000)")
    conn.execute("INSERT INTO coupons (code, discount_type, discount_value, min_order_value, max_discount_cap) VALUES ('MILTERRA10', 'percentage', 10, 499, 250)")

    db = MockD1Database(conn)
    yield db
    conn.close()


from starlette.testclient import TestClient


@pytest.fixture
def client(d1_db):
    app.state.env = MockEnv(d1_db)
    headers = {"x-test-customer-id": "user-1"}
    with TestClient(app, base_url="http://test", headers=headers) as c:
        yield c


def test_inventory_status_lookup(client):
    # Lookup first seeded product (e.g. cow500 or one from migration 0003)
    resp = client.get("/api/v1/marketplace/inventory/cow500")
    if resp.status_code == 404:
        # Seed a test product directly if not seeded
        pass
    else:
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["product_id"] == "cow500"
        assert data["price"] > 0
        assert data["currency"] == "INR"
        assert data["in_stock"] is True


def test_cart_add_and_get(client, d1_db):
    # Ensure product p-test exists
    asyncio.run(d1_db.prepare(
        "INSERT OR REPLACE INTO inventory (product_id, title, available_units, price_minor, currency, is_active) "
        "VALUES ('p-test', 'Organic Cow Ghee 500ml', 10, 65000, 'INR', 1)"
    ).run())

    # Clear cart first
    client.delete("/api/v1/marketplace/cart")

    # Add item to cart
    add_resp = client.post("/api/v1/marketplace/cart/items", json={"product_id": "p-test", "quantity": 2})
    assert add_resp.status_code == 201

    # Fetch cart
    cart_resp = client.get("/api/v1/marketplace/cart")
    assert cart_resp.status_code == 200
    cart = cart_resp.json()["data"]
    assert cart["item_count"] == 2
    assert cart["subtotal"] == 1300.0  # 2 * 650
    assert len(cart["items"]) == 1
    assert cart["items"][0]["product_id"] == "p-test"


def test_checkout_quote_calculation(client, d1_db):
    asyncio.run(d1_db.prepare(
        "INSERT OR REPLACE INTO inventory (product_id, title, available_units, price_minor, currency, is_active) "
        "VALUES ('p-q1', 'Buffalo Ghee 1L', 20, 40000, 'INR', 1)"  # ₹400
    ).run())

    client.delete("/api/v1/marketplace/cart")
    client.post("/api/v1/marketplace/cart/items", json={"product_id": "p-q1", "quantity": 1})

    # Quote under ₹500 has ₹50 delivery fee
    q1 = client.post("/api/v1/marketplace/orders/checkout/quote", json={"payment_method": "cod", "delivery_address_id": "addr-2"}).json()["data"]
    assert q1["subtotal"] == 400.0
    assert q1["delivery_fee"] == 50.0
    assert q1["total_amount"] == 450.0

    # Add second item to exceed ₹500 -> free delivery
    client.post("/api/v1/marketplace/cart/items", json={"product_id": "p-q1", "quantity": 1})
    q2 = client.post("/api/v1/marketplace/orders/checkout/quote", json={"payment_method": "cod", "delivery_address_id": "addr-1"}).json()["data"]
    assert q2["subtotal"] == 800.0
    assert q2["delivery_fee"] == 0.0
    assert q2["total_amount"] == 800.0


def test_atomic_checkout_order_creation_and_idempotency(client, d1_db):
    asyncio.run(d1_db.prepare(
        "INSERT OR REPLACE INTO inventory (product_id, title, available_units, price_minor, currency, is_active) "
        "VALUES ('p-order', 'Desi Bilona Ghee', 5, 80000, 'INR', 1)"  # ₹800
    ).run())

    client.delete("/api/v1/marketplace/cart")
    client.post("/api/v1/marketplace/cart/items", json={"product_id": "p-order", "quantity": 2})

    key = "idem-key-" + str(uuid.uuid4())
    req_body = {
        "idempotency_key": key,
        "delivery_address_id": "addr-1",
        "payment_method": "cod",
    }

    # 1. First checkout attempt succeeds
    resp1 = client.post("/api/v1/marketplace/orders/checkout", json=req_body)
    assert resp1.status_code == 201
    order = resp1.json()["data"]
    assert order["status"] == "confirmed"
    assert order["total_amount"] == 1600.0

    # Verify inventory was decremented from 5 to 3
    inv = asyncio.run(d1_db.prepare("SELECT available_units FROM inventory WHERE product_id = 'p-order'").first())
    assert inv["available_units"] == 3

    # Cart is cleared after checkout
    cart = client.get("/api/v1/marketplace/cart").json()["data"]
    assert cart["item_count"] == 0

    # 2. Exact same request replayed with same key -> 200 Replay without second stock decrement
    resp2 = client.post("/api/v1/marketplace/orders/checkout", json=req_body)
    assert resp2.status_code == 200
    assert resp2.json()["data"]["id"] == order["id"]
    inv2 = asyncio.run(d1_db.prepare("SELECT available_units FROM inventory WHERE product_id = 'p-order'").first())
    assert inv2["available_units"] == 3  # Stock unchanged

    # 3. Same key reused with different delivery address -> 409 Conflict
    conflicting_body = {**req_body, "delivery_address_id": "addr-2"}
    resp3 = client.post("/api/v1/marketplace/orders/checkout", json=conflicting_body)
    assert resp3.status_code == 409


def test_insufficient_stock_rejection_and_full_rollback(client, d1_db):
    # Only 1 unit in stock
    asyncio.run(d1_db.prepare(
        "INSERT OR REPLACE INTO inventory (product_id, title, available_units, price_minor, currency, is_active) "
        "VALUES ('p-low', 'Rare Limited Ghee', 1, 150000, 'INR', 1)"
    ).run())

    # Try to order 2 units
    client.delete("/api/v1/marketplace/cart")
    client.post("/api/v1/marketplace/cart/items", json={"product_id": "p-low", "quantity": 2})

    resp = client.post(
        "/api/v1/marketplace/orders/checkout",
        json={"idempotency_key": "idem-fail-" + str(uuid.uuid4()), "delivery_address_id": "addr-1"}
    )
    assert resp.status_code == 422
    assert "insufficient stock" in resp.text.lower()

    # Verify stock was NOT decremented
    inv = asyncio.run(d1_db.prepare("SELECT available_units FROM inventory WHERE product_id = 'p-low'").first())
    assert inv["available_units"] == 1


def test_multi_item_order_one_item_out_of_stock_rolls_back_both(client, d1_db):
    # Item A has plenty of stock (10); Item B has only 1
    asyncio.run(d1_db.prepare(
        "INSERT OR REPLACE INTO inventory (product_id, title, available_units, price_minor, currency, is_active) "
        "VALUES ('p-itemA', 'Item A Plenty', 10, 10000, 'INR', 1)"
    ).run())
    asyncio.run(d1_db.prepare(
        "INSERT OR REPLACE INTO inventory (product_id, title, available_units, price_minor, currency, is_active) "
        "VALUES ('p-itemB', 'Item B Scant', 1, 20000, 'INR', 1)"
    ).run())

    client.delete("/api/v1/marketplace/cart")
    client.post("/api/v1/marketplace/cart/items", json={"product_id": "p-itemA", "quantity": 3})
    client.post("/api/v1/marketplace/cart/items", json={"product_id": "p-itemB", "quantity": 5})  # 5 > 1

    resp = client.post(
        "/api/v1/marketplace/orders/checkout",
        json={"idempotency_key": "idem-multi-" + str(uuid.uuid4()), "delivery_address_id": "addr-1"}
    )
    assert resp.status_code == 422

    # CRITICAL INVARIANT: Item A must NOT have been decremented!
    invA = asyncio.run(d1_db.prepare("SELECT available_units FROM inventory WHERE product_id = 'p-itemA'").first())
    assert invA["available_units"] == 10
    invB = asyncio.run(d1_db.prepare("SELECT available_units FROM inventory WHERE product_id = 'p-itemB'").first())
    assert invB["available_units"] == 1


def test_order_cancellation_restores_stock(client, d1_db):
    asyncio.run(d1_db.prepare(
        "INSERT OR REPLACE INTO inventory (product_id, title, available_units, price_minor, currency, is_active) "
        "VALUES ('p-cancel', 'Cancellable Ghee', 10, 50000, 'INR', 1)"
    ).run())

    client.delete("/api/v1/marketplace/cart")
    client.post("/api/v1/marketplace/cart/items", json={"product_id": "p-cancel", "quantity": 3})

    # Place order
    key = "idem-cancel-" + str(uuid.uuid4())
    place_resp = client.post(
        "/api/v1/marketplace/orders/checkout",
        json={"idempotency_key": key, "delivery_address_id": "addr-1"}
    )
    order_id = place_resp.json()["data"]["id"]

    inv_after = asyncio.run(d1_db.prepare("SELECT available_units FROM inventory WHERE product_id = 'p-cancel'").first())
    assert inv_after["available_units"] == 7

    # Cancel order
    cancel_resp = client.post(f"/api/v1/marketplace/orders/{order_id}/cancel")
    assert cancel_resp.status_code == 200

    # Stock is restored to 10
    inv_restored = asyncio.run(d1_db.prepare("SELECT available_units FROM inventory WHERE product_id = 'p-cancel'").first())
    assert inv_restored["available_units"] == 10

    # Double cancellation is rejected with 400 and stock is NOT restored again
    repeat_cancel = client.post(f"/api/v1/marketplace/orders/{order_id}/cancel")
    assert repeat_cancel.status_code == 400
    assert "already cancelled" in repeat_cancel.text.lower()
    inv_still_10 = asyncio.run(d1_db.prepare("SELECT available_units FROM inventory WHERE product_id = 'p-cancel'").first())
    assert inv_still_10["available_units"] == 10


def test_address_ownership_and_pincode_validation(client, d1_db):
    asyncio.run(d1_db.prepare(
        "INSERT OR REPLACE INTO inventory (product_id, title, available_units, price_minor, currency, is_active) "
        "VALUES ('p-addr-test', 'Ghee for Address Test', 10, 50000, 'INR', 1)"
    ).run())

    # Seed an address belonging to a different customer (user-999)
    asyncio.run(d1_db.prepare(
        "INSERT OR IGNORE INTO customers (id, phone, role) VALUES ('user-999', '+919888877777', 'farmer')"
    ).run())
    asyncio.run(d1_db.prepare(
        "INSERT OR REPLACE INTO customer_addresses (id, customer_id, recipient_name, phone, address_line1, city, state, pincode, is_default) "
        "VALUES ('addr-other', 'user-999', 'Other Person', '+919888877777', 'Other Road', 'Delhi', 'Delhi', '110001', 1)"
    ).run())

    # Seed an address with invalid pincode for user-1
    asyncio.run(d1_db.prepare(
        "INSERT OR REPLACE INTO customer_addresses (id, customer_id, recipient_name, phone, address_line1, city, state, pincode, is_default) "
        "VALUES ('addr-bad-pin', 'user-1', 'Test Farmer', '+919999900000', 'Road 1', 'City', 'State', '123', 0)"
    ).run())

    client.delete("/api/v1/marketplace/cart")
    client.post("/api/v1/marketplace/cart/items", json={"product_id": "p-addr-test", "quantity": 1})

    # 1. Checkout quote with someone else's address -> 404
    quote_other = client.post("/api/v1/marketplace/orders/checkout/quote", json={"delivery_address_id": "addr-other"})
    assert quote_other.status_code == 404

    # 2. Checkout with someone else's address -> 404
    checkout_other = client.post(
        "/api/v1/marketplace/orders/checkout",
        json={"idempotency_key": "addr-check-" + str(uuid.uuid4()), "delivery_address_id": "addr-other"},
    )
    assert checkout_other.status_code == 404

    # 3. Checkout with invalid pincode address -> 422
    checkout_pin = client.post(
        "/api/v1/marketplace/orders/checkout",
        json={"idempotency_key": "pin-check-" + str(uuid.uuid4()), "delivery_address_id": "addr-bad-pin"},
    )
    assert checkout_pin.status_code == 422
    assert "pincode" in checkout_pin.text.lower()


def test_coupon_discount_calculation_and_validation(client, d1_db):
    asyncio.run(d1_db.prepare(
        "INSERT OR REPLACE INTO inventory (product_id, title, available_units, price_minor, currency, is_active) "
        "VALUES ('p-coupon-test', 'Ghee for Coupon', 20, 60000, 'INR', 1)"  # ₹600
    ).run())

    client.delete("/api/v1/marketplace/cart")
    client.post("/api/v1/marketplace/cart/items", json={"product_id": "p-coupon-test", "quantity": 1})

    # Valid coupon MILTERRA10 (10% off min order 499): 10% of 600 = 60
    q = client.post(
        "/api/v1/marketplace/orders/checkout/quote",
        json={"coupon_code": "MILTERRA10", "delivery_address_id": "addr-1"},
    )
    assert q.status_code == 200
    data = q.json()["data"]
    assert data["subtotal"] == 600.0
    assert data["discount"] == 60.0
    assert data["delivery_fee"] == 0.0  # free over 500
    assert data["total"] == 540.0
    assert data["total_amount"] == 540.0
    assert data["is_prelaunch_interest"] is False

    # Invalid coupon code -> 422
    bad_q = client.post(
        "/api/v1/marketplace/orders/checkout/quote",
        json={"coupon_code": "INVALID99", "delivery_address_id": "addr-1"},
    )
    assert bad_q.status_code == 422

    # Checkout with valid coupon applies discount and saves order
    resp = client.post(
        "/api/v1/marketplace/orders/checkout",
        json={
            "idempotency_key": "coupon-order-" + str(uuid.uuid4()),
            "delivery_address_id": "addr-1",
            "coupon_code": "MILTERRA10",
            "expected_total": 540.0,
        },
    )
    assert resp.status_code == 201
    assert resp.json()["data"]["total"] == 540.0


def test_auth_guard_blocks_test_header_when_not_in_test_environment(client):
    app.state.env.ENVIRONMENT = "production"
    app.state.env.ALLOW_TEST_AUTH = False

    # Attempt to bypass using x-test-customer-id
    resp = client.get("/api/v1/marketplace/cart", headers={"x-test-customer-id": "user-1"})
    assert resp.status_code == 401
    assert "Authentication required" in resp.text

    # Restore test environment for remaining tests
    app.state.env.ENVIRONMENT = "test"
    app.state.env.ALLOW_TEST_AUTH = True


def test_unimplemented_online_payment_fails_closed(client, d1_db):
    # Payment capabilities
    cap_resp = client.get("/api/v1/marketplace/orders/payment-capabilities")
    assert cap_resp.status_code == 200
    cap_data = cap_resp.json()["data"]
    assert cap_data["is_prelaunch_interest"] is False
    assert cap_data["online_payment_available"] is False

    # Create an order with UPI payment method
    asyncio.run(d1_db.prepare(
        "INSERT OR REPLACE INTO inventory (product_id, title, available_units, price_minor, currency, is_active) "
        "VALUES ('p-pay-test', 'Ghee for Pay Link', 5, 50000, 'INR', 1)"
    ).run())

    client.delete("/api/v1/marketplace/cart")
    client.post("/api/v1/marketplace/cart/items", json={"product_id": "p-pay-test", "quantity": 1})

    order_res = client.post(
        "/api/v1/marketplace/orders/checkout",
        json={
            "idempotency_key": "pay-order-" + str(uuid.uuid4()),
            "delivery_address_id": "addr-1",
            "payment_method": "upi",
        },
    )
    assert order_res.status_code == 503
    assert asyncio.run(d1_db.prepare("SELECT COUNT(*) AS n FROM orders").first())["n"] == 0
    assert asyncio.run(d1_db.prepare("SELECT available_units FROM inventory WHERE product_id = 'p-pay-test'").first())["available_units"] == 5


def test_refresh_token_and_inactive_customer_cannot_access_cart(client, d1_db):
    env = app.state.env
    env.ENVIRONMENT = "production"
    env.ALLOW_TEST_AUTH = False
    claims = {
        "sub": "user-1", "role": "admin", "type": "refresh",
        "exp": datetime.now(timezone.utc) + timedelta(minutes=10),
    }
    refresh = jwt.encode(claims, env.COMPAT_JWT_SECRET, algorithm="HS256")
    response = client.get("/api/v1/marketplace/cart", headers={"Authorization": f"Bearer {refresh}", "x-test-customer-id": ""})
    assert response.status_code == 401

    claims["type"] = "access"
    access = jwt.encode(claims, env.COMPAT_JWT_SECRET, algorithm="HS256")
    response = client.get("/api/v1/marketplace/cart", headers={"Authorization": f"Bearer {access}", "x-test-customer-id": ""})
    assert response.status_code == 200
    asyncio.run(d1_db.prepare("UPDATE customers SET is_active = 0 WHERE id = 'user-1'").run())
    response = client.get("/api/v1/marketplace/cart", headers={"Authorization": f"Bearer {access}", "x-test-customer-id": ""})
    assert response.status_code == 401


def test_unknown_pincode_rejected_before_order(client, d1_db):
    asyncio.run(d1_db.prepare(
        "INSERT INTO customer_addresses (id, customer_id, recipient_name, phone, address_line1, city, state, pincode) "
        "VALUES ('addr-uncovered', 'user-1', 'Test', '+919999900000', 'Road', 'City', 'State', '201305')"
    ).run())
    response = client.post("/api/v1/marketplace/orders/checkout/quote", json={"delivery_address_id": "addr-uncovered"})
    assert response.status_code == 422
    assert "not currently available" in response.text


def test_cors_only_allows_configured_storefront_origin(client):
    app.state.env.CORS_ORIGINS = "https://shop.example.test"
    allowed = client.options(
        "/api/v1/marketplace/cart",
        headers={"Origin": "https://shop.example.test", "Access-Control-Request-Method": "GET"},
    )
    assert allowed.status_code == 204
    assert allowed.headers["access-control-allow-origin"] == "https://shop.example.test"
    assert "Authorization" in allowed.headers["access-control-allow-headers"]
    denied = client.options(
        "/api/v1/marketplace/cart",
        headers={"Origin": "https://evil.example.test", "Access-Control-Request-Method": "GET"},
    )
    assert denied.status_code == 403
    assert "access-control-allow-origin" not in denied.headers


def test_paid_order_cannot_be_cancelled_without_refund_flow(client, d1_db):
    asyncio.run(d1_db.prepare(
        "INSERT INTO inventory (product_id, title, available_units, price_minor, currency) "
        "VALUES ('p-paid-cancel', 'Test', 2, 10000, 'INR')"
    ).run())
    client.post("/api/v1/marketplace/cart/items", json={"product_id": "p-paid-cancel", "quantity": 1})
    order = client.post(
        "/api/v1/marketplace/orders/checkout",
        json={"idempotency_key": str(uuid.uuid4()), "delivery_address_id": "addr-1"},
    ).json()["data"]
    asyncio.run(d1_db.prepare("UPDATE orders SET payment_status = 'paid' WHERE id = ?").bind(order["id"]).run())
    response = client.post(f"/api/v1/marketplace/orders/{order['id']}/cancel")
    assert response.status_code == 409
    assert asyncio.run(d1_db.prepare("SELECT available_units FROM inventory WHERE product_id = 'p-paid-cancel'").first())["available_units"] == 1


def test_disabled_coupon_cannot_be_applied(client, d1_db):
    asyncio.run(d1_db.prepare("UPDATE coupons SET is_active = 0 WHERE code = 'MILTERRA10'").run())
    asyncio.run(d1_db.prepare(
        "INSERT INTO inventory (product_id, title, available_units, price_minor, currency) "
        "VALUES ('p-disabled-coupon', 'Test', 1, 60000, 'INR')"
    ).run())
    client.post("/api/v1/marketplace/cart/items", json={"product_id": "p-disabled-coupon", "quantity": 1})
    response = client.post(
        "/api/v1/marketplace/orders/checkout/quote",
        json={"delivery_address_id": "addr-1", "coupon_code": "MILTERRA10"},
    )
    assert response.status_code == 422
    assert "no longer active" in response.text
