import pytest
from datetime import datetime, timedelta, timezone
from app.services.auth_service import hash_otp

pytestmark = pytest.mark.asyncio

class TestSendOTP:
    async def test_send_otp_new_user(self, client):
        response = await client.post("/api/v1/auth/send-otp", json={"phone": "9999900002"})
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["message"] == "OTP sent"

    async def test_send_otp_existing_user(self, client, test_user):
        response = await client.post("/api/v1/auth/send-otp", json={"phone": test_user.phone})
        assert response.status_code == 200
        assert response.json()["success"] is True

    async def test_send_otp_invalid_phone(self, client):
        response = await client.post("/api/v1/auth/send-otp", json={"phone": "123"})
        assert response.status_code == 422


class TestPasswordAuth:
    async def test_customer_can_register_and_login_without_paid_otp(self, client):
        registration = await client.post(
            "/api/v1/auth/register-password",
            json={"phone": "9876504321", "password": "milterra-test-123"},
        )
        assert registration.status_code == 201
        assert registration.json()["role"] == "farmer"

        login = await client.post(
            "/api/v1/auth/login-password",
            json={"identifier": "9876504321", "password": "milterra-test-123"},
        )
        assert login.status_code == 200
        assert login.json()["access_token"]

    async def test_password_registration_and_login_fail_safely(self, client):
        payload = {"phone": "9876504322", "password": "milterra-test-123"}
        assert (await client.post("/api/v1/auth/register-password", json=payload)).status_code == 201
        assert (await client.post("/api/v1/auth/register-password", json=payload)).status_code == 409
        wrong = await client.post(
            "/api/v1/auth/login-password",
            json={"identifier": payload["phone"], "password": "incorrect-password"},
        )
        assert wrong.status_code == 401

    async def test_password_requires_minimum_length(self, client):
        response = await client.post(
            "/api/v1/auth/register-password",
            json={"phone": "9876504323", "password": "short"},
        )
        assert response.status_code == 422

    async def test_customer_can_use_username_email_and_reset_password(self, client):
        registration = await client.post(
            "/api/v1/auth/register-password",
            json={
                "phone": "9876504399",
                "username": "dileep.customer",
                "email": "dileep@example.com",
                "display_name": "Dileep Customer",
                "password": "original-password",
            },
        )
        assert registration.status_code == 201

        by_username = await client.post(
            "/api/v1/auth/login-password",
            json={
                "identifier": "dileep.customer",
                "password": "original-password",
            },
        )
        assert by_username.status_code == 200

        recovery = await client.post(
            "/api/v1/auth/forgot-password",
            json={"identifier": "dileep@example.com"},
        )
        assert recovery.status_code == 200
        reset_token = recovery.json()["data"]["reset_token"]

        reset = await client.post(
            "/api/v1/auth/reset-password",
            json={"token": reset_token, "new_password": "updated-password"},
        )
        assert reset.status_code == 200

        old_login = await client.post(
            "/api/v1/auth/login-password",
            json={
                "identifier": "dileep@example.com",
                "password": "original-password",
            },
        )
        assert old_login.status_code == 401
        new_login = await client.post(
            "/api/v1/auth/login-password",
            json={
                "identifier": "dileep@example.com",
                "password": "updated-password",
            },
        )
        assert new_login.status_code == 200

    async def test_forgot_password_does_not_reveal_missing_account(self, client):
        response = await client.post(
            "/api/v1/auth/forgot-password",
            json={"identifier": "missing@example.com"},
        )
        assert response.status_code == 200
        assert response.json()["data"] == {}

class TestVerifyOTP:
    async def test_verify_otp_success(self, client, test_user):
        response = await client.post("/api/v1/auth/verify-otp", json={"phone": test_user.phone, "otp": "123456"})
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["role"] == "farmer"

    async def test_verify_otp_wrong(self, client, test_user):
        response = await client.post("/api/v1/auth/verify-otp", json={"phone": test_user.phone, "otp": "000000"})
        assert response.status_code == 401

    async def test_verify_otp_expired(self, client, test_user, db_session):
        test_user.otp_expires_at = datetime.now(timezone.utc) - timedelta(minutes=10)
        await db_session.flush()
        response = await client.post("/api/v1/auth/verify-otp", json={"phone": test_user.phone, "otp": "123456"})
        assert response.status_code == 401

class TestRefreshToken:
    async def test_refresh_token(self, client, test_user):
        # First login
        login_resp = await client.post("/api/v1/auth/verify-otp", json={"phone": test_user.phone, "otp": "123456"})
        refresh = login_resp.json()["refresh_token"]

        response = await client.post("/api/v1/auth/refresh", json={"refresh_token": refresh})
        assert response.status_code == 200
        assert "access_token" in response.json()["data"]

class TestMe:
    async def test_me_authenticated(self, client, auth_headers):
        response = await client.get("/api/v1/auth/me", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()["data"]
        assert data["role"] == "farmer"
        assert data["phone"] == "9999900001"

    async def test_me_unauthenticated(self, client):
        response = await client.get("/api/v1/auth/me")
        assert response.status_code == 403  # No auth header
