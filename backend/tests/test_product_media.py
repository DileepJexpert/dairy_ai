import io
import uuid

import pytest
from PIL import Image
from sqlalchemy import select

from app.config import settings
from app.models.product import ProductMedia, ProductFamily, MediaType
from app.models.vendor import Vendor
from tests.test_cart import product


def png():
    buffer = io.BytesIO()
    Image.new('RGB', (32, 24), 'green').save(buffer, format='PNG')
    return buffer.getvalue()


@pytest.fixture(autouse=True)
def local_media(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, 'PRODUCT_MEDIA_DIR', str(tmp_path / 'images'))
    return tmp_path / 'images'


async def upload(client, p, headers, raw=None):
    return await client.post(f'/api/v1/vendor/products/{p.id}/images', headers={**headers, 'Content-Type': 'application/octet-stream'}, content=png() if raw is None else raw)


@pytest.mark.asyncio
async def test_upload_persists_and_public_gallery_uses_it(client, db_session, vendor_user, vendor_headers, local_media):
    p = await product(db_session, vendor_user)
    pid = p.id
    uploaded = await upload(client, p, vendor_headers, png() + b'<script>ignored trailing payload</script>')
    assert uploaded.status_code == 201, uploaded.text
    row = uploaded.json()['data']
    assert row['is_primary'] is True
    await db_session.commit()
    db_session.expire_all()
    detail = (await client.get(f'/api/v1/marketplace/products/{pid}')).json()['data']
    assert detail['media'][0]['url'] == row['url']
    response = await client.get(row['url'])
    assert response.status_code == 200
    assert response.headers['content-type'] == 'image/jpeg'
    assert b'<script>' not in response.content
    assert response.headers['x-content-type-options'] == 'nosniff'
    assert Image.open(io.BytesIO(response.content)).size == (32, 24)
    assert len(list(local_media.glob('*.jpg'))) == 1


@pytest.mark.asyncio
async def test_roles_drafts_and_suspension(client, db_session, vendor_user, vendor_headers, auth_headers, test_user, admin_headers):
    p = await product(db_session, vendor_user)
    other = await product(db_session, test_user)
    assert (await upload(client, p, auth_headers)).status_code == 403
    assert (await upload(client, other, vendor_headers)).status_code == 403
    other_image = (await upload(client, other, admin_headers)).json()['data']
    other_base = f"/api/v1/vendor/products/{other.id}/media/{other_image['id']}"
    assert (await client.put(f'{other_base}/primary', headers=vendor_headers)).status_code == 403
    assert (await client.delete(other_base, headers=vendor_headers)).status_code == 403
    p.publication_status = 'draft'
    await db_session.flush()
    uploaded = (await upload(client, p, admin_headers)).json()['data']
    assert (await client.get(uploaded['url'])).status_code == 404
    preview = f"/api/v1/vendor/products/{p.id}/media/{uploaded['id']}/preview"
    assert (await client.get(preview, headers=vendor_headers)).status_code == 200
    assert (await client.get(preview, headers=auth_headers)).status_code == 403
    assert (await client.get(preview)).status_code in (401, 403)
    p.publication_status = 'published'
    await db_session.flush()
    assert (await client.get(uploaded['url'])).status_code == 200
    vendor = await db_session.get(Vendor, p.vendor_id)
    vendor.is_active = False
    await db_session.flush()
    assert (await upload(client, p, vendor_headers)).status_code == 403
    assert (await client.get(uploaded['url'])).status_code == 404


@pytest.mark.asyncio
async def test_primary_remove_and_shared_offer_reference(client, db_session, vendor_user, vendor_headers, admin_headers, test_user):
    p = await product(db_session, vendor_user)
    first = (await upload(client, p, vendor_headers)).json()['data']
    second = (await upload(client, p, vendor_headers)).json()['data']
    base = f'/api/v1/vendor/products/{p.id}/media'
    assert (await client.put(f"{base}/{second['id']}/primary", headers=vendor_headers)).status_code == 200
    rows = (await client.get(base, headers=vendor_headers)).json()['data']
    assert rows[0]['id'] == second['id'] and sum(x['is_primary'] for x in rows) == 1
    other = await product(db_session, test_user)
    db_session.add(ProductMedia(product_id=other.id, url=second['url'], media_type=MediaType.image))
    await db_session.flush()
    for _ in range(2):
        assert (await client.delete(f"{base}/{second['id']}", headers=vendor_headers)).status_code == 200
    assert (await client.get(second['url'])).status_code == 200  # other offer still references it
    rows = (await client.get(base, headers=vendor_headers)).json()['data']
    assert len(rows) == 1 and rows[0]['id'] == first['id'] and rows[0]['is_primary']
    assert (await client.delete(f"{base}/{first['id']}", headers=admin_headers)).status_code == 200
    assert (await client.get(first['url'])).status_code == 404


@pytest.mark.asyncio
@pytest.mark.parametrize('raw,status', [(b'', 422), (b'<svg><script>bad</script></svg>', 422), (b'x' * (5 * 1024 * 1024 + 1), 413)], ids=['empty', 'svg', 'oversized'])
async def test_invalid_upload_has_no_records_or_files(client, db_session, vendor_user, vendor_headers, raw, status, local_media):
    p = await product(db_session, vendor_user)
    assert (await upload(client, p, vendor_headers, raw)).status_code == status
    assert not list((await db_session.execute(select(ProductMedia))).scalars())
    assert not local_media.exists()


@pytest.mark.asyncio
async def test_limits_and_reserved_references(client, db_session, vendor_user, vendor_headers):
    p = await product(db_session, vendor_user)
    base = f'/api/v1/vendor/products/{p.id}/media'
    assert (await client.post(base, headers=vendor_headers, json={'url': f'/api/v1/marketplace/media/{uuid.uuid4()}'})).status_code == 422
    for i in range(12):
        db_session.add(ProductMedia(product_id=p.id, url=f'https://example.test/{i}.jpg', media_type=MediaType.image))
    await db_session.flush()
    assert (await upload(client, p, vendor_headers)).status_code == 422
    assert (await client.post(base, headers=vendor_headers, json={'url': 'https://example.test/13.jpg'})).status_code == 422


@pytest.mark.asyncio
async def test_unpublished_family_hides_images(client, db_session, vendor_user, vendor_headers):
    p = await product(db_session, vendor_user)
    family = ProductFamily(vendor_id=p.vendor_id, title='Private concept', slug='private-concept', is_published=False, is_concept=True)
    db_session.add(family)
    await db_session.flush()
    p.family_id = family.id
    row = (await upload(client, p, vendor_headers)).json()['data']
    assert (await client.get(row['url'])).status_code == 404


@pytest.mark.asyncio
async def test_pixel_limit_and_truncated_image(client, db_session, vendor_user, vendor_headers, monkeypatch):
    from app.api import product_media
    p = await product(db_session, vendor_user)
    monkeypatch.setattr(product_media, 'MAX_PIXELS', 500)
    assert (await upload(client, p, vendor_headers)).status_code == 422
    assert (await upload(client, p, vendor_headers, png()[:20])).status_code == 422
