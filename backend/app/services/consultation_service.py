import uuid
from datetime import datetime, timezone

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.vet import (
    Consultation,
    ConsultationStatus,
    Prescription,
    VetProfile,
)
from app.repositories import vet_repo
from app.integrations.agora import generate_rtc_token
from app.schemas.vet import ConsultationCreate, PrescriptionCreate, RatingCreate


async def request_consultation(
    db: AsyncSession,
    farmer_id: uuid.UUID,
    data: ConsultationCreate,
) -> Consultation:
    """Create a new consultation request with status=requested."""
    channel_name = f"consult_{uuid.uuid4().hex[:12]}"
    agora_token = generate_rtc_token(channel_name, uid=0, role="publisher")

    consultation = await vet_repo.create_consultation(
        db,
        farmer_id=farmer_id,
        cattle_id=uuid.UUID(data.cattle_id),
        consultation_type=data.consultation_type,
        symptoms=data.symptoms,
        status=ConsultationStatus.requested,
        agora_channel_name=channel_name,
        agora_token=agora_token,
    )
    return consultation


async def accept_consultation(
    db: AsyncSession,
    vet_id: uuid.UUID,
    consultation_id: uuid.UUID,
) -> Consultation | None:
    """Vet accepts a consultation request — status → assigned."""
    consultation = await vet_repo.get_consultation_by_id(db, consultation_id)
    if not consultation:
        return None
    return await vet_repo.update_consultation(
        db,
        consultation,
        vet_id=vet_id,
        status=ConsultationStatus.assigned,
    )


async def start_consultation(
    db: AsyncSession,
    consultation_id: uuid.UUID,
) -> Consultation | None:
    """Start an assigned consultation — status → in_progress."""
    consultation = await vet_repo.get_consultation_by_id(db, consultation_id)
    if not consultation:
        return None
    return await vet_repo.update_consultation(
        db,
        consultation,
        status=ConsultationStatus.in_progress,
        started_at=datetime.now(timezone.utc),
    )


async def end_consultation(
    db: AsyncSession,
    consultation_id: uuid.UUID,
    diagnosis: str | None = None,
    notes: str | None = None,
) -> Consultation | None:
    """End an in-progress consultation — calculate fee, platform cut, payout."""
    consultation = await vet_repo.get_consultation_by_id(db, consultation_id)
    if not consultation:
        return None

    now = datetime.now(timezone.utc)
    duration = 0
    if consultation.started_at:
        started = consultation.started_at
        if started.tzinfo is None:
            started = started.replace(tzinfo=timezone.utc)
        duration = int((now - started).total_seconds())

    # Fee calculation
    fee_amount = 0.0
    if consultation.vet_id:
        vet = await vet_repo.get_vet_by_id(db, consultation.vet_id)
        if vet:
            fee_amount = vet.consultation_fee
            # Update vet stats
            await vet_repo.update_vet_profile(
                db,
                vet,
                total_consultations=vet.total_consultations + 1,
                total_earnings=vet.total_earnings + (fee_amount * 0.8),
            )

    platform_fee = round(fee_amount * 0.2, 2)
    vet_payout = round(fee_amount * 0.8, 2)

    return await vet_repo.update_consultation(
        db,
        consultation,
        status=ConsultationStatus.completed,
        ended_at=now,
        duration_seconds=duration,
        vet_diagnosis=diagnosis,
        vet_notes=notes,
        fee_amount=fee_amount,
        platform_fee=platform_fee,
        vet_payout=vet_payout,
    )


async def create_prescription(
    db: AsyncSession,
    consultation_id: uuid.UUID,
    data: PrescriptionCreate,
) -> Prescription | None:
    """Create a prescription linked to a consultation."""
    consultation = await vet_repo.get_consultation_by_id(db, consultation_id)
    if not consultation or not consultation.vet_id:
        return None

    medicines_list = [m.model_dump() for m in data.medicines]

    prescription = await vet_repo.create_prescription(
        db,
        consultation_id=consultation_id,
        cattle_id=consultation.cattle_id,
        vet_id=consultation.vet_id,
        medicines=medicines_list,
        instructions=data.instructions,
        follow_up_date=data.follow_up_date,
    )
    return prescription


async def rate_consultation(
    db: AsyncSession,
    consultation_id: uuid.UUID,
    data: RatingCreate,
) -> Consultation | None:
    """Rate a completed consultation and recalculate vet avg rating."""
    consultation = await vet_repo.get_consultation_by_id(db, consultation_id)
    if not consultation:
        return None

    consultation = await vet_repo.update_consultation(
        db,
        consultation,
        farmer_rating=data.rating,
        farmer_review=data.review,
    )

    # Recalculate vet average rating
    if consultation.vet_id:
        vet = await vet_repo.get_vet_by_id(db, consultation.vet_id)
        if vet:
            # Compute average from all rated consultations for this vet
            result = await db.execute(
                select(func.avg(Consultation.farmer_rating)).where(
                    Consultation.vet_id == consultation.vet_id,
                    Consultation.farmer_rating.isnot(None),
                )
            )
            avg_rating = result.scalar() or 0.0
            await vet_repo.update_vet_profile(db, vet, rating_avg=round(float(avg_rating), 2))

    return consultation


async def get_farmer_consultations(
    db: AsyncSession, farmer_id: uuid.UUID
) -> list[Consultation]:
    """Get all consultations for a farmer."""
    return await vet_repo.get_farmer_consultations(db, farmer_id)


async def get_vet_queue(
    db: AsyncSession, vet_id: uuid.UUID
) -> list[Consultation]:
    """Get pending consultations for a vet."""
    return await vet_repo.get_vet_queue(db, vet_id)
