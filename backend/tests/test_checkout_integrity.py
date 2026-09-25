"""Commercial checkout prices, coverage, and inventory lifecycle regressions."""
import uuid
import hashlib
import hmac
import json
from datetime import datetime, timedelta
from decimal import Decimal

import pytest
from sqlalchemy import select

from app.config import settings
from app.integrations.payment import RazorpayClient
from app.models.order import Order, OrderItem, PaymentStatus, OrderStatus, FulfillmentStatus
from app.models.customer_commerce import OrderContact
from app.models.shipping import Shipment, ShipmentEvent
from app.models.product import ProductInventory
from app.models.serviceable_pincode import ServiceablePincode
from tests.test_cart import product
from tests.test_delivery_addresses import address
from tests.conftest import TestSessionLocal


async def cart_with_address(client, db_session, vendor_user, auth_headers, *, pin="302001"):
    item = await product(db_session, vendor_user, price=Decimal("1200"))
    created = await client.post(
        "/api/v1/marketplace/addresses", headers=auth_headers,
        json=address(postal_code=pin),
    )
    assert created.status_code == 201
    added = await client.post(
        "/api/v1/marketplace/cart/items", headers=auth_headers,
        json={"product_id": str(item.id), "quantity": 1},
    )
    assert added.status_code == 201
    return item, created.json()["data"]["id"]


def request(address_id, **extra):
    return {"delivery_address_id": address_id, "payment_method": "cod", **extra}


@pytest.mark.asyncio
async def test_payment_capabilities_reflect_gateway_configuration(client, auth_headers, monkeypatch):
    url = '/api/v1/marketplace/orders/payment-capabilities'
    monkeypatch.setattr(settings, 'PRELAUNCH_MODE', False)
    monkeypatch.setattr(settings, 'RAZORPAY_KEY_ID', '')
    monkeypatch.setattr(settings, 'RAZORPAY_KEY_SECRET', '')
    unavailable = await client.get(url, headers=auth_headers)
    assert unavailable.status_code == 200
    assert unavailable.json()['data'] == {
        'is_prelaunch_interest': False, 'online_payment_available': False,
    }
    monkeypatch.setattr(settings, 'RAZORPAY_KEY_ID', 'rzp_test_key')
    monkeypatch.setattr(settings, 'RAZORPAY_KEY_SECRET', 'rzp_test_secret')
    available = await client.get(url, headers=auth_headers)
    assert available.json()['data']['online_payment_available'] is True


@pytest.mark.asyncio
async def test_commercial_checkout_rejects_unknown_coverage_before_reserving_stock(
    client, db_session, vendor_user, auth_headers, monkeypatch,
):
    monkeypatch.setattr(settings, "PRELAUNCH_MODE", False)
    monkeypatch.setattr(settings, "SHIPPING_AUTO_BOOK_ENABLED", False)
    item, address_id = await cart_with_address(
        client, db_session, vendor_user, auth_headers, pin="999999",
    )
    quote = await client.post(
        "/api/v1/marketplace/orders/checkout/quote",
        headers=auth_headers, json=request(address_id),
    )
    checkout = await client.post(
        "/api/v1/marketplace/orders/checkout", headers=auth_headers,
        json=request(address_id, idempotency_key="unknown-coverage-1"),
    )
    assert quote.status_code == checkout.status_code == 422
    inventory = (await db_session.scalars(select(ProductInventory).where(
        ProductInventory.product_id == item.id))).one()
    assert inventory.available_quantity == 10
    assert (await db_session.scalars(select(Order))).all() == []


@pytest.mark.asyncio
async def test_checkout_quote_matches_saved_total_and_rejects_stale_price(
    client, db_session, vendor_user, auth_headers, monkeypatch,
):
    monkeypatch.setattr(settings, "PRELAUNCH_MODE", False)
    monkeypatch.setattr(settings, "SHIPPING_AUTO_BOOK_ENABLED", False)
    db_session.add(ServiceablePincode(
        pincode="302001", city="Jaipur", state="Rajasthan",
        is_serviceable=True, delivery_fee=Decimal("75.00"),
    ))
    item, address_id = await cart_with_address(client, db_session, vendor_user, auth_headers)
    url = "/api/v1/marketplace/orders/checkout"
    quote = await client.post(url + "/quote", headers=auth_headers, json=request(address_id))
    assert quote.status_code == 200
    assert quote.json()["data"]["total"] == "1275.00"
    item.base_price = Decimal("1300")
    await db_session.flush()
    stale = await client.post(url, headers=auth_headers, json=request(
        address_id, idempotency_key="stale-quote-1", expected_total="1275.00",
    ))
    assert stale.status_code == 409
    inventory = (await db_session.scalars(select(ProductInventory).where(
        ProductInventory.product_id == item.id))).one()
    assert inventory.available_quantity == 10
    refreshed = await client.post(url + "/quote", headers=auth_headers, json=request(address_id))
    assert refreshed.json()["data"]["total"] == "1375.00"
    placed = await client.post(url, headers=auth_headers, json=request(
        address_id, idempotency_key="stale-quote-1", expected_total="1375.00",
    ))
    assert placed.status_code == 201
    assert placed.json()["data"]["delivery_fee"] == "75.00"
    assert placed.json()["data"]["total"] == "1375.00"
    assert inventory.available_quantity == 9


@pytest.mark.asyncio
async def test_cancelled_unpaid_order_cannot_be_refunded_or_restocked_again(
    client, db_session, vendor_user, auth_headers, admin_headers, monkeypatch,
):
    monkeypatch.setattr(settings, "PRELAUNCH_MODE", False)
    monkeypatch.setattr(settings, "SHIPPING_AUTO_BOOK_ENABLED", False)
    db_session.add(ServiceablePincode(
        pincode="302001", city="Jaipur", state="Rajasthan", is_serviceable=True,
    ))
    item, address_id = await cart_with_address(client, db_session, vendor_user, auth_headers)
    placed = await client.post(
        "/api/v1/marketplace/orders/checkout", headers=auth_headers,
        json=request(address_id, idempotency_key="cancel-refund-1"),
    )
    order_id = placed.json()["data"]["id"]
    assert (await client.post(
        f"/api/v1/marketplace/orders/{order_id}/cancel",
        headers=auth_headers, json={},
    )).status_code == 200
    refund = await client.post(
        f"/api/v1/marketplace/orders/admin/refunds/{order_id}",
        headers=admin_headers, json={"action": "approve", "restock_inventory": True},
    )
    assert refund.status_code == 409
    inventory = (await db_session.scalars(select(ProductInventory).where(
        ProductInventory.product_id == item.id))).one()
    assert inventory.available_quantity == 10
    order = await db_session.get(Order, uuid.UUID(order_id))
    assert order.inventory_released is True
    assert order.payment_status == PaymentStatus.pending


@pytest.mark.asyncio
async def test_cod_fulfillment_waits_for_real_delivery_and_remittance(
    client, db_session, vendor_user, auth_headers, admin_headers, monkeypatch,
):
    monkeypatch.setattr(settings, 'PRELAUNCH_MODE', False)
    monkeypatch.setattr(settings, 'SHIPPING_AUTO_BOOK_ENABLED', False)
    db_session.add(ServiceablePincode(pincode='302001', city='Jaipur', state='Rajasthan', is_serviceable=True))
    item, address_id = await cart_with_address(client, db_session, vendor_user, auth_headers)
    placed = await client.post('/api/v1/marketplace/orders/checkout', headers=auth_headers,
        json=request(address_id, idempotency_key='cod-remittance-1'))
    assert placed.status_code == 201
    order_id = placed.json()['data']['id']
    assert placed.json()['data']['status'] == 'PENDING'
    order = await db_session.get(Order, uuid.UUID(order_id))
    assert order.is_cod and order.payment_status == PaymentStatus.pending
    assert len((await client.get('/api/v1/marketplace/orders/operations', headers=admin_headers)).json()['data']) == 1
    collect_url = f'/api/v1/marketplace/orders/admin/cod/{order_id}/collect'
    assert (await client.post(collect_url, headers=admin_headers,
        json={'remittance_reference': 'DLV-123'})).status_code == 409
    operations_url = f'/api/v1/marketplace/orders/operations/{order_id}'
    for stage in ('CONFIRMED', 'PACKED', 'DISPATCHED', 'DELIVERED'):
        result = await client.put(operations_url, headers=admin_headers, json={
            'status': stage, 'carrier': 'Local courier', 'tracking_number': 'AWB-123',
        })
        assert result.status_code == 200, result.text
    assert (await client.post(collect_url, headers=auth_headers,
        json={'remittance_reference': 'DLV-123'})).status_code == 403
    assert (await client.post(collect_url, headers=admin_headers,
        json={'remittance_reference': 'DLV-123'})).status_code == 200
    assert order.payment_status == PaymentStatus.paid
    assert (await client.post(collect_url, headers=admin_headers,
        json={'remittance_reference': 'DLV-123'})).status_code == 200
    assert (await client.post(collect_url, headers=admin_headers,
        json={'remittance_reference': 'OTHER'})).status_code == 409


@pytest.mark.asyncio
async def test_online_link_confirms_only_verified_full_payment_and_signed_webhook(
    client, db_session, vendor_user, auth_headers, admin_headers, monkeypatch,
):
    monkeypatch.setattr(settings, 'PRELAUNCH_MODE', False)
    monkeypatch.setattr(settings, 'SHIPPING_AUTO_BOOK_ENABLED', False)
    monkeypatch.setattr(settings, 'RAZORPAY_KEY_ID', 'rzp_test')
    monkeypatch.setattr(settings, 'RAZORPAY_KEY_SECRET', 'test-secret')
    monkeypatch.setattr(settings, 'RAZORPAY_WEBHOOK_SECRET', 'hook-secret')
    db_session.add(ServiceablePincode(pincode='302001', city='Jaipur', state='Rajasthan', is_serviceable=True))
    item, address_id = await cart_with_address(client, db_session, vendor_user, auth_headers)
    placed = await client.post('/api/v1/marketplace/orders/checkout', headers=auth_headers,
        json=request(address_id, payment_method='upi', idempotency_key='online-pay-1'))
    assert placed.status_code == 201
    order_id = placed.json()['data']['id']
    order = await db_session.get(Order, uuid.UUID(order_id))
    assert order.payment_status == PaymentStatus.pending
    link_id = 'plink_test123'
    calls = []
    async def create_link(amount, reference, name, phone):
        calls.append((amount, reference))
        return {'id': link_id, 'short_url': 'https://rzp.io/i/test123',
                'reference_id': reference, 'currency': 'INR', 'amount': amount}
    provider_status = {'status': 'created', 'amount_paid': 0}
    async def fetch_link(_):
        return {'id': link_id, 'reference_id': calls[0][1], 'currency': 'INR',
                'amount': 120000, **provider_status}
    monkeypatch.setattr(RazorpayClient, 'create_checkout_link', staticmethod(create_link))
    monkeypatch.setattr(RazorpayClient, 'fetch_checkout_link', staticmethod(fetch_link))
    link_url = f'/api/v1/marketplace/orders/{order_id}/payment-link'
    assert (await client.post(link_url, headers=auth_headers)).status_code == 200
    assert (await client.post(link_url, headers=auth_headers)).status_code == 200
    assert len(calls) == 1 and calls[0][0] == 120000 and calls[0][1].startswith(uuid.UUID(order_id).hex)
    verify_url = f'/api/v1/marketplace/orders/{order_id}/payment/verify'
    assert (await client.post(verify_url, headers=auth_headers)).json()['data']['confirmed'] is False
    provider_status.update(status='paid', amount_paid=100000)
    assert (await client.post(verify_url, headers=auth_headers)).json()['data']['confirmed'] is False
    provider_status.update(amount_paid=120000, payments=[{'payment_id': 'pay_test123'}])
    webhook = {'event': 'payment_link.paid', 'payload': {'payment_link': {'entity': {'id': link_id}}}}
    body = json.dumps(webhook).encode()
    hook_url = '/api/v1/marketplace/orders/webhooks/razorpay'
    assert (await client.post(hook_url, content=body,
        headers={'X-Razorpay-Signature': 'bad'})).status_code == 401
    assert order.payment_status == PaymentStatus.pending
    signature = hmac.new(b'hook-secret', body, hashlib.sha256).hexdigest()
    assert (await client.post(hook_url, content=body,
        headers={'X-Razorpay-Signature': signature})).status_code == 200
    assert order.payment_status == PaymentStatus.paid
    assert (await client.post(hook_url, content=body,
        headers={'X-Razorpay-Signature': signature})).status_code == 200
    contact = await db_session.get(OrderContact, order.id)
    assert contact.payment_link_id == link_id
    assert contact.payment_link_reference == calls[0][1]
    assert contact.payment_reference == 'pay_test123'
    refund_url = f'/api/v1/marketplace/orders/admin/refunds/{order_id}'
    async def fetch_refund(_):
        return {'id': 'rfnd_test123', 'payment_id': 'pay_test123',
                'currency': 'INR', 'amount': 120000, 'status': 'pending'}
    monkeypatch.setattr(RazorpayClient, 'fetch_checkout_refund', staticmethod(fetch_refund))
    unprocessed = await client.post(refund_url, headers=admin_headers, json={
        'action': 'approve', 'refund_reference': 'rfnd_test123',
    })
    assert unprocessed.status_code == 409 and order.payment_status == PaymentStatus.paid
    async def processed_refund(_):
        return {'id': 'rfnd_test123', 'payment_id': 'pay_test123',
                'currency': 'INR', 'amount': 120000, 'status': 'processed'}
    monkeypatch.setattr(RazorpayClient, 'fetch_checkout_refund', staticmethod(processed_refund))
    assert (await client.post(refund_url, headers=admin_headers, json={
        'action': 'approve', 'refund_reference': 'rfnd_test123',
    })).status_code == 200
    assert order.payment_status == PaymentStatus.refunded
    assert (await client.post(hook_url, content=body,
        headers={'X-Razorpay-Signature': signature})).status_code == 200


@pytest.mark.asyncio
async def test_rto_then_refund_releases_inventory_once(
    client, db_session, vendor_user, auth_headers, admin_headers, monkeypatch,
):
    monkeypatch.setattr(settings, "PRELAUNCH_MODE", False)
    monkeypatch.setattr(settings, "SHIPPING_AUTO_BOOK_ENABLED", False)
    db_session.add(ServiceablePincode(
        pincode="302001", city="Jaipur", state="Rajasthan", is_serviceable=True,
    ))
    item, address_id = await cart_with_address(client, db_session, vendor_user, auth_headers)
    placed = await client.post(
        "/api/v1/marketplace/orders/checkout", headers=auth_headers,
        json=request(address_id, idempotency_key="rto-refund-1"),
    )
    order_id = placed.json()["data"]["id"]
    order = await db_session.get(Order, uuid.UUID(order_id))
    order.payment_status = PaymentStatus.paid
    await db_session.flush()
    returned = await client.post(
        f"/api/v1/marketplace/orders/admin/returns/{order_id}/process",
        headers=admin_headers, json={"action": "mark_rto", "restock_inventory": True},
    )
    assert returned.status_code == 200
    refunded = await client.post(
        f"/api/v1/marketplace/orders/admin/refunds/{order_id}",
        headers=admin_headers, json={"action": "approve", "restock_inventory": True},
    )
    assert refunded.status_code == 200
    inventory = (await db_session.scalars(select(ProductInventory).where(
        ProductInventory.product_id == item.id))).one()
    assert inventory.available_quantity == 10
    assert order.inventory_released is True


@pytest.mark.asyncio
async def test_enum_roundtrip_and_case_insensitivity():
    assert OrderStatus("PENDING_PAYMENT") == OrderStatus.pending_payment
    assert OrderStatus("pending_payment") == OrderStatus.pending_payment
    assert OrderStatus["PENDING_PAYMENT"] == OrderStatus.pending_payment
    assert OrderStatus["pending_payment"] == OrderStatus.pending_payment

    assert PaymentStatus("PAID") == PaymentStatus.paid
    assert PaymentStatus("paid") == PaymentStatus.paid
    assert PaymentStatus("REFUNDED") == PaymentStatus.refunded
    assert PaymentStatus("refunded") == PaymentStatus.refunded

    assert FulfillmentStatus("DELIVERED") == FulfillmentStatus.delivered
    assert FulfillmentStatus("delivered") == FulfillmentStatus.delivered


@pytest.mark.asyncio
async def test_late_tracking_scan_does_not_overwrite_completed_return_or_cancellation(
    client, db_session, vendor_user, auth_headers, admin_headers, monkeypatch,
):
    monkeypatch.setattr(settings, "PRELAUNCH_MODE", False)
    monkeypatch.setattr(settings, "SHIPPING_AUTO_BOOK_ENABLED", False)
    db_session.add(ServiceablePincode(
        pincode="302001", city="Jaipur", state="Rajasthan", is_serviceable=True,
    ))
    item, address_id = await cart_with_address(client, db_session, vendor_user, auth_headers)
    placed = await client.post(
        "/api/v1/marketplace/orders/checkout", headers=auth_headers,
        json=request(address_id, idempotency_key="late-tracking-1"),
    )
    order_id = uuid.UUID(placed.json()["data"]["id"])
    order = await db_session.get(Order, order_id)
    order.status = OrderStatus.confirmed
    order.payment_status = PaymentStatus.paid

    shipment = Shipment(
        order_id=order_id, mode="surface", status="booked", courier_code="delhivery",
        awb="TESTAWB123", customer_fee=Decimal("0.00"), package={"weight_grams": 500},
        attempts=0, created_at=datetime.utcnow(), updated_at=datetime.utcnow(),
    )
    db_session.add(shipment)
    await db_session.flush()

    cancel_res = await client.post(
        f"/api/v1/marketplace/orders/admin/returns/{order_id}/process",
        headers=admin_headers, json={"action": "mark_rto", "restock_inventory": True},
    )
    assert cancel_res.status_code == 200

    class FakeCourier:
        async def track(self, awb):
            return [{
                "key": "scan-late-delivered",
                "status": "delivered",
                "occurred_at": datetime.utcnow().isoformat() + "Z",
                "description": "Late scan delivery event",
                "location": "Destination Hub",
            }]

    from app.api.shipment_tracking import poll_tracking_once
    await poll_tracking_once(courier=FakeCourier())

    order_items = (await db_session.scalars(select(OrderItem).where(OrderItem.order_id == order_id))).all()
    for oi in order_items:
        assert oi.fulfillment_status != FulfillmentStatus.delivered


@pytest.mark.asyncio
async def test_payment_link_retry_recreates_link_if_expired_or_cancelled(
    client, db_session, vendor_user, auth_headers, monkeypatch,
):
    monkeypatch.setattr(settings, "PRELAUNCH_MODE", False)
    monkeypatch.setattr(settings, "RAZORPAY_KEY_ID", "rzp_test_key")
    monkeypatch.setattr(settings, "RAZORPAY_KEY_SECRET", "rzp_test_secret")
    db_session.add(ServiceablePincode(
        pincode="302001", city="Jaipur", state="Rajasthan", is_serviceable=True,
    ))
    item, address_id = await cart_with_address(client, db_session, vendor_user, auth_headers)

    created_links = []
    async def fake_create_link(amount, ref, name, phone):
        link_id = f"plink_test_{len(created_links) + 1}"
        link = {
            "id": link_id, "reference_id": ref, "currency": "INR", "amount": amount,
            "short_url": f"https://rzp.io/i/{link_id}", "status": "created",
        }
        created_links.append(link)
        return link

    async def fake_fetch_link(link_id):
        if link_id == "plink_test_1":
            return {**created_links[0], "status": "expired"}
        return {**created_links[-1], "status": "created"}

    monkeypatch.setattr(RazorpayClient, "create_checkout_link", fake_create_link)
    monkeypatch.setattr(RazorpayClient, "fetch_checkout_link", fake_fetch_link)

    placed = await client.post(
        "/api/v1/marketplace/orders/checkout", headers=auth_headers,
        json={"delivery_address_id": address_id, "payment_method": "upi", "idempotency_key": "retry-link-1"},
    )
    assert placed.status_code == 201
    order_id = placed.json()["data"]["id"]

    # First payment-link call creates plink_test_1
    first_res = await client.post(f"/api/v1/marketplace/orders/{order_id}/payment-link", headers=auth_headers)
    assert first_res.status_code == 200
    assert len(created_links) == 1
    assert created_links[0]["id"] == "plink_test_1"

    # Now request payment link again; since plink_test_1 is expired, it should generate plink_test_2
    retry_res = await client.post(f"/api/v1/marketplace/orders/{order_id}/payment-link", headers=auth_headers)
    assert retry_res.status_code == 200
    assert len(created_links) == 2
    assert created_links[1]["id"] == "plink_test_2"
    assert retry_res.json()["data"]["url"] == "https://rzp.io/i/plink_test_2"


@pytest.mark.asyncio
async def test_order_cancellation_succeeds_when_payment_link_already_cancelled_or_expired(
    client, db_session, vendor_user, auth_headers, monkeypatch,
):
    monkeypatch.setattr(settings, "PRELAUNCH_MODE", False)
    monkeypatch.setattr(settings, "RAZORPAY_KEY_ID", "rzp_test_key")
    monkeypatch.setattr(settings, "RAZORPAY_KEY_SECRET", "rzp_test_secret")
    db_session.add(ServiceablePincode(
        pincode="302001", city="Jaipur", state="Rajasthan", is_serviceable=True,
    ))
    item, address_id = await cart_with_address(client, db_session, vendor_user, auth_headers)

    async def fake_create_link(amount, ref, name, phone):
        return {
            "id": "plink_expired_cancel", "reference_id": ref, "currency": "INR", "amount": amount,
            "short_url": "https://rzp.io/i/plink_expired_cancel", "status": "created",
        }

    async def fake_fetch_link(link_id):
        return {"id": link_id, "status": "expired"}

    monkeypatch.setattr(RazorpayClient, "create_checkout_link", fake_create_link)
    monkeypatch.setattr(RazorpayClient, "fetch_checkout_link", fake_fetch_link)

    placed = await client.post(
        "/api/v1/marketplace/orders/checkout", headers=auth_headers,
        json={"delivery_address_id": address_id, "payment_method": "upi", "idempotency_key": "cancel-exp-link-1"},
    )
    assert placed.status_code == 201
    order_id = placed.json()["data"]["id"]

    # Generate payment link to populate contact.payment_link_id
    link_res = await client.post(f"/api/v1/marketplace/orders/{order_id}/payment-link", headers=auth_headers)
    assert link_res.status_code == 200

    # Customer cancels order: should succeed without 409 because provider link is already expired
    cancel_res = await client.post(
        f"/api/v1/marketplace/orders/{order_id}/cancel", headers=auth_headers,
        json={"reason": "Changed my mind"},
    )
    assert cancel_res.status_code == 200
    assert cancel_res.json()["data"]["status"] == OrderStatus.cancelled.value

    inventory = (await db_session.scalars(select(ProductInventory).where(
        ProductInventory.product_id == item.id))).one()
    assert inventory.available_quantity == 10


@pytest.mark.asyncio
async def test_paid_link_retry_requires_full_verification_and_paid_cancel_needs_verified_refund(
    client, db_session, vendor_user, auth_headers, admin_headers, monkeypatch,
):
    monkeypatch.setattr(settings, 'PRELAUNCH_MODE', False)
    monkeypatch.setattr(settings, 'RAZORPAY_KEY_ID', 'rzp_test_key')
    monkeypatch.setattr(settings, 'RAZORPAY_KEY_SECRET', 'rzp_test_secret')
    db_session.add(ServiceablePincode(
        pincode='302001', city='Jaipur', state='Rajasthan', is_serviceable=True,
    ))
    item, address_id = await cart_with_address(client, db_session, vendor_user, auth_headers)
    created = {}
    provider = {'status': 'created', 'amount_paid': 0}

    async def create_link(amount, reference, name, phone):
        created.update(id='plink_live_checkout', reference_id=reference,
                       currency='INR', amount=amount,
                       short_url='https://rzp.io/i/live-checkout')
        return created

    async def fetch_link(_):
        return {**created, **provider}

    monkeypatch.setattr(RazorpayClient, 'create_checkout_link', staticmethod(create_link))
    monkeypatch.setattr(RazorpayClient, 'fetch_checkout_link', staticmethod(fetch_link))
    placed = await client.post('/api/v1/marketplace/orders/checkout', headers=auth_headers,
        json=request(address_id, payment_method='upi', idempotency_key='paid-retry-cancel-1'))
    assert placed.status_code == 201
    order_id = placed.json()['data']['id']
    link_url = f'/api/v1/marketplace/orders/{order_id}/payment-link'
    assert (await client.post(link_url, headers=auth_headers)).status_code == 200

    provider.update(status='paid', amount_paid=created['amount'] - 100,
                    payments=[{'payment_id': 'pay_live_checkout'}])
    assert (await client.post(link_url, headers=auth_headers)).status_code == 409
    order = await db_session.get(Order, uuid.UUID(order_id))
    assert order.payment_status == PaymentStatus.pending

    provider['amount_paid'] = created['amount']
    paid = await client.post(link_url, headers=auth_headers)
    assert paid.status_code == 200
    assert paid.json()['data']['payment_status'] == PaymentStatus.paid.value
    assert order.status == OrderStatus.confirmed
    contact = await db_session.get(OrderContact, order.id)
    assert contact.payment_reference == 'pay_live_checkout'

    cancel_url = f'/api/v1/marketplace/orders/{order_id}/cancel'
    requested = await client.post(cancel_url, headers=auth_headers,
        json={'reason': 'Ordered by mistake'})
    assert requested.status_code == 200
    assert requested.json()['data']['cancellation_status'] == 'REQUESTED'
    assert order.payment_status == PaymentStatus.paid
    inventory = (await db_session.scalars(select(ProductInventory).where(
        ProductInventory.product_id == item.id))).one()
    assert inventory.available_quantity == 9
    operations_url = f'/api/v1/marketplace/orders/operations/{order_id}'
    blocked = await client.put(operations_url, headers=admin_headers,
        json={'status': 'CONFIRMED'})
    assert blocked.status_code == 409

    refund_url = f'/api/v1/marketplace/orders/admin/refunds/{order_id}'
    rejected = await client.post(refund_url, headers=admin_headers,
        json={'action': 'reject', 'remarks': 'Please contact support'})
    assert rejected.status_code == 200
    assert rejected.json()['data']['cancellation_status'] == 'REJECTED'
    resumed = await client.put(operations_url, headers=admin_headers,
        json={'status': 'CONFIRMED'})
    assert resumed.status_code == 200
    requested_again = await client.post(cancel_url, headers=auth_headers,
        json={'reason': 'Still need to cancel'})
    assert requested_again.json()['data']['cancellation_status'] == 'REQUESTED'

    async def processed_refund(_):
        return {'id': 'rfnd_live_checkout', 'payment_id': 'pay_live_checkout',
                'currency': 'INR', 'amount': created['amount'], 'status': 'processed'}
    monkeypatch.setattr(RazorpayClient, 'fetch_checkout_refund', staticmethod(processed_refund))
    refunded = await client.post(refund_url, headers=admin_headers,
        json={'action': 'approve', 'refund_reference': 'rfnd_live_checkout'})
    assert refunded.status_code == 200
    assert refunded.json()['data']['cancellation_status'] == 'COMPLETED'
    assert order.status == OrderStatus.cancelled
    assert order.payment_status == PaymentStatus.refunded
    assert inventory.available_quantity == 10


@pytest.mark.asyncio
async def test_payment_provider_outage_keeps_original_link_instead_of_creating_another(
    client, db_session, vendor_user, auth_headers, monkeypatch,
):
    monkeypatch.setattr(settings, 'PRELAUNCH_MODE', False)
    monkeypatch.setattr(settings, 'RAZORPAY_KEY_ID', 'rzp_test_key')
    monkeypatch.setattr(settings, 'RAZORPAY_KEY_SECRET', 'rzp_test_secret')
    db_session.add(ServiceablePincode(
        pincode='302001', city='Jaipur', state='Rajasthan', is_serviceable=True,
    ))
    _, address_id = await cart_with_address(client, db_session, vendor_user, auth_headers)
    created = []

    async def create_link(amount, reference, name, phone):
        created.append(reference)
        return {'id': 'plink_outage', 'reference_id': reference, 'currency': 'INR',
                'amount': amount, 'short_url': 'https://rzp.io/i/outage'}

    async def fetch_link(_):
        return None

    monkeypatch.setattr(RazorpayClient, 'create_checkout_link', staticmethod(create_link))
    monkeypatch.setattr(RazorpayClient, 'fetch_checkout_link', staticmethod(fetch_link))
    placed = await client.post('/api/v1/marketplace/orders/checkout', headers=auth_headers,
        json=request(address_id, payment_method='upi', idempotency_key='link-outage-1'))
    order_id = placed.json()['data']['id']
    link_url = f'/api/v1/marketplace/orders/{order_id}/payment-link'
    assert (await client.post(link_url, headers=auth_headers)).status_code == 200
    assert (await client.post(link_url, headers=auth_headers)).status_code == 503
    assert len(created) == 1


@pytest.mark.asyncio
async def test_abandoned_unpaid_order_expires_and_releases_stock_once(
    client, db_session, vendor_user, auth_headers, monkeypatch,
):
    from app.api import orders as orders_api

    monkeypatch.setattr(settings, 'PRELAUNCH_MODE', False)
    monkeypatch.setattr(settings, 'RAZORPAY_KEY_ID', 'rzp_test_key')
    monkeypatch.setattr(settings, 'RAZORPAY_KEY_SECRET', 'rzp_test_secret')
    monkeypatch.setattr(settings, 'COMMERCE_UNPAID_ORDER_TTL_HOURS', 24)
    monkeypatch.setattr(orders_api, 'async_session_factory', TestSessionLocal)
    db_session.add(ServiceablePincode(
        pincode='302001', city='Jaipur', state='Rajasthan', is_serviceable=True,
    ))
    item, address_id = await cart_with_address(client, db_session, vendor_user, auth_headers)
    placed = await client.post('/api/v1/marketplace/orders/checkout', headers=auth_headers,
        json=request(address_id, payment_method='upi', idempotency_key='abandoned-online-1'))
    assert placed.status_code == 201
    order = await db_session.get(Order, uuid.UUID(placed.json()['data']['id']))
    order.created_at = datetime.utcnow() - timedelta(hours=25)
    await db_session.commit()

    assert await orders_api.expire_unpaid_order_once(order.id) is True
    await db_session.refresh(order)
    inventory = (await db_session.scalars(select(ProductInventory).where(
        ProductInventory.product_id == item.id))).one()
    await db_session.refresh(inventory)
    assert order.status == OrderStatus.cancelled
    assert order.payment_status == PaymentStatus.pending
    assert inventory.available_quantity == 10
    assert await orders_api.expire_unpaid_order_once(order.id) is False
    await db_session.refresh(inventory)
    assert inventory.available_quantity == 10


@pytest.mark.asyncio
async def test_abandoned_order_reconciles_paid_link_without_releasing_stock(
    client, db_session, vendor_user, auth_headers, monkeypatch,
):
    from app.api import orders as orders_api

    monkeypatch.setattr(settings, 'PRELAUNCH_MODE', False)
    monkeypatch.setattr(settings, 'RAZORPAY_KEY_ID', 'rzp_test_key')
    monkeypatch.setattr(settings, 'RAZORPAY_KEY_SECRET', 'rzp_test_secret')
    monkeypatch.setattr(settings, 'COMMERCE_UNPAID_ORDER_TTL_HOURS', 24)
    monkeypatch.setattr(orders_api, 'async_session_factory', TestSessionLocal)
    db_session.add(ServiceablePincode(
        pincode='302001', city='Jaipur', state='Rajasthan', is_serviceable=True,
    ))
    item, address_id = await cart_with_address(client, db_session, vendor_user, auth_headers)
    provider = {}

    async def create_link(amount, reference, name, phone):
        provider.update(id='plink_late_paid', reference_id=reference, currency='INR',
                        amount=amount, amount_paid=amount, status='paid',
                        payments=[{'payment_id': 'pay_late_paid'}],
                        short_url='https://rzp.io/i/late-paid')
        return provider

    async def fetch_link(_):
        return provider

    monkeypatch.setattr(RazorpayClient, 'create_checkout_link', staticmethod(create_link))
    monkeypatch.setattr(RazorpayClient, 'fetch_checkout_link', staticmethod(fetch_link))
    placed = await client.post('/api/v1/marketplace/orders/checkout', headers=auth_headers,
        json=request(address_id, payment_method='upi', idempotency_key='late-paid-1'))
    assert placed.status_code == 201
    order = await db_session.get(Order, uuid.UUID(placed.json()['data']['id']))
    assert (await client.post(f'/api/v1/marketplace/orders/{order.id}/payment-link',
                              headers=auth_headers)).status_code == 200
    order.created_at = datetime.utcnow() - timedelta(hours=25)
    await db_session.commit()

    assert await orders_api.expire_unpaid_order_once(order.id) is True
    await db_session.refresh(order)
    inventory = (await db_session.scalars(select(ProductInventory).where(
        ProductInventory.product_id == item.id))).one()
    await db_session.refresh(inventory)
    assert order.status == OrderStatus.confirmed
    assert order.payment_status == PaymentStatus.paid
    assert inventory.available_quantity == 9
