import uuid
import logging

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.services import marketplace_service
from app.schemas.marketplace import (
    ListingCreate, ListingUpdate, InquiryCreate,
    InquiryRespondRequest, ListingSearchParams,
)

logger = logging.getLogger("dairy_ai.api.marketplace")

router = APIRouter(prefix="/marketplace", tags=["Marketplace"])


# ── Listing Endpoints ───────────────────────────────────────────────────────


@router.post("/listings", status_code=201)
async def create_listing(
    data: ListingCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Create a new cattle listing."""
    logger.info(f"POST /marketplace/listings | user_id={current_user.id} | title={data.title}")
    listing = await marketplace_service.create_listing(db, current_user.id, data)
    logger.info(f"Listing created | listing_id={listing.id}")
    return {
        "success": True,
        "data": marketplace_service._listing_to_dict(listing),
        "message": "Listing created successfully",
    }


@router.get("/listings")
async def search_listings(
    category: str | None = Query(None),
    breed: str | None = Query(None),
    min_price: float | None = Query(None, ge=0),
    max_price: float | None = Query(None, ge=0),
    district: str | None = Query(None),
    state: str | None = Query(None),
    is_pregnant: bool | None = Query(None),
    health_verified: bool | None = Query(None),
    sort_by: str = Query("created_at"),
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    lat: float | None = Query(None),
    lng: float | None = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Search marketplace listings with filters."""
    logger.info(
        f"GET /marketplace/listings | user_id={current_user.id} | "
        f"category={category} | breed={breed} | district={district}"
    )
    filters = ListingSearchParams(
        category=category,
        breed=breed,
        min_price=min_price,
        max_price=max_price,
        district=district,
        state=state,
        is_pregnant=is_pregnant,
        health_verified=health_verified,
        sort_by=sort_by,
        page=page,
        per_page=per_page,
    )
    items, total = await marketplace_service.search_listings(
        db, filters, viewer_lat=lat, viewer_lng=lng, viewer_id=current_user.id,
    )
    logger.info(f"Search results | total={total} | returned={len(items)}")
    return {
        "success": True,
        "data": items,
        "total": total,
        "page": page,
        "per_page": per_page,
        "message": "Listings",
    }


@router.get("/my-listings")
async def my_listings(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Get current user's listings (as seller)."""
    logger.info(f"GET /marketplace/my-listings | user_id={current_user.id}")
    items = await marketplace_service.get_my_listings(db, current_user.id)
    return {
        "success": True,
        "data": items,
        "total": len(items),
        "message": "My listings",
    }


@router.get("/my-favorites")
async def my_favorites(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Get current user's favorited listings."""
    logger.info(f"GET /marketplace/my-favorites | user_id={current_user.id}")
    items = await marketplace_service.get_my_favorites(db, current_user.id)
    return {
        "success": True,
        "data": items,
        "total": len(items),
        "message": "Favorite listings",
    }


@router.get("/my-inquiries")
async def my_inquiries(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Get current user's inquiries (as buyer)."""
    logger.info(f"GET /marketplace/my-inquiries | user_id={current_user.id}")
    items = await marketplace_service.get_my_inquiries(db, current_user.id)
    return {
        "success": True,
        "data": items,
        "total": len(items),
        "message": "My inquiries",
    }


@router.get("/stats")
async def marketplace_stats(
    district: str | None = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Get marketplace statistics — avg prices by breed/category."""
    logger.info(f"GET /marketplace/stats | user_id={current_user.id} | district={district}")
    stats = await marketplace_service.get_marketplace_stats(db, district)
    return {
        "success": True,
        "data": stats,
        "message": "Marketplace statistics",
    }


@router.get("/listings/{listing_id}")
async def get_listing_detail(
    listing_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Get a listing detail with seller info and health summary."""
    logger.info(f"GET /marketplace/listings/{listing_id} | user_id={current_user.id}")
    detail = await marketplace_service.get_listing_detail(
        db, uuid.UUID(listing_id), viewer_id=current_user.id,
    )
    return {
        "success": True,
        "data": detail,
        "message": "Listing details",
    }


@router.put("/listings/{listing_id}")
async def update_listing(
    listing_id: str,
    data: ListingUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Update a listing (seller only)."""
    logger.info(f"PUT /marketplace/listings/{listing_id} | user_id={current_user.id}")
    listing = await marketplace_service.update_listing(
        db, uuid.UUID(listing_id), current_user.id, data,
    )
    return {
        "success": True,
        "data": marketplace_service._listing_to_dict(listing),
        "message": "Listing updated",
    }


@router.delete("/listings/{listing_id}")
async def delete_listing(
    listing_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Cancel/delete a listing (sets status to cancelled)."""
    logger.info(f"DELETE /marketplace/listings/{listing_id} | user_id={current_user.id}")
    from app.schemas.marketplace import ListingUpdate as LU
    listing = await marketplace_service.update_listing(
        db, uuid.UUID(listing_id), current_user.id, LU(status="cancelled"),
    )
    return {
        "success": True,
        "data": {"id": str(listing.id)},
        "message": "Listing cancelled",
    }


# ── Inquiry Endpoints ──────────────────────────────────────────────────────


@router.post("/listings/{listing_id}/inquiries", status_code=201)
async def create_inquiry(
    listing_id: str,
    data: InquiryCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Send an inquiry on a listing."""
    logger.info(f"POST /marketplace/listings/{listing_id}/inquiries | user_id={current_user.id}")
    inquiry = await marketplace_service.create_inquiry(
        db, uuid.UUID(listing_id), current_user.id, data,
    )
    return {
        "success": True,
        "data": marketplace_service._inquiry_to_dict(inquiry),
        "message": "Inquiry sent",
    }


@router.put("/inquiries/{inquiry_id}/respond")
async def respond_to_inquiry(
    inquiry_id: str,
    data: InquiryRespondRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Seller responds to an inquiry (accept/reject)."""
    logger.info(f"PUT /marketplace/inquiries/{inquiry_id}/respond | user_id={current_user.id}")
    inquiry = await marketplace_service.respond_to_inquiry(
        db, uuid.UUID(inquiry_id), current_user.id, data.response, data.status,
    )
    return {
        "success": True,
        "data": marketplace_service._inquiry_to_dict(inquiry),
        "message": f"Inquiry {data.status}",
    }


# ── Favorite Endpoint ──────────────────────────────────────────────────────


@router.post("/listings/{listing_id}/favorite")
async def toggle_favorite(
    listing_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Toggle favorite on a listing (add/remove)."""
    logger.info(f"POST /marketplace/listings/{listing_id}/favorite | user_id={current_user.id}")
    result = await marketplace_service.toggle_favorite(
        db, uuid.UUID(listing_id), current_user.id,
    )
    return {
        "success": True,
        "data": result,
        "message": "Favorited" if result["favorited"] else "Unfavorited",
    }


# ── Mark as Sold ────────────────────────────────────────────────────────────


@router.post("/listings/{listing_id}/sold")
async def mark_as_sold(
    listing_id: str,
    buyer_id: str | None = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Mark a listing as sold (seller only)."""
    logger.info(f"POST /marketplace/listings/{listing_id}/sold | user_id={current_user.id}")
    buyer_uuid = uuid.UUID(buyer_id) if buyer_id else None
    listing = await marketplace_service.mark_as_sold(
        db, uuid.UUID(listing_id), current_user.id, buyer_uuid,
    )
    return {
        "success": True,
        "data": marketplace_service._listing_to_dict(listing),
        "message": "Listing marked as sold",
    }
