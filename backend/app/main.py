import logging
import time
from contextlib import asynccontextmanager
from collections.abc import AsyncIterator

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

from app.api.auth import router as auth_router
from app.api.farmers import router as farmer_router
from app.api.cattle import router as cattle_router
from app.api.health import router as health_router
from app.api.milk import router as milk_router
from app.api.feed import router as feed_router
from app.api.breeding import router as breeding_router
from app.api.finance import router as finance_router
from app.api.vet import router as vet_router
from app.api.chat import router as chat_router
from app.api.whatsapp import router as whatsapp_router
from app.api.notifications import router as notifications_router
from app.api.admin import router as admin_router
from app.api.super_admin import router as super_admin_router
from app.api.vendor import router as vendor_router
from app.api.cooperative import router as cooperative_router
from app.api.collection import router as collection_router
from app.api.payments import router as payments_router
from app.api.marketplace import router as marketplace_router
from app.api.outbreak import router as outbreak_router
from app.api.withdrawal import router as withdrawal_router
from app.api.carbon import router as carbon_router
from app.api.vision import router as vision_router
from app.api.schemes import router as schemes_router
from app.api.mandi import router as mandi_router
from app.api.pashu_aadhaar import router as pashu_aadhaar_router
from app.database import init_db

# Configure logging for the whole app
logging.basicConfig(
    level=logging.DEBUG,
    format="%(asctime)s | %(levelname)-8s | %(name)-30s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("dairy_ai.main")


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    logger.info("=" * 60)
    logger.info("DairyAI API starting up...")
    logger.info("=" * 60)
    logger.info("Initializing database...")
    await init_db()
    logger.info("Database initialized successfully")
    logger.info("All routers registered. API is ready to serve requests!")
    logger.info("=" * 60)
    yield
    logger.info("DairyAI API shutting down...")
    logger.info("=" * 60)


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


@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Log every incoming request and response with timing."""
    start_time = time.time()
    method = request.method
    path = request.url.path
    client = request.client.host if request.client else "unknown"

    logger.info(f">>> {method} {path} | client={client}")

    response = await call_next(request)

    duration_ms = round((time.time() - start_time) * 1000, 2)
    logger.info(f"<<< {method} {path} | status={response.status_code} | {duration_ms}ms")

    return response


app.include_router(auth_router, prefix="/api/v1")
app.include_router(farmer_router, prefix="/api/v1")
app.include_router(cattle_router, prefix="/api/v1")
app.include_router(health_router, prefix="/api/v1")
app.include_router(milk_router, prefix="/api/v1")
app.include_router(feed_router, prefix="/api/v1")
app.include_router(breeding_router, prefix="/api/v1")
app.include_router(finance_router, prefix="/api/v1")
app.include_router(vet_router, prefix="/api/v1")
app.include_router(chat_router, prefix="/api/v1")
app.include_router(whatsapp_router, prefix="/api/v1")
app.include_router(notifications_router, prefix="/api/v1")
app.include_router(admin_router, prefix="/api/v1")
app.include_router(super_admin_router, prefix="/api/v1")
app.include_router(vendor_router, prefix="/api/v1")
app.include_router(cooperative_router, prefix="/api/v1")
app.include_router(collection_router, prefix="/api/v1")
app.include_router(payments_router, prefix="/api/v1")
app.include_router(marketplace_router, prefix="/api/v1")
app.include_router(outbreak_router, prefix="/api/v1")
app.include_router(withdrawal_router, prefix="/api/v1")
app.include_router(carbon_router, prefix="/api/v1")
app.include_router(vision_router, prefix="/api/v1")
app.include_router(schemes_router, prefix="/api/v1")
app.include_router(mandi_router, prefix="/api/v1")
app.include_router(pashu_aadhaar_router, prefix="/api/v1")

logger.info("Registered routers: auth, farmers, cattle, health, milk, feed, breeding, finance, vet, chat, whatsapp, notifications, admin, super-admin, vendor, cooperative, collection, payments, marketplace, outbreak, withdrawal, carbon, vision, schemes, mandi, pashu-aadhaar")


@app.get("/health")
async def health_check() -> dict[str, bool | str]:
    logger.debug("Health check endpoint called")
    return {"success": True, "message": "DairyAI API is running"}
