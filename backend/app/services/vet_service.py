import uuid
from typing import Optional

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.vet import VetProfile
from app.repositories import vet_repo
from app.schemas.vet import VetRegister, VetUpdate, VetSearchFilters


async def register_vet(
    db: AsyncSession, user_id: uuid.UUID, data: VetRegister
) -> VetProfile:
    """Create a new vet profile (unverified by default)."""
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
    return vet


async def verify_vet(db: AsyncSession, vet_id: uuid.UUID) -> VetProfile | None:
    """Admin action: mark vet as verified."""
    vet = await vet_repo.get_vet_by_id(db, vet_id)
    if not vet:
        return None
    return await vet_repo.update_vet_profile(db, vet, is_verified=True)


async def search_vets(db: AsyncSession, filters: VetSearchFilters) -> list[VetProfile]:
    """Search for available verified vets with optional filters."""
    return await vet_repo.search_vets(
        db,
        specialization=filters.specialization,
        language=filters.language,
        available_only=filters.available if filters.available is not None else False,
    )


async def toggle_availability(
    db: AsyncSession, vet_id: uuid.UUID, is_available: bool
) -> VetProfile | None:
    """Toggle vet online/offline availability."""
    vet = await vet_repo.get_vet_by_id(db, vet_id)
    if not vet:
        return None
    return await vet_repo.update_vet_profile(db, vet, is_available=is_available)


async def update_profile(
    db: AsyncSession, vet: VetProfile, data: VetUpdate
) -> VetProfile:
    """Update editable vet profile fields."""
    update_data = data.model_dump(exclude_unset=True)
    return await vet_repo.update_vet_profile(db, vet, **update_data)


async def get_vet_dashboard(db: AsyncSession, vet_id: uuid.UUID) -> dict:
    """Return vet dashboard stats."""
    vet = await vet_repo.get_vet_by_id(db, vet_id)
    if not vet:
        return {}

    queue = await vet_repo.get_vet_queue(db, vet_id)

    return {
        "total_consultations": vet.total_consultations,
        "total_earnings": vet.total_earnings,
        "rating_avg": vet.rating_avg,
        "is_available": vet.is_available,
        "is_verified": vet.is_verified,
        "pending_queue": len(queue),
    }
