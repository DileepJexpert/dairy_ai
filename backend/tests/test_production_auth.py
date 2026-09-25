"""Production auth must not inherit demo credentials or accept unbounded guesses."""

import pytest
import httpx
import json
from fastapi import HTTPException, Request

from app.config import settings
from app.services import auth_rate_limit
from app.integrations import otp_sms


def production_settings(**overrides):
    values = {
        "APP_ENV": "production",
        "JWT_SECRET": "production-secret-unique-for-this-test-only-123",
        "CORS_ORIGINS": "https://milterra.example",
        "INIT_DB_ON_STARTUP": False,
        "ALLOW_DEMO_LOGIN": False,
        "STOREFRONT_BASE_URL": "https://milterra.example",
        "REDIS_URL": "rediss://localhost:6380/0",
        "SMTP_HOST": "smtp.example",
        "SMTP_USERNAME": "merchant",
        "SMTP_PASSWORD": "smtp-secret",
        "SMTP_FROM_EMAIL": "support@milterra.example",
        "SMS_PROVIDER": "msg91",
        "SMS_API_KEY": "msg91-secret",
        "SMS_TEMPLATE_ID": "approved-template",
        "PRELAUNCH_MODE": False,
        "RAZORPAY_KEY_ID": "rzp_live_testonly",
        "RAZORPAY_KEY_SECRET": "razorpay-secret",
        "RAZORPAY_WEBHOOK_SECRET": "webhook-secret",
    }
    values.update(overrides)
    return settings.model_copy(update=values)


def test_production_config_accepts_complete_secrets():
    production_settings().validate_production_settings()


@pytest.mark.parametrize("missing", [
    {"ALLOW_DEMO_LOGIN": True},
    {"INIT_DB_ON_STARTUP": True},
    {"REDIS_URL": ""},
    {"SMS_TEMPLATE_ID": ""},
    {"SMTP_PASSWORD": ""},
    {"STOREFRONT_BASE_URL": "http://localhost:5051"},
    {"RAZORPAY_KEY_ID": "rzp_test_not_live"},
])
def test_production_config_rejects_incomplete_auth_or_payment(missing):
    with pytest.raises(RuntimeError):
        production_settings(**missing).validate_production_settings()


@pytest.mark.asyncio
async def test_shared_auth_limiter_rejects_repeated_attempts(monkeypatch):
    class FakeRedis:
        def __init__(self):
            self.counts = {}

        async def eval(self, script, keys, key, seconds):
            self.counts[key] = self.counts.get(key, 0) + 1
            return self.counts[key]

    monkeypatch.setattr(settings, "APP_ENV", "production")
    monkeypatch.setattr(settings, "REDIS_URL", "rediss://localhost:6380/0")
    fake = FakeRedis()
    monkeypatch.setattr(auth_rate_limit, "_redis", lambda: fake)
    request = Request({"type": "http", "client": ("127.0.0.1", 12345), "method": "POST", "path": "/auth"})
    await auth_rate_limit.limit_auth(request, "otp-verify", "9999900000",
                                     per_identity=1, per_ip=5, seconds=60)
    with pytest.raises(HTTPException) as exc:
        await auth_rate_limit.limit_auth(request, "otp-verify", "9999900000",
                                         per_identity=1, per_ip=5, seconds=60)
    assert exc.value.status_code == 429


@pytest.mark.asyncio
async def test_auth_limiter_fails_closed_when_redis_is_unavailable(monkeypatch):
    class FailedRedis:
        async def eval(self, *args):
            raise ConnectionError("not connected")

    monkeypatch.setattr(settings, "APP_ENV", "production")
    monkeypatch.setattr(settings, "REDIS_URL", "rediss://localhost:6380/0")
    monkeypatch.setattr(auth_rate_limit, "_redis", lambda: FailedRedis())
    request = Request({"type": "http", "client": ("127.0.0.1", 12345), "method": "POST", "path": "/auth"})
    with pytest.raises(HTTPException) as exc:
        await auth_rate_limit.limit_auth(request, "password-login", "customer@example.com",
                                         per_identity=5, per_ip=20, seconds=60)
    assert exc.value.status_code == 503


@pytest.mark.asyncio
async def test_msg91_sms_uses_approved_template_and_checks_provider_result(monkeypatch):
    config = settings.model_copy(update={
        "SMS_PROVIDER": "msg91", "SMS_API_KEY": "secret", "SMS_TEMPLATE_ID": "approved-template",
    })
    monkeypatch.setattr(otp_sms, "get_settings", lambda: config)
    calls = []

    def respond(request):
        calls.append(request)
        return httpx.Response(200, json={"type": "success", "message": "request-id"})

    original_client = httpx.AsyncClient
    monkeypatch.setattr(otp_sms.httpx, "AsyncClient",
                        lambda **kwargs: original_client(transport=httpx.MockTransport(respond)))
    assert await otp_sms.OtpSmsClient.send("9876543210", "654321") is True
    assert calls[0].url == otp_sms.MSG91_FLOW_URL
    assert calls[0].headers["authkey"] == "secret"
    assert json.loads(calls[0].read()) == {
        "template_id": "approved-template",
        "recipients": [{"mobiles": "919876543210", "VAR1": "654321"}],
    }
