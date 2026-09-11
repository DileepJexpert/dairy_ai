# DairyAI & MILTERRA — System Architecture Specification

## 1. Executive Architecture Overview

DairyAI / MILTERRA is engineered as a full-stack, two-tier platform designed to support both high-performance e-commerce and cutting-edge IoT cattle telemetry while strictly managing operational cost.

The architecture cleanly decouples into two operational tiers:
1. **Cloud / MILTERRA Storefront Tier** — Zero/low-cost, high-velocity consumer e-commerce storefront operating on serverless, scale-to-zero infrastructure.
2. **Local Engineering Lab Tier** — Deep cattle telemetry and IoT collar simulation environment running time-series analysis and MQTT brokering locally.

```mermaid
flowchart TD
    subgraph CloudTier["☁️ TIER 1: CLOUD / MILTERRA STOREFRONT (Near ₹0/month)"]
        direction TB
        FW["Flutter Web Storefront\n(Cloudflare Pages / CDN)"]
        FA["FastAPI Application\n(Google Cloud Run / Railway - Scale to Zero)"]
        PG["PostgreSQL Database\n(Supabase / Neon DB Free Tier)"]
        R2["Static Media & Assets\n(Cloudflare R2 / AWS S3)"]
        RP["Payment Gateway\n(Razorpay Webhooks)"]
        WA["Notifications\n(WhatsApp Cloud API / SMS)"]

        FW -->|HTTPS / REST| FA
        FW -.->|Optimized Images| R2
        FA -->|Async SQLAlchemy / asyncpg| PG
        FA -->|Payment Verification| RP
        FA -->|Event Alerts| WA
    end

    subgraph LabTier["🔬 TIER 2: LOCAL LAB / IOT TELEMETRY (Development / Hardware)"]
        direction TB
        COLLAR["ESP32 Collars / Sensor Simulators\n(scripts/mock_sensor_simulator.py)"]
        MOSQ["Eclipse Mosquitto Broker\n(Port 1883 / 9001)"]
        REDIS["Redis Cache & Queue\n(Port 6379)"]
        TSDB["TimescaleDB Extension\n(Port 5432)"]
        LOCAL_API["FastAPI Backend\n(IOT_ENABLED=true)"]

        COLLAR -->|MQTT Telemetry| MOSQ
        MOSQ -->|Subscribed: dairy/cattle/+/sensors| LOCAL_API
        LOCAL_API -->|Hypertable Hypertables| TSDB
        LOCAL_API -->|PubSub / Caching| REDIS
    end
```

---

## 2. Two-Tier Operational Model

### Tier 1: Cloud / MILTERRA Storefront (Production Mode)
- **Target Workload**: Consumer & Farmer e-commerce (Pure Dairy products, cattle feed concepts, marketplace).
- **Cost Profile**: Near **₹0/month** by leveraging scale-to-zero serverless compute and global CDN caching.
- **Enabled Feature Flags**:
  - `IOT_ENABLED=false`
  - `MQTT_ENABLED=false`
  - `REDIS_ENABLED=false`
  - `TIMESCALE_FEATURES_ENABLED=false`
- **Zero Cold-Start Dependency**: FastAPI boots unconditionally without waiting on MQTT brokers or Redis caches.

### Tier 2: Local Lab / Cattle Health Tracker (Engineering Mode)
- **Target Workload**: ESP32 smart collar development, sensor anomaly detection, real-time vitals processing, and time-series aggregation.
- **Orchestration**: Docker Compose with profiles (`docker compose --profile iot up`).
- **Enabled Feature Flags**:
  - `IOT_ENABLED=true`
  - `MQTT_ENABLED=true`
  - `REDIS_ENABLED=true`
  - `TIMESCALE_FEATURES_ENABLED=true`

---

## 3. Backend Architecture (FastAPI)

```mermaid
graph TD
    Client[Flutter Client / Web / IoT Broker] --> Main[FastAPI app/main.py]

    subgraph MiddlewareLayer[Middleware & Lifecycle]
        CORS[CORSMiddleware]
        LogMiddleware[Request Timing & Error Logger]
        Lifespan[Lifespan Handler\n- DB Init\n- Conditional MQTT Startup]
    end

    subgraph APIRouters[API Routers /api/v1]
        R_Auth[auth]
        R_Products[products & taxonomy]
        R_Cart[cart & delivery_addresses]
        R_Orders[orders & payments]
        R_Marketplace[marketplace & vendor]
        R_Admin[admin & super_admin]
        R_Herd[cattle & herd]
        R_Health[health & vet]
        R_IoT[iot & sensors]
        R_Milk[milk & purity]
    end

    subgraph ServiceLayer[Core Services & Processors]
        S_Marketplace[MarketplaceService]
        S_Sensor[SensorProcessor]
        S_Alert[AlertEngine]
        S_Auth[JWT & Security]
    end

    subgraph DBLayer[Database / Storage Layer]
        AsyncSession[AsyncSession Factory]
        Postgres[(PostgreSQL / TimescaleDB)]
    end

    Main --> MiddlewareLayer
    MiddlewareLayer --> APIRouters
    APIRouters --> ServiceLayer
    ServiceLayer --> DBLayer
```

### Key Modules & Responsibilities:
- **`backend/app/main.py`**: Lifespan startup/shutdown, router registration, request logging middleware, global exception handlers.
- **`backend/app/config.py`**: Pydantic `BaseSettings` reading environment variables with strict production validation rules (e.g. minimum 32-char JWT secret, explicit HTTPS origins).
- **`backend/app/database.py`**: Async SQLAlchemy engine (`asyncpg`) and sessionmaker with connection pooling.
- **`backend/app/iot/mqtt_client.py`**: Non-blocking MQTT subscriber running on the async event loop with auto-reconnect and database isolation.
- **`backend/app/iot/sensor_processor.py`**: Ingests temperature, heart rate, rumination, and activity vitals; calculates health anomaly alerts.

---

## 4. Frontend Architecture (Flutter Web & Mobile)

```mermaid
graph LR
    subgraph UIComponents["Presentation Layer"]
        Views["Screens (Catalog, Product Details, Cart, Checkout, Admin)"]
        Widgets["Reusable Widgets (Cards, Drawers, Badges, Banners)"]
    end

    subgraph StateMgmt["State Management (Riverpod)"]
        P_Cart["CartProvider"]
        P_Product["ProductProvider"]
        P_Wishlist["WishlistProvider"]
        P_Address["DeliveryAddressProvider"]
        P_Seller["SellerPortalProvider"]
        P_Admin["AdminMarketplaceProvider"]
    end

    subgraph CoreServices["Infrastructure Layer"]
        Router["GoRouter (lib/app/router.dart)"]
        API["ApiClient (Dio/Http)"]
        Storage["Secure Storage / Local Storage"]
        Theme["Milterra / Dairy StoreTheme"]
    end

    Views --> StateMgmt
    Widgets --> StateMgmt
    StateMgmt --> CoreServices
```

### Storefront Design Principles:
1. **Distinction between Verified Dairy & Nutrition Concepts**:
   - **Verified Pure Dairy**: Fully commercialized with pricing, inventory, Add-to-Cart, instant checkout, and purity certification batches.
   - **Animal Nutrition Concepts (MILTERRA)**: Displayed as R&D concept previews with clear `Concept Preview` and `In Development` badges; commercial purchasing controls are disabled while gathering farmer feedback.
2. **Performance Optimizations**:
   - Web image asset resolution fallback (local asset images with network URL fallbacks).
   - Optimistic UI updates on cart operations and wishlist toggling.
   - Zero-blocking page transitions via GoRouter.

---

## 5. Catalog & Commerce Taxonomy

The commerce engine supports a dual-taxonomy structure:

```mermaid
graph TD
    Root[MILTERRA Marketplace Catalog]
    
    Root --> PureDairy[🥛 Pure Dairy Products]
    PureDairy --> A2Milk[A2 Gir Cow Milk]
    PureDairy --> BilonaGhee[Vedic Bilona Ghee]
    PureDairy --> ButterPaneer[Artisanal Butter & Paneer]
    
    Root --> Nutrition[🌾 Cattle Nutrition Solutions]
    Nutrition --> PashuAahar[Pashu Aahar / Cattle Feed]
    Nutrition --> StageNutrition[Stage-Based Nutrition]
    Nutrition --> Supplements[Supplements & Minerals]
```

---

## 6. Docker Compose Configuration & Profiles

The Docker Compose configuration (`infra/docker-compose.yml`) leverages Docker compose profiles to support the Two-Tier architecture:

```yaml
version: "3.9"

services:
  postgres:
    image: timescale/timescaledb:latest-pg16
    container_name: dairy_ai_postgres
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: dairy
      POSTGRES_PASSWORD: dairy123
      POSTGRES_DB: dairy_ai
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    container_name: dairy_ai_redis
    ports:
      - "6379:6379"
    profiles:
      - iot
      - all

  mosquitto:
    image: eclipse-mosquitto:2
    container_name: dairy_ai_mosquitto
    ports:
      - "1883:1883"
      - "9001:9001"
    volumes:
      - ./mosquitto/mosquitto.conf:/mosquitto/config/mosquitto.conf
    profiles:
      - iot
      - all

  backend:
    build:
      context: ../backend
      dockerfile: Dockerfile
    container_name: dairy_ai_backend
    ports:
      - "8000:8000"
    depends_on:
      - postgres
    env_file:
      - ../.env

volumes:
  postgres_data:
```

### Execution Commands:
- **Core Mode (E-Commerce only)**:
  ```bash
  docker compose up -d
  ```
- **IoT / Local Lab Mode (Full stack with MQTT & Redis)**:
  ```bash
  docker compose --profile iot up -d
  ```

---

## 7. Environment Variables & Feature Flags

| Variable | Type | Default (Dev) | Production Recommendation | Purpose |
|---|---|---|---|---|
| `APP_ENV` | String | `development` | `production` | Application environment mode |
| `LOG_LEVEL` | String | `INFO` | `WARNING` / `INFO` | Log verbosity |
| `DATABASE_URL` | String | `postgresql+asyncpg://...` | Supabase / RDS async URL | Async database connection string |
| `IOT_ENABLED` | Boolean | `true` | `false` | Global toggle for IoT pipelines |
| `MQTT_ENABLED` | Boolean | `true` | `false` | Connects MQTT subscriber if true |
| `REDIS_ENABLED` | Boolean | `false` | `false` | Redis queue & cache integration |
| `TIMESCALE_FEATURES_ENABLED` | Boolean | `false` | `false` | TimescaleDB specific hypertables |
| `JWT_SECRET` | String | Demo key | 32+ character random secret | Authentication token signer |
| `CORS_ORIGINS` | String | `http://localhost:...` | `https://milterra.in` | Explicit allowed web origins |
| `INIT_DB_ON_STARTUP` | Boolean | `true` | `false` | Auto create schemas vs migrations |

---

## 8. Synthetic IoT Sensor Simulation

To simulate real-time cattle sensor collars without physical hardware, run the test simulator:

```bash
# Publish synthetic vitals via MQTT to Mosquitto
python backend/scripts/mock_sensor_simulator.py

# Simulate a fever/mastitis alert scenario
python backend/scripts/mock_sensor_simulator.py --scenario sick

# Direct REST ingestion mode (no MQTT broker needed)
python backend/scripts/mock_sensor_simulator.py --http
```

---

## 9. Launch Gates & Production Readiness Checklist

- [x] **Two-Tier Architecture separation** implemented and tested.
- [x] **Backend graceful startup**: MQTT and Redis decoupled from critical path.
- [x] **Product catalog separation**: Pure Dairy (commercial) vs Cattle Nutrition (concept preview).
- [x] **Admin & Seller management**: Product, pricing, deal, and inventory controls ready.
- [x] **Cart & Checkout workflows**: Cart drawer, checkout, delivery addresses, and order repository wired.
- [x] **Static code analysis**: 0 errors, 0 warnings on Flutter and backend modules.
