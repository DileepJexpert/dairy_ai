"""Repository for financial transactions."""
import uuid
from datetime import date
from sqlalchemy import select, func, and_, case
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.finance import Transaction, TransactionType, TransactionCategory


async def create(db: AsyncSession, farmer_id: uuid.UUID, data: dict) -> Transaction:
    txn = Transaction(farmer_id=farmer_id, **data)
    db.add(txn)
    await db.flush()
    return txn


async def get_by_farmer(
    db: AsyncSession, farmer_id: uuid.UUID,
    txn_type: TransactionType | None = None,
    category: TransactionCategory | None = None,
    from_date: date | None = None,
    to_date: date | None = None,
    limit: int = 100,
) -> list[Transaction]:
    query = select(Transaction).where(Transaction.farmer_id == farmer_id)
    if txn_type:
        query = query.where(Transaction.type == txn_type)
    if category:
        query = query.where(Transaction.category == category)
    if from_date:
        query = query.where(Transaction.date >= from_date)
    if to_date:
        query = query.where(Transaction.date <= to_date)
    query = query.order_by(Transaction.date.desc()).limit(limit)
    result = await db.execute(query)
    return list(result.scalars().all())


async def get_summary(
    db: AsyncSession, farmer_id: uuid.UUID,
    from_date: date | None = None, to_date: date | None = None,
) -> dict:
    """Return total income, expense, and net for a farmer in period."""
    conditions = [Transaction.farmer_id == farmer_id]
    if from_date:
        conditions.append(Transaction.date >= from_date)
    if to_date:
        conditions.append(Transaction.date <= to_date)

    result = await db.execute(
        select(
            func.coalesce(func.sum(case(
                (Transaction.type == TransactionType.income, Transaction.amount),
                else_=0,
            )), 0).label("total_income"),
            func.coalesce(func.sum(case(
                (Transaction.type == TransactionType.expense, Transaction.amount),
                else_=0,
            )), 0).label("total_expense"),
            func.count().label("transaction_count"),
        ).where(and_(*conditions))
    )
    row = result.one()
    return {
        "total_income": float(row.total_income),
        "total_expense": float(row.total_expense),
        "net": float(row.total_income) - float(row.total_expense),
        "transaction_count": row.transaction_count,
    }


async def get_category_breakdown(
    db: AsyncSession, farmer_id: uuid.UUID,
    from_date: date | None = None, to_date: date | None = None,
) -> list[dict]:
    conditions = [Transaction.farmer_id == farmer_id]
    if from_date:
        conditions.append(Transaction.date >= from_date)
    if to_date:
        conditions.append(Transaction.date <= to_date)

    result = await db.execute(
        select(
            Transaction.category,
            Transaction.type,
            func.sum(Transaction.amount).label("total"),
            func.count().label("count"),
        )
        .where(and_(*conditions))
        .group_by(Transaction.category, Transaction.type)
        .order_by(func.sum(Transaction.amount).desc())
    )
    return [
        {
            "category": row.category.value,
            "type": row.type.value,
            "total": float(row.total),
            "count": row.count,
        }
        for row in result.all()
    ]
