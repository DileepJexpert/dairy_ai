from decimal import Decimal

import pytest
from sqlalchemy import select

from app.models.order import Order, PaymentStatus
from app.models.product import ProductInventory
from app.models.serviceable_pincode import ServiceablePincode
from tests.test_cart import product
from tests.test_delivery_addresses import address


@pytest.mark.asyncio
async def test_checkout_rejects_item_changed_to_concept(client, db_session, vendor_user, auth_headers):
    item = await product(db_session, vendor_user, stock=5)
    delivery = (await client.post('/api/v1/marketplace/addresses', headers=auth_headers, json=address())).json()['data']
    assert (await client.post('/api/v1/marketplace/cart/items', headers=auth_headers,
        json={'product_id': str(item.id), 'quantity': 1})).status_code == 201
    item.specifications = {'listing_status': 'concept'}
    await db_session.commit()
    validation = (await client.post('/api/v1/marketplace/cart/validate', headers=auth_headers)).json()['data']
    assert any(issue['type'] == 'CONCEPT_PRODUCT' for issue in validation['issues'])
    response = await client.post('/api/v1/marketplace/orders/checkout', headers=auth_headers,
        json={'delivery_address_id': delivery['id'], 'idempotency_key': 'concept-checkout-blocked'})
    assert response.status_code == 422
    assert list((await db_session.execute(select(Order))).scalars()) == []
    inventory = (await db_session.execute(select(ProductInventory).where(ProductInventory.product_id == item.id))).scalar_one()
    assert inventory.available_quantity == 5


@pytest.mark.asyncio
async def test_prelaunch_checkout_snapshots_interest_without_decrementing_stock(client, db_session, vendor_user, auth_headers, admin_headers, monkeypatch):
    from app.config import settings
    monkeypatch.setattr(settings, 'PRELAUNCH_MODE', True)
    item = await product(db_session, vendor_user, stock=5, price=Decimal("250"))
    delivery = (await client.post("/api/v1/marketplace/addresses", headers=auth_headers, json=address())).json()["data"]
    assert (await client.post("/api/v1/marketplace/cart/items", headers=auth_headers, json={"product_id": str(item.id), "quantity": 2})).status_code == 201
    request = {"delivery_address_id": delivery["id"], "idempotency_key": "checkout-test-0001"}
    first = await client.post("/api/v1/marketplace/orders/checkout", headers=auth_headers, json=request)
    assert first.status_code == 201
    data = first.json()["data"]
    assert data["status"] == "PENDING_PAYMENT" and Decimal(data["total"]) == Decimal("500")
    assert data["is_prelaunch_interest"] is True
    assert data["address"]["postal_code"] == "302001" and data["items"][0]["quantity"] == 2
    again = await client.post("/api/v1/marketplace/orders/checkout", headers=auth_headers, json=request)
    assert again.status_code == 201 and again.json()["data"]["id"] == data["id"]
    inventory = (await db_session.execute(select(ProductInventory).where(ProductInventory.product_id == item.id))).scalar_one()
    assert inventory.available_quantity == 5
    assert (await client.get("/api/v1/marketplace/cart", headers=auth_headers)).json()["data"]["items"] == []
    interests = await client.get(
        "/api/v1/marketplace/orders/admin/interests", headers=admin_headers
    )
    assert interests.status_code == 200
    assert interests.json()["data"][0]["customer_phone"] == "9999900001"


@pytest.mark.asyncio
async def test_checkout_idempotency_key_rejects_changed_request_without_changing_order_or_stock(
        client, db_session, vendor_user, auth_headers, monkeypatch):
    from app.config import settings
    monkeypatch.setattr(settings, 'PRELAUNCH_MODE', False)
    monkeypatch.setattr(settings, 'RAZORPAY_KEY_ID', 'rzp_test')
    monkeypatch.setattr(settings, 'RAZORPAY_KEY_SECRET', 'test-secret')
    monkeypatch.setattr(settings, 'SHIPPING_AUTO_BOOK_ENABLED', False)
    db_session.add(ServiceablePincode(
        pincode='302001', city='Jaipur', state='Rajasthan', is_serviceable=True))
    item = await product(db_session, vendor_user, stock=5, price=Decimal('250'))
    delivery = (await client.post('/api/v1/marketplace/addresses', headers=auth_headers,
                                  json=address())).json()['data']
    another_address = address()
    another_address['address_line1'] = 'A different delivery address'
    alternate = (await client.post('/api/v1/marketplace/addresses', headers=auth_headers,
                                   json=another_address)).json()['data']
    await client.post('/api/v1/marketplace/cart/items', headers=auth_headers,
                      json={'product_id': str(item.id), 'quantity': 2})
    request = {'delivery_address_id': delivery['id'], 'idempotency_key': 'same-key-different-request',
               'payment_method': 'cod', 'expected_total': '500.00'}
    first = await client.post('/api/v1/marketplace/orders/checkout', headers=auth_headers, json=request)
    assert first.status_code == 201, first.text
    order_id = first.json()['data']['id']

    equivalent = await client.post('/api/v1/marketplace/orders/checkout', headers=auth_headers,
                                   json={**request, 'expected_total': '500.0'})
    assert equivalent.status_code == 201 and equivalent.json()['data']['id'] == order_id
    for change in (
        {'delivery_address_id': alternate['id']},
        {'payment_method': 'upi'},
        {'coupon_code': 'NEW10'},
        {'expected_total': '501.00'},
        {'expected_total': '500.0000000000000000000000000000001'},
        {'expected_total': None},
    ):
        reused = await client.post('/api/v1/marketplace/orders/checkout', headers=auth_headers,
                                   json={**request, **change})
        assert reused.status_code == 409, (change, reused.text)
        assert 'Idempotency key' in reused.text

    orders = list((await db_session.execute(select(Order))).scalars())
    assert len(orders) == 1 and str(orders[0].id) == order_id
    assert orders[0].status.value == 'CONFIRMED'
    assert orders[0].checkout_request_fingerprint is not None
    inventory = (await db_session.execute(select(ProductInventory).where(
        ProductInventory.product_id == item.id))).scalar_one()
    assert inventory.available_quantity == 3


@pytest.mark.asyncio
async def test_legacy_checkout_idempotency_retry_checks_saved_order_inputs(
        client, db_session, vendor_user, auth_headers, monkeypatch):
    from app.config import settings
    monkeypatch.setattr(settings, 'PRELAUNCH_MODE', True)
    item = await product(db_session, vendor_user, price=Decimal('250'))
    delivery = (await client.post('/api/v1/marketplace/addresses', headers=auth_headers,
                                  json=address())).json()['data']
    await client.post('/api/v1/marketplace/cart/items', headers=auth_headers,
                      json={'product_id': str(item.id), 'quantity': 1})
    request = {'delivery_address_id': delivery['id'], 'idempotency_key': 'legacy-checkout-retry'}
    first = await client.post('/api/v1/marketplace/orders/checkout', headers=auth_headers, json=request)
    assert first.status_code == 201, first.text
    order = (await db_session.execute(select(Order))).scalar_one()
    order.checkout_request_fingerprint = None  # Existing rows after the migration.
    await db_session.commit()

    same = await client.post('/api/v1/marketplace/orders/checkout', headers=auth_headers,
                             json={**request, 'expected_total': '250.00'})
    assert same.status_code == 201 and same.json()['data']['id'] == first.json()['data']['id']
    different = await client.post('/api/v1/marketplace/orders/checkout', headers=auth_headers,
                                  json={**request, 'payment_method': 'upi'})
    assert different.status_code == 409


@pytest.mark.asyncio
async def test_vendor_can_only_progress_its_own_order_items(client, db_session, vendor_user, vendor_headers, auth_headers, monkeypatch):
    from app.config import settings
    monkeypatch.setattr(settings, 'PRELAUNCH_MODE', False)
    monkeypatch.setattr(settings, 'RAZORPAY_KEY_ID', 'rzp_test')
    monkeypatch.setattr(settings, 'RAZORPAY_KEY_SECRET', 'test-secret')
    db_session.add(ServiceablePincode(
        pincode='302001', city='Jaipur', state='Rajasthan', is_serviceable=True))
    await db_session.flush()
    item = await product(db_session, vendor_user)
    delivery = (await client.post("/api/v1/marketplace/addresses", headers=auth_headers, json=address())).json()["data"]
    await client.post("/api/v1/marketplace/cart/items", headers=auth_headers, json={"product_id": str(item.id), "quantity": 1})
    await client.post("/api/v1/marketplace/orders/checkout", headers=auth_headers, json={"delivery_address_id": delivery["id"], "idempotency_key": "vendor-order-test-01", "payment_method": "upi"})
    assert (await client.get("/api/v1/marketplace/orders/vendor", headers=vendor_headers)).json()["data"] == []
    order = (await db_session.execute(select(Order))).scalar_one()
    order.payment_status = PaymentStatus.paid
    await db_session.commit()
    queue = (await client.get("/api/v1/marketplace/orders/vendor", headers=vendor_headers)).json()["data"]
    assert len(queue) == 1 and queue[0]["fulfillment_status"] == "PENDING"
    progressed = await client.put(f"/api/v1/marketplace/orders/vendor/items/{queue[0]['item_id']}/fulfillment", headers=vendor_headers, params={"fulfillment_status": "CONFIRMED"})
    assert progressed.status_code == 200 and progressed.json()["data"]["fulfillment_status"] == "CONFIRMED"
