import uuid
from decimal import Decimal
import pytest
from sqlalchemy import select
from app.models.customer_commerce import OrderContact, OrderEvent
from app.models.order import Order, OrderItem, PaymentStatus, OrderStatus, FulfillmentStatus
from app.models.product import ProductInventory
from app.models.serviceable_pincode import ServiceablePincode
from tests.test_cart import product
from tests.test_delivery_addresses import address
from app.config import settings

ROOT = '/api/v1/marketplace'

@pytest.mark.asyncio
async def test_help_content_and_support_are_persistent_and_role_scoped(client, db_session, auth_headers, vendor_headers, admin_headers):
    help_data = {'contact_message':'Please leave an enquiry.', 'faqs':[{'category':'Launch', 'question':'Can I order?', 'answer':'You can register interest; no payments are taken.'}]}
    assert (await client.put(f'{ROOT}/admin/help', headers=auth_headers, json=help_data)).status_code == 403
    assert (await client.put(f'{ROOT}/admin/help', headers=admin_headers, json=help_data)).status_code == 200
    await db_session.commit()
    assert (await client.get(f'{ROOT}/help')).json()['data'] == help_data
    ticket = (await client.post(f'{ROOT}/support', headers=auth_headers, json={'subject':'Launch enquiry', 'message':'Please tell me when ghee will launch.'})).json()['data']
    assert (await client.get(f'{ROOT}/support', headers=vendor_headers)).json()['data'] == []
    assert (await client.patch(f"{ROOT}/admin/support/{ticket['id']}", headers=auth_headers, json={'status':'CLOSED','reply':'spoof'})).status_code == 403
    assert (await client.patch(f"{ROOT}/admin/support/{ticket['id']}", headers=admin_headers, json={'status':'IN_PROGRESS','reply':'We will contact you before launch.'})).status_code == 200
    await db_session.commit()
    assert (await client.get(f'{ROOT}/support', headers=auth_headers)).json()['data'][0]['reply'] == 'We will contact you before launch.'

@pytest.mark.asyncio
async def test_customer_profile_preferences_persist_and_cannot_change_roles(client, db_session, auth_headers, vendor_headers):
    payload={'name':'Customer Name','village':'Lucknow','language':'hi','notify_payment':False}
    assert (await client.put(f'{ROOT}/profile', headers=auth_headers, json=payload | {'role':'admin'})).status_code == 422
    assert (await client.put(f'{ROOT}/profile', headers=auth_headers, json=payload)).status_code == 200
    await db_session.commit()
    saved=(await client.get(f'{ROOT}/profile', headers=auth_headers)).json()['data']
    assert saved['village']=='Lucknow' and saved['notify_payment'] is False
    assert (await client.get('/api/v1/auth/me', headers=auth_headers)).json()['data']['name']=='Customer Name'
    assert (await client.get(f'{ROOT}/profile', headers=vendor_headers)).json()['data'].get('village') is None

@pytest.mark.asyncio
async def test_wishlist_persists_is_idempotent_and_private(client, db_session, auth_headers, vendor_headers, vendor_user):
    p = await product(db_session, vendor_user)
    key = str(p.id)
    for _ in range(2):
        assert (await client.put(f'{ROOT}/wishlist/{key}', headers=auth_headers)).status_code == 200
    await db_session.commit()
    assert (await client.get(f'{ROOT}/wishlist', headers=auth_headers)).json()['data'] == [key]
    assert (await client.get(f'{ROOT}/wishlist', headers=vendor_headers)).json()['data'] == []
    assert (await client.get(f'{ROOT}/wishlist')).status_code in (401, 403)
    assert (await client.put(f'{ROOT}/wishlist/{uuid.uuid4()}', headers=auth_headers)).status_code == 404
    await client.delete(f'{ROOT}/wishlist/{key}', headers=auth_headers)
    assert (await client.get(f'{ROOT}/wishlist', headers=auth_headers)).json()['data'] == []

@pytest.mark.asyncio
async def test_save_restore_atomic_and_stock_revalidated(client, db_session, auth_headers, vendor_headers, vendor_user):
    p = await product(db_session, vendor_user, stock=3)
    item = (await client.post(f'{ROOT}/cart/items', headers=auth_headers, json={'product_id': str(p.id), 'quantity': 2})).json()['data']
    assert (await client.post(f"{ROOT}/cart/items/{item['id']}/save", headers=vendor_headers)).status_code == 404
    assert (await client.post(f"{ROOT}/cart/items/{item['id']}/save", headers=auth_headers)).status_code == 200
    await db_session.commit()
    assert (await client.get(f'{ROOT}/cart', headers=auth_headers)).json()['data']['items'] == []
    assert len((await client.get(f'{ROOT}/saved-items', headers=auth_headers)).json()['data']) == 1
    inv = (await db_session.execute(select(ProductInventory).where(ProductInventory.product_id == p.id))).scalar_one()
    inv.available_quantity = 1
    await db_session.flush()
    assert (await client.post(f'{ROOT}/saved-items/{p.id}/restore', headers=auth_headers)).status_code == 422
    assert len((await client.get(f'{ROOT}/saved-items', headers=auth_headers)).json()['data']) == 1
    inv.available_quantity = 3
    await db_session.flush()
    assert (await client.post(f'{ROOT}/saved-items/{p.id}/restore', headers=auth_headers)).status_code == 200
    assert (await client.get(f'{ROOT}/saved-items', headers=auth_headers)).json()['data'] == []
    assert (await client.get(f'{ROOT}/cart', headers=auth_headers)).json()['data']['items'][0]['quantity'] == 2

async def checkout(client, headers, p, db_session):
    if await db_session.get(ServiceablePincode, '302001') is None:
        db_session.add(ServiceablePincode(
            pincode='302001', city='Jaipur', state='Rajasthan', is_serviceable=True))
        await db_session.flush()
    await client.post(f'{ROOT}/cart/items', headers=headers, json={'product_id': str(p.id), 'quantity': 1})
    delivery = (await client.post(f'{ROOT}/addresses', headers=headers, json=address())).json()['data']
    response = await client.post(f'{ROOT}/orders/checkout', headers=headers, json={'delivery_address_id': delivery['id'], 'idempotency_key': str(uuid.uuid4()), 'payment_method': 'upi'})
    assert response.status_code == 201, response.text
    return response.json()['data']

@pytest.mark.asyncio
async def test_interest_order_history_cancel_followup_notification(client, db_session, auth_headers, vendor_headers, admin_headers, vendor_user, monkeypatch):
    monkeypatch.setattr(settings, 'PRELAUNCH_MODE', True)
    p = await product(db_session, vendor_user, stock=3)
    order = await checkout(client, auth_headers, p, db_session)
    assert order['payment_method'] == 'upi'
    assert len(order['timeline']) == 1
    await db_session.commit()
    oid = order['id']
    assert (await client.get(f'{ROOT}/orders/{oid}', headers=vendor_headers)).status_code == 404
    assert (await client.get(f'{ROOT}/orders/{oid}', headers=auth_headers)).json()['data']['id'] == oid
    payload = {'interest_status': 'CONTACTED', 'notes': 'Requested call after launch'}
    assert (await client.patch(f'{ROOT}/orders/admin/interests/{oid}', headers=auth_headers, json=payload)).status_code == 403
    assert (await client.patch(f'{ROOT}/orders/admin/interests/{oid}', headers=admin_headers, json=payload)).status_code == 200
    await db_session.commit()
    row = (await client.get(f'{ROOT}/orders/admin/interests', headers=admin_headers)).json()['data'][0]
    assert row['interest_status'] == 'CONTACTED' and row['followup_notes'] == payload['notes']
    customer = (await client.get(f'{ROOT}/orders/{oid}', headers=auth_headers)).json()['data']
    assert 'followup_notes' not in customer
    assert (await client.put(f'{ROOT}/orders/operations/{oid}', headers=admin_headers, json={'status': 'CONFIRMED'})).status_code == 409
    for _ in range(2):
        assert (await client.post(f'{ROOT}/orders/{oid}/cancel', headers=auth_headers, json={'reason':'Later'})).status_code == 200
    events = list((await db_session.execute(select(OrderEvent).where(OrderEvent.order_id == uuid.UUID(oid)))).scalars())
    assert len(events) == 2
    inv = (await db_session.execute(select(ProductInventory).where(ProductInventory.product_id == p.id))).scalar_one()
    assert inv.available_quantity == 3
    notices = (await client.get('/api/v1/notifications', headers=auth_headers)).json()['data']
    assert len(notices) == 2
    assert (await client.put(f"/api/v1/notifications/{notices[0]['id']}/read", headers=auth_headers)).status_code == 200

@pytest.mark.asyncio
async def test_commercial_cancel_restores_stock_once_and_paid_requests_refund_review(client, db_session, auth_headers, vendor_user, monkeypatch):
    monkeypatch.setattr(settings, 'PRELAUNCH_MODE', False)
    monkeypatch.setattr(settings, 'RAZORPAY_KEY_ID', 'rzp_test')
    monkeypatch.setattr(settings, 'RAZORPAY_KEY_SECRET', 'test-secret')
    p = await product(db_session, vendor_user, stock=3)
    data = await checkout(client, auth_headers, p, db_session)
    oid = data['id']
    inv = (await db_session.execute(select(ProductInventory).where(ProductInventory.product_id == p.id))).scalar_one()
    assert inv.available_quantity == 2
    for _ in range(2):
        assert (await client.post(f'{ROOT}/orders/{oid}/cancel', headers=auth_headers, json={})).status_code == 200
    assert inv.available_quantity == 3
    second = await checkout(client, auth_headers, p, db_session)
    row = await db_session.get(Order, uuid.UUID(second['id']))
    row.payment_status = PaymentStatus.paid
    await db_session.flush()
    paid_request = await client.post(f"{ROOT}/orders/{second['id']}/cancel", headers=auth_headers, json={})
    assert paid_request.status_code == 200
    assert paid_request.json()['data']['cancellation_status'] == 'REQUESTED'
    assert row.payment_status == PaymentStatus.paid
    assert inv.available_quantity == 2

@pytest.mark.asyncio
async def test_fulfillment_is_paid_vendor_isolated_and_persists(client, db_session, auth_headers, vendor_headers, admin_headers, vendor_user, monkeypatch):
    monkeypatch.setattr(settings, 'PRELAUNCH_MODE', False)
    monkeypatch.setattr(settings, 'RAZORPAY_KEY_ID', 'rzp_test')
    monkeypatch.setattr(settings, 'RAZORPAY_KEY_SECRET', 'test-secret')
    p = await product(db_session, vendor_user, stock=3)
    data = await checkout(client, auth_headers, p, db_session)
    oid = data['id']
    assert (await client.get(f'{ROOT}/orders/operations', headers=auth_headers)).status_code == 403
    assert (await client.get(f'{ROOT}/orders/operations', headers=vendor_headers)).json()['data'] == []
    row = await db_session.get(Order, uuid.UUID(oid))
    row.payment_status = PaymentStatus.paid
    row.status = OrderStatus.confirmed
    await db_session.flush()
    assert len((await client.get(f'{ROOT}/orders/operations', headers=vendor_headers)).json()['data']) == 1
    for stage in ['CONFIRMED', 'PACKED', 'DISPATCHED', 'DELIVERED']:
        body = {'status': stage, 'carrier': 'Manual courier', 'tracking_number': 'ACTUAL-123'}
        r = await client.put(f'{ROOT}/orders/operations/{oid}', headers=vendor_headers, json=body)
        assert r.status_code == 200, r.text
    await db_session.commit()
    detail = (await client.get(f'{ROOT}/orders/{oid}', headers=auth_headers)).json()['data']
    assert detail['items'][0]['fulfillment_status'] == 'DELIVERED'
    assert detail['tracking_number'] == 'ACTUAL-123'
