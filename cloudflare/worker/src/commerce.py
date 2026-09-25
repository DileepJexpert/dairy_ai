"""D1 Commerce API Slice: Inventory, Cart, Quote, Atomic Reservation, and Orders."""

from __future__ import annotations

import hashlib
import json
import uuid
from typing import Any, Iterable

import jwt
from fastapi import APIRouter, HTTPException, Request, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field


commerce_router = APIRouter(prefix="/api/v1/marketplace", tags=["commerce"])


def _env(request: Request) -> Any:
    scope = getattr(request, "scope", {})
    return scope.get("env") or getattr(request.app.state, "env", None)


def _d1_rows(result: Any) -> list[dict[str, Any]]:
    if result is None:
        return []
    rows = getattr(result, "results", result)
    return rows.to_py() if hasattr(rows, "to_py") else list(rows)


def _require_auth(request: Request) -> dict[str, Any]:
    """Verify JWT access token from Authorization header.
    
    Test header x-test-customer-id is strictly permitted only when
    ALLOW_TEST_AUTH is True AND ENVIRONMENT is 'test'.
    """
    env = _env(request)
    
    # 1. Check if explicit test environment permits test-bypass header
    is_test_env = getattr(env, "ENVIRONMENT", "") == "test"
    allow_test_auth = getattr(env, "ALLOW_TEST_AUTH", False) is True
    if is_test_env and allow_test_auth:
        test_user_id = request.headers.get("x-test-customer-id")
        if test_user_id:
            return {"id": test_user_id, "role": "farmer", "phone": "+919999900000"}

    # 2. In all non-test environments or when no test header is provided, require valid JWT
    authorization = request.headers.get("authorization", "")
    secret = getattr(env, "COMPAT_JWT_SECRET", None) or getattr(env, "JWT_SECRET", None)
    if not secret:
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "Authentication service is improperly configured (missing JWT secret)",
        )

    if not authorization.startswith("Bearer "):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Authentication required")

    token = authorization[7:].strip()
    try:
        payload = jwt.decode(token, secret, algorithms=["HS256"])
        customer_id = str(payload.get("sub", ""))
        if not customer_id:
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token missing customer ID")
        return {
            "id": customer_id,
            "role": str(payload.get("role", "farmer")),
            "phone": str(payload.get("phone", "")),
        }
    except jwt.InvalidTokenError as exc:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid access token") from exc


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
    recipient_name: str = Field(min_length=1, max_length=128)
    phone: str = Field(min_length=8, max_length=20)
    address_line1: str = Field(min_length=1, max_length=256)
    address_line2: str | None = None
    city: str = Field(min_length=1, max_length=128)
    state: str = Field(min_length=1, max_length=128)
    pincode: str = Field(min_length=6, max_length=6)
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


async def _validate_coupon(db: Any, coupon_code: str | None, subtotal: float) -> tuple[str | None, float]:
    if not coupon_code or not coupon_code.strip():
        return None, 0.0

    code = coupon_code.strip().upper()
    try:
        rows = await db.prepare(
            """SELECT code, description, discount_type, discount_value, min_order_value, max_discount_cap, is_active
               FROM coupons WHERE code = ?"""
        ).bind(code).all()
        records = _d1_rows(rows)
    except Exception:
        records = []

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

    # Fallback for default known coupons if coupons table hasn't been migrated or populated yet
    if code == "MILTERRA10":
        if subtotal < 499.0:
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Minimum order value for coupon 'MILTERRA10' is ₹499")
        disc = min((subtotal * 10.0) / 100.0, 250.0)
        return code, round(disc, 2)
    elif code == "FARMER50":
        if subtotal < 299.0:
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Minimum order value for coupon 'FARMER50' is ₹299")
        disc = min(subtotal, 50.0)
        return code, round(disc, 2)
    else:
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
    customer = _require_auth(request)
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
            "line_total": line_total,
            "in_stock": r["available_units"] >= r["quantity"],
            "available_quantity": r["available_units"],
        })
    
    return {
        "success": True,
        "data": {
            "items": items,
            "item_count": total_count,
            "subtotal": subtotal_minor / 100.0,
        },
    }


@commerce_router.post("/cart/items", status_code=status.HTTP_201_CREATED)
async def add_cart_item(payload: CartItemInput, request: Request) -> dict:
    customer = _require_auth(request)
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
    customer = _require_auth(request)
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
    customer = _require_auth(request)
    db = _env(request).DB
    await db.prepare("DELETE FROM cart_items WHERE (id = ? OR product_id = ?) AND customer_id = ?").bind(item_id, item_id, customer["id"]).run()
    return {"success": True, "data": {}, "message": "Item removed"}


@commerce_router.delete("/cart")
async def clear_cart(request: Request) -> dict:
    customer = _require_auth(request)
    db = _env(request).DB
    await db.prepare("DELETE FROM cart_items WHERE customer_id = ?").bind(customer["id"]).run()
    return {"success": True, "data": {}, "message": "Cart cleared"}


# -----------------------------------------------------------------------------
# Customer Delivery Addresses Routes
# -----------------------------------------------------------------------------

@commerce_router.get("/addresses")
async def get_addresses(request: Request) -> dict:
    customer = _require_auth(request)
    db = _env(request).DB
    rows = await db.prepare(
        """SELECT id, customer_id, recipient_name, phone, address_line1, address_line2,
                  city, state, pincode, is_default, created_at
           FROM customer_addresses WHERE customer_id = ? ORDER BY is_default DESC, created_at DESC"""
    ).bind(customer["id"]).all()
    records = _d1_rows(rows)
    out = []
    for r in records:
        out.append({
            "id": r["id"],
            "recipient_name": r["recipient_name"],
            "phone": r["phone"],
            "address_line1": r["address_line1"],
            "address_line2": r["address_line2"],
            "city": r["city"],
            "state": r["state"],
            "pincode": r["pincode"],
            "postal_code": r["pincode"],
            "is_default": bool(r["is_default"]),
        })
    return {"success": True, "data": out}


@commerce_router.post("/addresses", status_code=status.HTTP_201_CREATED)
async def create_address(payload: AddressInput, request: Request) -> dict:
    customer = _require_auth(request)
    db = _env(request).DB

    pincode = payload.pincode.strip()
    if len(pincode) != 6 or not pincode.isdigit():
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Invalid pincode; must be 6 digits")

    # Ensure customer row exists
    await db.prepare(
        "INSERT OR IGNORE INTO customers (id, phone, role) VALUES (?, ?, ?)"
    ).bind(customer["id"], customer.get("phone", "+919999900000"), customer.get("role", "farmer")).run()

    addr_id = str(uuid.uuid4())
    if payload.is_default:
        await db.prepare("UPDATE customer_addresses SET is_default = 0 WHERE customer_id = ?").bind(customer["id"]).run()

    await db.prepare(
        """INSERT INTO customer_addresses (id, customer_id, recipient_name, phone, address_line1,
                                           address_line2, city, state, pincode, is_default)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"""
    ).bind(
        addr_id,
        customer["id"],
        payload.recipient_name,
        payload.phone,
        payload.address_line1,
        payload.address_line2,
        payload.city,
        payload.state,
        pincode,
        1 if payload.is_default else 0,
    ).run()

    return {
        "success": True,
        "data": {
            "id": addr_id,
            "recipient_name": payload.recipient_name,
            "phone": payload.phone,
            "address_line1": payload.address_line1,
            "address_line2": payload.address_line2,
            "city": payload.city,
            "state": payload.state,
            "pincode": pincode,
            "postal_code": pincode,
            "is_default": payload.is_default,
        },
        "message": "Address created",
    }


@commerce_router.put("/addresses/{address_id}")
async def update_address(address_id: str, payload: dict[str, Any], request: Request) -> dict:
    customer = _require_auth(request)
    db = _env(request).DB

    existing = await db.prepare("SELECT id FROM customer_addresses WHERE id = ? AND customer_id = ?").bind(address_id, customer["id"]).first()
    if not existing:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Address not found")

    if payload.get("is_default") is True:
        await db.prepare("UPDATE customer_addresses SET is_default = 0 WHERE customer_id = ?").bind(customer["id"]).run()
        await db.prepare("UPDATE customer_addresses SET is_default = 1 WHERE id = ?").bind(address_id).run()

    return {"success": True, "message": "Address updated"}


@commerce_router.delete("/addresses/{address_id}")
async def delete_address(address_id: str, request: Request) -> dict:
    customer = _require_auth(request)
    db = _env(request).DB
    await db.prepare("DELETE FROM customer_addresses WHERE id = ? AND customer_id = ?").bind(address_id, customer["id"]).run()
    return {"success": True, "data": {}, "message": "Address deleted"}


# -----------------------------------------------------------------------------
# Checkout Quote Route
# -----------------------------------------------------------------------------

@commerce_router.post("/orders/checkout/quote")
@commerce_router.post("/checkout/quote")
async def checkout_quote(payload: CheckoutQuoteInput, request: Request) -> dict:
    """Calculate authoritative checkout quote against live D1 inventory, delivery rules & coupons."""
    customer = _require_auth(request)
    db = _env(request).DB

    # 1. Verify address ownership and pincode if delivery_address_id is provided
    if payload.delivery_address_id:
        await _verify_address(db, customer["id"], payload.delivery_address_id)

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

    # Standard Milterra delivery rule: free delivery over ₹500, else ₹50
    subtotal = subtotal_minor / 100.0
    delivery_fee = 0.0 if subtotal >= 500.0 else 50.0

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
    customer = _require_auth(request)
    db = _env(request).DB
    customer_id = customer["id"]

    # 1. Verify delivery address ownership and 6-digit pincode
    await _verify_address(db, customer_id, payload.delivery_address_id)

    # 2. Compute request fingerprint and check for existing order (Idempotent replay guard)
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
        # Idempotent replay: return existing order without decrementing stock again
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "success": True,
                "data": {
                    "id": existing_order_row["id"],
                    "status": existing_order_row["status"],
                    "payment_status": existing_order_row["payment_status"],
                    "total": existing_order_row["total_minor"] / 100.0,
                    "total_amount": existing_order_row["total_minor"] / 100.0,
                    "payment_method": payload.payment_method,
                    "is_prelaunch_interest": False,
                },
                "message": "Order replayed from existing idempotency record",
            },
        )

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
    delivery_fee = 0.0 if subtotal >= 500.0 else 50.0
    delivery_fee_minor = int(round(delivery_fee * 100))

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
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'INR', 'placed', 'pending', ?)"""
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
                return {
                    "success": True,
                    "data": {
                        "id": winner["id"],
                        "status": winner.get("status", "placed"),
                        "total": winner.get("total_minor", total_minor) / 100.0,
                        "total_amount": winner.get("total_minor", total_minor) / 100.0,
                        "is_prelaunch_interest": False,
                    },
                    "message": "Order replayed from concurrent transaction",
                }
            raise HTTPException(status.HTTP_409_CONFLICT, "Idempotency conflict") from exc
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, f"Order placement failed: {err_msg}") from exc

    return {
        "success": True,
        "data": {
            "id": order_id,
            "status": "placed",
            "payment_status": "pending",
            "total": total_minor / 100.0,
            "total_amount": total_minor / 100.0,
            "payment_method": payload.payment_method,
            "is_prelaunch_interest": False,
        },
        "message": "Order placed successfully",
    }


# -----------------------------------------------------------------------------
# Order Details, Payment & Cancellation
# -----------------------------------------------------------------------------

@commerce_router.get("/orders/payment-capabilities")
async def payment_capabilities(request: Request) -> dict:
    """Return payment capabilities for Flutter client."""
    env = _env(request)
    online_available = bool(
        getattr(env, "RAZORPAY_KEY_ID", None) and getattr(env, "RAZORPAY_KEY_SECRET", None)
    )
    if getattr(env, "ENVIRONMENT", "") in ("local", "test", "development"):
        online_available = True
    return {
        "success": True,
        "data": {
            "is_prelaunch_interest": False,
            "online_payment_available": online_available,
        },
    }


@commerce_router.get("/orders/{order_id}")
async def get_order_details(order_id: str, request: Request) -> dict:
    customer = _require_auth(request)
    db = _env(request).DB

    order_row = await db.prepare(
        """SELECT id, customer_id, status, payment_status, payment_method,
                  subtotal_minor, delivery_fee_minor, discount_minor, total_minor,
                  currency, created_at
           FROM orders WHERE id = ?"""
    ).bind(order_id).first()

    if not order_row:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Order not found")

    if order_row["customer_id"] != customer["id"] and customer.get("role") != "admin":
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Access denied")

    line_rows = await db.prepare(
        """SELECT id, product_id, product_title, quantity, unit_price_minor, total_minor
           FROM order_lines WHERE order_id = ?"""
    ).bind(order_id).all()

    lines = []
    for l in _d1_rows(line_rows):
        lines.append({
            "product_id": l["product_id"],
            "title": l["product_title"],
            "quantity": l["quantity"],
            "unit_price": l["unit_price_minor"] / 100.0,
            "total_price": l["total_minor"] / 100.0,
        })

    return {
        "success": True,
        "data": {
            "id": order_row["id"],
            "status": order_row["status"],
            "payment_status": order_row["payment_status"],
            "payment_method": order_row["payment_method"],
            "subtotal": order_row["subtotal_minor"] / 100.0,
            "delivery_fee": order_row["delivery_fee_minor"] / 100.0,
            "discount": order_row["discount_minor"] / 100.0,
            "total": order_row["total_minor"] / 100.0,
            "total_amount": order_row["total_minor"] / 100.0,
            "currency": order_row["currency"],
            "is_prelaunch_interest": False,
            "created_at": order_row["created_at"],
            "items": lines,
        },
    }


@commerce_router.post("/orders/{order_id}/cancel")
async def cancel_order(order_id: str, request: Request) -> dict:
    customer = _require_auth(request)
    db = _env(request).DB

    order_row = await db.prepare(
        "SELECT id, customer_id, status, reservation_id FROM orders WHERE id = ?"
    ).bind(order_id).first()

    if not order_row:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Order not found")

    if order_row["customer_id"] != customer["id"] and customer.get("role") != "admin":
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Access denied")

    if order_row["status"] == "cancelled":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Order is already cancelled")

    if order_row["status"] not in ("placed", "confirmed"):
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            f"Cannot cancel order in '{order_row['status']}' status; only placed or confirmed orders can be cancelled",
        )

    # Fetch lines to restore inventory
    lines_rows = await db.prepare("SELECT product_id, quantity FROM order_lines WHERE order_id = ?").bind(order_id).all()
    statements = [
        db.prepare("UPDATE orders SET status = 'cancelled' WHERE id = ?").bind(order_id),
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

    try:
        await db.batch(statements)
    except Exception as exc:
        err_msg = str(exc)
        if "only placed or confirmed" in err_msg.lower() or "abort" in err_msg.lower():
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Order cannot be cancelled") from exc
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, f"Cancellation failed: {err_msg}") from exc

    return {"success": True, "message": "Order cancelled and stock restored"}


# -----------------------------------------------------------------------------
# Payment Capabilities & Link Routes
# -----------------------------------------------------------------------------

@commerce_router.post("/orders/{order_id}/payment-link")
async def checkout_payment_link(order_id: str, request: Request) -> dict:
    """Issue hosted payment link for online checkout."""
    customer = _require_auth(request)
    db = _env(request).DB

    order = await db.prepare(
        "SELECT id, customer_id, status, payment_status, payment_method, total_minor FROM orders WHERE id = ?"
    ).bind(order_id).first()

    if not order:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Order not found")

    if order["customer_id"] != customer["id"] and customer.get("role") != "admin":
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Access denied")

    if order["status"] == "cancelled" or order["payment_method"] == "cod":
        raise HTTPException(status.HTTP_409_CONFLICT, "Online payment is unavailable for this order")

    if order["payment_status"] != "pending":
        raise HTTPException(status.HTTP_409_CONFLICT, "This order no longer needs payment")

    payment_url = f"https://checkout.razorpay.com/v1/milterra_pay/{order_id}"
    return {
        "success": True,
        "data": {
            "order_id": order_id,
            "url": payment_url,
            "payment_status": order["payment_status"],
            "amount": order["total_minor"] / 100.0,
        },
    }

