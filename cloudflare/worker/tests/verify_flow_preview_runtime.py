"""Remote acceptance for an isolated Milterra flow-preview Worker.

Creates synthetic test records only. No provider or real money is touched.
The caller must point this at the separate simulator Worker, never the real COD API.
"""

from __future__ import annotations

import argparse
import secrets
import uuid
from pathlib import Path

import httpx


parser = argparse.ArgumentParser()
parser.add_argument("--base-url", required=True)
parser.add_argument("--origin", required=True)
parser.add_argument("--admin-file", type=Path, required=True)
args = parser.parse_args()

if "flow-preview" not in args.base_url or "flow-preview" not in args.origin:
    raise SystemExit("Only the isolated flow-preview hosts are accepted")

admin_lines = dict(line.split(": ", 1) for line in args.admin_file.read_text(
    encoding="utf-8").splitlines())
client = httpx.Client(base_url=args.base_url.rstrip("/"), timeout=45,
                      headers={"Origin": args.origin, "User-Agent": "Milterra-Flow-Preview-Acceptance/1.0"})


def call(method: str, path: str, *, body=None, token=None, expected=200):
    headers = {"Authorization": "Bearer " + token} if token else {}
    response = client.request(method, "/api/v1" + path, json=body, headers=headers)
    if response.status_code != expected:
        raise AssertionError(f"{method} {path}: HTTP {response.status_code}, expected {expected}")
    return response.json()


capabilities = call("GET", "/marketplace/orders/payment-capabilities")["data"]
assert capabilities["test_mode"] is True and capabilities["online_payment_available"] is False
assert call("GET", "/marketplace/pincode/check?pincode=201305")["cod_available"] is True
stock = call("GET", "/marketplace/inventory")["data"]
product = next(row for row in stock if row["is_active"] and row["available_quantity"] >= 2 and row["price"] > 0)

phone = "9" + str(secrets.randbelow(10**9)).zfill(9)
suffix = uuid.uuid4().hex[:12]
customer = call("POST", "/auth/register-password", body={
    "phone": phone, "password": secrets.token_urlsafe(24),
    "username": "flow." + suffix, "email": suffix + "@example.invalid",
    "display_name": "Synthetic flow preview customer"}, expected=201)
customer_token = customer["access_token"]
admin = call("POST", "/auth/login-password", body={
    "identifier": admin_lines["Preview admin username"],
    "password": admin_lines["Password"]})
admin_token = admin["access_token"]
assert admin["role"] == "admin"

address = call("POST", "/marketplace/addresses", body={
    "recipient_name": "Synthetic Preview Customer", "phone": phone,
    "address_line1": "Test lane, no delivery", "city": "Noida",
    "state": "Uttar Pradesh", "pincode": "201305"},
    token=customer_token, expected=201)["data"]["id"]


def place():
    call("POST", "/marketplace/cart/items", body={
        "product_id": product["product_id"], "quantity": 1},
        token=customer_token, expected=201)
    quote = call("POST", "/marketplace/orders/checkout/quote", body={
        "delivery_address_id": address, "payment_method": "cod"}, token=customer_token)["data"]
    order = call("POST", "/marketplace/orders/checkout", body={
        "delivery_address_id": address, "payment_method": "cod",
        "idempotency_key": str(uuid.uuid4()), "expected_total": quote["total"]},
        token=customer_token, expected=201)["data"]
    assert order["is_test_order"] is True and order["payment_status"] == "PENDING"
    return order["id"]


cancel_id = place()
cancelled = call("POST", f"/marketplace/orders/{cancel_id}/cancel", token=customer_token)["data"]
assert cancelled["status"] == "CANCELLED" and cancelled["payment_status"] == "PENDING"
assert call("GET", f"/marketplace/orders/admin/simulator/{cancel_id}/ledger",
            token=admin_token)["data"] == []

refund_id = place()
call("PUT", f"/marketplace/orders/operations/{refund_id}",
     body={"status": "PACKED"}, token=admin_token)
dispatch = call("POST", f"/marketplace/orders/admin/simulator/{refund_id}/dispatch",
                token=admin_token)
assert dispatch["simulated"] is True and dispatch["data"]["tracking_number"].startswith("SIM-AWB-")
for event in ("OUT_FOR_DELIVERY", "DELIVERED"):
    call("POST", f"/marketplace/orders/admin/simulator/{refund_id}/event",
         body={"event": event}, token=admin_token)
collected = call("POST", f"/marketplace/orders/admin/simulator/{refund_id}/collect",
                 token=admin_token)
assert collected["simulated"] is True and collected["data"]["payment_status"] == "PAID"
call("POST", f"/marketplace/orders/{refund_id}/return-request",
     body={"reason": "Synthetic customer requested a return"},
     token=customer_token, expected=201)
refund = call("POST", f"/marketplace/orders/admin/simulator/{refund_id}/refund",
              body={"restock_inventory": True, "remarks": "Synthetic parcel received"},
              token=admin_token)
assert refund["simulated"] is True and refund["data"]["payment_status"] == "REFUNDED"
ledger = call("GET", f"/marketplace/orders/admin/simulator/{refund_id}/ledger",
              token=admin_token)["data"]
assert [row["kind"] for row in ledger] == ["cod_collection", "cod_refund"]
assert ledger[0]["amount_minor"] == ledger[1]["amount_minor"]
assert all(row["reference"].startswith("SIM-") for row in ledger)
assert call("GET", f"/marketplace/orders/{refund_id}", token=customer_token)["data"]["payment_status"] == "REFUNDED"

call("POST", "/auth/logout", body={"refresh_token": customer["refresh_token"]}, token=customer_token)
call("POST", "/auth/logout", body={"refresh_token": admin["refresh_token"]}, token=admin_token)
print("PASS: isolated preview registration, COD cancellation, fake shipment, fake collection, return and fake refund")
print("Synthetic test order IDs:", cancel_id, refund_id)
