import uuid
import logging

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.repositories import farmer_repo, cattle_repo
from app.services import cattle_service
from app.schemas.cattle import CattleCreate, CattleUpdate

logger = logging.getLogger("dairy_ai.api.cattle")

router = APIRouter(prefix="/cattle", tags=["cattle"])


async def _get_farmer_id(db: AsyncSession, user: User) -> uuid.UUID:
    logger.debug(f"Looking up farmer profile for user_id={user.id}")
    farmer = await farmer_repo.get_by_user_id(db, user.id)
    if not farmer:
        logger.warning(f"Farmer profile not found for user_id={user.id}")
        raise HTTPException(status_code=404, detail="Farmer profile not found. Create profile first.")
    logger.debug(f"Farmer profile found | farmer_id={farmer.id}")
    return farmer.id


@router.post("", status_code=201)
async def create_cattle(
    data: CattleCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"POST /cattle called | user_id={current_user.id} | tag_id={data.tag_id} | name={data.name}")
    farmer_id = await _get_farmer_id(db, current_user)
    logger.debug(f"Calling cattle_service.register_cattle | farmer_id={farmer_id} | breed={data.breed}")
    try:
        cattle = await cattle_service.register_cattle(db, farmer_id, data)
        logger.info(f"Cattle registered successfully | cattle_id={cattle.id} | tag_id={cattle.tag_id} | name={cattle.name}")
        return {
            "success": True,
            "data": {
                "id": str(cattle.id),
                "tag_id": cattle.tag_id,
                "name": cattle.name,
                "breed": cattle.breed.value if hasattr(cattle.breed, 'value') else cattle.breed,
            },
            "message": "Cattle registered",
        }
    except Exception as e:
        logger.error(f"Failed to register cattle for farmer_id={farmer_id}: {e}")
        raise


@router.get("")
async def list_cattle(
    status: str | None = Query(None),
    breed: str | None = Query(None),
    limit: int = Query(50, le=100),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /cattle called | user_id={current_user.id} | status={status} | breed={breed} | limit={limit} | offset={offset}")
    farmer_id = await _get_farmer_id(db, current_user)
    logger.debug(f"Calling cattle_service.list_cattle_by_farmer | farmer_id={farmer_id}")
    cattle_list, total = await cattle_service.list_cattle_by_farmer(
        db, farmer_id, status=status, breed=breed, limit=limit, offset=offset
    )
    logger.info(f"Cattle list retrieved | farmer_id={farmer_id} | total={total} | returned={len(cattle_list)}")
    return {
        "success": True,
        "data": [
            {
                "id": str(c.id),
                "farmer_id": str(c.farmer_id),
                "tag_id": c.tag_id,
                "name": c.name,
                "breed": c.breed.value if hasattr(c.breed, 'value') else c.breed,
                "sex": c.sex.value if hasattr(c.sex, 'value') else c.sex,
                "status": c.status.value if hasattr(c.status, 'value') else c.status,
            }
            for c in cattle_list
        ],
        "total": total,
        "message": "Cattle list",
    }


@router.get("/dashboard")
async def cattle_dashboard(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /cattle/dashboard called | user_id={current_user.id}")
    farmer_id = await _get_farmer_id(db, current_user)
    logger.debug(f"Calling cattle_service.get_cattle_dashboard | farmer_id={farmer_id}")
    dashboard = await cattle_service.get_cattle_dashboard(db, farmer_id)
    logger.info(f"Cattle dashboard retrieved | farmer_id={farmer_id}")
    return {"success": True, "data": dashboard, "message": "Cattle dashboard"}


@router.get("/{cattle_id}")
async def get_cattle(
    cattle_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /cattle/{cattle_id} called | user_id={current_user.id}")
    farmer_id = await _get_farmer_id(db, current_user)
    logger.debug(f"Fetching cattle by id={cattle_id}")
    cattle = await cattle_repo.get_by_id(db, uuid.UUID(cattle_id))
    if not cattle or cattle.farmer_id != farmer_id:
        logger.warning(f"Cattle not found or ownership mismatch | cattle_id={cattle_id} | farmer_id={farmer_id}")
        raise HTTPException(status_code=404, detail="Cattle not found")
    logger.info(f"Cattle found | cattle_id={cattle.id} | tag_id={cattle.tag_id} | name={cattle.name}")
    return {
        "success": True,
        "data": {
            "id": str(cattle.id),
            "farmer_id": str(cattle.farmer_id),
            "tag_id": cattle.tag_id,
            "name": cattle.name,
            "breed": cattle.breed.value if hasattr(cattle.breed, 'value') else cattle.breed,
            "sex": cattle.sex.value if hasattr(cattle.sex, 'value') else cattle.sex,
            "dob": str(cattle.dob) if cattle.dob else None,
            "weight_kg": cattle.weight_kg,
            "status": cattle.status.value if hasattr(cattle.status, 'value') else cattle.status,
        },
        "message": "Cattle details",
    }


@router.put("/{cattle_id}")
async def update_cattle(
    cattle_id: str,
    data: CattleUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"PUT /cattle/{cattle_id} called | user_id={current_user.id}")
    farmer_id = await _get_farmer_id(db, current_user)
    logger.debug(f"Fetching cattle for update | cattle_id={cattle_id}")
    cattle = await cattle_repo.get_by_id(db, uuid.UUID(cattle_id))
    if not cattle or cattle.farmer_id != farmer_id:
        logger.warning(f"Cattle not found or ownership mismatch for update | cattle_id={cattle_id} | farmer_id={farmer_id}")
        raise HTTPException(status_code=404, detail="Cattle not found")
    logger.debug(f"Calling cattle_service.update_cattle | cattle_id={cattle_id}")
    try:
        updated = await cattle_service.update_cattle(db, cattle, data)
        logger.info(f"Cattle updated successfully | cattle_id={updated.id}")
        return {"success": True, "data": {"id": str(updated.id)}, "message": "Cattle updated"}
    except Exception as e:
        logger.error(f"Failed to update cattle | cattle_id={cattle_id}: {e}")
        raise


@router.delete("/{cattle_id}")
async def delete_cattle(
    cattle_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"DELETE /cattle/{cattle_id} called | user_id={current_user.id}")
    farmer_id = await _get_farmer_id(db, current_user)
    logger.debug(f"Fetching cattle for deletion | cattle_id={cattle_id}")
    cattle = await cattle_repo.get_by_id(db, uuid.UUID(cattle_id))
    if not cattle or cattle.farmer_id != farmer_id:
        logger.warning(f"Cattle not found or ownership mismatch for delete | cattle_id={cattle_id} | farmer_id={farmer_id}")
        raise HTTPException(status_code=404, detail="Cattle not found")
    logger.debug(f"Calling cattle_repo.delete | cattle_id={cattle_id}")
    try:
        await cattle_repo.delete(db, cattle)
        logger.info(f"Cattle deleted successfully | cattle_id={cattle_id}")
        return {"success": True, "data": {}, "message": "Cattle deleted"}
    except Exception as e:
        logger.error(f"Failed to delete cattle | cattle_id={cattle_id}: {e}")
        raise
