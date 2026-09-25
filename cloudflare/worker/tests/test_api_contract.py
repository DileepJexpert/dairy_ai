"""The first Worker route preserves the existing FastAPI liveness contract."""

import asyncio
import sys
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from api import app


def test_health_contract_is_identical_and_uncached() -> None:
    async def run() -> httpx.Response:
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
            return await client.get("/health")

    response = asyncio.run(run())
    assert response.status_code == 200
    assert response.json() == {"success": True, "message": "DairyAI API is running"}
    assert response.headers["cache-control"] == "no-store"


def test_unknown_api_route_is_404_json() -> None:
    async def run() -> httpx.Response:
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
            return await client.get("/api/v1/unknown")

    response = asyncio.run(run())
    assert response.status_code == 404
    assert response.json()["detail"] == "Not Found"
