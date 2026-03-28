import uuid
import logging

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user, require_role
from app.models.user import User, UserRole
from app.models.vet import ConsultationStatus
from app.repositories import vet_repo, farmer_repo
from app.services import vet_service, consultation_service
from app.schemas.vet import (
    VetRegister,
    VetUpdate,
    VetSearchFilters,
    ConsultationCreate,
    ConsultationUpdate,
    PrescriptionCreate,
    RatingCreate,
    AvailabilityUpdate,
)

logger = logging.getLogger("dairy_ai.api.vet")

router = APIRouter(tags=["vet"])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _vet_to_dict(vet, distance_km: float | None = None) -> dict:
    data = {
        "id": str(vet.id),
        "user_id": str(vet.user_id),
        "license_number": vet.license_number,
        "qualification": vet.qualification.value if hasattr(vet.qualification, "value") else vet.qualification,
        "specializations": vet.specializations or [],
        "experience_years": vet.experience_years,
        "languages": vet.languages or [],
        "consultation_fee": vet.consultation_fee,
        "rating_avg": vet.rating_avg,
        "total_consultations": vet.total_consultations,
        "total_earnings": vet.total_earnings,
        "is_verified": vet.is_verified,
        "is_available": vet.is_available,
        "bio": vet.bio,
        "pincode": vet.pincode,
        "city": vet.city,
        "district": vet.district,
        "state": vet.state,
        "address": vet.address,
        "lat": vet.lat,
        "lng": vet.lng,
        "service_radius_km": vet.service_radius_km,
    }
    if distance_km is not None:
        data["distance_km"] = distance_km
    return data


def _consultation_to_dict(c) -> dict:
    return {
        "id": str(c.id),
        "farmer_id": str(c.farmer_id),
        "cattle_id": str(c.cattle_id),
        "vet_id": str(c.vet_id) if c.vet_id else None,
        "consultation_type": c.consultation_type.value if hasattr(c.consultation_type, "value") else c.consultation_type,
        "status": c.status.value if hasattr(c.status, "value") else c.status,
        "symptoms": c.symptoms,
        "vet_diagnosis": c.vet_diagnosis,
        "vet_notes": c.vet_notes,
        "agora_channel_name": c.agora_channel_name,
        "agora_token": c.agora_token,
        "started_at": str(c.started_at) if c.started_at else None,
        "ended_at": str(c.ended_at) if c.ended_at else None,
        "duration_seconds": c.duration_seconds,
        "fee_amount": c.fee_amount,
        "platform_fee": c.platform_fee,
        "vet_payout": c.vet_payout,
        "farmer_rating": c.farmer_rating,
        "farmer_review": c.farmer_review,
        "follow_up_date": str(c.follow_up_date) if c.follow_up_date else None,
    }


def _prescription_to_dict(p) -> dict:
    return {
        "id": str(p.id),
        "consultation_id": str(p.consultation_id),
        "cattle_id": str(p.cattle_id),
        "vet_id": str(p.vet_id),
        "medicines": p.medicines or [],
        "instructions": p.instructions,
        "follow_up_date": str(p.follow_up_date) if p.follow_up_date else None,
        "is_fulfilled": p.is_fulfilled,
    }


async def _get_farmer_id(db: AsyncSession, user: User) -> uuid.UUID:
    logger.debug(f"Looking up farmer profile for user_id={user.id}")
    farmer = await farmer_repo.get_by_user_id(db, user.id)
    if not farmer:
        logger.warning(f"Farmer profile not found | user_id={user.id}")
        raise HTTPException(status_code=404, detail="Farmer profile not found")
    logger.debug(f"Farmer profile found | farmer_id={farmer.id}")
    return farmer.id


async def _get_vet_profile(db: AsyncSession, user: User):
    logger.debug(f"Looking up vet profile for user_id={user.id}")
    vet = await vet_repo.get_vet_by_user_id(db, user.id)
    if not vet:
        logger.warning(f"Vet profile not found | user_id={user.id}")
        raise HTTPException(status_code=404, detail="Vet profile not found")
    logger.debug(f"Vet profile found | vet_id={vet.id}")
    return vet


# ---------------------------------------------------------------------------
# Vet Profile Endpoints
# ---------------------------------------------------------------------------

@router.post("/vets/register", status_code=201)
async def register_vet(
    data: VetRegister,
    current_user: User = Depends(require_role(UserRole.vet)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"POST /vets/register called | user_id={current_user.id} | license={data.license_number}")
    logger.debug(f"Checking if vet profile already exists for user_id={current_user.id}")
    existing = await vet_repo.get_vet_by_user_id(db, current_user.id)
    if existing:
        logger.warning(f"Vet profile already exists | user_id={current_user.id} | vet_id={existing.id}")
        raise HTTPException(status_code=400, detail="Vet profile already exists")
    logger.debug(f"Calling vet_service.register_vet | user_id={current_user.id}")
    try:
        vet = await vet_service.register_vet(db, current_user.id, data)
        logger.info(f"Vet registered successfully | vet_id={vet.id} | user_id={current_user.id} | license={vet.license_number}")
        return {
            "success": True,
            "data": _vet_to_dict(vet),
            "message": "Vet profile registered. Awaiting verification.",
        }
    except Exception as e:
        logger.error(f"Failed to register vet for user_id={current_user.id}: {e}")
        raise


@router.get("/vets/search")
async def search_vets(
    specialization: str | None = Query(None, description="Filter by specialization (e.g. 'cattle', 'poultry')"),
    language: str | None = Query(None, description="Filter by language (e.g. 'hi', 'en', 'ta')"),
    available: bool | None = Query(None, description="Only show available vets"),
    pincode: str | None = Query(None, description="Filter by exact pincode"),
    lat: float | None = Query(None, description="Farmer's latitude for distance search"),
    lng: float | None = Query(None, description="Farmer's longitude for distance search"),
    max_distance_km: float = Query(50.0, description="Max distance in km (default 50)"),
    min_fee: float | None = Query(None, description="Minimum consultation fee"),
    max_fee: float | None = Query(None, description="Maximum consultation fee"),
    sort_by: str = Query("distance", description="Sort by: distance, fee_low, fee_high, rating"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(
        f"GET /vets/search called | user_id={current_user.id} | specialization={specialization} | "
        f"language={language} | available={available} | pincode={pincode} | "
        f"lat={lat} | lng={lng} | max_distance_km={max_distance_km} | "
        f"min_fee={min_fee} | max_fee={max_fee} | sort_by={sort_by}"
    )
    filters = VetSearchFilters(
        specialization=specialization,
        language=language,
        available=available,
        pincode=pincode,
        lat=lat,
        lng=lng,
        max_distance_km=max_distance_km,
        min_fee=min_fee,
        max_fee=max_fee,
        sort_by=sort_by,
    )
    logger.debug(f"Calling vet_service.search_vets with filters: {filters}")
    results = await vet_service.search_vets(db, filters)
    logger.info(f"Vet search completed | results_count={len(results)} | sort_by={sort_by}")
    return {
        "success": True,
        "data": [_vet_to_dict(r["vet"], r.get("distance_km")) for r in results],
        "message": f"Found {len(results)} vets",
    }


@router.put("/vets/me")
async def update_vet_profile(
    data: VetUpdate,
    current_user: User = Depends(require_role(UserRole.vet)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"PUT /vets/me called | user_id={current_user.id}")
    vet = await _get_vet_profile(db, current_user)
    logger.debug(f"Calling vet_service.update_profile | vet_id={vet.id}")
    try:
        updated = await vet_service.update_profile(db, vet, data)
        logger.info(f"Vet profile updated | vet_id={updated.id}")
        return {
            "success": True,
            "data": _vet_to_dict(updated),
            "message": "Vet profile updated",
        }
    except Exception as e:
        logger.error(f"Failed to update vet profile | vet_id={vet.id}: {e}")
        raise


@router.get("/vets/me/dashboard")
async def vet_dashboard(
    current_user: User = Depends(require_role(UserRole.vet)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /vets/me/dashboard called | user_id={current_user.id}")
    vet = await _get_vet_profile(db, current_user)
    logger.debug(f"Calling vet_service.get_vet_dashboard | vet_id={vet.id}")
    dashboard = await vet_service.get_vet_dashboard(db, vet.id)
    logger.info(f"Vet dashboard retrieved | vet_id={vet.id}")
    return {"success": True, "data": dashboard, "message": "Vet dashboard"}


@router.put("/vets/me/availability")
async def update_availability(
    data: AvailabilityUpdate,
    current_user: User = Depends(require_role(UserRole.vet)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"PUT /vets/me/availability called | user_id={current_user.id} | is_available={data.is_available}")
    vet = await _get_vet_profile(db, current_user)
    logger.debug(f"Calling vet_service.toggle_availability | vet_id={vet.id} | is_available={data.is_available}")
    updated = await vet_service.toggle_availability(db, vet.id, data.is_available)
    logger.info(f"Vet availability updated | vet_id={vet.id} | is_available={updated.is_available if updated else False}")
    return {
        "success": True,
        "data": {"is_available": updated.is_available if updated else False},
        "message": "Availability updated",
    }


@router.post("/vets/{vet_id}/verify")
async def verify_vet(
    vet_id: str,
    current_user: User = Depends(require_role(UserRole.admin)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"POST /vets/{vet_id}/verify called | admin_user_id={current_user.id}")
    logger.debug(f"Calling vet_service.verify_vet | vet_id={vet_id}")
    vet = await vet_service.verify_vet(db, uuid.UUID(vet_id))
    if not vet:
        logger.warning(f"Vet not found for verification | vet_id={vet_id}")
        raise HTTPException(status_code=404, detail="Vet not found")
    logger.info(f"Vet verified successfully | vet_id={vet.id} | license={vet.license_number}")
    return {
        "success": True,
        "data": _vet_to_dict(vet),
        "message": "Vet verified",
    }


# ---------------------------------------------------------------------------
# Consultation Endpoints
# ---------------------------------------------------------------------------

@router.post("/consultations", status_code=201)
async def create_consultation(
    data: ConsultationCreate,
    current_user: User = Depends(require_role(UserRole.farmer)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"POST /consultations called | user_id={current_user.id} | cattle_id={data.cattle_id} | type={data.consultation_type}")
    farmer_id = await _get_farmer_id(db, current_user)
    logger.debug(f"Calling consultation_service.request_consultation | farmer_id={farmer_id}")
    try:
        consultation = await consultation_service.request_consultation(db, farmer_id, data)
        logger.info(f"Consultation requested | consultation_id={consultation.id} | farmer_id={farmer_id} | status={consultation.status}")
        return {
            "success": True,
            "data": _consultation_to_dict(consultation),
            "message": "Consultation requested",
        }
    except Exception as e:
        logger.error(f"Failed to create consultation for farmer_id={farmer_id}: {e}")
        raise


@router.put("/consultations/{consultation_id}/accept")
async def accept_consultation(
    consultation_id: str,
    current_user: User = Depends(require_role(UserRole.vet)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"PUT /consultations/{consultation_id}/accept called | user_id={current_user.id}")
    vet = await _get_vet_profile(db, current_user)
    logger.debug(f"Calling consultation_service.accept_consultation | vet_id={vet.id} | consultation_id={consultation_id}")
    consultation = await consultation_service.accept_consultation(
        db, vet.id, uuid.UUID(consultation_id)
    )
    if not consultation:
        logger.warning(f"Consultation not found for accept | consultation_id={consultation_id}")
        raise HTTPException(status_code=404, detail="Consultation not found")
    logger.info(f"Consultation accepted | consultation_id={consultation.id} | vet_id={vet.id}")
    return {
        "success": True,
        "data": _consultation_to_dict(consultation),
        "message": "Consultation accepted",
    }


@router.put("/consultations/{consultation_id}/start")
async def start_consultation(
    consultation_id: str,
    current_user: User = Depends(require_role(UserRole.vet)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"PUT /consultations/{consultation_id}/start called | user_id={current_user.id}")
    logger.debug(f"Calling consultation_service.start_consultation | consultation_id={consultation_id}")
    consultation = await consultation_service.start_consultation(
        db, uuid.UUID(consultation_id)
    )
    if not consultation:
        logger.warning(f"Consultation not found for start | consultation_id={consultation_id}")
        raise HTTPException(status_code=404, detail="Consultation not found")
    logger.info(f"Consultation started | consultation_id={consultation.id} | started_at={consultation.started_at}")
    return {
        "success": True,
        "data": _consultation_to_dict(consultation),
        "message": "Consultation started",
    }


@router.put("/consultations/{consultation_id}/end")
async def end_consultation(
    consultation_id: str,
    data: ConsultationUpdate,
    current_user: User = Depends(require_role(UserRole.vet)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"PUT /consultations/{consultation_id}/end called | user_id={current_user.id}")
    logger.debug(f"Calling consultation_service.end_consultation | consultation_id={consultation_id} | has_diagnosis={bool(data.vet_diagnosis)}")
    consultation = await consultation_service.end_consultation(
        db,
        uuid.UUID(consultation_id),
        diagnosis=data.vet_diagnosis,
        notes=data.vet_notes,
    )
    if not consultation:
        logger.warning(f"Consultation not found for end | consultation_id={consultation_id}")
        raise HTTPException(status_code=404, detail="Consultation not found")
    logger.info(f"Consultation completed | consultation_id={consultation.id} | duration={consultation.duration_seconds}s | fee={consultation.fee_amount}")
    return {
        "success": True,
        "data": _consultation_to_dict(consultation),
        "message": "Consultation completed",
    }


@router.post("/consultations/{consultation_id}/prescription", status_code=201)
async def create_prescription(
    consultation_id: str,
    data: PrescriptionCreate,
    current_user: User = Depends(require_role(UserRole.vet)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"POST /consultations/{consultation_id}/prescription called | user_id={current_user.id}")
    logger.debug(f"Calling consultation_service.create_prescription | consultation_id={consultation_id} | medicines_count={len(data.medicines) if data.medicines else 0}")
    prescription = await consultation_service.create_prescription(
        db, uuid.UUID(consultation_id), data
    )
    if not prescription:
        logger.warning(f"Consultation not found or no vet assigned for prescription | consultation_id={consultation_id}")
        raise HTTPException(status_code=404, detail="Consultation not found or no vet assigned")
    logger.info(f"Prescription created | prescription_id={prescription.id} | consultation_id={consultation_id}")
    return {
        "success": True,
        "data": _prescription_to_dict(prescription),
        "message": "Prescription created",
    }


@router.put("/consultations/{consultation_id}/rate")
async def rate_consultation(
    consultation_id: str,
    data: RatingCreate,
    current_user: User = Depends(require_role(UserRole.farmer)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"PUT /consultations/{consultation_id}/rate called | user_id={current_user.id} | rating={data.rating}")
    logger.debug(f"Calling consultation_service.rate_consultation | consultation_id={consultation_id}")
    consultation = await consultation_service.rate_consultation(
        db, uuid.UUID(consultation_id), data
    )
    if not consultation:
        logger.warning(f"Consultation not found for rating | consultation_id={consultation_id}")
        raise HTTPException(status_code=404, detail="Consultation not found")
    logger.info(f"Consultation rated | consultation_id={consultation.id} | rating={consultation.farmer_rating}")
    return {
        "success": True,
        "data": _consultation_to_dict(consultation),
        "message": "Consultation rated",
    }


@router.get("/consultations/me")
async def farmer_consultations(
    current_user: User = Depends(require_role(UserRole.farmer)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /consultations/me called | user_id={current_user.id}")
    farmer_id = await _get_farmer_id(db, current_user)
    logger.debug(f"Calling consultation_service.get_farmer_consultations | farmer_id={farmer_id}")
    consultations = await consultation_service.get_farmer_consultations(db, farmer_id)
    logger.info(f"Farmer consultations retrieved | farmer_id={farmer_id} | count={len(consultations)}")
    return {
        "success": True,
        "data": [_consultation_to_dict(c) for c in consultations],
        "message": "Farmer consultations",
    }


@router.get("/consultations/queue")
async def vet_queue(
    current_user: User = Depends(require_role(UserRole.vet)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /consultations/queue called | user_id={current_user.id}")
    vet = await _get_vet_profile(db, current_user)
    logger.debug(f"Calling consultation_service.get_vet_queue | vet_id={vet.id}")
    consultations = await consultation_service.get_vet_queue(db, vet.id)
    logger.info(f"Vet queue retrieved | vet_id={vet.id} | count={len(consultations)}")
    return {
        "success": True,
        "data": [_consultation_to_dict(c) for c in consultations],
        "message": "Vet consultation queue",
    }
