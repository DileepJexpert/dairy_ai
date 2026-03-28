import uuid
import logging

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.repositories import farmer_repo, cattle_repo
from app.services import breeding_service
from app.schemas.breeding import BreedingEventCreate

logger = logging.getLogger("dairy_ai.api.breeding")

router = APIRouter(tags=["breeding"])


@router.post("/cattle/{cattle_id}/breeding", status_code=201)
async def record_event(
    cattle_id: str, data: BreedingEventCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"POST /cattle/{cattle_id}/breeding called | user_id={current_user.id} | event_type={data.event_type}")
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
    logger.debug(f"Calling breeding_service.record_breeding_event | cattle_id={cid}")
    try:
        record = await breeding_service.record_breeding_event(db, cid, data)
        logger.info(f"Breeding event recorded | record_id={record.id} | cattle_id={cid} | event_type={record.event_type.value if hasattr(record.event_type, 'value') else record.event_type}")
        return {
            "success": True,
            "data": {"id": str(record.id), "event_type": record.event_type.value if hasattr(record.event_type, 'value') else record.event_type},
            "message": "Breeding event recorded",
        }
    except Exception as e:
        logger.error(f"Failed to record breeding event for cattle_id={cid}: {e}")
        raise


@router.get("/cattle/{cattle_id}/breeding")
async def get_timeline(
    cattle_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /cattle/{cattle_id}/breeding called | user_id={current_user.id}")
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
    logger.debug(f"Calling breeding_service.get_breeding_timeline | cattle_id={cid}")
    records = await breeding_service.get_breeding_timeline(db, cid)
    logger.info(f"Breeding timeline retrieved | cattle_id={cid} | events_count={len(records)}")
    return {
        "success": True,
        "data": [
            {
                "id": str(r.id),
                "event_type": r.event_type.value if hasattr(r.event_type, 'value') else r.event_type,
                "date": str(r.date),
                "expected_calving_date": str(r.expected_calving_date) if r.expected_calving_date else None,
            }
            for r in records
        ],
        "message": "Breeding timeline",
    }


@router.get("/farmers/me/expected-calvings")
async def expected_calvings(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /farmers/me/expected-calvings called | user_id={current_user.id}")
    logger.debug(f"Looking up farmer profile for user_id={current_user.id}")
    farmer = await farmer_repo.get_by_user_id(db, current_user.id)
    if not farmer:
        logger.warning(f"Farmer profile not found | user_id={current_user.id}")
        raise HTTPException(status_code=404, detail="Farmer profile not found")
    logger.debug(f"Fetching all cattle for farmer_id={farmer.id}")
    cattle_list, _ = await cattle_repo.get_by_farmer(db, farmer.id, limit=500)
    cattle_ids = [c.id for c in cattle_list]
    logger.debug(f"Calling breeding_service.get_expected_calvings | farmer_id={farmer.id} | cattle_count={len(cattle_ids)}")
    calvings = await breeding_service.get_expected_calvings(db, cattle_ids)
    logger.info(f"Expected calvings retrieved | farmer_id={farmer.id} | calvings_count={len(calvings)}")
    return {
        "success": True,
        "data": [
            {
                "id": str(r.id),
                "cattle_id": str(r.cattle_id),
                "expected_calving_date": str(r.expected_calving_date),
            }
            for r in calvings
        ],
        "message": "Expected calvings",
    }
