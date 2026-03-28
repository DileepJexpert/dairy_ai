import logging
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

logger = logging.getLogger("dairy_ai.services.consultation")


async def request_consultation(
    db: AsyncSession,
    farmer_id: uuid.UUID,
    data: ConsultationCreate,
) -> Consultation:
    """Create a new consultation request with status=requested."""
    logger.info(f"request_consultation called | farmer_id={farmer_id}, cattle_id={data.cattle_id}, type={data.consultation_type}")
    logger.debug(f"Consultation symptoms: {data.symptoms}")

    channel_name = f"consult_{uuid.uuid4().hex[:12]}"
    logger.debug(f"Generated Agora channel name: {channel_name}")

    logger.debug(f"Generating Agora RTC token for channel={channel_name}")
    agora_token = generate_rtc_token(channel_name, uid=0, role="publisher")

    logger.debug(f"Creating consultation record in database | farmer_id={farmer_id}")
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
    logger.info(f"Consultation requested | consultation_id={consultation.id}, farmer_id={farmer_id}, status=requested, channel={channel_name}")
    return consultation


async def accept_consultation(
    db: AsyncSession,
    vet_id: uuid.UUID,
    consultation_id: uuid.UUID,
) -> Consultation | None:
    """Vet accepts a consultation request -- status -> assigned."""
    logger.info(f"accept_consultation called | vet_id={vet_id}, consultation_id={consultation_id}")

    logger.debug(f"Fetching consultation from database | consultation_id={consultation_id}")
    consultation = await vet_repo.get_consultation_by_id(db, consultation_id)
    if not consultation:
        logger.warning(f"Consultation not found | consultation_id={consultation_id}")
        return None

    logger.debug(f"Assigning vet to consultation | vet_id={vet_id}, consultation_id={consultation_id}, old_status={consultation.status}")
    updated = await vet_repo.update_consultation(
        db,
        consultation,
        vet_id=vet_id,
        status=ConsultationStatus.assigned,
    )
    logger.info(f"Consultation accepted | consultation_id={consultation_id}, vet_id={vet_id}, status=assigned")
    return updated


async def start_consultation(
    db: AsyncSession,
    consultation_id: uuid.UUID,
) -> Consultation | None:
    """Start an assigned consultation -- status -> in_progress."""
    logger.info(f"start_consultation called | consultation_id={consultation_id}")

    consultation = await vet_repo.get_consultation_by_id(db, consultation_id)
    if not consultation:
        logger.warning(f"Consultation not found | consultation_id={consultation_id}")
        return None

    start_time = datetime.now(timezone.utc)
    logger.debug(f"Starting consultation | consultation_id={consultation_id}, started_at={start_time.isoformat()}")

    updated = await vet_repo.update_consultation(
        db,
        consultation,
        status=ConsultationStatus.in_progress,
        started_at=start_time,
    )
    logger.info(f"Consultation started | consultation_id={consultation_id}, vet_id={consultation.vet_id}, status=in_progress")
    return updated


async def end_consultation(
    db: AsyncSession,
    consultation_id: uuid.UUID,
    diagnosis: str | None = None,
    notes: str | None = None,
) -> Consultation | None:
    """End an in-progress consultation -- calculate fee, platform cut, payout."""
    logger.info(f"end_consultation called | consultation_id={consultation_id}")
    logger.debug(f"End consultation details | diagnosis={diagnosis}, notes={notes}")

    consultation = await vet_repo.get_consultation_by_id(db, consultation_id)
    if not consultation:
        logger.warning(f"Consultation not found for ending | consultation_id={consultation_id}")
        return None

    now = datetime.now(timezone.utc)
    duration = 0
    if consultation.started_at:
        started = consultation.started_at
        if started.tzinfo is None:
            started = started.replace(tzinfo=timezone.utc)
        duration = int((now - started).total_seconds())
    logger.debug(f"Consultation duration | consultation_id={consultation_id}, duration={duration}s ({duration // 60}min {duration % 60}s)")

    # Fee calculation
    fee_amount = 0.0
    if consultation.vet_id:
        logger.debug(f"Fetching vet profile for fee calculation | vet_id={consultation.vet_id}")
        vet = await vet_repo.get_vet_by_id(db, consultation.vet_id)
        if vet:
            fee_amount = vet.consultation_fee
            logger.debug(f"Vet fee: ₹{fee_amount} | vet_id={consultation.vet_id}")
            # Update vet stats
            vet_payout_amount = fee_amount * 0.8
            logger.debug(f"Updating vet stats | total_consultations={vet.total_consultations + 1}, new_earnings=+₹{vet_payout_amount}")
            await vet_repo.update_vet_profile(
                db,
                vet,
                total_consultations=vet.total_consultations + 1,
                total_earnings=vet.total_earnings + vet_payout_amount,
            )

    platform_fee = round(fee_amount * 0.2, 2)
    vet_payout = round(fee_amount * 0.8, 2)
    logger.info(f"Fee breakdown | consultation_id={consultation_id}, total_fee=₹{fee_amount}, platform_fee=₹{platform_fee} (20%), vet_payout=₹{vet_payout} (80%)")

    updated = await vet_repo.update_consultation(
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
    logger.info(f"Consultation completed | consultation_id={consultation_id}, duration={duration}s, fee=₹{fee_amount}")
    return updated


async def create_prescription(
    db: AsyncSession,
    consultation_id: uuid.UUID,
    data: PrescriptionCreate,
) -> Prescription | None:
    """Create a prescription linked to a consultation."""
    logger.info(f"create_prescription called | consultation_id={consultation_id}")

    consultation = await vet_repo.get_consultation_by_id(db, consultation_id)
    if not consultation or not consultation.vet_id:
        logger.warning(f"Cannot create prescription — consultation not found or no vet assigned | consultation_id={consultation_id}")
        return None

    medicines_list = [m.model_dump() for m in data.medicines]
    logger.debug(f"Prescription details | medicines_count={len(medicines_list)}, follow_up={data.follow_up_date}")
    for i, med in enumerate(medicines_list):
        logger.debug(f"  Medicine {i+1}: {med}")

    logger.debug(f"Creating prescription in database | consultation_id={consultation_id}")
    prescription = await vet_repo.create_prescription(
        db,
        consultation_id=consultation_id,
        cattle_id=consultation.cattle_id,
        vet_id=consultation.vet_id,
        medicines=medicines_list,
        instructions=data.instructions,
        follow_up_date=data.follow_up_date,
    )
    logger.info(f"Prescription created | prescription_id={prescription.id}, consultation_id={consultation_id}, medicines_count={len(medicines_list)}")
    return prescription


async def rate_consultation(
    db: AsyncSession,
    consultation_id: uuid.UUID,
    data: RatingCreate,
) -> Consultation | None:
    """Rate a completed consultation and recalculate vet avg rating."""
    logger.info(f"rate_consultation called | consultation_id={consultation_id}, rating={data.rating}")
    logger.debug(f"Rating details | review={data.review}")

    consultation = await vet_repo.get_consultation_by_id(db, consultation_id)
    if not consultation:
        logger.warning(f"Consultation not found for rating | consultation_id={consultation_id}")
        return None

    logger.debug(f"Saving rating for consultation | consultation_id={consultation_id}")
    consultation = await vet_repo.update_consultation(
        db,
        consultation,
        farmer_rating=data.rating,
        farmer_review=data.review,
    )

    # Recalculate vet average rating
    if consultation.vet_id:
        logger.debug(f"Recalculating average rating for vet_id={consultation.vet_id}")
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
            new_avg = round(float(avg_rating), 2)
            logger.debug(f"Vet rating recalculated | vet_id={consultation.vet_id}, old_avg={vet.rating_avg}, new_avg={new_avg}")
            await vet_repo.update_vet_profile(db, vet, rating_avg=new_avg)

    logger.info(f"Consultation rated | consultation_id={consultation_id}, rating={data.rating}, vet_id={consultation.vet_id}")
    return consultation


async def get_farmer_consultations(
    db: AsyncSession, farmer_id: uuid.UUID
) -> list[Consultation]:
    """Get all consultations for a farmer."""
    logger.debug(f"get_farmer_consultations called | farmer_id={farmer_id}")
    consultations = await vet_repo.get_farmer_consultations(db, farmer_id)
    logger.debug(f"Farmer consultations fetched | farmer_id={farmer_id}, count={len(consultations)}")
    return consultations


async def get_vet_queue(
    db: AsyncSession, vet_id: uuid.UUID
) -> list[Consultation]:
    """Get pending consultations for a vet."""
    logger.debug(f"get_vet_queue called | vet_id={vet_id}")
    queue = await vet_repo.get_vet_queue(db, vet_id)
    logger.debug(f"Vet queue fetched | vet_id={vet_id}, pending_count={len(queue)}")
    return queue
