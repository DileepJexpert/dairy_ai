import uuid
from datetime import date, timedelta
from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.finance import Transaction, TransactionType
from app.schemas.finance import TransactionCreate


async def add_transaction(db: AsyncSession, farmer_id: uuid.UUID, data: TransactionCreate) -> Transaction:
    txn = Transaction(
        farmer_id=farmer_id,
        type=data.type,
        category=data.category,
        amount=data.amount,
        description=data.description,
        cattle_id=uuid.UUID(data.cattle_id) if data.cattle_id else None,
        date=data.date,
    )
    db.add(txn)
    await db.flush()
    return txn


async def get_transactions(
    db: AsyncSession, farmer_id: uuid.UUID,
    type_filter: str | None = None, category: str | None = None,
    limit: int = 50, offset: int = 0,
) -> list[Transaction]:
    query = select(Transaction).where(Transaction.farmer_id == farmer_id)
    if type_filter:
        query = query.where(Transaction.type == type_filter)
    if category:
        query = query.where(Transaction.category == category)
    query = query.order_by(Transaction.date.desc()).offset(offset).limit(limit)
    result = await db.execute(query)
    return list(result.scalars().all())


async def get_profit_loss(db: AsyncSession, farmer_id: uuid.UUID, months: int = 6) -> dict:
    cutoff = date.today() - timedelta(days=months * 30)

    # Get income
    income_result = await db.execute(
        select(Transaction.category, func.sum(Transaction.amount))
        .where(and_(
            Transaction.farmer_id == farmer_id,
            Transaction.type == "income",
            Transaction.date >= cutoff,
        ))
        .group_by(Transaction.category)
    )
    income_by_cat = {}
    total_income = 0.0
    for cat, amount in income_result.all():
        cat_val = cat.value if hasattr(cat, 'value') else cat
        income_by_cat[cat_val] = round(float(amount), 2)
        total_income += float(amount)

    # Get expenses
    expense_result = await db.execute(
        select(Transaction.category, func.sum(Transaction.amount))
        .where(and_(
            Transaction.farmer_id == farmer_id,
            Transaction.type == "expense",
            Transaction.date >= cutoff,
        ))
        .group_by(Transaction.category)
    )
    expense_by_cat = {}
    total_expenses = 0.0
    for cat, amount in expense_result.all():
        cat_val = cat.value if hasattr(cat, 'value') else cat
        expense_by_cat[cat_val] = round(float(amount), 2)
        total_expenses += float(amount)

    return {
        "total_income": round(total_income, 2),
        "total_expenses": round(total_expenses, 2),
        "net_profit": round(total_income - total_expenses, 2),
        "income_by_category": income_by_cat,
        "expense_by_category": expense_by_cat,
    }


async def get_monthly_summary(db: AsyncSession, farmer_id: uuid.UUID, months: int = 6) -> list[dict]:
    summaries = []
    today = date.today()
    for i in range(months):
        month_start = date(today.year, today.month, 1) - timedelta(days=30 * i)
        month_start = date(month_start.year, month_start.month, 1)
        if month_start.month == 12:
            month_end = date(month_start.year + 1, 1, 1)
        else:
            month_end = date(month_start.year, month_start.month + 1, 1)

        income_result = await db.execute(
            select(func.sum(Transaction.amount))
            .where(and_(
                Transaction.farmer_id == farmer_id,
                Transaction.type == "income",
                Transaction.date >= month_start,
                Transaction.date < month_end,
            ))
        )
        expense_result = await db.execute(
            select(func.sum(Transaction.amount))
            .where(and_(
                Transaction.farmer_id == farmer_id,
                Transaction.type == "expense",
                Transaction.date >= month_start,
                Transaction.date < month_end,
            ))
        )
        income = float(income_result.scalar() or 0)
        expenses = float(expense_result.scalar() or 0)
        summaries.append({
            "month": month_start.strftime("%Y-%m"),
            "income": round(income, 2),
            "expenses": round(expenses, 2),
            "net": round(income - expenses, 2),
        })
    return summaries
