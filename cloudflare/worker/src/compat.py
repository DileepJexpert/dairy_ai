"""Small tests of operations used by the existing commerce API.

These functions do not create orders or accept payments. They are kept separate
from the legacy server to test Python Workers without changing live behavior.
"""

import hashlib
import hmac
import io

import httpx
import jwt
from PIL import Image, ImageOps, UnidentifiedImageError


MAX_IMAGE_BYTES = 5 * 1024 * 1024
MAX_IMAGE_PIXELS = 16_000_000


def verify_access_token(token: str, secret: str) -> dict:
    """Match the existing HS256 access-token claims, without trusting role alone."""
    claims = jwt.decode(
        token,
        secret,
        algorithms=["HS256"],
        options={"require": ["sub", "exp", "type", "role"]},
    )
    if claims["type"] != "access" or not claims["sub"]:
        raise jwt.InvalidTokenError("Not an access token")
    return claims


def verify_razorpay_signature(body: bytes, signature: str, secret: str) -> bool:
    """Use the raw request bytes, as in the existing Razorpay webhook."""
    if not secret or len(signature) != 64:
        return False
    expected = hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature)


async def fetch_checkout_link_status(
    link_id: str,
    key_id: str,
    key_secret: str,
    *,
    base_url: str = "https://api.razorpay.com/v1",
    transport: httpx.AsyncBaseTransport | None = None,
) -> dict:
    """Exercise the existing provider's authenticated GET against a mock or test API."""
    if not link_id.startswith("plink_") or not key_id or not key_secret:
        raise ValueError("Invalid payment-link query")
    async with httpx.AsyncClient(timeout=10, transport=transport) as client:
        response = await client.get(
            f"{base_url.rstrip('/')}/payment_links/{link_id}",
            auth=(key_id, key_secret),
        )
        response.raise_for_status()
        payload = response.json()
    if not isinstance(payload, dict) or payload.get("id") != link_id:
        raise ValueError("Provider returned a different payment link")
    return payload


def sanitize_product_image(raw: bytes) -> bytes:
    """Match the existing 5 MB, format, pixel and EXIF-stripping policy."""
    if len(raw) > MAX_IMAGE_BYTES:
        raise ValueError("Image must be 5 MB or smaller")
    try:
        with Image.open(io.BytesIO(raw)) as original:
            if original.format not in {"JPEG", "PNG", "WEBP"}:
                raise ValueError("Choose a JPEG, PNG or WebP image")
            if original.width * original.height > MAX_IMAGE_PIXELS or getattr(original, "n_frames", 1) != 1:
                raise ValueError("Use a still image with at most 16 million pixels")
            original.load()
            corrected = ImageOps.exif_transpose(original).convert("RGBA")
            corrected.thumbnail((2400, 2400))
            clean = Image.new("RGB", corrected.size, "white")
            clean.paste(corrected, mask=corrected.getchannel("A"))
            output = io.BytesIO()
            clean.save(output, format="JPEG", quality=90)
            return output.getvalue()
    except (UnidentifiedImageError, OSError, Image.DecompressionBombError) as exc:
        raise ValueError("The file is not a valid supported image") from exc
