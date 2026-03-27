import uuid
from datetime import date, timedelta
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories import milk_repo, cattle_repo
from app.schemas.milk import MilkRecordCreate


async def record_milk(db: AsyncSession, cattle_id: uuid.UUID, data: MilkRecordCreate) -> dict:
    total = None
    if data.quantity_litres and data.price_per_litre:
        total = round(data.quantity_litres * data.price_per_litre, 2)

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
    return record


async def get_milk_history(db: AsyncSession, cattle_id: uuid.UUID, days: int = 30):
    return await milk_repo.get_milk_records(db, cattle_id, days=days)


async def get_farmer_milk_summary(db: AsyncSession, farmer_id: uuid.UUID, days: int = 30) -> dict:
    cattle_list, _ = await cattle_repo.get_by_farmer(db, farmer_id, limit=500)
    cattle_ids = [c.id for c in cattle_list]
    summary = await milk_repo.get_farmer_milk_summary(db, cattle_ids, days=days)
    best = await milk_repo.get_best_cow(db, cattle_ids, days=days)
    if best:
        summary["best_cow_id"] = best["cattle_id"]
        summary["best_cow_yield"] = best["total_yield"]
    return summary


async def get_district_prices(db: AsyncSession, district: str, price_date: date | None = None):
    return await milk_repo.get_district_prices(db, district, price_date)


async def get_best_buyer(db: AsyncSession, district: str, fat_pct: float | None = None):
    return await milk_repo.get_best_buyer(db, district, fat_pct)


async def predict_daily_yield(db: AsyncSession, cattle_id: uuid.UUID) -> dict:
    """Simple moving average prediction based on last 7 days."""
    records = await milk_repo.get_milk_records(db, cattle_id, days=7)
    if not records:
        return {"predicted_yield": 0, "confidence": 0}
    total = sum(r.quantity_litres for r in records)
    days_with_data = len(set(str(r.date) for r in records))
    if days_with_data == 0:
        return {"predicted_yield": 0, "confidence": 0}
    avg = round(total / days_with_data, 2)
    confidence = min(days_with_data / 7.0, 1.0)
    return {"predicted_yield": avg, "confidence": round(confidence, 2)}
