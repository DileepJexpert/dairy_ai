import asyncio
import sqlite3
import time
from pathlib import Path
from types import SimpleNamespace

import httpx
import pytest
from starlette.testclient import TestClient

from api import app
from customer_auth import hash_password, verify_password
from test_commerce import MockD1Database


@pytest.fixture
def auth_client():
    conn = sqlite3.connect(":memory:", check_same_thread=False, isolation_level=None)
    conn.execute("PRAGMA foreign_keys = ON")
    for migration in sorted((Path(__file__).parents[1] / "migrations").glob("*.sql")):
        conn.executescript(migration.read_text())
    old = getattr(app.state, "env", None)
    app.state.env = SimpleNamespace(DB=MockD1Database(conn), CUSTOMER_AUTH_ENABLED="true", AUTH_SECRET="test-only-secret-at-least-32-bytes-long", CORS_ORIGINS="https://store.test")
    with TestClient(app) as client:
        yield client, conn
    app.state.env = old
    conn.close()


ACCOUNT = {"phone": "9876543210", "password": "a-unique-test-password", "username": "customer.one", "email": "test@example.com", "display_name": "Test Customer"}


def register(client, **changes):
    return client.post("/api/v1/auth/register-password", json={**ACCOUNT, **changes})


def test_full_lifecycle_and_logout_revokes_refresh(auth_client):
    client, conn = auth_client
    result = register(client)
    assert result.status_code == 201
    pair = result.json()
    headers = {"Authorization": "Bearer " + pair["access_token"]}
    profile = client.get("/api/v1/auth/me", headers=headers)
    assert profile.json()["data"]["name"] == "Test Customer"
    assert profile.headers["cache-control"] == "no-store"
    record = conn.execute("SELECT password_hash, phone_verified, email_verified FROM customer_credentials").fetchone()
    assert record[0].startswith("pbkdf2_sha256$600000$") and record[1:] == (0, 0)
    assert ACCOUNT["password"] not in record[0]
    stored = conn.execute("SELECT access_hash, refresh_hash FROM customer_sessions").fetchone()
    assert pair["access_token"] not in stored and pair["refresh_token"] not in stored
    rotated = client.post("/api/v1/auth/refresh", json={"refresh_token": pair["refresh_token"]})
    assert rotated.status_code == 200
    assert client.get("/api/v1/auth/me", headers=headers).status_code == 401
    assert client.post("/api/v1/auth/refresh", json={"refresh_token": pair["refresh_token"]}).status_code == 401
    new = rotated.json()["data"]
    assert client.post("/api/v1/auth/logout", json={"refresh_token": new["refresh_token"]}).status_code == 200
    assert client.get("/api/v1/auth/me", headers={"Authorization": "Bearer " + new["access_token"]}).status_code == 401
    assert client.post("/api/v1/auth/refresh", json={"refresh_token": new["refresh_token"]}).status_code == 401


@pytest.mark.parametrize("identifier", ["9876543210", "+919876543210", "CUSTOMER.ONE", "TEST@EXAMPLE.COM"])
def test_login_identifiers(auth_client, identifier):
    client, _ = auth_client
    assert register(client).status_code == 201
    assert client.post("/api/v1/auth/login-password", json={"identifier": identifier, "password": ACCOUNT["password"]}).status_code == 200
    assert client.post("/api/v1/auth/login-password", json={"identifier": identifier, "password": "wrong-password"}).status_code == 401


def test_duplicates_are_atomic_and_roles_cannot_be_injected(auth_client):
    client, conn = auth_client
    assert register(client).status_code == 201
    assert register(client, phone="9876543211").status_code == 409
    assert conn.execute("SELECT COUNT(*) FROM customers WHERE phone != '9839769808'").fetchone()[0] == 1
    assert conn.execute("SELECT COUNT(*) FROM customer_sessions").fetchone()[0] == 1
    assert register(client, role="admin").status_code == 422
    assert register(client, password="Password@123").status_code == 422


def test_disabled_user_and_expired_session_rejected(auth_client):
    client, conn = auth_client
    pair = register(client).json()
    conn.execute("UPDATE customer_sessions SET access_expires_at = 0")
    assert client.get("/api/v1/auth/me", headers={"Authorization": "Bearer " + pair["access_token"]}).status_code == 401
    conn.execute("UPDATE customers SET is_active = 0")
    assert client.post("/api/v1/auth/refresh", json={"refresh_token": pair["refresh_token"]}).status_code == 401
    assert client.post("/api/v1/auth/login-password", json={"identifier": ACCOUNT["phone"], "password": ACCOUNT["password"]}).status_code == 401


def test_rate_limit_configuration_cors_and_body_bounds(auth_client):
    client, conn = auth_client
    assert register(client).status_code == 201
    # Prefill the same server-wide bucket to exercise rejection without expensive KDF loops.
    conn.execute("UPDATE auth_rate_limits SET attempts = 100")
    assert register(client).status_code == 429
    assert client.post("/api/v1/auth/login-password", json={"identifier": "customer", "password": "some-password"}, headers={"Origin": "https://evil.test"}).status_code == 403
    assert client.post("/api/v1/auth/login-password", content="x" * 8193).status_code == 413
    app.state.env.CUSTOMER_AUTH_ENABLED = "false"
    assert register(client).status_code == 503


def test_overlapping_refresh_has_one_winner(auth_client):
    client, conn = auth_client
    pair = register(client).json()
    async def race():
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app), base_url="http://test") as session:
            return await asyncio.gather(*[
                session.post("/api/v1/auth/refresh", json={"refresh_token": pair["refresh_token"]}) for _ in range(2)
            ])
    replies = asyncio.run(race())
    assert sorted(r.status_code for r in replies) == [200, 401]
    assert conn.execute("SELECT COUNT(*) FROM customer_sessions").fetchone()[0] == 1


def test_password_hash_is_salted():
    one, two = asyncio.run(hash_password("long-password")), asyncio.run(hash_password("long-password"))
    assert one != two
    assert asyncio.run(verify_password("long-password", one))
    assert not asyncio.run(verify_password("wrong-password", one))


def test_public_otp_routes_cannot_create_or_promote_staff(auth_client):
    client, conn = auth_client
    before = conn.execute("SELECT COUNT(*) FROM customers WHERE role IN ('admin','super_admin')").fetchone()[0]
    assert client.post("/api/v1/auth/send-otp", json={"phone": "9876543210"}).status_code == 503
    assert client.post("/api/v1/auth/verify-otp", json={
        "phone": "9876543210", "otp": "123456"}).status_code == 503
    assert conn.execute("SELECT COUNT(*) FROM customers WHERE role IN ('admin','super_admin')").fetchone()[0] == before


def test_existing_staff_account_can_use_password_login(auth_client):
    client, conn = auth_client
    staff = conn.execute("""SELECT c.id, a.username FROM customers c
        JOIN customer_credentials a ON a.customer_id=c.id WHERE c.role='admin'""").fetchone()
    assert staff is not None
    conn.execute("UPDATE customer_credentials SET password_hash=? WHERE customer_id=?",
                 (asyncio.run(hash_password("temporary-test-admin-password")), staff[0]))
    login = client.post("/api/v1/auth/login-password", json={
        "identifier": staff[1], "password": "temporary-test-admin-password"})
    assert login.status_code == 200, login.text
    assert login.json()["role"] == "admin"
    profile = client.get("/api/v1/auth/me", headers={
        "Authorization": "Bearer " + login.json()["access_token"]})
    assert profile.status_code == 200
    assert profile.json()["data"]["role"] == "admin"
