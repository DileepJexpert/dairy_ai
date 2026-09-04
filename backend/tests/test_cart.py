import uuid
from datetime import datetime, timedelta, timezone
from decimal import Decimal

import pytest
from sqlalchemy import select

from app.models.product import Product, ProductCategory, ProductInventory
from app.models.user import User, UserRole
from app.models.vendor import Vendor, VendorType
from app.services.auth_service import create_access_token


async def product(db_session, vendor_user, *, stock=10, active=True, price=Decimal("1200"), minimum=1):
    vendor = (await db_session.execute(select(Vendor).where(Vendor.user_id == vendor_user.id))).scalar_one_or_none()
    if vendor is None:
        vendor = Vendor(user_id=vendor_user.id, business_name="Cart Feeds", vendor_type=VendorType.feed_supplier)
        db_session.add(vendor); await db_session.flush()
    item = Product(vendor_id=vendor.id, sku=f"SKU-{uuid.uuid4()}", title="Mineral Mixture", slug="mineral-mixture", category=ProductCategory.feed_nutrition, base_price=price, unit="bag", is_active=active, min_order_quantity=minimum)
    db_session.add(item); await db_session.flush()
    db_session.add(ProductInventory(product_id=item.id, available_quantity=stock, reserved_quantity=0))
    await db_session.flush()
    return item


@pytest.mark.asyncio
async def test_empty_cart_is_created(client, auth_headers):
    response = await client.get('/api/v1/marketplace/cart', headers=auth_headers)
    assert response.status_code == 200
    assert response.json()['data']['items'] == []
    assert response.json()['data']['item_count'] == 0


@pytest.mark.asyncio
async def test_add_same_product_updates_quantity_and_subtotal(client, db_session, vendor_user, auth_headers):
    item = await product(db_session, vendor_user)
    for quantity in (2, 3):
        response = await client.post('/api/v1/marketplace/cart/items', headers=auth_headers, json={'product_id': str(item.id), 'quantity': quantity})
        assert response.status_code == 201
    cart = (await client.get('/api/v1/marketplace/cart', headers=auth_headers)).json()['data']
    assert cart['item_count'] == 5 and len(cart['items']) == 1
    assert Decimal(cart['subtotal']) == Decimal('6000')


@pytest.mark.asyncio
async def test_rejects_inactive_out_of_stock_and_invalid_quantity(client, db_session, vendor_user, auth_headers):
    inactive = await product(db_session, vendor_user, active=False)
    empty = await product(db_session, vendor_user, stock=0)
    for item, quantity in ((inactive, 1), (empty, 1)):
        assert (await client.post('/api/v1/marketplace/cart/items', headers=auth_headers, json={'product_id': str(item.id), 'quantity': quantity})).status_code in (404, 422)
    valid = await product(db_session, vendor_user, stock=2)
    assert (await client.post('/api/v1/marketplace/cart/items', headers=auth_headers, json={'product_id': str(valid.id), 'quantity': 0})).status_code == 422
    assert (await client.post('/api/v1/marketplace/cart/items', headers=auth_headers, json={'product_id': str(valid.id), 'quantity': 3})).status_code == 422


@pytest.mark.asyncio
async def test_update_remove_clear_and_user_isolation(client, db_session, vendor_user, auth_headers, test_user):
    item = await product(db_session, vendor_user)
    added = await client.post('/api/v1/marketplace/cart/items', headers=auth_headers, json={'product_id': str(item.id), 'quantity': 1})
    cart_item_id = added.json()['data']['id']
    assert (await client.put(f'/api/v1/marketplace/cart/items/{cart_item_id}', headers=auth_headers, json={'quantity': 4})).json()['data']['quantity'] == 4
    other = User(id=uuid.uuid4(), phone='9999988888', role=UserRole.farmer, is_active=True, otp_expires_at=datetime.now(timezone.utc) + timedelta(minutes=5))
    db_session.add(other); await db_session.flush()
    other_headers = {'Authorization': f'Bearer {create_access_token(str(other.id), other.role.value)}'}
    assert (await client.delete(f'/api/v1/marketplace/cart/items/{cart_item_id}', headers=other_headers)).status_code == 404
    assert (await client.delete(f'/api/v1/marketplace/cart/items/{cart_item_id}', headers=auth_headers)).status_code == 200
    assert (await client.delete('/api/v1/marketplace/cart', headers=auth_headers)).status_code == 200


@pytest.mark.asyncio
async def test_price_change_and_stock_validation(client, db_session, vendor_user, auth_headers):
    item = await product(db_session, vendor_user, stock=5, price=Decimal('850'))
    await client.post('/api/v1/marketplace/cart/items', headers=auth_headers, json={'product_id': str(item.id), 'quantity': 2})
    item.base_price = Decimal('900')
    inventory = (await db_session.execute(select(ProductInventory).where(ProductInventory.product_id == item.id))).scalar_one()
    inventory.available_quantity = 1
    await db_session.flush()
    cart = (await client.get('/api/v1/marketplace/cart', headers=auth_headers)).json()['data']
    assert cart['items'][0]['price_changed'] is True and Decimal(cart['subtotal']) == Decimal('1800')
    validation = (await client.post('/api/v1/marketplace/cart/validate', headers=auth_headers)).json()['data']
    assert validation['valid'] is False
    assert {issue['type'] for issue in validation['issues']} == {'INSUFFICIENT_STOCK', 'PRICE_CHANGED'}
