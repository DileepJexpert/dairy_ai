import uuid
from typing import Optional

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.vet import (
    VetProfile,
    Consultation,
    ConsultationStatus,
    Prescription,
)


# ---------------------------------------------------------------------------
# Vet Profile
# ---------------------------------------------------------------------------

async def create_vet_profile(db: AsyncSession, **kwargs) -> VetProfile:
    vet = VetProfile(**kwargs)
    db.add(vet)
    await db.flush()
    return vet


async def get_vet_by_user_id(db: AsyncSession, user_id: uuid.UUID) -> VetProfile | None:
    result = await db.execute(
        select(VetProfile).where(VetProfile.user_id == user_id)
    )
    return result.scalar_one_or_none()


async def get_vet_by_id(db: AsyncSession, vet_id: uuid.UUID) -> VetProfile | None:
    result = await db.execute(
        select(VetProfile).where(VetProfile.id == vet_id)
    )
    return result.scalar_one_or_none()


async def update_vet_profile(db: AsyncSession, vet: VetProfile, **kwargs) -> VetProfile:
    for key, value in kwargs.items():
        if value is not None:
            setattr(vet, key, value)
    await db.flush()
    return vet


async def search_vets(
    db: AsyncSession,
    specialization: Optional[str] = None,
    language: Optional[str] = None,
    available_only: bool = False,
) -> list[VetProfile]:
    query = select(VetProfile).where(VetProfile.is_verified == True)  # noqa: E712

    if available_only:
        query = query.where(VetProfile.is_available == True)  # noqa: E712

    result = await db.execute(query)
    vets = list(result.scalars().all())

    # Filter by JSON contains in Python (SQLite compatible)
    if specialization:
        vets = [v for v in vets if v.specializations and specialization in v.specializations]
    if language:
        vets = [v for v in vets if v.languages and language in v.languages]

    return vets


# ---------------------------------------------------------------------------
# Consultation
# ---------------------------------------------------------------------------

async def create_consultation(db: AsyncSession, **kwargs) -> Consultation:
    consultation = Consultation(**kwargs)
    db.add(consultation)
    await db.flush()
    return consultation


async def get_consultation_by_id(db: AsyncSession, consultation_id: uuid.UUID) -> Consultation | None:
    result = await db.execute(
        select(Consultation).where(Consultation.id == consultation_id)
    )
    return result.scalar_one_or_none()


async def update_consultation(db: AsyncSession, consultation: Consultation, **kwargs) -> Consultation:
    for key, value in kwargs.items():
        if value is not None:
            setattr(consultation, key, value)
    await db.flush()
    return consultation


async def get_farmer_consultations(db: AsyncSession, farmer_id: uuid.UUID) -> list[Consultation]:
    result = await db.execute(
        select(Consultation)
        .where(Consultation.farmer_id == farmer_id)
        .order_by(Consultation.created_at.desc())
    )
    return list(result.scalars().all())


async def get_vet_queue(db: AsyncSession, vet_id: uuid.UUID) -> list[Consultation]:
    """Return pending consultations for a vet (requested/assigned/in_progress)."""
    result = await db.execute(
        select(Consultation)
        .where(
            Consultation.vet_id == vet_id,
            Consultation.status.in_([
                ConsultationStatus.requested,
                ConsultationStatus.assigned,
                ConsultationStatus.in_progress,
            ]),
        )
        .order_by(Consultation.created_at.asc())
    )
    return list(result.scalars().all())


# ---------------------------------------------------------------------------
# Prescription
# ---------------------------------------------------------------------------

async def create_prescription(db: AsyncSession, **kwargs) -> Prescription:
    prescription = Prescription(**kwargs)
    db.add(prescription)
    await db.flush()
    return prescription


async def get_prescriptions_by_consultation(
    db: AsyncSession, consultation_id: uuid.UUID
) -> list[Prescription]:
    result = await db.execute(
        select(Prescription).where(Prescription.consultation_id == consultation_id)
    )
    return list(result.scalars().all())
