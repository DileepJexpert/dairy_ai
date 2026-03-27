from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user, require_role
from app.models.user import User, UserRole
from app.repositories import farmer_repo
from app.schemas.farmer import FarmerCreate, FarmerUpdate, FarmerResponse

router = APIRouter(prefix="/farmers", tags=["farmers"])


@router.get("/me")
async def get_my_profile(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    farmer = await farmer_repo.get_by_user_id(db, current_user.id)
    if not farmer:
        raise HTTPException(status_code=404, detail="Farmer profile not found")
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
    existing = await farmer_repo.get_by_user_id(db, current_user.id)
    if existing:
        raise HTTPException(status_code=409, detail="Profile already exists")
    farmer = await farmer_repo.create(db, current_user.id, **data.model_dump())
    return {
        "success": True,
        "data": {"id": str(farmer.id), "name": farmer.name},
        "message": "Farmer profile created",
    }


@router.put("/me")
async def update_my_profile(
    data: FarmerUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    farmer = await farmer_repo.get_by_user_id(db, current_user.id)
    if not farmer:
        raise HTTPException(status_code=404, detail="Farmer profile not found")
    updated = await farmer_repo.update(db, farmer, **data.model_dump(exclude_unset=True))
    return {"success": True, "data": {"id": str(updated.id), "name": updated.name}, "message": "Profile updated"}


@router.get("/{farmer_id}")
async def get_farmer(
    farmer_id: str,
    current_user: User = Depends(require_role(UserRole.admin)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    import uuid as _uuid
    farmer = await farmer_repo.get_by_id(db, _uuid.UUID(farmer_id))
    if not farmer:
        raise HTTPException(status_code=404, detail="Farmer not found")
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
