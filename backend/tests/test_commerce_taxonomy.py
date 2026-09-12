import uuid
import pytest
import pytest_asyncio
from sqlalchemy import select
from app.config import settings
from app.models.commerce_taxonomy import CommerceAudit, TaxonomyLock
from app.models.product import Product, ProductCategory, ProductInventory
from app.models.vendor import Vendor, VendorType


@pytest_asyncio.fixture(autouse=True)
async def enable_taxonomy(db_session, monkeypatch):
    monkeypatch.setattr(settings, "COMMERCE_TAXONOMY_ENABLED", True)
    db_session.add(TaxonomyLock(id=1))
    await db_session.flush()


async def create(client, headers, name="Dairy Foods", slug="dairy-foods", parent=None):
    response = await client.post('/api/v1/admin/commerce/taxonomy', headers=headers, json={"kind": "category" if parent else "department", "name": name, "slug": slug, "parent_id": parent})
    assert response.status_code == 201, response.text
    return response.json()['data']


def update(node, **changes):
    return {**{k: node[k] for k in ('name', 'slug', 'description', 'parent_id', 'sort_order', 'is_active')}, 'expected_version': node['version'], **changes}


@pytest.mark.asyncio
async def test_public_browsing_admin_permissions_and_revocation(client, auth_headers, vendor_headers, admin_headers, admin_user, db_session):
    assert (await client.get('/api/v1/marketplace/taxonomy')).status_code == 200
    for headers in ({}, auth_headers, vendor_headers):
        r = await client.post('/api/v1/admin/commerce/taxonomy', headers=headers, json={'kind': 'department', 'name': 'Forbidden', 'slug': 'forbidden'})
        assert r.status_code in (401, 403)
    department = await create(client, admin_headers)
    assert (await client.get('/api/v1/marketplace/taxonomy')).json()['data'][0]['id'] == department['id']
    admin_user.is_active = False
    await db_session.flush()
    assert (await client.get('/api/v1/admin/commerce/taxonomy', headers=admin_headers)).status_code == 401


@pytest.mark.asyncio
async def test_tree_validation_versions_and_audit(client, admin_headers, db_session):
    department = await create(client, admin_headers)
    category = await create(client, admin_headers, 'Ghee', 'ghee', department['id'])
    child = await create(client, admin_headers, 'Cow ghee', 'cow-ghee', category['id'])
    r = await client.put(f"/api/v1/admin/commerce/taxonomy/{category['id']}", headers=admin_headers, json=update(category, parent_id=child['id']))
    assert r.status_code == 422
    r = await client.put(f"/api/v1/admin/commerce/taxonomy/{department['id']}", headers=admin_headers, json=update(department, is_active=False))
    assert r.status_code == 409
    r = await client.put(f"/api/v1/admin/commerce/taxonomy/{child['id']}", headers=admin_headers, json=update(child, name='Cow clarified butter'))
    assert r.status_code == 200
    assert r.json()['data']['version'] == 2
    r = await client.put(f"/api/v1/admin/commerce/taxonomy/{child['id']}", headers=admin_headers, json=update(child, name='Stale write'))
    assert r.status_code == 409
    assert len((await db_session.scalars(select(CommerceAudit))).all()) == 4
    r = await client.post('/api/v1/admin/commerce/taxonomy', headers=admin_headers, json={'kind': 'department', 'name': 'Duplicate', 'slug': 'ghee'})
    assert r.status_code == 409


@pytest.mark.asyncio
async def test_archive_restore_and_invalid_payload(client, admin_headers):
    department = await create(client, admin_headers)
    r = await client.put(f"/api/v1/admin/commerce/taxonomy/{department['id']}", headers=admin_headers, json=update(department, is_active=False))
    assert r.status_code == 200
    assert (await client.get('/api/v1/marketplace/taxonomy')).json()['data'] == []
    assert len((await client.get('/api/v1/admin/commerce/taxonomy', headers=admin_headers)).json()['data']) == 1
    r = await client.post('/api/v1/admin/commerce/taxonomy', headers=admin_headers, json={'kind': 'category', 'name': 'Ghee', 'slug': 'ghee', 'parent_id': department['id']})
    assert r.status_code == 422
    r = await client.put(f"/api/v1/admin/commerce/taxonomy/{department['id']}", headers=admin_headers, json=update(department, expected_version=2, is_active=True))
    assert r.status_code == 200
    for changes in ({'name': '  '}, {'slug': 'Bad Slug'}, {'parent_id': department['id']}, {'role': 'super_admin'}):
        r = await client.post('/api/v1/admin/commerce/taxonomy', headers=admin_headers, json={'kind': 'department', 'name': 'Valid name', 'slug': 'valid-name', **changes})
        assert r.status_code == 422


@pytest.mark.asyncio
async def test_classification_filtering_preserves_product_and_counts(client, admin_headers, vendor_user, db_session):
    vendor_profile = Vendor(user_id=vendor_user.id, business_name='Test seller', vendor_type=VendorType.feed_supplier)
    db_session.add(vendor_profile)
    await db_session.flush()
    department = await create(client, admin_headers)
    category = await create(client, admin_headers, 'Ghee', 'ghee', department['id'])
    product = Product(id=uuid.uuid4(), vendor_id=vendor_profile.id, sku='FIXTURE-GHEE', title='Name unrelated to category', slug='fixture-ghee', category=ProductCategory.feed_nutrition, base_price=100, unit='pack', is_active=True)
    db_session.add(product)
    await db_session.flush()
    db_session.add(ProductInventory(product_id=product.id, available_quantity=4, reserved_quantity=0))
    await db_session.flush()
    r = await client.put(f'/api/v1/admin/commerce/catalogue/{product.id}/category', headers=admin_headers, json={'category_id': category['id']})
    assert r.status_code == 200, r.text
    r = await client.get('/api/v1/marketplace/products', params={'taxonomy_id': department['id'], 'in_stock': True, 'per_page': 1})
    assert r.json()['total'] == 1
    assert r.json()['data'][0]['id'] == str(product.id)
    assert r.json()['data'][0]['taxonomy']['category_name'] == 'Ghee'
    assert (await client.get('/api/v1/marketplace/products', params={'in_stock': False})).json()['total'] == 0
    r = await client.put(f"/api/v1/admin/commerce/taxonomy/{category['id']}", headers=admin_headers, json=update(category, is_active=False))
    assert r.status_code == 409
    r = await client.put(f'/api/v1/admin/commerce/catalogue/{product.id}/category', headers=admin_headers, json={'category_id': category['id'], 'expected_version': 0})
    assert r.status_code == 409


@pytest.mark.asyncio
async def test_disabled_rollout_does_not_break_legacy_catalogue(client, admin_headers, monkeypatch):
    monkeypatch.setattr(settings, 'COMMERCE_TAXONOMY_ENABLED', False)
    assert (await client.get('/api/v1/marketplace/taxonomy')).json() == {'success': True, 'enabled': False, 'data': []}
    assert (await client.get('/api/v1/marketplace/products')).status_code == 200
    assert (await client.get('/api/v1/admin/commerce/taxonomy', headers=admin_headers)).status_code == 503


@pytest.mark.asyncio
async def test_public_catalogue_can_resolve_a_product_by_sku(client, vendor_user, db_session):
    vendor = Vendor(user_id=vendor_user.id, business_name='Milterra', vendor_type=VendorType.feed_supplier)
    db_session.add(vendor)
    await db_session.flush()
    product = Product(
        id=uuid.uuid4(), vendor_id=vendor.id, sku='MIL-GHEE-500',
        title='Milterra A2 Desi Cow Ghee', slug='mil-ghee-500',
        category=ProductCategory.feed_nutrition, base_price=799, unit='jar',
        is_active=True,
    )
    db_session.add(product)
    await db_session.flush()
    db_session.add(ProductInventory(product_id=product.id, available_quantity=4, reserved_quantity=0))
    await db_session.flush()

    response = await client.get('/api/v1/marketplace/products', params={'sku': 'MIL-GHEE-500'})
    assert response.status_code == 200
    assert response.json()['total'] == 1
    assert response.json()['data'][0]['id'] == str(product.id)
