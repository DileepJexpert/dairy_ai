import logging
import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import require_role
from app.models.user import User, UserRole
from app.schemas.analytics_schemas import (
    AdminCartListResponse,
    BatchEventsRequest,
    CartRecoveryNudgeResponse,
    ClickstreamTimelineResponse,
    TrafficSummaryResponse,
    VisitRegisterRequest,
    VisitRegisterResponse,
)
from app.services import analytics_service
from app.services.auth_service import decode_token, get_user_by_id

logger = logging.getLogger("dairy_ai.api.analytics")

router = APIRouter(tags=["analytics"])

optional_security = HTTPBearer(auto_error=False)


async def get_optional_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(optional_security),
    db: AsyncSession = Depends(get_db),
) -> User | None:
    if not credentials:
        return None
    try:
        payload = decode_token(credentials.credentials)
        if payload.get("type") == "access" and payload.get("sub"):
            return await get_user_by_id(db, payload["sub"])
    except Exception:
        pass
    return None


# ---------------------------------------------------------------------------
# PUBLIC TELEMETRY ENDPOINTS
# ---------------------------------------------------------------------------

@router.post("/analytics/visit")
async def register_visit(
    data: VisitRegisterRequest,
    request: Request,
    user: User | None = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db),
) -> dict[str, Any]:
    """Register or update a visitor session."""
    client_ip = (
        request.headers.get("x-forwarded-for", "").split(",")[0].strip()
        or (request.client.host if request.client else None)
    )
    user_id = user.id if user else None

    session_obj = await analytics_service.record_or_update_visit(
        db,
        data,
        user_id=user_id,
        client_ip=client_ip,
    )

    return {
        "success": True,
        "data": {
            "session_id": session_obj.session_id,
            "city": session_obj.city,
            "state": session_obj.state,
            "country": session_obj.country,
        },
        "message": "Visit registered",
    }


@router.post("/analytics/events")
async def ingest_events(
    data: BatchEventsRequest,
    user: User | None = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db),
) -> dict[str, Any]:
    """Ingest a batch of user clickstream events."""
    raw_events = [ev.model_dump() for ev in data.events]
    count = await analytics_service.ingest_events_batch(
        db,
        raw_events,
        user_id=user.id if user else None,
    )
    return {
        "success": True,
        "data": {"processed": count},
        "message": f"Successfully recorded {count} events",
    }


# ---------------------------------------------------------------------------
# ADMIN ANALYTICS & CART INTELLIGENCE ENDPOINTS
# ---------------------------------------------------------------------------

@router.get("/admin/ecommerce/carts")
async def get_admin_carts(
    status: str = Query("all", description="all, active, abandoned, checked_out"),
    search: str | None = Query(None, description="Search phone number or cart ID"),
    limit: int = Query(50, le=100),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(require_role(UserRole.admin, UserRole.super_admin)),
    db: AsyncSession = Depends(get_db),
) -> dict[str, Any]:
    """Admin live cart intelligence view: who has added items, active vs abandoned."""
    carts, total = await analytics_service.get_admin_carts(
        db,
        status_filter=status,
        search_query=search,
        limit=limit,
        offset=offset,
    )
    return {
        "success": True,
        "data": [c.model_dump() for c in carts],
        "total": total,
        "message": "Carts retrieved successfully",
    }


@router.post("/admin/ecommerce/carts/{cart_id}/nudge")
async def nudge_abandoned_cart(
    cart_id: str,
    current_user: User = Depends(require_role(UserRole.admin, UserRole.super_admin)),
    db: AsyncSession = Depends(get_db),
) -> dict[str, Any]:
    """Generate a personalized WhatsApp/SMS cart recovery nudge with discount coupon."""
    try:
        cart_uuid = uuid.UUID(cart_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid cart UUID")

    try:
        res = await analytics_service.generate_cart_recovery_nudge(db, cart_uuid)
        return {
            "success": True,
            "data": res.model_dump(),
            "message": "Cart recovery nudge generated",
        }
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/admin/ecommerce/analytics/traffic")
async def get_traffic_analytics(
    current_user: User = Depends(require_role(UserRole.admin, UserRole.super_admin)),
    db: AsyncSession = Depends(get_db),
) -> dict[str, Any]:
    """Traffic and geolocation analytics: visitors, geo breakdown, referrers, devices."""
    res = await analytics_service.get_traffic_summary(db)
    return {
        "success": True,
        "data": res.model_dump(),
        "message": "Traffic analytics retrieved successfully",
    }


@router.get("/admin/ecommerce/analytics/clickstream")
async def get_clickstream_timeline(
    user_id: str | None = Query(None),
    session_id: str | None = Query(None),
    user_phone: str | None = Query(None),
    event_type: str | None = Query(None),
    limit: int = Query(100, le=200),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(require_role(UserRole.admin, UserRole.super_admin)),
    db: AsyncSession = Depends(get_db),
) -> dict[str, Any]:
    """Clickstream journey: step-by-step click log filtered by user, session, or event."""
    user_uuid = None
    if user_id:
        try:
            user_uuid = uuid.UUID(user_id)
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid user UUID")

    events, total = await analytics_service.get_clickstream_timeline(
        db,
        user_id=user_uuid,
        session_id=session_id,
        user_phone=user_phone,
        event_type=event_type,
        limit=limit,
        offset=offset,
    )
    return {
        "success": True,
        "data": [ev.model_dump() for ev in events],
        "total": total,
        "message": "Clickstream events retrieved successfully",
    }
