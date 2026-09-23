import uuid
import logging

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.repositories import farmer_repo, cattle_repo
from app.services import feed_service

logger = logging.getLogger("dairy_ai.api.feed")

router = APIRouter(tags=["feed"])


@router.post("/cattle/{cattle_id}/feed-plan/generate", status_code=201)
async def generate_feed_plan(
    cattle_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"POST /cattle/{cattle_id}/feed-plan/generate called | user_id={current_user.id}")
    logger.debug(f"Looking up farmer profile for user_id={current_user.id}")
    farmer = await farmer_repo.get_by_user_id(db, current_user.id)
    if not farmer:
        logger.warning(f"Farmer profile not found | user_id={current_user.id}")
        raise HTTPException(status_code=404, detail="Farmer profile not found")
    cid = uuid.UUID(cattle_id)
    logger.debug(f"Verifying cattle ownership | cattle_id={cid} | farmer_id={farmer.id}")
    cattle = await cattle_repo.get_by_id(db, cid)
    if not cattle or cattle.farmer_id != farmer.id:
        logger.warning(f"Cattle not found or ownership mismatch | cattle_id={cattle_id} | farmer_id={farmer.id}")
        raise HTTPException(status_code=404, detail="Cattle not found")
    logger.debug(f"Calling feed_service.generate_feed_plan | cattle_id={cid}")
    try:
        plan = await feed_service.generate_feed_plan(db, cid)
        logger.info(f"Feed plan generated | plan_id={plan.id} | cattle_id={cid} | cost_per_day={plan.total_cost_per_day} | nutrition_score={plan.nutrition_score}")
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
    except Exception as e:
        logger.error(f"Failed to generate feed plan for cattle_id={cid}: {e}")
        raise


@router.get("/cattle/{cattle_id}/feed-plan/current")
async def get_current_plan(
    cattle_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /cattle/{cattle_id}/feed-plan/current called | user_id={current_user.id}")
    logger.debug(f"Looking up farmer profile for user_id={current_user.id}")
    farmer = await farmer_repo.get_by_user_id(db, current_user.id)
    if not farmer:
        logger.warning(f"Farmer profile not found | user_id={current_user.id}")
        raise HTTPException(status_code=404, detail="Farmer profile not found")
    cid = uuid.UUID(cattle_id)
    logger.debug(f"Verifying cattle ownership | cattle_id={cid} | farmer_id={farmer.id}")
    cattle = await cattle_repo.get_by_id(db, cid)
    if not cattle or cattle.farmer_id != farmer.id:
        logger.warning(f"Cattle not found or ownership mismatch | cattle_id={cattle_id} | farmer_id={farmer.id}")
        raise HTTPException(status_code=404, detail="Cattle not found")
    logger.debug(f"Calling feed_service.get_current_feed_plan | cattle_id={cid}")
    plan = await feed_service.get_current_feed_plan(db, cid)
    if not plan:
        logger.info(f"No current feed plan found for cattle_id={cid}")
        return {"success": True, "data": None, "message": "No feed plan"}
    logger.info(f"Current feed plan retrieved | plan_id={plan.id} | cattle_id={cid} | valid_from={plan.valid_from}")
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


@router.get("/cattle/{cattle_id}/feed-plans")
@router.get("/feed-plans")
async def get_feed_plans(
    cattle_id: str | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    if not cattle_id:
        return {"success": True, "data": [], "message": "No cattle specified"}
    try:
        cid = uuid.UUID(cattle_id)
    except ValueError:
        return {"success": True, "data": [], "message": "Invalid cattle_id"}
    plan = await feed_service.get_current_feed_plan(db, cid)
    data = []
    if plan:
        data.append({
            "id": str(plan.id),
            "plan": plan.plan,
            "total_cost_per_day": plan.total_cost_per_day,
            "nutrition_score": plan.nutrition_score,
            "valid_from": str(plan.valid_from),
        })
    return {"success": True, "data": data, "message": "Feed plans"}


@router.post("/feed-plans/generate", status_code=201)
async def generate_feed_plan_alt(
    payload: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    cattle_id = payload.get("cattle_id")
    if not cattle_id:
        raise HTTPException(status_code=422, detail="cattle_id is required")
    return await generate_feed_plan(cattle_id=cattle_id, current_user=current_user, db=db)
