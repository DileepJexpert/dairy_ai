import logging

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user, require_role
from app.models.user import User, UserRole
from app.repositories import farmer_repo
from app.schemas.farmer import FarmerCreate, FarmerUpdate, FarmerResponse

logger = logging.getLogger("dairy_ai.api.farmers")

router = APIRouter(prefix="/farmers", tags=["farmers"])


@router.get("/me")
async def get_my_profile(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /farmers/me called | user_id={current_user.id}")
    logger.debug(f"Looking up farmer profile for user_id={current_user.id}")
    farmer = await farmer_repo.get_by_user_id(db, current_user.id)
    if not farmer:
        logger.warning(f"Farmer profile not found for user_id={current_user.id}")
        raise HTTPException(status_code=404, detail="Farmer profile not found")
    logger.info(f"Farmer profile found | farmer_id={farmer.id} | name={farmer.name}")
    return {
        "success": True,
        "data": {
            "id": str(farmer.id),
            "user_id": str(farmer.user_id),
            "name": farmer.name,
            "village": farmer.village,
            "district": farmer.district,
            "state": farmer.state,
            "language": farmer.language,
            "total_cattle": farmer.total_cattle,
        },
        "message": "Farmer profile",
    }


@router.post("/me")
async def create_my_profile(
    data: FarmerCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"POST /farmers/me called | user_id={current_user.id} | name={data.name}")
    logger.debug(f"Checking if farmer profile already exists for user_id={current_user.id}")
    existing = await farmer_repo.get_by_user_id(db, current_user.id)
    if existing:
        logger.warning(f"Farmer profile already exists for user_id={current_user.id} | farmer_id={existing.id}")
        raise HTTPException(status_code=409, detail="Profile already exists")
    logger.debug(f"Creating farmer profile for user_id={current_user.id} | data={data.model_dump()}")
    try:
        farmer = await farmer_repo.create(db, current_user.id, **data.model_dump())
        logger.info(f"Farmer profile created | farmer_id={farmer.id} | name={farmer.name}")
        return {
            "success": True,
            "data": {"id": str(farmer.id), "name": farmer.name},
            "message": "Farmer profile created",
        }
    except Exception as e:
        logger.error(f"Failed to create farmer profile for user_id={current_user.id}: {e}")
        raise


@router.put("/me")
async def update_my_profile(
    data: FarmerUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"PUT /farmers/me called | user_id={current_user.id}")
    logger.debug(f"Update fields: {data.model_dump(exclude_unset=True)}")
    farmer = await farmer_repo.get_by_user_id(db, current_user.id)
    if not farmer:
        logger.warning(f"Farmer profile not found for update | user_id={current_user.id}")
        raise HTTPException(status_code=404, detail="Farmer profile not found")
    try:
        updated = await farmer_repo.update(db, farmer, **data.model_dump(exclude_unset=True))
        logger.info(f"Farmer profile updated | farmer_id={updated.id} | name={updated.name}")
        return {"success": True, "data": {"id": str(updated.id), "name": updated.name}, "message": "Profile updated"}
    except Exception as e:
        logger.error(f"Failed to update farmer profile for user_id={current_user.id}: {e}")
        raise


@router.get("/{farmer_id}")
async def get_farmer(
    farmer_id: str,
    current_user: User = Depends(require_role(UserRole.admin)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    import uuid as _uuid
    logger.info(f"GET /farmers/{farmer_id} called | admin_user_id={current_user.id}")
    logger.debug(f"Looking up farmer by id={farmer_id}")
    farmer = await farmer_repo.get_by_id(db, _uuid.UUID(farmer_id))
    if not farmer:
        logger.warning(f"Farmer not found | farmer_id={farmer_id}")
        raise HTTPException(status_code=404, detail="Farmer not found")
    logger.info(f"Farmer found | farmer_id={farmer.id} | name={farmer.name} | district={farmer.district}")
    return {
        "success": True,
        "data": {
            "id": str(farmer.id),
            "user_id": str(farmer.user_id),
            "name": farmer.name,
            "village": farmer.village,
            "district": farmer.district,
            "state": farmer.state,
            "language": farmer.language,
            "total_cattle": farmer.total_cattle,
        },
        "message": "Farmer profile",
    }
