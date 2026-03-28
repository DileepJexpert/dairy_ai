import logging

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user, require_role
from app.models.user import User, UserRole
from app.repositories import vendor_repo
from app.services import vendor_service
from app.schemas.vendor import VendorCreate, VendorUpdate

logger = logging.getLogger("dairy_ai.api.vendor")

router = APIRouter(prefix="/vendor", tags=["vendor"])


def _vendor_to_dict(vendor) -> dict:
    logger.debug(f"Serializing vendor | vendor_id={vendor.id}")
    return {
        "id": str(vendor.id),
        "user_id": str(vendor.user_id),
        "business_name": vendor.business_name,
        "vendor_type": vendor.vendor_type.value if hasattr(vendor.vendor_type, "value") else vendor.vendor_type,
        "contact_person": vendor.contact_person,
        "address": vendor.address,
        "district": vendor.district,
        "state": vendor.state,
        "gst_number": vendor.gst_number,
        "license_number": vendor.license_number,
        "description": vendor.description,
        "products_services": vendor.products_services or [],
        "service_areas": vendor.service_areas or [],
        "rating_avg": vendor.rating_avg,
        "total_orders": vendor.total_orders,
        "total_revenue": round(float(vendor.total_revenue), 2),
        "is_verified": vendor.is_verified,
        "is_active": vendor.is_active,
    }


@router.post("/register", status_code=201)
async def register_vendor(
    data: VendorCreate,
    current_user: User = Depends(require_role(UserRole.vendor)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"POST /vendor/register called | user_id={current_user.id} | business_name={data.business_name}")
    logger.debug(f"Vendor registration data: {data.model_dump()}")
    try:
        vendor = await vendor_service.register_vendor(db, current_user.id, data)
        logger.info(f"Vendor registered | vendor_id={vendor.id} | user_id={current_user.id}")
        return {
            "success": True,
            "data": _vendor_to_dict(vendor),
            "message": "Vendor profile registered successfully",
        }
    except ValueError as e:
        logger.warning(f"Vendor registration failed | user_id={current_user.id} | error={e}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Unexpected error during vendor registration | user_id={current_user.id} | error={e}")
        raise


@router.get("/me")
async def get_my_profile(
    current_user: User = Depends(require_role(UserRole.vendor)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /vendor/me called | user_id={current_user.id}")
    logger.debug(f"Looking up vendor profile for user_id={current_user.id}")
    vendor = await vendor_repo.get_by_user_id(db, current_user.id)
    if not vendor:
        logger.warning(f"Vendor profile not found | user_id={current_user.id}")
        raise HTTPException(status_code=404, detail="Vendor profile not found")
    logger.info(f"Vendor profile found | vendor_id={vendor.id} | business_name={vendor.business_name}")
    return {
        "success": True,
        "data": _vendor_to_dict(vendor),
        "message": "Vendor profile",
    }


@router.put("/me")
async def update_my_profile(
    data: VendorUpdate,
    current_user: User = Depends(require_role(UserRole.vendor)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"PUT /vendor/me called | user_id={current_user.id}")
    logger.debug(f"Update fields: {data.model_dump(exclude_unset=True)}")
    vendor = await vendor_repo.get_by_user_id(db, current_user.id)
    if not vendor:
        logger.warning(f"Vendor profile not found for update | user_id={current_user.id}")
        raise HTTPException(status_code=404, detail="Vendor profile not found")
    try:
        updated = await vendor_service.update_vendor(db, vendor, data)
        logger.info(f"Vendor profile updated | vendor_id={updated.id}")
        return {
            "success": True,
            "data": _vendor_to_dict(updated),
            "message": "Vendor profile updated",
        }
    except Exception as e:
        logger.error(f"Failed to update vendor profile | user_id={current_user.id} | error={e}")
        raise


@router.get("/dashboard")
async def vendor_dashboard(
    current_user: User = Depends(require_role(UserRole.vendor)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /vendor/dashboard called | user_id={current_user.id}")
    logger.debug(f"Looking up vendor profile for dashboard | user_id={current_user.id}")
    vendor = await vendor_repo.get_by_user_id(db, current_user.id)
    if not vendor:
        logger.warning(f"Vendor profile not found for dashboard | user_id={current_user.id}")
        raise HTTPException(status_code=404, detail="Vendor profile not found. Please register first.")
    logger.debug(f"Calling vendor_service.get_vendor_dashboard | vendor_id={vendor.id}")
    dashboard = await vendor_service.get_vendor_dashboard(db, vendor.id, current_user.id)
    logger.info(f"Vendor dashboard retrieved | vendor_id={vendor.id} | user_id={current_user.id}")
    return {
        "success": True,
        "data": dashboard,
        "message": "Vendor dashboard",
    }
