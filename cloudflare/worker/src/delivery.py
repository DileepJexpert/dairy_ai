"""Milk Delivery Management API Router: Societies, Flats, Routes, Deliveries, Change Requests, Absences, and Sync."""

from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone
from typing import Any, List, Optional

import jwt
from fastapi import APIRouter, HTTPException, Request, Header
from pydantic import BaseModel, Field


delivery_router = APIRouter(prefix="/api/v1/delivery", tags=["milk delivery"])


def _env(request: Request) -> Any:
    scope = getattr(request, "scope", {})
    return scope.get("env") or getattr(request.app.state, "env", None)


def _d1_rows(result: Any) -> list[dict[str, Any]]:
    if result is None:
        return []
    if isinstance(result, dict) and "results" in result:
        rows = result["results"]
    else:
        rows = getattr(result, "results", result)
    return rows.to_py() if hasattr(rows, "to_py") else list(rows)


def _normalize_phone(phone: str) -> str:
    cleaned = "".join(ch for ch in phone if ch.isdigit())
    if cleaned.startswith("91") and len(cleaned) == 12:
        return cleaned[2:]
    return cleaned


# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------

class LoginRequest(BaseModel):
    phone: str
    otp: str
    name: str = "User"
    role: str = "subscriber"  # 'milkman' or 'subscriber'


class SocietyCreate(BaseModel):
    name: str
    address: str = ""


class FlatCreate(BaseModel):
    flat_number: str
    owner_name: str
    owner_phone: str
    has_app: bool = False
    default_quantity: float = 1.0
    price_per_litre: float = 60.0


class FlatUpdate(BaseModel):
    flat_number: Optional[str] = None
    owner_name: Optional[str] = None
    owner_phone: Optional[str] = None
    has_app: Optional[bool] = None
    default_quantity: Optional[float] = None
    price_per_litre: Optional[float] = None
    status: Optional[str] = None  # 'active', 'paused', 'stopped'


class DeliveryRecordPayload(BaseModel):
    id: Optional[str] = None
    flat_id: str
    date_key: str
    planned_quantity: float
    actual_quantity: float = 0.0
    status: str = "pending"
    delivered_at: Optional[str] = None
    notes: Optional[str] = None


class BatchDeliveriesPayload(BaseModel):
    deliveries: List[DeliveryRecordPayload]


class ChangeRequestCreate(BaseModel):
    flat_id: str
    type: str  # 'pauseToday', 'pauseTomorrow', 'pauseRange', 'changeQuantity', 'custom'
    start_date: str
    end_date: str
    requested_quantity: Optional[float] = None
    reason: Optional[str] = None


class ChangeRequestResolve(BaseModel):
    action: str  # 'applied' or 'rejected'
    notes: Optional[str] = None


class AbsenceCreate(BaseModel):
    type: str  # 'singleDay', 'dateRange', 'recurringDayOfWeek'
    date_key: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    day_of_week: Optional[int] = None
    reason: Optional[str] = None


class AuditLogCreate(BaseModel):
    flat_id: str
    actor_id: str
    actor_name: str
    actor_role: str
    type: str
    old_value: str
    new_value: str
    reason: Optional[str] = None


class QueueItem(BaseModel):
    op: str  # 'upsert' or 'delete'
    collection: str  # 'societies', 'flats', 'deliveries', 'change_requests', 'absences', 'audit_logs'
    data: dict[str, Any]


class DrainPayload(BaseModel):
    items: List[QueueItem]


# ---------------------------------------------------------------------------
# Auth Helper
# ---------------------------------------------------------------------------

def _get_user_id(request: Request, x_user_id: Optional[str] = Header(None)) -> str:
    # Supports explicit user header or Bearer JWT token
    if x_user_id:
        return x_user_id
    auth_header = request.headers.get("authorization", "")
    if auth_header.startswith("Bearer "):
        token = auth_header[7:].strip()
        try:
            payload = jwt.decode(token, options={"verify_signature": False})
            return payload.get("sub") or payload.get("user_id") or ""
        except Exception:
            pass
    return "milkman-1"  # Default fallback for testing


# ---------------------------------------------------------------------------
# 1. Auth Endpoints
# ---------------------------------------------------------------------------

@delivery_router.post("/auth/login")
async def login(payload: LoginRequest, request: Request):
    """Sign in with phone and OTP. Accepts '123456' as standard test/demo OTP."""
    cleaned = _normalize_phone(payload.phone)
    if payload.otp.strip() != "123456":
        raise HTTPException(400, "Invalid OTP. Use demo OTP 123456.")

    db = _env(request).DB
    user = await db.prepare("SELECT * FROM delivery_users WHERE phone = ?").bind(cleaned).first()

    if not user:
        user_id = str(uuid.uuid4())
        await db.prepare(
            "INSERT INTO delivery_users (id, phone, name, role) VALUES (?, ?, ?, ?)"
        ).bind(user_id, cleaned, payload.name.strip() or "User", payload.role).run()
        user = {"id": user_id, "phone": cleaned, "name": payload.name.strip() or "User", "role": payload.role}
    else:
        # Update name or role if provided
        if payload.name and payload.name != "User" and payload.name != user["name"]:
            await db.prepare("UPDATE delivery_users SET name = ? WHERE id = ?").bind(payload.name, user["id"]).run()
            user["name"] = payload.name

    # Create token
    token = jwt.encode({"sub": user["id"], "phone": user["phone"], "role": user["role"]}, "milterra-delivery-secret", algorithm="HS256")

    return {
        "success": True,
        "token": token,
        "user": {
            "id": user["id"],
            "phone": user["phone"],
            "name": user["name"],
            "role": user["role"],
        },
    }


@delivery_router.get("/auth/me")
async def get_me(request: Request, x_user_id: Optional[str] = Header(None)):
    user_id = _get_user_id(request, x_user_id)
    db = _env(request).DB
    user = await db.prepare("SELECT * FROM delivery_users WHERE id = ?").bind(user_id).first()
    if not user:
        raise HTTPException(404, "User not found")
    return {"success": True, "user": user}


# ---------------------------------------------------------------------------
# 2. Sync / State Hydration Endpoint
# ---------------------------------------------------------------------------

@delivery_router.get("/sync")
async def sync_data(request: Request, date_key: Optional[str] = None, x_user_id: Optional[str] = Header(None)):
    """Hydrates all relevant delivery data in a single roundtrip."""
    user_id = _get_user_id(request, x_user_id)
    db = _env(request).DB

    today = date_key or datetime.now(timezone.utc).strftime("%Y-%m-%d")
    user = await db.prepare("SELECT * FROM delivery_users WHERE id = ?").bind(user_id).first()

    if not user or user["role"] == "milkman":
        milkman_id = user["id"] if user else user_id

        societies_res = await db.prepare(
            "SELECT * FROM delivery_societies WHERE milkman_id = ? ORDER BY name ASC"
        ).bind(milkman_id).all()
        societies = _d1_rows(societies_res)
        society_ids = [s["id"] for s in societies]

        flats = []
        deliveries = []
        change_requests = []

        if society_ids:
            placeholders = ",".join("?" for _ in society_ids)
            flats_res = await db.prepare(
                f"SELECT * FROM delivery_flats WHERE society_id IN ({placeholders}) ORDER BY flat_number ASC"
            ).bind(*society_ids).all()
            flats = _d1_rows(flats_res)
            flat_ids = [f["id"] for f in flats]

            if flat_ids:
                f_placeholders = ",".join("?" for _ in flat_ids)
                deliv_res = await db.prepare(
                    f"SELECT * FROM delivery_records WHERE flat_id IN ({f_placeholders}) AND date_key = ?"
                ).bind(*flat_ids, today).all()
                deliveries = _d1_rows(deliv_res)

                cr_res = await db.prepare(
                    f"SELECT * FROM delivery_change_requests WHERE flat_id IN ({f_placeholders}) AND status = 'pending'"
                ).bind(*flat_ids).all()
                change_requests = _d1_rows(cr_res)

        absences_res = await db.prepare(
            "SELECT * FROM delivery_absences WHERE milkman_id = ?"
        ).bind(milkman_id).all()
        absences = _d1_rows(absences_res)

        return {
            "success": True,
            "role": "milkman",
            "date_key": today,
            "societies": societies,
            "flats": flats,
            "deliveries": deliveries,
            "change_requests": change_requests,
            "absences": absences,
        }

    else:
        # Subscriber role
        flat = await db.prepare("SELECT * FROM delivery_flats WHERE owner_phone = ?").bind(user["phone"]).first()
        if not flat:
            return {"success": True, "role": "subscriber", "flat": None, "deliveries": [], "change_requests": [], "absences": []}

        society = await db.prepare("SELECT * FROM delivery_societies WHERE id = ?").bind(flat["society_id"]).first()

        deliv_res = await db.prepare(
            "SELECT * FROM delivery_records WHERE flat_id = ? ORDER BY date_key DESC LIMIT 31"
        ).bind(flat["id"]).all()
        deliveries = _d1_rows(deliv_res)

        cr_res = await db.prepare(
            "SELECT * FROM delivery_change_requests WHERE flat_id = ? ORDER BY created_at DESC"
        ).bind(flat["id"]).all()
        change_requests = _d1_rows(cr_res)

        absences = []
        if society:
            abs_res = await db.prepare(
                "SELECT * FROM delivery_absences WHERE milkman_id = ?"
            ).bind(society["milkman_id"]).all()
            absences = _d1_rows(abs_res)

        return {
            "success": True,
            "role": "subscriber",
            "flat": flat,
            "society": society,
            "deliveries": deliveries,
            "change_requests": change_requests,
            "absences": absences,
        }


# ---------------------------------------------------------------------------
# 3. Societies Endpoints
# ---------------------------------------------------------------------------

@delivery_router.get("/societies")
async def list_societies(request: Request, x_user_id: Optional[str] = Header(None)):
    user_id = _get_user_id(request, x_user_id)
    db = _env(request).DB
    rows = await db.prepare("SELECT * FROM delivery_societies WHERE milkman_id = ? ORDER BY name ASC").bind(user_id).all()
    return {"success": True, "societies": _d1_rows(rows)}


@delivery_router.post("/societies")
async def create_society(payload: SocietyCreate, request: Request, x_user_id: Optional[str] = Header(None)):
    user_id = _get_user_id(request, x_user_id)
    db = _env(request).DB
    society_id = str(uuid.uuid4())
    await db.prepare(
        "INSERT INTO delivery_societies (id, milkman_id, name, address) VALUES (?, ?, ?, ?)"
    ).bind(society_id, user_id, payload.name.strip(), payload.address.strip()).run()

    created = await db.prepare("SELECT * FROM delivery_societies WHERE id = ?").bind(society_id).first()
    return {"success": True, "society": created}


@delivery_router.delete("/societies/{society_id}")
async def delete_society(society_id: str, request: Request, x_user_id: Optional[str] = Header(None)):
    user_id = _get_user_id(request, x_user_id)
    db = _env(request).DB
    await db.prepare("DELETE FROM delivery_societies WHERE id = ? AND milkman_id = ?").bind(society_id, user_id).run()
    return {"success": True, "message": "Society deleted"}


# ---------------------------------------------------------------------------
# 4. Flats Endpoints
# ---------------------------------------------------------------------------

@delivery_router.get("/societies/{society_id}/flats")
async def list_flats_in_society(society_id: str, request: Request):
    db = _env(request).DB
    rows = await db.prepare("SELECT * FROM delivery_flats WHERE society_id = ? ORDER BY flat_number ASC").bind(society_id).all()
    return {"success": True, "flats": _d1_rows(rows)}


@delivery_router.post("/societies/{society_id}/flats")
async def create_flat(society_id: str, payload: FlatCreate, request: Request):
    db = _env(request).DB
    flat_id = str(uuid.uuid4())
    cleaned_phone = _normalize_phone(payload.owner_phone)

    await db.prepare(
        """INSERT INTO delivery_flats (id, society_id, flat_number, owner_name, owner_phone, has_app, default_quantity, price_per_litre, status)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'active')"""
    ).bind(
        flat_id, society_id, payload.flat_number.strip(), payload.owner_name.strip(),
        cleaned_phone, 1 if payload.has_app else 0, payload.default_quantity, payload.price_per_litre
    ).run()

    created = await db.prepare("SELECT * FROM delivery_flats WHERE id = ?").bind(flat_id).first()
    return {"success": True, "flat": created}


@delivery_router.put("/flats/{flat_id}")
async def update_flat(flat_id: str, payload: FlatUpdate, request: Request):
    db = _env(request).DB
    flat = await db.prepare("SELECT * FROM delivery_flats WHERE id = ?").bind(flat_id).first()
    if not flat:
        raise HTTPException(404, "Flat not found")

    updates = []
    values = []
    if payload.flat_number is not None:
        updates.append("flat_number = ?")
        values.append(payload.flat_number.strip())
    if payload.owner_name is not None:
        updates.append("owner_name = ?")
        values.append(payload.owner_name.strip())
    if payload.owner_phone is not None:
        updates.append("owner_phone = ?")
        values.append(_normalize_phone(payload.owner_phone))
    if payload.has_app is not None:
        updates.append("has_app = ?")
        values.append(1 if payload.has_app else 0)
    if payload.default_quantity is not None:
        updates.append("default_quantity = ?")
        values.append(payload.default_quantity)
    if payload.price_per_litre is not None:
        updates.append("price_per_litre = ?")
        values.append(payload.price_per_litre)
    if payload.status is not None:
        updates.append("status = ?")
        values.append(payload.status)

    if updates:
        values.append(flat_id)
        sql = f"UPDATE delivery_flats SET {', '.join(updates)} WHERE id = ?"
        await db.prepare(sql).bind(*values).run()

    updated = await db.prepare("SELECT * FROM delivery_flats WHERE id = ?").bind(flat_id).first()
    return {"success": True, "flat": updated}


# ---------------------------------------------------------------------------
# 5. Delivery Records Endpoints
# ---------------------------------------------------------------------------

@delivery_router.post("/deliveries/batch")
async def save_deliveries_batch(payload: BatchDeliveriesPayload, request: Request):
    """Upserts delivery records in bulk."""
    db = _env(request).DB
    stmts = []

    for d in payload.deliveries:
        deliv_id = d.id or str(uuid.uuid4())
        delivered_at = d.delivered_at or (datetime.now(timezone.utc).isoformat() if d.status == "delivered" else None)
        stmts.append(
            db.prepare(
                """INSERT INTO delivery_records (id, flat_id, date_key, planned_quantity, actual_quantity, status, delivered_at, notes)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                   ON CONFLICT(flat_id, date_key) DO UPDATE SET
                   actual_quantity = excluded.actual_quantity,
                   status = excluded.status,
                   delivered_at = excluded.delivered_at,
                   notes = excluded.notes"""
            ).bind(
                deliv_id, d.flat_id, d.date_key, d.planned_quantity,
                d.actual_quantity, d.status, delivered_at, d.notes or ""
            )
        )
        if d.status == "delivered":
            milkman_id = _get_user_id(request)
            await _award_delivery_partner_points(db, milkman_id, deliv_id, d.flat_id, d.date_key)

    if stmts:
        await db.batch(stmts)

    return {"success": True, "count": len(stmts)}


@delivery_router.put("/deliveries/{delivery_id}")
async def update_single_delivery(delivery_id: str, payload: DeliveryRecordPayload, request: Request):
    db = _env(request).DB
    delivered_at = payload.delivered_at or (datetime.now(timezone.utc).isoformat() if payload.status == "delivered" else None)
    await db.prepare(
        """INSERT INTO delivery_records (id, flat_id, date_key, planned_quantity, actual_quantity, status, delivered_at, notes)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)
           ON CONFLICT(flat_id, date_key) DO UPDATE SET
           actual_quantity = excluded.actual_quantity,
           status = excluded.status,
           delivered_at = excluded.delivered_at,
           notes = excluded.notes"""
    ).bind(
        delivery_id, payload.flat_id, payload.date_key, payload.planned_quantity,
        payload.actual_quantity, payload.status, delivered_at, payload.notes or ""
    ).run()

    if payload.status == "delivered":
        milkman_id = _get_user_id(request)
        await _award_delivery_partner_points(db, milkman_id, delivery_id, payload.flat_id, payload.date_key)

    updated = await db.prepare("SELECT * FROM delivery_records WHERE id = ?").bind(delivery_id).first()
    return {"success": True, "delivery": updated}


# ---------------------------------------------------------------------------
# 6. Change Requests Endpoints
# ---------------------------------------------------------------------------

@delivery_router.get("/change-requests")
async def list_change_requests(request: Request, flat_id: Optional[str] = None):
    db = _env(request).DB
    if flat_id:
        rows = await db.prepare("SELECT * FROM delivery_change_requests WHERE flat_id = ? ORDER BY created_at DESC").bind(flat_id).all()
    else:
        rows = await db.prepare("SELECT * FROM delivery_change_requests WHERE status = 'pending' ORDER BY created_at DESC").all()
    return {"success": True, "requests": _d1_rows(rows)}


@delivery_router.post("/change-requests")
async def create_change_request(payload: ChangeRequestCreate, request: Request):
    db = _env(request).DB
    req_id = str(uuid.uuid4())
    await db.prepare(
        """INSERT INTO delivery_change_requests (id, flat_id, type, start_date, end_date, requested_quantity, reason, status)
           VALUES (?, ?, ?, ?, ?, ?, ?, 'pending')"""
    ).bind(
        req_id, payload.flat_id, payload.type, payload.start_date, payload.end_date,
        payload.requested_quantity, payload.reason or ""
    ).run()

    created = await db.prepare("SELECT * FROM delivery_change_requests WHERE id = ?").bind(req_id).first()
    return {"success": True, "request": created}


@delivery_router.post("/change-requests/{request_id}/resolve")
async def resolve_change_request(request_id: str, payload: ChangeRequestResolve, request: Request):
    db = _env(request).DB
    resolved_at = datetime.now(timezone.utc).isoformat()
    await db.prepare(
        "UPDATE delivery_change_requests SET status = ?, resolved_at = ? WHERE id = ?"
    ).bind(payload.action, resolved_at, request_id).run()

    updated = await db.prepare("SELECT * FROM delivery_change_requests WHERE id = ?").bind(request_id).first()
    return {"success": True, "request": updated}


# ---------------------------------------------------------------------------
# 7. Absences Endpoints
# ---------------------------------------------------------------------------

@delivery_router.get("/absences")
async def list_absences(request: Request, x_user_id: Optional[str] = Header(None)):
    user_id = _get_user_id(request, x_user_id)
    db = _env(request).DB
    rows = await db.prepare("SELECT * FROM delivery_absences WHERE milkman_id = ? ORDER BY created_at DESC").bind(user_id).all()
    return {"success": True, "absences": _d1_rows(rows)}


@delivery_router.post("/absences")
async def create_absence(payload: AbsenceCreate, request: Request, x_user_id: Optional[str] = Header(None)):
    user_id = _get_user_id(request, x_user_id)
    db = _env(request).DB
    abs_id = str(uuid.uuid4())
    await db.prepare(
        """INSERT INTO delivery_absences (id, milkman_id, type, date_key, start_date, end_date, day_of_week, reason)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)"""
    ).bind(
        abs_id, user_id, payload.type, payload.date_key,
        payload.start_date, payload.end_date, payload.day_of_week, payload.reason or ""
    ).run()

    created = await db.prepare("SELECT * FROM delivery_absences WHERE id = ?").bind(abs_id).first()
    return {"success": True, "absence": created}


@delivery_router.delete("/absences/{absence_id}")
async def delete_absence(absence_id: str, request: Request, x_user_id: Optional[str] = Header(None)):
    user_id = _get_user_id(request, x_user_id)
    db = _env(request).DB
    await db.prepare("DELETE FROM delivery_absences WHERE id = ? AND milkman_id = ?").bind(absence_id, user_id).run()
    return {"success": True, "message": "Absence deleted"}


# ---------------------------------------------------------------------------
# 8. Offline Queue Drain Endpoint (SyncQueue Drain)
# ---------------------------------------------------------------------------

@delivery_router.post("/sync/drain")
async def drain_queue(payload: DrainPayload, request: Request):
    """Processes batched operations queued locally in Hive while offline."""
    db = _env(request).DB
    stmts = []

    for item in payload.items:
        op = item.op
        coll = item.collection
        d = item.data

        if coll == "societies":
            if op == "upsert":
                stmts.append(
                    db.prepare(
                        "INSERT INTO delivery_societies (id, milkman_id, name, address) VALUES (?, ?, ?, ?) "
                        "ON CONFLICT(id) DO UPDATE SET name=excluded.name, address=excluded.address"
                    ).bind(d.get("id"), d.get("milkmanId") or d.get("milkman_id"), d.get("name"), d.get("address", ""))
                )
            elif op == "delete":
                stmts.append(db.prepare("DELETE FROM delivery_societies WHERE id = ?").bind(d.get("id")))

        elif coll == "flats":
            if op == "upsert":
                stmts.append(
                    db.prepare(
                        """INSERT INTO delivery_flats (id, society_id, flat_number, owner_name, owner_phone, has_app, default_quantity, price_per_litre, status)
                           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                           ON CONFLICT(id) DO UPDATE SET
                           flat_number=excluded.flat_number, owner_name=excluded.owner_name,
                           owner_phone=excluded.owner_phone, has_app=excluded.has_app,
                           default_quantity=excluded.default_quantity, price_per_litre=excluded.price_per_litre,
                           status=excluded.status"""
                    ).bind(
                        d.get("id"), d.get("societyId") or d.get("society_id"),
                        d.get("flatNumber") or d.get("flat_number"),
                        d.get("ownerName") or d.get("owner_name"),
                        _normalize_phone(d.get("ownerPhone") or d.get("owner_phone", "")),
                        1 if d.get("hasApp") or d.get("has_app") else 0,
                        float(d.get("defaultQuantity") or d.get("default_quantity") or 1.0),
                        float(d.get("pricePerLitre") or d.get("price_per_litre") or 60.0),
                        d.get("status", "active"),
                    )
                )
            elif op == "delete":
                stmts.append(db.prepare("DELETE FROM delivery_flats WHERE id = ?").bind(d.get("id")))

        elif coll == "deliveries":
            if op == "upsert":
                deliv_id = d.get("id") or str(uuid.uuid4())
                stmts.append(
                    db.prepare(
                        """INSERT INTO delivery_records (id, flat_id, date_key, planned_quantity, actual_quantity, status, delivered_at, notes)
                           VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                           ON CONFLICT(flat_id, date_key) DO UPDATE SET
                           actual_quantity=excluded.actual_quantity,
                           status=excluded.status,
                           delivered_at=excluded.delivered_at,
                           notes=excluded.notes"""
                    ).bind(
                        deliv_id, d.get("flatId") or d.get("flat_id"),
                        d.get("dateKey") or d.get("date_key"),
                        float(d.get("plannedQuantity") or d.get("planned_quantity") or 1.0),
                        float(d.get("actualQuantity") or d.get("actual_quantity") or 0.0),
                        d.get("status", "pending"),
                        d.get("deliveredAt") or d.get("delivered_at"),
                        d.get("notes", ""),
                    )
                )

        elif coll == "change_requests":
            if op == "upsert":
                stmts.append(
                    db.prepare(
                        """INSERT INTO delivery_change_requests (id, flat_id, type, start_date, end_date, requested_quantity, reason, status)
                           VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                           ON CONFLICT(id) DO UPDATE SET status=excluded.status"""
                    ).bind(
                        d.get("id"), d.get("flatId") or d.get("flat_id"),
                        d.get("type"), d.get("startDate") or d.get("start_date"),
                        d.get("endDate") or d.get("end_date"),
                        float(d.get("requestedQuantity") or d.get("requested_quantity")) if d.get("requestedQuantity") or d.get("requested_quantity") else None,
                        d.get("reason", ""), d.get("status", "pending")
                    )
                )

        elif coll == "absences":
            if op == "upsert":
                stmts.append(
                    db.prepare(
                        """INSERT INTO delivery_absences (id, milkman_id, type, date_key, start_date, end_date, day_of_week, reason)
                           VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                           ON CONFLICT(id) DO NOTHING"""
                    ).bind(
                        d.get("id"), d.get("milkmanId") or d.get("milkman_id"),
                        d.get("type"), d.get("dateKey") or d.get("date_key"),
                        d.get("startDate") or d.get("start_date"),
                        d.get("endDate") or d.get("end_date"),
                        d.get("dayOfWeek") or d.get("day_of_week"),
                        d.get("reason", ""),
                    )
                )
            elif op == "delete":
                stmts.append(db.prepare("DELETE FROM delivery_absences WHERE id = ?").bind(d.get("id")))

    if stmts:
        await db.batch(stmts)

    return {"success": True, "applied": len(stmts)}


# ---------------------------------------------------------------------------
# 9. Delivery Partner Points Collection Endpoints
# ---------------------------------------------------------------------------

async def _award_delivery_partner_points(db: Any, milkman_id: str, deliv_id: str, flat_id: str, date_key: str):
    """Award collection points to delivery partner for each completed order."""
    if not milkman_id or not deliv_id:
        return
    point_id = f"dp-{uuid.uuid4()}"
    try:
        await db.prepare(
            """INSERT INTO delivery_partner_points (id, milkman_id, delivery_record_id, flat_id, points_earned, delivered_date, notes)
               VALUES (?, ?, ?, ?, 10, ?, 'Order delivery collection points')"""
        ).bind(point_id, milkman_id, deliv_id, flat_id, date_key).run()
    except Exception:
        pass


@delivery_router.get("/partner/points")
@delivery_router.get("/deliveries/points-summary")
async def get_delivery_partner_points(request: Request, x_user_id: Optional[str] = Header(None)):
    user_id = _get_user_id(request, x_user_id)
    db = _env(request).DB
    records = []
    try:
        rows = await db.prepare(
            "SELECT * FROM delivery_partner_points WHERE milkman_id = ? ORDER BY created_at DESC"
        ).bind(user_id).all()
        records = _d1_rows(rows)
    except Exception:
        pass

    total_points = sum(r.get("points_earned", 10) for r in records)
    total_deliveries = len(records)

    return {
        "success": True,
        "data": {
            "milkman_id": user_id,
            "total_points": total_points,
            "total_deliveries": total_deliveries,
            "points_per_delivery": 10,
            "history": records
        }
    }
