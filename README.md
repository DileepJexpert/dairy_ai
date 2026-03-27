# DairyAI — Full Dairy AI Super-App Platform

India's first full-stack dairy problem solver. End-to-end platform for dairy farmers, veterinarians, and administrators.

## Features

- **Farmer App**: Herd management, milk recording, health monitoring, AI-powered feed plans, financial tracking
- **Vet Connect**: "Practo for cattle" — video consultations, prescriptions, ratings
- **AI Triage**: Symptom-based severity scoring with sensor data integration
- **IoT Pipeline**: ESP32 sensor collars → MQTT → real-time health monitoring
- **WhatsApp Bot**: Multilingual support (Hindi/English) for price checks, health queries
- **Admin Dashboard**: Platform analytics, vet verification, farmer management

## Tech Stack

- **Backend**: Python 3.12, FastAPI, SQLAlchemy 2.0 (async), PostgreSQL + TimescaleDB
- **Mobile**: Flutter 3.x (Riverpod, GoRouter)
- **IoT**: ESP32, MQTT (Mosquitto)
- **ML**: Rule-based triage (MVP), scikit-learn/XGBoost (planned)
- **Integrations**: WhatsApp Business API, Agora RTC, Bhashini API

## Quick Start

### Backend

```bash
# Start infrastructure
cd infra && docker-compose up -d

# Install dependencies
cd backend && pip install -r requirements.txt

# Run migrations
alembic upgrade head

# Seed demo data
python -m scripts.seed_data

# Start server
uvicorn app.main:app --reload --port 8000
```

### API Docs
Open http://localhost:8000/docs for interactive Swagger UI.

### Demo Credentials
All accounts use OTP: `123456`

| Role | Phone | Name |
|------|-------|------|
| Admin | 9999900000 | Admin |
| Farmer | 9999900001 | Ramesh Patel (3 cattle) |
| Farmer | 9999900002 | Suresh Kumar (3 cattle) |
| Farmer | 9999900003 | Lakshmi Devi (2 cattle) |
| Vet | 9999900010 | Dr. Amit Shah |
| Vet | 9999900011 | Dr. Priya Verma |

### Run Tests

```bash
cd backend && python -m pytest tests/ -v
```

## API Endpoints

### Auth
- `POST /api/v1/auth/send-otp` — Send OTP to phone
- `POST /api/v1/auth/verify-otp` — Verify OTP, get JWT tokens
- `POST /api/v1/auth/refresh` — Refresh access token
- `GET /api/v1/auth/me` — Current user info

### Farmers & Cattle
- `GET/POST/PUT /api/v1/farmers/me` — Farmer profile CRUD
- `POST/GET /api/v1/cattle` — Register and list cattle
- `GET /api/v1/cattle/dashboard` — Herd summary stats
- `GET/PUT/DELETE /api/v1/cattle/{id}` — Cattle detail operations

### Health & Sensors
- `POST/GET /api/v1/cattle/{id}/health-records` — Health records
- `POST/GET /api/v1/cattle/{id}/vaccinations` — Vaccination tracking
- `POST /api/v1/cattle/{id}/sensor-data` — Ingest sensor readings
- `GET /api/v1/cattle/{id}/sensors/latest` — Latest vitals
- `GET /api/v1/cattle/{id}/sensors/stats` — Aggregated stats
- `GET /api/v1/cattle/{id}/health-dashboard` — Combined health view

### Milk & Prices
- `POST/GET /api/v1/cattle/{id}/milk-records` — Record milk
- `GET /api/v1/farmers/me/milk-summary` — Farmer milk summary
- `GET /api/v1/milk-prices?district=X` — Price comparison
- `GET /api/v1/milk-prices/best-buyer` — Best buyer recommendation

### Feed, Breeding, Finance
- `POST /api/v1/cattle/{id}/feed-plan/generate` — AI feed plan
- `POST/GET /api/v1/cattle/{id}/breeding` — Breeding events
- `POST/GET /api/v1/transactions` — Financial transactions
- `GET /api/v1/farmers/me/profit-loss` — P&L report

### Vet Connect
- `POST /api/v1/vets/register` — Vet registration
- `GET /api/v1/vets/search` — Find available vets
- `POST /api/v1/consultations` — Request consultation
- `PUT /api/v1/consultations/{id}/accept|start|end` — Consultation lifecycle
- `POST /api/v1/consultations/{id}/prescription` — Create prescription
- `PUT /api/v1/consultations/{id}/rate` — Rate consultation

### AI & Chat
- `POST /api/v1/triage` — AI health triage
- `POST /api/v1/chat/message` — AI chat assistant

### WhatsApp
- `GET/POST /api/v1/whatsapp/webhook` — WhatsApp Business webhook

### Admin
- `GET /api/v1/admin/dashboard` — Platform stats
- `GET /api/v1/admin/farmers` — Manage farmers
- `GET /api/v1/admin/vets` — Manage vets
- `GET /api/v1/admin/analytics/registrations` — Registration trends

## Architecture

```
Farmer App / Vet App / Admin Dashboard (Flutter)
        │
        ▼
    FastAPI Backend (async)
        │
    ┌───┴───────┬──────────┬──────────┐
    │           │          │          │
PostgreSQL  Redis    MQTT Broker   External APIs
(TimescaleDB)        (Mosquitto)   (WhatsApp, Agora,
                         │          Bhashini, LLM)
                     ESP32 Collars
```
