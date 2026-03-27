import uuid
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.cattle import Cattle
from app.repositories import cattle_repo, farmer_repo
from app.schemas.cattle import CattleCreate, CattleUpdate


async def register_cattle(db: AsyncSession, farmer_id: uuid.UUID, data: CattleCreate) -> Cattle:
    # Check duplicate tag
    existing = await cattle_repo.get_by_tag_id(db, data.tag_id)
    if existing:
        from fastapi import HTTPException
        raise HTTPException(status_code=409, detail="Cattle with this tag_id already exists")

    cattle = await cattle_repo.create(
        db, farmer_id,
        tag_id=data.tag_id,
        name=data.name,
        breed=data.breed,
        sex=data.sex,
        dob=data.dob,
        weight_kg=data.weight_kg,
        photo_url=data.photo_url,
    )

    # Increment farmer total_cattle
    farmer = await farmer_repo.get_by_id(db, farmer_id)
    if farmer:
        farmer.total_cattle = (farmer.total_cattle or 0) + 1
        await db.flush()

    return cattle


async def update_cattle(db: AsyncSession, cattle: Cattle, data: CattleUpdate) -> Cattle:
    update_data = data.model_dump(exclude_unset=True)
    return await cattle_repo.update(db, cattle, **update_data)


async def get_cattle(db: AsyncSession, cattle_id: uuid.UUID) -> Cattle | None:
    return await cattle_repo.get_by_id(db, cattle_id)


async def list_cattle_by_farmer(
    db: AsyncSession, farmer_id: uuid.UUID,
    status: str | None = None, breed: str | None = None,
    limit: int = 50, offset: int = 0,
) -> tuple[list[Cattle], int]:
    return await cattle_repo.get_by_farmer(db, farmer_id, status=status, breed=breed, limit=limit, offset=offset)


async def get_cattle_dashboard(db: AsyncSession, farmer_id: uuid.UUID) -> dict:
    return await cattle_repo.count_by_farmer(db, farmer_id)
