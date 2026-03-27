import random
import uuid
from datetime import datetime, timedelta, timezone

import hashlib
import hmac
import jwt as pyjwt
from jwt.exceptions import PyJWTError as JWTError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.models.user import User, UserRole


def generate_otp() -> str:
    return f"{random.randint(0, 999999):06d}"

def hash_otp(otp: str) -> str:
    """Hash OTP using SHA256 with a salt (simple, no bcrypt dependency issues)."""
    settings = get_settings()
    return hashlib.sha256(f"{otp}{settings.JWT_SECRET}".encode()).hexdigest()

def verify_otp(plain_otp: str, hashed_otp: str) -> bool:
    expected = hash_otp(plain_otp)
    return hmac.compare_digest(expected, hashed_otp)

def create_access_token(user_id: str, role: str) -> str:
    settings = get_settings()
    expire = datetime.now(timezone.utc) + timedelta(minutes=15)
    payload = {
        "sub": str(user_id),
        "role": role,
        "exp": expire,
        "type": "access"
    }
    return pyjwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)

def create_refresh_token(user_id: str) -> str:
    settings = get_settings()
    expire = datetime.now(timezone.utc) + timedelta(days=30)
    payload = {
        "sub": str(user_id),
        "exp": expire,
        "type": "refresh"
    }
    return pyjwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)

def decode_token(token: str) -> dict:
    settings = get_settings()
    return pyjwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])

async def get_user_by_phone(db: AsyncSession, phone: str) -> User | None:
    result = await db.execute(select(User).where(User.phone == phone))
    return result.scalar_one_or_none()

async def get_user_by_id(db: AsyncSession, user_id: str) -> User | None:
    result = await db.execute(select(User).where(User.id == uuid.UUID(user_id)))
    return result.scalar_one_or_none()

async def send_otp(db: AsyncSession, phone: str) -> str:
    """Generate OTP and store hash. For dev: phone starting with 99999 uses OTP 123456."""
    user = await get_user_by_phone(db, phone)

    # Dev mode: phones starting with 99999 always use 123456
    if phone.startswith("99999"):
        otp = "123456"
    else:
        otp = generate_otp()

    otp_hashed = hash_otp(otp)
    expires = datetime.now(timezone.utc) + timedelta(minutes=5)

    if user is None:
        user = User(
            phone=phone,
            otp_hash=otp_hashed,
            otp_expires_at=expires,
            role=UserRole.farmer,
        )
        db.add(user)
    else:
        user.otp_hash = otp_hashed
        user.otp_expires_at = expires

    await db.flush()
    return otp

async def verify_otp_and_login(db: AsyncSession, phone: str, otp: str) -> dict | None:
    """Verify OTP and return tokens if valid."""
    user = await get_user_by_phone(db, phone)
    if user is None:
        return None

    if user.otp_hash is None or user.otp_expires_at is None:
        return None

    # Check expiry - make both aware or both naive for comparison
    now = datetime.now(timezone.utc)
    expires = user.otp_expires_at
    if expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)

    if now > expires:
        return None

    if not verify_otp(otp, user.otp_hash):
        return None

    # Clear OTP after use
    user.otp_hash = None
    user.otp_expires_at = None
    await db.flush()

    access_token = create_access_token(str(user.id), user.role.value)
    refresh_token = create_refresh_token(str(user.id))

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "role": user.role.value,
    }

async def refresh_access_token(db: AsyncSession, refresh_token: str) -> dict | None:
    """Validate refresh token and return new access token."""
    try:
        payload = decode_token(refresh_token)
    except JWTError:
        return None

    if payload.get("type") != "refresh":
        return None

    user_id = payload.get("sub")
    user = await get_user_by_id(db, user_id)
    if user is None or not user.is_active:
        return None

    new_access = create_access_token(str(user.id), user.role.value)
    return {
        "access_token": new_access,
        "token_type": "bearer",
        "role": user.role.value,
    }
