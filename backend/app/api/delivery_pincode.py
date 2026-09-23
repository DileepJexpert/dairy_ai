import httpx
from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_, select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import require_role
from app.models.user import UserRole
from app.models.serviceable_pincode import ServiceablePincode
from app.schemas.serviceable_pincode import (
    PincodeBulkCreate,
    PincodeCheckResponse,
    PincodeCreate,
    PincodeResponse,
    PincodeUpdate,
)

router = APIRouter(tags=["delivery pincodes"])
admin_only = require_role(UserRole.admin, UserRole.super_admin)

DEFAULT_SEEDS = [
    # Delhi NCR (Express 1-day delivery)
    {"pincode": "110001", "city": "New Delhi", "state": "Delhi", "delivery_days_min": 1, "delivery_days_max": 1, "express_available": True, "delivery_message": "Next-Day Morning Delivery by 8 AM via Cold-Chain Express"},
    {"pincode": "110002", "city": "New Delhi", "state": "Delhi", "delivery_days_min": 1, "delivery_days_max": 1, "express_available": True, "delivery_message": "Next-Day Morning Delivery by 8 AM via Cold-Chain Express"},
    {"pincode": "110016", "city": "Hauz Khas, New Delhi", "state": "Delhi", "delivery_days_min": 1, "delivery_days_max": 1, "express_available": True, "delivery_message": "Next-Day Morning Delivery by 8 AM"},
    {"pincode": "110020", "city": "Okhla, New Delhi", "state": "Delhi", "delivery_days_min": 1, "delivery_days_max": 1, "express_available": True, "delivery_message": "Next-Day Morning Delivery by 8 AM"},
    {"pincode": "201301", "city": "Noida", "state": "Uttar Pradesh", "delivery_days_min": 1, "delivery_days_max": 1, "express_available": True, "delivery_message": "Express Cold-Chain Delivery across Noida & Greater Noida"},
    {"pincode": "122001", "city": "Gurugram", "state": "Haryana", "delivery_days_min": 1, "delivery_days_max": 1, "express_available": True, "delivery_message": "Express Cold-Chain Delivery across Gurugram"},
    {"pincode": "122002", "city": "Gurugram (DLF Phase)", "state": "Haryana", "delivery_days_min": 1, "delivery_days_max": 1, "express_available": True, "delivery_message": "Express Cold-Chain Delivery across DLF / Golf Course"},
    # Lucknow (1-2 days)
    {"pincode": "226001", "city": "Lucknow (Hazratganj)", "state": "Uttar Pradesh", "delivery_days_min": 1, "delivery_days_max": 2, "express_available": True, "delivery_message": "Direct Farm Delivery in 1-2 Days"},
    {"pincode": "226010", "city": "Lucknow (Gomti Nagar)", "state": "Uttar Pradesh", "delivery_days_min": 1, "delivery_days_max": 2, "express_available": True, "delivery_message": "Direct Farm Delivery in 1-2 Days"},
    # Metro Hubs (2-3 days)
    {"pincode": "560001", "city": "Bengaluru", "state": "Karnataka", "delivery_days_min": 2, "delivery_days_max": 3, "express_available": False, "delivery_message": "Secure Glass-Pack Delivery via DTDC Air Express"},
    {"pincode": "400001", "city": "Mumbai", "state": "Maharashtra", "delivery_days_min": 2, "delivery_days_max": 3, "express_available": False, "delivery_message": "Secure Glass-Pack Delivery via DTDC Air Express"},
]


async def _ensure_seeded(db: AsyncSession):
    """Seed default delivery hubs if table is completely empty."""
    count = await db.scalar(select(func.count(ServiceablePincode.pincode)))
    if count == 0:
        for seed in DEFAULT_SEEDS:
            db.add(ServiceablePincode(**seed))
        await db.flush()


async def lookup_india_post_pincode(pincode: str) -> dict | None:
    """Fetch postal data from India Post open API."""
    clean = pincode.strip()
    if len(clean) != 6 or not clean.isdigit():
        return None
    try:
        async with httpx.AsyncClient(timeout=3.0) as client:
            resp = await client.get(f"https://api.postalpincode.in/pincode/{clean}")
            if resp.status_code == 200:
                data = resp.json()
                if isinstance(data, list) and len(data) > 0 and data[0].get("Status") == "Success":
                    offices = data[0].get("PostOffice") or []
                    if offices:
                        first = offices[0]
                        district = (first.get("District") or "").strip()
                        state = (first.get("State") or "").strip()
                        block = (first.get("Block") or "").strip()
                        name = (first.get("Name") or "").strip()

                        # Determine friendly city
                        city = district
                        for po in offices:
                            b = (po.get("Block") or "").strip().lower()
                            if "noida" in b:
                                city = "Noida"
                                break
                            elif "bangalore" in b:
                                city = "Bengaluru"
                                break
                            elif "mumbai" in b:
                                city = "Mumbai"
                                break
                            elif "delhi" in b:
                                city = "New Delhi"
                                break

                        if "gautam buddha nagar" in district.lower():
                            city = "Noida"
                        elif "bangalore" in district.lower():
                            city = "Bengaluru"
                        elif "delhi" in state.lower() or "delhi" in district.lower():
                            city = "New Delhi"
                        elif not city or city.lower() in {"na", "nil", "null"}:
                            city = block or name or district

                        return {
                            "pincode": clean,
                            "city": city,
                            "district": district,
                            "state": state,
                            "division": first.get("Division") or "",
                            "name": name,
                        }
    except Exception:
        pass
    return None


def _format_expected_date(min_days: int, max_days: int) -> str:
    now = datetime.now()
    if min_days <= 1:
        tomorrow = now + timedelta(days=1)
        return f"Tomorrow, {tomorrow.strftime('%b %d')} by 8 AM"
    target_start = now + timedelta(days=min_days)
    target_end = now + timedelta(days=max_days)
    if min_days == max_days:
        return target_start.strftime("%A, %b %d")
    return f"{target_start.strftime('%a, %b %d')} - {target_end.strftime('%a, %b %d')}"


def _serialize(row: ServiceablePincode) -> dict:
    return {
        "pincode": row.pincode,
        "city": row.city,
        "state": row.state,
        "is_serviceable": row.is_serviceable,
        "delivery_days_min": row.delivery_days_min,
        "delivery_days_max": row.delivery_days_max,
        "express_available": row.express_available,
        "delivery_fee": str(row.delivery_fee),
        "delivery_message": row.delivery_message,
        "created_at": row.created_at,
        "updated_at": row.updated_at,
    }


# ─── PUBLIC STOREFRONT APIS ──────────────────────────────────────────────────

@router.get("/marketplace/pincode/lookup")
async def lookup_pincode_details(
    pincode: str = Query(..., description="6-digit Indian Postal PIN code")
):
    """Direct lookup endpoint that returns official city, district, and state from India Post."""
    clean_pin = pincode.strip()
    data = await lookup_india_post_pincode(clean_pin)
    if not data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Could not find postal details for PIN code {clean_pin}",
        )
    return data


@router.get("/marketplace/pincode/reverse-geocode")
async def reverse_geocode_location(
    lat: float = Query(..., description="Latitude coordinate"),
    lon: float = Query(..., description="Longitude coordinate"),
    db: AsyncSession = Depends(get_db),
):
    """
    Reverse geocodes GPS coordinates into Indian address and PIN code using OpenStreetMap Nominatim.
    Also automatically evaluates delivery serviceability and estimated arrival time.
    """
    url = f"https://nominatim.openstreetmap.org/reverse?format=json&lat={lat}&lon={lon}&addressdetails=1"
    headers = {"User-Agent": "MilterraDairyEcommerce/1.0 (contact@milterra.in)"}

    try:
        async with httpx.AsyncClient(timeout=4.0) as client:
            resp = await client.get(url, headers=headers)
            if resp.status_code == 200:
                data = resp.json()
                addr = data.get("address", {})
                raw_pin = addr.get("postcode", "").strip()

                pincode = ""
                for part in raw_pin.replace("-", " ").split():
                    clean_digits = "".join(ch for ch in part if ch.isdigit())
                    if len(clean_digits) == 6:
                        pincode = clean_digits
                        break

                city = (
                    addr.get("city")
                    or addr.get("town")
                    or addr.get("village")
                    or addr.get("suburb")
                    or addr.get("state_district")
                    or "Unknown City"
                )
                state = addr.get("state", "")
                road = addr.get("road", "")
                suburb = addr.get("suburb", "")

                if "gautam buddha nagar" in str(addr).lower():
                    city = "Noida"
                elif "delhi" in state.lower() or "delhi" in city.lower():
                    city = "New Delhi"

                serviceability = None
                if pincode:
                    serviceability = await check_pincode_serviceability(pincode=pincode, db=db)

                return {
                    "pincode": pincode,
                    "city": city,
                    "state": state,
                    "road": road,
                    "suburb": suburb,
                    "formatted_address": data.get("display_name", f"{city}, {state}"),
                    "serviceability": serviceability,
                }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Reverse geocoding service error: {str(e)}",
        )
    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail="Could not resolve address from coordinates",
    )


@router.get("/marketplace/pincode/auto-detect")
async def auto_detect_pincode(
    lat: Optional[float] = Query(None, description="Optional GPS Latitude"),
    lon: Optional[float] = Query(None, description="Optional GPS Longitude"),
    db: AsyncSession = Depends(get_db),
):
    """
    Auto-detects user delivery PIN code and city.
    Uses OpenStreetMap Nominatim if GPS coordinates are supplied,
    or falls back to zero-cost network IP geolocation.
    """
    if lat is not None and lon is not None:
        return await reverse_geocode_location(lat=lat, lon=lon, db=db)

    # Fallback to free network IP geolocation
    try:
        async with httpx.AsyncClient(timeout=3.0) as client:
            resp = await client.get("http://ip-api.com/json/")
            if resp.status_code == 200:
                ip_data = resp.json()
                if ip_data.get("status") == "success":
                    ip_pin = "".join(ch for ch in str(ip_data.get("zip", "")) if ch.isdigit())
                    ip_lat = ip_data.get("lat")
                    ip_lon = ip_data.get("lon")

                    # If valid lat/lon, try Nominatim for street/pincode accuracy
                    if ip_lat and ip_lon:
                        try:
                            return await reverse_geocode_location(lat=ip_lat, lon=ip_lon, db=db)
                        except Exception:
                            pass

                    # Direct IP location fallback
                    city = ip_data.get("city", "New Delhi")
                    state = ip_data.get("regionName", "Delhi")
                    pincode = ip_pin if len(ip_pin) == 6 else "110001"

                    serviceability = await check_pincode_serviceability(pincode=pincode, db=db)

                    return {
                        "pincode": pincode,
                        "city": city,
                        "state": state,
                        "road": "",
                        "suburb": "",
                        "formatted_address": f"{city}, {state} {pincode}",
                        "serviceability": serviceability,
                    }
    except Exception:
        pass

    fallback_svc = await check_pincode_serviceability(pincode="110001", db=db)
    return {
        "pincode": "110001",
        "city": "New Delhi",
        "state": "Delhi",
        "formatted_address": "New Delhi, Delhi 110001",
        "serviceability": fallback_svc,
    }


@router.get("/marketplace/pincode/check", response_model=PincodeCheckResponse)
async def check_pincode_serviceability(
    pincode: str = Query(..., description="6-digit Indian Postal PIN code"),
    db: AsyncSession = Depends(get_db),
):
    """Checks whether a given PIN code is serviceable and returns the estimated arrival time."""
    clean_pin = pincode.strip()
    await _ensure_seeded(db)

    row = await db.scalar(
        select(ServiceablePincode).where(ServiceablePincode.pincode == clean_pin)
    )

    if not row or not row.is_serviceable:
        lookup = await lookup_india_post_pincode(clean_pin)
        city_name = lookup.get("city") if lookup else None
        state_name = lookup.get("state") if lookup else None
        loc_str = f" to {city_name}" if city_name else ""
        return PincodeCheckResponse(
            is_serviceable=False,
            pincode=clean_pin,
            city=city_name,
            state=state_name,
            message=f"Delivery is currently not available{loc_str} ({clean_pin}). We are expanding our coverage soon!",
        )

    expected_text = _format_expected_date(row.delivery_days_min, row.delivery_days_max)

    return PincodeCheckResponse(
        is_serviceable=True,
        pincode=row.pincode,
        city=row.city,
        state=row.state,
        delivery_days_min=row.delivery_days_min,
        delivery_days_max=row.delivery_days_max,
        expected_delivery_text=expected_text,
        express_available=row.express_available,
        delivery_fee=str(row.delivery_fee),
        message=row.delivery_message or f"Delivers to {row.city} in {row.delivery_days_min}-{row.delivery_days_max} business days.",
    )


# ─── ADMIN MANAGEMENT APIS ───────────────────────────────────────────────────

@router.get("/admin/pincodes")
async def list_pincodes(
    query: Optional[str] = None,
    is_serviceable: Optional[bool] = None,
    page: int = Query(1, ge=1),
    per_page: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
    _: None = Depends(admin_only),
):
    """Lists all delivery PIN codes in the master table with search & filtering."""
    await _ensure_seeded(db)
    stmt = select(ServiceablePincode)

    if query:
        q = f"%{query.strip()}%"
        stmt = stmt.where(
            or_(
                ServiceablePincode.pincode.ilike(q),
                ServiceablePincode.city.ilike(q),
                ServiceablePincode.state.ilike(q),
            )
        )
    if is_serviceable is not None:
        stmt = stmt.where(ServiceablePincode.is_serviceable == is_serviceable)

    total = await db.scalar(select(func.count()).select_from(stmt.subquery()))
    stmt = stmt.order_by(ServiceablePincode.city.asc(), ServiceablePincode.pincode.asc())
    stmt = stmt.offset((page - 1) * per_page).limit(per_page)

    rows = (await db.execute(stmt)).scalars().all()
    return {
        "success": True,
        "data": [_serialize(r) for r in rows],
        "total": total,
        "page": page,
        "per_page": per_page,
    }


@router.post("/admin/pincodes", status_code=status.HTTP_201_CREATED)
async def create_pincode(
    data: PincodeCreate,
    db: AsyncSession = Depends(get_db),
    _: None = Depends(admin_only),
):
    """Adds a new serviceable PIN code to the master table."""
    existing = await db.scalar(
        select(ServiceablePincode).where(ServiceablePincode.pincode == data.pincode)
    )
    if existing:
        raise HTTPException(status.HTTP_409_CONFLICT, f"PIN code {data.pincode} already exists in master table")

    row = ServiceablePincode(**data.model_dump())
    db.add(row)
    await db.flush()
    return {"success": True, "data": _serialize(row), "message": "Pincode created"}


@router.put("/admin/pincodes/{pincode}")
async def update_pincode(
    pincode: str,
    data: PincodeUpdate,
    db: AsyncSession = Depends(get_db),
    _: None = Depends(admin_only),
):
    """Updates delivery rules (city, days, express, active) for a PIN code."""
    row = await db.scalar(
        select(ServiceablePincode).where(ServiceablePincode.pincode == pincode)
    )
    if not row:
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"PIN code {pincode} not found")

    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(row, k, v)
    row.updated_at = datetime.utcnow()
    await db.flush()
    return {"success": True, "data": _serialize(row), "message": "Pincode updated"}


@router.delete("/admin/pincodes/{pincode}")
async def delete_pincode(
    pincode: str,
    db: AsyncSession = Depends(get_db),
    _: None = Depends(admin_only),
):
    """Deletes or deactivates a PIN code from the master table."""
    row = await db.scalar(
        select(ServiceablePincode).where(ServiceablePincode.pincode == pincode)
    )
    if not row:
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"PIN code {pincode} not found")

    await db.delete(row)
    await db.flush()
    return {"success": True, "message": f"PIN code {pincode} removed"}


@router.post("/admin/pincodes/bulk")
async def bulk_create_pincodes(
    data: PincodeBulkCreate,
    db: AsyncSession = Depends(get_db),
    _: None = Depends(admin_only),
):
    """Bulk import or update multiple PIN codes at once."""
    inserted = 0
    updated = 0
    for item in data.pincodes:
        existing = await db.scalar(
            select(ServiceablePincode).where(ServiceablePincode.pincode == item.pincode)
        )
        if existing:
            existing.city = item.city
            existing.state = item.state
            existing.delivery_days_min = item.delivery_days_min
            existing.delivery_days_max = item.delivery_days_max
            existing.express_available = item.express_available
            if item.delivery_message:
                existing.delivery_message = item.delivery_message
            existing.is_serviceable = True
            existing.updated_at = datetime.utcnow()
            updated += 1
        else:
            row = ServiceablePincode(
                pincode=item.pincode,
                city=item.city,
                state=item.state,
                delivery_days_min=item.delivery_days_min,
                delivery_days_max=item.delivery_days_max,
                express_available=item.express_available,
                delivery_message=item.delivery_message,
                is_serviceable=True,
            )
            db.add(row)
            inserted += 1

    await db.flush()
    return {
        "success": True,
        "inserted": inserted,
        "updated": updated,
        "total": inserted + updated,
        "message": f"Successfully processed {inserted + updated} PIN codes ({inserted} added, {updated} updated).",
    }
