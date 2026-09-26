"""Isolated FastAPI/D1 compatibility worker; not the production commerce API."""

import hashlib

import httpx
import jwt
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from compat import (
    MAX_IMAGE_BYTES,
    fetch_checkout_link_status,
    sanitize_product_image,
    verify_access_token,
    verify_razorpay_signature,
)
from commerce import commerce_router


app = FastAPI(title="Milterra Worker compatibility and commerce API")
app.include_router(commerce_router)


@app.middleware("http")
async def storefront_cors(request: Request, call_next):
    """Allow only explicitly configured storefront origins, including preflight."""
    origin = request.headers.get("origin")
    env = request.scope.get("env") or getattr(request.app.state, "env", None)
    configured = getattr(env, "CORS_ORIGINS", "") or ""
    allowed = {value.strip().rstrip("/") for value in configured.split(",") if value.strip()}
    valid_origin = bool(origin and origin in allowed and origin != "*")
    if request.method == "OPTIONS" and request.headers.get("access-control-request-method"):
        if not valid_origin:
            return JSONResponse({"detail": "Origin not allowed"}, status_code=403)
        requested_method = request.headers["access-control-request-method"].upper()
        if requested_method not in {"GET", "POST", "PUT", "PATCH", "DELETE"}:
            return JSONResponse({"detail": "Method not allowed"}, status_code=405)
        response = JSONResponse({}, status_code=204)
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, PATCH, DELETE"
        response.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type"
        response.headers["Access-Control-Max-Age"] = "600"
    else:
        response = await call_next(request)
    if request.url.path.startswith("/api/v1/marketplace/"):
        response.headers["Cache-Control"] = "no-store"
    if valid_origin:
        response.headers["Access-Control-Allow-Origin"] = origin
        vary = response.headers.get("Vary", "")
        response.headers["Vary"] = f"{vary}, Origin" if vary else "Origin"
    return response


@app.get("/health")
async def health_check() -> JSONResponse:
    # Exact request and response contract from backend/app/main.py.
    return JSONResponse(
        {"success": True, "message": "DairyAI API is running"},
        headers={"Cache-Control": "no-store"},
    )


@app.get("/ready")
async def readiness_check(request: Request) -> JSONResponse:
    try:
        db = _env(request).DB
        for table in ("customers", "inventory", "orders", "coupons", "serviceable_pincodes"):
            await db.prepare(f"SELECT 1 FROM {table} LIMIT 1").first()
    except Exception:
        return JSONResponse(
            {"success": False, "message": "Database unavailable"},
            status_code=503,
            headers={"Cache-Control": "no-store"},
        )
    return JSONResponse(
        {"success": True, "message": "Ready"},
        headers={"Cache-Control": "no-store"},
    )


def _env(request: Request):
    return request.scope.get("env") or getattr(request.app.state, "env", None)


def _d1_rows(result) -> list[dict]:
    rows = result.results
    return rows.to_py() if hasattr(rows, "to_py") else rows


def _require_probe_access(request: Request) -> None:
    env = _env(request)
    secret = getattr(env, "COMPAT_JWT_SECRET", "")
    authorization = request.headers.get("authorization", "")
    if not secret or not authorization.startswith("Bearer "):
        raise HTTPException(404, "Not found")
    try:
        claims = verify_access_token(authorization[7:], secret)
    except jwt.InvalidTokenError as exc:
        raise HTTPException(401, "Invalid access token") from exc
    if claims["role"] != "admin":
        raise HTTPException(403, "Admin access required")


class ProbeValue(BaseModel):
    value: str = Field(min_length=1, max_length=256)


@app.put("/__compat/d1/{key}")
async def write_probe(key: str, payload: ProbeValue, request: Request) -> dict:
    _require_probe_access(request)
    if len(key) > 128:
        raise HTTPException(422, "Key too long")
    db = _env(request).DB
    await db.prepare(
        "INSERT INTO compat_probe(probe_key, probe_value) VALUES (?, ?) "
        "ON CONFLICT(probe_key) DO UPDATE SET probe_value = excluded.probe_value, "
        "updated_at = CURRENT_TIMESTAMP"
    ).bind(key, payload.value).run()
    rows = await db.prepare(
        "SELECT probe_key, probe_value FROM compat_probe WHERE probe_key = ?"
    ).bind(key).all()
    return {"success": True, "data": _d1_rows(rows)[0]}


@app.get("/__compat/d1/{key}")
async def read_probe(key: str, request: Request) -> dict:
    _require_probe_access(request)
    rows = await _env(request).DB.prepare(
        "SELECT probe_key, probe_value FROM compat_probe WHERE probe_key = ?"
    ).bind(key).all()
    records = _d1_rows(rows)
    if not records:
        raise HTTPException(404, "Probe missing")
    return {"success": True, "data": records[0]}


@app.post("/__compat/signature")
async def check_webhook_signature(request: Request) -> dict:
    _require_probe_access(request)
    body = await request.body()
    secret = getattr(_env(request), "COMPAT_WEBHOOK_SECRET", "")
    signature = request.headers.get("x-razorpay-signature", "")
    if not verify_razorpay_signature(body, signature, secret):
        raise HTTPException(401, "Invalid payment webhook signature")
    return {"success": True, "data": {"verified": True}}


@app.get("/__compat/provider/{link_id}")
async def check_provider(link_id: str, request: Request) -> dict:
    _require_probe_access(request)
    env = _env(request)
    base_url = getattr(env, "COMPAT_PROVIDER_URL", "")
    if not base_url:
        raise HTTPException(503, "Mock provider not configured")
    try:
        result = await fetch_checkout_link_status(
            link_id,
            getattr(env, "COMPAT_PROVIDER_KEY_ID", ""),
            getattr(env, "COMPAT_PROVIDER_KEY_SECRET", ""),
            base_url=base_url,
        )
    except (httpx.HTTPError, ValueError) as exc:
        # This route is only a compatibility probe and never updates an order.
        raise HTTPException(502, "Provider probe failed") from exc
    return {"success": True, "data": {"id": result["id"], "status": result.get("status")}}


@app.post("/__compat/image")
async def check_image_processing(request: Request) -> dict:
    _require_probe_access(request)
    raw = bytearray()
    async for chunk in request.stream():
        if len(raw) + len(chunk) > MAX_IMAGE_BYTES:
            raise HTTPException(413, "Image must be 5 MB or smaller")
        raw.extend(chunk)
    try:
        clean = sanitize_product_image(bytes(raw))
    except ValueError as exc:
        raise HTTPException(422, str(exc)) from exc
    return {"success": True, "data": {"bytes": len(clean), "sha256": hashlib.sha256(clean).hexdigest()}}
