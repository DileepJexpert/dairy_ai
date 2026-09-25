"""Shipping guards and courier retry behavior; no live carrier calls."""
import uuid
from decimal import Decimal

import pytest
from sqlalchemy import select

from app.api import shipment_tracking as shipping
from app.config import settings
from app.integrations.delhivery_shipping import BookingUncertain, CourierQuote
from app.integrations.shipping_policy import select_quote
from app.models.order import FulfillmentStatus, Order, OrderItem, PaymentStatus
from app.models.shipping import Shipment, ShipmentEvent
from app.models.serviceable_pincode import ServiceablePincode
from app.models.user import User, UserRole
from app.services.auth_service import create_access_token
from tests.conftest import TestSessionLocal
from tests.test_cart import product
from tests.test_delivery_addresses import address


def test_quote_policy_uses_cost_eta_and_ceiling(monkeypatch):
    class Provider:
        def __init__(self, code):
            self.code = code

    cheap, fast = Provider("cheap"), Provider("fast")
    offers = [(cheap, CourierQuote("cheap", "Cheap", Decimal("80"), 4)),
              (fast, CourierQuote("fast", "Fast", Decimal("110"), 2))]
    monkeypatch.setattr(settings, "SHIPPING_MAX_COURIER_COST", 0)
    monkeypatch.setattr(settings, "SHIPPING_MAX_DELIVERY_DAYS", 0)
    monkeypatch.setattr(settings, "SHIPPING_SELECTION_STRATEGY", "lowest_cost")
    assert select_quote(offers)[0] is cheap
    monkeypatch.setattr(settings, "SHIPPING_SELECTION_STRATEGY", "fastest")
    assert select_quote(offers)[0] is fast
    monkeypatch.setattr(settings, "SHIPPING_MAX_COURIER_COST", 100)
    assert select_quote(offers)[0] is cheap
    monkeypatch.setattr(settings, "SHIPPING_MAX_DELIVERY_DAYS", 3)
    assert select_quote(offers) is None


async def make_order(client, db_session, vendor_user, auth_headers, monkeypatch, *, prelaunch=False):
    monkeypatch.setattr(settings, "PRELAUNCH_MODE", prelaunch)
    monkeypatch.setattr(settings, "RAZORPAY_KEY_ID", "rzp_test")
    monkeypatch.setattr(settings, "RAZORPAY_KEY_SECRET", "test-secret")
    if await db_session.get(ServiceablePincode, "302001") is None:
        db_session.add(ServiceablePincode(
            pincode="302001", city="Jaipur", state="Rajasthan", is_serviceable=True))
        await db_session.flush()
    item = await product(db_session, vendor_user)
    item.weight_grams = 500
    delivery = (await client.post("/api/v1/marketplace/addresses", headers=auth_headers, json=address())).json()["data"]
    await client.post("/api/v1/marketplace/cart/items", headers=auth_headers, json={"product_id": str(item.id), "quantity": 1})
    response = await client.post("/api/v1/marketplace/orders/checkout", headers=auth_headers, json={
        "delivery_address_id": delivery["id"], "idempotency_key": str(uuid.uuid4()), "payment_method": "upi",
    })
    assert response.status_code == 201, response.text
    return uuid.UUID(response.json()["data"]["id"])


@pytest.mark.asyncio
async def test_tracking_is_owned_and_never_invents_a_courier(client, db_session, vendor_user, auth_headers, admin_headers, monkeypatch):
    order_id = await make_order(client, db_session, vendor_user, auth_headers, monkeypatch, prelaunch=True)
    url = f"/api/v1/marketplace/orders/{order_id}/tracking"
    response = await client.get(url, headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["data"]["status"] == "NOT_PREPARED"
    assert response.json()["data"]["awb"] is None
    assert response.json()["data"]["checkpoints"] == []
    assert (await client.get(url)).status_code in {401, 403}
    other = User(phone="9999966666", role=UserRole.farmer, is_active=True)
    db_session.add(other)
    await db_session.flush()
    other_auth = {"Authorization": f"Bearer {create_access_token(str(other.id), other.role.value)}"}
    assert (await client.get(url, headers=other_auth)).status_code == 404
    assert (await client.post(f"/api/v1/marketplace/orders/{order_id}/shipping/prepare", headers=admin_headers,
        json={"weight_grams": 500, "length_cm": 20, "width_cm": 10, "height_cm": 10})).status_code == 409
    assert (await db_session.execute(select(Shipment))).scalars().first() is None


@pytest.mark.asyncio
async def test_packed_order_can_be_prepared_then_dispatched_manually(client, db_session, vendor_user, auth_headers, admin_headers, monkeypatch):
    order_id = await make_order(client, db_session, vendor_user, auth_headers, monkeypatch)
    order = await db_session.get(Order, order_id)
    order.payment_status = PaymentStatus.paid
    await db_session.commit()
    url = f"/api/v1/marketplace/orders/operations/{order_id}"
    for stage in ("CONFIRMED", "PACKED"):
        response = await client.put(url, headers=admin_headers, json={"status": stage})
        assert response.status_code == 200, response.text
    shipment = (await db_session.execute(select(Shipment).where(Shipment.order_id == order_id))).scalar_one()
    assert shipment.status == "needs_package"
    package = {"weight_grams": 750, "length_cm": 20, "width_cm": 15, "height_cm": 12}
    ready = await client.post(f"/api/v1/marketplace/orders/{order_id}/shipping/prepare", headers=admin_headers, json=package)
    assert ready.status_code == 200 and ready.json()["data"]["status"] == "READY"
    assert (await client.put(url, headers=admin_headers, json={"status": "OUT_FOR_DELIVERY"})).status_code == 422
    dispatched = await client.put(url, headers=admin_headers, json={"status": "DISPATCHED", "carrier": "Blue Dart", "tracking_number": "REAL-123"})
    assert dispatched.status_code == 200, dispatched.text
    again = await client.put(url, headers=admin_headers, json={"status": "DISPATCHED", "carrier": "Blue Dart", "tracking_number": "REAL-123"})
    assert again.status_code == 200
    shipment = (await db_session.execute(select(Shipment).where(Shipment.order_id == order_id))).scalar_one()
    assert shipment.mode == "manual" and shipment.awb == "REAL-123"
    assert (await client.get(f"/api/v1/marketplace/orders/{order_id}/tracking", headers=auth_headers)).json()["data"]["awb"] == "REAL-123"
    delivered = await client.put(url, headers=admin_headers, json={"status": "DELIVERED"})
    assert delivered.status_code == 200
    tracking = (await client.get(f"/api/v1/marketplace/orders/{order_id}/tracking", headers=auth_headers)).json()["data"]
    assert tracking["status"] == "DELIVERED"
    assert [checkpoint["status"] for checkpoint in tracking["checkpoints"]] == ["DISPATCHED", "DELIVERED"]


class FakeCourier:
    code = "delhivery"
    name = "Delhivery"
    configured = True
    calls = 0
    uncertain = False
    scans = []

    async def quote(self, destination_pin, grams, cod):
        assert destination_pin == "302001" and grams == 750 and not cod
        return CourierQuote("delhivery", "Delhivery", Decimal("82.50"))

    async def book(self, order, address, names, package, method):
        self.calls += 1
        if self.uncertain:
            raise BookingUncertain("Result unknown")
        return "REAL-DELHIVERY-AWB"

    async def request_pickup(self, count):
        assert count == 1

    async def track(self, awb):
        assert awb == "REAL-DELHIVERY-AWB"
        return self.scans

    async def label_pdf(self, awb):
        assert awb == "REAL-DELHIVERY-AWB"
        return b"%PDF-1.4\nlabel"


@pytest.mark.asyncio
@pytest.mark.parametrize("uncertain", [False, True])
async def test_automatic_booking_claim_is_idempotent_and_uncertain_results_stop(client, db_session, vendor_user, auth_headers, admin_headers, monkeypatch, uncertain):
    order_id = await make_order(client, db_session, vendor_user, auth_headers, monkeypatch)
    order = await db_session.get(Order, order_id)
    order.payment_status = PaymentStatus.paid
    await db_session.commit()
    url = f"/api/v1/marketplace/orders/operations/{order_id}"
    for stage in ("CONFIRMED", "PACKED"):
        assert (await client.put(url, headers=admin_headers, json={"status": stage})).status_code == 200
    await client.post(f"/api/v1/marketplace/orders/{order_id}/shipping/prepare", headers=admin_headers,
                      json={"weight_grams": 750, "length_cm": 20, "width_cm": 15, "height_cm": 12})
    await db_session.commit()
    monkeypatch.setattr(shipping, "async_session_factory", TestSessionLocal)
    monkeypatch.setattr(settings, "SHIPPING_AUTO_BOOK_ENABLED", True)
    courier = FakeCourier()
    courier.uncertain = uncertain
    assert await shipping.process_ready_once(courier) is True
    assert await shipping.process_ready_once(courier) is False
    assert courier.calls == 1
    db_session.expire_all()
    booked = (await db_session.execute(select(Shipment).where(Shipment.order_id == order_id))).scalar_one()
    assert booked.status == ("needs_attention" if uncertain else "booked")
    assert booked.awb == (None if uncertain else "REAL-DELHIVERY-AWB")
    if uncertain:
        assert (await client.put(url, headers=admin_headers,
                json={"status": "DISPATCHED", "carrier": "Blue Dart", "tracking_number": "OTHER-AWB"})).status_code == 409
        resolved = await client.post(f"/api/v1/marketplace/orders/{order_id}/shipping/resolve", headers=admin_headers,
                                     json={"action": "no_booking", "note": "Checked Delhivery portal; no booking exists"})
        assert resolved.status_code == 200 and resolved.json()["data"]["status"] == "MANUAL_PENDING"
        manual = await client.put(url, headers=admin_headers,
                                  json={"status": "DISPATCHED", "carrier": "Blue Dart", "tracking_number": "OTHER-AWB"})
        assert manual.status_code == 200 and courier.calls == 1
    if not uncertain:
        monkeypatch.setattr(shipping, "DelhiveryShipping", lambda: courier)
        label = await client.get(f"/api/v1/marketplace/orders/{order_id}/shipping/label", headers=admin_headers)
        assert label.status_code == 200 and label.content.startswith(b"%PDF")
        assert (await client.get(f"/api/v1/marketplace/orders/{order_id}/shipping/label", headers=auth_headers)).status_code == 403
        await db_session.commit()
        courier.scans = [{"key": "scan-1", "status": "In Transit", "description": "Picked up",
                          "location": "Noida", "occurred_at": "2026-09-24T08:00:00"}]
        assert await shipping.poll_tracking_once(courier) is True
        async with TestSessionLocal() as check:
            shipment = (await check.execute(select(Shipment).where(Shipment.order_id == order_id))).scalar_one()
            assert shipment.status == "in_transit"
            assert (await check.execute(select(OrderItem).where(OrderItem.order_id == order_id))).scalar_one().fulfillment_status == FulfillmentStatus.shipped
            shipment.last_tracking_at = None
            await check.commit()
        assert await shipping.poll_tracking_once(courier) is True
        async with TestSessionLocal() as check:
            assert len((await check.execute(select(ShipmentEvent))).scalars().all()) == 1


@pytest.mark.asyncio
async def test_refund_during_quote_cannot_overtake_courier_booking(
    client, db_session, vendor_user, auth_headers, admin_headers, monkeypatch,
):
    order_id = await make_order(client, db_session, vendor_user, auth_headers, monkeypatch)
    order = await db_session.get(Order, order_id)
    order.payment_status = PaymentStatus.paid
    await db_session.commit()
    for stage in ("CONFIRMED", "PACKED"):
        response = await client.put(
            f"/api/v1/marketplace/orders/operations/{order_id}",
            headers=admin_headers, json={"status": stage},
        )
        assert response.status_code == 200
    prepared = await client.post(
        f"/api/v1/marketplace/orders/{order_id}/shipping/prepare",
        headers=admin_headers,
        json={"weight_grams": 750, "length_cm": 20, "width_cm": 15, "height_cm": 12},
    )
    assert prepared.status_code == 200
    await db_session.commit()

    class RefundDuringQuote(FakeCourier):
        async def quote(self, *args):
            refund = await client.post(
                f"/api/v1/marketplace/orders/admin/refunds/{order_id}",
                headers=admin_headers,
                json={"action": "approve", "restock_inventory": True},
            )
            assert refund.status_code == 409
            return CourierQuote(self.code, self.name, Decimal("80"))

    monkeypatch.setattr(shipping, "async_session_factory", TestSessionLocal)
    monkeypatch.setattr(settings, "SHIPPING_AUTO_BOOK_ENABLED", True)
    courier = RefundDuringQuote()
    assert await shipping.process_ready_once(courier) is True
    db_session.expire_all()
    assert (await db_session.get(Order, order_id)).payment_status == PaymentStatus.paid
    shipment = (await db_session.scalars(select(Shipment).where(
        Shipment.order_id == order_id))).one()
    assert shipment.status == "booked" and shipment.awb == "REAL-DELHIVERY-AWB"


@pytest.mark.asyncio
async def test_active_booking_cannot_be_resolved_as_missing(
    client, db_session, vendor_user, auth_headers, admin_headers, monkeypatch,
):
    order_id = await make_order(client, db_session, vendor_user, auth_headers, monkeypatch)
    order = await db_session.get(Order, order_id)
    order.payment_status = PaymentStatus.paid
    await db_session.commit()
    for stage in ("CONFIRMED", "PACKED"):
        response = await client.put(
            f"/api/v1/marketplace/orders/operations/{order_id}",
            headers=admin_headers, json={"status": stage},
        )
        assert response.status_code == 200
    prepared = await client.post(
        f"/api/v1/marketplace/orders/{order_id}/shipping/prepare",
        headers=admin_headers,
        json={"weight_grams": 750, "length_cm": 20, "width_cm": 15, "height_cm": 12},
    )
    assert prepared.status_code == 200
    await db_session.commit()

    class ResolveDuringBook(FakeCourier):
        async def book(self, *args):
            recovery = await client.post(
                f"/api/v1/marketplace/orders/{order_id}/shipping/resolve",
                headers=admin_headers,
                json={"action": "no_booking", "note": "Portal search found nothing yet"},
            )
            assert recovery.status_code == 409
            return "REAL-DELHIVERY-AWB"

    monkeypatch.setattr(shipping, "async_session_factory", TestSessionLocal)
    monkeypatch.setattr(settings, "SHIPPING_AUTO_BOOK_ENABLED", True)
    assert await shipping.process_ready_once(ResolveDuringBook()) is True
    db_session.expire_all()
    shipment = (await db_session.scalars(select(Shipment).where(
        Shipment.order_id == order_id))).one()
    assert shipment.status == "booked" and shipment.awb == "REAL-DELHIVERY-AWB"
