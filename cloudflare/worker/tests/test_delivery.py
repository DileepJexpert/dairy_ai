"""Tests for Milk Delivery Management API router."""

import sqlite3
from pathlib import Path
import pytest
from httpx import ASGITransport, AsyncClient

from api import app

MIGRATIONS_DIR = Path(__file__).resolve().parents[1] / "migrations"


class MockD1Statement:
    def __init__(self, db, sql: str, params: tuple = ()):
        self.db = db
        self.sql = sql
        self.params = params

    def bind(self, *args):
        clean_params = []
        for a in args:
            if isinstance(a, bool):
                clean_params.append(1 if a else 0)
            else:
                clean_params.append(a)
        return MockD1Statement(self.db, self.sql, tuple(clean_params))

    async def run(self):
        cursor = self.db.conn.cursor()
        cursor.execute(self.sql, self.params)
        self.db.conn.commit()
        return {"success": True}

    async def first(self, col: str | None = None):
        cursor = self.db.conn.cursor()
        cursor.execute(self.sql, self.params)
        row = cursor.fetchone()
        if not row:
            return None
        col_names = [d[0] for d in cursor.description]
        rec = dict(zip(col_names, row))
        return rec[col] if col else rec

    async def all(self):
        cursor = self.db.conn.cursor()
        cursor.execute(self.sql, self.params)
        rows = cursor.fetchall()
        col_names = [d[0] for d in cursor.description]
        return {"results": [dict(zip(col_names, r)) for r in rows]}


class MockD1Database:
    def __init__(self):
        self.conn = sqlite3.connect(":memory:", check_same_thread=False)
        self.conn.row_factory = sqlite3.Row

    def prepare(self, sql: str):
        return MockD1Statement(self, sql)

    async def batch(self, statements):
        cursor = self.conn.cursor()
        for stmt in statements:
            cursor.execute(stmt.sql, stmt.params)
        self.conn.commit()
        return [{"success": True} for _ in statements]


class MockEnv:
    def __init__(self, db):
        self.DB = db
        self.ENVIRONMENT = "test"
        self.AUTH_SECRET = "0123456789abcdef0123456789abcdef"


@pytest.fixture
def mock_db():
    db = MockD1Database()
    # Apply migration 0014
    mig_14 = MIGRATIONS_DIR / "0014_milk_delivery.sql"
    sql = mig_14.read_text(encoding="utf-8")
    db.conn.executescript(sql)
    return db


@pytest.mark.asyncio
async def test_delivery_auth_and_sync(mock_db):
    env = MockEnv(mock_db)
    app.state.env = env
    transport = ASGITransport(app=app)

    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Login with demo OTP
        login_res = await client.post(
            "/api/v1/delivery/auth/login",
            json={"phone": "9000000001", "otp": "123456", "name": "Ramu Milkman", "role": "milkman"}
        )
        assert login_res.status_code == 200
        data = login_res.json()
        assert data["success"] is True
        token = data["token"]
        assert token

        # 2. Sync data for milkman
        sync_res = await client.get(
            "/api/v1/delivery/sync?date_key=2026-10-03",
            headers={"Authorization": f"Bearer {token}", "X-User-Id": "milkman-1"}
        )
        assert sync_res.status_code == 200
        sync_data = sync_res.json()
        assert sync_data["success"] is True
        assert len(sync_data["societies"]) >= 2
        assert len(sync_data["flats"]) >= 5


@pytest.mark.asyncio
async def test_delivery_lifecycle(mock_db):
    env = MockEnv(mock_db)
    app.state.env = env
    transport = ASGITransport(app=app)

    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Create a new society
        soc_res = await client.post(
            "/api/v1/delivery/societies",
            json={"name": "Sunrise Towers", "address": "Block C, Indiranagar"},
            headers={"X-User-Id": "milkman-1"}
        )
        assert soc_res.status_code == 200
        soc_id = soc_res.json()["society"]["id"]

        # 2. Create flat
        flat_res = await client.post(
            f"/api/v1/delivery/societies/{soc_id}/flats",
            json={
                "flat_number": "101",
                "owner_name": "Rohan Gupta",
                "owner_phone": "9876543210",
                "has_app": True,
                "default_quantity": 2.0,
                "price_per_litre": 62.0
            }
        )
        assert flat_res.status_code == 200
        flat_id = flat_res.json()["flat"]["id"]

        # 3. Batch mark deliveries
        batch_res = await client.post(
            "/api/v1/delivery/deliveries/batch",
            json={
                "deliveries": [
                    {
                        "flat_id": flat_id,
                        "date_key": "2026-10-03",
                        "planned_quantity": 2.0,
                        "actual_quantity": 2.0,
                        "status": "delivered"
                    }
                ]
            }
        )
        assert batch_res.status_code == 200
        assert batch_res.json()["count"] == 1

        # 4. Subscriber change request
        cr_res = await client.post(
            "/api/v1/delivery/change-requests",
            json={
                "flat_id": flat_id,
                "type": "pauseToday",
                "start_date": "2026-10-04T00:00:00Z",
                "end_date": "2026-10-04T23:59:59Z",
                "reason": "Traveling"
            }
        )
        assert cr_res.status_code == 200
        cr_id = cr_res.json()["request"]["id"]

        # 5. Milkman resolves request
        resolve_res = await client.post(
            f"/api/v1/delivery/change-requests/{cr_id}/resolve",
            json={"action": "applied"}
        )
        assert resolve_res.status_code == 200
        assert resolve_res.json()["request"]["status"] == "applied"

        # 6. Absence
        abs_res = await client.post(
            "/api/v1/delivery/absences",
            json={"type": "singleDay", "date_key": "2026-10-05", "reason": "Festival"},
            headers={"X-User-Id": "milkman-1"}
        )
        assert abs_res.status_code == 200
        assert abs_res.json()["absence"]["reason"] == "Festival"

        # 7. Offline sync drain
        drain_res = await client.post(
            "/api/v1/delivery/sync/drain",
            json={
                "items": [
                    {
                        "op": "upsert",
                        "collection": "flats",
                        "data": {
                            "id": "offline-flat-1",
                            "society_id": soc_id,
                            "flat_number": "102",
                            "owner_name": "Kavita Rao",
                            "owner_phone": "9876543211",
                            "default_quantity": 1.0,
                            "price_per_litre": 62.0,
                            "status": "active"
                        }
                    }
                ]
            }
        )
        assert drain_res.status_code == 200
        assert drain_res.json()["applied"] == 1
