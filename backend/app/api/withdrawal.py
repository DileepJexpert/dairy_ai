import uuid
import logging

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user, require_role
from app.models.user import User, UserRole
from app.repositories import farmer_repo
from app.services import withdrawal_service

logger = logging.getLogger("dairy_ai.api.withdrawal")

router = APIRouter(prefix="/withdrawal", tags=["Antibiotic Withdrawal"])


async def _get_farmer_id(db: AsyncSession, user: User) -> uuid.UUID:
    farmer = await farmer_repo.get_by_user_id(db, user.id)
    if not farmer:
        raise HTTPException(status_code=404, detail="Farmer profile not found. Create profile first.")
    return farmer.id


@router.post("/record", status_code=201)
async def record_treatment(
    data: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Record an antibiotic treatment with automatic withdrawal period calculation."""
    logger.info(f"POST /withdrawal/record called | user_id={current_user.id}")
    farmer_id = await _get_farmer_id(db, current_user)

    required_fields = ["cattle_id", "medicine_name", "active_ingredient", "treatment_start_date", "treatment_end_date"]
    for field in required_fields:
        if field not in data:
            logger.warning(f"Missing required field: {field}")
            raise HTTPException(status_code=422, detail=f"Missing required field: {field}")

    try:
        cattle_id = uuid.UUID(data["cattle_id"])
    except (ValueError, TypeError):
        raise HTTPException(status_code=422, detail="Invalid cattle_id format")

    try:
        record = await withdrawal_service.record_treatment(db, cattle_id, farmer_id, data)
        logger.info(f"Withdrawal record created | record_id={record.id}")
        return {
            "success": True,
            "data": {
                "id": str(record.id),
                "cattle_id": str(record.cattle_id),
                "medicine_name": record.medicine_name,
                "active_ingredient": record.active_ingredient,
                "route": record.route.value,
                "treatment_start_date": str(record.treatment_start_date),
                "treatment_end_date": str(record.treatment_end_date),
                "milk_withdrawal_days": record.milk_withdrawal_days,
                "meat_withdrawal_days": record.meat_withdrawal_days,
                "milk_safe_date": str(record.milk_safe_date),
                "meat_safe_date": str(record.meat_safe_date),
            },
            "message": (
                f"Treatment recorded. Milk safe after {record.milk_safe_date}. "
                f"Meat safe after {record.meat_safe_date}."
            ),
        }
    except Exception as e:
        logger.error(f"Failed to record treatment: {e}")
        raise HTTPException(status_code=500, detail="Failed to record treatment")


@router.get("/active")
async def get_active_withdrawals(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Get farmer's cattle with active withdrawal periods."""
    logger.info(f"GET /withdrawal/active called | user_id={current_user.id}")
    farmer_id = await _get_farmer_id(db, current_user)

    try:
        active = await withdrawal_service.get_active_withdrawals(db, farmer_id)
        logger.info(f"Active withdrawals retrieved | farmer_id={farmer_id} | count={len(active)}")
        return {
            "success": True,
            "data": active,
            "message": f"Found {len(active)} active withdrawal records",
        }
    except Exception as e:
        logger.error(f"Failed to get active withdrawals: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve active withdrawals")


@router.get("/cattle/{cattle_id}/status")
async def get_cattle_withdrawal_status(
    cattle_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Check if a specific cattle's milk and meat are safe."""
    logger.info(f"GET /withdrawal/cattle/{cattle_id}/status called | user_id={current_user.id}")

    try:
        cid = uuid.UUID(cattle_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=422, detail="Invalid cattle_id format")

    try:
        status = await withdrawal_service.get_cattle_withdrawal_status(db, cid)
        logger.info(f"Cattle withdrawal status retrieved | cattle_id={cattle_id} | milk_safe={status['is_milk_safe']}")
        return {
            "success": True,
            "data": status,
            "message": status["message"],
        }
    except Exception as e:
        logger.error(f"Failed to get cattle withdrawal status: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve cattle withdrawal status")


@router.post("/{record_id}/clear")
async def clear_withdrawal(
    record_id: str,
    data: dict | None = None,
    current_user: User = Depends(require_role(UserRole.vet, UserRole.admin)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Vet manually clears a withdrawal record (e.g., after lab confirmation)."""
    logger.info(f"POST /withdrawal/{record_id}/clear called | user_id={current_user.id}")

    try:
        rid = uuid.UUID(record_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=422, detail="Invalid record_id format")

    cleared_by = current_user.phone
    if data and "cleared_by" in data:
        cleared_by = data["cleared_by"]

    try:
        record = await withdrawal_service.clear_withdrawal(db, rid, cleared_by)
        logger.info(f"Withdrawal cleared | record_id={record.id}")
        return {
            "success": True,
            "data": {
                "id": str(record.id),
                "cattle_id": str(record.cattle_id),
                "medicine_name": record.medicine_name,
                "is_milk_cleared": record.is_milk_cleared,
                "is_meat_cleared": record.is_meat_cleared,
                "cleared_by": record.cleared_by,
                "cleared_at": str(record.cleared_at),
            },
            "message": "Withdrawal record cleared by veterinarian",
        }
    except ValueError as e:
        logger.warning(f"Withdrawal record not found: {e}")
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        logger.error(f"Failed to clear withdrawal: {e}")
        raise HTTPException(status_code=500, detail="Failed to clear withdrawal record")


@router.get("/database")
async def get_withdrawal_database(
    current_user: User = Depends(get_current_user),
) -> dict:
    """Get the built-in antibiotic withdrawal period database."""
    logger.info(f"GET /withdrawal/database called | user_id={current_user.id}")
    database = withdrawal_service.get_withdrawal_database()
    return {
        "success": True,
        "data": database,
        "message": f"Withdrawal database with {len(database)} entries",
    }


@router.get("/collection-check")
async def check_milk_collection_safety(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Check if farmer's milk is safe for collection today (any cattle with active withdrawal?)."""
    logger.info(f"GET /withdrawal/collection-check called | user_id={current_user.id}")
    farmer_id = await _get_farmer_id(db, current_user)

    try:
        safety = await withdrawal_service.check_milk_collection_safety(db, farmer_id)
        logger.info(
            f"Collection safety check | farmer_id={farmer_id} | safe={safety['is_collection_safe']}"
        )
        return {
            "success": True,
            "data": safety,
            "message": safety["message"],
        }
    except Exception as e:
        logger.error(f"Failed to check milk collection safety: {e}")
        raise HTTPException(status_code=500, detail="Failed to check milk collection safety")
