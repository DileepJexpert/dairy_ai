"""Contract probes that run under CPython before the Workers runtime check."""

import hashlib
import hmac
import io
import asyncio
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import httpx
import jwt
import pytest
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from compat import (
    fetch_checkout_link_status,
    sanitize_product_image,
    verify_access_token,
    verify_razorpay_signature,
)


def test_existing_access_token_claims() -> None:
    token = jwt.encode(
        {
            "sub": "test-user",
            "role": "admin",
            "type": "access",
            "exp": datetime.now(timezone.utc) + timedelta(minutes=5),
        },
        "test-secret",
        algorithm="HS256",
    )
    assert verify_access_token(token, "test-secret")["sub"] == "test-user"
    with pytest.raises(jwt.InvalidTokenError):
        verify_access_token(token, "wrong-secret")
    refresh = jwt.encode(
        {"sub": "test-user", "role": "admin", "type": "refresh", "exp": datetime.now(timezone.utc) + timedelta(minutes=5)},
        "test-secret",
        algorithm="HS256",
    )
    with pytest.raises(jwt.InvalidTokenError):
        verify_access_token(refresh, "test-secret")


def test_raw_razorpay_hmac_rejects_tampering() -> None:
    body = b'{"event":"payment_link.paid"}'
    signature = hmac.new(b"webhook-secret", body, hashlib.sha256).hexdigest()
    assert verify_razorpay_signature(body, signature, "webhook-secret")
    assert not verify_razorpay_signature(body + b" ", signature, "webhook-secret")
    assert not verify_razorpay_signature(body, "invalid", "webhook-secret")


def test_provider_query_uses_basic_auth_and_checks_link_identity() -> None:
    observed = []

    def provider(request: httpx.Request) -> httpx.Response:
        observed.append(request)
        return httpx.Response(200, json={"id": "plink_test", "status": "paid"})

    result = asyncio.run(fetch_checkout_link_status(
        "plink_test", "rzp_test_id", "test_secret",
        base_url="https://provider.test/v1",
        transport=httpx.MockTransport(provider),
    ))
    assert result["status"] == "paid"
    assert observed[0].url.path == "/v1/payment_links/plink_test"
    assert observed[0].headers["authorization"].startswith("Basic ")

    async def wrong_link(_request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"id": "plink_other", "status": "paid"})

    with pytest.raises(ValueError, match="different payment link"):
        asyncio.run(fetch_checkout_link_status(
            "plink_test", "rzp_test_id", "test_secret", transport=httpx.MockTransport(wrong_link)
        ))


def test_image_processing_reencodes_without_metadata_and_rejects_bad_input() -> None:
    image = Image.new("RGB", (8, 8), "red")
    source = io.BytesIO()
    image.save(source, format="PNG", pnginfo=None)
    clean = sanitize_product_image(source.getvalue())
    with Image.open(io.BytesIO(clean)) as output:
        assert output.format == "JPEG"
        assert output.size == (8, 8)
        assert not output.getexif()
    with pytest.raises(ValueError, match="valid supported image"):
        sanitize_product_image(b"not an image")
