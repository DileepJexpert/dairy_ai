"""Mandi price API — feed ingredients and cattle market prices."""
import logging
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.mandi import MandiCategory
from app.services import mandi_service

logger = logging.getLogger("dairy_ai.api.mandi")
router = APIRouter(prefix="/mandi", tags=["Mandi Prices"])


@router.get("/feed-prices")
async def get_feed_prices(
    district: str | None = None,
    category: str | None = None,
    days_back: int = Query(7, ge=1, le=90),
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    cat = MandiCategory(category) if category else None
    prices = await mandi_service.get_feed_prices(db, district, cat, days_back)
    return {"success": True, "data": {"prices": prices, "count": len(prices)}, "message": "Feed prices retrieved"}


@router.post("/feed-prices")
async def record_feed_price(
    data: dict,
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    price = await mandi_service.record_feed_price(db, data)
    await db.commit()
    return {"success": True, "data": {"id": str(price.id)}, "message": "Price recorded"}


@router.get("/cattle-prices")
async def get_cattle_market_prices(
    breed: str | None = None,
    category: str | None = None,
    district: str | None = None,
    days_back: int = Query(30, ge=1, le=180),
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    prices = await mandi_service.get_cattle_market_prices(db, breed, category, district, days_back)
    return {"success": True, "data": {"prices": prices, "count": len(prices)}, "message": "Cattle market prices retrieved"}


@router.get("/feed-prices/trend")
async def get_price_trend(
    ingredient: str = Query(...),
    district: str | None = None,
    months: int = Query(3, ge=1, le=12),
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    trend = await mandi_service.get_price_trend(db, ingredient, district, months)
    return {"success": True, "data": {"trend": trend, "ingredient": ingredient}, "message": "Price trend retrieved"}


@router.post("/seed")
async def seed_prices(
    district: str = Query("Jaipur"),
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    """Admin: seed default feed prices for testing."""
    if user.role.value not in ("admin", "super_admin"):
        return {"success": False, "data": None, "message": "Admin access required"}
    count = await mandi_service.seed_default_prices(db, district)
    await db.commit()
    return {"success": True, "data": {"seeded": count, "district": district}, "message": f"Seeded {count} prices"}
