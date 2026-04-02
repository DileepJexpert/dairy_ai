"""Pashu Aadhaar service — cattle identification and government UID management."""
import logging
import uuid
from datetime import date, datetime, timezone
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.pashu_aadhaar import PashuAadhaar, IdentificationMethod, RegistrationStatus

logger = logging.getLogger("dairy_ai.services.pashu_aadhaar")


async def register_cattle(
    db: AsyncSession,
    cattle_id: uuid.UUID,
    farmer_id: uuid.UUID,
    data: dict,
) -> PashuAadhaar:
    """Register cattle for Pashu Aadhaar identification."""
    record = PashuAadhaar(
        cattle_id=cattle_id,
        farmer_id=farmer_id,
        pashu_aadhaar_number=data.get("pashu_aadhaar_number"),
        ear_tag_number=data.get("ear_tag_number"),
        identification_method=IdentificationMethod(data.get("identification_method", "ear_tag")),
        muzzle_print_hash=data.get("muzzle_print_hash"),
        photo_front_url=data.get("photo_front_url"),
        photo_side_url=data.get("photo_side_url"),
        ear_tag_photo_url=data.get("ear_tag_photo_url"),
        species=data.get("species", "cattle"),
        breed_govt=data.get("breed_govt"),
        color=data.get("color"),
        horn_type=data.get("horn_type"),
        special_marks=data.get("special_marks"),
        owner_name_govt=data.get("owner_name"),
        owner_aadhaar_last4=data.get("owner_aadhaar_last4"),
        village_code=data.get("village_code"),
        block_code=data.get("block_code"),
        district_code=data.get("district_code"),
        status=RegistrationStatus.pending,
        registered_at=date.today(),
    )
    db.add(record)
    await db.flush()
    logger.info("Registered Pashu Aadhaar for cattle=%s, farmer=%s", cattle_id, farmer_id)

    # Try to sync with government API
    try:
        from app.integrations.pashudhan import PashudhanClient
        if record.pashu_aadhaar_number:
            govt_data = await PashudhanClient.fetch_cattle_by_uid(record.pashu_aadhaar_number)
            if govt_data and not govt_data.get("error"):
                record.inaph_vaccinations = govt_data.get("vaccinations", [])
                record.inaph_ai_records = govt_data.get("ai_records", [])
                record.last_synced_at = datetime.now(timezone.utc)
                record.status = RegistrationStatus.registered
                logger.info("Synced with INAPH for Pashu Aadhaar %s", record.pashu_aadhaar_number)
    except Exception as e:
        logger.warning("Failed to sync with INAPH: %s", e)

    return record


async def get_by_cattle(db: AsyncSession, cattle_id: uuid.UUID) -> PashuAadhaar | None:
    result = await db.execute(
        select(PashuAadhaar).where(PashuAadhaar.cattle_id == cattle_id)
    )
    return result.scalar_one_or_none()


async def get_by_uid(db: AsyncSession, uid: str) -> PashuAadhaar | None:
    result = await db.execute(
        select(PashuAadhaar).where(PashuAadhaar.pashu_aadhaar_number == uid)
    )
    return result.scalar_one_or_none()


async def get_by_ear_tag(db: AsyncSession, ear_tag: str) -> PashuAadhaar | None:
    result = await db.execute(
        select(PashuAadhaar).where(PashuAadhaar.ear_tag_number == ear_tag)
    )
    return result.scalar_one_or_none()


async def get_farmer_cattle(db: AsyncSession, farmer_id: uuid.UUID) -> list[PashuAadhaar]:
    result = await db.execute(
        select(PashuAadhaar)
        .where(PashuAadhaar.farmer_id == farmer_id)
        .order_by(PashuAadhaar.created_at.desc())
    )
    return list(result.scalars().all())


async def verify_registration(
    db: AsyncSession, record_id: uuid.UUID, verified_by: str,
) -> PashuAadhaar | None:
    record = await db.get(PashuAadhaar, record_id)
    if not record:
        return None
    record.status = RegistrationStatus.verified
    record.verified_at = date.today()
    record.verified_by = verified_by
    await db.flush()
    logger.info("Verified Pashu Aadhaar id=%s by %s", record_id, verified_by)
    return record


async def sync_with_inaph(db: AsyncSession, record_id: uuid.UUID) -> dict:
    """Sync cattle data with government INAPH database."""
    record = await db.get(PashuAadhaar, record_id)
    if not record or not record.pashu_aadhaar_number:
        return {"error": "No Pashu Aadhaar number to sync"}

    try:
        from app.integrations.pashudhan import PashudhanClient
        govt_data = await PashudhanClient.fetch_cattle_by_uid(record.pashu_aadhaar_number)
        if govt_data and not govt_data.get("error"):
            record.inaph_vaccinations = govt_data.get("vaccinations", [])
            record.inaph_ai_records = govt_data.get("ai_records", [])
            record.breed_govt = govt_data.get("breed", record.breed_govt)
            record.owner_name_govt = govt_data.get("owner_name", record.owner_name_govt)
            record.last_synced_at = datetime.now(timezone.utc)
            await db.flush()
            return {"synced": True, "vaccinations": len(record.inaph_vaccinations or []), "ai_records": len(record.inaph_ai_records or [])}
        return {"synced": False, "error": govt_data.get("error", "No data")}
    except Exception as e:
        logger.error("INAPH sync failed for %s: %s", record.pashu_aadhaar_number, e)
        return {"synced": False, "error": str(e)}


async def get_registration_stats(db: AsyncSession, farmer_id: uuid.UUID | None = None) -> dict:
    """Get registration statistics."""
    from sqlalchemy import func

    query = select(
        PashuAadhaar.status,
        func.count().label("count"),
    )
    if farmer_id:
        query = query.where(PashuAadhaar.farmer_id == farmer_id)
    query = query.group_by(PashuAadhaar.status)

    result = await db.execute(query)
    stats = {row.status.value: row.count for row in result.all()}
    stats["total"] = sum(stats.values())
    return stats
