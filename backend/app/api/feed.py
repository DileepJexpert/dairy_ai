import uuid
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.repositories import farmer_repo, cattle_repo
from app.services import feed_service

router = APIRouter(tags=["feed"])


@router.post("/cattle/{cattle_id}/feed-plan/generate", status_code=201)
async def generate_feed_plan(
    cattle_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    farmer = await farmer_repo.get_by_user_id(db, current_user.id)
    if not farmer:
        raise HTTPException(status_code=404, detail="Farmer profile not found")
    cid = uuid.UUID(cattle_id)
    cattle = await cattle_repo.get_by_id(db, cid)
    if not cattle or cattle.farmer_id != farmer.id:
        raise HTTPException(status_code=404, detail="Cattle not found")
    plan = await feed_service.generate_feed_plan(db, cid)
    return {
        "success": True,
        "data": {
            "id": str(plan.id),
            "plan": plan.plan,
            "total_cost_per_day": plan.total_cost_per_day,
            "nutrition_score": plan.nutrition_score,
        },
        "message": "Feed plan generated",
    }


@router.get("/cattle/{cattle_id}/feed-plan/current")
async def get_current_plan(
    cattle_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    farmer = await farmer_repo.get_by_user_id(db, current_user.id)
    if not farmer:
        raise HTTPException(status_code=404, detail="Farmer profile not found")
    cid = uuid.UUID(cattle_id)
    cattle = await cattle_repo.get_by_id(db, cid)
    if not cattle or cattle.farmer_id != farmer.id:
        raise HTTPException(status_code=404, detail="Cattle not found")
    plan = await feed_service.get_current_feed_plan(db, cid)
    if not plan:
        return {"success": True, "data": None, "message": "No feed plan"}
    return {
        "success": True,
        "data": {
            "id": str(plan.id),
            "plan": plan.plan,
            "total_cost_per_day": plan.total_cost_per_day,
            "nutrition_score": plan.nutrition_score,
            "valid_from": str(plan.valid_from),
        },
        "message": "Current feed plan",
    }
