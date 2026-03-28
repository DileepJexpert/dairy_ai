"""Pashu Aadhaar API — cattle identification and government UID."""
import logging
import uuid
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.services import pashu_aadhaar_service

logger = logging.getLogger("dairy_ai.api.pashu_aadhaar")
router = APIRouter(prefix="/pashu-aadhaar", tags=["Pashu Aadhaar"])


@router.post("/register")
async def register_cattle(
    data: dict,
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    cattle_id = uuid.UUID(data.pop("cattle_id"))
    farmer_id = uuid.UUID(data.pop("farmer_id"))
    record = await pashu_aadhaar_service.register_cattle(db, cattle_id, farmer_id, data)
    await db.commit()
    return {
        "success": True,
        "data": {
            "id": str(record.id),
            "pashu_aadhaar_number": record.pashu_aadhaar_number,
            "ear_tag_number": record.ear_tag_number,
            "status": record.status.value,
        },
        "message": "Cattle registered for Pashu Aadhaar",
    }


@router.get("/cattle/{cattle_id}")
async def get_by_cattle(
    cattle_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    record = await pashu_aadhaar_service.get_by_cattle(db, cattle_id)
    if not record:
        return {"success": False, "data": None, "message": "No Pashu Aadhaar found for this cattle"}
    return {
        "success": True,
        "data": {
            "id": str(record.id),
            "cattle_id": str(record.cattle_id),
            "pashu_aadhaar_number": record.pashu_aadhaar_number,
            "ear_tag_number": record.ear_tag_number,
            "identification_method": record.identification_method.value,
            "species": record.species,
            "breed_govt": record.breed_govt,
            "color": record.color,
            "status": record.status.value,
            "inaph_vaccinations": record.inaph_vaccinations,
            "inaph_ai_records": record.inaph_ai_records,
            "last_synced_at": str(record.last_synced_at) if record.last_synced_at else None,
        },
        "message": "Pashu Aadhaar retrieved",
    }


@router.get("/lookup/{uid}")
async def lookup_by_uid(
    uid: str,
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    record = await pashu_aadhaar_service.get_by_uid(db, uid)
    if not record:
        record = await pashu_aadhaar_service.get_by_ear_tag(db, uid)
    if not record:
        return {"success": False, "data": None, "message": "No cattle found with this ID"}
    return {
        "success": True,
        "data": {
            "id": str(record.id),
            "cattle_id": str(record.cattle_id),
            "farmer_id": str(record.farmer_id),
            "pashu_aadhaar_number": record.pashu_aadhaar_number,
            "ear_tag_number": record.ear_tag_number,
            "status": record.status.value,
            "species": record.species,
            "breed_govt": record.breed_govt,
        },
        "message": "Cattle found",
    }


@router.get("/my-cattle")
async def get_my_cattle(
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    from app.models.farmer import Farmer
    from sqlalchemy import select
    result = await db.execute(select(Farmer).where(Farmer.user_id == user.id))
    farmer = result.scalar_one_or_none()
    if not farmer:
        return {"success": False, "data": None, "message": "Farmer profile not found"}

    records = await pashu_aadhaar_service.get_farmer_cattle(db, farmer.id)
    return {
        "success": True,
        "data": {
            "cattle": [
                {
                    "id": str(r.id),
                    "cattle_id": str(r.cattle_id),
                    "pashu_aadhaar_number": r.pashu_aadhaar_number,
                    "ear_tag_number": r.ear_tag_number,
                    "status": r.status.value,
                    "species": r.species,
                    "breed_govt": r.breed_govt,
                }
                for r in records
            ],
            "count": len(records),
        },
        "message": "Cattle list retrieved",
    }


@router.post("/{record_id}/verify")
async def verify_registration(
    record_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    if user.role.value not in ("admin", "super_admin", "vet"):
        raise HTTPException(403, "Only admin or vet can verify")
    record = await pashu_aadhaar_service.verify_registration(db, record_id, f"user:{user.id}")
    if not record:
        return {"success": False, "data": None, "message": "Record not found"}
    await db.commit()
    return {"success": True, "data": {"status": record.status.value}, "message": "Registration verified"}


@router.post("/{record_id}/sync")
async def sync_with_inaph(
    record_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    result = await pashu_aadhaar_service.sync_with_inaph(db, record_id)
    if result.get("synced"):
        await db.commit()
    return {"success": result.get("synced", False), "data": result, "message": "Sync complete" if result.get("synced") else result.get("error", "Sync failed")}


@router.get("/stats")
async def get_stats(
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    farmer_id = None
    if user.role.value == "farmer":
        from app.models.farmer import Farmer
        from sqlalchemy import select
        result = await db.execute(select(Farmer).where(Farmer.user_id == user.id))
        farmer = result.scalar_one_or_none()
        if farmer:
            farmer_id = farmer.id
    stats = await pashu_aadhaar_service.get_registration_stats(db, farmer_id)
    return {"success": True, "data": stats, "message": "Registration stats"}
