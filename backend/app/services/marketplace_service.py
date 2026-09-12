import logging
import math
import uuid
from datetime import datetime, timedelta

from fastapi import HTTPException
from sqlalchemy import select, func, and_, or_, case, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.marketplace import (
    CattleListing, ListingInquiry, ListingFavorite,
    ListingStatus, ListingCategory, InquiryStatus,
)
from app.models.cattle import Cattle
from app.models.health import HealthRecord, Vaccination
from app.models.farmer import Farmer
from app.models.user import User
from app.models.notification import Notification, NotificationType
from app.schemas.marketplace import (
    ListingCreate, ListingUpdate, InquiryCreate, ListingSearchParams,
)

logger = logging.getLogger("dairy_ai.services.marketplace")

# Default listing expiry: 30 days
LISTING_EXPIRY_DAYS = 30


def _haversine(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Calculate distance in km between two lat/lng points using haversine formula."""
    R = 6371.0  # Earth radius in km
    d_lat = math.radians(lat2 - lat1)
    d_lng = math.radians(lng2 - lng1)
    a = (
        math.sin(d_lat / 2) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(d_lng / 2) ** 2
    )
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c


async def _verify_health_status(db: AsyncSession, cattle_id: uuid.UUID) -> tuple[bool, bool]:
    """Check if cattle has health records and up-to-date vaccinations."""
    # Health verified: at least one health record exists
    health_result = await db.execute(
        select(func.count(HealthRecord.id)).where(HealthRecord.cattle_id == cattle_id)
    )
    health_count = health_result.scalar_one()
    health_verified = health_count > 0

    # Vaccination verified: has vaccinations and none are overdue
    vacc_result = await db.execute(
        select(Vaccination).where(Vaccination.cattle_id == cattle_id)
    )
    vaccinations = vacc_result.scalars().all()
    if not vaccinations:
        vaccination_verified = False
    else:
        today = datetime.utcnow().date()
        vaccination_verified = all(
            v.next_due_date is None or v.next_due_date >= today
            for v in vaccinations
        )

    return health_verified, vaccination_verified


def _listing_to_dict(listing: CattleListing) -> dict:
    """Convert a CattleListing to a serializable dict."""
    return {
        "id": str(listing.id),
        "seller_id": str(listing.seller_id),
        "cattle_id": str(listing.cattle_id) if listing.cattle_id else None,
        "category": listing.category.value if hasattr(listing.category, "value") else listing.category,
        "breed": listing.breed,
        "age_months": listing.age_months,
        "weight_kg": listing.weight_kg,
        "milk_yield_litres": listing.milk_yield_litres,
        "fat_pct": listing.fat_pct,
        "lactation_number": listing.lactation_number,
        "is_pregnant": listing.is_pregnant,
        "months_pregnant": listing.months_pregnant,
        "health_verified": listing.health_verified,
        "vaccination_verified": listing.vaccination_verified,
        "title": listing.title,
        "description": listing.description,
        "price": listing.price,
        "is_negotiable": listing.is_negotiable,
        "photos": listing.photos,
        "video_url": listing.video_url,
        "location_village": listing.location_village,
        "location_district": listing.location_district,
        "location_state": listing.location_state,
        "lat": listing.lat,
        "lng": listing.lng,
        "views_count": listing.views_count,
        "inquiries_count": listing.inquiries_count,
        "status": listing.status.value if hasattr(listing.status, "value") else listing.status,
        "featured": listing.featured,
        "expires_at": listing.expires_at.isoformat() if listing.expires_at else None,
        "created_at": listing.created_at.isoformat() if listing.created_at else None,
        "updated_at": listing.updated_at.isoformat() if listing.updated_at else None,
    }


def _inquiry_to_dict(inquiry: ListingInquiry) -> dict:
    """Convert a ListingInquiry to a serializable dict."""
    return {
        "id": str(inquiry.id),
        "listing_id": str(inquiry.listing_id),
        "buyer_id": str(inquiry.buyer_id),
        "message": inquiry.message,
        "offered_price": inquiry.offered_price,
        "phone_shared": inquiry.phone_shared,
        "status": inquiry.status.value if hasattr(inquiry.status, "value") else inquiry.status,
        "seller_response": inquiry.seller_response,
        "created_at": inquiry.created_at.isoformat() if inquiry.created_at else None,
        "updated_at": inquiry.updated_at.isoformat() if inquiry.updated_at else None,
    }


# ── Listing CRUD ────────────────────────────────────────────────────────────


async def create_listing(
    db: AsyncSession, seller_id: uuid.UUID, data: ListingCreate,
) -> CattleListing:
    """Create a new cattle listing. Auto-verify health/vaccination if cattle_id is linked."""
    logger.info(f"create_listing | seller_id={seller_id} | title={data.title}")

    health_verified = False
    vaccination_verified = False

    cattle_uuid = uuid.UUID(data.cattle_id) if data.cattle_id else None

    if cattle_uuid:
        # Verify the cattle belongs to this seller
        cattle_result = await db.execute(
            select(Cattle).where(Cattle.id == cattle_uuid)
        )
        cattle = cattle_result.scalar_one_or_none()
        if not cattle:
            raise HTTPException(status_code=404, detail="Cattle not found")

        # Check cattle ownership via farmer profile
        farmer_result = await db.execute(
            select(Farmer).where(Farmer.user_id == seller_id)
        )
        farmer = farmer_result.scalar_one_or_none()
        if not farmer or cattle.farmer_id != farmer.id:
            raise HTTPException(status_code=403, detail="You do not own this cattle")

        health_verified, vaccination_verified = await _verify_health_status(db, cattle_uuid)
        logger.info(
            f"Cattle verification | cattle_id={cattle_uuid} | "
            f"health_verified={health_verified} | vaccination_verified={vaccination_verified}"
        )

    listing = CattleListing(
        seller_id=seller_id,
        cattle_id=cattle_uuid,
        category=data.category,
        breed=data.breed,
        age_months=data.age_months,
        weight_kg=data.weight_kg,
        milk_yield_litres=data.milk_yield_litres,
        fat_pct=data.fat_pct,
        lactation_number=data.lactation_number,
        is_pregnant=data.is_pregnant,
        months_pregnant=data.months_pregnant,
        health_verified=health_verified,
        vaccination_verified=vaccination_verified,
        title=data.title,
        description=data.description,
        price=data.price,
        is_negotiable=data.is_negotiable,
        photos=data.photos,
        video_url=data.video_url,
        location_village=data.location_village,
        location_district=data.location_district,
        location_state=data.location_state,
        lat=data.lat,
        lng=data.lng,
        status=data.status,
        expires_at=datetime.utcnow() + timedelta(days=LISTING_EXPIRY_DAYS),
    )
    db.add(listing)
    await db.flush()
    await db.refresh(listing)

    logger.info(f"Listing created | listing_id={listing.id}")
    return listing


async def update_listing(
    db: AsyncSession,
    listing_id: uuid.UUID,
    seller_id: uuid.UUID,
    data: ListingUpdate,
) -> CattleListing:
    """Update listing — only seller can update, and only if not sold."""
    logger.info(f"update_listing | listing_id={listing_id} | seller_id={seller_id}")

    result = await db.execute(
        select(CattleListing).where(CattleListing.id == listing_id)
    )
    listing = result.scalar_one_or_none()
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
    if listing.seller_id != seller_id:
        raise HTTPException(status_code=403, detail="Not your listing")
    if listing.status == ListingStatus.sold:
        raise HTTPException(status_code=400, detail="Cannot update a sold listing")

    update_data = data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(listing, field, value)

    listing.updated_at = datetime.utcnow()
    await db.flush()
    await db.refresh(listing)

    logger.info(f"Listing updated | listing_id={listing.id}")
    return listing


async def search_listings(
    db: AsyncSession,
    filters: ListingSearchParams,
    viewer_lat: float | None = None,
    viewer_lng: float | None = None,
    viewer_id: uuid.UUID | None = None,
) -> tuple[list[dict], int]:
    """Search active listings with filters and sorting."""
    logger.info(f"search_listings | filters={filters.model_dump()}")

    conditions = [CattleListing.status == ListingStatus.active]

    if filters.category:
        conditions.append(CattleListing.category == filters.category)
    if filters.breed:
        conditions.append(CattleListing.breed.ilike(f"%{filters.breed}%"))
    if filters.min_price is not None:
        conditions.append(CattleListing.price >= filters.min_price)
    if filters.max_price is not None:
        conditions.append(CattleListing.price <= filters.max_price)
    if filters.district:
        conditions.append(CattleListing.location_district.ilike(f"%{filters.district}%"))
    if filters.state:
        conditions.append(CattleListing.location_state.ilike(f"%{filters.state}%"))
    if filters.is_pregnant is not None:
        conditions.append(CattleListing.is_pregnant == filters.is_pregnant)
    if filters.health_verified is not None:
        conditions.append(CattleListing.health_verified == filters.health_verified)

    # Exclude expired listings
    conditions.append(
        or_(
            CattleListing.expires_at.is_(None),
            CattleListing.expires_at > datetime.utcnow(),
        )
    )

    where_clause = and_(*conditions)

    # Count total
    count_q = select(func.count(CattleListing.id)).where(where_clause)
    total_result = await db.execute(count_q)
    total = total_result.scalar_one()

    # Build main query
    query = select(CattleListing).where(where_clause)

    # Sorting
    if filters.sort_by == "price_asc":
        query = query.order_by(CattleListing.price.asc())
    elif filters.sort_by == "price_desc":
        query = query.order_by(CattleListing.price.desc())
    elif filters.sort_by == "views":
        query = query.order_by(CattleListing.views_count.desc())
    else:
        # Default: created_at desc (newest first), featured first
        query = query.order_by(
            CattleListing.featured.desc(),
            CattleListing.created_at.desc(),
        )

    # Pagination
    offset = (filters.page - 1) * filters.per_page
    query = query.offset(offset).limit(filters.per_page)

    result = await db.execute(query)
    listings = result.scalars().all()

    # Get favorites for viewer
    favorited_ids: set[uuid.UUID] = set()
    if viewer_id:
        fav_result = await db.execute(
            select(ListingFavorite.listing_id).where(
                ListingFavorite.user_id == viewer_id,
            )
        )
        favorited_ids = {row[0] for row in fav_result.all()}

    # Build response with optional distance sorting
    items = []
    for listing in listings:
        item = _listing_to_dict(listing)
        item["is_favorited"] = listing.id in favorited_ids

        # Attach seller info
        if listing.seller:
            item["seller_phone"] = listing.seller.phone
        # Try to get seller name from farmer profile
        farmer_result = await db.execute(
            select(Farmer.name).where(Farmer.user_id == listing.seller_id)
        )
        farmer_name = farmer_result.scalar_one_or_none()
        item["seller_name"] = farmer_name

        # Calculate distance if viewer coords provided
        if viewer_lat is not None and viewer_lng is not None and listing.lat and listing.lng:
            item["distance_km"] = round(
                _haversine(viewer_lat, viewer_lng, listing.lat, listing.lng), 1
            )
        else:
            item["distance_km"] = None

        items.append(item)

    # Sort by distance if requested and coords available
    if filters.sort_by == "distance" and viewer_lat is not None and viewer_lng is not None:
        items.sort(key=lambda x: x.get("distance_km") or float("inf"))

    logger.info(f"search_listings | found={total} | returned={len(items)}")
    return items, total


async def get_listing_detail(
    db: AsyncSession,
    listing_id: uuid.UUID,
    viewer_id: uuid.UUID | None = None,
) -> dict:
    """Get listing detail, increment view count, include seller info and health summary."""
    logger.info(f"get_listing_detail | listing_id={listing_id} | viewer_id={viewer_id}")

    result = await db.execute(
        select(CattleListing).where(CattleListing.id == listing_id)
    )
    listing = result.scalar_one_or_none()
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")

    # Increment views (only if not the seller viewing their own listing)
    if viewer_id and viewer_id != listing.seller_id:
        listing.views_count = (listing.views_count or 0) + 1
        await db.flush()

    item = _listing_to_dict(listing)

    # Seller info
    if listing.seller:
        item["seller_phone"] = listing.seller.phone
    farmer_result = await db.execute(
        select(Farmer).where(Farmer.user_id == listing.seller_id)
    )
    farmer = farmer_result.scalar_one_or_none()
    item["seller_name"] = farmer.name if farmer else None
    item["seller_village"] = farmer.village if farmer else None

    # Health summary if cattle is linked
    if listing.cattle_id:
        health_result = await db.execute(
            select(HealthRecord)
            .where(HealthRecord.cattle_id == listing.cattle_id)
            .order_by(HealthRecord.date.desc())
            .limit(5)
        )
        health_records = health_result.scalars().all()
        item["health_summary"] = [
            {
                "date": str(hr.date),
                "type": hr.record_type.value if hasattr(hr.record_type, "value") else hr.record_type,
                "diagnosis": hr.diagnosis,
                "resolved": hr.resolved,
            }
            for hr in health_records
        ]

        vacc_result = await db.execute(
            select(Vaccination)
            .where(Vaccination.cattle_id == listing.cattle_id)
            .order_by(Vaccination.date_given.desc())
        )
        vaccinations = vacc_result.scalars().all()
        item["vaccination_records"] = [
            {
                "vaccine_name": v.vaccine_name,
                "date_given": str(v.date_given),
                "next_due_date": str(v.next_due_date) if v.next_due_date else None,
            }
            for v in vaccinations
        ]
    else:
        item["health_summary"] = []
        item["vaccination_records"] = []

    # Check if favorited by viewer
    item["is_favorited"] = False
    if viewer_id:
        fav_result = await db.execute(
            select(ListingFavorite).where(
                and_(
                    ListingFavorite.listing_id == listing_id,
                    ListingFavorite.user_id == viewer_id,
                )
            )
        )
        item["is_favorited"] = fav_result.scalar_one_or_none() is not None

    logger.info(f"get_listing_detail completed | listing_id={listing_id}")
    return item


# ── Inquiry Operations ──────────────────────────────────────────────────────


async def create_inquiry(
    db: AsyncSession,
    listing_id: uuid.UUID,
    buyer_id: uuid.UUID,
    data: InquiryCreate,
) -> ListingInquiry:
    """Create an inquiry on a listing and notify the seller."""
    logger.info(f"create_inquiry | listing_id={listing_id} | buyer_id={buyer_id}")

    result = await db.execute(
        select(CattleListing).where(CattleListing.id == listing_id)
    )
    listing = result.scalar_one_or_none()
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
    if listing.status != ListingStatus.active:
        raise HTTPException(status_code=400, detail="Listing is not active")
    if listing.seller_id == buyer_id:
        raise HTTPException(status_code=400, detail="Cannot inquire on your own listing")

    # Check for existing pending inquiry from same buyer
    existing_result = await db.execute(
        select(ListingInquiry).where(
            and_(
                ListingInquiry.listing_id == listing_id,
                ListingInquiry.buyer_id == buyer_id,
                ListingInquiry.status == InquiryStatus.pending,
            )
        )
    )
    if existing_result.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="You already have a pending inquiry on this listing")

    inquiry = ListingInquiry(
        listing_id=listing_id,
        buyer_id=buyer_id,
        message=data.message,
        offered_price=data.offered_price,
        phone_shared=data.phone_shared,
    )
    db.add(inquiry)

    # Increment inquiry count
    listing.inquiries_count = (listing.inquiries_count or 0) + 1

    # Create notification for seller
    notification = Notification(
        user_id=listing.seller_id,
        type=NotificationType.general,
        title="New inquiry on your listing",
        body=f"Someone is interested in: {listing.title}",
        data={"listing_id": str(listing_id), "inquiry_id": str(inquiry.id)},
    )
    db.add(notification)

    await db.flush()
    await db.refresh(inquiry)

    logger.info(f"Inquiry created | inquiry_id={inquiry.id}")
    return inquiry


async def respond_to_inquiry(
    db: AsyncSession,
    inquiry_id: uuid.UUID,
    seller_id: uuid.UUID,
    response: str,
    status: str,
) -> ListingInquiry:
    """Seller responds to an inquiry."""
    logger.info(f"respond_to_inquiry | inquiry_id={inquiry_id} | seller_id={seller_id}")

    result = await db.execute(
        select(ListingInquiry).where(ListingInquiry.id == inquiry_id)
    )
    inquiry = result.scalar_one_or_none()
    if not inquiry:
        raise HTTPException(status_code=404, detail="Inquiry not found")

    # Verify the seller owns the listing
    listing_result = await db.execute(
        select(CattleListing).where(CattleListing.id == inquiry.listing_id)
    )
    listing = listing_result.scalar_one_or_none()
    if not listing or listing.seller_id != seller_id:
        raise HTTPException(status_code=403, detail="Not your listing")

    if inquiry.status != InquiryStatus.pending:
        raise HTTPException(status_code=400, detail="Inquiry has already been responded to")

    inquiry.seller_response = response
    inquiry.status = status
    inquiry.updated_at = datetime.utcnow()

    # Notify the buyer
    notification = Notification(
        user_id=inquiry.buyer_id,
        type=NotificationType.general,
        title=f"Your inquiry was {status}",
        body=f"The seller responded to your inquiry on: {listing.title}",
        data={"listing_id": str(listing.listing_id), "inquiry_id": str(inquiry_id)},
    )
    db.add(notification)

    await db.flush()
    await db.refresh(inquiry)

    logger.info(f"Inquiry responded | inquiry_id={inquiry.id} | status={status}")
    return inquiry


# ── Favorite Operations ─────────────────────────────────────────────────────


async def toggle_favorite(
    db: AsyncSession, listing_id: uuid.UUID, user_id: uuid.UUID,
) -> dict:
    """Toggle favorite — add if not favorited, remove if already favorited."""
    logger.info(f"toggle_favorite | listing_id={listing_id} | user_id={user_id}")

    # Verify listing exists
    listing_result = await db.execute(
        select(CattleListing).where(CattleListing.id == listing_id)
    )
    if not listing_result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Listing not found")

    # Check if already favorited
    existing = await db.execute(
        select(ListingFavorite).where(
            and_(
                ListingFavorite.listing_id == listing_id,
                ListingFavorite.user_id == user_id,
            )
        )
    )
    fav = existing.scalar_one_or_none()

    if fav:
        await db.delete(fav)
        await db.flush()
        logger.info(f"Favorite removed | listing_id={listing_id}")
        return {"favorited": False}
    else:
        new_fav = ListingFavorite(
            listing_id=listing_id,
            user_id=user_id,
        )
        db.add(new_fav)
        await db.flush()
        logger.info(f"Favorite added | listing_id={listing_id}")
        return {"favorited": True}


# ── My Listings / Favorites / Inquiries ─────────────────────────────────────


async def get_my_listings(
    db: AsyncSession, user_id: uuid.UUID,
) -> list[dict]:
    """Get all listings created by the user."""
    logger.info(f"get_my_listings | user_id={user_id}")

    result = await db.execute(
        select(CattleListing)
        .where(CattleListing.seller_id == user_id)
        .order_by(CattleListing.created_at.desc())
    )
    listings = result.scalars().all()

    items = [_listing_to_dict(listing) for listing in listings]
    logger.info(f"get_my_listings | count={len(items)}")
    return items


async def get_my_favorites(
    db: AsyncSession, user_id: uuid.UUID,
) -> list[dict]:
    """Get all listings favorited by the user."""
    logger.info(f"get_my_favorites | user_id={user_id}")

    result = await db.execute(
        select(CattleListing)
        .join(ListingFavorite, ListingFavorite.listing_id == CattleListing.id)
        .where(ListingFavorite.user_id == user_id)
        .order_by(ListingFavorite.created_at.desc())
    )
    listings = result.scalars().all()

    items = []
    for listing in listings:
        item = _listing_to_dict(listing)
        item["is_favorited"] = True
        items.append(item)

    logger.info(f"get_my_favorites | count={len(items)}")
    return items


async def get_my_inquiries(
    db: AsyncSession, user_id: uuid.UUID,
) -> list[dict]:
    """Get all inquiries made by the user (as buyer)."""
    logger.info(f"get_my_inquiries | user_id={user_id}")

    result = await db.execute(
        select(ListingInquiry)
        .where(ListingInquiry.buyer_id == user_id)
        .order_by(ListingInquiry.created_at.desc())
    )
    inquiries = result.scalars().all()

    items = []
    for inquiry in inquiries:
        item = _inquiry_to_dict(inquiry)
        # Attach listing title
        if inquiry.listing:
            item["listing_title"] = inquiry.listing.title
        items.append(item)

    logger.info(f"get_my_inquiries | count={len(items)}")
    return items


# ── Mark as Sold ────────────────────────────────────────────────────────────


async def mark_as_sold(
    db: AsyncSession,
    listing_id: uuid.UUID,
    seller_id: uuid.UUID,
    buyer_id: uuid.UUID | None = None,
) -> CattleListing:
    """Mark a listing as sold. Optionally record buyer_id."""
    logger.info(f"mark_as_sold | listing_id={listing_id} | seller_id={seller_id}")

    result = await db.execute(
        select(CattleListing).where(CattleListing.id == listing_id)
    )
    listing = result.scalar_one_or_none()
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
    if listing.seller_id != seller_id:
        raise HTTPException(status_code=403, detail="Not your listing")
    if listing.status == ListingStatus.sold:
        raise HTTPException(status_code=400, detail="Listing is already marked as sold")

    listing.status = ListingStatus.sold
    listing.updated_at = datetime.utcnow()

    # If cattle_id is linked, update cattle status to sold
    if listing.cattle_id:
        cattle_result = await db.execute(
            select(Cattle).where(Cattle.id == listing.cattle_id)
        )
        cattle = cattle_result.scalar_one_or_none()
        if cattle:
            cattle.status = "sold"
            logger.info(f"Cattle status updated to sold | cattle_id={listing.cattle_id}")

    # Notify buyer if provided
    if buyer_id:
        notification = Notification(
            user_id=buyer_id,
            type=NotificationType.general,
            title="Listing marked as sold",
            body=f"The listing '{listing.title}' has been marked as sold to you.",
            data={"listing_id": str(listing_id)},
        )
        db.add(notification)

    # Reject all pending inquiries
    pending_result = await db.execute(
        select(ListingInquiry).where(
            and_(
                ListingInquiry.listing_id == listing_id,
                ListingInquiry.status == InquiryStatus.pending,
            )
        )
    )
    pending_inquiries = pending_result.scalars().all()
    for inq in pending_inquiries:
        if buyer_id and inq.buyer_id == buyer_id:
            inq.status = InquiryStatus.completed
        else:
            inq.status = InquiryStatus.rejected
            inq.seller_response = "Listing has been sold."
        inq.updated_at = datetime.utcnow()

    await db.flush()
    await db.refresh(listing)

    logger.info(f"Listing marked as sold | listing_id={listing.id}")
    return listing


# ── Marketplace Statistics ──────────────────────────────────────────────────


async def get_marketplace_stats(
    db: AsyncSession, district: str | None = None,
) -> dict:
    """Get marketplace statistics — avg prices by breed/category, active listing counts."""
    logger.info(f"get_marketplace_stats | district={district}")

    conditions = [CattleListing.status == ListingStatus.active]
    if district:
        conditions.append(CattleListing.location_district.ilike(f"%{district}%"))

    where_clause = and_(*conditions)

    # Total active listings
    total_result = await db.execute(
        select(func.count(CattleListing.id)).where(where_clause)
    )
    total_active = total_result.scalar_one()

    # Average price by category
    category_stats_result = await db.execute(
        select(
            CattleListing.category,
            func.count(CattleListing.id).label("count"),
            func.avg(CattleListing.price).label("avg_price"),
            func.min(CattleListing.price).label("min_price"),
            func.max(CattleListing.price).label("max_price"),
        )
        .where(where_clause)
        .group_by(CattleListing.category)
    )
    category_stats = [
        {
            "category": row[0].value if hasattr(row[0], "value") else row[0],
            "count": row[1],
            "avg_price": round(float(row[2]), 2) if row[2] else 0,
            "min_price": float(row[3]) if row[3] else 0,
            "max_price": float(row[4]) if row[4] else 0,
        }
        for row in category_stats_result.all()
    ]

    # Average price by breed
    breed_stats_result = await db.execute(
        select(
            CattleListing.breed,
            func.count(CattleListing.id).label("count"),
            func.avg(CattleListing.price).label("avg_price"),
        )
        .where(where_clause)
        .group_by(CattleListing.breed)
        .order_by(func.count(CattleListing.id).desc())
        .limit(20)
    )
    breed_stats = [
        {
            "breed": row[0],
            "count": row[1],
            "avg_price": round(float(row[2]), 2) if row[2] else 0,
        }
        for row in breed_stats_result.all()
    ]

    stats = {
        "total_active_listings": total_active,
        "by_category": category_stats,
        "by_breed": breed_stats,
    }

    if district:
        stats["district"] = district

    logger.info(f"get_marketplace_stats completed | total_active={total_active}")
    return stats
