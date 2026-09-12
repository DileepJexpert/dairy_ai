import uuid
import pytest
from datetime import datetime, timedelta
from decimal import Decimal
from sqlalchemy import select

from app.models.cart import Cart, CartItem, CartStatus
from app.models.product import Product, ProductCategory, ProductInventory
from app.models.user import User, UserRole
from app.models.vendor import Vendor, VendorType


@pytest.mark.asyncio
async def test_register_visit(client):
    res = await client.post(
        "/api/v1/analytics/visit",
        json={
            "session_id": f"sess-{uuid.uuid4()}",
            "city": "Mumbai",
            "state": "Maharashtra",
            "country": "India",
            "referrer": "https://wa.me/share",
            "utm_source": "whatsapp",
            "landing_page": "/shop",
        },
    )
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    assert body["data"]["city"] == "Mumbai"


@pytest.mark.asyncio
async def test_ingest_clickstream_events(client):
    sess_id = f"sess-{uuid.uuid4()}"
    res = await client.post(
        "/api/v1/analytics/events",
        json={
            "events": [
                {
                    "session_id": sess_id,
                    "event_type": "PAGE_VIEW",
                    "page_url": "/shop",
                    "element_text": "Storefront",
                },
                {
                    "session_id": sess_id,
                    "event_type": "PRODUCT_VIEW",
                    "page_url": "/shop/product/ghee",
                    "element_text": "Desi Cow Ghee 1L",
                    "metadata": {"price": 1499},
                },
            ]
        },
    )
    assert res.status_code == 200
    assert res.json()["data"]["processed"] == 2


@pytest.mark.asyncio
async def test_admin_traffic_summary(client, admin_headers):
    res = await client.get("/api/v1/admin/ecommerce/analytics/traffic", headers=admin_headers)
    assert res.status_code == 200
    data = res.json()["data"]
    assert "total_visitors" in data
    assert "top_cities" in data
    assert "top_referrers" in data


@pytest.mark.asyncio
async def test_admin_clickstream_timeline(client, admin_headers):
    sess_id = f"sess-test-{uuid.uuid4()}"
    await client.post(
        "/api/v1/analytics/events",
        json={
            "events": [
                {
                    "session_id": sess_id,
                    "event_type": "SEARCH_QUERY",
                    "page_url": "/shop",
                    "element_text": "Search: Paneer",
                }
            ]
        },
    )

    res = await client.get(
        f"/api/v1/admin/ecommerce/analytics/clickstream?session_id={sess_id}",
        headers=admin_headers,
    )
    assert res.status_code == 200
    events = res.json()["data"]
    assert len(events) >= 1
    assert events[0]["event_type"] == "SEARCH_QUERY"


@pytest.mark.asyncio
async def test_admin_carts_and_nudge(client, db_session, admin_headers, test_user, vendor_user):
    # Setup a product and a cart
    vendor = Vendor(user_id=vendor_user.id, business_name="Milterra Sourcing", vendor_type=VendorType.feed_supplier)
    db_session.add(vendor)
    await db_session.flush()

    prod = Product(
        vendor_id=vendor.id,
        sku=f"SKU-TEST-{uuid.uuid4()}",
        title="Milterra Test Ghee",
        slug="test-ghee",
        category=ProductCategory.feed_nutrition,
        base_price=Decimal("799.00"),
        unit="jar",
        is_active=True,
    )
    db_session.add(prod)
    await db_session.flush()
    db_session.add(ProductInventory(product_id=prod.id, available_quantity=20))
    await db_session.flush()

    cart = Cart(
        id=uuid.uuid4(),
        user_id=test_user.id,
        status=CartStatus.active,
        created_at=datetime.utcnow() - timedelta(hours=3),
        updated_at=datetime.utcnow() - timedelta(hours=2),
    )
    db_session.add(cart)
    await db_session.flush()

    db_session.add(CartItem(
        cart_id=cart.id,
        product_id=prod.id,
        quantity=2,
        price_when_added=Decimal("799.00"),
        created_at=datetime.utcnow() - timedelta(hours=3),
        updated_at=datetime.utcnow() - timedelta(hours=2),
    ))
    await db_session.commit()

    # Query admin carts
    res = await client.get("/api/v1/admin/ecommerce/carts", headers=admin_headers)
    assert res.status_code == 200
    carts = res.json()["data"]
    matching_cart = next((c for c in carts if c["cart_id"] == str(cart.id)), None)
    assert matching_cart is not None
    assert matching_cart["user_phone"] == test_user.phone
    assert matching_cart["is_abandoned"] is True
    assert matching_cart["item_count"] == 2
    assert Decimal(matching_cart["subtotal"]) == Decimal("1598.00")

    # Trigger nudge
    nudge_res = await client.post(f"/api/v1/admin/ecommerce/carts/{cart.id}/nudge", headers=admin_headers)
    assert nudge_res.status_code == 200
    nudge_data = nudge_res.json()["data"]
    assert "whatsapp_link" in nudge_data
    assert "RECOVER10" in nudge_data["whatsapp_link"]
