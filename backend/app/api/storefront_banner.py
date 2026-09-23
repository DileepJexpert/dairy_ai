"""Storefront banner API — public read + admin CRUD."""
import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import require_role
from app.models.user import UserRole
from app.models.storefront_banner import StorefrontBanner
from app.schemas.storefront_banner import BannerCreate, BannerUpdate, BannerReorderRequest

router = APIRouter(tags=["storefront banners"])
admin_only = require_role(UserRole.admin, UserRole.super_admin)


def _banner_json(row: StorefrontBanner) -> dict:
    return {
        "id": str(row.id),
        "title": row.title,
        "subtitle": row.subtitle,
        "image_url": row.image_url,
        "icon_name": row.icon_name,
        "action_type": row.action_type,
        "action_value": row.action_value,
        "bg_color": row.bg_color,
        "text_color": row.text_color,
        "display_order": row.display_order,
        "is_active": row.is_active,
        "starts_at": row.starts_at.isoformat() + "Z" if row.starts_at else None,
        "ends_at": row.ends_at.isoformat() + "Z" if row.ends_at else None,
        "created_at": row.created_at.isoformat() + "Z" if row.created_at else None,
    }


# ─── PUBLIC ──────────────────────────────────────────────────────────────────

@router.get("/marketplace/storefront/banners")
async def get_active_banners(db: AsyncSession = Depends(get_db)):
    """Returns active banners visible right now, sorted by display_order.

    Filters: is_active=True AND (starts_at is null OR <= now) AND (ends_at is null OR > now).
    No auth required — storefront is public.
    """
    now = datetime.utcnow()
    stmt = (
        select(StorefrontBanner)
        .where(
            StorefrontBanner.is_active == True,
            (StorefrontBanner.starts_at == None) | (StorefrontBanner.starts_at <= now),
            (StorefrontBanner.ends_at == None) | (StorefrontBanner.ends_at > now),
        )
        .order_by(StorefrontBanner.display_order.asc(), StorefrontBanner.created_at.asc())
    )
    result = await db.execute(stmt)
    banners = result.scalars().all()
    return [_banner_json(b) for b in banners]


# ─── ADMIN ───────────────────────────────────────────────────────────────────

@router.post("/admin/storefront/banners", dependencies=[Depends(admin_only)])
async def create_banner(body: BannerCreate, db: AsyncSession = Depends(get_db)):
    """Create a new storefront banner card."""
    banner = StorefrontBanner(**body.model_dump())
    db.add(banner)
    await db.flush()
    return _banner_json(banner)


@router.get("/admin/storefront/banners", dependencies=[Depends(admin_only)])
async def list_all_banners(db: AsyncSession = Depends(get_db)):
    """List ALL banners (active + inactive), sorted by display_order."""
    stmt = select(StorefrontBanner).order_by(
        StorefrontBanner.display_order.asc(), StorefrontBanner.created_at.asc()
    )
    result = await db.execute(stmt)
    return [_banner_json(b) for b in result.scalars().all()]


@router.put("/admin/storefront/banners/{banner_id}", dependencies=[Depends(admin_only)])
async def update_banner(
    banner_id: str, body: BannerUpdate, db: AsyncSession = Depends(get_db)
):
    """Update a storefront banner. Only provided fields are updated."""
    stmt = select(StorefrontBanner).where(StorefrontBanner.id == uuid.UUID(banner_id))
    result = await db.execute(stmt)
    banner = result.scalar_one_or_none()
    if not banner:
        raise HTTPException(404, "Banner not found")

    updates = body.model_dump(exclude_unset=True)
    for field, value in updates.items():
        setattr(banner, field, value)
    banner.updated_at = datetime.utcnow()
    await db.flush()
    return _banner_json(banner)


@router.delete("/admin/storefront/banners/{banner_id}", dependencies=[Depends(admin_only)])
async def delete_banner(banner_id: str, db: AsyncSession = Depends(get_db)):
    """Soft-delete: sets is_active=False. Banner stays in DB for audit."""
    stmt = select(StorefrontBanner).where(StorefrontBanner.id == uuid.UUID(banner_id))
    result = await db.execute(stmt)
    banner = result.scalar_one_or_none()
    if not banner:
        raise HTTPException(404, "Banner not found")
    banner.is_active = False
    banner.updated_at = datetime.utcnow()
    await db.flush()
    return {"status": "deactivated", "id": banner_id}


@router.patch("/admin/storefront/banners/reorder", dependencies=[Depends(admin_only)])
async def reorder_banners(body: BannerReorderRequest, db: AsyncSession = Depends(get_db)):
    """Bulk update display_order for multiple banners at once."""
    for item in body.banners:
        await db.execute(
            update(StorefrontBanner)
            .where(StorefrontBanner.id == uuid.UUID(item.id))
            .values(display_order=item.display_order, updated_at=datetime.utcnow())
        )
    await db.flush()
    return {"status": "reordered", "count": len(body.banners)}
