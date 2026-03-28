import logging
import uuid
from typing import Optional

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.vet import VetProfile
from app.repositories import vet_repo
from app.schemas.vet import VetRegister, VetUpdate, VetSearchFilters

logger = logging.getLogger("dairy_ai.services.vet")


async def register_vet(
    db: AsyncSession, user_id: uuid.UUID, data: VetRegister
) -> VetProfile:
    """Create a new vet profile (unverified by default)."""
    logger.info(f"register_vet called | user_id={user_id}, license={data.license_number}, qualification={data.qualification}")
    logger.debug(f"Vet registration details | specializations={data.specializations}, experience={data.experience_years}yrs, languages={data.languages}, fee=₹{data.consultation_fee}")

    logger.debug(f"Creating vet profile in database | user_id={user_id}")
    vet = await vet_repo.create_vet_profile(
        db,
        user_id=user_id,
        license_number=data.license_number,
        qualification=data.qualification,
        specializations=data.specializations,
        experience_years=data.experience_years,
        languages=data.languages,
        consultation_fee=data.consultation_fee,
        bio=data.bio,
    )
    logger.info(f"Vet profile created (unverified) | vet_id={vet.id}, user_id={user_id}, license={data.license_number}")
    return vet


async def verify_vet(db: AsyncSession, vet_id: uuid.UUID) -> VetProfile | None:
    """Admin action: mark vet as verified."""
    logger.info(f"verify_vet called | vet_id={vet_id}")

    logger.debug(f"Fetching vet profile from database | vet_id={vet_id}")
    vet = await vet_repo.get_vet_by_id(db, vet_id)
    if not vet:
        logger.warning(f"Vet not found for verification | vet_id={vet_id}")
        return None

    logger.debug(f"Marking vet as verified | vet_id={vet_id}, user_id={vet.user_id}")
    updated = await vet_repo.update_vet_profile(db, vet, is_verified=True)
    logger.info(f"Vet verified successfully | vet_id={vet_id}")
    return updated


async def search_vets(db: AsyncSession, filters: VetSearchFilters) -> list[VetProfile]:
    """Search for available verified vets with optional filters."""
    logger.info(f"search_vets called | specialization={filters.specialization}, language={filters.language}, available_only={filters.available}")

    results = await vet_repo.search_vets(
        db,
        specialization=filters.specialization,
        language=filters.language,
        available_only=filters.available if filters.available is not None else False,
    )
    logger.info(f"Vet search completed | results_count={len(results)}, filters={{specialization={filters.specialization}, language={filters.language}}}")
    return results


async def toggle_availability(
    db: AsyncSession, vet_id: uuid.UUID, is_available: bool
) -> VetProfile | None:
    """Toggle vet online/offline availability."""
    logger.info(f"toggle_availability called | vet_id={vet_id}, is_available={is_available}")

    vet = await vet_repo.get_vet_by_id(db, vet_id)
    if not vet:
        logger.warning(f"Vet not found for availability toggle | vet_id={vet_id}")
        return None

    logger.debug(f"Updating vet availability | vet_id={vet_id}, old={vet.is_available}, new={is_available}")
    updated = await vet_repo.update_vet_profile(db, vet, is_available=is_available)
    logger.info(f"Vet availability updated | vet_id={vet_id}, is_available={is_available}")
    return updated


async def update_profile(
    db: AsyncSession, vet: VetProfile, data: VetUpdate
) -> VetProfile:
    """Update editable vet profile fields."""
    update_data = data.model_dump(exclude_unset=True)
    logger.info(f"update_profile called | vet_id={vet.id}, fields_to_update={list(update_data.keys())}")
    logger.debug(f"Update values: {update_data}")

    updated = await vet_repo.update_vet_profile(db, vet, **update_data)
    logger.info(f"Vet profile updated successfully | vet_id={vet.id}")
    return updated


async def get_vet_dashboard(db: AsyncSession, vet_id: uuid.UUID) -> dict:
    """Return vet dashboard stats."""
    logger.info(f"get_vet_dashboard called | vet_id={vet_id}")

    logger.debug(f"Fetching vet profile | vet_id={vet_id}")
    vet = await vet_repo.get_vet_by_id(db, vet_id)
    if not vet:
        logger.warning(f"Vet not found for dashboard | vet_id={vet_id}")
        return {}

    logger.debug(f"Fetching vet consultation queue | vet_id={vet_id}")
    queue = await vet_repo.get_vet_queue(db, vet_id)

    dashboard = {
        "total_consultations": vet.total_consultations,
        "total_earnings": vet.total_earnings,
        "rating_avg": vet.rating_avg,
        "is_available": vet.is_available,
        "is_verified": vet.is_verified,
        "pending_queue": len(queue),
    }
    logger.info(f"Vet dashboard loaded | vet_id={vet_id}, total_consultations={vet.total_consultations}, earnings=₹{vet.total_earnings}, rating={vet.rating_avg}, pending={len(queue)}")
    return dashboard
