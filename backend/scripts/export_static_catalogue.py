"""Publish a deterministic, public-only snapshot of the live product catalogue.

Run from ``backend`` after migrations and product/media publication:

    python -m scripts.export_static_catalogue --output ../mobile/assets/catalogue/products.json \
        --public-media-base-url https://media.example.com/product-media/

The database remains authoritative for price, stock, availability, and checkout.
This file is for browsing only; it deliberately contains no stock quantities.
"""

from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import math
import os
import re
import tempfile
import uuid
from collections import defaultdict
from decimal import Decimal
from pathlib import Path
from urllib.parse import urlsplit

from sqlalchemy import or_, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import async_session_factory
from app.models.product import Product, ProductFamily, ProductMedia
from app.models.vendor import Vendor
from app.services import commerce_taxonomy_service as taxonomy


SCHEMA_VERSION = 1
_LOCAL_MEDIA_PREFIX = "/api/v1/marketplace/media/"
_PRIVATE_SPEC_KEYS = re.compile(
    r"(?:password|secret|token|credential|api.?key|webhook|bank|account|ifsc|"
    r"phone|mobile|email|address|otp|private|internal|audit|payment|upi.?id|"
    r"supplier|purchase|wholesale|cost|margin|rating|review|testimonial|verified)",
    re.IGNORECASE,
)
_SAFE_SPEC_KEY = re.compile(r"^[\w][\w .&/%()+,'-]{0,79}$", re.UNICODE)


def _media_base_url(value: str | None) -> str | None:
    if value is None:
        return None
    parsed = urlsplit(value)
    if (parsed.scheme != "https" or not parsed.netloc or parsed.username or
            parsed.password or parsed.query or parsed.fragment or
            ".." in parsed.path.split("/")):
        raise ValueError("Public media base URL must be an HTTPS URL without credentials, query, or fragment")
    return value.rstrip("/")


def _public_media_url(value: str, base_url: str | None) -> str:
    if not isinstance(value, str) or not value or "\\" in value or "\x00" in value:
        raise ValueError("Catalogue media URL is invalid")
    if value.startswith(_LOCAL_MEDIA_PREFIX):
        try:
            media_id = uuid.UUID(value[len(_LOCAL_MEDIA_PREFIX):])
        except ValueError as exc:
            raise ValueError("Catalogue media URL has an invalid upload ID") from exc
        if base_url is None:
            raise ValueError("Uploaded product media requires --public-media-base-url and copied public image bytes")
        return f"{base_url}/{media_id}.jpg"
    if value.startswith("assets/") or value.startswith("/assets/"):
        if ".." in value.split("/") or "?" in value or "#" in value:
            raise ValueError("Catalogue asset path is invalid")
        return value
    parsed = urlsplit(value)
    if (parsed.scheme == "https" and parsed.netloc and not parsed.username and
            not parsed.password and not parsed.query and not parsed.fragment and
            ".." not in parsed.path.split("/")):
        return value
    raise ValueError("Catalogue media must be a bundled asset or stable HTTPS URL")


def _public_specifications(raw: object) -> dict[str, str | int | float | bool]:
    """Keep only simple display metadata; reject arbitrary nested/private JSON."""
    if not isinstance(raw, dict):
        return {}
    result: dict[str, str | int | float | bool] = {}
    for key, value in raw.items():
        if not isinstance(key, str) or not _SAFE_SPEC_KEY.fullmatch(key) or _PRIVATE_SPEC_KEYS.search(key):
            continue
        if isinstance(value, bool):
            result[key] = value
        elif isinstance(value, (int, float)) and not isinstance(value, bool):
            if abs(value) <= 1_000_000_000 and math.isfinite(value):
                result[key] = value
        elif isinstance(value, str) and len(value) <= 2_000:
            result[key] = value
    return result


def _product_record(product: Product, vendor: Vendor, media: list[ProductMedia],
                    metadata: dict | None, media_base_url: str | None) -> dict:
    specs = _public_specifications(product.specifications)
    public_media = [
        {
            "id": str(row.id),
            "url": _public_media_url(row.url, media_base_url),
            "media_type": row.media_type.value,
            "is_primary": bool(row.is_primary),
            "sort_order": row.sort_order,
        }
        for row in sorted(media, key=lambda row: (not row.is_primary, row.sort_order, str(row.id)))
    ]
    return {
        "id": str(product.id),
        "vendor_id": str(product.vendor_id),
        "family_id": str(product.family_id) if product.family_id else None,
        "sku": product.sku,
        "title": product.title,
        "slug": product.slug,
        "category": product.category.value,
        "subcategory": product.subcategory,
        "brand": product.brand,
        "description": product.description,
        "short_description": product.short_description,
        "base_price": str(product.base_price),
        "compare_at_price": str(product.compare_at_price) if product.compare_at_price is not None else None,
        "unit": product.unit,
        "pack_size": product.pack_size,
        "weight_grams": product.weight_grams,
        "publication_status": "published",
        "specifications": specs,
        "is_active": True,
        "is_featured": bool(product.is_featured),
        "is_rentable": bool(product.is_rentable),
        "rental_rate_per_hour": str(product.rental_rate_per_hour) if product.rental_rate_per_hour is not None else None,
        "rental_rate_per_acre": str(product.rental_rate_per_acre) if product.rental_rate_per_acre is not None else None,
        "min_order_quantity": product.min_order_quantity,
        "media": public_media,
        "vendor": {"id": str(vendor.id), "business_name": vendor.business_name},
        "taxonomy": metadata,
        # Stock is intentionally absent. Checkout must query the live API.
    }


def _family_record(family: ProductFamily, variants: list[dict],
                   media_base_url: str | None) -> dict:
    documents = family.supporting_documents if isinstance(family.supporting_documents, dict) else {}
    primary = documents.get("primary_image")
    raw_media = documents.get("media") or []
    if not isinstance(raw_media, list):
        raise ValueError(f"Family {family.id} has invalid media metadata")
    return {
        "id": str(family.id),
        "vendor_id": str(family.vendor_id),
        "slug": family.slug,
        "title": family.title,
        "brand": family.brand,
        "department": family.department,
        "collection": family.collection,
        "milk_source": family.milk_source,
        "production_method": family.production_method,
        "ingredients": family.ingredients,
        "description": family.description,
        "is_published": True,
        "is_concept": bool(family.is_concept),
        "primary_image": _public_media_url(primary, media_base_url) if primary else None,
        "media": [_public_media_url(url, media_base_url) for url in raw_media],
        "variants": [] if family.is_concept else sorted(variants, key=lambda row: (Decimal(row["base_price"]), row["id"])),
    }


async def build_snapshot(db: AsyncSession, public_media_base_url: str | None = None) -> dict:
    """Read published catalogue rows and return a content-addressed JSON object."""
    media_base_url = _media_base_url(public_media_base_url)
    product_rows = (await db.execute(
        select(Product, Vendor)
        .join(Vendor, Vendor.id == Product.vendor_id)
        .outerjoin(ProductFamily, ProductFamily.id == Product.family_id)
        .where(
            Product.is_active.is_(True),
            Product.publication_status == "published",
            Vendor.is_active.is_(True),
            or_(Product.family_id.is_(None), ProductFamily.is_published.is_(True)),
        )
        .order_by(Product.sku, Product.id)
    )).all()
    families = list((await db.scalars(
        select(ProductFamily).join(Vendor, Vendor.id == ProductFamily.vendor_id)
        .where(ProductFamily.is_published.is_(True), Vendor.is_active.is_(True))
        .order_by(ProductFamily.slug, ProductFamily.id)
    )).all())
    product_ids = [product.id for product, _ in product_rows]
    media_by_product: dict[uuid.UUID, list[ProductMedia]] = defaultdict(list)
    if product_ids:
        for row in (await db.scalars(
            select(ProductMedia).where(ProductMedia.product_id.in_(product_ids))
        )).all():
            media_by_product[row.product_id].append(row)

    metadata_by_product = (
        await taxonomy.product_metadata(db, product_ids)
        if settings.COMMERCE_TAXONOMY_ENABLED and product_ids else {}
    )
    products = [
        _product_record(product, vendor, media_by_product[product.id],
                        metadata_by_product.get(str(product.id)),
                        media_base_url)
        for product, vendor in product_rows
    ]
    variants_by_family: dict[str, list[dict]] = defaultdict(list)
    for product in products:
        if product["family_id"]:
            variants_by_family[product["family_id"]].append(product)
    payload = {
        "schema_version": SCHEMA_VERSION,
        "products": products,
        "families": [
            _family_record(family, variants_by_family[str(family.id)], media_base_url)
            for family in families
        ],
    }
    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    return {**payload, "content_sha256": hashlib.sha256(canonical).hexdigest()}


def write_snapshot(snapshot: dict, output: Path) -> bool:
    """Atomically replace the snapshot; leave unchanged content untouched."""
    data = (json.dumps(snapshot, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n").encode("utf-8")
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.is_file() and output.read_bytes() == data:
        return False
    temp_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(dir=output.parent, prefix=f".{output.name}.", suffix=".tmp", delete=False) as handle:
            handle.write(data)
            temp_path = Path(handle.name)
        os.replace(temp_path, output)
    finally:
        if temp_path is not None:
            temp_path.unlink(missing_ok=True)
    return True


async def _run(output: Path, public_media_base_url: str | None, allow_empty: bool = False) -> dict:
    async with async_session_factory() as db:
        async with db.begin():
            if db.get_bind().dialect.name == "postgresql":
                await db.execute(text("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY"))
            snapshot = await build_snapshot(db, public_media_base_url)
    if not snapshot["products"] and not allow_empty:
        raise ValueError("No published products found; refusing to replace the storefront catalogue (pass --allow-empty to override)")
    write_snapshot(snapshot, output)
    return snapshot


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="Path to the generated public JSON file")
    parser.add_argument("--public-media-base-url", help="HTTPS R2/CDN prefix containing uploaded <uuid>.jpg images")
    parser.add_argument("--allow-empty", action="store_true", help="Publish an empty product list intentionally")
    args = parser.parse_args()
    snapshot = asyncio.run(_run(args.output, args.public_media_base_url, args.allow_empty))
    print(f"Exported {len(snapshot['products'])} products and {len(snapshot['families'])} families; sha256={snapshot['content_sha256']}")


if __name__ == "__main__":
    main()
