"""Customer-only password authentication; no activation of commerce or staff roles."""

import base64
import hashlib
import hmac
import json
import re
import secrets
import time
import uuid

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field, field_validator

auth_router = APIRouter(prefix="/api/v1/auth", tags=["customer authentication"])
ITERATIONS = 600_000  # Preserve the authoritative backend's password strength.
ACCESS_SECONDS = 900
SESSION_SECONDS = 30 * 86400


def environment(request):
    return request.scope.get("env") or getattr(request.app.state, "env", None)


def configured(request):
    env = environment(request)
    if getattr(env, "CUSTOMER_AUTH_ENABLED", "false") != "true" or len(
        getattr(env, "AUTH_SECRET", "") or ""
    ) < 32:
        raise HTTPException(503, "Customer accounts are temporarily unavailable")
    return env


def fingerprint(secret, value):
    return hmac.new(secret.encode(), value.encode(), hashlib.sha256).hexdigest()


def normalize_phone(value):
    value = value.strip().replace(" ", "").replace("-", "")
    if value.startswith("+91"):
        value = value[3:]
    return value


async def hash_password(password, salt=None, env=None):
    salt = salt or secrets.token_bytes(16)
    if hasattr(hashlib, "pbkdf2_hmac"):
        digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, ITERATIONS)
    elif env is not None and getattr(env, "PASSWORD_HASHER", None):
        # Standard KDF in a private Durable Object with the appropriate CPU budget.
        try:
            response = await env.PASSWORD_HASHER.fetch(
                "https://kdf.internal/derive", method="POST",
                body=json.dumps({"password": password, "salt": salt.hex()}),
            )
            if response.status != 200:
                raise HTTPException(503, f"Secure sign-in is temporarily unavailable (hash service {response.status}). Please retry.")
            digest = bytes.fromhex(json.loads(await response.text())["digest"])
            if len(digest) != 32:
                raise ValueError("Invalid derivation")
        except HTTPException:
            raise
        except Exception as exc:
            raise HTTPException(503, "Secure sign-in is temporarily unavailable. Please retry.") from exc
    else:
        raise HTTPException(503, "Secure sign-in is temporarily unavailable. Please retry.")
    return "pbkdf2_sha256${}${}${}".format(
        ITERATIONS, base64.urlsafe_b64encode(salt).decode(),
        base64.urlsafe_b64encode(digest).decode(),
    )


async def verify_password(password, encoded, env=None):
    try:
        algorithm, iterations, salt, digest = encoded.split("$")
        if algorithm != "pbkdf2_sha256" or int(iterations) != ITERATIONS:
            return False
        actual = await hash_password(password, base64.urlsafe_b64decode(salt), env)
        return hmac.compare_digest(actual, encoded)
    except (ValueError, TypeError):
        return False


class LoginInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    identifier: str = Field(min_length=3, max_length=254)
    password: str = Field(min_length=8, max_length=72)


class RegisterInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    phone: str = Field(max_length=20)
    password: str = Field(min_length=8, max_length=72)
    username: str | None = Field(default=None, max_length=30)
    email: str | None = Field(default=None, max_length=254)
    display_name: str | None = Field(default=None, max_length=128)

    @field_validator("phone")
    @classmethod
    def phone_valid(cls, value):
        value = normalize_phone(value)
        if not re.fullmatch(r"[6-9][0-9]{9}", value):
            raise ValueError("Enter a valid 10-digit Indian mobile number")
        return value

    @field_validator("username", "email", "display_name")
    @classmethod
    def normalize_optional(cls, value, info):
        if value is None or not value.strip():
            return None
        value = value.strip()
        if info.field_name == "username":
            value = value.lower()
            if not re.fullmatch(r"[a-z][a-z0-9._]{2,29}", value):
                raise ValueError("Username must start with a letter and contain 3-30 letters, numbers, dots or underscores")
        if info.field_name == "email":
            value = value.lower()
            if not re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", value):
                raise ValueError("Enter a valid email address")
        return value

    @field_validator("password")
    @classmethod
    def reject_demo(cls, value):
        if value == "Password@123":
            raise ValueError("Choose a password that is not a published demo password")
        return value


class RefreshInput(BaseModel):
    refresh_token: str = Field(min_length=32, max_length=256)


class ForgotPasswordInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    identifier: str = Field(min_length=3, max_length=254)


class ResetPasswordInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    token: str = Field(min_length=16, max_length=128)
    new_password: str = Field(min_length=8, max_length=72)

    @field_validator("new_password")
    @classmethod
    def reject_demo(cls, value):
        if value == "Password@123":
            raise ValueError("Choose a password that is not a published demo password")
        return value


async def rate_limit(request, action, identifier=None):
    env = configured(request)
    now = int(time.time())
    # Cloudflare overwrites this header at its edge; never trust X-Forwarded-For.
    ip = request.headers.get("cf-connecting-ip", "unknown")
    limit = {"register": 5, "login": 30, "refresh": 120, "forgot-password": 5, "reset-password": 10}.get(action, 30)
    keys = [(f"{action}:ip:{ip}", limit)]
    if identifier is not None:
        keys.append((f"{action}:identifier:{identifier}", 10))
    for key, maximum in keys:
        bucket = fingerprint(env.AUTH_SECRET, key)
        row = await env.DB.prepare(
            """INSERT INTO auth_rate_limits(bucket, attempts, expires_at) VALUES (?, 1, ?)
            ON CONFLICT(bucket) DO UPDATE SET
            attempts = CASE WHEN expires_at <= ? THEN 1 ELSE attempts + 1 END,
            expires_at = CASE WHEN expires_at <= ? THEN excluded.expires_at ELSE expires_at END
            RETURNING attempts"""
        ).bind(bucket, now + 900, now, now).first()
        if row["attempts"] > maximum:
            raise HTTPException(429, "Too many attempts. Please try again in 15 minutes.", headers={"Retry-After": "900"})
    # Bounded cleanup, including stale buckets left by varying network addresses.
    await env.DB.prepare(
        "DELETE FROM auth_rate_limits WHERE bucket IN (SELECT bucket FROM auth_rate_limits WHERE expires_at < ? LIMIT 100)"
    ).bind(now).run()
    await env.DB.prepare(
        "DELETE FROM customer_sessions WHERE id IN (SELECT id FROM customer_sessions WHERE expires_at < ? LIMIT 100)"
    ).bind(now).run()


def tokens(env):
    access, refresh = secrets.token_urlsafe(48), secrets.token_urlsafe(48)
    return access, refresh, fingerprint(env.AUTH_SECRET, access), fingerprint(env.AUTH_SECRET, refresh)


def response_tokens(access, refresh, role="farmer"):
    return {"access_token": access, "refresh_token": refresh, "token_type": "bearer", "role": role}


def session_insert(env, customer_id, access_hash, refresh_hash):
    now = int(time.time())
    return env.DB.prepare(
        "INSERT INTO customer_sessions(id, customer_id, access_hash, refresh_hash, access_expires_at, expires_at, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)"
    ).bind(str(uuid.uuid4()), customer_id, access_hash, refresh_hash, now + ACCESS_SECONDS, now + SESSION_SECONDS, now)


@auth_router.post("/register-password", status_code=201)
async def register(data: RegisterInput, request: Request):
    env = configured(request)
    await rate_limit(request, "register", data.phone)
    customer_id = str(uuid.uuid4())
    access, refresh, access_hash, refresh_hash = tokens(env)
    encoded = await hash_password(data.password, env=env)
    try:
        await env.DB.batch([
            env.DB.prepare("INSERT INTO customers(id, phone, full_name, role) VALUES (?, ?, ?, 'farmer')").bind(customer_id, data.phone, data.display_name),
            env.DB.prepare("INSERT INTO customer_credentials(customer_id, username, email, password_hash) VALUES (?, ?, ?, ?)").bind(customer_id, data.username, data.email, encoded),
            session_insert(env, customer_id, access_hash, refresh_hash),
        ])
    except Exception as exc:
        if "UNIQUE constraint failed" in str(exc):
            raise HTTPException(409, "An account already uses these details. Sign in instead.") from exc
        raise
    return response_tokens(access, refresh, role="farmer")


@auth_router.post("/login-password")
async def login(data: LoginInput, request: Request):
    env = configured(request)
    identifier = data.identifier.strip().lower()
    phone = normalize_phone(identifier)
    await rate_limit(request, "login", phone)
    row = await env.DB.prepare(
        """SELECT c.id, c.is_active, c.role, a.password_hash FROM customers c
        JOIN customer_credentials a ON a.customer_id = c.id
        WHERE c.phone = ? OR a.username = ? OR a.email = ?"""
    ).bind(phone, identifier, identifier).first()
    # Equal KDF work for unknown identifiers; do not reveal registration through login.
    encoded = row["password_hash"] if row else "pbkdf2_sha256$600000$AAAAAAAAAAAAAAAAAAAAAA==$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    valid = await verify_password(data.password, encoded, env)
    if not valid or not row or not row["is_active"]:
        raise HTTPException(401, "Invalid credentials")
    access, refresh, access_hash, refresh_hash = tokens(env)
    await session_insert(env, row["id"], access_hash, refresh_hash).run()
    return response_tokens(access, refresh, role=row["role"])


async def require_session(request):
    env = configured(request)
    authorization = request.headers.get("authorization", "")
    if not authorization.startswith("Bearer ") or len(authorization) > 300:
        raise HTTPException(401, "Sign in to continue")
    row = await env.DB.prepare(
        """SELECT c.id, c.phone, c.full_name, c.role, a.username, a.email, s.id AS session_id
        FROM customer_sessions s JOIN customers c ON c.id = s.customer_id
        JOIN customer_credentials a ON a.customer_id = c.id
        WHERE s.access_hash = ? AND s.access_expires_at > ? AND s.expires_at > ?
        AND c.is_active = 1"""
    ).bind(fingerprint(env.AUTH_SECRET, authorization[7:]), int(time.time()), int(time.time())).first()
    if not row:
        raise HTTPException(401, "Session expired. Please sign in again.")
    return row


@auth_router.get("/me")
async def profile(request: Request):
    row = await require_session(request)
    return {"success": True, "data": {"id": row["id"], "phone": row["phone"], "role": row["role"], "name": row["full_name"], "username": row["username"], "email": row["email"]}}


@auth_router.post("/refresh")
async def refresh(data: RefreshInput, request: Request):
    env = configured(request)
    await rate_limit(request, "refresh")
    access, refresh_value, access_hash, refresh_hash = tokens(env)
    now = int(time.time())
    # One conditional statement replaces both tokens. A competing replay cannot win.
    row = await env.DB.prepare(
        """UPDATE customer_sessions SET access_hash = ?, refresh_hash = ?, access_expires_at = ?
        WHERE refresh_hash = ? AND expires_at > ? AND customer_id IN
        (SELECT id FROM customers WHERE is_active = 1) RETURNING customer_id"""
    ).bind(access_hash, refresh_hash, now + ACCESS_SECONDS, fingerprint(env.AUTH_SECRET, data.refresh_token), now).first()
    if not row:
        raise HTTPException(401, "Session expired. Please sign in again.")
    cust = await env.DB.prepare("SELECT role FROM customers WHERE id = ?").bind(row["customer_id"]).first()
    role = cust["role"] if cust else "farmer"
    return {"success": True, "data": response_tokens(access, refresh_value, role=role)}


@auth_router.post("/logout")
async def logout(data: RefreshInput, request: Request):
    env = configured(request)
    await env.DB.prepare("DELETE FROM customer_sessions WHERE refresh_hash = ?").bind(fingerprint(env.AUTH_SECRET, data.refresh_token)).run()
    return {"success": True}


@auth_router.post("/forgot-password")
async def forgot_password(data: ForgotPasswordInput, request: Request):
    env = configured(request)
    identifier = data.identifier.strip().lower()
    phone = normalize_phone(identifier)
    await rate_limit(request, "forgot-password", phone)

    if getattr(env, "ENVIRONMENT", "test") in ("production", "staging") and not getattr(env, "ALLOW_TEST_AUTH", False):
        raise HTTPException(503, "Password recovery via SMS/email is disabled in production until gateway integration.")

    row = await env.DB.prepare(
        """SELECT c.id, c.phone, c.is_active, a.email FROM customers c
        JOIN customer_credentials a ON a.customer_id = c.id
        WHERE c.phone = ? OR a.username = ? OR a.email = ?"""
    ).bind(phone, identifier, identifier).first()

    if not row or not row["is_active"]:
        raise HTTPException(404, "No registered account found matching that phone, username, or email.")

    customer_id = row["id"]
    token = secrets.token_urlsafe(32)
    token_hash = fingerprint(env.AUTH_SECRET, token)
    now = int(time.time())

    await env.DB.prepare(
        """INSERT INTO customer_password_resets(token_hash, customer_id, expires_at, created_at)
        VALUES (?, ?, ?, ?)"""
    ).bind(token_hash, customer_id, now + 900, now).run()

    storefront_url = getattr(env, "STOREFRONT_BASE_URL", "https://milterrafoods.com") or "https://milterrafoods.com"
    reset_url = f"{storefront_url.rstrip('/')}/#/reset-password?token={token}"

    return {
        "success": True,
        "message": "Password reset token generated successfully.",
        "data": {
            "reset_token": token,
            "reset_url": reset_url,
            "email_sent": False,
        },
    }


@auth_router.post("/reset-password")
async def reset_password(data: ResetPasswordInput, request: Request):
    env = configured(request)
    await rate_limit(request, "reset-password")
    now = int(time.time())
    token_hash = fingerprint(env.AUTH_SECRET, data.token)

    reset_row = await env.DB.prepare(
        """SELECT customer_id FROM customer_password_resets
        WHERE token_hash = ? AND expires_at > ?"""
    ).bind(token_hash, now).first()

    if not reset_row:
        raise HTTPException(400, "Reset link is invalid or expired")

    customer_id = reset_row["customer_id"]
    encoded = await hash_password(data.new_password, env=env)

    await env.DB.batch([
        env.DB.prepare("UPDATE customer_credentials SET password_hash = ? WHERE customer_id = ?").bind(encoded, customer_id),
        env.DB.prepare("DELETE FROM customer_password_resets WHERE customer_id = ?").bind(customer_id),
        env.DB.prepare("DELETE FROM customer_sessions WHERE customer_id = ?").bind(customer_id),
    ])

    return {"success": True, "data": {}, "message": "Password updated successfully"}


class SendOtpInput(BaseModel):
    model_config = ConfigDict(extra="allow")
    phone: str = Field(max_length=25)


class VerifyOtpInput(BaseModel):
    model_config = ConfigDict(extra="allow")
    phone: str = Field(max_length=25)
    otp: str = Field(min_length=1, max_length=50)


@auth_router.post("/send-otp")
async def send_otp(data: SendOtpInput, request: Request):
    configured(request)
    raise HTTPException(503, "SMS OTP service is not configured. Please sign in with password.")


@auth_router.post("/verify-otp")
async def verify_otp(data: VerifyOtpInput, request: Request):
    configured(request)
    raise HTTPException(503, "SMS OTP service is not configured. Please sign in with password.")

