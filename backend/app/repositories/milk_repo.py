import logging
import uuid
from datetime import date, timedelta
from sqlalchemy import select, func, and_, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.milk import MilkRecord, MilkPrice

logger = logging.getLogger("dairy_ai.repos.milk")


async def create_milk_record(db: AsyncSession, cattle_id: uuid.UUID, **kwargs) -> MilkRecord:
    logger.info("Creating milk record for cattle_id=%s: quantity=%s, session=%s, price=%s",
                cattle_id, kwargs.get("quantity_litres"), kwargs.get("session"), kwargs.get("price_per_litre"))
    record = MilkRecord(cattle_id=cattle_id, **kwargs)
    db.add(record)
    await db.flush()
    logger.info("Created milk record id=%s for cattle %s", record.id, cattle_id)
    return record


async def get_milk_records(db: AsyncSession, cattle_id: uuid.UUID, days: int = 30) -> list[MilkRecord]:
    cutoff = date.today() - timedelta(days=days)
    logger.debug("Querying milk records for cattle_id=%s, last %d days (since %s)", cattle_id, days, cutoff)
    result = await db.execute(
        select(MilkRecord)
        .where(and_(MilkRecord.cattle_id == cattle_id, MilkRecord.date >= cutoff))
        .order_by(MilkRecord.date.desc(), MilkRecord.session)
    )
    records = list(result.scalars().all())
    logger.info("Found %d milk records for cattle %s over last %d days", len(records), cattle_id, days)
    return records


async def get_farmer_milk_records(db: AsyncSession, cattle_ids: list[uuid.UUID], days: int = 30) -> list[MilkRecord]:
    if not cattle_ids:
        logger.debug("No cattle IDs provided for farmer milk records query, returning empty")
        return []
    cutoff = date.today() - timedelta(days=days)
    logger.debug("Querying farmer milk records for %d cattle, last %d days (since %s)",
                 len(cattle_ids), days, cutoff)
    result = await db.execute(
        select(MilkRecord)
        .where(and_(MilkRecord.cattle_id.in_(cattle_ids), MilkRecord.date >= cutoff))
        .order_by(MilkRecord.date.desc())
    )
    records = list(result.scalars().all())
    logger.info("Found %d milk records for %d cattle over last %d days", len(records), len(cattle_ids), days)
    return records


async def get_farmer_milk_summary(db: AsyncSession, cattle_ids: list[uuid.UUID], days: int = 30) -> dict:
    if not cattle_ids:
        logger.debug("No cattle IDs provided for milk summary, returning zeros")
        return {"total_litres": 0, "total_income": 0, "avg_price": None}
    cutoff = date.today() - timedelta(days=days)
    logger.debug("Computing milk summary for %d cattle, last %d days (since %s)", len(cattle_ids), days, cutoff)
    result = await db.execute(
        select(
            func.sum(MilkRecord.quantity_litres).label("total_litres"),
            func.sum(MilkRecord.total_amount).label("total_income"),
            func.avg(MilkRecord.price_per_litre).label("avg_price"),
        )
        .where(and_(MilkRecord.cattle_id.in_(cattle_ids), MilkRecord.date >= cutoff))
    )
    row = result.one()
    summary = {
        "total_litres": round(float(row.total_litres or 0), 2),
        "total_income": round(float(row.total_income or 0), 2),
        "avg_price": round(float(row.avg_price), 2) if row.avg_price else None,
    }
    logger.info("Milk summary for %d cattle (last %dd): total_litres=%.2f, total_income=%.2f, avg_price=%s",
                len(cattle_ids), days, summary["total_litres"], summary["total_income"], summary["avg_price"])
    return summary


async def get_best_cow(db: AsyncSession, cattle_ids: list[uuid.UUID], days: int = 30) -> dict | None:
    if not cattle_ids:
        logger.debug("No cattle IDs provided for best cow query, returning None")
        return None
    cutoff = date.today() - timedelta(days=days)
    logger.debug("Querying best cow among %d cattle, last %d days", len(cattle_ids), days)
    result = await db.execute(
        select(MilkRecord.cattle_id, func.sum(MilkRecord.quantity_litres).label("total"))
        .where(and_(MilkRecord.cattle_id.in_(cattle_ids), MilkRecord.date >= cutoff))
        .group_by(MilkRecord.cattle_id)
        .order_by(desc("total"))
        .limit(1)
    )
    row = result.first()
    if row:
        best = {"cattle_id": str(row[0]), "total_yield": round(float(row[1]), 2)}
        logger.info("Best cow: cattle_id=%s with total_yield=%.2f litres over %d days",
                     best["cattle_id"], best["total_yield"], days)
        return best
    logger.info("No milk records found to determine best cow among %d cattle", len(cattle_ids))
    return None


async def get_district_prices(db: AsyncSession, district: str, price_date: date | None = None) -> list[MilkPrice]:
    logger.debug("Querying milk prices for district=%s, date=%s", district, price_date)
    query = select(MilkPrice).where(MilkPrice.district == district)
    if price_date:
        query = query.where(MilkPrice.date == price_date)
    query = query.order_by(MilkPrice.price_per_litre.desc())
    result = await db.execute(query)
    prices = list(result.scalars().all())
    logger.info("Found %d milk prices for district %s (date=%s)", len(prices), district, price_date)
    return prices


async def get_best_buyer(db: AsyncSession, district: str, fat_pct: float | None = None) -> MilkPrice | None:
    logger.debug("Querying best buyer for district=%s, fat_pct=%s", district, fat_pct)
    query = select(MilkPrice).where(MilkPrice.district == district)
    if fat_pct:
        query = query.where(MilkPrice.fat_pct_basis <= fat_pct)
    query = query.order_by(MilkPrice.price_per_litre.desc()).limit(1)
    result = await db.execute(query)
    buyer = result.scalar_one_or_none()
    if buyer:
        logger.info("Best buyer in district %s: buyer=%s, price=%.2f/litre",
                     district, buyer.buyer_name, buyer.price_per_litre)
    else:
        logger.info("No buyer found for district %s with fat_pct=%s", district, fat_pct)
    return buyer
