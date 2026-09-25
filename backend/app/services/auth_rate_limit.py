"""Shared, fail-closed authentication request limits for production workers."""

import hashlib
import hmac
import logging
from functools import lru_cache

from fastapi import HTTPException, Request
from redis.asyncio import Redis

from app.config import settings

logger = logging.getLogger(__name__)

_INCREMENT_WITH_EXPIRY = """
local count = redis.call('INCR', KEYS[1])
if count == 1 then redis.call('EXPIRE', KEYS[1], ARGV[1]) end
return count
"""


@lru_cache(maxsize=1)
def _redis() -> Redis:
    return Redis.from_url(settings.REDIS_URL, decode_responses=True)


def _key(action: str, kind: str, value: str) -> str:
    digest = hmac.new(settings.JWT_SECRET.encode(), value.strip().lower().encode(), hashlib.sha256).hexdigest()
    return f"auth-limit:{action}:{kind}:{digest}"


async def limit_auth(request: Request, action: str, identifier: str,
                     *, per_identity: int, per_ip: int, seconds: int) -> None:
    if settings.APP_ENV.lower() != "production":
        return
    if not settings.REDIS_URL:
        raise HTTPException(503, "Authentication is temporarily unavailable")
    client_ip = request.client.host if request.client else "unknown"
    try:
        redis = _redis()
        identity_count = await redis.eval(_INCREMENT_WITH_EXPIRY, 1, _key(action, "id", identifier), seconds)
        ip_count = await redis.eval(_INCREMENT_WITH_EXPIRY, 1, _key(action, "ip", client_ip), seconds)
    except Exception:
        logger.exception("Authentication rate limiter is unavailable")
        raise HTTPException(503, "Authentication is temporarily unavailable")
    if identity_count > per_identity or ip_count > per_ip:
        raise HTTPException(429, "Too many attempts; try again later")
