"""Run against `pywrangler dev` and the local mock provider, never production."""

import hashlib
import hmac
import io
from datetime import datetime, timedelta, timezone

import httpx
import jwt
from PIL import Image


API = "http://127.0.0.1:8787"
JWT_SECRET = "local-compat-jwt-secret-long-enough"
WEBHOOK_SECRET = "local-compat-webhook-secret"


def verify() -> None:
    token = jwt.encode(
        {
            "sub": "compat-admin",
            "role": "admin",
            "type": "access",
            "exp": datetime.now(timezone.utc) + timedelta(minutes=5),
        },
        JWT_SECRET,
        algorithm="HS256",
    )
    auth = {"Authorization": f"Bearer {token}"}
    with httpx.Client(base_url=API, timeout=20) as client:
        health = client.get("/health")
        assert health.status_code == 200, health.text
        assert health.json() == {"success": True, "message": "DairyAI API is running"}
        assert health.headers["cache-control"] == "no-store"

        ready = client.get("/ready")
        assert ready.status_code == 200, ready.text
        assert ready.headers["cache-control"] == "no-store"

        assert client.get("/__compat/d1/missing").status_code == 404
        probe_key = "quote' OR 1=1 --"
        written = client.put(f"/__compat/d1/{probe_key}", headers=auth, json={"value": "safe"})
        assert written.status_code == 200, written.text
        assert written.json()["data"] == {"probe_key": probe_key, "probe_value": "safe"}
        read = client.get(f"/__compat/d1/{probe_key}", headers=auth)
        assert read.status_code == 200, read.text
        assert read.json() == written.json()
        assert client.get("/__compat/d1/other", headers=auth).status_code == 404

        body = b'{"event":"payment_link.paid"}'
        signature = hmac.new(WEBHOOK_SECRET.encode(), body, hashlib.sha256).hexdigest()
        verified = client.post(
            "/__compat/signature", headers={**auth, "X-Razorpay-Signature": signature}, content=body
        )
        assert verified.status_code == 200, verified.text
        assert client.post(
            "/__compat/signature", headers={**auth, "X-Razorpay-Signature": signature}, content=body + b" "
        ).status_code == 401

        provider = client.get("/__compat/provider/plink_test", headers=auth)
        assert provider.status_code == 200, provider.text
        assert provider.json()["data"] == {"id": "plink_test", "status": "paid"}

        image = Image.new("RGB", (8, 8), "green")
        raw = io.BytesIO()
        image.save(raw, format="PNG")
        sanitized = client.post("/__compat/image", headers=auth, content=raw.getvalue())
        assert sanitized.status_code == 200, sanitized.text
        assert sanitized.json()["data"]["bytes"] > 0
        assert client.post("/__compat/image", headers=auth, content=b"bad").status_code == 422
        assert client.get("/api/v1/not-a-route").status_code == 404
    print("Worker runtime verified: health, readiness, D1, JWT, HMAC, provider, image, 404")


if __name__ == "__main__":
    verify()
