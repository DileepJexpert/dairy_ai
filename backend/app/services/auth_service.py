import logging
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

logger = logging.getLogger("dairy_ai.services.auth")


def generate_otp() -> str:
    otp = f"{random.randint(0, 999999):06d}"
    logger.debug(f"Generated new OTP (length={len(otp)})")
    return otp

def hash_otp(otp: str) -> str:
    """Hash OTP using SHA256 with a salt (simple, no bcrypt dependency issues)."""
    settings = get_settings()
    hashed = hashlib.sha256(f"{otp}{settings.JWT_SECRET}".encode()).hexdigest()
    logger.debug("OTP hashed successfully using SHA256")
    return hashed

def verify_otp(plain_otp: str, hashed_otp: str) -> bool:
    expected = hash_otp(plain_otp)
    match = hmac.compare_digest(expected, hashed_otp)
    logger.debug(f"OTP verification result: {'match' if match else 'mismatch'}")
    return match

def create_access_token(user_id: str, role: str) -> str:
    settings = get_settings()
    expire = datetime.now(timezone.utc) + timedelta(minutes=15)
    payload = {
        "sub": str(user_id),
        "role": role,
        "exp": expire,
        "type": "access"
    }
    token = pyjwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)
    logger.info(f"Access token created | user_id={user_id}, role={role}, expires_in=15min")
    return token

def create_refresh_token(user_id: str) -> str:
    settings = get_settings()
    expire = datetime.now(timezone.utc) + timedelta(days=30)
    payload = {
        "sub": str(user_id),
        "exp": expire,
        "type": "refresh"
    }
    token = pyjwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)
    logger.info(f"Refresh token created | user_id={user_id}, expires_in=30days")
    return token

def decode_token(token: str) -> dict:
    settings = get_settings()
    logger.debug("Decoding JWT token...")
    try:
        payload = pyjwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])
        logger.debug(f"Token decoded successfully | type={payload.get('type')}, sub={payload.get('sub')}")
        return payload
    except JWTError as e:
        logger.warning(f"Token decode failed: {e}")
        raise

async def get_user_by_phone(db: AsyncSession, phone: str) -> User | None:
    masked_phone = f"****{phone[-4:]}" if len(phone) >= 4 else "****"
    logger.debug(f"Looking up user by phone={masked_phone}")
    result = await db.execute(select(User).where(User.phone == phone))
    user = result.scalar_one_or_none()
    if user:
        logger.debug(f"User found | id={user.id}, role={user.role.value}, phone={masked_phone}")
    else:
        logger.debug(f"No user found for phone={masked_phone}")
    return user

async def get_user_by_id(db: AsyncSession, user_id: str) -> User | None:
    logger.debug(f"Looking up user by id={user_id}")
    result = await db.execute(select(User).where(User.id == uuid.UUID(user_id)))
    user = result.scalar_one_or_none()
    if user:
        logger.debug(f"User found | id={user.id}, role={user.role.value}")
    else:
        logger.debug(f"No user found for id={user_id}")
    return user

async def send_otp(db: AsyncSession, phone: str) -> str:
    """Generate OTP and store hash. For dev: phone starting with 99999 uses OTP 123456."""
    masked_phone = f"****{phone[-4:]}" if len(phone) >= 4 else "****"
    logger.info(f"send_otp called | phone={masked_phone}")

    user = await get_user_by_phone(db, phone)

    # Dev mode: phones starting with 99999 always use 123456
    if phone.startswith("99999"):
        otp = "123456"
        logger.debug(f"Dev mode: using fixed OTP 123456 for phone={masked_phone}")
    else:
        otp = generate_otp()
        logger.debug(f"Generated OTP for phone={masked_phone}")

    otp_hashed = hash_otp(otp)
    expires = datetime.now(timezone.utc) + timedelta(minutes=5)
    logger.debug(f"OTP expires at {expires.isoformat()}")

    if user is None:
        logger.info(f"New user — creating account for phone={masked_phone} with role=farmer")
        user = User(
            phone=phone,
            otp_hash=otp_hashed,
            otp_expires_at=expires,
            role=UserRole.farmer,
        )
        db.add(user)
    else:
        logger.debug(f"Existing user — updating OTP for user_id={user.id}")
        user.otp_hash = otp_hashed
        user.otp_expires_at = expires

    await db.flush()
    logger.info(f"send_otp completed | phone={masked_phone}, user_id={user.id}")
    return otp

async def verify_otp_and_login(db: AsyncSession, phone: str, otp: str) -> dict | None:
    """Verify OTP and return tokens if valid."""
    masked_phone = f"****{phone[-4:]}" if len(phone) >= 4 else "****"
    logger.info(f"verify_otp_and_login called | phone={masked_phone}")

    user = await get_user_by_phone(db, phone)
    if user is None:
        logger.warning(f"Login failed — no user found for phone={masked_phone}")
        return None

    if user.otp_hash is None or user.otp_expires_at is None:
        logger.warning(f"Login failed — no OTP set for user_id={user.id}")
        return None

    # Check expiry - make both aware or both naive for comparison
    now = datetime.now(timezone.utc)
    expires = user.otp_expires_at
    if expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)

    if now > expires:
        logger.warning(f"Login failed — OTP expired for user_id={user.id} (expired at {expires.isoformat()})")
        return None

    if not verify_otp(otp, user.otp_hash):
        logger.warning(f"Login failed — incorrect OTP for user_id={user.id}, phone={masked_phone}")
        return None

    # Clear OTP after use
    logger.debug(f"OTP verified — clearing OTP for user_id={user.id}")
    user.otp_hash = None
    user.otp_expires_at = None
    await db.flush()

    access_token = create_access_token(str(user.id), user.role.value)
    refresh_token = create_refresh_token(str(user.id))

    logger.info(f"Login successful | user_id={user.id}, role={user.role.value}, phone={masked_phone}")

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "role": user.role.value,
    }

async def refresh_access_token(db: AsyncSession, refresh_token: str) -> dict | None:
    """Validate refresh token and return new access token."""
    logger.info("refresh_access_token called")
    try:
        payload = decode_token(refresh_token)
    except JWTError as e:
        logger.warning(f"Refresh failed — invalid token: {e}")
        return None

    if payload.get("type") != "refresh":
        logger.warning(f"Refresh failed — token type is '{payload.get('type')}', expected 'refresh'")
        return None

    user_id = payload.get("sub")
    logger.debug(f"Refresh token valid — looking up user_id={user_id}")
    user = await get_user_by_id(db, user_id)
    if user is None or not user.is_active:
        logger.warning(f"Refresh failed — user not found or inactive | user_id={user_id}")
        return None

    new_access = create_access_token(str(user.id), user.role.value)
    logger.info(f"Token refreshed successfully | user_id={user.id}, role={user.role.value}")
    return {
        "access_token": new_access,
        "token_type": "bearer",
        "role": user.role.value,
    }
