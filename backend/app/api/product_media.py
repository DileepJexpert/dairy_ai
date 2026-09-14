"""Local, validated product images. No external storage or filename trust."""
import io
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import FileResponse
from PIL import Image, ImageOps, UnidentifiedImageError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.concurrency import run_in_threadpool

from app.config import settings
from app.database import get_db
from app.dependencies import require_role
from app.models.commerce_admin import CommerceAudit
from app.models.product import Product, ProductFamily, ProductMedia, MediaType
from app.models.user import User, UserRole
from app.models.vendor import Vendor
from app.repositories import product_repo, vendor_repo

router = APIRouter(tags=["product-images"])
MAX_BYTES = 5 * 1024 * 1024
MAX_PIXELS = 16_000_000
MAX_IMAGES = 12
manage = require_role(UserRole.vendor, UserRole.admin, UserRole.super_admin)


async def owned_product(db, product_id, user):
    product = (await db.execute(select(Product).where(Product.id == product_id).with_for_update())).scalar_one_or_none()
    if not product:
        raise HTTPException(404, "Product not found")
    if user.role not in (UserRole.admin, UserRole.super_admin):
        vendor = await vendor_repo.get_by_user_id(db, user.id)
        if not vendor or not vendor.is_active or product.vendor_id != vendor.id:
            raise HTTPException(403, "You can manage only your active vendor's products")
    return product


def audit(db, user, product_id, action):
    db.add(CommerceAudit(actor_id=user.id, user_role=user.role.value, action=action,
                         entity_type="product_media", entity_id=str(product_id), details=action))


def sanitized_image(raw):
    try:
        with Image.open(io.BytesIO(raw)) as original:
            if original.format not in {"JPEG", "PNG", "WEBP"}:
                raise HTTPException(422, "Choose a JPEG, PNG or WebP image")
            if original.width * original.height > MAX_PIXELS or getattr(original, "n_frames", 1) != 1:
                raise HTTPException(422, "Use a still image with at most 16 million pixels")
            original.load()
            corrected = ImageOps.exif_transpose(original).convert("RGBA")
            corrected.thumbnail((2400, 2400))
            # Flatten transparency and strip EXIF/location and any appended data.
            clean = Image.new("RGB", corrected.size, "white")
            clean.paste(corrected, mask=corrected.getchannel("A"))
            output = io.BytesIO()
            clean.save(output, format="JPEG", quality=90)
            return output.getvalue()
    except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError) as exc:
        raise HTTPException(422, "The file is not a valid supported image") from exc


def image_path(file_id):
    # UUID comes from validated path params or the server, never client filenames.
    return Path(settings.PRODUCT_MEDIA_DIR).resolve() / f"{file_id}.jpg"


@router.get("/vendor/products/{product_id}/media")
async def list_media(product_id: uuid.UUID, user: User = Depends(manage), db: AsyncSession = Depends(get_db)):
    await owned_product(db, product_id, user)
    return {"success": True, "data": [{"id": str(x.id), "url": x.url, "is_primary": x.is_primary,
                                         "media_type": x.media_type.value} for x in await product_repo.media(db, product_id)]}


@router.post("/vendor/products/{product_id}/images", status_code=201)
async def upload_image(product_id: uuid.UUID, request: Request, user: User = Depends(manage), db: AsyncSession = Depends(get_db)):
    await owned_product(db, product_id, user)
    rows = await product_repo.media(db, product_id)
    if len(rows) >= MAX_IMAGES:
        raise HTTPException(422, "A product can have at most 12 images; remove one first")
    raw = bytearray()
    async for chunk in request.stream():
        if len(raw) + len(chunk) > MAX_BYTES:
            raise HTTPException(413, "Image must be 5 MB or smaller")
        raw.extend(chunk)
    clean = await run_in_threadpool(sanitized_image, bytes(raw))
    file_id = uuid.uuid4()
    path = image_path(file_id)
    path.parent.mkdir(parents=True, exist_ok=True)
    await run_in_threadpool(path.write_bytes, clean)
    url = f"/api/v1/marketplace/media/{file_id}"
    row = ProductMedia(id=file_id, product_id=product_id, url=url, media_type=MediaType.image,
                       sort_order=len(rows), is_primary=not rows)
    db.add(row)
    audit(db, user, product_id, "image_uploaded")
    await db.flush()
    return {"success": True, "data": {"id": str(row.id), "url": url, "is_primary": row.is_primary}}


@router.put("/vendor/products/{product_id}/media/{media_id}/primary")
async def make_primary(product_id: uuid.UUID, media_id: uuid.UUID, user: User = Depends(manage), db: AsyncSession = Depends(get_db)):
    await owned_product(db, product_id, user)
    rows = await product_repo.media(db, product_id)
    if not any(x.id == media_id and x.media_type == MediaType.image for x in rows):
        raise HTTPException(404, "Product image not found")
    for row in rows:
        row.is_primary = row.id == media_id
    audit(db, user, product_id, "primary_image_changed")
    await db.flush()
    return {"success": True}


@router.delete("/vendor/products/{product_id}/media/{media_id}")
async def remove_media(product_id: uuid.UUID, media_id: uuid.UUID, user: User = Depends(manage), db: AsyncSession = Depends(get_db)):
    await owned_product(db, product_id, user)
    rows = await product_repo.media(db, product_id)
    row = next((x for x in rows if x.id == media_id), None)
    if row:
        await db.delete(row)
        remaining = [x for x in rows if x.id != media_id and x.media_type == MediaType.image]
        if row.is_primary and remaining:
            remaining[0].is_primary = True
        audit(db, user, product_id, "image_removed")
        await db.flush()
    # Retain file bytes: other seller offers can reference the same URL.
    return {"success": True}


@router.get("/marketplace/media/{file_id}")
async def public_image(file_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    url = f"/api/v1/marketplace/media/{file_id}"
    # Match all references, not only the original media ID (seller offer copies).
    products = list((await db.execute(select(Product).join(ProductMedia, ProductMedia.product_id == Product.id)
        .join(Vendor, Vendor.id == Product.vendor_id).where(ProductMedia.url == url,
        Product.is_active.is_(True), Product.publication_status == "published", Vendor.is_active.is_(True)))).scalars())
    for product in products:
        family = await db.get(ProductFamily, product.family_id) if product.family_id else None
        if product.family_id and (not family or not family.is_published):
            continue
        path = image_path(file_id)
        if path.is_file():
            return FileResponse(path, media_type="image/jpeg", headers={"X-Content-Type-Options": "nosniff", "Cache-Control": "no-cache"})
    raise HTTPException(404, "Published image not found")


@router.get("/vendor/products/{product_id}/media/{media_id}/preview")
async def private_preview(product_id: uuid.UUID, media_id: uuid.UUID, user: User = Depends(manage), db: AsyncSession = Depends(get_db)):
    await owned_product(db, product_id, user)
    row = await db.get(ProductMedia, media_id)
    if not row or row.product_id != product_id or not row.url.startswith("/api/v1/marketplace/media/"):
        raise HTTPException(404, "Local image not found")
    try:
        path = image_path(uuid.UUID(row.url.rsplit("/", 1)[1]))
    except ValueError:
        raise HTTPException(404, "Local image not found")
    if not path.is_file():
        raise HTTPException(404, "Local image not found")
    return FileResponse(path, media_type="image/jpeg", headers={"Cache-Control": "no-store", "X-Content-Type-Options": "nosniff"})
