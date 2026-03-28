import logging
import uuid
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.cattle import Cattle
from app.repositories import cattle_repo, farmer_repo
from app.schemas.cattle import CattleCreate, CattleUpdate

logger = logging.getLogger("dairy_ai.services.cattle")


async def register_cattle(db: AsyncSession, farmer_id: uuid.UUID, data: CattleCreate) -> Cattle:
    logger.info(f"register_cattle called | farmer_id={farmer_id}, tag_id={data.tag_id}, breed={data.breed}, sex={data.sex}")

    # Check duplicate tag
    logger.debug(f"Checking for duplicate tag_id={data.tag_id}...")
    existing = await cattle_repo.get_by_tag_id(db, data.tag_id)
    if existing:
        logger.warning(f"Duplicate tag_id found | tag_id={data.tag_id}, existing_cattle_id={existing.id}")
        from fastapi import HTTPException
        raise HTTPException(status_code=409, detail="Cattle with this tag_id already exists")

    logger.debug(f"No duplicate found. Creating cattle record in database | tag_id={data.tag_id}")
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
    logger.info(f"Cattle record created | cattle_id={cattle.id}, tag_id={data.tag_id}")

    # Increment farmer total_cattle
    logger.debug(f"Incrementing total_cattle for farmer_id={farmer_id}")
    farmer = await farmer_repo.get_by_id(db, farmer_id)
    if farmer:
        old_count = farmer.total_cattle or 0
        farmer.total_cattle = old_count + 1
        await db.flush()
        logger.debug(f"Farmer total_cattle updated: {old_count} -> {farmer.total_cattle}")
    else:
        logger.warning(f"Farmer not found for id={farmer_id}, skipping total_cattle increment")

    logger.info(f"register_cattle completed successfully | cattle_id={cattle.id}, farmer_id={farmer_id}")
    return cattle


async def update_cattle(db: AsyncSession, cattle: Cattle, data: CattleUpdate) -> Cattle:
    update_data = data.model_dump(exclude_unset=True)
    logger.info(f"update_cattle called | cattle_id={cattle.id}, fields_to_update={list(update_data.keys())}")
    logger.debug(f"Update values: {update_data}")

    updated = await cattle_repo.update(db, cattle, **update_data)
    logger.info(f"Cattle updated successfully | cattle_id={cattle.id}")
    return updated


async def get_cattle(db: AsyncSession, cattle_id: uuid.UUID) -> Cattle | None:
    logger.debug(f"get_cattle called | cattle_id={cattle_id}")
    cattle = await cattle_repo.get_by_id(db, cattle_id)
    if cattle:
        logger.debug(f"Cattle found | cattle_id={cattle.id}, tag_id={cattle.tag_id}")
    else:
        logger.debug(f"Cattle not found | cattle_id={cattle_id}")
    return cattle


async def list_cattle_by_farmer(
    db: AsyncSession, farmer_id: uuid.UUID,
    status: str | None = None, breed: str | None = None,
    limit: int = 50, offset: int = 0,
) -> tuple[list[Cattle], int]:
    logger.info(f"list_cattle_by_farmer called | farmer_id={farmer_id}, status={status}, breed={breed}, limit={limit}, offset={offset}")
    cattle_list, total = await cattle_repo.get_by_farmer(db, farmer_id, status=status, breed=breed, limit=limit, offset=offset)
    logger.info(f"list_cattle_by_farmer result | farmer_id={farmer_id}, returned={len(cattle_list)}, total={total}")
    return cattle_list, total


async def get_cattle_dashboard(db: AsyncSession, farmer_id: uuid.UUID) -> dict:
    logger.info(f"get_cattle_dashboard called | farmer_id={farmer_id}")
    dashboard = await cattle_repo.count_by_farmer(db, farmer_id)
    logger.info(f"Cattle dashboard loaded | farmer_id={farmer_id}, stats={dashboard}")
    return dashboard
