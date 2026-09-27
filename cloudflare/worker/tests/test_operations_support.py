"""Tests for seller COD operations, tracking timeline, customer support, and delivery coverage."""
import asyncio
import uuid
import httpx

from api import app
from test_customer_auth import auth_client, register


def test_operations_support_and_coverage(auth_client):
    client, conn = auth_client
    pair = register(client).json()
    farmer_headers = {"Authorization": "Bearer " + pair["access_token"]}
    client.headers["Authorization"] = "Bearer " + pair["access_token"]
    app.state.env.TEST_COMMERCE_ENABLED = "true"
    app.state.env.ENVIRONMENT = "staging"

    # 1. Customer Support & Store Help
    help_resp = client.get("/api/v1/marketplace/help")
    assert help_resp.status_code == 200, help_resp.text
    help_data = help_resp.json()["data"]
    assert "faqs" in help_data
    assert len(help_data["faqs"]) > 0

    ticket_resp = client.post("/api/v1/marketplace/support", json={
        "subject": "Delivery enquiry",
        "message": "When will my organic cow ghee order be delivered to Noida?",
    })
    assert ticket_resp.status_code == 201, ticket_resp.text
    ticket = ticket_resp.json()["data"]
    assert ticket["status"] == "OPEN"
    assert ticket["subject"] == "Delivery enquiry"

    my_tickets = client.get("/api/v1/marketplace/support")
    assert my_tickets.status_code == 200
    assert len(my_tickets.json()["data"]) == 1

    # Security check: Customer with role 'farmer' CANNOT access admin support or help
    farmer_admin_support = client.get("/api/v1/marketplace/admin/support")
    assert farmer_admin_support.status_code == 403, "Farmers must not access admin support"

    farmer_admin_help = client.put("/api/v1/marketplace/admin/help", json={"test": "data"})
    assert farmer_admin_help.status_code == 403, "Farmers must not overwrite store help"

    # Register an admin user for operational tasks
    admin_pair = register(client, phone="9999900000", username="ops.admin", email="admin@milterrafoods.com").json()
    conn.execute("UPDATE customers SET role='admin' WHERE phone='9999900000'")
    admin_headers = {"Authorization": "Bearer " + admin_pair["access_token"]}

    # Admin CAN access admin support and reply
    admin_tickets = client.get("/api/v1/marketplace/admin/support", headers=admin_headers)
    assert admin_tickets.status_code == 200
    assert len(admin_tickets.json()["data"]) >= 1
    assert "customer_phone" in admin_tickets.json()["data"][0]

    reply_resp = client.patch(f"/api/v1/marketplace/admin/support/{ticket['id']}", json={
        "status": "IN_PROGRESS",
        "reply": "Your order is being prepared and will be dispatched tomorrow.",
    }, headers=admin_headers)
    assert reply_resp.status_code == 200
    assert reply_resp.json()["data"]["status"] == "IN_PROGRESS"
    assert "dispatched tomorrow" in reply_resp.json()["data"]["reply"]

    # 2. Serviceable Pincodes Coverage & Lookup
    conn.execute("INSERT OR REPLACE INTO serviceable_pincodes (pincode, city, state, is_serviceable, delivery_fee_minor, delivery_days_min, delivery_days_max) VALUES ('110001', 'New Delhi', 'Delhi', 1, 4000, 1, 2)")
    conn.execute("INSERT OR REPLACE INTO serviceable_pincodes (pincode, city, state, is_serviceable, delivery_fee_minor, delivery_days_min, delivery_days_max) VALUES ('201305', 'Noida', 'Uttar Pradesh', 1, 0, 1, 2)")

    delhi_check = client.get("/api/v1/marketplace/pincode/check?pincode=110001")
    assert delhi_check.status_code == 200
    assert delhi_check.json()["is_serviceable"] is True
    assert delhi_check.json()["delivery_fee"] == 40.0

    delhi_lookup = client.get("/api/v1/marketplace/pincode/lookup?pincode=110001")
    assert delhi_lookup.status_code == 200
    assert delhi_lookup.json()["state"] == "Delhi"

    # 3. Order Placement with Initial Event (placed by farmer)
    client.headers["Authorization"] = farmer_headers["Authorization"]
    conn.execute("INSERT INTO inventory VALUES ('ghee-500', 'A2 Desi Ghee', 10, 79900, 'INR', 1, CURRENT_TIMESTAMP)")
    addr_resp = client.post("/api/v1/marketplace/addresses", json={
        "recipient_name": "Farmer Ramesh",
        "phone": "9876543210",
        "address_line1": "Farm House 12",
        "village_or_city": "Noida",
        "district": "Gautam Buddha Nagar",
        "state": "Uttar Pradesh",
        "postal_code": "201305",
        "landmark": "Near Dairy Center",
        "is_default": True,
    })
    assert addr_resp.status_code == 201
    address_id = addr_resp.json()["data"]["id"]

    client.post("/api/v1/marketplace/cart/items", json={"product_id": "ghee-500", "quantity": 1})
    quote = client.post("/api/v1/marketplace/orders/checkout/quote", json={
        "delivery_address_id": address_id,
        "payment_method": "cod",
    }).json()["data"]

    placed_order = client.post("/api/v1/marketplace/orders/checkout", json={
        "delivery_address_id": address_id,
        "payment_method": "cod",
        "idempotency_key": "ops-test-order-1",
        "expected_total": quote["total"],
    }).json()["data"]

    order_id = placed_order["id"]
    assert placed_order["status"] == "CONFIRMED"
    assert len(placed_order["timeline"]) >= 1
    assert placed_order["timeline"][0]["status"] == "CONFIRMED"

    # Security check: Farmer CANNOT list operational orders or fulfill them
    farmer_ops = client.get("/api/v1/marketplace/orders/operations")
    assert farmer_ops.status_code == 403, "Farmer must not list operational orders"

    farmer_pack = client.put(f"/api/v1/marketplace/orders/operations/{order_id}", json={"status": "PACKED"})
    assert farmer_pack.status_code == 403, "Farmer must not fulfill orders"

    # 4. Seller/Admin Operations: List Fulfillable Orders
    ops_orders = client.get("/api/v1/marketplace/orders/operations", headers=admin_headers)
    assert ops_orders.status_code == 200
    assert any(o["id"] == order_id for o in ops_orders.json()["data"])

    # 5. State Machine: Cannot jump directly from CONFIRMED to DELIVERED or OUT_FOR_DELIVERY
    bad_jump = client.put(f"/api/v1/marketplace/orders/operations/{order_id}", json={
        "status": "DELIVERED",
    }, headers=admin_headers)
    assert bad_jump.status_code == 409, "Must not jump from confirmed to delivered"

    # Pack Order
    pack_resp = client.put(f"/api/v1/marketplace/orders/operations/{order_id}", json={
        "status": "PACKED",
        "remarks": "Packed in thermal insulation box.",
        "location": "Milterra Noida Unit",
    }, headers=admin_headers)
    assert pack_resp.status_code == 200, pack_resp.text
    packed_order = pack_resp.json()["data"]
    assert packed_order["status"] == "PACKED"
    assert any(e["status"] == "PACKED" for e in packed_order["timeline"])

    # State Machine: Cannot jump from PACKED directly to DELIVERED
    bad_packed_jump = client.put(f"/api/v1/marketplace/orders/operations/{order_id}", json={
        "status": "DELIVERED",
    }, headers=admin_headers)
    assert bad_packed_jump.status_code == 409

    # 6. Dispatch Order (SHIPPED)
    dispatch_resp = client.put(f"/api/v1/marketplace/orders/operations/{order_id}", json={
        "status": "SHIPPED",
        "carrier": "Blue Dart Express",
        "tracking_number": "BD987654321IN",
        "location": "Noida Hub",
        "remarks": "Handed to courier pilot.",
    }, headers=admin_headers)
    assert dispatch_resp.status_code == 200, dispatch_resp.text
    shipped_order = dispatch_resp.json()["data"]
    assert shipped_order["status"] == "SHIPPED"
    assert shipped_order["carrier"] == "Blue Dart Express"
    assert shipped_order["tracking_number"] == "BD987654321IN"
    assert any(e["status"] == "SHIPPED" for e in shipped_order["timeline"])

    # Customer cannot cancel shipped order
    cancel_resp = client.post(f"/api/v1/marketplace/orders/{order_id}/cancel")
    assert cancel_resp.status_code == 400

    # State Machine: Cannot move backwards from SHIPPED to PACKED
    backwards_pack = client.put(f"/api/v1/marketplace/orders/operations/{order_id}", json={
        "status": "PACKED",
    }, headers=admin_headers)
    assert backwards_pack.status_code == 409

    # 7. Out for Delivery: Updates order status to out_for_delivery
    ofd_resp = client.put(f"/api/v1/marketplace/orders/operations/{order_id}", json={
        "status": "OUT_FOR_DELIVERY",
        "remarks": "Rider out with package.",
    }, headers=admin_headers)
    assert ofd_resp.status_code == 200, ofd_resp.text
    ofd_order = ofd_resp.json()["data"]
    assert ofd_order["status"] == "OUT_FOR_DELIVERY"
    assert any(e["status"] == "OUT_FOR_DELIVERY" for e in ofd_order["timeline"])

    # 8. Deliver Order
    deliver_resp = client.put(f"/api/v1/marketplace/orders/operations/{order_id}", json={
        "status": "DELIVERED",
        "remarks": "Delivered to recipient Ramesh.",
    }, headers=admin_headers)
    assert deliver_resp.status_code == 200, deliver_resp.text
    delivered_order = deliver_resp.json()["data"]
    assert delivered_order["status"] == "DELIVERED"
    assert any(e["status"] == "DELIVERED" for e in delivered_order["timeline"])

    # State Machine: Cannot move backwards from DELIVERED to PACKED or SHIPPED
    backwards_delivered = client.put(f"/api/v1/marketplace/orders/operations/{order_id}", json={
        "status": "PACKED",
    }, headers=admin_headers)
    assert backwards_delivered.status_code == 409

    # Security check: Customer CANNOT collect COD remittance
    farmer_remit = client.post(f"/api/v1/marketplace/orders/admin/cod/{order_id}/collect", json={
        "remittance_reference": "REMIT-BD-20260927-001",
    })
    assert farmer_remit.status_code == 403, "Farmer must not record COD remittance"

    # 9. Settle COD Cash Remittance by Admin
    remit_resp = client.post(f"/api/v1/marketplace/orders/admin/cod/{order_id}/collect", json={
        "remittance_reference": "REMIT-BD-20260927-001",
    }, headers=admin_headers)
    assert remit_resp.status_code == 200, remit_resp.text
    settled_order = remit_resp.json()["data"]
    assert settled_order["payment_status"] == "PAID"
    assert any(e["status"] == "PAID" for e in settled_order["timeline"])

    # Idempotent re-settlement with exact same reference succeeds without duplicate events
    idemp_remit = client.post(f"/api/v1/marketplace/orders/admin/cod/{order_id}/collect", json={
        "remittance_reference": "REMIT-BD-20260927-001",
    }, headers=admin_headers)
    assert idemp_remit.status_code == 200

    # Conflicting remittance reference on already-paid order returns 409 Conflict
    conflict_remit = client.post(f"/api/v1/marketplace/orders/admin/cod/{order_id}/collect", json={
        "remittance_reference": "REMIT-DIFFERENT-REF-999",
    }, headers=admin_headers)
    assert conflict_remit.status_code == 409

    # Customer viewing their own order details sees full timeline
    detail_resp = client.get(f"/api/v1/marketplace/orders/{order_id}")
    assert detail_resp.status_code == 200
    cust_order = detail_resp.json()["data"]
    assert cust_order["status"] == "DELIVERED"
    assert cust_order["payment_status"] == "PAID"
    assert cust_order["carrier"] == "Blue Dart Express"
    assert cust_order["tracking_number"] == "BD987654321IN"
    # Timeline milestones: CONFIRMED, PACKED, SHIPPED, OUT_FOR_DELIVERY, DELIVERED, PAID
    assert len(cust_order["timeline"]) == 6

    # Security check: Another customer cannot view this order
    other_pair = register(client, phone="9876599999", username="other.farmer", email="other@test.com").json()
    other_headers = {"Authorization": "Bearer " + other_pair["access_token"]}
    other_detail = client.get(f"/api/v1/marketplace/orders/{order_id}", headers=other_headers)
    assert other_detail.status_code == 404, "Another customer must not view another customer's order"

    # 10. Customer Profile Preferences GET & PUT
    prof_get = client.get("/api/v1/marketplace/profile")
    assert prof_get.status_code == 200, prof_get.text
    prof_data = prof_get.json()["data"]
    assert "name" in prof_data
    assert prof_data["language"] == "en"

    prof_put = client.put("/api/v1/marketplace/profile", json={
        "name": "Ramesh Kumar Farmer",
        "village": "Bishnah",
        "district": "Gautam Buddha Nagar",
        "state": "Uttar Pradesh",
        "language": "hi",
        "notify_health": True,
        "notify_vaccination": True,
        "notify_consultation": False,
        "notify_payment": True,
    })
    assert prof_put.status_code == 200, prof_put.text

    prof_get2 = client.get("/api/v1/marketplace/profile")
    assert prof_get2.status_code == 200
    prof_data2 = prof_get2.json()["data"]
    assert prof_data2["name"] == "Ramesh Kumar Farmer"
    assert prof_data2["village"] == "Bishnah"
    assert prof_data2["language"] == "hi"
    assert prof_data2["notify_consultation"] is False


def test_password_recovery_and_reset_round_trip(auth_client):
    client, conn = auth_client
    app.state.env.ENVIRONMENT = "test"
    app.state.env.ALLOW_TEST_AUTH = True

    # Register user with known phone & password
    reg_resp = client.post("/api/v1/auth/register-password", json={
        "phone": "9123456780",
        "password": "InitialPassword@2026",
        "display_name": "Reset Test User",
    })
    assert reg_resp.status_code == 201

    # Request password reset in test environment returns token
    forgot_resp = client.post("/api/v1/auth/forgot-password", json={
        "identifier": "9123456780",
    })
    assert forgot_resp.status_code == 200, forgot_resp.text
    forgot_data = forgot_resp.json()["data"]
    assert "reset_token" in forgot_data
    reset_token = forgot_data["reset_token"]

    # In production and staging without email gateway, forgot-password returns 503 and no token
    app.state.env.ENVIRONMENT = "production"
    app.state.env.ALLOW_TEST_AUTH = False
    prod_forgot = client.post("/api/v1/auth/forgot-password", json={
        "identifier": "9123456780",
    })
    assert prod_forgot.status_code == 503
    assert "reset_token" not in prod_forgot.text

    app.state.env.ENVIRONMENT = "staging"
    staging_forgot = client.post("/api/v1/auth/forgot-password", json={
        "identifier": "9123456780",
    })
    assert staging_forgot.status_code == 503
    assert "reset_token" not in staging_forgot.text

    app.state.env.ENVIRONMENT = "test"
    app.state.env.ALLOW_TEST_AUTH = True

    # Invalid token fails
    bad_reset = client.post("/api/v1/auth/reset-password", json={
        "token": "invalid-token-here-12345678",
        "new_password": "NewSecretPassword@2026",
    })
    assert bad_reset.status_code == 400

    # Valid reset succeeds
    good_reset = client.post("/api/v1/auth/reset-password", json={
        "token": reset_token,
        "new_password": "NewSecretPassword@2026",
    })
    assert good_reset.status_code == 200

    # Old password fails
    old_login = client.post("/api/v1/auth/login-password", json={
        "identifier": "9123456780",
        "password": "InitialPassword@2026",
    })
    assert old_login.status_code == 401

    # New password succeeds
    new_login = client.post("/api/v1/auth/login-password", json={
        "identifier": "9123456780",
        "password": "NewSecretPassword@2026",
    })
    assert new_login.status_code == 200
    assert "access_token" in new_login.json()


def test_cancellation_racing_packing_atomicity(auth_client):
    client, conn = auth_client
    pair = register(client, phone="9876500112").json()
    farmer_headers = {"Authorization": "Bearer " + pair["access_token"]}
    app.state.env.TEST_COMMERCE_ENABLED = "true"
    app.state.env.ENVIRONMENT = "test"
    app.state.env.ALLOW_TEST_AUTH = True

    admin_pair = register(client, phone="9876500113", username="admin.race", email="admin.race@milterra.com").json()
    conn.execute("UPDATE customers SET role='admin' WHERE phone='9876500113'")
    admin_headers = {"Authorization": "Bearer " + admin_pair["access_token"]}

    # Create address & place order
    conn.execute("INSERT OR IGNORE INTO inventory VALUES ('race-ghee-500', 'Race A2 Ghee', 10, 79900, 'INR', 1, CURRENT_TIMESTAMP)")
    addr_resp = client.post("/api/v1/marketplace/addresses", json={
        "recipient_name": "Race User",
        "phone": "9876500112",
        "address_line1": "Flat 1, Race St",
        "village_or_city": "Noida",
        "district": "Gautam Buddha Nagar",
        "state": "Uttar Pradesh",
        "postal_code": "201301",
        "landmark": "Near Gate",
        "is_default": True,
    }, headers=farmer_headers)
    assert addr_resp.status_code == 201, addr_resp.text
    address_id = addr_resp.json()["data"]["id"]

    client.post("/api/v1/marketplace/cart/items", json={"product_id": "race-ghee-500", "quantity": 1}, headers=farmer_headers)
    quote = client.post("/api/v1/marketplace/orders/checkout/quote", json={
        "delivery_address_id": address_id,
        "payment_method": "cod",
    }, headers=farmer_headers).json()["data"]

    checkout_resp = client.post("/api/v1/marketplace/orders/checkout", json={
        "delivery_address_id": address_id,
        "payment_method": "cod",
        "idempotency_key": "race-order-test-01",
        "expected_total": quote["total"],
    }, headers=farmer_headers)
    assert checkout_resp.status_code in (200, 201), checkout_resp.text
    order_id = checkout_resp.json()["data"]["id"]

    # Customer cancels the order
    cancel_resp = client.post(f"/api/v1/marketplace/orders/{order_id}/cancel", headers=farmer_headers)
    assert cancel_resp.status_code == 200

    # Seller attempts to PACK the cancelled order: MUST return 409 Conflict and NOT insert PACKED event
    pack_resp = client.put(f"/api/v1/marketplace/orders/operations/{order_id}", json={
        "status": "PACKED",
        "location": "Warehouse",
    }, headers=admin_headers)
    assert pack_resp.status_code == 409

    # Verify order is still cancelled and timeline has NO PACKED event
    order_detail = client.get(f"/api/v1/marketplace/orders/{order_id}", headers=farmer_headers).json()["data"]
    assert order_detail["status"] == "CANCELLED"
    events = [e["status"] for e in order_detail["timeline"]]
    assert "PACKED" not in events
    assert "CANCELLED" in events


def _setup_order_fixture(client, conn, farmer_headers, prefix="atomic"):
    product_id = f"{prefix}-prod"
    conn.execute(f"INSERT OR IGNORE INTO inventory VALUES ('{product_id}', 'Test Item', 10, 50000, 'INR', 1, CURRENT_TIMESTAMP)")

    addr_resp = client.post("/api/v1/marketplace/addresses", json={
        "recipient_name": f"{prefix.capitalize()} User",
        "phone": "9876500999",
        "address_line1": "Street 1",
        "village_or_city": "Noida",
        "district": "Gautam Buddha Nagar",
        "state": "Uttar Pradesh",
        "postal_code": "201301",
        "landmark": "Near Hub",
        "is_default": True,
    }, headers=farmer_headers)
    assert addr_resp.status_code == 201, addr_resp.text
    addr_id = addr_resp.json()["data"]["id"]

    client.post("/api/v1/marketplace/cart/items", json={"product_id": product_id, "quantity": 1}, headers=farmer_headers)
    quote = client.post("/api/v1/marketplace/orders/checkout/quote", json={
        "delivery_address_id": addr_id,
        "payment_method": "cod",
    }, headers=farmer_headers).json()["data"]

    checkout_resp = client.post("/api/v1/marketplace/orders/checkout", json={
        "delivery_address_id": addr_id,
        "payment_method": "cod",
        "idempotency_key": f"{prefix}-key-" + str(uuid.uuid4()),
        "expected_total": quote["total"],
    }, headers=farmer_headers)
    assert checkout_resp.status_code in (200, 201), checkout_resp.text
    return checkout_resp.json()["data"]["id"], product_id


def test_cancellation_atomicity_on_cleanup_failure(auth_client):
    """P1 Verification: Simulated batch failure during cancellation cleanup rolls back status update."""
    client, conn = auth_client
    pair = register(client, phone="9876500201").json()
    farmer_headers = {"Authorization": "Bearer " + pair["access_token"]}
    app.state.env.TEST_COMMERCE_ENABLED = "true"
    app.state.env.ENVIRONMENT = "test"
    app.state.env.ALLOW_TEST_AUTH = True

    order_id, product_id = _setup_order_fixture(client, conn, farmer_headers, prefix="cancel-atom")

    inv_before = conn.execute("SELECT available_units FROM inventory WHERE product_id=?", (product_id,)).fetchone()[0]
    assert inv_before == 9

    original_batch = app.state.env.DB.batch
    failed_attempts = 0

    async def failing_batch(statements):
        nonlocal failed_attempts
        if failed_attempts == 0:
            failed_attempts += 1
            raise Exception("Simulated D1 batch execution failure during cancellation cleanup")
        return await original_batch(statements)

    app.state.env.DB.batch = failing_batch

    # Attempt cancellation: should fail with 500
    fail_resp = client.post(f"/api/v1/marketplace/orders/{order_id}/cancel", headers=farmer_headers)
    assert fail_resp.status_code == 500, fail_resp.text

    # CRITICAL: Database state must be rolled back completely
    row = conn.execute("SELECT status, payment_status, reservation_id FROM orders WHERE id=?", (order_id,)).fetchone()
    assert row[0] == "confirmed", f"Order status should still be confirmed, got {row[0]}"
    inv_mid = conn.execute("SELECT available_units FROM inventory WHERE product_id=?", (product_id,)).fetchone()[0]
    assert inv_mid == 9, f"Stock should still be 9, got {inv_mid}"
    res_row = conn.execute("SELECT status FROM reservations WHERE id=?", (row[2],)).fetchone()
    assert res_row[0] == "RESERVED", f"Reservation should still be RESERVED, got {res_row[0]}"
    events = [r[0] for r in conn.execute("SELECT status FROM order_events WHERE order_id=?", (order_id,)).fetchall()]
    assert "CANCELLED" not in events

    # Retry cancellation with restored DB: MUST succeed and not return 400 "already cancelled"
    app.state.env.DB.batch = original_batch
    retry_resp = client.post(f"/api/v1/marketplace/orders/{order_id}/cancel", headers=farmer_headers)
    assert retry_resp.status_code == 200, f"Retry cancellation must succeed, got {retry_resp.status_code}: {retry_resp.text}"
    assert retry_resp.json()["data"]["status"] == "CANCELLED"

    # Verify final consistent state
    row_final = conn.execute("SELECT status, reservation_id FROM orders WHERE id=?", (order_id,)).fetchone()
    assert row_final[0] == "cancelled"
    inv_final = conn.execute("SELECT available_units FROM inventory WHERE product_id=?", (product_id,)).fetchone()[0]
    assert inv_final == 10
    res_final = conn.execute("SELECT status FROM reservations WHERE id=?", (row_final[1],)).fetchone()
    assert res_final[0] == "CANCELLED"
    events_final = [r[0] for r in conn.execute("SELECT status FROM order_events WHERE order_id=?", (order_id,)).fetchall()]
    assert "CANCELLED" in events_final

    # Repeat cancellation: rejected with 400 "already cancelled"
    repeat_resp = client.post(f"/api/v1/marketplace/orders/{order_id}/cancel", headers=farmer_headers)
    assert repeat_resp.status_code == 400
    assert "already cancelled" in repeat_resp.text.lower()


def test_fulfillment_atomicity_on_event_failure(auth_client):
    """P1 Verification: Simulated event failure during fulfillment rolls back order status update."""
    client, conn = auth_client
    pair = register(client, phone="9876500202").json()
    farmer_headers = {"Authorization": "Bearer " + pair["access_token"]}
    app.state.env.TEST_COMMERCE_ENABLED = "true"
    app.state.env.ENVIRONMENT = "test"
    app.state.env.ALLOW_TEST_AUTH = True

    admin_pair = register(client, phone="9876500203", username="admin.fulfill", email="admin.fulfill@milterra.com").json()
    conn.execute("UPDATE customers SET role='admin' WHERE phone='9876500203'")
    admin_headers = {"Authorization": "Bearer " + admin_pair["access_token"]}

    order_id, _ = _setup_order_fixture(client, conn, farmer_headers, prefix="fulfill-atom")

    original_batch = app.state.env.DB.batch
    failed_attempts = 0

    async def failing_batch(statements):
        nonlocal failed_attempts
        if failed_attempts == 0:
            failed_attempts += 1
            raise Exception("Simulated D1 batch event insertion failure")
        return await original_batch(statements)

    app.state.env.DB.batch = failing_batch

    # Seller attempts to pack the order: fails with 500
    fail_resp = client.put(f"/api/v1/marketplace/orders/operations/{order_id}", json={
        "status": "PACKED",
        "location": "Warehouse Hub",
    }, headers=admin_headers)
    assert fail_resp.status_code == 500

    # CRITICAL: Order must NOT be left as PACKED without its event!
    row = conn.execute("SELECT status FROM orders WHERE id=?", (order_id,)).fetchone()
    assert row[0] == "confirmed", f"Order status should remain confirmed after failure, got {row[0]}"
    events = [r[0] for r in conn.execute("SELECT status FROM order_events WHERE order_id=?", (order_id,)).fetchall()]
    assert "PACKED" not in events

    # Retry packing: MUST succeed (NOT return 409 Conflict)
    app.state.env.DB.batch = original_batch
    retry_resp = client.put(f"/api/v1/marketplace/orders/operations/{order_id}", json={
        "status": "PACKED",
        "location": "Warehouse Hub",
    }, headers=admin_headers)
    assert retry_resp.status_code == 200, f"Retry packing must succeed, got {retry_resp.status_code}: {retry_resp.text}"
    assert retry_resp.json()["data"]["status"] == "PACKED"
    events_after = [e["status"] for e in retry_resp.json()["data"]["timeline"]]
    assert "PACKED" in events_after


def test_cod_settlement_atomicity_on_event_failure(auth_client):
    """P1 Verification: Simulated event failure during COD settlement rolls back payment status update."""
    client, conn = auth_client
    pair = register(client, phone="9876500204").json()
    farmer_headers = {"Authorization": "Bearer " + pair["access_token"]}
    app.state.env.TEST_COMMERCE_ENABLED = "true"
    app.state.env.ENVIRONMENT = "test"
    app.state.env.ALLOW_TEST_AUTH = True

    admin_pair = register(client, phone="9876500205", username="admin.settle", email="admin.settle@milterra.com").json()
    conn.execute("UPDATE customers SET role='admin' WHERE phone='9876500205'")
    admin_headers = {"Authorization": "Bearer " + admin_pair["access_token"]}

    order_id, _ = _setup_order_fixture(client, conn, farmer_headers, prefix="settle-atom")

    # Progress through fulfillment to delivered
    client.put(f"/api/v1/marketplace/orders/operations/{order_id}", json={"status": "PACKED"}, headers=admin_headers)
    client.put(f"/api/v1/marketplace/orders/operations/{order_id}", json={
        "status": "SHIPPED",
        "carrier": "BlueDart",
        "tracking_number": "BD998877",
    }, headers=admin_headers)
    client.put(f"/api/v1/marketplace/orders/operations/{order_id}", json={"status": "DELIVERED"}, headers=admin_headers)

    original_batch = app.state.env.DB.batch
    failed_attempts = 0

    async def failing_batch(statements):
        nonlocal failed_attempts
        if failed_attempts == 0:
            failed_attempts += 1
            raise Exception("Simulated D1 batch remittance event write failure")
        return await original_batch(statements)

    app.state.env.DB.batch = failing_batch

    # Attempt COD settlement: fails with 500
    fail_resp = client.post(f"/api/v1/marketplace/orders/admin/cod/{order_id}/collect", json={
        "remittance_reference": "REMIT-ATOM-01",
    }, headers=admin_headers)
    assert fail_resp.status_code == 500

    # CRITICAL: Payment status must NOT be left as PAID without its audit event!
    row = conn.execute("SELECT payment_status, remittance_reference FROM orders WHERE id=?", (order_id,)).fetchone()
    assert row[0] == "pending", f"Payment status should remain pending, got {row[0]}"
    assert row[1] is None, f"Remittance reference should remain None, got {row[1]}"
    events = [r[0] for r in conn.execute("SELECT status FROM order_events WHERE order_id=?", (order_id,)).fetchall()]
    assert "PAID" not in events

    # Retry settlement: MUST succeed and record remittance event
    app.state.env.DB.batch = original_batch
    retry_resp = client.post(f"/api/v1/marketplace/orders/admin/cod/{order_id}/collect", json={
        "remittance_reference": "REMIT-ATOM-01",
    }, headers=admin_headers)
    assert retry_resp.status_code == 200, f"Retry settlement must succeed, got {retry_resp.status_code}: {retry_resp.text}"
    assert retry_resp.json()["data"]["payment_status"] == "PAID"
    events_after = [e["status"] for e in retry_resp.json()["data"]["timeline"]]
    assert "PAID" in events_after

    # Idempotent replay with same reference: 200 OK
    replay_resp = client.post(f"/api/v1/marketplace/orders/admin/cod/{order_id}/collect", json={
        "remittance_reference": "REMIT-ATOM-01",
    }, headers=admin_headers)
    assert replay_resp.status_code == 200

    # Conflicting reference: 409 Conflict
    conflict_resp = client.post(f"/api/v1/marketplace/orders/admin/cod/{order_id}/collect", json={
        "remittance_reference": "REMIT-ATOM-02",
    }, headers=admin_headers)
    assert conflict_resp.status_code == 409
    assert "already been settled with another reference" in conflict_resp.text.lower()


def test_concurrent_settlement_reference_conflict(auth_client):
    """P1 Verification: Concurrent settlement requests with conflicting references are rejected."""
    client, conn = auth_client
    pair = register(client, phone="9876500206").json()
    farmer_headers = {"Authorization": "Bearer " + pair["access_token"]}
    app.state.env.TEST_COMMERCE_ENABLED = "true"
    app.state.env.ENVIRONMENT = "test"
    app.state.env.ALLOW_TEST_AUTH = True

    admin_pair = register(client, phone="9876500207", username="admin.race2", email="admin.race2@milterra.com").json()
    conn.execute("UPDATE customers SET role='admin' WHERE phone='9876500207'")
    admin_headers = {"Authorization": "Bearer " + admin_pair["access_token"]}

    order_id, _ = _setup_order_fixture(client, conn, farmer_headers, prefix="race-settle")

    # Move order to delivered
    client.put(f"/api/v1/marketplace/orders/operations/{order_id}", json={"status": "PACKED"}, headers=admin_headers)
    client.put(f"/api/v1/marketplace/orders/operations/{order_id}", json={
        "status": "SHIPPED",
        "carrier": "Delhivery",
        "tracking_number": "DL123",
    }, headers=admin_headers)
    client.put(f"/api/v1/marketplace/orders/operations/{order_id}", json={"status": "DELIVERED"}, headers=admin_headers)

    # First settlement request with REF-ALPHA succeeds
    resp_a = client.post(f"/api/v1/marketplace/orders/admin/cod/{order_id}/collect", json={
        "remittance_reference": "REF-ALPHA",
    }, headers=admin_headers)
    assert resp_a.status_code == 200

    # Overlapping second settlement request with REF-BETA is rejected with 409 Conflict
    resp_b = client.post(f"/api/v1/marketplace/orders/admin/cod/{order_id}/collect", json={
        "remittance_reference": "REF-BETA",
    }, headers=admin_headers)
    assert resp_b.status_code == 409

    # Replay of winner REF-ALPHA returns 200 OK
    resp_a_replay = client.post(f"/api/v1/marketplace/orders/admin/cod/{order_id}/collect", json={
        "remittance_reference": "REF-ALPHA",
    }, headers=admin_headers)
    assert resp_a_replay.status_code == 200


def test_concurrent_asyncio_gather_race(auth_client):
    """P1 Verification: Simultaneous overlapping cancellation and packing requests using asyncio.gather."""
    client, conn = auth_client
    pair = register(client, phone="9876500301").json()
    farmer_headers = {"Authorization": "Bearer " + pair["access_token"]}
    app.state.env.TEST_COMMERCE_ENABLED = "true"
    app.state.env.ENVIRONMENT = "test"
    app.state.env.ALLOW_TEST_AUTH = True

    admin_pair = register(client, phone="9876500302", username="admin.async", email="admin.async@milterra.com").json()
    conn.execute("UPDATE customers SET role='admin' WHERE phone='9876500302'")
    admin_headers = {"Authorization": "Bearer " + admin_pair["access_token"]}

    order_id, _ = _setup_order_fixture(client, conn, farmer_headers, prefix="async-gather")

    async def run_race():
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as ac:
            cancel_coro = ac.post(f"/api/v1/marketplace/orders/{order_id}/cancel", headers=farmer_headers)
            pack_coro = ac.put(f"/api/v1/marketplace/orders/operations/{order_id}", json={"status": "PACKED"}, headers=admin_headers)
            return await asyncio.gather(cancel_coro, pack_coro, return_exceptions=True)

    results = asyncio.run(run_race())
    status_codes = [r.status_code for r in results if not isinstance(r, Exception)]
    # Exactly one operation must succeed (200) and the other must be rejected (400 or 409)
    assert 200 in status_codes, f"One operation should have succeeded: {status_codes}"
    assert any(code in (400, 409) for code in status_codes), f"One operation should have been rejected with 400/409: {status_codes}"

    # Verify database timeline consistency: NO conflicting timeline events allowed
    events = [r[0] for r in conn.execute("SELECT status FROM order_events WHERE order_id=?", (order_id,)).fetchall()]
    assert not ("CANCELLED" in events and "PACKED" in events), "Timeline must never contain both CANCELLED and PACKED"


def test_concurrent_asyncio_gather_cod_settlement_conflict(auth_client):
    """P1 Verification: Simultaneous overlapping COD settlement requests with conflicting references using asyncio.gather."""
    client, conn = auth_client
    pair = register(client, phone="9876500303").json()
    farmer_headers = {"Authorization": "Bearer " + pair["access_token"]}
    app.state.env.TEST_COMMERCE_ENABLED = "true"
    app.state.env.ENVIRONMENT = "test"
    app.state.env.ALLOW_TEST_AUTH = True

    admin_pair = register(client, phone="9876500304", username="admin.async2", email="admin.async2@milterra.com").json()
    conn.execute("UPDATE customers SET role='admin' WHERE phone='9876500304'")
    admin_headers = {"Authorization": "Bearer " + admin_pair["access_token"]}

    order_id, _ = _setup_order_fixture(client, conn, farmer_headers, prefix="async-settle")

    # Move order to delivered
    client.put(f"/api/v1/marketplace/orders/operations/{order_id}", json={"status": "PACKED"}, headers=admin_headers)
    client.put(f"/api/v1/marketplace/orders/operations/{order_id}", json={
        "status": "SHIPPED",
        "carrier": "Delhivery",
        "tracking_number": "DL8899",
    }, headers=admin_headers)
    client.put(f"/api/v1/marketplace/orders/operations/{order_id}", json={"status": "DELIVERED"}, headers=admin_headers)

    async def run_race():
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as ac:
            req1 = ac.post(f"/api/v1/marketplace/orders/admin/cod/{order_id}/collect", json={"remittance_reference": "REF-ASYNC-1"}, headers=admin_headers)
            req2 = ac.post(f"/api/v1/marketplace/orders/admin/cod/{order_id}/collect", json={"remittance_reference": "REF-ASYNC-2"}, headers=admin_headers)
            return await asyncio.gather(req1, req2, return_exceptions=True)

    results = asyncio.run(run_race())
    status_codes = [r.status_code for r in results if not isinstance(r, Exception)]
    assert 200 in status_codes
    assert 409 in status_codes

    # Exactly ONE PAID event in database
    paid_events = [r[0] for r in conn.execute("SELECT status FROM order_events WHERE order_id=? AND status='PAID'", (order_id,)).fetchall()]
    assert len(paid_events) == 1, "There must be exactly one PAID event recorded"
