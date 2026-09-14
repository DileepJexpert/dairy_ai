"""Admin -> persisted records -> storefront/cart/checkout contracts."""
import uuid
from datetime import datetime, timedelta, timezone
from decimal import Decimal

import pytest
from sqlalchemy import select

from app.models.commerce_admin import CommerceAudit, CommerceCoupon, OrderCoupon
from app.models.product import ProductInventory
from app.models.vendor import Vendor
from tests.test_cart import product
from tests.test_delivery_addresses import address

ROOT = "/api/v1"


def coupon(**changes):
    return {"code": "launch10", "description": "Launch preview savings", "discount_type": "percentage",
            "discount_value": "10", "min_order_value": "100", "max_discount_cap": "50",
            "valid_until": (datetime.now(timezone.utc) + timedelta(days=7)).isoformat(), **changes}


@pytest.mark.asyncio
async def test_admin_offer_changes_persist_and_reach_store_cart(client, db_session, vendor_user, admin_headers, auth_headers):
    p = await product(db_session, vendor_user, stock=5, price=Decimal("200"))
    response = await client.patch(f"{ROOT}/admin/commerce/offers/{p.id}", headers=admin_headers,
                                  json={"selling_price": "150", "mrp": "210", "available_stock": 8})
    assert response.status_code == 200, response.text
    await db_session.commit()
    db_session.expire_all()
    snapshot = (await client.get(f"{ROOT}/admin/commerce", headers=admin_headers)).json()["data"]
    assert Decimal(snapshot["offers"][0]["selling_price"]) == 150
    assert snapshot["offers"][0]["available_stock"] == 8
    assert snapshot["audit_logs"][0]["user_role"] == "admin"
    detail = (await client.get(f"{ROOT}/marketplace/products/{snapshot['offers'][0]['id']}")).json()["data"]
    assert Decimal(detail["base_price"]) == 150
    added = await client.post(f"{ROOT}/marketplace/cart/items", headers=auth_headers,
                             json={"product_id": detail["id"], "quantity": 2})
    assert added.status_code == 201
    cart = (await client.get(f"{ROOT}/marketplace/cart", headers=auth_headers)).json()["data"]
    assert Decimal(cart["subtotal"]) == 300


@pytest.mark.asyncio
async def test_offer_validation_and_role_isolation(client, db_session, vendor_user, admin_headers, auth_headers, vendor_headers, test_user):
    p = await product(db_session, vendor_user, stock=5)
    other = await product(db_session, test_user)
    assert (await client.get(f"{ROOT}/admin/commerce", headers=auth_headers)).status_code == 403
    assert (await client.get(f"{ROOT}/admin/commerce", headers=vendor_headers)).status_code == 403
    assert (await client.patch(f"{ROOT}/admin/commerce/offers/{p.id}", headers=auth_headers, json={"available_stock": 9})).status_code == 403
    assert (await client.patch(f"{ROOT}/vendor/commerce/offers/{other.id}", headers=vendor_headers, json={"available_stock": 9})).status_code == 403
    assert (await client.patch(f"{ROOT}/vendor/commerce/offers/{p.id}", headers=vendor_headers, json={"available_stock": 9})).status_code == 200
    for invalid in [{"available_stock": -1}, {"selling_price": 0}, {"mrp": 1}, {}, {"available_stock": None}]:
        assert (await client.patch(f"{ROOT}/admin/commerce/offers/{p.id}", headers=admin_headers, json=invalid)).status_code == 422
    snapshot = (await client.get(f"{ROOT}/vendor/commerce", headers=vendor_headers)).json()["data"]
    assert len(snapshot["offers"]) == 1 and snapshot["offers"][0]["id"] == str(p.id)
    assert snapshot["audit_logs"] == [] and snapshot["coupons"] == []


@pytest.mark.asyncio
async def test_stock_cannot_erase_reservations(client, db_session, vendor_user, admin_headers):
    p = await product(db_session, vendor_user, stock=5)
    inventory = (await db_session.execute(select(ProductInventory).where(ProductInventory.product_id == p.id))).scalar_one()
    inventory.reserved_quantity = 3
    await db_session.flush()
    response = await client.patch(f"{ROOT}/admin/commerce/offers/{p.id}", headers=admin_headers,
                                  json={"selling_price": "100", "available_stock": 2})
    assert response.status_code == 422
    assert p.base_price == 1200 and inventory.available_quantity == 5


@pytest.mark.asyncio
async def test_suspension_removes_seller_products_and_blocks_checkout(client, db_session, vendor_user, admin_headers, auth_headers):
    p = await product(db_session, vendor_user)
    await client.post(f"{ROOT}/marketplace/cart/items", headers=auth_headers, json={"product_id": str(p.id), "quantity": 1})
    delivery = (await client.post(f"{ROOT}/marketplace/addresses", headers=auth_headers, json=address())).json()["data"]
    assert (await client.patch(f"{ROOT}/admin/commerce/sellers/{p.vendor_id}", headers=admin_headers, json={"status": "suspended"})).status_code == 200
    listing = (await client.get(f"{ROOT}/marketplace/products")).json()["data"]
    assert listing == []
    checkout = await client.post(f"{ROOT}/marketplace/orders/checkout", headers=auth_headers,
        json={"delivery_address_id": delivery["id"], "idempotency_key": "suspended-seller"})
    assert checkout.status_code == 422
    assert (await client.patch(f"{ROOT}/admin/commerce/sellers/{p.vendor_id}", headers=admin_headers, json={"status": "approved"})).status_code == 200
    assert len((await client.get(f"{ROOT}/marketplace/products")).json()["data"]) == 1


@pytest.mark.asyncio
async def test_coupon_admin_store_quote_checkout_snapshot_and_idempotency(client, db_session, vendor_user, admin_headers, auth_headers):
    p = await product(db_session, vendor_user, price=Decimal("799"))
    created = await client.post(f"{ROOT}/admin/commerce/coupons", headers=admin_headers, json=coupon())
    assert created.status_code == 201, created.text
    coupon_id = created.json()["data"]["id"]
    await db_session.commit()
    available = (await client.get(f"{ROOT}/marketplace/coupons")).json()["data"]
    assert available[0]["code"] == "LAUNCH10"
    await client.post(f"{ROOT}/marketplace/cart/items", headers=auth_headers, json={"product_id": str(p.id), "quantity": 1})
    quote = await client.post(f"{ROOT}/marketplace/coupons/quote", headers=auth_headers, json={"code": "launch10"})
    assert quote.status_code == 200 and Decimal(quote.json()["data"]["discount"]) == 50
    delivery = (await client.post(f"{ROOT}/marketplace/addresses", headers=auth_headers, json=address())).json()["data"]
    request = {"delivery_address_id": delivery["id"], "idempotency_key": "coupon-checkout-once", "coupon_code": "LAUNCH10"}
    first = await client.post(f"{ROOT}/marketplace/orders/checkout", headers=auth_headers, json=request)
    assert first.status_code == 201, first.text
    assert Decimal(first.json()["data"]["total"]) == 749 and Decimal(first.json()["data"]["discount"]) == 50
    await client.patch(f"{ROOT}/admin/commerce/coupons/{coupon_id}", headers=admin_headers, json={"is_active": False})
    again = await client.post(f"{ROOT}/marketplace/orders/checkout", headers=auth_headers, json=request)
    assert again.json()["data"]["id"] == first.json()["data"]["id"]
    assert len(list((await db_session.execute(select(OrderCoupon))).scalars())) == 1
    snapshot = (await client.get(f"{ROOT}/admin/commerce", headers=admin_headers)).json()["data"]
    assert snapshot["coupons"][0]["usage_count"] == 1
    assert (await client.get(f"{ROOT}/marketplace/coupons")).json()["data"] == []


@pytest.mark.asyncio
async def test_coupon_expiry_validation_edit_and_authorization(client, db_session, admin_headers, auth_headers, vendor_user):
    assert (await client.post(f"{ROOT}/admin/commerce/coupons", headers=auth_headers, json=coupon())).status_code == 403
    for invalid in [coupon(discount_value=101), coupon(discount_value=-1), coupon(code="bad code"), coupon(max_discount_cap=0)]:
        assert (await client.post(f"{ROOT}/admin/commerce/coupons", headers=admin_headers, json=invalid)).status_code == 422
    created = await client.post(f"{ROOT}/admin/commerce/coupons", headers=admin_headers, json=coupon())
    cid = created.json()["data"]["id"]
    p = await product(db_session, vendor_user, price=Decimal("99"))
    await client.post(f"{ROOT}/marketplace/cart/items", headers=auth_headers, json={"product_id": str(p.id), "quantity": 1})
    assert (await client.post(f"{ROOT}/marketplace/coupons/quote", headers=auth_headers, json={"code": "LAUNCH10"})).status_code == 422
    updated = await client.put(f"{ROOT}/admin/commerce/coupons/{cid}", headers=admin_headers,
                              json=coupon(discount_type="flat", discount_value=150, min_order_value=0, max_discount_cap=None))
    assert updated.status_code == 200
    assert Decimal((await client.post(f"{ROOT}/marketplace/coupons/quote", headers=auth_headers, json={"code": "LAUNCH10"})).json()["data"]["total"]) == 0
    expired = coupon(valid_until=(datetime.now(timezone.utc)-timedelta(hours=1)).isoformat())
    await client.put(f"{ROOT}/admin/commerce/coupons/{cid}", headers=admin_headers, json=expired)
    assert (await client.get(f"{ROOT}/marketplace/coupons")).json()["data"] == []
    assert (await client.post(f"{ROOT}/marketplace/coupons/quote", headers=auth_headers, json={"code": "LAUNCH10"})).status_code == 422


@pytest.mark.asyncio
async def test_coupon_disabled_after_quote_preserves_cart(client, db_session, admin_headers, auth_headers, vendor_user):
    p = await product(db_session, vendor_user)
    c = (await client.post(f"{ROOT}/admin/commerce/coupons", headers=admin_headers, json=coupon())).json()["data"]
    await client.post(f"{ROOT}/marketplace/cart/items", headers=auth_headers, json={"product_id": str(p.id), "quantity": 1})
    assert (await client.post(f"{ROOT}/marketplace/coupons/quote", headers=auth_headers, json={"code": c["code"]})).status_code == 200
    await client.patch(f"{ROOT}/admin/commerce/coupons/{c['id']}", headers=admin_headers, json={"is_active": False})
    delivery = (await client.post(f"{ROOT}/marketplace/addresses", headers=auth_headers, json=address())).json()["data"]
    response = await client.post(f"{ROOT}/marketplace/orders/checkout", headers=auth_headers,
        json={"delivery_address_id": delivery["id"], "idempotency_key": "invalid-coupon-retry", "coupon_code": c["code"]})
    assert response.status_code == 422
    assert (await client.get(f"{ROOT}/marketplace/cart", headers=auth_headers)).json()["data"]["item_count"] == 1


@pytest.mark.asyncio
async def test_certificates_persist_publish_and_withdraw(client, db_session, vendor_user, admin_headers, auth_headers, vendor_headers):
    p = await product(db_session, vendor_user)
    data = {"product_id": str(p.id), "batch_number": "TEST-BATCH-1", "test_date": "2026-09-14T09:00:00+05:30",
            "laboratory": "Testing Lab", "status": "PENDING_REVIEW", "test_parameters": {"Moisture": "0.1%"}}
    assert (await client.post(f"{ROOT}/admin/commerce/certificates", headers=auth_headers, json=data)).status_code == 403
    assert (await client.post(f"{ROOT}/admin/commerce/certificates", headers=admin_headers, json={**data, "product_id": str(uuid.uuid4())})).status_code == 404
    created = await client.post(f"{ROOT}/admin/commerce/certificates", headers=admin_headers, json=data)
    assert created.status_code == 201, created.text
    cid = created.json()["data"]["id"]
    assert (await client.get(f"{ROOT}/marketplace/certificates")).json()["data"] == []
    assert (await client.put(f"{ROOT}/admin/commerce/certificates/{cid}", headers=admin_headers, json={**data, "status": "CERTIFIED"})).status_code == 422
    certified = {**data, "status": "CERTIFIED", "report_url": "https://example.com/report.pdf", "certified_by": "Lab signatory"}
    assert (await client.put(f"{ROOT}/admin/commerce/certificates/{cid}", headers=admin_headers, json=certified)).status_code == 200
    await db_session.commit()
    public = (await client.get(f"{ROOT}/marketplace/certificates", params={"product_id": str(p.id)})).json()["data"]
    assert public[0]["report_url"] == certified["report_url"]
    assert public[0]["test_parameters"] == data["test_parameters"]
    assert public[0]["test_date"] == "2026-09-14T03:30:00Z"
    vendor = (await client.get(f"{ROOT}/vendor/commerce", headers=vendor_headers)).json()["data"]
    assert len(vendor["batch_certificates"]) == 1
    await client.put(f"{ROOT}/admin/commerce/certificates/{cid}", headers=admin_headers, json={**certified, "status": "REJECTED"})
    assert (await client.get(f"{ROOT}/marketplace/certificates")).json()["data"] == []


@pytest.mark.asyncio
async def test_duplicate_codes_conflict(client, admin_headers):
    assert (await client.post(f"{ROOT}/admin/commerce/coupons", headers=admin_headers, json=coupon())).status_code == 201
    assert (await client.post(f"{ROOT}/admin/commerce/coupons", headers=admin_headers, json=coupon(code="LAUNCH10"))).status_code == 409


@pytest.mark.asyncio
async def test_seller_offer_creation_is_persistent_and_requires_approval(client, db_session, vendor_user, vendor_headers):
    p = await product(db_session, vendor_user)
    payload = {"source_product_id": str(p.id), "seller_sku": "NEW-SELLER-OFFER", "selling_price": 1000, "mrp": 1200, "available_stock": 7}
    assert (await client.post(f"{ROOT}/vendor/commerce/offers", headers=vendor_headers, json=payload)).status_code == 403
    vendor = await db_session.get(Vendor, p.vendor_id)
    vendor.is_verified = True
    await db_session.flush()
    response = await client.post(f"{ROOT}/vendor/commerce/offers", headers=vendor_headers, json=payload)
    assert response.status_code == 201, response.text
    created_id = response.json()["data"]["id"]
    assert created_id != str(p.id)
    await db_session.commit()
    own = (await client.get(f"{ROOT}/vendor/commerce", headers=vendor_headers)).json()["data"]["offers"]
    assert len(own) == 2
    offer = next(row for row in own if row["id"] == created_id)
    assert Decimal(offer["selling_price"]) == 1000 and offer["available_stock"] == 7
