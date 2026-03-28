"""
Milk Collection, Cold Chain Monitoring, and Route APIs.
Covers: collection centers CRUD, milk collection recording, cold chain alerts,
route management, demand forecasting.
"""
import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from datetime import date

from app.database import get_db
from app.dependencies import get_current_user, require_role
from app.models.user import User, UserRole
from app.models.collection import (
    CollectionCenter, MilkCollection, CollectionRoute,
    ColdChainReading, ColdChainAlert, RouteStatus,
)
from app.schemas.collection import (
    CollectionCenterCreate, CollectionCenterUpdate,
    MilkCollectionCreate, CollectionRouteCreate, CollectionRouteUpdate,
    ColdChainReadingCreate,
)
from app.services import collection_service
from app.ml.demand_forecaster import forecast_demand, detect_collection_anomaly, optimize_route

logger = logging.getLogger("dairy_ai.api.collection")

router = APIRouter(prefix="/collection", tags=["collection"])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _center_to_dict(c: CollectionCenter) -> dict:
    return {
        "id": str(c.id),
        "name": c.name,
        "code": c.code,
        "cooperative_id": str(c.cooperative_id) if c.cooperative_id else None,
        "address": c.address,
        "village": c.village,
        "district": c.district,
        "state": c.state,
        "pincode": c.pincode,
        "lat": c.lat,
        "lng": c.lng,
        "capacity_litres": c.capacity_litres,
        "current_stock_litres": c.current_stock_litres,
        "chilling_temp_celsius": c.chilling_temp_celsius,
        "has_fat_analyzer": c.has_fat_analyzer,
        "has_snf_analyzer": c.has_snf_analyzer,
        "manager_name": c.manager_name,
        "manager_phone": c.manager_phone,
        "status": c.status.value if hasattr(c.status, "value") else c.status,
    }


def _collection_to_dict(m: MilkCollection) -> dict:
    return {
        "id": str(m.id),
        "center_id": str(m.center_id),
        "farmer_id": str(m.farmer_id),
        "date": str(m.date),
        "shift": m.shift.value if hasattr(m.shift, "value") else m.shift,
        "quantity_litres": m.quantity_litres,
        "fat_pct": m.fat_pct,
        "snf_pct": m.snf_pct,
        "temperature_celsius": m.temperature_celsius,
        "milk_grade": m.milk_grade.value if m.milk_grade and hasattr(m.milk_grade, "value") else m.milk_grade,
        "rate_per_litre": m.rate_per_litre,
        "total_amount": m.total_amount,
        "quality_bonus": m.quality_bonus,
        "deductions": m.deductions,
        "net_amount": m.net_amount,
        "is_rejected": m.is_rejected,
        "rejection_reason": m.rejection_reason,
    }


def _route_to_dict(r: CollectionRoute) -> dict:
    return {
        "id": str(r.id),
        "name": r.name,
        "date": str(r.date),
        "shift": r.shift.value if hasattr(r.shift, "value") else r.shift,
        "vehicle_number": r.vehicle_number,
        "driver_name": r.driver_name,
        "status": r.status.value if hasattr(r.status, "value") else r.status,
        "center_ids": r.center_ids or [],
        "waypoints": r.waypoints or [],
        "total_distance_km": r.total_distance_km,
        "estimated_duration_mins": r.estimated_duration_mins,
        "total_collected_litres": r.total_collected_litres,
    }


# ---------------------------------------------------------------------------
# Collection Center Endpoints
# ---------------------------------------------------------------------------

@router.post("/centers", status_code=201)
async def create_center(
    data: CollectionCenterCreate,
    current_user: User = Depends(require_role(UserRole.admin, UserRole.super_admin, UserRole.cooperative)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"POST /collection/centers called | user_id={current_user.id} | name={data.name} | code={data.code}")
    logger.debug(f"Center creation data: district={data.district}, capacity={data.capacity_litres}L")
    try:
        center = await collection_service.create_collection_center(db, data.model_dump())
        logger.info(f"Collection center created | center_id={center.id} | code={center.code}")
        return {
            "success": True,
            "data": _center_to_dict(center),
            "message": "Collection center created",
        }
    except Exception as e:
        logger.error(f"Failed to create collection center: {e}")
        raise


@router.get("/centers")
async def list_centers(
    district: str | None = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /collection/centers called | user_id={current_user.id} | district={district}")
    query = select(CollectionCenter)
    if district:
        query = query.where(CollectionCenter.district == district)
    result = await db.execute(query)
    centers = list(result.scalars().all())
    logger.info(f"Listed {len(centers)} collection centers | district={district}")
    return {
        "success": True,
        "data": [_center_to_dict(c) for c in centers],
        "message": f"Found {len(centers)} centers",
    }


@router.get("/centers/{center_id}/dashboard")
async def center_dashboard(
    center_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /collection/centers/{center_id}/dashboard called | user_id={current_user.id}")
    dashboard = await collection_service.get_center_dashboard(db, uuid.UUID(center_id))
    if not dashboard:
        logger.warning(f"Center not found | center_id={center_id}")
        raise HTTPException(status_code=404, detail="Collection center not found")
    logger.info(f"Center dashboard retrieved | center_id={center_id}")
    return {"success": True, "data": dashboard, "message": "Center dashboard"}


# ---------------------------------------------------------------------------
# Milk Collection Endpoints
# ---------------------------------------------------------------------------

@router.post("/milk", status_code=201)
async def record_collection(
    data: MilkCollectionCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(
        f"POST /collection/milk called | user_id={current_user.id} | "
        f"center_id={data.center_id} | farmer_id={data.farmer_id} | "
        f"quantity={data.quantity_litres}L | fat={data.fat_pct} | snf={data.snf_pct}"
    )
    try:
        collection = await collection_service.record_milk_collection(db, data.model_dump())
        logger.info(
            f"Milk collection recorded | id={collection.id} | "
            f"grade={collection.milk_grade} | net_amount=₹{collection.net_amount} | "
            f"rejected={collection.is_rejected}"
        )
        return {
            "success": True,
            "data": _collection_to_dict(collection),
            "message": "Milk collection recorded" if not collection.is_rejected else "Milk REJECTED — see reason",
        }
    except Exception as e:
        logger.error(f"Failed to record milk collection: {e}")
        raise


@router.get("/milk")
async def list_collections(
    center_id: str | None = Query(None),
    farmer_id: str | None = Query(None),
    collection_date: date | None = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(
        f"GET /collection/milk called | user_id={current_user.id} | "
        f"center_id={center_id} | farmer_id={farmer_id} | date={collection_date}"
    )
    query = select(MilkCollection)
    if center_id:
        query = query.where(MilkCollection.center_id == uuid.UUID(center_id))
    if farmer_id:
        query = query.where(MilkCollection.farmer_id == uuid.UUID(farmer_id))
    if collection_date:
        query = query.where(MilkCollection.date == collection_date)
    query = query.order_by(MilkCollection.created_at.desc()).limit(100)
    result = await db.execute(query)
    collections = list(result.scalars().all())
    logger.info(f"Listed {len(collections)} milk collections")
    return {
        "success": True,
        "data": [_collection_to_dict(c) for c in collections],
        "message": f"Found {len(collections)} collections",
    }


# ---------------------------------------------------------------------------
# Cold Chain Monitoring
# ---------------------------------------------------------------------------

@router.post("/cold-chain/reading", status_code=201)
async def record_cold_chain(
    data: ColdChainReadingCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(
        f"POST /collection/cold-chain/reading called | user_id={current_user.id} | "
        f"center_id={data.center_id} | temp={data.temperature_celsius}°C"
    )
    reading = await collection_service.record_cold_chain_reading(db, data.model_dump())
    alert_msg = " — ALERT triggered!" if reading.is_alert else ""
    logger.info(f"Cold chain reading recorded | id={reading.id} | temp={reading.temperature_celsius}°C{alert_msg}")
    return {
        "success": True,
        "data": {
            "id": str(reading.id),
            "temperature_celsius": reading.temperature_celsius,
            "is_alert": reading.is_alert,
            "recorded_at": str(reading.recorded_at),
        },
        "message": f"Temperature recorded: {reading.temperature_celsius}°C{alert_msg}",
    }


@router.get("/cold-chain/alerts")
async def list_alerts(
    center_id: str | None = Query(None),
    status_filter: str | None = Query(None, alias="status"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /collection/cold-chain/alerts called | center_id={center_id} | status={status_filter}")
    query = select(ColdChainAlert)
    if center_id:
        query = query.where(ColdChainAlert.center_id == uuid.UUID(center_id))
    if status_filter:
        query = query.where(ColdChainAlert.status == status_filter)
    query = query.order_by(ColdChainAlert.created_at.desc()).limit(50)
    result = await db.execute(query)
    alerts = list(result.scalars().all())
    logger.info(f"Listed {len(alerts)} cold chain alerts")
    return {
        "success": True,
        "data": [
            {
                "id": str(a.id),
                "center_id": str(a.center_id) if a.center_id else None,
                "temperature_celsius": a.temperature_celsius,
                "severity": a.severity.value if hasattr(a.severity, "value") else a.severity,
                "status": a.status.value if hasattr(a.status, "value") else a.status,
                "message": a.message,
                "created_at": str(a.created_at),
            }
            for a in alerts
        ],
        "message": f"Found {len(alerts)} alerts",
    }


# ---------------------------------------------------------------------------
# Route Optimization
# ---------------------------------------------------------------------------

@router.post("/routes", status_code=201)
async def create_route(
    data: CollectionRouteCreate,
    current_user: User = Depends(require_role(UserRole.admin, UserRole.super_admin, UserRole.cooperative)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"POST /collection/routes called | user_id={current_user.id} | name={data.name} | centers={len(data.center_ids)}")

    # Create the route
    route = CollectionRoute(
        name=data.name,
        date=data.date,
        shift=data.shift,
        vehicle_number=data.vehicle_number,
        driver_name=data.driver_name,
        driver_phone=data.driver_phone,
        center_ids=data.center_ids,
    )

    # Optimize if centers have lat/lng
    logger.debug(f"Fetching center coordinates for route optimization | center_count={len(data.center_ids)}")
    center_data = []
    for cid in data.center_ids:
        result = await db.execute(select(CollectionCenter).where(CollectionCenter.id == uuid.UUID(cid)))
        center = result.scalar_one_or_none()
        if center and center.lat and center.lng:
            center_data.append({"id": str(center.id), "lat": center.lat, "lng": center.lng, "name": center.name})

    if len(center_data) >= 2:
        logger.info(f"Optimizing route with {len(center_data)} centers")
        optimized = optimize_route(center_data)
        route.waypoints = optimized
        total_dist = sum(c.get("distance_km", 0) for c in optimized)
        route.total_distance_km = round(total_dist, 2)
        route.estimated_duration_mins = int(total_dist / 30 * 60)  # assume 30 km/h avg
        logger.info(f"Route optimized | distance={route.total_distance_km}km | est_duration={route.estimated_duration_mins}min")
    else:
        logger.debug("Not enough centers with coordinates for optimization")

    db.add(route)
    await db.flush()
    logger.info(f"Route created | route_id={route.id}")
    return {
        "success": True,
        "data": _route_to_dict(route),
        "message": "Collection route created and optimized",
    }


@router.get("/routes")
async def list_routes(
    route_date: date | None = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /collection/routes called | date={route_date}")
    query = select(CollectionRoute)
    if route_date:
        query = query.where(CollectionRoute.date == route_date)
    query = query.order_by(CollectionRoute.created_at.desc()).limit(50)
    result = await db.execute(query)
    routes = list(result.scalars().all())
    logger.info(f"Listed {len(routes)} routes")
    return {
        "success": True,
        "data": [_route_to_dict(r) for r in routes],
        "message": f"Found {len(routes)} routes",
    }


# ---------------------------------------------------------------------------
# Demand Forecasting & Anomaly Detection
# ---------------------------------------------------------------------------

@router.get("/centers/{center_id}/forecast")
async def get_forecast(
    center_id: str,
    days: int = Query(7, ge=1, le=30),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /collection/centers/{center_id}/forecast called | days={days}")
    forecast = await forecast_demand(db, uuid.UUID(center_id), days)
    logger.info(f"Forecast generated | center_id={center_id} | days={len(forecast)}")
    return {
        "success": True,
        "data": forecast,
        "message": f"Demand forecast for next {days} days",
    }


@router.get("/centers/{center_id}/anomaly")
async def check_anomaly(
    center_id: str,
    today_litres: float = Query(..., description="Today's actual collection in litres"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /collection/centers/{center_id}/anomaly called | today_litres={today_litres}")
    result = await detect_collection_anomaly(db, uuid.UUID(center_id), today_litres)
    logger.info(f"Anomaly check done | center_id={center_id} | is_anomaly={result.get('is_anomaly')}")
    return {
        "success": True,
        "data": result,
        "message": "Anomaly detected!" if result.get("is_anomaly") else "Collection within normal range",
    }
