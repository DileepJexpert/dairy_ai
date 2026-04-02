"""Mandi price service — feed ingredient and cattle market prices."""
import logging
import uuid
from datetime import date, timedelta
from sqlalchemy import select, func, and_, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.mandi import MandiPrice, MandiCategory, CattleMarketPrice

logger = logging.getLogger("dairy_ai.services.mandi")

# ---------------------------------------------------------------------------
# Default Indian feed ingredient prices (fallback when no mandi data)
# ---------------------------------------------------------------------------
DEFAULT_FEED_PRICES: dict[str, dict] = {
    "napier_grass": {"category": "green_fodder", "price_per_kg": 2.5, "unit": "kg"},
    "maize_fodder": {"category": "green_fodder", "price_per_kg": 3.0, "unit": "kg"},
    "berseem": {"category": "green_fodder", "price_per_kg": 4.0, "unit": "kg"},
    "lucerne": {"category": "green_fodder", "price_per_kg": 5.0, "unit": "kg"},
    "wheat_straw": {"category": "dry_fodder", "price_per_kg": 5.0, "unit": "kg"},
    "paddy_straw": {"category": "dry_fodder", "price_per_kg": 3.5, "unit": "kg"},
    "jowar_kadbi": {"category": "dry_fodder", "price_per_kg": 4.0, "unit": "kg"},
    "cotton_seed_cake": {"category": "concentrate", "price_per_kg": 32.0, "unit": "kg"},
    "mustard_cake": {"category": "concentrate", "price_per_kg": 35.0, "unit": "kg"},
    "soybean_meal": {"category": "concentrate", "price_per_kg": 42.0, "unit": "kg"},
    "groundnut_cake": {"category": "concentrate", "price_per_kg": 45.0, "unit": "kg"},
    "maize_grain": {"category": "concentrate", "price_per_kg": 22.0, "unit": "kg"},
    "wheat_bran": {"category": "concentrate", "price_per_kg": 18.0, "unit": "kg"},
    "rice_bran": {"category": "concentrate", "price_per_kg": 16.0, "unit": "kg"},
    "bajra_grain": {"category": "concentrate", "price_per_kg": 24.0, "unit": "kg"},
    "mineral_mixture": {"category": "mineral", "price_per_kg": 80.0, "unit": "kg"},
    "common_salt": {"category": "mineral", "price_per_kg": 12.0, "unit": "kg"},
    "di_calcium_phosphate": {"category": "mineral", "price_per_kg": 60.0, "unit": "kg"},
    "bypass_fat": {"category": "supplement", "price_per_kg": 160.0, "unit": "kg"},
    "urea_molasses_block": {"category": "supplement", "price_per_kg": 25.0, "unit": "kg"},
}


async def get_feed_prices(
    db: AsyncSession,
    district: str | None = None,
    category: MandiCategory | None = None,
    days_back: int = 7,
) -> list[dict]:
    """Get latest feed prices, falling back to defaults if no mandi data."""
    since = date.today() - timedelta(days=days_back)
    query = select(MandiPrice).where(MandiPrice.date >= since)
    if district:
        query = query.where(MandiPrice.district == district)
    if category:
        query = query.where(MandiPrice.category == category)
    query = query.order_by(MandiPrice.date.desc())

    result = await db.execute(query)
    rows = list(result.scalars().all())

    if rows:
        # Deduplicate: latest price per ingredient
        seen = {}
        for r in rows:
            if r.ingredient_name not in seen:
                seen[r.ingredient_name] = {
                    "ingredient": r.ingredient_name,
                    "category": r.category.value,
                    "price_per_kg": r.price_per_kg,
                    "unit": r.unit,
                    "district": r.district,
                    "mandi": r.mandi_name,
                    "date": str(r.date),
                    "source": r.source or "mandi",
                }
        return list(seen.values())

    # Fallback to defaults
    logger.info("No mandi data found for district=%s, using defaults", district)
    prices = []
    for name, info in DEFAULT_FEED_PRICES.items():
        if category and info["category"] != category.value:
            continue
        prices.append({
            "ingredient": name.replace("_", " ").title(),
            "category": info["category"],
            "price_per_kg": info["price_per_kg"],
            "unit": info["unit"],
            "district": district or "default",
            "mandi": None,
            "date": str(date.today()),
            "source": "default",
        })
    return prices


async def record_feed_price(db: AsyncSession, data: dict) -> MandiPrice:
    """Record a feed ingredient price from mandi/manual entry."""
    price = MandiPrice(**data)
    db.add(price)
    await db.flush()
    logger.info("Recorded mandi price: %s = ₹%.1f/kg at %s", data.get("ingredient_name"), data.get("price_per_kg"), data.get("district"))
    return price


async def get_cattle_market_prices(
    db: AsyncSession,
    breed: str | None = None,
    category: str | None = None,
    district: str | None = None,
    days_back: int = 30,
) -> list[dict]:
    """Get cattle trading prices from markets."""
    since = date.today() - timedelta(days=days_back)
    query = select(CattleMarketPrice).where(CattleMarketPrice.date >= since)
    if breed:
        query = query.where(CattleMarketPrice.breed == breed)
    if category:
        query = query.where(CattleMarketPrice.category == category)
    if district:
        query = query.where(CattleMarketPrice.district == district)
    query = query.order_by(CattleMarketPrice.date.desc()).limit(50)

    result = await db.execute(query)
    return [
        {
            "breed": r.breed,
            "category": r.category,
            "age_range": r.age_range,
            "milk_yield_range": r.milk_yield_range,
            "avg_price": r.avg_price,
            "min_price": r.min_price,
            "max_price": r.max_price,
            "mandi": r.mandi_name,
            "district": r.district,
            "date": str(r.date),
        }
        for r in result.scalars().all()
    ]


async def get_price_trend(
    db: AsyncSession, ingredient_name: str, district: str | None = None, months: int = 3,
) -> list[dict]:
    """Monthly average price trend for a feed ingredient."""
    since = date.today() - timedelta(days=months * 30)
    query = select(
        func.avg(MandiPrice.price_per_kg).label("avg_price"),
        func.min(MandiPrice.price_per_kg).label("min_price"),
        func.max(MandiPrice.price_per_kg).label("max_price"),
        func.count().label("data_points"),
        func.extract("month", MandiPrice.date).label("month"),
        func.extract("year", MandiPrice.date).label("year"),
    ).where(
        and_(
            MandiPrice.ingredient_name == ingredient_name,
            MandiPrice.date >= since,
        )
    )
    if district:
        query = query.where(MandiPrice.district == district)
    query = query.group_by("year", "month").order_by("year", "month")

    result = await db.execute(query)
    return [
        {
            "month": int(row.month),
            "year": int(row.year),
            "avg_price": round(float(row.avg_price), 2),
            "min_price": round(float(row.min_price), 2),
            "max_price": round(float(row.max_price), 2),
            "data_points": row.data_points,
        }
        for row in result.all()
    ]


async def seed_default_prices(db: AsyncSession, district: str = "Jaipur") -> int:
    """Seed default feed prices for a district (for demo/testing)."""
    count = 0
    today = date.today()
    for name, info in DEFAULT_FEED_PRICES.items():
        price = MandiPrice(
            ingredient_name=name.replace("_", " ").title(),
            category=MandiCategory(info["category"]),
            price_per_kg=info["price_per_kg"],
            unit=info["unit"],
            district=district,
            state="Rajasthan",
            mandi_name=f"{district} Mandi",
            date=today,
            source="seed_data",
        )
        db.add(price)
        count += 1
    await db.flush()
    logger.info("Seeded %d default feed prices for %s", count, district)
    return count
