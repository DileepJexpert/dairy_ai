"""Repository for feed plans."""
import uuid
from datetime import date
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.feed import FeedPlan


async def create(db: AsyncSession, cattle_id: uuid.UUID, data: dict) -> FeedPlan:
    plan = FeedPlan(cattle_id=cattle_id, **data)
    db.add(plan)
    await db.flush()
    return plan


async def get_current(db: AsyncSession, cattle_id: uuid.UUID) -> FeedPlan | None:
    today = date.today()
    result = await db.execute(
        select(FeedPlan).where(
            and_(
                FeedPlan.cattle_id == cattle_id,
                FeedPlan.valid_from <= today,
                (FeedPlan.valid_to >= today) | (FeedPlan.valid_to.is_(None)),
            )
        ).order_by(FeedPlan.created_at.desc()).limit(1)
    )
    return result.scalar_one_or_none()


async def get_history(
    db: AsyncSession, cattle_id: uuid.UUID, limit: int = 20
) -> list[FeedPlan]:
    result = await db.execute(
        select(FeedPlan)
        .where(FeedPlan.cattle_id == cattle_id)
        .order_by(FeedPlan.created_at.desc())
        .limit(limit)
    )
    return list(result.scalars().all())


async def get_by_id(db: AsyncSession, plan_id: uuid.UUID) -> FeedPlan | None:
    result = await db.execute(select(FeedPlan).where(FeedPlan.id == plan_id))
    return result.scalar_one_or_none()
