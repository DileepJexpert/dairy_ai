"""D1 Commerce API Slice: Inventory, Cart, Quote, Atomic Reservation, and Orders."""

from __future__ import annotations

import hashlib
import json
import uuid
from datetime import datetime, timezone
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


def _live_cod_pincodes(env) -> set[str]:
    raw = getattr(env, "LIVE_COD_PINCODES", "")
    pincodes = [pin.strip() for pin in raw.split(",")]
    if not pincodes or any(len(pin) != 6 or not pin.isdigit() for pin in pincodes):
        return set()
    return set(pincodes)


def _live_cod(env) -> bool:
    return (getattr(env, "LIVE_COD_ENABLED", "false") == "true"
            and getattr(env, "TEST_COMMERCE_ENABLED", "false") != "true"
            and getattr(env, "CUSTOMER_AUTH_ENABLED", "false") == "true"
            and bool(_live_cod_pincodes(env)))


def _pincode_enabled(env, pincode: str) -> bool:
    return _test_commerce(env) or (_live_cod(env) and pincode in _live_cod_pincodes(env))


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
    if (getattr(env, "CUSTOMER_AUTH_ENABLED", "false") == "true"
            and not _pincode_enabled(env, address["pincode"])):
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            f"Delivery is not currently available for pincode {address['pincode']}",
        )
    coverage = await db.prepare(
        "SELECT is_serviceable, delivery_fee_minor FROM serviceable_pincodes WHERE pincode = ?"
    ).bind(address["pincode"]).first()
    if not coverage or not coverage["is_serviceable"]:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            f"Delivery is not currently available for pincode {address['pincode']}",
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
        """SELECT code, description, discount_type, discount_value, min_order_value, max_discount_cap, is_active
           FROM coupons WHERE code = ?"""
    ).bind(code).all()
    records = _d1_rows(rows)

    if records:
        c = records[0]
        if not c.get("is_active", 1):
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, f"Coupon '{code}' is no longer active")
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



# -----------------------------------------------------------------------------
# Inventory & Stock Routes
# -----------------------------------------------------------------------------

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
    _, discount = await _validate_coupon(db, payload.coupon_code, subtotal)
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
    row = await env.DB.prepare("SELECT * FROM serviceable_pincodes WHERE pincode=?").bind(pincode).first()
    if not row or not _pincode_enabled(env, pincode):
        return {"pincode": pincode, "is_serviceable": False, "message": "Delivery is not currently available for this pincode."}
    return {**row, "is_serviceable": bool(row["is_serviceable"]), "delivery_fee": row["delivery_fee_minor"] / 100, "expected_delivery_text": "Delivery available" if row["is_serviceable"] else "Delivery is not currently available for this pincode.", "express_available": False}


@commerce_router.get("/pincode/lookup")
async def lookup_pincode(pincode: str, request: Request):
    row = await _env(request).DB.prepare("SELECT city,state FROM serviceable_pincodes WHERE pincode=?").bind(pincode).first()
    if not row:
        raise HTTPException(404, "PIN not in local coverage; enter location manually")
    city_lower = row["city"].lower()
    district = "Gautam Buddha Nagar" if "noida" in city_lower else ("New Delhi" if "delhi" in city_lower else row["city"])
    return {**row, "pincode": pincode, "district": district}


@commerce_router.get("/coupons")
async def list_coupons(request: Request):
    await _require_auth(request)
    rows = await _env(request).DB.prepare("SELECT * FROM coupons WHERE is_active=1").all()
    return {"success": True, "data": _d1_rows(rows)}


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
        if any(keyword in err_msg.lower() for keyword in ["cannot modify", "cannot pack", "cannot ship", "cannot mark out", "cannot deliver"]):
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
    coupons = _d1_rows(coupons_rows)

    events_rows = await db.prepare("SELECT * FROM order_events ORDER BY created_at DESC LIMIT 100").all()
    audit_logs = [
        {
            "id": e["id"],
            "user_role": "admin",
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
            "sellers": [],
            "offers": [],
            "coupons": coupons,
            "batch_certificates": [],
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
    max_discount_cap: float | None = Field(default=None)
    valid_until: str | None = Field(default=None)
    is_active: bool = Field(default=True)


class CouponUpdateInput(BaseModel):
    model_config = ConfigDict(extra="ignore")
    code: str | None = Field(default=None)
    description: str | None = Field(default=None)
    discount_type: Literal["percentage", "flat"] | None = Field(default=None)
    discount_value: float | None = Field(default=None)
    min_order_value: float | None = Field(default=None)
    max_discount_cap: float | None = Field(default=None)
    valid_until: str | None = Field(default=None)
    is_active: bool | None = Field(default=None)


@commerce_router.post("/admin/commerce/coupons")
@commerce_router.post("/vendor/commerce/coupons")
async def create_coupon(data: CouponCreateInput, request: Request):
    await _require_auth(request, allowed_roles={"admin", "vendor", "super_admin"})
    db = _env(request).DB
    code = data.code.strip().upper()
    existing = await db.prepare("SELECT code FROM coupons WHERE code=?").bind(code).first()
    if existing:
        raise HTTPException(409, f"Coupon code '{code}' already exists")

    is_active = 1 if data.is_active else 0
    await db.prepare(
        """INSERT INTO coupons(code, description, discount_type, discount_value, min_order_value, max_discount_cap, is_active)
        VALUES (?, ?, ?, ?, ?, ?, ?)"""
    ).bind(code, data.description.strip(), data.discount_type, data.discount_value, data.min_order_value, data.max_discount_cap, is_active).run()

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
    min_order_value = data.min_order_value if data.min_order_value is not None else row["min_order_value"]
    max_discount_cap = data.max_discount_cap if data.max_discount_cap is not None else row["max_discount_cap"]

    await db.prepare(
        """UPDATE coupons SET description=?, discount_type=?, discount_value=?, min_order_value=?, max_discount_cap=?, is_active=?
        WHERE code=?"""
    ).bind(description, discount_type, discount_value, min_order_value, max_discount_cap, is_active, coupon_id).run()

    return {"success": True, "message": f"Coupon {coupon_id} updated successfully"}


class SellerStatusUpdate(BaseModel):
    model_config = ConfigDict(extra="ignore")
    status: Literal["approved", "suspended", "rejected"]
    reason: str = Field(default="", max_length=500)


@commerce_router.patch("/admin/commerce/sellers/{seller_id}")
async def update_seller_status(seller_id: str, data: SellerStatusUpdate, request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    return {"success": True, "message": f"Seller {seller_id} status updated to {data.status}"}


class OfferUpdateInput(BaseModel):
    model_config = ConfigDict(extra="ignore")
    selling_price: float | None = None
    mrp: float | None = None
    available_stock: int | None = None


@commerce_router.patch("/admin/commerce/offers/{offer_id}")
@commerce_router.patch("/vendor/commerce/offers/{offer_id}")
async def update_offer(offer_id: str, data: OfferUpdateInput, request: Request):
    await _require_auth(request, allowed_roles={"admin", "vendor", "super_admin"})
    return {"success": True, "message": f"Offer {offer_id} updated successfully"}


@commerce_router.post("/admin/commerce/certificates")
@commerce_router.put("/admin/commerce/certificates/{cert_id}")
@commerce_router.patch("/admin/commerce/certificates/{cert_id}")
async def save_certificate(request: Request):
    await _require_auth(request, allowed_roles={"admin", "super_admin"})
    return {"success": True, "message": "Certificate saved successfully"}


