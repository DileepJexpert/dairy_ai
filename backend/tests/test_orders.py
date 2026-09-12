from decimal import Decimal

import pytest
from sqlalchemy import select

from app.models.order import Order, PaymentStatus
from app.models.product import ProductInventory
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
async def test_checkout_snapshots_address_decrements_stock_and_is_idempotent(client, db_session, vendor_user, auth_headers):
    item = await product(db_session, vendor_user, stock=5, price=Decimal("250"))
    delivery = (await client.post("/api/v1/marketplace/addresses", headers=auth_headers, json=address())).json()["data"]
    assert (await client.post("/api/v1/marketplace/cart/items", headers=auth_headers, json={"product_id": str(item.id), "quantity": 2})).status_code == 201
    request = {"delivery_address_id": delivery["id"], "idempotency_key": "checkout-test-0001"}
    first = await client.post("/api/v1/marketplace/orders/checkout", headers=auth_headers, json=request)
    assert first.status_code == 201
    data = first.json()["data"]
    assert data["status"] == "PENDING_PAYMENT" and Decimal(data["total"]) == Decimal("500")
    assert data["address"]["postal_code"] == "302001" and data["items"][0]["quantity"] == 2
    again = await client.post("/api/v1/marketplace/orders/checkout", headers=auth_headers, json=request)
    assert again.status_code == 201 and again.json()["data"]["id"] == data["id"]
    inventory = (await db_session.execute(select(ProductInventory).where(ProductInventory.product_id == item.id))).scalar_one()
    assert inventory.available_quantity == 3
    assert (await client.get("/api/v1/marketplace/cart", headers=auth_headers)).json()["data"]["items"] == []


@pytest.mark.asyncio
async def test_vendor_can_only_progress_its_own_order_items(client, db_session, vendor_user, vendor_headers, auth_headers):
    item = await product(db_session, vendor_user)
    delivery = (await client.post("/api/v1/marketplace/addresses", headers=auth_headers, json=address())).json()["data"]
    await client.post("/api/v1/marketplace/cart/items", headers=auth_headers, json={"product_id": str(item.id), "quantity": 1})
    await client.post("/api/v1/marketplace/orders/checkout", headers=auth_headers, json={"delivery_address_id": delivery["id"], "idempotency_key": "vendor-order-test-01"})
    assert (await client.get("/api/v1/marketplace/orders/vendor", headers=vendor_headers)).json()["data"] == []
    order = (await db_session.execute(select(Order))).scalar_one()
    order.payment_status = PaymentStatus.paid
    await db_session.commit()
    queue = (await client.get("/api/v1/marketplace/orders/vendor", headers=vendor_headers)).json()["data"]
    assert len(queue) == 1 and queue[0]["fulfillment_status"] == "PENDING"
    progressed = await client.put(f"/api/v1/marketplace/orders/vendor/items/{queue[0]['item_id']}/fulfillment", headers=vendor_headers, params={"fulfillment_status": "CONFIRMED"})
    assert progressed.status_code == 200 and progressed.json()["data"]["fulfillment_status"] == "CONFIRMED"
