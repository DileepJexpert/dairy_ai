import uuid

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.repositories import farmer_repo, cattle_repo
from app.services import cattle_service
from app.schemas.cattle import CattleCreate, CattleUpdate

router = APIRouter(prefix="/cattle", tags=["cattle"])


async def _get_farmer_id(db: AsyncSession, user: User) -> uuid.UUID:
    farmer = await farmer_repo.get_by_user_id(db, user.id)
    if not farmer:
        raise HTTPException(status_code=404, detail="Farmer profile not found. Create profile first.")
    return farmer.id


@router.post("", status_code=201)
async def create_cattle(
    data: CattleCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    farmer_id = await _get_farmer_id(db, current_user)
    cattle = await cattle_service.register_cattle(db, farmer_id, data)
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


@router.get("")
async def list_cattle(
    status: str | None = Query(None),
    breed: str | None = Query(None),
    limit: int = Query(50, le=100),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    farmer_id = await _get_farmer_id(db, current_user)
    cattle_list, total = await cattle_service.list_cattle_by_farmer(
        db, farmer_id, status=status, breed=breed, limit=limit, offset=offset
    )
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
    farmer_id = await _get_farmer_id(db, current_user)
    dashboard = await cattle_service.get_cattle_dashboard(db, farmer_id)
    return {"success": True, "data": dashboard, "message": "Cattle dashboard"}


@router.get("/{cattle_id}")
async def get_cattle(
    cattle_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    farmer_id = await _get_farmer_id(db, current_user)
    cattle = await cattle_repo.get_by_id(db, uuid.UUID(cattle_id))
    if not cattle or cattle.farmer_id != farmer_id:
        raise HTTPException(status_code=404, detail="Cattle not found")
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
    farmer_id = await _get_farmer_id(db, current_user)
    cattle = await cattle_repo.get_by_id(db, uuid.UUID(cattle_id))
    if not cattle or cattle.farmer_id != farmer_id:
        raise HTTPException(status_code=404, detail="Cattle not found")
    updated = await cattle_service.update_cattle(db, cattle, data)
    return {"success": True, "data": {"id": str(updated.id)}, "message": "Cattle updated"}


@router.delete("/{cattle_id}")
async def delete_cattle(
    cattle_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    farmer_id = await _get_farmer_id(db, current_user)
    cattle = await cattle_repo.get_by_id(db, uuid.UUID(cattle_id))
    if not cattle or cattle.farmer_id != farmer_id:
        raise HTTPException(status_code=404, detail="Cattle not found")
    await cattle_repo.delete(db, cattle)
    return {"success": True, "data": {}, "message": "Cattle deleted"}
