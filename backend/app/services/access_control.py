"""Ownership scopes shared by cooperative and farmer endpoints."""
import uuid

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.cooperative import Cooperative
from app.models.farmer import Farmer
from app.models.user import User, UserRole

ADMIN_ROLES = {UserRole.admin, UserRole.super_admin}


async def owned_cooperative_id(db: AsyncSession, user: User) -> uuid.UUID:
    cooperative_id = await db.scalar(
        select(Cooperative.id).where(
            Cooperative.user_id == user.id,
            Cooperative.is_active.is_(True),
        )
    )
    if cooperative_id is None:
        raise HTTPException(403, "An active cooperative profile is required")
    return cooperative_id


def owned_farmer_ids(user: User):
    return select(Farmer.id).where(Farmer.user_id == user.id)
