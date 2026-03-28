import logging
import uuid
from datetime import date

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.vendor import Vendor
from app.models.milk import MilkRecord
from app.repositories import vendor_repo
from app.schemas.vendor import VendorCreate, VendorUpdate

logger = logging.getLogger("dairy_ai.services.vendor")


async def register_vendor(db: AsyncSession, user_id: uuid.UUID, data: VendorCreate) -> Vendor:
    logger.info(f"register_vendor called | user_id={user_id} | business_name={data.business_name} | type={data.vendor_type}")

    logger.debug(f"Checking if vendor profile already exists for user_id={user_id}")
    existing = await vendor_repo.get_by_user_id(db, user_id)
    if existing:
        logger.warning(f"Vendor profile already exists | user_id={user_id} | vendor_id={existing.id}")
        raise ValueError("Vendor profile already exists")

    logger.debug(f"Creating vendor profile | user_id={user_id}")
    vendor = await vendor_repo.create(db, user_id, **data.model_dump(exclude_none=True))
    logger.info(f"Vendor registered | vendor_id={vendor.id} | business_name={vendor.business_name}")
    return vendor


async def update_vendor(db: AsyncSession, vendor: Vendor, data: VendorUpdate) -> Vendor:
    logger.info(f"update_vendor called | vendor_id={vendor.id}")
    fields = data.model_dump(exclude_unset=True)
    logger.debug(f"Update fields: {list(fields.keys())}")
    updated = await vendor_repo.update(db, vendor, **fields)
    logger.info(f"Vendor updated | vendor_id={updated.id}")
    return updated


async def get_vendor_dashboard(db: AsyncSession, vendor_id: uuid.UUID, user_id: uuid.UUID) -> dict:
    logger.info(f"get_vendor_dashboard called | vendor_id={vendor_id} | user_id={user_id}")

    logger.debug(f"Fetching vendor profile | vendor_id={vendor_id}")
    vendor = await vendor_repo.get_by_id(db, vendor_id)
    if not vendor:
        logger.warning(f"Vendor not found | vendor_id={vendor_id}")
        return {}

    today = date.today()

    logger.debug(f"Building vendor dashboard | vendor_id={vendor_id}")
    dashboard = {
        "profile": {
            "id": str(vendor.id),
            "business_name": vendor.business_name,
            "vendor_type": vendor.vendor_type.value if hasattr(vendor.vendor_type, "value") else vendor.vendor_type,
            "is_verified": vendor.is_verified,
            "is_active": vendor.is_active,
            "district": vendor.district,
            "state": vendor.state,
        },
        "stats": {
            "total_orders": vendor.total_orders,
            "total_revenue": round(float(vendor.total_revenue), 2),
            "rating_avg": round(float(vendor.rating_avg), 2),
        },
        "products_services": vendor.products_services or [],
        "service_areas": vendor.service_areas or [],
    }

    logger.info(f"Vendor dashboard built | vendor_id={vendor_id} | orders={vendor.total_orders} | revenue={vendor.total_revenue}")
    return dashboard
