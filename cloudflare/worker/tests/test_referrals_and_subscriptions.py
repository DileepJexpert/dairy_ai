"""Tests for Milterra Referrals, Recurring Subscriptions, Batch Purity Verification, and WhatsApp Alerts."""

import pytest
from api import app
from test_customer_auth import auth_client, register


BASE = "/api/v1/marketplace"
GHEE_PRODUCT_ID = "ffd7186f-6cee-4b8e-9a87-6af173aabffd"


def test_referral_program_flow(auth_client):
    client, conn = auth_client
    app.state.env.LIVE_COD_ENABLED = "true"

    # 1. Register Customer 1 (Referrer)
    res1 = register(client, phone="9876543210", username="user.one").json()
    token1 = res1["access_token"]
    client.headers["Authorization"] = f"Bearer {token1}"

    # Customer 1 gets referral code
    res_ref1 = client.get(f"{BASE}/referral/me")
    assert res_ref1.status_code == 200
    ref_data1 = res_ref1.json()["data"]
    code1 = ref_data1["referral_code"]
    assert code1 == "MILTERRA-3210"
    assert ref_data1["total_referrals_completed"] == 0

    # 2. Register Customer 2 (Referee)
    res2 = register(client, phone="9123456789", username="user.two", email="user2@example.com").json()
    token2 = res2["access_token"]
    client.headers["Authorization"] = f"Bearer {token2}"

    # Customer 2 checks own code
    res_ref2 = client.get(f"{BASE}/referral/me")
    assert res_ref2.status_code == 200
    assert res_ref2.json()["data"]["referral_code"] == "MILTERRA-6789"

    # Customer 2 cannot claim own code
    err_self = client.post(f"{BASE}/referral/claim", json={"referral_code": "MILTERRA-6789"})
    assert err_self.status_code == 400

    # Customer 2 claims Customer 1's code
    res_claim = client.post(f"{BASE}/referral/claim", json={"referral_code": code1})
    assert res_claim.status_code == 200
    assert res_claim.json()["reward_points"] == 100

    # Customer 2 loyalty balance should now be 100 points
    bal2 = client.get(f"{BASE}/loyalty/balance").json()["data"]
    assert bal2["points_balance"] == 100

    # Customer 2 cannot claim a second time
    err_twice = client.post(f"{BASE}/referral/claim", json={"referral_code": code1})
    assert err_twice.status_code == 400

    # Customer 1 loyalty balance should now also be 100 points
    client.headers["Authorization"] = f"Bearer {token1}"
    bal1 = client.get(f"{BASE}/loyalty/balance").json()["data"]
    assert bal1["points_balance"] == 100

    # Customer 1 stats show 1 referral completed
    res_ref1_updated = client.get(f"{BASE}/referral/me").json()["data"]
    assert res_ref1_updated["total_referrals_completed"] == 1
    assert res_ref1_updated["total_points_earned"] == 100


def test_recurring_subscriptions_lifecycle(auth_client):
    client, conn = auth_client
    app.state.env.LIVE_COD_ENABLED = "true"
    res = register(client, phone="9988776655", username="user.subs").json()
    token = res["access_token"]
    client.headers["Authorization"] = f"Bearer {token}"

    # 1. Create a daily subscription for Vedic Ghee
    sub_res = client.post(f"{BASE}/subscriptions", json={
        "product_id": GHEE_PRODUCT_ID,
        "frequency": "daily",
        "quantity": 1.0,
        "start_date": "2026-10-10",
        "payment_mode": "wallet_or_cod"
    })
    assert sub_res.status_code == 200
    sub_data = sub_res.json()["data"]
    sub_id = sub_data["id"]
    assert sub_data["status"] == "active"

    # 2. List customer subscriptions
    list_res = client.get(f"{BASE}/subscriptions")
    assert list_res.status_code == 200
    subs = list_res.json()["data"]
    assert len(subs) == 1
    assert subs[0]["id"] == sub_id
    assert subs[0]["frequency"] == "daily"

    # 3. Pause subscription
    pause_res = client.put(f"{BASE}/subscriptions/{sub_id}/pause", json={
        "pause_start_date": "2026-10-15",
        "pause_end_date": "2026-10-20"
    })
    assert pause_res.status_code == 200

    # Verify paused status
    subs_after_pause = client.get(f"{BASE}/subscriptions").json()["data"]
    assert subs_after_pause[0]["status"] == "paused"
    assert subs_after_pause[0]["pause_start_date"] == "2026-10-15"

    # 4. Resume subscription
    resume_res = client.put(f"{BASE}/subscriptions/{sub_id}/resume")
    assert resume_res.status_code == 200
    subs_after_resume = client.get(f"{BASE}/subscriptions").json()["data"]
    assert subs_after_resume[0]["status"] == "active"
    assert subs_after_resume[0]["pause_start_date"] is None

    # 5. Cancel subscription
    del_res = client.delete(f"{BASE}/subscriptions/{sub_id}")
    assert del_res.status_code == 200
    subs_after_cancel = client.get(f"{BASE}/subscriptions").json()["data"]
    assert subs_after_cancel[0]["status"] == "cancelled"


def test_batch_lab_purity_verification(auth_client):
    client, conn = auth_client
    app.state.env.LIVE_COD_ENABLED = "true"

    # 1. Verify default seeded batch certificate (Public lookup, no auth required)
    res = client.get(f"{BASE}/purity/verify/MIL-GHEE-2026-10")
    assert res.status_code == 200
    batch = res.json()["data"]
    assert batch["batch_number"] == "MIL-GHEE-2026-10"
    assert batch["purity_score"] >= 99.8
    assert "FSSAI" in batch["lab_name"]

    # Lookup non-existent batch
    res_404 = client.get(f"{BASE}/purity/verify/NON-EXISTENT-999")
    assert res_404.status_code == 404

    # 2. Admin adds a new batch report
    reg = register(client, phone="9111222333", username="admin.batch").json()
    token = reg["access_token"]
    client.headers["Authorization"] = f"Bearer {token}"
    cust_id = conn.execute("SELECT id FROM customers ORDER BY rowid DESC LIMIT 1").fetchone()[0]
    conn.execute("UPDATE customers SET role='admin' WHERE id=?", (cust_id,))

    new_batch_res = client.post(f"{BASE}/admin/marketplace/purity/batches", json={
        "product_id": GHEE_PRODUCT_ID,
        "batch_number": "MIL-GHEE-NOV26",
        "churn_date": "2026-11-01",
        "expiry_date": "2027-11-01",
        "purity_score": 100.0,
        "fat_percentage": 99.9,
        "snf_percentage": 0.1,
        "lab_name": "Milterra Quality Central Lab",
        "certificate_summary": "100% pure organic Vedic Bilona Ghee"
    })
    assert new_batch_res.status_code == 200

    # Public user can immediately verify the new batch
    verify_new = client.get(f"{BASE}/purity/verify/MIL-GHEE-NOV26")
    assert verify_new.status_code == 200
    assert verify_new.json()["data"]["purity_score"] == 100.0


def test_admin_whatsapp_abandoned_cart_and_dispatch(auth_client):
    client, conn = auth_client
    app.state.env.LIVE_COD_ENABLED = "true"
    reg = register(client, phone="9555666777", username="admin.whatsapp").json()
    token = reg["access_token"]
    client.headers["Authorization"] = f"Bearer {token}"
    cust_id = conn.execute("SELECT id FROM customers ORDER BY rowid DESC LIMIT 1").fetchone()[0]
    conn.execute("UPDATE customers SET role='admin' WHERE id=?", (cust_id,))

    # Add item to cart
    client.post(f"{BASE}/cart/items", json={"product_id": GHEE_PRODUCT_ID, "quantity": 2})

    # Trigger abandoned cart reminders
    cart_rem_res = client.post(f"{BASE}/admin/marketplace/whatsapp/abandoned-cart-reminders", json={
        "discount_points": 50
    })
    assert cart_rem_res.status_code == 200
    cart_rem_data = cart_rem_res.json()
    assert cart_rem_data["reminders_dispatched"] >= 1
    assert "notifications" in cart_rem_data

    # Dispatch alert with missing order -> 404
    disp_res = client.post(f"{BASE}/admin/marketplace/whatsapp/dispatch-alert", json={
        "order_id": "non-existent-order-id",
        "tracking_url": "https://milterrafoods.com/track/123",
        "delivery_partner": "Milterra Express"
    })
    assert disp_res.status_code == 404
