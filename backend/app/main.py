from contextlib import asynccontextmanager
from collections.abc import AsyncIterator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.auth import router as auth_router
from app.api.farmers import router as farmer_router
from app.api.cattle import router as cattle_router
from app.api.health import router as health_router
from app.api.milk import router as milk_router
from app.api.feed import router as feed_router
from app.api.breeding import router as breeding_router
from app.api.finance import router as finance_router
from app.database import init_db


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    await init_db()
    yield


app = FastAPI(
    title="DairyAI API",
    version="1.0.0",
    description="India's first full-stack dairy problem solver",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


app.include_router(auth_router, prefix="/api/v1")
app.include_router(farmer_router, prefix="/api/v1")
app.include_router(cattle_router, prefix="/api/v1")
app.include_router(health_router, prefix="/api/v1")
app.include_router(milk_router, prefix="/api/v1")
app.include_router(feed_router, prefix="/api/v1")
app.include_router(breeding_router, prefix="/api/v1")
app.include_router(finance_router, prefix="/api/v1")


@app.get("/health")
async def health_check() -> dict[str, bool | str]:
    return {"success": True, "message": "DairyAI API is running"}
