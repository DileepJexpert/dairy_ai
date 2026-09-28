"""Isolated courier/COD simulator for test orders; never calls external providers."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Literal

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field

from commerce import _d1_rows, _env, _order_data, _require_auth, _test_commerce


simulation_router = APIRouter(prefix="/api/v1/marketplace/orders/admin/simulator", tags=["test simulation"])
SIMULATED_CARRIER = "Milterra Test Courier (SIMULATED)"


def _require_simulation(request: Request) -> None:
    env = _env(request)
    if getattr(env, "SIMULATION_ENABLED", "false") != "true" or not _test_commerce(env):
        raise HTTPException(404, "Not found")


async def _admin_test_order(order_id: str, request: Request):
    _require_simulation(request)
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    db = _env(request).DB
    order = await db.prepare("SELECT * FROM orders WHERE id=? AND is_test_order=1").bind(order_id).first()
    if not order:
        raise HTTPException(404, "Test order not found")
    return db, order


async def _active_return(db, order_id: str) -> bool:
    return bool(await db.prepare(
        "SELECT id FROM order_return_cases WHERE order_id=? AND status!='rejected'"
    ).bind(order_id).first())


@simulation_router.post("/{order_id}/dispatch")
async def simulate_dispatch(order_id: str, request: Request):
    db, order = await _admin_test_order(order_id, request)
    if order["status"] != "packed" or await _active_return(db, order_id):
        raise HTTPException(409, "Only a packed test order without a return case can be dispatched")
    tracking = "SIM-AWB-" + uuid.uuid4().hex[:16].upper()
    await db.batch([
        db.prepare("""UPDATE orders SET status='shipped', carrier=?, tracking_number=?, dispatched_at=?
            WHERE id=? AND is_test_order=1""").bind(
            SIMULATED_CARRIER, tracking, datetime.now(timezone.utc).isoformat(), order_id),
        db.prepare("""INSERT INTO order_events(id,order_id,status,title,remarks)
            VALUES(?,?,'SHIPPED','[SIMULATED] Courier dispatch',?)""").bind(
            str(uuid.uuid4()), order_id, f"No parcel booked. Test tracking number: {tracking}"),
    ])
    return {"success": True, "simulated": True, "data": await _order_data(db,
        await db.prepare("SELECT * FROM orders WHERE id=?").bind(order_id).first())}


class CourierEvent(BaseModel):
    model_config = ConfigDict(extra="forbid")
    event: Literal["OUT_FOR_DELIVERY", "DELIVERED", "DELIVERY_FAILED"]
    reason: str = Field(default="", max_length=300)


@simulation_router.post("/{order_id}/event")
async def simulate_courier_event(order_id: str, data: CourierEvent, request: Request):
    db, order = await _admin_test_order(order_id, request)
    if order["carrier"] != SIMULATED_CARRIER or await _active_return(db, order_id):
        raise HTTPException(409, "An active simulated shipment without a return case is required")
    current = order["status"]
    if data.event == "OUT_FOR_DELIVERY":
        if current != "shipped":
            raise HTTPException(409, "Shipment must be dispatched first")
        statements = [db.prepare("UPDATE orders SET status='out_for_delivery' WHERE id=?").bind(order_id)]
        title = "[SIMULATED] Out for delivery"
    elif data.event == "DELIVERED":
        if current not in ("shipped", "out_for_delivery"):
            raise HTTPException(409, "Shipment is not in transit")
        statements = [db.prepare("UPDATE orders SET status='delivered', delivered_at=? WHERE id=?").bind(
            datetime.now(timezone.utc).isoformat(), order_id)]
        title = "[SIMULATED] Delivered"
    else:
        if current not in ("shipped", "out_for_delivery"):
            raise HTTPException(409, "Only an in-transit shipment can fail delivery")
        if len(data.reason.strip()) < 5:
            raise HTTPException(422, "Give a delivery failure reason")
        statements = [db.prepare("""INSERT INTO order_return_cases(id,order_id,kind,reason,remarks)
            VALUES(?,?,'rto',?,?)""").bind(str(uuid.uuid4()), order_id,
            data.reason.strip(), "Simulated courier failure")]
        title = "[SIMULATED] Delivery failed; return to sender"
    statements.append(db.prepare("""INSERT INTO order_events(id,order_id,status,title,remarks)
        VALUES(?,?,?,?,?)""").bind(str(uuid.uuid4()), order_id, data.event, title,
        "No courier was contacted. " + data.reason.strip()))
    await db.batch(statements)
    return {"success": True, "simulated": True, "data": await _order_data(db,
        await db.prepare("SELECT * FROM orders WHERE id=?").bind(order_id).first())}


@simulation_router.post("/{order_id}/collect")
async def simulate_cod_collection(order_id: str, request: Request):
    db, order = await _admin_test_order(order_id, request)
    if order["payment_method"] != "cod" or order["status"] != "delivered" or await _active_return(db, order_id):
        raise HTTPException(409, "Only a delivered COD test order without a return case can be collected")
    if order["carrier"] != SIMULATED_CARRIER:
        raise HTTPException(409, "A simulated courier delivery is required")
    if order["payment_status"] != "pending":
        raise HTTPException(409, "Test COD is no longer pending")
    reference = "SIM-COD-" + uuid.uuid4().hex.upper()
    await db.batch([
        db.prepare("UPDATE orders SET payment_status='paid', remittance_reference=? WHERE id=?").bind(reference, order_id),
        db.prepare("""INSERT INTO simulated_money_movements(id,order_id,kind,amount_minor,reference)
            VALUES(?,?,'cod_collection',?,?)""").bind(str(uuid.uuid4()), order_id, order["total_minor"], reference),
        db.prepare("""INSERT INTO order_events(id,order_id,status,title,remarks)
            VALUES(?,?,'PAID','[SIMULATED] COD collection',?)""").bind(
            str(uuid.uuid4()), order_id, "No cash collected. Test reference: " + reference),
    ])
    return {"success": True, "simulated": True, "reference": reference,
        "data": await _order_data(db, await db.prepare("SELECT * FROM orders WHERE id=?").bind(order_id).first())}


class SimulatedRefund(BaseModel):
    model_config = ConfigDict(extra="forbid")
    restock_inventory: bool = True
    remarks: str = Field(default="", max_length=800)


@simulation_router.post("/{order_id}/refund")
async def simulate_cod_refund(order_id: str, data: SimulatedRefund, request: Request):
    db, order = await _admin_test_order(order_id, request)
    case = await db.prepare("SELECT * FROM order_return_cases WHERE order_id=?").bind(order_id).first()
    capture = await db.prepare("""SELECT id FROM simulated_money_movements
        WHERE order_id=? AND kind='cod_collection'""").bind(order_id).first()
    if (order["payment_method"] != "cod" or order["status"] != "delivered"
            or order["payment_status"] != "paid" or not capture or not case
            or case["kind"] != "customer_return" or case["status"] != "requested"):
        raise HTTPException(409, "A paid simulated COD order with a requested customer return is required")
    reference = "SIM-REFUND-" + uuid.uuid4().hex.upper()
    statements = [
        db.prepare("""UPDATE order_return_cases SET status='received', remarks=?, refund_reference=?,
            restocked=?, resolved_at=CURRENT_TIMESTAMP WHERE id=?""").bind(
            data.remarks.strip(), reference, int(data.restock_inventory), case["id"]),
        db.prepare("UPDATE orders SET payment_status='refunded' WHERE id=?").bind(order_id),
    ]
    if data.restock_inventory:
        lines = _d1_rows(await db.prepare("SELECT product_id,quantity FROM order_lines WHERE order_id=?").bind(order_id).all())
        for line in lines:
            statements.append(db.prepare("""UPDATE inventory SET available_units=available_units+?,
                updated_at=CURRENT_TIMESTAMP WHERE product_id=?""").bind(line["quantity"], line["product_id"]))
        if order["reservation_id"]:
            statements.append(db.prepare("UPDATE reservations SET status='CANCELLED' WHERE id=?").bind(order["reservation_id"]))
    statements.extend([
        db.prepare("""INSERT INTO simulated_money_movements(id,order_id,kind,amount_minor,reference)
            VALUES(?,?,'cod_refund',?,?)""").bind(str(uuid.uuid4()), order_id, order["total_minor"], reference),
        db.prepare("""INSERT INTO order_events(id,order_id,status,title,remarks)
            VALUES(?,?,'REFUNDED','[SIMULATED] COD refund',?)""").bind(
            str(uuid.uuid4()), order_id, "No money transferred. Test reference: " + reference),
    ])
    await db.batch(statements)
    return {"success": True, "simulated": True, "reference": reference,
        "data": await _order_data(db, await db.prepare("SELECT * FROM orders WHERE id=?").bind(order_id).first())}


@simulation_router.get("/{order_id}/ledger")
async def simulated_ledger(order_id: str, request: Request):
    db, _ = await _admin_test_order(order_id, request)
    rows = _d1_rows(await db.prepare("""SELECT kind,amount_minor,reference,created_at
        FROM simulated_money_movements WHERE order_id=? ORDER BY created_at""").bind(order_id).all())
    return {"success": True, "simulated": True, "data": [{**row,
        "amount": row["amount_minor"] / 100, "currency": "INR"} for row in rows]}
