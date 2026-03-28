import logging

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user, require_role
from app.models.user import User, UserRole
from app.repositories import cooperative_repo
from app.services import cooperative_service
from app.schemas.cooperative import CooperativeCreate, CooperativeUpdate

logger = logging.getLogger("dairy_ai.api.cooperative")

router = APIRouter(prefix="/cooperative", tags=["cooperative"])


def _coop_to_dict(coop) -> dict:
    logger.debug(f"Serializing cooperative | cooperative_id={coop.id}")
    return {
        "id": str(coop.id),
        "user_id": str(coop.user_id),
        "name": coop.name,
        "registration_number": coop.registration_number,
        "cooperative_type": coop.cooperative_type.value if hasattr(coop.cooperative_type, "value") else coop.cooperative_type,
        "chairman_name": coop.chairman_name,
        "secretary_name": coop.secretary_name,
        "address": coop.address,
        "village": coop.village,
        "district": coop.district,
        "state": coop.state,
        "total_members": coop.total_members,
        "total_milk_collected_litres": round(float(coop.total_milk_collected_litres), 2),
        "total_revenue": round(float(coop.total_revenue), 2),
        "total_payouts": round(float(coop.total_payouts), 2),
        "milk_price_per_litre": round(float(coop.milk_price_per_litre), 2),
        "collection_centers": coop.collection_centers or [],
        "services_offered": coop.services_offered or [],
        "is_verified": coop.is_verified,
        "is_active": coop.is_active,
    }


@router.post("/register", status_code=201)
async def register_cooperative(
    data: CooperativeCreate,
    current_user: User = Depends(require_role(UserRole.cooperative)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"POST /cooperative/register called | user_id={current_user.id} | name={data.name}")
    logger.debug(f"Cooperative registration data: {data.model_dump()}")
    try:
        coop = await cooperative_service.register_cooperative(db, current_user.id, data)
        logger.info(f"Cooperative registered | cooperative_id={coop.id} | user_id={current_user.id}")
        return {
            "success": True,
            "data": _coop_to_dict(coop),
            "message": "Cooperative profile registered successfully",
        }
    except ValueError as e:
        logger.warning(f"Cooperative registration failed | user_id={current_user.id} | error={e}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Unexpected error during cooperative registration | user_id={current_user.id} | error={e}")
        raise


@router.get("/me")
async def get_my_profile(
    current_user: User = Depends(require_role(UserRole.cooperative)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /cooperative/me called | user_id={current_user.id}")
    logger.debug(f"Looking up cooperative profile for user_id={current_user.id}")
    coop = await cooperative_repo.get_by_user_id(db, current_user.id)
    if not coop:
        logger.warning(f"Cooperative profile not found | user_id={current_user.id}")
        raise HTTPException(status_code=404, detail="Cooperative profile not found")
    logger.info(f"Cooperative profile found | cooperative_id={coop.id} | name={coop.name}")
    return {
        "success": True,
        "data": _coop_to_dict(coop),
        "message": "Cooperative profile",
    }


@router.put("/me")
async def update_my_profile(
    data: CooperativeUpdate,
    current_user: User = Depends(require_role(UserRole.cooperative)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"PUT /cooperative/me called | user_id={current_user.id}")
    logger.debug(f"Update fields: {data.model_dump(exclude_unset=True)}")
    coop = await cooperative_repo.get_by_user_id(db, current_user.id)
    if not coop:
        logger.warning(f"Cooperative profile not found for update | user_id={current_user.id}")
        raise HTTPException(status_code=404, detail="Cooperative profile not found")
    try:
        updated = await cooperative_service.update_cooperative(db, coop, data)
        logger.info(f"Cooperative profile updated | cooperative_id={updated.id}")
        return {
            "success": True,
            "data": _coop_to_dict(updated),
            "message": "Cooperative profile updated",
        }
    except Exception as e:
        logger.error(f"Failed to update cooperative profile | user_id={current_user.id} | error={e}")
        raise


@router.get("/dashboard")
async def cooperative_dashboard(
    current_user: User = Depends(require_role(UserRole.cooperative)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /cooperative/dashboard called | user_id={current_user.id}")
    logger.debug(f"Looking up cooperative profile for dashboard | user_id={current_user.id}")
    coop = await cooperative_repo.get_by_user_id(db, current_user.id)
    if not coop:
        logger.warning(f"Cooperative profile not found for dashboard | user_id={current_user.id}")
        raise HTTPException(status_code=404, detail="Cooperative profile not found. Please register first.")
    logger.debug(f"Calling cooperative_service.get_cooperative_dashboard | cooperative_id={coop.id}")
    dashboard = await cooperative_service.get_cooperative_dashboard(db, coop.id, current_user.id)
    logger.info(f"Cooperative dashboard retrieved | cooperative_id={coop.id} | user_id={current_user.id}")
    return {
        "success": True,
        "data": dashboard,
        "message": "Cooperative dashboard",
    }
