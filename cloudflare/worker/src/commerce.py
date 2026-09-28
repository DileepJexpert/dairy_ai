"""D1 Commerce API Slice: Inventory, Cart, Quote, Atomic Reservation, and Orders."""

from __future__ import annotations

import hashlib
import json
import re
import uuid
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from typing import Any, Iterable, Literal

import jwt
from fastapi import APIRouter, HTTPException, Request, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field, AliasChoices, ConfigDict
from customer_auth import require_session

from compat import verify_access_token


commerce_router = APIRouter(prefix="/api/v1/marketplace", tags=["commerce"])


def _env(request: Request) -> Any:
    scope = getattr(request, "scope", {})
    return scope.get("env") or getattr(request.app.state, "env", None)


def _d1_rows(result: Any) -> list[dict[str, Any]]:
    if result is None:
        return []
    rows = getattr(result, "results", result)
    return rows.to_py() if hasattr(rows, "to_py") else list(rows)


def _test_commerce(env):
    return (getattr(env, "TEST_COMMERCE_ENABLED", "false") == "true"
            and getattr(env, "LIVE_COD_ENABLED", "false") != "true"
            and getattr(env, "ENVIRONMENT", "") in ("staging", "test", "local"))


def _live_cod(env) -> bool:
    return (getattr(env, "LIVE_COD_ENABLED", "false") == "true"
            and getattr(env, "TEST_COMMERCE_ENABLED", "false") != "true"
            and getattr(env, "CUSTOMER_AUTH_ENABLED", "false") == "true")


def _indian_pincode_format(pincode: str) -> bool:
    # Format only: PIN existence and courier reach are separate checks.
    return bool(re.fullmatch(r"[1-8][0-9]{5}", pincode))


async def _delivery_policy(db: Any, pincode: str, env: Any) -> dict[str, Any]:
    if not _indian_pincode_format(pincode):
        return {"is_serviceable": False, "cod_available": False,
                "prepaid_available": False, "delivery_fee_minor": 0}
    hint = await db.prepare(
        "SELECT city, state, is_serviceable, delivery_fee_minor, delivery_days_min, delivery_days_max "
        "FROM serviceable_pincodes WHERE pincode=?"
    ).bind(pincode).first()
    if _test_commerce(env) or getattr(env, "CUSTOMER_AUTH_ENABLED", "false") != "true":
        enabled = bool(hint and hint["is_serviceable"])
        return {"pincode": pincode, "city": hint["city"] if hint else "",
                "state": hint["state"] if hint else "", "is_serviceable": enabled,
                "cod_available": enabled, "prepaid_available": False,
                "delivery_fee_minor": int(hint["delivery_fee_minor"]) if hint else 0,
                "delivery_days_min": hint["delivery_days_min"] if hint else None,
                "delivery_days_max": hint["delivery_days_max"] if hint else None}
    if not _live_cod(env):
        return {"pincode": pincode, "is_serviceable": False,
                "cod_available": False, "prepaid_available": False,
                "delivery_fee_minor": 0}
    default = await db.prepare(
        "SELECT cod_default_enabled, prepaid_default_enabled, delivery_fee_minor "
        "FROM delivery_policy WHERE id=1"
    ).first()
    rule = await db.prepare(
        "SELECT cod_enabled, prepaid_enabled, delivery_fee_minor, city, state "
        "FROM delivery_pincode_rules WHERE pincode=?"
    ).bind(pincode).first()
    if not default:
        raise HTTPException(503, "Delivery policy is unavailable")
    cod = bool(rule["cod_enabled"] if rule and rule["cod_enabled"] is not None
               else default["cod_default_enabled"])
    fee = int(rule["delivery_fee_minor"] if rule and rule["delivery_fee_minor"] is not None
              else default["delivery_fee_minor"])
    # A configured prepaid rule does not make an unintegrated gateway safe.
    prepaid_policy = bool(rule["prepaid_enabled"] if rule and rule["prepaid_enabled"] is not None
                          else default["prepaid_default_enabled"])
    return {"pincode": pincode, "city": (rule["city"] if rule and rule["city"] else hint["city"] if hint else ""),
            "state": (rule["state"] if rule and rule["state"] else hint["state"] if hint else ""),
            "is_serviceable": cod, "cod_available": cod, "prepaid_available": False,
            "prepaid_policy_enabled": prepaid_policy, "delivery_fee_minor": fee,
            "delivery_days_min": None, "delivery_days_max": None}


async def _require_auth(
    request: Request,
    allowed_roles: set[str] | list[str] | tuple[str, ...] | None = None,
) -> dict[str, Any]:
    """Verify an access token and load its current customer from D1, optionally enforcing roles."""
    env = _env(request)

    if getattr(env, "CUSTOMER_AUTH_ENABLED", "false") == "true":
        if not (_test_commerce(env) or _live_cod(env)):
            raise HTTPException(503, "Checkout is currently unavailable. Please try again later.")
        user = await require_session(request)
        if allowed_roles and user.get("role") not in allowed_roles:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Insufficient permissions")
        return user

    is_test_env = getattr(env, "ENVIRONMENT", "") == "test"
    allow_test_auth = getattr(env, "ALLOW_TEST_AUTH", False) is True
    if is_test_env and allow_test_auth:
        test_user_id = request.headers.get("x-test-customer-id")
        if test_user_id:
            customer_id = test_user_id
        else:
            customer_id = None
    else:
        customer_id = None

    if customer_id is None:
        authorization = request.headers.get("authorization", "")
        secret = getattr(env, "COMPAT_JWT_SECRET", None) or getattr(env, "JWT_SECRET", None)
        if not secret:
            raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Authentication is not configured")
        if not authorization.startswith("Bearer "):
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Authentication required")
        try:
            claims = verify_access_token(authorization[7:].strip(), secret)
        except jwt.InvalidTokenError as exc:
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid access token") from exc
        customer_id = str(claims["sub"])

    customer = await env.DB.prepare(
        "SELECT id, phone, role, full_name, is_active FROM customers WHERE id = ?"
    ).bind(customer_id).first()
    if not customer or not customer["is_active"]:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Customer not found or inactive")
    if allowed_roles and customer.get("role") not in allowed_roles:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Insufficient permissions")
    return {"id": customer["id"], "role": customer["role"], "phone": customer["phone"], "full_name": customer.get("full_name", "")}



def _normalize_lines(
    lines: Iterable[tuple[str, int, int]],
) -> list[tuple[str, int, int]]:
    normalized = sorted(lines)
    if not normalized:
        raise ValueError("At least one item is required")
    if len({line[0] for line in normalized}) != len(normalized):
        raise ValueError("Duplicate products must be combined before reservation")
    for product_id, quantity, price_minor in normalized:
        if not product_id or not isinstance(quantity, int) or quantity <= 0:
            raise ValueError("Invalid product or quantity")
        if not isinstance(price_minor, int) or price_minor < 0:
            raise ValueError("Price must be non-negative integer minor units")
    return normalized


def canonical_payload_hash(customer_id: str, lines: Iterable[tuple[str, int, int]]) -> str:
    canonical = json.dumps(
        {"customer_id": customer_id, "currency": "INR", "lines": _normalize_lines(lines)},
        sort_keys=True,
        separators=(",", ":"),
    )
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def checkout_fingerprint(
    customer_id: str,
    idempotency_key: str,
    address_id: str,
    payment_method: str = "cod",
    coupon_code: str | None = None,
    expected_total: float | None = None,
) -> str:
    payload = {
        "version": 1,
        "customer_id": customer_id,
        "idempotency_key": idempotency_key,
        "delivery_address_id": address_id,
        "payment_method": payment_method,
        "coupon_code": coupon_code.strip().upper() if coupon_code else None,
        "expected_total": round(expected_total, 2) if expected_total is not None else None,
    }
    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


# -----------------------------------------------------------------------------
# Input & Output Schemas
# -----------------------------------------------------------------------------

class CartItemInput(BaseModel):
    product_id: str = Field(min_length=1, max_length=128)
    quantity: int = Field(ge=1, le=999)


class CheckoutQuoteInput(BaseModel):
    delivery_address_id: str | None = None
    coupon_code: str | None = None
    payment_method: str = "cod"


class CouponQuoteInput(BaseModel):
    code: str = Field(min_length=1, max_length=50)


class CheckoutInput(BaseModel):
    idempotency_key: str = Field(min_length=8, max_length=128)
    delivery_address_id: str = Field(min_length=1, max_length=128)
    payment_method: str = "cod"
    coupon_code: str | None = None
    expected_total: float | None = None


class CartItemUpdateInput(BaseModel):
    quantity: int = Field(ge=0, le=999)


class AddressInput(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    recipient_name: str = Field(min_length=1, max_length=128)
    phone: str = Field(min_length=8, max_length=20)
    address_line1: str = Field(min_length=1, max_length=256)
    address_line2: str | None = None
    city: str = Field(min_length=1, max_length=128, validation_alias=AliasChoices("city", "village_or_city"))
    state: str = Field(min_length=1, max_length=128)
    pincode: str = Field(pattern=r"^[0-9]{6}$", validation_alias=AliasChoices("pincode", "postal_code"))
    district: str = Field(default="", max_length=128)
    landmark: str | None = Field(default=None, max_length=256)
    is_default: bool = False


async def _verify_address(db: Any, customer_id: str, address_id: str) -> dict[str, Any]:
    rows = await db.prepare(
        """SELECT id, customer_id, recipient_name, phone, address_line1, address_line2, city, state, pincode, is_default
           FROM customer_addresses WHERE id = ? AND customer_id = ?"""
    ).bind(address_id, customer_id).all()
    records = _d1_rows(rows)
    if not records:
        raise HTTPException(
            status.HTTP_404_NOT_FOUND,
            "Delivery address not found or does not belong to customer",
        )
    addr = records[0]
    pincode = str(addr.get("pincode", "")).strip()
    if len(pincode) != 6 or not pincode.isdigit():
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            f"Invalid delivery pincode '{pincode}'; must be exactly 6 numeric digits",
        )
    return addr


async def _delivery_fee_minor(db: Any, address: dict[str, Any], env: Any) -> int:
    coverage = await _delivery_policy(db, address["pincode"], env)
    if not coverage["cod_available"]:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            f"Cash on delivery is not currently available for pincode {address['pincode']}",
        )
    return int(coverage["delivery_fee_minor"])


def _require_supported_payment_method(payment_method: str) -> None:
    # This D1 slice has no provider settlement, webhook or refund path yet.
    if payment_method != "cod":
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "Online payment is unavailable on this API",
        )


async def _validate_coupon(db: Any, coupon_code: str | None, subtotal: float) -> tuple[str | None, float]:
    if not coupon_code or not coupon_code.strip():
        return None, 0.0

    code = coupon_code.strip().upper()
    rows = await db.prepare(
        """SELECT code, description, discount_type, discount_value, min_order_value, max_discount_cap, is_active, valid_until
           FROM coupons WHERE code = ?"""
    ).bind(code).all()
    records = _d1_rows(rows)

    if records:
        c = records[0]
        if not c.get("is_active", 1):
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, f"Coupon '{code}' is no longer active")
        if _coupon_expired(c.get("valid_until")):
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, f"Coupon '{code}' has expired")
        min_order = float(c.get("min_order_value") or 0.0)
        if subtotal < min_order:
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, f"Minimum order value for coupon '{code}' is ₹{min_order:.0f}")
        discount_type = c.get("discount_type")
        val = float(c.get("discount_value") or 0.0)
        if discount_type == "percentage":
            disc = (subtotal * val) / 100.0
            cap = c.get("max_discount_cap")
            if cap is not None:
                disc = min(disc, float(cap))
            return code, round(disc, 2)
        else:
            disc = min(subtotal, val)
            return code, round(disc, 2)

    raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, f"Invalid coupon code '{code}'")


def _money_minor(value: float, label: str) -> int:
    try:
        amount = Decimal(str(value))
        if not amount.is_finite() or amount <= 0 or amount > Decimal("10000000"):
            raise InvalidOperation
        minor = amount * 100
        if minor != minor.to_integral_value(rounding=ROUND_HALF_UP):
            raise InvalidOperation
        return int(minor)
    except (InvalidOperation, ValueError, TypeError) as exc:
        raise HTTPException(422, f"{label} must be a positive amount with at most two decimal places") from exc


def _coupon_expired(value: str | None) -> bool:
    if not value:
        return False
    expiry = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if expiry.tzinfo is None:
        expiry = expiry.replace(tzinfo=timezone.utc)
    return expiry <= datetime.now(timezone.utc)


def _coupon_view(row: dict[str, Any]) -> dict[str, Any]:
    return {**row, "id": row["code"], "is_active": bool(row["is_active"]),
            "usage_count": row.get("usage_count", 0)}


def _validate_coupon_value(discount_type: str, discount_value: float) -> None:
    value = Decimal(str(discount_value))
    if not value.is_finite() or value <= 0 or (discount_type == "percentage" and value > 100):
        raise HTTPException(422, "Coupon value must be positive and percentage discounts cannot exceed 100%")



# -----------------------------------------------------------------------------
# Inventory & Stock Routes
# -----------------------------------------------------------------------------

@commerce_router.get("/inventory")
async def list_live_inventory(request: Request):
    rows = await _env(request).DB.prepare("""SELECT i.product_id, i.price_minor, i.available_units, i.is_active,
        p.mrp_minor FROM inventory i LEFT JOIN inventory_pricing p ON p.product_id=i.product_id""").all()
    return {"success": True, "data": [{"product_id": row["product_id"],
        "price": row["price_minor"] / 100, "available_quantity": row["available_units"],
        "is_active": bool(row["is_active"]),
        "mrp": row["mrp_minor"] / 100 if row["mrp_minor"] is not None else None}
        for row in _d1_rows(rows)]}

@commerce_router.get("/inventory/{product_id}")
async def get_inventory_status(product_id: str, request: Request) -> dict:
    """Fetch live authoritative stock and price from D1."""
    db = _env(request).DB
    rows = await db.prepare(
        "SELECT product_id, title, available_units, price_minor, currency, is_active "
        "FROM inventory WHERE product_id = ?"
    ).bind(product_id).all()
    records = _d1_rows(rows)
    if not records:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Product not found in inventory")
    item = records[0]
    return {
        "success": True,
        "data": {
            "product_id": item["product_id"],
            "title": item["title"],
            "available_units": item["available_units"],
            "price": item["price_minor"] / 100.0,
            "currency": item["currency"],
            "in_stock": item["available_units"] > 0,
            "is_active": bool(item["is_active"]),
        },
    }


# -----------------------------------------------------------------------------
# Customer Cart Routes
# -----------------------------------------------------------------------------

@commerce_router.get("/cart")
async def get_cart(request: Request) -> dict:
    customer = await _require_auth(request)
    db = _env(request).DB
    
    rows = await db.prepare(
        """SELECT c.id AS cart_item_id, c.product_id, c.quantity,
                  i.title, i.price_minor, i.available_units, i.currency
           FROM cart_items c
           JOIN inventory i ON c.product_id = i.product_id
           WHERE c.customer_id = ?"""
    ).bind(customer["id"]).all()
    
    items = []
    subtotal_minor = 0
    total_count = 0
    for r in _d1_rows(rows):
        price = r["price_minor"] / 100.0
        line_total = price * r["quantity"]
        subtotal_minor += r["price_minor"] * r["quantity"]
        total_count += r["quantity"]
        items.append({
            "id": r["cart_item_id"],
            "product_id": r["product_id"],
            "title": r["title"],
            "quantity": r["quantity"],
            "price": price,
            "price_when_added": price,
            "current_price": price,
            "price_changed": False,
            "line_total": line_total,
            "in_stock": r["available_units"] >= r["quantity"],
            "available_quantity": r["available_units"],
        })
    
    return {
        "success": True,
        "data": {
            "id": customer["id"],
            "items": items,
            "item_count": total_count,
            "subtotal": subtotal_minor / 100.0,
        },
    }


@commerce_router.post("/cart/items", status_code=status.HTTP_201_CREATED)
async def add_cart_item(payload: CartItemInput, request: Request) -> dict:
    customer = await _require_auth(request)
    db = _env(request).DB

    # Verify product exists in inventory
    inv = await db.prepare("SELECT product_id, is_active FROM inventory WHERE product_id = ?").bind(payload.product_id).first()
    if not inv:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Product does not exist")
    if not inv.get("is_active", 1):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Product is not available for purchase")

    item_id = str(uuid.uuid4())
    await db.prepare(
        """INSERT INTO cart_items (id, customer_id, product_id, quantity, updated_at)
           VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
           ON CONFLICT(customer_id, product_id)
           DO UPDATE SET quantity = quantity + excluded.quantity, updated_at = CURRENT_TIMESTAMP"""
    ).bind(item_id, customer["id"], payload.product_id, payload.quantity).run()

    return {"success": True, "message": "Item added to cart", "data": {"product_id": payload.product_id, "quantity": payload.quantity}}


@commerce_router.put("/cart/items/{item_id}")
async def update_cart_item(item_id: str, payload: CartItemUpdateInput, request: Request) -> dict:
    customer = await _require_auth(request)
    db = _env(request).DB

    if payload.quantity <= 0:
        await db.prepare(
            "DELETE FROM cart_items WHERE (id = ? OR product_id = ?) AND customer_id = ?"
        ).bind(item_id, item_id, customer["id"]).run()
        return {"success": True, "data": {}, "message": "Item removed"}

    # Verify inventory exists and is active
    rows = await db.prepare(
        """SELECT c.id, c.product_id, i.available_units, i.is_active, i.title
           FROM cart_items c
           JOIN inventory i ON c.product_id = i.product_id
           WHERE (c.id = ? OR c.product_id = ?) AND c.customer_id = ?"""
    ).bind(item_id, item_id, customer["id"]).all()
    records = _d1_rows(rows)
    if not records:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Item not found in cart")

    item = records[0]
    if not item.get("is_active", 1):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, f"Product {item['title']} is inactive")
    if item["available_units"] < payload.quantity:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            f"Insufficient stock for {item['title']}. Available: {item['available_units']}, requested: {payload.quantity}",
        )

    await db.prepare(
        "UPDATE cart_items SET quantity = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?"
    ).bind(payload.quantity, item["id"]).run()

    return {"success": True, "data": {"id": item["id"], "quantity": payload.quantity}, "message": "Cart updated"}


@commerce_router.delete("/cart/items/{item_id}")
async def remove_cart_item(item_id: str, request: Request) -> dict:
    customer = await _require_auth(request)
    db = _env(request).DB
    await db.prepare("DELETE FROM cart_items WHERE (id = ? OR product_id = ?) AND customer_id = ?").bind(item_id, item_id, customer["id"]).run()
    return {"success": True, "data": {}, "message": "Item removed"}


@commerce_router.delete("/cart")
async def clear_cart(request: Request) -> dict:
    customer = await _require_auth(request)
    db = _env(request).DB
    await db.prepare("DELETE FROM cart_items WHERE customer_id = ?").bind(customer["id"]).run()
    return {"success": True, "data": {}, "message": "Cart cleared"}


# -----------------------------------------------------------------------------
# Customer Delivery Addresses Routes
# -----------------------------------------------------------------------------

def _address_data(row):
    return {**row, "village_or_city": row["city"], "postal_code": row["pincode"], "is_default": bool(row["is_default"])}


@commerce_router.get("/addresses")
async def get_addresses(request: Request):
    customer = await _require_auth(request)
    rows = await _env(request).DB.prepare("SELECT * FROM customer_addresses WHERE customer_id = ? ORDER BY is_default DESC, created_at DESC").bind(customer["id"]).all()
    return {"success": True, "data": [_address_data(r) for r in _d1_rows(rows)]}


@commerce_router.post("/addresses", status_code=201)
async def create_address(payload: AddressInput, request: Request):
    customer = await _require_auth(request)
    db = _env(request).DB
    address_id = str(uuid.uuid4())
    statements = []
    if payload.is_default:
        statements.append(db.prepare("UPDATE customer_addresses SET is_default=0 WHERE customer_id=?").bind(customer["id"]))
    statements.append(db.prepare("""INSERT INTO customer_addresses
        (id, customer_id, recipient_name, phone, address_line1, address_line2, city, state, pincode, is_default, district, landmark)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""").bind(address_id, customer["id"], payload.recipient_name, payload.phone, payload.address_line1, payload.address_line2, payload.city, payload.state, payload.pincode, int(payload.is_default), payload.district, payload.landmark))
    await db.batch(statements)
    return {"success": True, "data": _address_data({"id": address_id, **payload.model_dump()})}


@commerce_router.put("/addresses/{address_id}")
async def update_address(address_id: str, payload: dict[str, Any], request: Request):
    customer = await _require_auth(request)
    db = _env(request).DB
    existing = await db.prepare("SELECT * FROM customer_addresses WHERE id=? AND customer_id=?").bind(address_id, customer["id"]).first()
    if not existing:
        raise HTTPException(404, "Address not found")
    # Alias normalization before validation; never accept ownership from input.
    values = dict(payload)
    if "postal_code" in values: values["pincode"] = values.pop("postal_code")
    if "village_or_city" in values: values["city"] = values.pop("village_or_city")
    try:
        data = AddressInput.model_validate({**existing, **values})
    except ValueError:
        raise HTTPException(422, "Invalid address details")
    statements = []
    if data.is_default:
        statements.append(db.prepare("UPDATE customer_addresses SET is_default=0 WHERE customer_id=?").bind(customer["id"]))
    statements.append(db.prepare("""UPDATE customer_addresses SET recipient_name=?, phone=?, address_line1=?, address_line2=?, city=?, state=?, pincode=?, is_default=?, district=?, landmark=? WHERE id=? AND customer_id=?""").bind(data.recipient_name, data.phone, data.address_line1, data.address_line2, data.city, data.state, data.pincode, int(data.is_default), data.district, data.landmark, address_id, customer["id"]))
    await db.batch(statements)
    return {"success": True, "data": _address_data({"id": address_id, **data.model_dump()})}


@commerce_router.delete("/addresses/{address_id}")
async def delete_address(address_id: str, request: Request):
    customer = await _require_auth(request)
    db = _env(request).DB
    await db.batch([
        db.prepare("UPDATE orders SET address_id=NULL WHERE address_id=? AND customer_id=? AND address_snapshot <> '{}'").bind(address_id, customer["id"]),
        db.prepare("DELETE FROM customer_addresses WHERE id=? AND customer_id=?").bind(address_id, customer["id"]),
    ])
    return {"success": True, "data": {}, "message": "Address deleted"}


# -----------------------------------------------------------------------------
# Checkout Quote Route
# -----------------------------------------------------------------------------

@commerce_router.post("/orders/checkout/quote")
@commerce_router.post("/checkout/quote")
async def checkout_quote(payload: CheckoutQuoteInput, request: Request) -> dict:
    """Calculate authoritative checkout quote against live D1 inventory, delivery rules & coupons."""
    customer = await _require_auth(request)
    db = _env(request).DB
    if not await db.prepare("SELECT id FROM commerce_sellers WHERE id='vendor-1' AND status='approved'").first():
        raise HTTPException(503, "Ordering is temporarily unavailable")

    _require_supported_payment_method(payload.payment_method)
    if not payload.delivery_address_id:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Delivery address is required")
    address = await _verify_address(db, customer["id"], payload.delivery_address_id)
    delivery_fee_minor = await _delivery_fee_minor(db, address, _env(request))

    # 2. Fetch cart items
    rows = await db.prepare(
        """SELECT c.product_id, c.quantity, i.title, i.price_minor, i.available_units, i.currency, i.is_active
           FROM cart_items c
           JOIN inventory i ON c.product_id = i.product_id
           WHERE c.customer_id = ?"""
    ).bind(customer["id"]).all()
    cart_records = _d1_rows(rows)

    if not cart_records:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Cart is empty")

    subtotal_minor = 0
    items_out = []
    for r in cart_records:
        if not r.get("is_active", 1):
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, f"Product {r['title']} is inactive")
        if r["available_units"] < r["quantity"]:
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_ENTITY,
                f"Insufficient stock for {r['title']}. Available: {r['available_units']}, requested: {r['quantity']}"
            )
        line_total_minor = r["price_minor"] * r["quantity"]
        subtotal_minor += line_total_minor
        items_out.append({
            "product_id": r["product_id"],
            "title": r["title"],
            "quantity": r["quantity"],
            "price": r["price_minor"] / 100.0,
            "line_total": line_total_minor / 100.0,
        })

    subtotal = subtotal_minor / 100.0
    delivery_fee = delivery_fee_minor / 100.0

    # Coupon validation
    coupon_code, discount = await _validate_coupon(db, payload.coupon_code, subtotal)

    total_amount = round(max(0.0, subtotal + delivery_fee - discount), 2)

    return {
        "success": True,
        "data": {
            "subtotal": subtotal,
            "delivery_fee": delivery_fee,
            "discount": discount,
            "total": total_amount,
            "total_amount": total_amount,
            "coupon_code": coupon_code,
            "currency": "INR",
            "is_prelaunch_interest": False,
            "items": items_out,
        },
    }



# -----------------------------------------------------------------------------
# Atomic Checkout Order Placement
# -----------------------------------------------------------------------------

@commerce_router.post("/orders/checkout", status_code=status.HTTP_201_CREATED)
@commerce_router.post("/checkout", status_code=status.HTTP_201_CREATED)
async def checkout(payload: CheckoutInput, request: Request) -> dict:
    """Execute atomic batch reservation and order creation in D1."""
    customer = await _require_auth(request)
    db = _env(request).DB
    customer_id = customer["id"]

    _require_supported_payment_method(payload.payment_method)
    # A successful order must remain replayable even if its delivery coverage or
    # saved address changes after the first request.
    fingerprint = checkout_fingerprint(
        customer_id=customer_id,
        idempotency_key=payload.idempotency_key,
        address_id=payload.delivery_address_id,
        payment_method=payload.payment_method,
        coupon_code=payload.coupon_code,
        expected_total=payload.expected_total,
    )
    existing_order_row = await db.prepare(
        "SELECT id, status, payment_status, total_minor, checkout_request_fingerprint "
        "FROM orders WHERE customer_id = ? AND idempotency_key = ?"
    ).bind(customer_id, payload.idempotency_key).first()

    if existing_order_row:
        saved_fp = existing_order_row.get("checkout_request_fingerprint", "")
        if saved_fp != fingerprint:
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "Idempotency key was already used for a different checkout request"
            )
        return JSONResponse(status_code=200, content=await get_order_details(existing_order_row["id"], request))

    if not await db.prepare("SELECT id FROM commerce_sellers WHERE id='vendor-1' AND status='approved'").first():
        raise HTTPException(503, "Ordering is temporarily unavailable")

    address = await _verify_address(db, customer_id, payload.delivery_address_id)
    delivery_fee_minor = await _delivery_fee_minor(db, address, _env(request))

    # 3. Fetch current cart items joined with inventory
    rows = await db.prepare(
        """SELECT c.product_id, c.quantity, i.title, i.price_minor, i.available_units, i.currency
           FROM cart_items c
           JOIN inventory i ON c.product_id = i.product_id
           WHERE c.customer_id = ?"""
    ).bind(customer_id).all()
    cart_records = _d1_rows(rows)

    if not cart_records:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Cart is empty")

    # 4. Build normalized lines list: (product_id, quantity, price_minor)
    lines: list[tuple[str, int, int]] = []
    subtotal_minor = 0
    for r in cart_records:
        lines.append((r["product_id"], r["quantity"], r["price_minor"]))
        subtotal_minor += r["price_minor"] * r["quantity"]

    subtotal = subtotal_minor / 100.0

    # Validate coupon if provided
    applied_coupon, discount = await _validate_coupon(db, payload.coupon_code, subtotal)
    discount_minor = int(round(discount * 100))

    total_minor = max(0, subtotal_minor + delivery_fee_minor - discount_minor)

    # Optional: verify client expected total
    if payload.expected_total is not None:
        expected_minor = int(round(payload.expected_total * 100))
        if abs(expected_minor - total_minor) > 1:
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_ENTITY,
                f"Checkout total mismatch: calculated ₹{total_minor/100:.2f}, expected ₹{payload.expected_total:.2f}"
            )

    # 5. Construct atomic D1 Batch statements
    reservation_id = str(uuid.uuid4())
    order_id = str(uuid.uuid4())
    hash_val = canonical_payload_hash(customer_id, lines)

    statements = []

    # Step A: Insert Reservation (Parent)
    statements.append(
        db.prepare(
            """INSERT INTO reservations (id, customer_id, idempotency_key, payload_sha256, expected_lines, status)
               VALUES (?, ?, ?, ?, ?, 'CREATING')"""
        ).bind(reservation_id, customer_id, payload.idempotency_key, hash_val, len(lines))
    )

    # Step B: Insert Reservation Lines (Triggers will decrement stock & verify unit_price_minor)
    for p_id, qty, price_minor in _normalize_lines(lines):
        statements.append(
            db.prepare(
                """INSERT INTO reservation_lines (reservation_id, product_id, quantity, unit_price_minor, currency)
                   VALUES (?, ?, ?, ?, 'INR')"""
            ).bind(reservation_id, p_id, qty, price_minor)
        )

    # Step C: Insert Reservation Seal (Triggers will verify line count & mark status 'RESERVED')
    statements.append(
        db.prepare("INSERT INTO reservation_seals (reservation_id) VALUES (?)").bind(reservation_id)
    )

    # Step D: Insert Order
    statements.append(
        db.prepare(
            """INSERT INTO orders (id, customer_id, reservation_id, idempotency_key, checkout_request_fingerprint,
                                   address_id, subtotal_minor, delivery_fee_minor, discount_minor, total_minor,
                                   currency, status, payment_status, payment_method)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'INR', 'confirmed', 'pending', ?)"""
        ).bind(
            order_id,
            customer_id,
            reservation_id,
            payload.idempotency_key,
            fingerprint,
            payload.delivery_address_id,
            subtotal_minor,
            delivery_fee_minor,
            discount_minor,
            total_minor,
            payload.payment_method,
        )
    )

    statements.append(db.prepare("UPDATE orders SET is_test_order=? WHERE id=?").bind(int(_test_commerce(_env(request))), order_id))

    # Step E: Insert Order Lines
    for r in cart_records:
        line_id = str(uuid.uuid4())
        statements.append(
            db.prepare(
                """INSERT INTO order_lines (id, order_id, product_id, product_title, quantity,
                                           unit_price_minor, total_minor, currency)
                   VALUES (?, ?, ?, ?, ?, ?, ?, 'INR')"""
            ).bind(
                line_id,
                order_id,
                r["product_id"],
                r["title"],
                r["quantity"],
                r["price_minor"],
                r["price_minor"] * r["quantity"],
            )
        )

    # Step F: Clear Customer Cart Items
    statements.append(
        db.prepare("DELETE FROM cart_items WHERE customer_id = ?").bind(customer_id)
    )
    if applied_coupon:
        statements.append(db.prepare(
            "UPDATE coupons SET usage_count = usage_count + 1 WHERE code = ?"
        ).bind(applied_coupon))
    # Step G: Record initial order milestone
    statements.append(
        db.prepare(
            """INSERT INTO order_events (id, order_id, status, title, location, remarks)
               VALUES (?, ?, 'CONFIRMED', 'Order Placed & Confirmed', 'Online Store', 'Your order has been received and verified for fulfillment.')"""
        ).bind(str(uuid.uuid4()), order_id)
    )

    # 6. Execute D1 batch atomically
    try:
        await db.batch(statements)
    except Exception as exc:
        err_msg = str(exc)
        if "insufficient stock" in err_msg.lower():
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Insufficient stock for one or more items") from exc
        if "price changed" in err_msg.lower():
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Price changed; please refresh your cart") from exc
        if "unique" in err_msg.lower():
            # In race conditions, another request might have completed with the same key
            winner = await db.prepare(
                "SELECT id, status, total_minor, checkout_request_fingerprint FROM orders WHERE customer_id = ? AND idempotency_key = ?"
            ).bind(customer_id, payload.idempotency_key).first()
            if winner:
                if winner.get("checkout_request_fingerprint") != fingerprint:
                    raise HTTPException(
                        status.HTTP_409_CONFLICT,
                        "Idempotency conflict: a concurrent order was placed with the same key but different parameters",
                    ) from exc
                return JSONResponse(status_code=200, content=await get_order_details(winner["id"], request))
            raise HTTPException(status.HTTP_409_CONFLICT, "Idempotency conflict") from exc
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, f"Order placement failed: {err_msg}") from exc

    return await get_order_details(order_id, request)


# -----------------------------------------------------------------------------
# Order Details, Payment & Cancellation
# -----------------------------------------------------------------------------

@commerce_router.get("/orders/payment-capabilities")
async def payment_capabilities(request: Request) -> dict:
    """Return payment capabilities for Flutter client."""
    return {
        "success": True,
        "data": {
            "is_prelaunch_interest": False,
            "online_payment_available": False,
            "test_mode": _test_commerce(_env(request)),
        },
    }


async def _order_data(db, row):
    lines = _d1_rows(await db.prepare("SELECT * FROM order_lines WHERE order_id=?").bind(row["id"]).all())
    state = row["status"].upper()
    timeline = []
    try:
        events = _d1_rows(await db.prepare(
            "SELECT id, status, title, location, remarks, created_at FROM order_events WHERE order_id=? ORDER BY created_at ASC"
        ).bind(row["id"]).all())
        timeline = [{
            "id": ev["id"],
            "time": ev["created_at"],
            "title": ev["title"],
            "location": ev.get("location") or "",
            "remarks": ev.get("remarks") or "",
            "status": ev["status"].upper(),
        } for ev in events]
    except Exception:
        timeline = []
    carrier = row.get("carrier") if "carrier" in row and row["carrier"] else "Not assigned"
    tracking = row.get("tracking_number") if "tracking_number" in row and row["tracking_number"] else ""
    return_case = await db.prepare("SELECT kind,status,reason,remarks,restocked FROM order_return_cases WHERE order_id=?").bind(row["id"]).first()
    return {
        "id": row["id"], "status": state, "payment_status": row["payment_status"].upper(),
        "payment_method": row["payment_method"], "created_at": row["created_at"],
        "subtotal": row["subtotal_minor"] / 100, "delivery_fee": row["delivery_fee_minor"] / 100,
        "discount": row["discount_minor"] / 100, "total": row["total_minor"] / 100,
        "total_amount": row["total_minor"] / 100, "currency": "INR",
        "is_prelaunch_interest": False, "is_test_order": bool(row["is_test_order"]),
        "address": json.loads(row["address_snapshot"]),
        "items": [{"product_id": x["product_id"], "title": x["product_title"],
                   "quantity": x["quantity"], "unit_price": x["unit_price_minor"] / 100,
                   "line_total": x["total_minor"] / 100, "fulfillment_status": state} for x in lines],
        "carrier": carrier, "tracking_number": tracking, "timeline": timeline,
        "return_case": return_case,
    }


@commerce_router.get("/orders")
async def list_orders(request: Request):
    customer = await _require_auth(request)
    db = _env(request).DB
    rows = _d1_rows(await db.prepare("SELECT * FROM orders WHERE customer_id=? ORDER BY created_at DESC LIMIT 100").bind(customer["id"]).all())
    return {"success": True, "data": [await _order_data(db, row) for row in rows]}


@commerce_router.get("/orders/operations")
async def list_operations_orders(request: Request):
    await _require_auth(request, allowed_roles={"admin", "vendor", "super_admin"})
    db = _env(request).DB
    rows = _d1_rows(await db.prepare(
        "SELECT * FROM orders WHERE status != 'cancelled' ORDER BY created_at DESC LIMIT 100"
    ).all())
    return {"success": True, "data": [await _order_data(db, row) for row in rows]}

@commerce_router.get("/orders/{order_id}")
async def get_order_details(order_id: str, request: Request):
    customer = await _require_auth(request)
    db = _env(request).DB
    if customer.get("role") in ("admin", "vendor", "super_admin"):
        row = await db.prepare("SELECT * FROM orders WHERE id=?").bind(order_id).first()
    else:
        row = await db.prepare("SELECT * FROM orders WHERE id=? AND customer_id=?").bind(order_id, customer["id"]).first()
    if not row:
        raise HTTPException(404, "Order not found")
    return {"success": True, "data": await _order_data(db, row)}


@commerce_router.post("/orders/{order_id}/cancel")
async def cancel_order(order_id: str, request: Request) -> dict:
    customer = await _require_auth(request)
    db = _env(request).DB

    order_row = await db.prepare(
        "SELECT id, customer_id, status, payment_status, reservation_id FROM orders WHERE id = ?"
    ).bind(order_id).first()

    if not order_row:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Order not found")

    if order_row["customer_id"] != customer["id"] and customer.get("role") not in ("admin", "super_admin"):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Access denied")

    if order_row["status"] == "cancelled":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Order is already cancelled")

    if order_row["status"] not in ("placed", "confirmed"):
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            f"Cannot cancel order in '{order_row['status']}' status; only placed or confirmed orders can be cancelled",
        )
    if order_row["payment_status"] != "pending":
        raise HTTPException(status.HTTP_409_CONFLICT, "Payment must be reconciled before cancellation")

    # Fetch lines to restore inventory
    lines_rows = await db.prepare("SELECT product_id, quantity FROM order_lines WHERE order_id = ?").bind(order_id).all()
    statements = [
        db.prepare(
            "UPDATE orders SET status = 'cancelled' WHERE id = ?"
        ).bind(order_id)
    ]
    if order_row.get("reservation_id"):
        statements.append(
            db.prepare("UPDATE reservations SET status = 'CANCELLED' WHERE id = ?").bind(order_row["reservation_id"])
        )
    for l in _d1_rows(lines_rows):
        statements.append(
            db.prepare(
                "UPDATE inventory SET available_units = available_units + ?, updated_at = CURRENT_TIMESTAMP WHERE product_id = ?"
            ).bind(l["quantity"], l["product_id"])
        )
    statements.append(
        db.prepare(
            """INSERT INTO order_events (id, order_id, status, title, location, remarks)
               VALUES (?, ?, 'CANCELLED', 'Order Cancelled', '', 'Order cancelled and reserved stock restored.')"""
        ).bind(str(uuid.uuid4()), order_id)
    )

    try:
        await db.batch(statements)
    except Exception as exc:
        err_msg = str(exc)
        current = await db.prepare("SELECT status FROM orders WHERE id = ?").bind(order_id).first()
        current_st = current["status"] if current else "unknown"
        if current_st == "cancelled":
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Order is already cancelled") from exc
        if current_st not in ("placed", "confirmed"):
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                f"Cannot cancel order in '{current_st}' status; only placed or confirmed orders can be cancelled",
            ) from exc
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, f"Cancellation cleanup failed: {err_msg}") from exc

    return await get_order_details(order_id, request)


# -----------------------------------------------------------------------------
# Payment Capabilities & Link Routes
# -----------------------------------------------------------------------------

@commerce_router.post("/orders/{order_id}/payment-link")
async def checkout_payment_link(order_id: str, request: Request) -> dict:
    """Issue hosted payment link for online checkout."""
    customer = await _require_auth(request)
    db = _env(request).DB

    order = await db.prepare(
        "SELECT id, customer_id, status, payment_status, payment_method, total_minor FROM orders WHERE id = ?"
    ).bind(order_id).first()

    if not order:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Order not found")

    if order["customer_id"] != customer["id"] and customer.get("role") not in ("admin", "super_admin"):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Access denied")

    if order["status"] == "cancelled" or order["payment_method"] == "cod":
        raise HTTPException(status.HTTP_409_CONFLICT, "Online payment is unavailable for this order")

    if order["payment_status"] != "pending":
        raise HTTPException(status.HTTP_409_CONFLICT, "This order no longer needs payment")

    raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Online payment is unavailable on this API")


@commerce_router.get("/locations")
async def locations():
    from location_master import DATA
    return DATA


@commerce_router.get("/pincode/check")
async def check_pincode(pincode: str, request: Request):
    env = _env(request)
    row = await _delivery_policy(env.DB, pincode, env)
    if not row["is_serviceable"]:
        return {**row, "message": "Cash on delivery is not currently available for this pincode."}
    return {**row, "delivery_fee": row["delivery_fee_minor"] / 100,
            "expected_delivery_text": "Delivery availability is confirmed when your order is reviewed",
            "express_available": False}


@commerce_router.get("/pincode/lookup")
async def lookup_pincode(pincode: str, request: Request):
    row = await _env(request).DB.prepare("SELECT city,state FROM serviceable_pincodes WHERE pincode=?").bind(pincode).first()
    if not row:
        raise HTTPException(404, "PIN not in local coverage; enter location manually")
    city_lower = row["city"].lower()
    district = "Gautam Buddha Nagar" if "noida" in city_lower else ("New Delhi" if "delhi" in city_lower else row["city"])
    return {**row, "pincode": pincode, "district": district}


class DeliveryPolicyUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    cod_default_enabled: bool
    delivery_fee_minor: int = Field(ge=0, le=100000)
    prepaid_default_enabled: bool = False


class PincodeRuleInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    pincode: str = Field(pattern=r"^[1-8][0-9]{5}$")
    cod_enabled: bool | None = None
    prepaid_enabled: bool | None = None
    delivery_fee_minor: int | None = Field(default=None, ge=0, le=100000)
    city: str = Field(default="", max_length=128)
    state: str = Field(default="", max_length=128)


class PincodeRuleUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    cod_enabled: bool | None = None
    prepaid_enabled: bool | None = None
    delivery_fee_minor: int | None = Field(default=None, ge=0, le=100000)
    city: str | None = Field(default=None, max_length=128)
    state: str | None = Field(default=None, max_length=128)


@commerce_router.get("/admin/delivery-policy")
async def get_admin_delivery_policy(request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    db = _env(request).DB
    row = await db.prepare("SELECT * FROM delivery_policy WHERE id=1").first()
    if not row:
        raise HTTPException(503, "Delivery policy is unavailable")
    return {"success": True, "data": {**row, "cod_default_enabled": bool(row["cod_default_enabled"]),
            "prepaid_default_enabled": bool(row["prepaid_default_enabled"]),
            "online_payment_available": False}}


@commerce_router.put("/admin/delivery-policy")
async def update_admin_delivery_policy(data: DeliveryPolicyUpdate, request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    db = _env(request).DB
    await db.prepare("UPDATE delivery_policy SET cod_default_enabled=?, delivery_fee_minor=?, "
                     "prepaid_default_enabled=?, updated_at=CURRENT_TIMESTAMP WHERE id=1").bind(
        int(data.cod_default_enabled), data.delivery_fee_minor, int(data.prepaid_default_enabled)).run()
    return await get_admin_delivery_policy(request)


@commerce_router.get("/admin/pincodes")
async def list_admin_pincode_rules(request: Request, query: str = "", per_page: int = 100):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    if per_page < 1 or per_page > 500 or len(query) > 128:
        raise HTTPException(422, "Invalid search or page size")
    db = _env(request).DB
    rows = _d1_rows(await db.prepare(
        "SELECT * FROM delivery_pincode_rules WHERE pincode LIKE ? OR city LIKE ? OR state LIKE ? "
        "ORDER BY pincode LIMIT ?"
    ).bind(f"%{query.strip()}%", f"%{query.strip()}%", f"%{query.strip()}%", per_page).all())
    return {"success": True, "data": [{**r, "cod_enabled": r["cod_enabled"] is not None and bool(r["cod_enabled"]),
             "prepaid_enabled": r["prepaid_enabled"] is not None and bool(r["prepaid_enabled"])} for r in rows]}


@commerce_router.post("/admin/pincodes", status_code=201)
async def create_admin_pincode_rule(data: PincodeRuleInput, request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    if data.cod_enabled is None and data.prepaid_enabled is None and data.delivery_fee_minor is None:
        raise HTTPException(422, "At least one override is required")
    db = _env(request).DB
    if await db.prepare("SELECT pincode FROM delivery_pincode_rules WHERE pincode=?").bind(data.pincode).first():
        raise HTTPException(409, "PIN override already exists")
    await db.prepare(
        "INSERT INTO delivery_pincode_rules (pincode,cod_enabled,prepaid_enabled,delivery_fee_minor,city,state) "
        "VALUES (?,?,?,?,?,?)"
    ).bind(data.pincode, int(data.cod_enabled) if data.cod_enabled is not None else None,
           int(data.prepaid_enabled) if data.prepaid_enabled is not None else None,
           data.delivery_fee_minor, data.city.strip(), data.state.strip()).run()
    return {"success": True, "data": data.model_dump()}


@commerce_router.put("/admin/pincodes/{pincode}")
async def update_admin_pincode_rule(pincode: str, data: PincodeRuleUpdate, request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    if not _indian_pincode_format(pincode):
        raise HTTPException(422, "Invalid Indian PIN format")
    db = _env(request).DB
    row = await db.prepare("SELECT * FROM delivery_pincode_rules WHERE pincode=?").bind(pincode).first()
    if not row:
        raise HTTPException(404, "PIN override not found")
    values = data.model_dump(exclude_unset=True)
    merged = {k: values.get(k, row[k]) for k in
              ("cod_enabled", "prepaid_enabled", "delivery_fee_minor", "city", "state")}
    if all(merged[k] is None for k in ("cod_enabled", "prepaid_enabled", "delivery_fee_minor")):
        raise HTTPException(422, "At least one override is required")
    await db.prepare("UPDATE delivery_pincode_rules SET cod_enabled=?,prepaid_enabled=?,delivery_fee_minor=?,"
                     "city=?,state=?,updated_at=CURRENT_TIMESTAMP WHERE pincode=?").bind(
        int(merged["cod_enabled"]) if merged["cod_enabled"] is not None else None,
        int(merged["prepaid_enabled"]) if merged["prepaid_enabled"] is not None else None,
        merged["delivery_fee_minor"], merged["city"], merged["state"], pincode).run()
    return {"success": True, "data": {"pincode": pincode, **merged}}


@commerce_router.delete("/admin/pincodes/{pincode}")
async def delete_admin_pincode_rule(pincode: str, request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    db = _env(request).DB
    if not await db.prepare("SELECT pincode FROM delivery_pincode_rules WHERE pincode=?").bind(pincode).first():
        raise HTTPException(404, "PIN override not found")
    await db.prepare("DELETE FROM delivery_pincode_rules WHERE pincode=?").bind(pincode).run()
    return {"success": True}


@commerce_router.get("/coupons")
async def list_coupons(request: Request):
    await _require_auth(request)
    rows = await _env(request).DB.prepare("SELECT * FROM coupons WHERE is_active=1").all()
    return {"success": True, "data": [_coupon_view(row) for row in _d1_rows(rows)
            if not _coupon_expired(row.get("valid_until"))]}


@commerce_router.post("/coupons/quote")
async def quote_coupon(payload: CouponQuoteInput, request: Request):
    customer = await _require_auth(request)
    if not payload.code.strip():
        raise HTTPException(422, "Enter a promo code")
    db = _env(request).DB
    rows = await db.prepare(
        """SELECT c.quantity, i.price_minor, i.available_units, i.is_active
           FROM cart_items c JOIN inventory i ON i.product_id = c.product_id
           WHERE c.customer_id = ?"""
    ).bind(customer["id"]).all()
    items = _d1_rows(rows)
    if not items:
        raise HTTPException(422, "Cart is empty")
    if any(not item["is_active"] or item["quantity"] > item["available_units"] for item in items):
        raise HTTPException(422, "Review your cart before applying a coupon")
    subtotal = sum(item["quantity"] * item["price_minor"] for item in items) / 100.0
    code, discount = await _validate_coupon(db, payload.code, subtotal)
    coupon = await db.prepare("SELECT * FROM coupons WHERE code = ?").bind(code).first()
    return {"success": True, "data": {"coupon": _coupon_view(coupon),
            "subtotal": subtotal, "discount": discount,
            "total": round(subtotal - discount, 2)}}


# -----------------------------------------------------------------------------
# Seller Order Operations (Pack, Dispatch, Track, Deliver, COD Remittance)
# -----------------------------------------------------------------------------

class FulfillmentUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    status: Literal["PACKED", "SHIPPED", "DISPATCHED", "OUT_FOR_DELIVERY", "DELIVERED"]
    carrier: str = Field(default="", max_length=100)
    tracking_number: str = Field(default="", max_length=100)
    location: str = Field(default="", max_length=200)
    remarks: str = Field(default="", max_length=800)




VALID_FULFILLMENT_TRANSITIONS: dict[str, set[str]] = {
    "placed": {"packed"},
    "confirmed": {"packed"},
    "packed": {"shipped"},
    "shipped": {"out_for_delivery", "delivered"},
    "out_for_delivery": {"delivered"},
    "delivered": set(),
    "cancelled": set(),
}


@commerce_router.put("/orders/operations/{order_id}")
async def update_order_fulfillment(order_id: str, data: FulfillmentUpdate, request: Request):
    await _require_auth(request, allowed_roles={"admin", "vendor", "super_admin"})
    db = _env(request).DB
    order = await db.prepare("SELECT * FROM orders WHERE id=?").bind(order_id).first()
    if not order:
        raise HTTPException(404, "Order not found")

    current_status = order["status"].lower()
    if current_status == "cancelled":
        raise HTTPException(status.HTTP_409_CONFLICT, "Cannot fulfill a cancelled order")
    if current_status == "delivered":
        raise HTTPException(status.HTTP_409_CONFLICT, "Order is already delivered and cannot be modified")
    active_return = await db.prepare("SELECT id FROM order_return_cases WHERE order_id=? AND status!='rejected'").bind(order_id).first()
    if active_return:
        raise HTTPException(status.HTTP_409_CONFLICT, "Order has an active return or failed-delivery case")

    raw_target = data.status.upper()
    target_lower = "shipped" if raw_target in ("SHIPPED", "DISPATCHED") else raw_target.lower()

    valid_targets = VALID_FULFILLMENT_TRANSITIONS.get(current_status, set())
    if target_lower not in valid_targets:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            f"Cannot transition order from '{current_status}' to '{target_lower}'. Valid next states: {sorted(list(valid_targets)) or 'none'}",
        )

    now = datetime.now(timezone.utc).isoformat()
    carrier = data.carrier.strip() or order.get("carrier") or ""
    tracking = data.tracking_number.strip() or order.get("tracking_number") or ""
    location = data.location.strip()
    remarks = data.remarks.strip()

    event_title = ""
    event_remarks = remarks
    statements = []

    if target_lower == "packed":
        statements.append(
            db.prepare("UPDATE orders SET status='packed' WHERE id=?").bind(order_id)
        )
        event_title = "Order Packed"
        if not event_remarks:
            event_remarks = "Items carefully packed and sealed for transit."
        if not location:
            location = "Milterra Facility"
    elif target_lower == "shipped":
        if not carrier or not tracking:
            raise HTTPException(422, "Carrier and tracking number are required to dispatch")
        statements.append(
            db.prepare(
                "UPDATE orders SET status='shipped', carrier=?, tracking_number=?, dispatched_at=? WHERE id=?"
            ).bind(carrier, tracking, now, order_id)
        )
        event_title = f"Dispatched with {carrier}"
        if not event_remarks:
            event_remarks = f"Handed over to courier. AWB / Tracking: {tracking}"
        if not location:
            location = "Logistics Hub"
    elif target_lower == "out_for_delivery":
        statements.append(
            db.prepare("UPDATE orders SET status='out_for_delivery' WHERE id=?").bind(order_id)
        )
        event_title = "Out for Delivery"
        if not event_remarks:
            event_remarks = "Package is out for delivery with the courier agent."
    elif target_lower == "delivered":
        statements.append(
            db.prepare("UPDATE orders SET status='delivered', delivered_at=? WHERE id=?").bind(now, order_id)
        )
        event_title = "Delivered"
        if not event_remarks:
            event_remarks = "Package successfully delivered to customer."

    # Both status update and milestone event executed in ONE atomic batch
    statements.append(
        db.prepare(
            """INSERT INTO order_events (id, order_id, status, title, location, remarks)
               VALUES (?, ?, ?, ?, ?, ?)"""
        ).bind(str(uuid.uuid4()), order_id, raw_target, event_title, location, event_remarks)
    )

    try:
        await db.batch(statements)
    except Exception as exc:
        err_msg = str(exc)
        current = await db.prepare("SELECT status FROM orders WHERE id=?").bind(order_id).first()
        current_status = current["status"] if current else "unknown"
        if any(keyword in err_msg.lower() for keyword in ["cannot modify", "cannot pack", "cannot ship", "cannot mark out", "cannot deliver", "return or failed-delivery case"]):
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                f"Order status conflict: {err_msg} (current status: '{current_status}')",
            ) from exc
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, f"Fulfillment update failed: {err_msg}") from exc

    updated = await db.prepare("SELECT * FROM orders WHERE id=?").bind(order_id).first()
    return {"success": True, "data": await _order_data(db, updated)}


class CodSettlementRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    remittance_reference: str = Field(min_length=3, max_length=100)


@commerce_router.post("/orders/admin/cod/{order_id}/collect")
async def settle_cod_payment(order_id: str, data: CodSettlementRequest, request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    db = _env(request).DB
    ref = data.remittance_reference.strip()

    order = await db.prepare("SELECT * FROM orders WHERE id=?").bind(order_id).first()
    if not order:
        raise HTTPException(404, "Order not found")
    if order["payment_method"] != "cod":
        raise HTTPException(409, "A COD order is required for cash collection")
    if order["status"] != "delivered":
        raise HTTPException(409, "Record courier delivery before COD remittance")
    if await db.prepare("SELECT id FROM order_return_cases WHERE order_id=? AND status!='rejected'").bind(order_id).first():
        raise HTTPException(409, "Resolve the return case before recording COD remittance")

    # Idempotent match: already settled with this exact reference
    if order["payment_status"] == "paid":
        if order.get("remittance_reference") == ref:
            return {"success": True, "data": await _order_data(db, order)}
        raise HTTPException(409, "COD has already been settled with another reference")

    # Both payment_status update and remittance event MUST execute in one atomic batch
    statements = [
        db.prepare(
            """UPDATE orders SET payment_status='paid', remittance_reference=?
               WHERE id=?"""
        ).bind(ref, order_id),
        db.prepare(
            """INSERT INTO order_events (id, order_id, status, title, location, remarks)
               VALUES (?, ?, 'PAID', 'COD Remittance Recorded', '', ?)"""
        ).bind(str(uuid.uuid4()), order_id, f"Remittance reference: {ref}")
    ]

    try:
        await db.batch(statements)
    except Exception as exc:
        err_msg = str(exc)
        current = await db.prepare("SELECT id, status, payment_status, remittance_reference FROM orders WHERE id=?").bind(order_id).first()
        if not current:
            raise HTTPException(404, "Order not found") from exc
        if current["payment_status"] == "paid":
            if current.get("remittance_reference") == ref:
                return {"success": True, "data": await _order_data(db, current)}
            raise HTTPException(409, "COD has already been settled with another reference") from exc
        if current["status"] != "delivered":
            raise HTTPException(409, "Record courier delivery before COD remittance") from exc
        if "already paid" in err_msg.lower():
            raise HTTPException(409, "COD order is already paid") from exc
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, f"COD settlement failed: {err_msg}") from exc

    updated = await db.prepare("SELECT * FROM orders WHERE id=?").bind(order_id).first()
    return {"success": True, "data": await _order_data(db, updated)}


# -----------------------------------------------------------------------------
# Customer Support & Store Help
# -----------------------------------------------------------------------------

class SupportTicketInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    subject: str = Field(min_length=3, max_length=200)
    message: str = Field(min_length=10, max_length=4000)


class SupportTicketUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    status: Literal["OPEN", "IN_PROGRESS", "CLOSED"]
    reply: str = Field(min_length=1, max_length=4000)


@commerce_router.get("/help")
async def get_help(request: Request):
    db = _env(request).DB
    row = None
    try:
        row = await db.prepare("SELECT content FROM store_help WHERE key='help'").first()
    except Exception:
        pass
    if row and row.get("content"):
        try:
            return {"success": True, "data": json.loads(row["content"])}
        except Exception:
            pass
    return {
        "success": True,
        "data": {
            "contact_message": "For any questions about your orders, deliveries, or farm-direct products, submit an enquiry below or reach our team.",
            "faqs": [
                {"category": "Ordering", "question": "How does Cash on Delivery (COD) work?", "answer": "You can place your order online and pay the delivery courier in cash or via UPI QR when your package arrives at your doorstep."},
                {"category": "Delivery", "question": "Which locations do you currently deliver to?", "answer": "We currently deliver to serviceable pincodes across select partner regions. Use our pincode check during checkout to verify coverage for your address."},
                {"category": "Quality", "question": "How are Milterra dairy products packaged?", "answer": "All products are securely packed from our partner suppliers for safe transit to your location."},
                {"category": "Returns", "question": "What is your return and cancellation policy?", "answer": "Orders can be cancelled directly from your account page before dispatch. For questions or issues with a delivered order, contact our support team through the Help & Support section."},
            ],
        },
    }


@commerce_router.put("/admin/help")
async def update_help(request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    body = await request.json()
    db = _env(request).DB
    await db.prepare(
        "INSERT OR REPLACE INTO store_help (key, content) VALUES ('help', ?)"
    ).bind(json.dumps(body)).run()
    return {"success": True, "data": body}


@commerce_router.post("/support", status_code=201)
async def create_support_ticket(data: SupportTicketInput, request: Request):
    customer = await _require_auth(request)
    db = _env(request).DB
    ticket_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc).isoformat()
    await db.prepare(
        """INSERT INTO support_tickets (id, customer_id, subject, message, status, created_at, updated_at)
           VALUES (?, ?, ?, ?, 'OPEN', ?, ?)"""
    ).bind(ticket_id, customer["id"], data.subject.strip(), data.message.strip(), now, now).run()
    return {
        "success": True,
        "data": {
            "id": ticket_id,
            "subject": data.subject.strip(),
            "message": data.message.strip(),
            "status": "OPEN",
            "reply": None,
            "created_at": now,
        },
    }


@commerce_router.get("/support")
async def list_support_tickets(request: Request):
    customer = await _require_auth(request)
    db = _env(request).DB
    rows = _d1_rows(await db.prepare(
        "SELECT id, subject, message, status, reply, created_at FROM support_tickets WHERE customer_id=? ORDER BY created_at DESC LIMIT 100"
    ).bind(customer["id"]).all())
    return {"success": True, "data": rows}


@commerce_router.get("/admin/support")
async def list_admin_support_tickets(request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    db = _env(request).DB
    rows = _d1_rows(await db.prepare(
        """SELECT t.id, t.customer_id, t.subject, t.message, t.status, t.reply, t.created_at, c.phone AS customer_phone
           FROM support_tickets t JOIN customers c ON c.id = t.customer_id
           ORDER BY t.created_at DESC LIMIT 500"""
    ).all())
    return {"success": True, "data": rows}


@commerce_router.patch("/admin/support/{ticket_id}")
async def reply_support_ticket(ticket_id: str, data: SupportTicketUpdate, request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    db = _env(request).DB
    now = datetime.now(timezone.utc).isoformat()
    row = await db.prepare("SELECT * FROM support_tickets WHERE id=?").bind(ticket_id).first()
    if not row:
        raise HTTPException(404, "Support ticket not found")
    await db.prepare(
        "UPDATE support_tickets SET status=?, reply=?, updated_at=? WHERE id=?"
    ).bind(data.status, data.reply.strip(), now, ticket_id).run()
    return {
        "success": True,
        "data": {
            "id": ticket_id,
            "subject": row["subject"],
            "message": row["message"],
            "status": data.status,
            "reply": data.reply.strip(),
            "created_at": row["created_at"],
        },
    }


class ProfileUpdateInput(BaseModel):
    model_config = ConfigDict(extra="ignore")
    name: str | None = Field(default=None, max_length=128)
    village: str | None = Field(default="", max_length=128)
    district: str | None = Field(default="", max_length=128)
    state: str | None = Field(default="", max_length=128)
    language: str | None = Field(default="en", max_length=10)
    notify_health: bool = True
    notify_vaccination: bool = True
    notify_consultation: bool = True
    notify_payment: bool = True


@commerce_router.get("/profile")
async def get_profile(request: Request) -> dict:
    """Load authenticated customer profile details and communication preferences."""
    customer = await _require_auth(request)
    db = _env(request).DB
    customer_id = customer["id"]

    prof_row = await db.prepare(
        "SELECT village, district, state, language, notify_health, notify_vaccination, notify_consultation, notify_payment "
        "FROM customer_profiles WHERE customer_id = ?"
    ).bind(customer_id).first()

    return {
        "success": True,
        "data": {
            "id": customer_id,
            "name": customer.get("full_name") or "",
            "phone": customer.get("phone") or "",
            "village": prof_row["village"] if prof_row else "",
            "district": prof_row["district"] if prof_row else "",
            "state": prof_row["state"] if prof_row else "",
            "language": prof_row["language"] if prof_row else "en",
            "notify_health": bool(prof_row["notify_health"]) if prof_row else True,
            "notify_vaccination": bool(prof_row["notify_vaccination"]) if prof_row else True,
            "notify_consultation": bool(prof_row["notify_consultation"]) if prof_row else True,
            "notify_payment": bool(prof_row["notify_payment"]) if prof_row else True,
        },
    }


@commerce_router.put("/profile")
async def update_profile(payload: ProfileUpdateInput, request: Request) -> dict:
    """Update authenticated customer display name and profile preferences."""
    customer = await _require_auth(request)
    db = _env(request).DB
    customer_id = customer["id"]

    statements = []
    if payload.name is not None:
        statements.append(
            db.prepare("UPDATE customers SET full_name = ? WHERE id = ?").bind(payload.name.strip(), customer_id)
        )

    statements.append(
        db.prepare(
            """INSERT INTO customer_profiles (
                customer_id, village, district, state, language,
                notify_health, notify_vaccination, notify_consultation, notify_payment, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
            ON CONFLICT(customer_id) DO UPDATE SET
                village = excluded.village,
                district = excluded.district,
                state = excluded.state,
                language = excluded.language,
                notify_health = excluded.notify_health,
                notify_vaccination = excluded.notify_vaccination,
                notify_consultation = excluded.notify_consultation,
                notify_payment = excluded.notify_payment,
                updated_at = excluded.updated_at"""
        ).bind(
            customer_id,
            (payload.village or "").strip(),
            (payload.district or "").strip(),
            (payload.state or "").strip(),
            (payload.language or "en").strip(),
            1 if payload.notify_health else 0,
            1 if payload.notify_vaccination else 0,
            1 if payload.notify_consultation else 0,
            1 if payload.notify_payment else 0,
        )
    )

    await db.batch(statements)
    return {"success": True, "message": "Profile updated successfully"}


@commerce_router.get("/admin/commerce")
@commerce_router.get("/vendor/commerce")
async def get_admin_commerce_dashboard(request: Request):
    await _require_auth(request, allowed_roles={"admin", "vendor", "super_admin"})
    db = _env(request).DB

    coupons_rows = await db.prepare("SELECT * FROM coupons").all()
    coupons = [_coupon_view(row) for row in _d1_rows(coupons_rows)]
    sellers = _d1_rows(await db.prepare("SELECT * FROM commerce_sellers ORDER BY created_at").all())
    inventory = _d1_rows(await db.prepare("""SELECT i.*, p.mrp_minor FROM inventory i
        LEFT JOIN inventory_pricing p ON p.product_id=i.product_id ORDER BY i.title""").all())
    offers = [{"id": row["product_id"], "product_id": row["product_id"],
               "seller_id": "vendor-1", "seller_name": "Milterra", "seller_sku": row["product_id"],
               "mrp": (row["mrp_minor"] or row["price_minor"]) / 100,
               "selling_price": row["price_minor"] / 100,
               "available_stock": row["available_units"],
               "offer_status": "active" if row["is_active"] else "inactive"} for row in inventory]
    certificates = [_certificate_view(row) for row in _d1_rows(
        await db.prepare("SELECT b.*, i.title AS product_title FROM batch_certificates b JOIN inventory i ON i.product_id=b.product_id ORDER BY b.test_date DESC").all())]

    events_rows = await db.prepare("SELECT * FROM order_events ORDER BY created_at DESC LIMIT 100").all()
    audit_logs = [
        {
            "id": e["id"],
            "user_role": "system",
            "user_identifier": "system",
            "action": e.get("status", "update").lower(),
            "entity_type": "order",
            "entity_id": e.get("order_id", ""),
            "details": f"{e.get('title', '')} - {e.get('remarks', '')}".strip(" -"),
            "timestamp": e.get("created_at", datetime.now(timezone.utc).isoformat()),
        }
        for e in _d1_rows(events_rows)
    ]

    return {
        "success": True,
        "data": {
            "sellers": sellers,
            "offers": offers,
            "coupons": coupons,
            "batch_certificates": certificates,
            "audit_logs": audit_logs,
        },
    }


class CouponCreateInput(BaseModel):
    model_config = ConfigDict(extra="ignore")
    code: str = Field(min_length=2, max_length=50)
    description: str = Field(default="", max_length=500)
    discount_type: Literal["percentage", "flat"]
    discount_value: float = Field(ge=0)
    min_order_value: float = Field(default=0.0, ge=0)
    max_discount_cap: float | None = Field(default=None, ge=0)
    valid_until: datetime | None = Field(default=None)
    is_active: bool = Field(default=True)


class CouponUpdateInput(BaseModel):
    model_config = ConfigDict(extra="ignore")
    code: str | None = Field(default=None)
    description: str | None = Field(default=None)
    discount_type: Literal["percentage", "flat"] | None = Field(default=None)
    discount_value: float | None = Field(default=None, ge=0)
    min_order_value: float | None = Field(default=None, ge=0)
    max_discount_cap: float | None = Field(default=None, ge=0)
    valid_until: datetime | None = Field(default=None)
    is_active: bool | None = Field(default=None)


@commerce_router.post("/admin/commerce/coupons")
@commerce_router.post("/vendor/commerce/coupons")
async def create_coupon(data: CouponCreateInput, request: Request):
    await _require_auth(request, allowed_roles={"admin", "vendor", "super_admin"})
    _validate_coupon_value(data.discount_type, data.discount_value)
    db = _env(request).DB
    code = data.code.strip().upper()
    existing = await db.prepare("SELECT code FROM coupons WHERE code=?").bind(code).first()
    if existing:
        raise HTTPException(409, f"Coupon code '{code}' already exists")

    is_active = 1 if data.is_active else 0
    await db.prepare(
        """INSERT INTO coupons(code, description, discount_type, discount_value, min_order_value, max_discount_cap, is_active, valid_until)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)"""
    ).bind(code, data.description.strip(), data.discount_type, data.discount_value, data.min_order_value,
           data.max_discount_cap, is_active, data.valid_until.isoformat() if data.valid_until else None).run()

    return {"success": True, "message": f"Coupon {code} created successfully", "data": {"code": code, "id": code}}


@commerce_router.put("/admin/commerce/coupons/{coupon_id}")
@commerce_router.patch("/admin/commerce/coupons/{coupon_id}")
@commerce_router.put("/vendor/commerce/coupons/{coupon_id}")
@commerce_router.patch("/vendor/commerce/coupons/{coupon_id}")
async def update_coupon(coupon_id: str, data: CouponUpdateInput, request: Request):
    await _require_auth(request, allowed_roles={"admin", "vendor", "super_admin"})
    db = _env(request).DB
    coupon_id = coupon_id.strip().upper()
    row = await db.prepare("SELECT * FROM coupons WHERE code=?").bind(coupon_id).first()
    if not row:
        raise HTTPException(404, "Coupon not found")

    is_active = (1 if data.is_active else 0) if data.is_active is not None else row["is_active"]
    description = data.description.strip() if data.description is not None else row["description"]
    discount_type = data.discount_type if data.discount_type is not None else row["discount_type"]
    discount_value = data.discount_value if data.discount_value is not None else row["discount_value"]
    _validate_coupon_value(discount_type, discount_value)
    min_order_value = data.min_order_value if data.min_order_value is not None else row["min_order_value"]
    max_discount_cap = data.max_discount_cap if data.max_discount_cap is not None else row["max_discount_cap"]
    new_code = data.code.strip().upper() if data.code is not None else coupon_id
    if len(new_code) < 2 or len(new_code) > 50:
        raise HTTPException(422, "Coupon code must have 2 to 50 characters")
    if new_code != coupon_id and await db.prepare("SELECT code FROM coupons WHERE code=?").bind(new_code).first():
        raise HTTPException(409, "Coupon code already exists")
    valid_until = (data.valid_until.isoformat() if data.valid_until else None) if "valid_until" in data.model_fields_set else row["valid_until"]

    await db.prepare(
        """UPDATE coupons SET code=?, description=?, discount_type=?, discount_value=?, min_order_value=?, max_discount_cap=?, is_active=?, valid_until=?
        WHERE code=?"""
    ).bind(new_code, description, discount_type, discount_value, min_order_value, max_discount_cap, is_active, valid_until, coupon_id).run()

    return {"success": True, "message": f"Coupon {new_code} updated successfully"}


class SellerStatusUpdate(BaseModel):
    model_config = ConfigDict(extra="ignore")
    status: Literal["approved", "suspended", "rejected"]
    reason: str = Field(default="", max_length=500)


@commerce_router.patch("/admin/commerce/sellers/{seller_id}")
async def update_seller_status(seller_id: str, data: SellerStatusUpdate, request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    db = _env(request).DB
    row = await db.prepare("SELECT id FROM commerce_sellers WHERE id=?").bind(seller_id).first()
    if not row:
        raise HTTPException(404, "Seller not found")
    await db.prepare("UPDATE commerce_sellers SET status=? WHERE id=?").bind(data.status, seller_id).run()
    return {"success": True, "message": f"Seller {seller_id} status updated to {data.status}"}


class OfferUpdateInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    selling_price: float | None = None
    mrp: float | None = None
    available_stock: int | None = Field(default=None, ge=0)


@commerce_router.patch("/admin/commerce/offers/{offer_id}")
@commerce_router.patch("/vendor/commerce/offers/{offer_id}")
async def update_offer(offer_id: str, data: OfferUpdateInput, request: Request):
    await _require_auth(request, allowed_roles={"admin", "vendor", "super_admin"})
    if not any(value is not None for value in (data.selling_price, data.mrp, data.available_stock)):
        raise HTTPException(422, "Provide a price or available stock")
    db = _env(request).DB
    row = await db.prepare("""SELECT i.product_id, i.price_minor, p.mrp_minor, i.available_units
        FROM inventory i LEFT JOIN inventory_pricing p ON p.product_id=i.product_id
        WHERE i.product_id=?""").bind(offer_id).first()
    if not row:
        raise HTTPException(404, "Product not found")
    price_minor = _money_minor(data.selling_price, "Selling price") if data.selling_price is not None else row["price_minor"]
    mrp_minor = _money_minor(data.mrp, "MRP") if data.mrp is not None else row.get("mrp_minor")
    if mrp_minor is not None and mrp_minor < price_minor:
        raise HTTPException(422, "MRP cannot be below selling price")
    available = data.available_stock if data.available_stock is not None else row["available_units"]
    statements = [db.prepare("""UPDATE inventory SET price_minor=?, available_units=?, updated_at=CURRENT_TIMESTAMP
                        WHERE product_id=?""").bind(price_minor, available, offer_id)]
    if data.mrp is not None:
        statements.append(db.prepare("""INSERT INTO inventory_pricing(product_id,mrp_minor) VALUES(?,?)
            ON CONFLICT(product_id) DO UPDATE SET mrp_minor=excluded.mrp_minor""").bind(offer_id, mrp_minor))
    await db.batch(statements)
    return {"success": True, "data": {"id": offer_id, "selling_price": price_minor / 100,
            "mrp": mrp_minor / 100 if mrp_minor is not None else None, "available_stock": available}}


def _certificate_view(row: dict[str, Any]) -> dict[str, Any]:
    return {**row, "category": "", "test_parameters": json.loads(row["test_parameters"])}


class CertificateInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    product_id: str
    batch_number: str = Field(min_length=1, max_length=100)
    test_date: datetime
    laboratory: str = Field(min_length=1, max_length=200)
    fssai_license: str = Field(default="", max_length=100)
    purity_percent: float | None = Field(default=None, ge=0, le=100)
    test_parameters: dict[str, str] = Field(default_factory=dict)
    status: Literal["PENDING_REVIEW", "CERTIFIED", "REJECTED"] = "PENDING_REVIEW"
    certified_by: str = ""
    remarks: str = ""
    report_url: str | None = None


@commerce_router.post("/admin/commerce/certificates")
@commerce_router.put("/admin/commerce/certificates/{cert_id}")
@commerce_router.patch("/admin/commerce/certificates/{cert_id}")
async def save_certificate(request: Request, data: CertificateInput, cert_id: str | None = None):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    db = _env(request).DB
    product = await db.prepare("SELECT title FROM inventory WHERE product_id=?").bind(data.product_id).first()
    if not product:
        raise HTTPException(404, "Product not found")
    if cert_id:
        existing = await db.prepare("SELECT id FROM batch_certificates WHERE id=?").bind(cert_id).first()
        if not existing:
            raise HTTPException(404, "Certificate not found")
        await db.prepare("""UPDATE batch_certificates SET product_id=?, batch_number=?, test_date=?, laboratory=?,
            fssai_license=?, purity_percent=?, test_parameters=?, status=?, certified_by=?, remarks=?, report_url=? WHERE id=?""").bind(
            data.product_id, data.batch_number, data.test_date.isoformat(), data.laboratory, data.fssai_license,
            data.purity_percent, json.dumps(data.test_parameters), data.status, data.certified_by, data.remarks,
            data.report_url, cert_id).run()
    else:
        cert_id = str(uuid.uuid4())
        await db.prepare("""INSERT INTO batch_certificates(id, product_id, batch_number, test_date, laboratory,
            fssai_license, purity_percent, test_parameters, status, certified_by, remarks, report_url)
            VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""").bind(cert_id, data.product_id, data.batch_number,
            data.test_date.isoformat(), data.laboratory, data.fssai_license, data.purity_percent,
            json.dumps(data.test_parameters), data.status, data.certified_by, data.remarks, data.report_url).run()
    saved = await db.prepare("SELECT b.*, i.title AS product_title FROM batch_certificates b JOIN inventory i ON i.product_id=b.product_id WHERE b.id=?").bind(cert_id).first()
    return {"success": True, "data": _certificate_view(saved)}


@commerce_router.get("/vendor/products")
@commerce_router.get("/admin/products")
async def list_vendor_products(request: Request):
    await _require_auth(request, allowed_roles={"admin", "vendor", "super_admin"})
    db = _env(request).DB
    rows = await db.prepare("""SELECT i.*, p.mrp_minor, f.department, v.pack_size, v.publication_status
        FROM inventory i LEFT JOIN inventory_pricing p ON p.product_id=i.product_id
        LEFT JOIN product_family_variants v ON v.id=i.product_id
        LEFT JOIN product_families f ON f.id=v.family_id""").all()
    products = [
        {
            "id": r["product_id"],
            "product_id": r["product_id"],
            "vendor_id": "vendor-1",
            "title": r["title"],
            "category": r["department"] or "Uncategorized",
            "base_price": r["price_minor"] / 100.0,
            "price": r["price_minor"] / 100.0,
            "unit": "pack",
            "pack_size": r["pack_size"] or "",
            "description": r["title"],
            "available_quantity": r["available_units"],
            "available_units": r["available_units"],
            "min_order_quantity": 1,
            "in_stock": r["available_units"] > 0 and r["is_active"] == 1,
            "is_active": r["is_active"] == 1,
            "publication_status": r["publication_status"] or ("published" if r["is_active"] else "draft"),
            "media": [],
            "specifications": {},
            "taxonomy": None,
            "vendor": {
                "id": "vendor-1",
                "business_name": "Milterra Central Operations",
            },
        }
        for r in _d1_rows(rows)
    ]
    return {"success": True, "data": products}


@commerce_router.get("/vendor/families")
@commerce_router.get("/admin/families")
async def list_product_families(request: Request):
    await _require_auth(request, allowed_roles={"admin", "vendor", "super_admin"})
    db = _env(request).DB
    families = _d1_rows(await db.prepare("SELECT * FROM product_families ORDER BY created_at DESC").all())
    variants = _d1_rows(await db.prepare("""SELECT v.*, i.title, i.price_minor, i.available_units, i.is_active
        FROM product_family_variants v JOIN inventory i ON i.product_id=v.id""").all())
    by_family: dict[str, list[dict[str, Any]]] = {}
    for item in variants:
        by_family.setdefault(item["family_id"], []).append({"id": item["id"], "sku": item["sku"],
            "pack_size": item["pack_size"], "base_price": item["price_minor"] / 100,
            "compare_at_price": item["compare_at_price_minor"] / 100 if item["compare_at_price_minor"] is not None else None,
            "available_quantity": item["available_units"], "in_stock": bool(item["is_active"] and item["available_units"]),
            "publication_status": item["publication_status"]})
    return {"success": True, "data": [{"id": fam["id"], "title": fam["title"],
        "brand": fam["brand"], "department": fam["department"], "collection": fam["collection_name"],
        "description": fam["description"], "production_method": fam["production_method"],
        "vendor_id": fam["vendor_id"],
        "is_published": bool(fam["is_published"]), "is_concept": fam["status"] == "concept_preview",
        "variants": by_family.get(fam["id"], [])} for fam in families]}


class FamilyInput(BaseModel):
    model_config = ConfigDict(extra="ignore")
    title: str = Field(min_length=2, max_length=200)
    brand: str = Field(default="Milterra", max_length=100)
    department: str = Field(default="", max_length=100)
    collection: str | None = None
    description: str = ""
    status: Literal["concept_preview", "draft"] = "draft"
    is_concept: bool = False
    is_published: bool = False
    vendor_id: str = "vendor-1"
    production_method: str | None = None
    supporting_documents: dict[str, Any] = Field(default_factory=dict)


@commerce_router.post("/vendor/families")
async def create_product_family(data: FamilyInput, request: Request):
    await _require_auth(request, allowed_roles={"admin", "vendor", "super_admin"})
    if data.is_published:
        raise HTTPException(422, "New product families are drafts until the catalogue is published")
    db = _env(request).DB
    if not await db.prepare("SELECT id FROM commerce_sellers WHERE id=? AND status='approved'").bind(data.vendor_id).first():
        raise HTTPException(422, "Select the active Milterra seller")
    family_id = str(uuid.uuid4())
    await db.prepare("""INSERT INTO product_families(id,title,brand,department,collection_name,description,
        production_method,supporting_documents,status,vendor_id,is_published)
        VALUES(?,?,?,?,?,?,?,?,?,?,0)""").bind(family_id, data.title, data.brand, data.department,
        data.collection, data.description, data.production_method, json.dumps(data.supporting_documents),
        "concept_preview" if data.is_concept else data.status, data.vendor_id).run()
    return {"success": True, "data": {"id": family_id, "is_published": False}}


class FamilyVariantInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    sku: str = Field(min_length=1, max_length=100)
    pack_size: str = Field(min_length=1, max_length=100)
    base_price: float = Field(gt=0)
    compare_at_price: float | None = None
    initial_stock: int = Field(default=0, ge=0)
    publication_status: Literal["draft", "published"] = "draft"


@commerce_router.post("/vendor/families/{family_id}/variants")
async def create_family_variant(family_id: str, data: FamilyVariantInput, request: Request):
    await _require_auth(request, allowed_roles={"admin", "vendor", "super_admin"})
    if data.publication_status == "published":
        raise HTTPException(422, "New variants are drafts until the catalogue is published")
    db = _env(request).DB
    family = await db.prepare("SELECT title,is_published FROM product_families WHERE id=?").bind(family_id).first()
    if not family:
        raise HTTPException(404, "Product family not found")
    if family["is_published"]:
        raise HTTPException(409, "Publish the product catalogue before making a new variant sellable")
    price_minor = _money_minor(data.base_price, "Selling price")
    compare_minor = _money_minor(data.compare_at_price, "Compare price") if data.compare_at_price is not None else None
    if compare_minor is not None and compare_minor < price_minor:
        raise HTTPException(422, "Compare price cannot be below selling price")
    variant_id = str(uuid.uuid4())
    statements = [
        db.prepare("INSERT INTO inventory(product_id,title,available_units,price_minor,currency,is_active) VALUES(?,?,?,?, 'INR',0)").bind(
            variant_id, family["title"] + " " + data.pack_size, data.initial_stock, price_minor),
        db.prepare("INSERT INTO product_family_variants(id,family_id,sku,pack_size,compare_at_price_minor,publication_status) VALUES(?,?,?,?,?,'draft')").bind(
            variant_id, family_id, data.sku, data.pack_size, compare_minor),
    ]
    if compare_minor is not None:
        statements.append(db.prepare("INSERT INTO inventory_pricing(product_id,mrp_minor) VALUES(?,?)").bind(
            variant_id, compare_minor))
    await db.batch(statements)
    return {"success": True, "data": {"id": variant_id, "publication_status": "draft"}}


@commerce_router.get("/admin/marketplace/vendors")
async def list_marketplace_vendors(request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    rows = await _env(request).DB.prepare("SELECT * FROM commerce_sellers ORDER BY created_at").all()
    return {"success": True, "data": _d1_rows(rows)}


@commerce_router.post("/admin/marketplace/vendors")
async def create_marketplace_vendor(request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    raise HTTPException(409, "This storefront is configured for a single Milterra seller")


# -----------------------------------------------------------------------------
# Reviews Moderation Endpoints
# -----------------------------------------------------------------------------

@commerce_router.get("/admin/marketplace/reviews")
@commerce_router.get("/vendor/products/reviews")
@commerce_router.get("/marketplace/admin/marketplace/reviews")
@commerce_router.get("/marketplace/vendor/products/reviews")
async def list_reviews(request: Request):
    await _require_auth(request, allowed_roles={"admin", "vendor", "super_admin"})
    rows = await _env(request).DB.prepare("""SELECT r.*, c.full_name AS author_name, i.title AS product_title
        FROM product_reviews r JOIN customers c ON c.id=r.customer_id
        JOIN inventory i ON i.product_id=r.product_id ORDER BY r.created_at DESC LIMIT 100""").all()
    return {"success": True, "data": [_review_view(row) for row in _d1_rows(rows)]}


def _review_view(row: dict[str, Any]) -> dict[str, Any]:
    return {**row, "customer_name": row["author_name"], "review_text": row["content"],
            "comment": row["content"], "is_approved": row["status"] == "APPROVED",
            "is_verified": True, "reply": row["vendor_reply"]}


class ReviewInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    order_id: str
    rating: int = Field(ge=1, le=5)
    headline: str = Field(default="", max_length=150)
    content: str = Field(min_length=5, max_length=2000)


@commerce_router.post("/products/{product_id}/reviews", status_code=201)
async def create_review(product_id: str, data: ReviewInput, request: Request):
    customer = await _require_auth(request)
    db = _env(request).DB
    order = await db.prepare("""SELECT o.id FROM orders o JOIN order_lines l ON l.order_id=o.id
        WHERE o.id=? AND o.customer_id=? AND o.status='delivered' AND l.product_id=?""").bind(
        data.order_id, customer["id"], product_id).first()
    if not order:
        raise HTTPException(403, "Only a customer with a delivered order can review this product")
    review_id = str(uuid.uuid4())
    try:
        await db.prepare("""INSERT INTO product_reviews(id,customer_id,product_id,order_id,rating,headline,content)
            VALUES(?,?,?,?,?,?,?)""").bind(review_id, customer["id"], product_id, data.order_id,
            data.rating, data.headline, data.content).run()
    except Exception as exc:
        if "UNIQUE" in str(exc).upper():
            raise HTTPException(409, "This order already has a review for the product") from exc
        raise
    return {"success": True, "data": {"id": review_id, "status": "PENDING"}}


@commerce_router.get("/products/{product_id}/reviews")
async def list_public_reviews(product_id: str, request: Request):
    rows = await _env(request).DB.prepare("""SELECT r.*, c.full_name AS author_name, i.title AS product_title
        FROM product_reviews r JOIN customers c ON c.id=r.customer_id
        JOIN inventory i ON i.product_id=r.product_id WHERE r.product_id=? AND r.status='APPROVED'
        ORDER BY r.created_at DESC LIMIT 100""").bind(product_id).all()
    return {"success": True, "data": [_review_view(row) for row in _d1_rows(rows)]}


class ReviewStatusUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    status: Literal["APPROVED", "REJECTED", "PENDING"] | None = None
    is_approved: bool | None = None
    reason: str | None = None
    rejection_reason: str | None = None


@commerce_router.patch("/admin/marketplace/reviews/{review_id}/status")
@commerce_router.patch("/admin/marketplace/reviews/{review_id}")
@commerce_router.patch("/marketplace/admin/marketplace/reviews/{review_id}/status")
@commerce_router.patch("/marketplace/admin/marketplace/reviews/{review_id}")
@commerce_router.patch("/admin/marketplace/reviews/{review_id}/moderation")
async def update_review_status(review_id: str, data: ReviewStatusUpdate, request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    target = data.status or ("APPROVED" if data.is_approved else "REJECTED" if data.is_approved is False else None)
    if not target:
        raise HTTPException(422, "Review status is required")
    db = _env(request).DB
    if not await db.prepare("SELECT id FROM product_reviews WHERE id=?").bind(review_id).first():
        raise HTTPException(404, "Review not found")
    reason = data.rejection_reason or data.reason
    await db.prepare("UPDATE product_reviews SET status=?, rejection_reason=? WHERE id=?").bind(
        target, reason if target == "REJECTED" else None, review_id).run()
    return {"success": True, "message": f"Review {review_id} status updated to {target}"}


class ReviewReplyInput(BaseModel):
    model_config = ConfigDict(extra="ignore")
    reply: str = Field(min_length=1, max_length=1000)


@commerce_router.post("/vendor/products/reviews/{review_id}/reply")
@commerce_router.post("/admin/marketplace/reviews/{review_id}/reply")
@commerce_router.post("/marketplace/vendor/products/reviews/{review_id}/reply")
@commerce_router.post("/marketplace/admin/marketplace/reviews/{review_id}/reply")
async def reply_review(review_id: str, data: ReviewReplyInput, request: Request):
    await _require_auth(request, allowed_roles={"admin", "vendor", "super_admin"})
    db = _env(request).DB
    if not await db.prepare("SELECT id FROM product_reviews WHERE id=?").bind(review_id).first():
        raise HTTPException(404, "Review not found")
    await db.prepare("UPDATE product_reviews SET vendor_reply=? WHERE id=?").bind(data.reply, review_id).run()
    return {"success": True, "message": f"Reply added to review {review_id}"}


# -----------------------------------------------------------------------------
# Purchase Interests, Cancellations, Returns & Settlements
# -----------------------------------------------------------------------------

@commerce_router.get("/marketplace/orders/admin/interests")
@commerce_router.get("/orders/admin/interests")
@commerce_router.get("/admin/commerce/interests")
async def list_admin_purchase_interests(request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    return {"success": True, "data": []}


@commerce_router.patch("/marketplace/orders/admin/interests/{interest_id}")
@commerce_router.patch("/orders/admin/interests/{interest_id}")
async def update_admin_purchase_interest(interest_id: str, request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    raise HTTPException(501, "Pre-launch interest follow-up is not active in the live COD store")


@commerce_router.get("/marketplace/orders/admin/cancellations")
@commerce_router.get("/orders/admin/cancellations")
async def list_admin_cancellations(request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    rows = await _env(request).DB.prepare("""SELECT o.*, c.phone AS customer_phone FROM orders o
        JOIN customers c ON c.id=o.customer_id WHERE o.status='cancelled'
        ORDER BY o.created_at DESC LIMIT 100""").all()
    return {"success": True, "data": [{"id": row["id"], "status": "CANCELLED",
        "payment_status": row["payment_status"].upper(), "customer_phone": row["customer_phone"],
        "total": row["total_minor"] / 100, "created_at": row["created_at"],
        "refund_status": "NOT_REQUIRED" if row["payment_method"] == "cod" else "REVIEW_REQUIRED"}
        for row in _d1_rows(rows)]}


class ReturnReasonInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    reason: str = Field(min_length=5, max_length=300)
    remarks: str = Field(default="", max_length=800)


@commerce_router.post("/orders/{order_id}/return-request", status_code=201)
@commerce_router.post("/orders/{order_id}/return", status_code=201)
async def request_customer_return(order_id: str, data: ReturnReasonInput, request: Request):
    customer = await _require_auth(request)
    db = _env(request).DB
    order = await db.prepare("SELECT status FROM orders WHERE id=? AND customer_id=?").bind(order_id, customer["id"]).first()
    if not order:
        raise HTTPException(404, "Order not found")
    if order["status"] != "delivered":
        raise HTTPException(409, "Return requests are available after delivery")
    try:
        await db.prepare("INSERT INTO order_return_cases(id,order_id,kind,reason,remarks) VALUES(?,?,'customer_return',?,?)").bind(
            str(uuid.uuid4()), order_id, data.reason.strip(), data.remarks.strip()).run()
    except Exception as exc:
        if "UNIQUE" in str(exc).upper():
            raise HTTPException(409, "This order already has a return case") from exc
        raise
    return {"success": True, "message": "Return request received for review", "data": {"order_id": order_id, "return_status": "RETURN_REQUESTED"}}


@commerce_router.post("/orders/admin/returns/{order_id}/rto", status_code=201)
async def open_rto_case(order_id: str, data: ReturnReasonInput, request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    db = _env(request).DB
    order = await db.prepare("SELECT status FROM orders WHERE id=?").bind(order_id).first()
    if not order:
        raise HTTPException(404, "Order not found")
    if order["status"] not in ("shipped", "out_for_delivery"):
        raise HTTPException(409, "RTO can only be opened for an in-transit order")
    try:
        await db.batch([
            db.prepare("INSERT INTO order_return_cases(id,order_id,kind,reason,remarks) VALUES(?,?,'rto',?,?)").bind(
                str(uuid.uuid4()), order_id, data.reason.strip(), data.remarks.strip()),
            db.prepare("""INSERT INTO order_events(id,order_id,status,title,remarks)
                VALUES(?,?,'RTO_REQUESTED','Delivery failed; return to sender opened',?)""").bind(
                str(uuid.uuid4()), order_id, data.reason.strip()),
        ])
    except Exception as exc:
        if "UNIQUE" in str(exc).upper():
            raise HTTPException(409, "This order already has a return case") from exc
        raise
    return {"success": True, "data": {"order_id": order_id, "return_status": "RTO_REQUESTED"}}


@commerce_router.get("/marketplace/orders/admin/returns")
@commerce_router.get("/orders/admin/returns")
async def list_admin_returns(request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    rows = await _env(request).DB.prepare("""SELECT r.*, o.total_minor, o.payment_status,
        c.phone AS customer_phone FROM order_return_cases r JOIN orders o ON o.id=r.order_id
        JOIN customers c ON c.id=o.customer_id ORDER BY r.created_at DESC LIMIT 100""").all()
    return {"success": True, "data": [{"id": row["order_id"], "case_id": row["id"],
        "return_reason": row["reason"], "return_remarks": row["remarks"],
        "return_status": ("RTO_DELIVERED" if row["kind"] == "rto" else "RETURN_COMPLETED")
        if row["status"] == "received" else ("RETURN_REJECTED" if row["status"] == "rejected"
        else ("RTO_REQUESTED" if row["kind"] == "rto" else "RETURN_REQUESTED")),
        "payment_status": row["payment_status"].upper(), "customer_phone": row["customer_phone"],
        "total": row["total_minor"] / 100} for row in _d1_rows(rows)]}


class ReturnResolutionInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    action: Literal["confirm_received_refund", "confirm_received", "reject"]
    refund_reference: str = Field(default="", max_length=100)
    remarks: str = Field(default="", max_length=800)
    restock_inventory: bool = True


@commerce_router.post("/marketplace/orders/admin/returns/{order_id}/process")
@commerce_router.post("/orders/admin/returns/{order_id}/process")
async def process_return_case(order_id: str, data: ReturnResolutionInput, request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    db = _env(request).DB
    row = await db.prepare("""SELECT r.*, o.payment_status, o.payment_method, o.reservation_id
        FROM order_return_cases r JOIN orders o ON o.id=r.order_id WHERE r.order_id=?""").bind(order_id).first()
    if not row:
        raise HTTPException(404, "Return case not found")
    if row["status"] != "requested":
        raise HTTPException(409, "Return case has already been resolved")
    if data.action == "reject" and not data.remarks.strip():
        raise HTTPException(422, "A rejection explanation is required")
    receiving = data.action != "reject"
    if receiving and row["payment_status"] == "paid":
        if row["payment_method"] != "cod":
            raise HTTPException(409, "Online refunds require payment-provider verification")
        if len(data.refund_reference.strip()) < 3:
            raise HTTPException(422, "Enter the completed COD refund reference")
    statements = [db.prepare("""UPDATE order_return_cases SET status=?, remarks=?, refund_reference=?,
        restocked=?, resolved_at=CURRENT_TIMESTAMP WHERE id=?""").bind(
        "received" if receiving else "rejected", data.remarks.strip(),
        data.refund_reference.strip() or None, int(receiving and data.restock_inventory), row["id"])]
    if receiving and data.restock_inventory:
        lines = _d1_rows(await db.prepare("SELECT product_id,quantity FROM order_lines WHERE order_id=?").bind(order_id).all())
        for line in lines:
            statements.append(db.prepare("UPDATE inventory SET available_units=available_units+?,updated_at=CURRENT_TIMESTAMP WHERE product_id=?").bind(
                line["quantity"], line["product_id"]))
        if row["reservation_id"]:
            statements.append(db.prepare("UPDATE reservations SET status='CANCELLED' WHERE id=?").bind(row["reservation_id"]))
    if receiving and row["payment_status"] == "paid":
        statements.append(db.prepare("UPDATE orders SET payment_status='refunded' WHERE id=?").bind(order_id))
    statements.append(db.prepare("""INSERT INTO order_events(id,order_id,status,title,remarks)
        VALUES(?,?,?,?,?)""").bind(str(uuid.uuid4()), order_id,
        "RETURN_RECEIVED" if receiving else "RETURN_REJECTED",
        "Return received and closed" if receiving else "Return request rejected", data.remarks.strip()))
    try:
        await db.batch(statements)
    except Exception as exc:
        if "return case already finalized" in str(exc).lower():
            raise HTTPException(409, "Return case has already been resolved") from exc
        raise
    return {"success": True, "data": {"order_id": order_id,
        "return_status": "RETURN_COMPLETED" if receiving else "RETURN_REJECTED"}}


@commerce_router.get("/admin/commerce/vendors/settlements")
@commerce_router.get("/marketplace/admin/commerce/vendors/settlements")
async def list_vendor_settlements(request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    return {"success": True, "data": []}


@commerce_router.get("/admin/marketplace/concept-feedback")
@commerce_router.get("/marketplace/admin/marketplace/concept-feedback")
async def list_concept_feedback(request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    return {"success": True, "data": []}


# -----------------------------------------------------------------------------
# Financial Reports & Carts Analytics
# -----------------------------------------------------------------------------

@commerce_router.get("/admin/commerce/reports/gstr1")
@commerce_router.get("/marketplace/admin/commerce/reports/gstr1")
async def get_gstr1_report(request: Request, format: str = "json"):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    raise HTTPException(501, "Tax reporting is not configured; export verified invoices from your accounting system")


@commerce_router.get("/admin/commerce/reports/settlements")
@commerce_router.get("/marketplace/admin/commerce/reports/settlements")
async def get_settlements_report(request: Request, format: str = "json"):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    raise HTTPException(501, "Vendor settlements do not apply to this single-seller store")


@commerce_router.get("/admin/ecommerce/carts")
@commerce_router.get("/marketplace/admin/ecommerce/carts")
async def list_admin_carts(request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    rows = await _env(request).DB.prepare("""SELECT c.customer_id, u.phone AS customer_phone,
        SUM(c.quantity) AS item_count, MAX(c.updated_at) AS updated_at
        FROM cart_items c JOIN customers u ON u.id=c.customer_id
        GROUP BY c.customer_id ORDER BY updated_at DESC LIMIT 100""").all()
    return {"success": True, "data": _d1_rows(rows)}


@commerce_router.get("/admin/ecommerce/analytics/traffic")
@commerce_router.get("/marketplace/admin/ecommerce/analytics/traffic")
async def get_admin_traffic_analytics(request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    return {"success": True, "data": {"available": False,
            "reason": "Visitor and page-view tracking is not configured"}}


@commerce_router.post("/admin/ecommerce/carts/{cart_id}/nudge")
@commerce_router.post("/marketplace/admin/ecommerce/carts/{cart_id}/nudge")
async def nudge_abandoned_cart(cart_id: str, request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    raise HTTPException(501, "Customer messaging is not configured; no notification was sent")


# -----------------------------------------------------------------------------
# Admin Dashboard & Operations
# -----------------------------------------------------------------------------

@commerce_router.get("/marketplace/certificates")
@commerce_router.get("/certificates")
async def list_certificates(request: Request):
    rows = await _env(request).DB.prepare("""SELECT b.*, i.title AS product_title FROM batch_certificates b
        JOIN inventory i ON i.product_id=b.product_id WHERE b.status='CERTIFIED'
        ORDER BY b.test_date DESC""").all()
    return {"success": True, "data": [_certificate_view(row) for row in _d1_rows(rows)]}


@commerce_router.get("/admin/dashboard")
@commerce_router.get("/marketplace/admin/dashboard")
async def get_admin_dashboard(request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    db = _env(request).DB
    customers = await db.prepare("SELECT COUNT(*) AS n FROM customers WHERE role IN ('farmer','customer')").first()
    orders = await db.prepare("""SELECT COUNT(*) AS n,
        COALESCE(SUM(CASE WHEN payment_status='paid' THEN total_minor ELSE 0 END),0) AS revenue_minor
        FROM orders WHERE status!='cancelled'""").first()
    return {
        "success": True,
        "data": {
            "total_farmers": customers["n"],
            "total_vets": 0,
            "total_orders": orders["n"],
            "total_revenue": orders["revenue_minor"] / 100,
        },
    }


@commerce_router.get("/admin/farmers")
@commerce_router.get("/marketplace/admin/farmers")
async def list_admin_farmers(request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    db = _env(request).DB
    rows = _d1_rows(await db.prepare("SELECT id, phone, full_name, is_active, created_at FROM customers WHERE role='farmer' OR role='customer' LIMIT 100").all())
    return {"success": True, "data": rows}


@commerce_router.get("/admin/vets")
@commerce_router.get("/marketplace/admin/vets")
async def list_admin_vets(request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    return {"success": True, "data": []}


@commerce_router.post("/vet-profiles/verify")
@commerce_router.post("/marketplace/vet-profiles/verify")
async def verify_vet_profile(request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    return {"success": True, "message": "Vet profile verified successfully"}


@commerce_router.get("/admin/consultations")
@commerce_router.get("/marketplace/admin/consultations")
async def list_admin_consultations(request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    return {"success": True, "data": []}


@commerce_router.get("/admin/analytics")
@commerce_router.get("/marketplace/admin/analytics")
async def get_admin_analytics(request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    db = _env(request).DB
    customers = await db.prepare("SELECT COUNT(*) AS n FROM customers WHERE role IN ('farmer','customer')").first()
    orders = await db.prepare("""SELECT COUNT(*) AS n,
        COALESCE(SUM(CASE WHEN payment_status='paid' THEN total_minor ELSE 0 END),0) AS revenue_minor
        FROM orders WHERE status!='cancelled' AND strftime('%Y-%m',created_at)=strftime('%Y-%m','now')""").first()
    return {
        "success": True,
        "data": {
            "active_users": 0,
            "registered_customers": customers["n"],
            "visitor_tracking_available": False,
            "monthly_orders": orders["n"],
            "revenue_inr": orders["revenue_minor"] / 100,
        },
    }
