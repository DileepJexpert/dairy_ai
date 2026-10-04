"""Tests for Milterra Customer Loyalty Points and Delivery Partner Point Collection System."""

import pytest
from api import app
from test_customer_auth import auth_client, register


BASE = '/api/v1/marketplace'


def test_customer_loyalty_balance_and_admin_controls(auth_client):
    client, conn = auth_client
    app.state.env.LIVE_COD_ENABLED = "true"
    
    # 1. Register customer
    registered = register(client).json()
    token = registered['access_token']
    client.headers['Authorization'] = 'Bearer ' + token

    # 2. Get initial loyalty balance
    res_bal = client.get(f"{BASE}/loyalty/balance")
    assert res_bal.status_code == 200
    data_bal = res_bal.json()["data"]
    assert data_bal["points_balance"] == 0
    assert data_bal["is_active"] is True

    # 3. Promote customer to admin for admin endpoints
    customer_id = conn.execute("SELECT id FROM customers ORDER BY rowid DESC LIMIT 1").fetchone()[0]
    conn.execute("UPDATE customers SET role='admin' WHERE id=?", (customer_id,))

    # 4. Admin manual points adjustment
    res_adj = client.post(f"{BASE}/admin/marketplace/loyalty/adjust", json={
        "customer_id": customer_id,
        "points_change": 150,
        "description": "Welcome bonus points"
    })
    assert res_adj.status_code == 200
    assert res_adj.json()["new_balance"] == 150

    # 5. Customer checks balance again
    res_bal2 = client.get(f"{BASE}/loyalty/balance")
    assert res_bal2.status_code == 200
    data_bal2 = res_bal2.json()["data"]
    assert data_bal2["points_balance"] == 150
    assert data_bal2["rupee_value"] == 150.0

    # 6. Admin updates loyalty settings
    res_set = client.put(f"{BASE}/admin/marketplace/loyalty/settings", json={
        "is_active": True,
        "earning_rate_percent": 5.0,
        "redemption_rate_minor": 100,
        "min_points_to_redeem": 20,
        "max_redeem_percent_per_order": 50.0
    })
    assert res_set.status_code == 200
    assert res_set.json()["data"]["earning_rate_percent"] == 5.0

    # 7. Admin lists customer loyalty balances
    res_cust = client.get(f"{BASE}/admin/marketplace/loyalty/customers")
    assert res_cust.status_code == 200
    assert len(res_cust.json()["data"]) >= 1


def test_delivery_partner_points_summary(auth_client):
    client, conn = auth_client
    res_points = client.get("/api/v1/delivery/partner/points", headers={"x-user-id": "milkman-101"})
    assert res_points.status_code == 200
    data = res_points.json()["data"]
    assert "total_points" in data
    assert data["milkman_id"] == "milkman-101"
