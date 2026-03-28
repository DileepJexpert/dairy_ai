import logging
import uuid
from datetime import date, timedelta
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories import milk_repo, cattle_repo
from app.schemas.milk import MilkRecordCreate

logger = logging.getLogger("dairy_ai.services.milk")


async def record_milk(db: AsyncSession, cattle_id: uuid.UUID, data: MilkRecordCreate) -> dict:
    logger.info(f"record_milk called | cattle_id={cattle_id}, date={data.date}, session={data.session}")
    logger.debug(f"Milk details | quantity={data.quantity_litres}L, fat={data.fat_pct}%, snf={data.snf_pct}%, buyer={data.buyer_name}, price=₹{data.price_per_litre}/L")

    total = None
    if data.quantity_litres and data.price_per_litre:
        total = round(data.quantity_litres * data.price_per_litre, 2)
        logger.debug(f"Calculated total amount: ₹{total} ({data.quantity_litres}L x ₹{data.price_per_litre}/L)")

    logger.debug(f"Creating milk record in database for cattle_id={cattle_id}")
    record = await milk_repo.create_milk_record(
        db, cattle_id,
        date=data.date,
        session=data.session,
        quantity_litres=data.quantity_litres,
        fat_pct=data.fat_pct,
        snf_pct=data.snf_pct,
        buyer_name=data.buyer_name,
        price_per_litre=data.price_per_litre,
        total_amount=total,
    )
    logger.info(f"Milk record created | cattle_id={cattle_id}, quantity={data.quantity_litres}L, total=₹{total}")
    return record


async def get_milk_history(db: AsyncSession, cattle_id: uuid.UUID, days: int = 30):
    logger.debug(f"get_milk_history called | cattle_id={cattle_id}, days={days}")
    records = await milk_repo.get_milk_records(db, cattle_id, days=days)
    logger.debug(f"Milk history fetched | cattle_id={cattle_id}, records_count={len(records)}")
    return records


async def get_farmer_milk_summary(db: AsyncSession, farmer_id: uuid.UUID, days: int = 30) -> dict:
    logger.info(f"get_farmer_milk_summary called | farmer_id={farmer_id}, days={days}")

    logger.debug(f"Fetching cattle list for farmer_id={farmer_id}")
    cattle_list, _ = await cattle_repo.get_by_farmer(db, farmer_id, limit=500)
    cattle_ids = [c.id for c in cattle_list]
    logger.debug(f"Found {len(cattle_ids)} cattle for farmer_id={farmer_id}")

    logger.debug(f"Calculating milk summary for {len(cattle_ids)} cattle over {days} days")
    summary = await milk_repo.get_farmer_milk_summary(db, cattle_ids, days=days)

    logger.debug(f"Finding best performing cow for farmer_id={farmer_id}")
    best = await milk_repo.get_best_cow(db, cattle_ids, days=days)
    if best:
        summary["best_cow_id"] = best["cattle_id"]
        summary["best_cow_yield"] = best["total_yield"]
        logger.info(f"Best cow identified | cattle_id={best['cattle_id']}, total_yield={best['total_yield']}L")

    logger.info(f"Farmer milk summary loaded | farmer_id={farmer_id}, summary={summary}")
    return summary


async def get_district_prices(db: AsyncSession, district: str, price_date: date | None = None):
    logger.info(f"get_district_prices called | district={district}, date={price_date}")
    prices = await milk_repo.get_district_prices(db, district, price_date)
    logger.info(f"District prices fetched | district={district}, entries={len(prices) if isinstance(prices, list) else 'N/A'}")
    return prices


async def get_best_buyer(db: AsyncSession, district: str, fat_pct: float | None = None):
    logger.info(f"get_best_buyer called | district={district}, fat_pct={fat_pct}")
    buyer = await milk_repo.get_best_buyer(db, district, fat_pct)
    if buyer:
        logger.info(f"Best buyer found | district={district}, buyer={buyer}")
    else:
        logger.debug(f"No buyer data found for district={district}")
    return buyer


async def predict_daily_yield(db: AsyncSession, cattle_id: uuid.UUID) -> dict:
    """Simple moving average prediction based on last 7 days."""
    logger.info(f"predict_daily_yield called | cattle_id={cattle_id}")

    records = await milk_repo.get_milk_records(db, cattle_id, days=7)
    if not records:
        logger.debug(f"No milk records found for last 7 days | cattle_id={cattle_id}")
        return {"predicted_yield": 0, "confidence": 0}

    total = sum(r.quantity_litres for r in records)
    days_with_data = len(set(str(r.date) for r in records))
    logger.debug(f"Yield prediction data | cattle_id={cattle_id}, records={len(records)}, days_with_data={days_with_data}, total_litres={total}")

    if days_with_data == 0:
        logger.debug(f"No days with data for cattle_id={cattle_id}, returning zero prediction")
        return {"predicted_yield": 0, "confidence": 0}

    avg = round(total / days_with_data, 2)
    confidence = min(days_with_data / 7.0, 1.0)
    logger.info(f"Yield prediction | cattle_id={cattle_id}, predicted={avg}L/day, confidence={round(confidence, 2)}")
    return {"predicted_yield": avg, "confidence": round(confidence, 2)}
