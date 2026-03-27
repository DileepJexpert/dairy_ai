import uuid
from datetime import date, timedelta
from sqlalchemy import select, func, and_, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.milk import MilkRecord, MilkPrice


async def create_milk_record(db: AsyncSession, cattle_id: uuid.UUID, **kwargs) -> MilkRecord:
    record = MilkRecord(cattle_id=cattle_id, **kwargs)
    db.add(record)
    await db.flush()
    return record


async def get_milk_records(db: AsyncSession, cattle_id: uuid.UUID, days: int = 30) -> list[MilkRecord]:
    cutoff = date.today() - timedelta(days=days)
    result = await db.execute(
        select(MilkRecord)
        .where(and_(MilkRecord.cattle_id == cattle_id, MilkRecord.date >= cutoff))
        .order_by(MilkRecord.date.desc(), MilkRecord.session)
    )
    return list(result.scalars().all())


async def get_farmer_milk_records(db: AsyncSession, cattle_ids: list[uuid.UUID], days: int = 30) -> list[MilkRecord]:
    if not cattle_ids:
        return []
    cutoff = date.today() - timedelta(days=days)
    result = await db.execute(
        select(MilkRecord)
        .where(and_(MilkRecord.cattle_id.in_(cattle_ids), MilkRecord.date >= cutoff))
        .order_by(MilkRecord.date.desc())
    )
    return list(result.scalars().all())


async def get_farmer_milk_summary(db: AsyncSession, cattle_ids: list[uuid.UUID], days: int = 30) -> dict:
    if not cattle_ids:
        return {"total_litres": 0, "total_income": 0, "avg_price": None}
    cutoff = date.today() - timedelta(days=days)
    result = await db.execute(
        select(
            func.sum(MilkRecord.quantity_litres).label("total_litres"),
            func.sum(MilkRecord.total_amount).label("total_income"),
            func.avg(MilkRecord.price_per_litre).label("avg_price"),
        )
        .where(and_(MilkRecord.cattle_id.in_(cattle_ids), MilkRecord.date >= cutoff))
    )
    row = result.one()
    return {
        "total_litres": round(float(row.total_litres or 0), 2),
        "total_income": round(float(row.total_income or 0), 2),
        "avg_price": round(float(row.avg_price), 2) if row.avg_price else None,
    }


async def get_best_cow(db: AsyncSession, cattle_ids: list[uuid.UUID], days: int = 30) -> dict | None:
    if not cattle_ids:
        return None
    cutoff = date.today() - timedelta(days=days)
    result = await db.execute(
        select(MilkRecord.cattle_id, func.sum(MilkRecord.quantity_litres).label("total"))
        .where(and_(MilkRecord.cattle_id.in_(cattle_ids), MilkRecord.date >= cutoff))
        .group_by(MilkRecord.cattle_id)
        .order_by(desc("total"))
        .limit(1)
    )
    row = result.first()
    if row:
        return {"cattle_id": str(row[0]), "total_yield": round(float(row[1]), 2)}
    return None


async def get_district_prices(db: AsyncSession, district: str, price_date: date | None = None) -> list[MilkPrice]:
    query = select(MilkPrice).where(MilkPrice.district == district)
    if price_date:
        query = query.where(MilkPrice.date == price_date)
    query = query.order_by(MilkPrice.price_per_litre.desc())
    result = await db.execute(query)
    return list(result.scalars().all())


async def get_best_buyer(db: AsyncSession, district: str, fat_pct: float | None = None) -> MilkPrice | None:
    query = select(MilkPrice).where(MilkPrice.district == district)
    if fat_pct:
        query = query.where(MilkPrice.fat_pct_basis <= fat_pct)
    query = query.order_by(MilkPrice.price_per_litre.desc()).limit(1)
    result = await db.execute(query)
    return result.scalar_one_or_none()
