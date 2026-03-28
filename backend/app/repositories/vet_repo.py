import logging
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

logger = logging.getLogger("dairy_ai.repos.vet")


# ---------------------------------------------------------------------------
# Vet Profile
# ---------------------------------------------------------------------------

async def create_vet_profile(db: AsyncSession, **kwargs) -> VetProfile:
    logger.info("Creating vet profile: user_id=%s, license=%s", kwargs.get("user_id"), kwargs.get("license_no"))
    vet = VetProfile(**kwargs)
    db.add(vet)
    await db.flush()
    logger.info("Created vet profile id=%s for user_id=%s", vet.id, vet.user_id)
    return vet


async def get_vet_by_user_id(db: AsyncSession, user_id: uuid.UUID) -> VetProfile | None:
    logger.debug("Querying vet profile by user_id=%s", user_id)
    result = await db.execute(
        select(VetProfile).where(VetProfile.user_id == user_id)
    )
    vet = result.scalar_one_or_none()
    if vet:
        logger.info("Found vet profile id=%s for user_id=%s, verified=%s", vet.id, user_id, vet.is_verified)
    else:
        logger.info("No vet profile found for user_id=%s", user_id)
    return vet


async def get_vet_by_id(db: AsyncSession, vet_id: uuid.UUID) -> VetProfile | None:
    logger.debug("Querying vet profile by id=%s", vet_id)
    result = await db.execute(
        select(VetProfile).where(VetProfile.id == vet_id)
    )
    vet = result.scalar_one_or_none()
    if vet:
        logger.info("Found vet id=%s, verified=%s, available=%s", vet.id, vet.is_verified, vet.is_available)
    else:
        logger.info("No vet profile found for id=%s", vet_id)
    return vet


async def update_vet_profile(db: AsyncSession, vet: VetProfile, **kwargs) -> VetProfile:
    logger.info("Updating vet profile id=%s with fields=%s", vet.id, {k: v for k, v in kwargs.items() if v is not None})
    for key, value in kwargs.items():
        if value is not None:
            setattr(vet, key, value)
    await db.flush()
    logger.info("Updated vet profile id=%s successfully", vet.id)
    return vet


async def search_vets(
    db: AsyncSession,
    specialization: Optional[str] = None,
    language: Optional[str] = None,
    available_only: bool = False,
) -> list[VetProfile]:
    logger.debug("Searching vets: specialization=%s, language=%s, available_only=%s",
                 specialization, language, available_only)
    query = select(VetProfile).where(VetProfile.is_verified == True)  # noqa: E712

    if available_only:
        query = query.where(VetProfile.is_available == True)  # noqa: E712

    result = await db.execute(query)
    vets = list(result.scalars().all())
    logger.debug("Found %d verified vets from DB before in-memory filtering", len(vets))

    # Filter by JSON contains in Python (SQLite compatible)
    if specialization:
        before_count = len(vets)
        vets = [v for v in vets if v.specializations and specialization in v.specializations]
        logger.debug("Specialization filter '%s': %d -> %d vets", specialization, before_count, len(vets))
    if language:
        before_count = len(vets)
        vets = [v for v in vets if v.languages and language in v.languages]
        logger.debug("Language filter '%s': %d -> %d vets", language, before_count, len(vets))

    logger.info("Search returned %d vets (specialization=%s, language=%s, available_only=%s)",
                len(vets), specialization, language, available_only)
    return vets


# ---------------------------------------------------------------------------
# Consultation
# ---------------------------------------------------------------------------

async def create_consultation(db: AsyncSession, **kwargs) -> Consultation:
    logger.info("Creating consultation: farmer_id=%s, cattle_id=%s, vet_id=%s, type=%s",
                kwargs.get("farmer_id"), kwargs.get("cattle_id"), kwargs.get("vet_id"), kwargs.get("type"))
    consultation = Consultation(**kwargs)
    db.add(consultation)
    await db.flush()
    logger.info("Created consultation id=%s, status=%s", consultation.id, consultation.status)
    return consultation


async def get_consultation_by_id(db: AsyncSession, consultation_id: uuid.UUID) -> Consultation | None:
    logger.debug("Querying consultation by id=%s", consultation_id)
    result = await db.execute(
        select(Consultation).where(Consultation.id == consultation_id)
    )
    consultation = result.scalar_one_or_none()
    if consultation:
        logger.info("Found consultation id=%s, status=%s, vet_id=%s", consultation.id, consultation.status, consultation.vet_id)
    else:
        logger.info("No consultation found for id=%s", consultation_id)
    return consultation


async def update_consultation(db: AsyncSession, consultation: Consultation, **kwargs) -> Consultation:
    logger.info("Updating consultation id=%s with fields=%s", consultation.id, {k: v for k, v in kwargs.items() if v is not None})
    for key, value in kwargs.items():
        if value is not None:
            setattr(consultation, key, value)
    await db.flush()
    logger.info("Updated consultation id=%s, new status=%s", consultation.id, consultation.status)
    return consultation


async def get_farmer_consultations(db: AsyncSession, farmer_id: uuid.UUID) -> list[Consultation]:
    logger.debug("Querying consultations for farmer_id=%s", farmer_id)
    result = await db.execute(
        select(Consultation)
        .where(Consultation.farmer_id == farmer_id)
        .order_by(Consultation.created_at.desc())
    )
    consultations = list(result.scalars().all())
    logger.info("Found %d consultations for farmer %s", len(consultations), farmer_id)
    return consultations


async def get_vet_queue(db: AsyncSession, vet_id: uuid.UUID) -> list[Consultation]:
    """Return pending consultations for a vet (requested/assigned/in_progress)."""
    logger.debug("Querying vet queue for vet_id=%s (requested/assigned/in_progress)", vet_id)
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
    consultations = list(result.scalars().all())
    logger.info("Vet %s queue: %d pending consultations", vet_id, len(consultations))
    return consultations


# ---------------------------------------------------------------------------
# Prescription
# ---------------------------------------------------------------------------

async def create_prescription(db: AsyncSession, **kwargs) -> Prescription:
    logger.info("Creating prescription for consultation_id=%s", kwargs.get("consultation_id"))
    prescription = Prescription(**kwargs)
    db.add(prescription)
    await db.flush()
    logger.info("Created prescription id=%s for consultation %s", prescription.id, prescription.consultation_id)
    return prescription


async def get_prescriptions_by_consultation(
    db: AsyncSession, consultation_id: uuid.UUID
) -> list[Prescription]:
    logger.debug("Querying prescriptions for consultation_id=%s", consultation_id)
    result = await db.execute(
        select(Prescription).where(Prescription.consultation_id == consultation_id)
    )
    prescriptions = list(result.scalars().all())
    logger.info("Found %d prescriptions for consultation %s", len(prescriptions), consultation_id)
    return prescriptions
