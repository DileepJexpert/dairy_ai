# DairyAI — Full Dairy AI Super-App Platform

## Mission
Build India's first full-stack dairy problem solver. Beat Amul AI by solving end-to-end problems, not just giving advice.

## Tech Stack
- **Backend**: Python 3.12, FastAPI (async), SQLAlchemy 2.0 (async), PostgreSQL 16 + TimescaleDB, Redis, Celery
- **Mobile**: Flutter 3.x (single codebase → farmer app + vet app + admin dashboard via role-based routing)
- **IoT**: ESP32, MQTT (Mosquitto), sensor pipeline
- **ML**: scikit-learn, XGBoost, ONNX Runtime (inference)
- **Video**: Agora RTC SDK (vet consultations)
- **Messaging**: WhatsApp Business Cloud API, Firebase FCM
- **Voice/NLP**: Bhashini API (Indian languages STT/TTS), OpenAI-compatible LLM
- **Infra**: Docker Compose (dev), AWS (prod)

## Architecture Principles
- **Monorepo** — all code in `dairy-ai/`
- **Feature-first** Flutter architecture (not layer-first)
- **Async everywhere** in FastAPI
- **Repository pattern** — services never touch DB directly, go through repos
- **TDD** — write test first, then implement. Every endpoint has tests.
- **12-factor app** — config via env vars, stateless services
- **Phone OTP auth** — no email (rural farmers don't use email)

## Project Structure
```
dairy-ai/
├── backend/
│   ├── app/
│   │   ├── main.py                 # FastAPI app factory
│   │   ├── config.py               # Settings from env
│   │   ├── database.py             # Async SQLAlchemy engine + session
│   │   ├── dependencies.py         # Dependency injection
│   │   ├── models/                 # SQLAlchemy ORM models
│   │   │   ├── __init__.py
│   │   │   ├── farmer.py
│   │   │   ├── cattle.py
│   │   │   ├── health.py
│   │   │   ├── milk.py
│   │   │   ├── feed.py
│   │   │   ├── breeding.py
│   │   │   ├── finance.py
│   │   │   ├── vet.py
│   │   │   └── conversation.py
│   │   ├── schemas/                # Pydantic request/response schemas
│   │   │   ├── __init__.py
│   │   │   ├── farmer.py
│   │   │   ├── cattle.py
│   │   │   ├── health.py
│   │   │   ├── milk.py
│   │   │   ├── feed.py
│   │   │   ├── breeding.py
│   │   │   ├── finance.py
│   │   │   └── vet.py
│   │   ├── api/                    # Route handlers (thin — delegate to services)
│   │   │   ├── __init__.py
│   │   │   ├── auth.py
│   │   │   ├── farmers.py
│   │   │   ├── cattle.py
│   │   │   ├── health.py
│   │   │   ├── milk.py
│   │   │   ├── feed.py
│   │   │   ├── breeding.py
│   │   │   ├── finance.py
│   │   │   ├── vet.py
│   │   │   ├── whatsapp.py
│   │   │   └── admin.py
│   │   ├── services/               # Business logic
│   │   │   ├── __init__.py
│   │   │   ├── auth_service.py
│   │   │   ├── cattle_service.py
│   │   │   ├── health_service.py
│   │   │   ├── triage_service.py
│   │   │   ├── feed_service.py
│   │   │   ├── breeding_service.py
│   │   │   ├── milk_service.py
│   │   │   ├── finance_service.py
│   │   │   ├── vet_service.py
│   │   │   ├── whatsapp_service.py
│   │   │   ├── notification_service.py
│   │   │   └── llm_service.py
│   │   ├── repositories/           # DB access layer
│   │   │   ├── __init__.py
│   │   │   ├── farmer_repo.py
│   │   │   ├── cattle_repo.py
│   │   │   ├── health_repo.py
│   │   │   └── vet_repo.py
│   │   ├── ml/                     # ML models + inference
│   │   │   ├── disease_predictor.py
│   │   │   ├── feed_optimizer.py
│   │   │   ├── yield_predictor.py
│   │   │   └── triage_scorer.py
│   │   ├── iot/                    # MQTT handlers
│   │   │   ├── mqtt_client.py
│   │   │   └── sensor_processor.py
│   │   └── integrations/           # External APIs
│   │       ├── whatsapp.py
│   │       ├── bhashini.py
│   │       ├── agora.py
│   │       ├── pashudhan.py
│   │       └── payment.py
│   ├── alembic/                    # DB migrations
│   ├── tests/
│   │   ├── conftest.py             # Fixtures (test DB, client, auth)
│   │   ├── test_auth.py
│   │   ├── test_cattle.py
│   │   ├── test_health.py
│   │   ├── test_vet.py
│   │   └── ...
│   ├── alembic.ini
│   ├── requirements.txt
│   └── Dockerfile
├── mobile/                         # Flutter
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app/
│   │   │   ├── router.dart         # GoRouter with role-based shells
│   │   │   ├── theme.dart
│   │   │   └── providers.dart      # Riverpod providers
│   │   ├── core/
│   │   │   ├── api_client.dart     # Dio HTTP client
│   │   │   ├── storage.dart        # Secure storage
│   │   │   ├── constants.dart
│   │   │   └── extensions.dart
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   ├── home/
│   │   │   ├── herd/
│   │   │   ├── health/
│   │   │   ├── feed/
│   │   │   ├── breeding/
│   │   │   ├── milk/
│   │   │   ├── finance/
│   │   │   ├── vet_farmer/        # Farmer-side vet consultation
│   │   │   ├── vet_doctor/        # Vet-side dashboard
│   │   │   ├── marketplace/
│   │   │   ├── chat/              # AI chat + WhatsApp
│   │   │   └── admin/             # Admin dashboard
│   │   └── shared/
│   │       ├── widgets/
│   │       ├── models/            # Dart data classes (freezed)
│   │       └── utils/
│   └── pubspec.yaml
├── firmware/                       # ESP32
│   ├── src/main.cpp
│   ├── src/sensors/
│   ├── src/mqtt/
│   └── platformio.ini
├── infra/
│   ├── docker-compose.yml
│   ├── docker-compose.prod.yml
│   ├── nginx/nginx.conf
│   └── .env.example
├── CLAUDE.md                       # THIS FILE
└── README.md
```

## Coding Conventions

### Python (Backend)
- All functions async unless impossible
- Type hints on every function signature
- Pydantic BaseModel for all request/response schemas
- SQLAlchemy 2.0 style (mapped_column, not Column)
- Snake_case everywhere
- Every API response: `{"success": bool, "data": {}, "message": str}`
- HTTP exceptions via FastAPI HTTPException with proper status codes
- Alembic for all schema changes (never raw SQL)

### Flutter (Mobile)
- Riverpod for state management (NOT provider, NOT bloc)
- GoRouter for navigation
- Freezed + json_serializable for data models
- Dio for HTTP with interceptors (auth token, error handling)
- Feature-first folder structure
- Role-based routing: farmer → FarmerShell, vet → VetShell, admin → AdminShell

### Testing (TDD)
- pytest + pytest-asyncio for backend
- Test DB uses SQLite in-memory for speed
- httpx.AsyncClient for API tests
- Every endpoint: test happy path + test validation + test auth
- Flutter: widget tests for key screens, unit tests for providers

## Database Schema Overview

### Core Tables
- farmers (id, phone, name, village, district, state, language, lat, lng)
- cattle (id, farmer_id, tag_id, name, breed, sex, dob, photo_url, status)
- sensor_readings (time, cattle_id, temperature, heart_rate, activity_level, battery) — TimescaleDB hypertable
- health_records (id, cattle_id, date, type, symptoms, diagnosis, treatment, vet_id)
- vaccinations (id, cattle_id, vaccine_name, date_given, next_due, administered_by)
- milk_records (id, cattle_id, date, session, quantity_litres, fat_pct, snf_pct, buyer, price_per_litre)
- feed_plans (id, cattle_id, plan_json, cost_per_day, created_at)
- breeding_records (id, cattle_id, event_type, date, bull_id, ai_tech_id, result, calf_id)
- transactions (id, farmer_id, type, category, amount, description, date)
- vet_profiles (id, user_id, license_no, qualification, specializations, fee, rating, is_verified)
- consultations (id, farmer_id, cattle_id, vet_id, type, triage_severity, ai_diagnosis, vet_diagnosis, status, started_at, ended_at, fee, rating)
- prescriptions (id, consultation_id, medicines_json, instructions, follow_up_date)
- conversations (id, farmer_id, channel, messages_json, created_at)
- milk_prices (id, district, buyer_name, price_per_litre, fat_pct, date)
- notifications (id, user_id, type, title, body, data_json, is_read, created_at)

### Auth
- users (id, phone, otp_hash, role [farmer/vet/admin], is_active, created_at)
- JWT tokens with refresh token rotation

## API Endpoints Overview
- POST /auth/send-otp, POST /auth/verify-otp, POST /auth/refresh
- CRUD /farmers, /cattle, /health-records, /vaccinations
- CRUD /milk-records, /feed-plans, /breeding-records, /transactions
- GET /milk-prices?district=X
- POST /triage (symptoms + cattle_id → severity + diagnosis)
- CRUD /vet-profiles, POST /vet-profiles/verify
- POST /consultations, PATCH /consultations/{id}/start, /end
- POST /prescriptions
- POST /whatsapp/webhook (incoming), POST /whatsapp/send
- GET /admin/dashboard, /admin/farmers, /admin/vets
- POST /iot/sensor-data (MQTT bridge endpoint)
- GET /cattle/{id}/sensor-history?hours=24
- POST /chat/message (AI chat)

## Environment Variables
DATABASE_URL, REDIS_URL, JWT_SECRET, JWT_ALGORITHM=HS256
WHATSAPP_TOKEN, WHATSAPP_PHONE_ID, WHATSAPP_VERIFY_TOKEN
AGORA_APP_ID, AGORA_APP_CERTIFICATE
BHASHINI_API_KEY, BHASHINI_USER_ID
LLM_API_URL, LLM_API_KEY, LLM_MODEL
MQTT_BROKER_HOST, MQTT_BROKER_PORT
AWS_ACCESS_KEY, AWS_SECRET_KEY, S3_BUCKET
RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET
