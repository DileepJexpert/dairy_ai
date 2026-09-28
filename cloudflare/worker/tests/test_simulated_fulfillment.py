"""End-to-end test-order lifecycle without a courier, cash, or bank transfer."""

import sqlite3
import uuid

import pytest

from api import app
from test_commerce import client, d1_db


BASE = "/api/v1/marketplace"


def _enable(client, db):
    app.state.env.TEST_COMMERCE_ENABLED = "true"
    app.state.env.SIMULATION_ENABLED = "true"
    db.conn.execute("UPDATE customers SET role='admin' WHERE id='user-1'")


def _place(client, db, product_id):
    db.conn.execute("""INSERT INTO inventory(product_id,title,available_units,price_minor,currency,is_active)
        VALUES(?, 'Simulation item', 5, 10000, 'INR', 1)""", (product_id,))
    assert client.post(f"{BASE}/cart/items", json={"product_id": product_id, "quantity": 2}).status_code == 201
    result = client.post(f"{BASE}/checkout", json={
        "idempotency_key": str(uuid.uuid4()), "delivery_address_id": "addr-1", "payment_method": "cod"})
    assert result.status_code == 201, result.text
    assert result.json()["data"]["is_test_order"] is True
    return result.json()["data"]["id"]


def _ship_and_deliver(client, order_id):
    assert client.put(f"{BASE}/orders/operations/{order_id}", json={"status": "PACKED"}).status_code == 200
    dispatch = client.post(f"{BASE}/orders/admin/simulator/{order_id}/dispatch")
    assert dispatch.status_code == 200, dispatch.text
    assert dispatch.json()["data"]["tracking_number"].startswith("SIM-AWB-")
    for event in ("OUT_FOR_DELIVERY", "DELIVERED"):
        result = client.post(f"{BASE}/orders/admin/simulator/{order_id}/event", json={"event": event})
        assert result.status_code == 200, result.text


def test_unpaid_cod_cancellation_restores_stock_without_refund(client, d1_db):
    _enable(client, d1_db)
    order_id = _place(client, d1_db, "sim-cancel")
    assert d1_db.conn.execute("SELECT available_units FROM inventory WHERE product_id='sim-cancel'").fetchone()[0] == 3
    cancelled = client.post(f"{BASE}/orders/{order_id}/cancel")
    assert cancelled.status_code == 200
    assert cancelled.json()["data"]["status"] == "CANCELLED"
    assert cancelled.json()["data"]["payment_status"] == "PENDING"
    assert d1_db.conn.execute("SELECT available_units FROM inventory WHERE product_id='sim-cancel'").fetchone()[0] == 5
    assert client.get(f"{BASE}/orders/admin/simulator/{order_id}/ledger").json()["data"] == []
    assert client.post(f"{BASE}/orders/admin/simulator/{order_id}/dispatch").status_code == 409


def test_simulated_delivery_collection_return_and_refund(client, d1_db):
    _enable(client, d1_db)
    order_id = _place(client, d1_db, "sim-refund")
    _ship_and_deliver(client, order_id)
    assert client.post(f"{BASE}/orders/{order_id}/cancel").status_code == 400
    collection = client.post(f"{BASE}/orders/admin/simulator/{order_id}/collect")
    assert collection.status_code == 200, collection.text
    assert collection.json()["simulated"] is True
    assert collection.json()["data"]["payment_status"] == "PAID"
    assert client.post(f"{BASE}/orders/admin/simulator/{order_id}/collect").status_code == 409
    case = client.post(f"{BASE}/orders/{order_id}/return-request", json={"reason": "I changed my mind"})
    assert case.status_code == 201, case.text
    refund = client.post(f"{BASE}/orders/admin/simulator/{order_id}/refund", json={
        "restock_inventory": True, "remarks": "Test parcel received"})
    assert refund.status_code == 200, refund.text
    assert refund.json()["simulated"] is True
    assert refund.json()["data"]["payment_status"] == "REFUNDED"
    assert client.post(f"{BASE}/orders/admin/simulator/{order_id}/refund", json={}).status_code == 409
    ledger = client.get(f"{BASE}/orders/admin/simulator/{order_id}/ledger")
    assert ledger.status_code == 200
    rows = ledger.json()["data"]
    assert [row["kind"] for row in rows] == ["cod_collection", "cod_refund"]
    assert rows[0]["amount_minor"] == rows[1]["amount_minor"] == 20000
    assert all(row["reference"].startswith("SIM-") for row in rows)
    assert d1_db.conn.execute("SELECT available_units FROM inventory WHERE product_id='sim-refund'").fetchone()[0] == 5
    titles = [item["title"] for item in refund.json()["data"]["timeline"]]
    assert any("[SIMULATED]" in title for title in titles)


def test_delivery_failure_uses_existing_rto_flow(client, d1_db):
    _enable(client, d1_db)
    order_id = _place(client, d1_db, "sim-rto")
    assert client.put(f"{BASE}/orders/operations/{order_id}", json={"status": "PACKED"}).status_code == 200
    assert client.post(f"{BASE}/orders/admin/simulator/{order_id}/dispatch").status_code == 200
    failure = client.post(f"{BASE}/orders/admin/simulator/{order_id}/event", json={
        "event": "DELIVERY_FAILED", "reason": "Address unavailable"})
    assert failure.status_code == 200, failure.text
    assert client.post(f"{BASE}/orders/admin/simulator/{order_id}/event", json={"event": "DELIVERED"}).status_code == 409
    assert client.post(f"{BASE}/orders/admin/cod/{order_id}/collect", json={
        "remittance_reference": "real-looking-reference"}).status_code == 409
    received = client.post(f"{BASE}/orders/admin/returns/{order_id}/process", json={
        "action": "confirm_received", "restock_inventory": True})
    assert received.status_code == 200, received.text
    assert d1_db.conn.execute("SELECT available_units FROM inventory WHERE product_id='sim-rto'").fetchone()[0] == 5
    assert client.get(f"{BASE}/orders/admin/simulator/{order_id}/ledger").json()["data"] == []


def test_simulator_is_hidden_unless_explicitly_isolated(client, d1_db):
    _enable(client, d1_db)
    order_id = _place(client, d1_db, "sim-guard")
    path = f"{BASE}/orders/admin/simulator/{order_id}/dispatch"
    app.state.env.SIMULATION_ENABLED = "false"
    assert client.post(path).status_code == 404
    app.state.env.SIMULATION_ENABLED = "true"
    app.state.env.TEST_COMMERCE_ENABLED = "false"
    assert client.post(path).status_code == 404
    app.state.env.TEST_COMMERCE_ENABLED = "true"
    app.state.env.LIVE_COD_ENABLED = "true"
    assert client.post(path).status_code == 404
    app.state.env.LIVE_COD_ENABLED = "false"
    app.state.env.ENVIRONMENT = "production"
    assert client.post(path).status_code == 404
    app.state.env.ENVIRONMENT = "test"
    d1_db.conn.execute("UPDATE customers SET role='farmer' WHERE id='user-1'")
    assert client.post(path).status_code == 403


def test_simulated_collection_is_atomic_when_ledger_write_fails(client, d1_db):
    _enable(client, d1_db)
    order_id = _place(client, d1_db, "sim-atomic")
    _ship_and_deliver(client, order_id)
    d1_db.conn.execute("""CREATE TRIGGER break_test_movement BEFORE INSERT ON simulated_money_movements
        BEGIN SELECT RAISE(ABORT, 'test ledger failure'); END""")
    with pytest.raises(sqlite3.IntegrityError, match="test ledger failure"):
        client.post(f"{BASE}/orders/admin/simulator/{order_id}/collect")
    state = d1_db.conn.execute("SELECT payment_status,remittance_reference FROM orders WHERE id=?", (order_id,)).fetchone()
    assert state == ("pending", None)
    assert d1_db.conn.execute("SELECT COUNT(*) FROM simulated_money_movements").fetchone()[0] == 0


def test_customer_and_admin_use_separate_accounts(client, d1_db):
    app.state.env.TEST_COMMERCE_ENABLED = "true"
    app.state.env.SIMULATION_ENABLED = "true"
    d1_db.conn.execute("""INSERT INTO customers(id,phone,full_name,role)
        VALUES('staff-1','+919999900111','Store admin','admin')""")
    admin_headers = {"x-test-customer-id": "staff-1"}
    order_id = _place(client, d1_db, "sim-roles")
    assert client.post(f"{BASE}/orders/admin/simulator/{order_id}/dispatch").status_code == 403
    assert client.put(f"{BASE}/orders/operations/{order_id}", json={"status": "PACKED"},
        headers=admin_headers).status_code == 200
    dispatched = client.post(f"{BASE}/orders/admin/simulator/{order_id}/dispatch",
        headers=admin_headers)
    assert dispatched.status_code == 200, dispatched.text
    assert client.get(f"{BASE}/orders/{order_id}").json()["data"]["tracking_number"].startswith("SIM-AWB-")
    assert client.get(f"{BASE}/orders/admin/simulator/{order_id}/ledger").status_code == 403
    assert client.get(f"{BASE}/orders/admin/simulator/{order_id}/ledger", headers=admin_headers).status_code == 200


def test_real_order_cannot_be_simulated_even_when_test_switch_is_enabled(client, d1_db):
    _enable(client, d1_db)
    order_id = _place(client, d1_db, "sim-real-guard")
    d1_db.conn.execute("UPDATE orders SET is_test_order=0 WHERE id=?", (order_id,))
    assert client.post(f"{BASE}/orders/admin/simulator/{order_id}/dispatch").status_code == 404
    assert client.get(f"{BASE}/orders/admin/simulator/{order_id}/ledger").status_code == 404
