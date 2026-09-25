"""The public snapshot must not leak unpublished offers or private seller data."""

import uuid
from decimal import Decimal
import hashlib
import json

import pytest

from app.models.product import (
    MediaType, Product, ProductCategory, ProductFamily, ProductInventory,
    ProductMedia, ProductReview,
)
from app.models.user import User, UserRole
from app.models.vendor import Vendor, VendorType
from scripts.export_static_catalogue import (
    _public_media_url, build_snapshot,
)


def _product(vendor_id, *, family_id=None, sku="MIL-TEST-1", status="published", active=True):
    return Product(
        id=uuid.uuid4(), vendor_id=vendor_id, family_id=family_id,
        sku=sku, title=f"Product {sku}", slug=sku.lower(),
        category=ProductCategory.feed_nutrition, base_price=Decimal("123.45"),
        compare_at_price=Decimal("150.00"), unit="pack", pack_size="500 g",
        publication_status=status, is_active=active, min_order_quantity=1,
        specifications={
            "Milk Source": "A2 cow milk",
            "badge": "Fresh",
            "api_key": "never-publish-this",
            "bank_account": "never-publish-this-either",
            "supplier_cost": "never-publish",
            "rating": "5.0 synthetic",
            "private_details": {"phone": "9000000000"},
        },
    )


@pytest.mark.asyncio
async def test_snapshot_is_public_stable_and_uses_exact_prices(db_session):
    seller_user = User(id=uuid.uuid4(), phone="9999999801", role=UserRole.vendor)
    hidden_user = User(id=uuid.uuid4(), phone="9999999802", role=UserRole.vendor)
    seller = Vendor(
        id=uuid.uuid4(), user_id=seller_user.id, business_name="Milterra",
        vendor_type=VendorType.feed_supplier, is_active=True,
        account_number="SECRET-BANK-ACCOUNT", support_phone="9999999801",
    )
    hidden_seller = Vendor(
        id=uuid.uuid4(), user_id=hidden_user.id, business_name="Hidden seller",
        vendor_type=VendorType.feed_supplier, is_active=False,
    )
    family = ProductFamily(
        id=uuid.uuid4(), vendor_id=seller.id, slug="test-family", title="Test family",
        is_published=True, supporting_documents={
            "primary_image": "assets/store/example.jpg",
            "internal_contract": "PRIVATE-CONTRACT",
        },
    )
    hidden_family = ProductFamily(
        id=uuid.uuid4(), vendor_id=seller.id, slug="hidden-family", title="Hidden family",
        is_published=False,
    )
    concept = ProductFamily(
        id=uuid.uuid4(), vendor_id=seller.id, slug="concept-family", title="Concept family",
        is_published=True, is_concept=True,
    )
    public = _product(seller.id, family_id=family.id)
    draft = _product(seller.id, sku="MIL-DRAFT", status="draft")
    inactive = _product(seller.id, sku="MIL-INACTIVE", active=False)
    family_hidden = _product(seller.id, family_id=hidden_family.id, sku="MIL-HIDDEN-FAMILY")
    seller_hidden = _product(hidden_seller.id, sku="MIL-HIDDEN-SELLER")
    db_session.add_all([
        seller_user, hidden_user, seller, hidden_seller, family, hidden_family,
        concept, public, draft, inactive, family_hidden, seller_hidden,
    ])
    await db_session.flush()
    upload_id = uuid.uuid4()
    db_session.add_all([
        ProductMedia(
            id=uuid.uuid4(), product_id=public.id, media_type=MediaType.image,
            url=f"/api/v1/marketplace/media/{upload_id}", is_primary=True,
            sort_order=0,
        ),
        ProductInventory(product_id=public.id, available_quantity=99, reserved_quantity=4),
        ProductReview(
            product_id=public.id, author_name="Customer", rating=5,
            headline="Good", content="Good product", is_approved=True,
        ),
    ])
    await db_session.flush()

    prefix = "https://media.example.com/product-media/"
    first = await build_snapshot(db_session, prefix)
    second = await build_snapshot(db_session, prefix)
    assert first == second
    assert [p["id"] for p in first["products"]] == [str(public.id)]
    assert [f["slug"] for f in first["families"]] == ["concept-family", "test-family"]
    row = first["products"][0]
    assert row["base_price"] == "123.45"
    assert row["compare_at_price"] == "150.00"
    assert row["media"][0]["url"] == f"https://media.example.com/product-media/{upload_id}.jpg"
    assert "in_stock" not in row and "available_quantity" not in row
    assert row["specifications"] == {"Milk Source": "A2 cow milk", "badge": "Fresh"}
    assert set(row["vendor"]) == {"id", "business_name"}
    assert "SECRET-BANK-ACCOUNT" not in str(first)
    assert "PRIVATE-CONTRACT" not in str(first)
    assert len(first["families"][0]["variants"]) == 0
    assert [v["id"] for v in first["families"][1]["variants"]] == [str(public.id)]

    canonical = json.dumps(
        {key: value for key, value in first.items() if key != "content_sha256"},
        sort_keys=True, separators=(",", ":"), ensure_ascii=False,
    ).encode("utf-8")
    assert hashlib.sha256(canonical).hexdigest() == first["content_sha256"]

    public.base_price = Decimal("124.00")
    await db_session.flush()
    changed = await build_snapshot(db_session, prefix)
    assert changed["content_sha256"] != first["content_sha256"]


@pytest.mark.asyncio
async def test_uploaded_media_cannot_create_backend_dependent_snapshot(db_session):
    user = User(id=uuid.uuid4(), phone="9999999803", role=UserRole.vendor)
    seller = Vendor(id=uuid.uuid4(), user_id=user.id, business_name="Milterra", vendor_type=VendorType.feed_supplier)
    product = _product(seller.id)
    db_session.add_all([user, seller, product])
    await db_session.flush()
    db_session.add(ProductMedia(
        product_id=product.id, media_type=MediaType.image,
        url=f"/api/v1/marketplace/media/{uuid.uuid4()}",
    ))
    await db_session.flush()
    with pytest.raises(ValueError, match="requires --public-media-base-url"):
        await build_snapshot(db_session)


@pytest.mark.parametrize("unsafe", [
    "http://example.com/image.jpg",
    "https://example.com/image.jpg?signature=secret",
    "assets/../secret.jpg",
    "//example.com/image.jpg",
    "/api/v1/marketplace/media/not-a-uuid",
])
def test_unstable_or_unsafe_media_rejected(unsafe):
    with pytest.raises(ValueError):
        _public_media_url(unsafe, "https://media.example.com/product-media")
