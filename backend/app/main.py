import logging
import time
import traceback
from contextlib import asynccontextmanager
from collections.abc import AsyncIterator

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

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
from app.api.milk_purity import router as milk_purity_router
from app.api.products import router as products_router
from app.api.commerce_taxonomy import router as commerce_taxonomy_router
from app.api.cart import router as cart_router
from app.api.delivery_addresses import router as delivery_address_router
from app.api.orders import router as order_router
from app.database import init_db
from app.config import settings

# Configure logging for the whole app
logging.basicConfig(
    level=getattr(logging, settings.LOG_LEVEL.upper(), logging.INFO),
    format="%(asctime)s | %(levelname)-8s | %(name)-30s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("dairy_ai.main")


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings.validate_production_settings()
    logger.info("=" * 60)
    logger.info("DairyAI API starting up...")
    logger.info("=" * 60)
    if settings.INIT_DB_ON_STARTUP:
        logger.info("Initializing database...")
        await init_db()
        logger.info("Database initialized successfully")
    else:
        logger.info("Skipping schema creation; migrations must be applied before startup")

    # Start MQTT subscriber if broker configured and IoT/MQTT flags enabled
    if settings.IOT_ENABLED and settings.MQTT_ENABLED and settings.MQTT_BROKER_HOST:
        from app.iot.mqtt_client import mqtt_subscriber
        logger.info(f"Starting MQTT subscriber → {settings.MQTT_BROKER_HOST}:{settings.MQTT_BROKER_PORT}")
        try:
            await mqtt_subscriber.connect()
        except Exception as e:
            logger.warning(f"MQTT: Failed to connect to broker on startup (non-fatal): {e}")
    else:
        logger.info("MQTT/IoT: Disabled or no broker configured, skipping MQTT subscriber")

    logger.info("All routers registered. API is ready to serve requests!")
    logger.info("=" * 60)
    yield
    logger.info("DairyAI API shutting down...")
    if settings.IOT_ENABLED and settings.MQTT_ENABLED:
        try:
            from app.iot.mqtt_client import mqtt_subscriber
            if mqtt_subscriber.is_connected:
                await mqtt_subscriber.disconnect()
        except Exception as e:
            logger.warning(f"MQTT: Error during shutdown disconnect: {e}")
    logger.info("=" * 60)


app = FastAPI(
    title="DairyAI API",
    version="1.0.0",
    description="India's first full-stack dairy problem solver",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_origin_regex=settings.cors_origin_regex,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Log every incoming request and response with timing and error traces."""
    start_time = time.time()
    method = request.method
    path = request.url.path
    client = request.client.host if request.client else "unknown"

    logger.info(f">>> {method} {path} | client={client}")

    try:
        response = await call_next(request)
        duration_ms = round((time.time() - start_time) * 1000, 2)
        logger.info(f"<<< {method} {path} | status={response.status_code} | {duration_ms}ms")
        return response
    except Exception as exc:
        duration_ms = round((time.time() - start_time) * 1000, 2)
        logger.error(
            f"<<< {method} {path} | FAILED ({duration_ms}ms) | {exc}\n{traceback.format_exc()}"
        )
        raise


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    logger.error(
        f"VALIDATION ERROR on {request.method} {request.url.path}:\n"
        f"Errors: {exc.errors()}\n"
        f"Body: {exc.body}"
    )
    return JSONResponse(
        status_code=422,
        content={"success": False, "message": "Validation Error", "errors": exc.errors()},
    )


@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    if exc.status_code >= 400:
        logger.warning(f"HTTP {exc.status_code} on {request.method} {request.url.path}: {exc.detail}")
    return JSONResponse(
        status_code=exc.status_code,
        content={"success": False, "message": exc.detail},
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    logger.error(
        f"UNHANDLED EXCEPTION on {request.method} {request.url.path}: {exc}\n"
        f"{traceback.format_exc()}"
    )
    return JSONResponse(
        status_code=500,
        content={"success": False, "message": "Internal server error", "detail": str(exc)},
    )


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
app.include_router(milk_purity_router, prefix="/api/v1")
app.include_router(products_router, prefix="/api/v1")
app.include_router(commerce_taxonomy_router, prefix="/api/v1")
app.include_router(cart_router, prefix="/api/v1")
app.include_router(delivery_address_router, prefix="/api/v1")
app.include_router(order_router, prefix="/api/v1")

logger.info(
    "Registered routers: auth, farmers, cattle, health, milk, feed, breeding, "
    "finance, vet, chat, whatsapp, notifications, admin, super-admin, vendor, "
    "cooperative, collection, payments, marketplace, outbreak, withdrawal, "
    "carbon, vision, schemes, mandi, pashu-aadhaar, milk-purity, products, "
    "commerce-taxonomy, cart, delivery-addresses, orders"
)


@app.get("/health")
async def health_check() -> dict[str, bool | str]:
    logger.debug("Health check endpoint called")
    return {"success": True, "message": "DairyAI API is running"}
