# DairyAI - Local Setup & End-to-End Testing Guide

## Prerequisites

- **Docker & Docker Compose** (for Postgres, Redis, MQTT)
- **Python 3.11+** (backend)
- **Flutter 3.x** (mobile - optional for backend-only testing)

---

## Quick Start

### Option 1: Full Docker (recommended)

```bash
cd dairy_ai

# Copy env (edit values as needed)
cp infra/.env.example .env

# Start all services
cd infra
docker compose up -d

# Backend at http://localhost:8000
# Swagger docs at http://localhost:8000/docs
```

### Option 2: Docker infra + local Python backend

```bash
# Start only infra
cd infra
docker compose up -d postgres redis mosquitto

# Setup Python
cd ../backend
python -m venv venv
source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt

# Run backend
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Option 3: Run tests only (no Docker needed)

Tests use in-memory SQLite - zero external dependencies:

```bash
cd backend
pip install -r requirements.txt
python -m pytest -v
# All 123 tests pass
```

---

## Services & Ports

| Service              | Port  | Description                        |
|----------------------|-------|------------------------------------|
| FastAPI Backend      | 8000  | REST API + Swagger UI              |
| PostgreSQL+TimescaleDB | 5432 | Primary database                  |
| Redis                | 6379  | Cache & Celery broker              |
| Mosquitto MQTT       | 1883  | IoT sensor data                    |
| Mosquitto WebSocket  | 9001  | MQTT over WebSocket                |

---

## Environment Variables

Copy `infra/.env.example` to `.env` at project root. Key variables:

| Variable          | Default                                          | Required |
|-------------------|--------------------------------------------------|----------|
| DATABASE_URL      | postgresql+asyncpg://dairy:dairy123@localhost:5432/dairy_ai | Yes |
| REDIS_URL         | redis://localhost:6379/0                         | Yes      |
| JWT_SECRET        | change-me-in-production-use-long-random-string   | Yes      |
| JWT_ALGORITHM     | HS256                                            | Yes      |
| MQTT_BROKER_HOST  | localhost                                        | For IoT  |
| WHATSAPP_TOKEN    | (empty)                                          | For WhatsApp |
| BHASHINI_API_KEY  | (empty)                                          | For voice/NLP |
| LLM_API_URL       | http://localhost:11434/v1                        | For AI chat |
| RAZORPAY_KEY_ID   | (empty)                                          | For payments |

---

## Dev Mode Features

- **Phone OTP bypass**: Any phone starting with `99999` accepts OTP `123456`
- **Auto table creation**: `init_db()` runs on startup, creates all tables
- **Swagger UI**: Full interactive API docs at `/docs`

---

## End-to-End Testing Walkthrough

### Step 1: Auth - Register & Login

```bash
# Send OTP (dev phone)
curl -X POST http://localhost:8000/api/v1/auth/send-otp \
  -H "Content-Type: application/json" \
  -d '{"phone": "9999900001"}'

# Verify OTP -> get JWT + dashboard_url
curl -X POST http://localhost:8000/api/v1/auth/verify-otp \
  -H "Content-Type: application/json" \
  -d '{"phone": "9999900001", "otp": "123456"}'

# Save the access_token
export TOKEN="<access_token_from_response>"
export AUTH="Authorization: Bearer $TOKEN"
```

### Step 2: Create Multiple Roles

```bash
# Farmer (default on first login - 9999900001)

# Vet doctor (login with different phone, then register)
curl -X POST http://localhost:8000/api/v1/auth/send-otp \
  -d '{"phone": "9999900002"}' -H "Content-Type: application/json"
curl -X POST http://localhost:8000/api/v1/auth/verify-otp \
  -d '{"phone": "9999900002", "otp": "123456", "role": "vet"}' \
  -H "Content-Type: application/json"

# Register vet profile with location
curl -X POST http://localhost:8000/api/v1/vets/register \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "license_no": "VET-RAJ-1234",
    "qualification": "BVSc",
    "specializations": ["cattle", "dairy"],
    "fee": 300,
    "pincode": "302001",
    "city": "Jaipur",
    "district": "Jaipur",
    "state": "Rajasthan",
    "lat": 26.9124,
    "lng": 75.7873,
    "service_radius_km": 30
  }'

# Vendor
curl -X POST http://localhost:8000/api/v1/auth/verify-otp \
  -d '{"phone": "9999900003", "otp": "123456", "role": "vendor"}' \
  -H "Content-Type: application/json"

# Cooperative
curl -X POST http://localhost:8000/api/v1/auth/verify-otp \
  -d '{"phone": "9999900004", "otp": "123456", "role": "cooperative"}' \
  -H "Content-Type: application/json"
```

### Step 3: Search Nearby Vets (as farmer)

```bash
# Search by GPS (sorts by distance)
curl "http://localhost:8000/api/v1/vets/search?lat=26.92&lng=75.80&max_distance_km=50&sort_by=distance" \
  -H "$AUTH"

# Search by fee range
curl "http://localhost:8000/api/v1/vets/search?min_fee=100&max_fee=500&sort_by=fee_low" \
  -H "$AUTH"

# Search by pincode
curl "http://localhost:8000/api/v1/vets/search?pincode=302001" \
  -H "$AUTH"
```

### Step 4: Milk Collection Flow

```bash
# Create collection center (needs admin/cooperative token)
curl -X POST http://localhost:8000/api/v1/collection/centers \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "name": "Village BMC Jaipur",
    "code": "JP-BMC-001",
    "district": "Jaipur",
    "state": "Rajasthan",
    "capacity_litres": 1000
  }'
# Save center_id from response

# Record milk pour (auto-grades A/B/C/rejected, auto-prices)
curl -X POST http://localhost:8000/api/v1/collection/milk \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "center_id": "<center_id>",
    "farmer_id": "<farmer_id>",
    "date": "2026-03-28",
    "shift": "morning",
    "quantity_litres": 10.5,
    "fat_pct": 4.2,
    "snf_pct": 8.7,
    "temperature_celsius": 3.5
  }'
# Response: grade=A, rate=36.0/L, quality_bonus=21.0, net=399.0

# Test rejection (high temperature)
curl -X POST http://localhost:8000/api/v1/collection/milk \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "center_id": "<center_id>",
    "farmer_id": "<farmer_id>",
    "date": "2026-03-28",
    "shift": "evening",
    "quantity_litres": 8.0,
    "fat_pct": 3.8,
    "snf_pct": 8.2,
    "temperature_celsius": 12.0
  }'
# Response: is_rejected=true, net_amount=0.0

# View center dashboard
curl "http://localhost:8000/api/v1/collection/centers/<center_id>/dashboard" \
  -H "$AUTH"
```

### Step 5: Cold Chain Monitoring

```bash
# Normal temperature (no alert)
curl -X POST http://localhost:8000/api/v1/collection/cold-chain/reading \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"center_id": "<center_id>", "temperature_celsius": 3.5}'

# Warning temperature (>4.5C)
curl -X POST http://localhost:8000/api/v1/collection/cold-chain/reading \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"center_id": "<center_id>", "temperature_celsius": 6.5}'
# Response: is_alert=true

# Critical temperature (>8.0C)
curl -X POST http://localhost:8000/api/v1/collection/cold-chain/reading \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"center_id": "<center_id>", "temperature_celsius": 10.0}'

# View all alerts
curl "http://localhost:8000/api/v1/collection/cold-chain/alerts?center_id=<center_id>" \
  -H "$AUTH"
```

### Step 6: Auto Payment Engine

```bash
# Create payment cycle (admin/cooperative)
curl -X POST http://localhost:8000/api/v1/payments/cycles \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "cycle_type": "weekly",
    "period_start": "2026-03-22",
    "period_end": "2026-03-28",
    "center_id": "<center_id>"
  }'

# Process payments (auto-calculates per farmer)
curl -X POST "http://localhost:8000/api/v1/payments/cycles/<cycle_id>/process" \
  -H "$AUTH"
# Response: net_payout, farmers_count, total_litres, deductions, bonuses

# View all cycles
curl "http://localhost:8000/api/v1/payments/cycles" -H "$AUTH"
```

### Step 7: Loans

```bash
# Farmer applies for loan
curl -X POST http://localhost:8000/api/v1/payments/loans/apply \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "farmer_id": "<farmer_id>",
    "loan_type": "cattle_purchase",
    "principal_amount": 50000,
    "tenure_months": 12,
    "interest_rate_pct": 8.5
  }'
# Response: emi_amount calculated via reducing balance formula

# Admin approves loan
curl -X PUT "http://localhost:8000/api/v1/payments/loans/<loan_id>/approve" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"interest_rate_pct": 8.5}'

# List loans
curl "http://localhost:8000/api/v1/payments/loans?farmer_id=<farmer_id>" -H "$AUTH"
```

### Step 8: Cattle Insurance

```bash
# Create insurance policy
curl -X POST http://localhost:8000/api/v1/payments/insurance \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "farmer_id": "<farmer_id>",
    "cattle_id": "<cattle_id>",
    "insurer_name": "IFFCO Tokio",
    "sum_insured": 80000,
    "premium_amount": 3200,
    "govt_subsidy_pct": 50,
    "start_date": "2026-03-28",
    "end_date": "2027-03-28"
  }'
# Response: farmer_premium = 1600 (50% govt subsidy)

# File a claim
curl -X POST "http://localhost:8000/api/v1/payments/insurance/<insurance_id>/claim" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"claim_amount": 50000, "claim_reason": "Cattle illness treatment"}'
```

### Step 9: Govt Subsidies

```bash
# Apply for subsidy
curl -X POST http://localhost:8000/api/v1/payments/subsidies \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "farmer_id": "<farmer_id>",
    "scheme": "nabard_dairy",
    "scheme_name": "NABARD Dairy Entrepreneurship Development",
    "applied_amount": 100000
  }'

# Admin updates status
curl -X PUT "http://localhost:8000/api/v1/payments/subsidies/<subsidy_id>/status" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"status": "approved", "approved_amount": 85000}'

# View all applications
curl "http://localhost:8000/api/v1/payments/subsidies?farmer_id=<farmer_id>" -H "$AUTH"
```

### Step 10: Farmer Ledger (complete financial overview)

```bash
curl "http://localhost:8000/api/v1/payments/ledger/<farmer_id>" -H "$AUTH"
# Response: total_earnings, total_loans_outstanding, total_subsidies_received,
#           recent_payments, loans, insurance_policies
```

### Step 11: Demand Forecasting & Anomaly Detection

```bash
# Get 7-day demand forecast
curl "http://localhost:8000/api/v1/collection/centers/<center_id>/forecast?days=7" \
  -H "$AUTH"

# Check if today's collection is anomalous
curl "http://localhost:8000/api/v1/collection/centers/<center_id>/anomaly?today_litres=500" \
  -H "$AUTH"
```

---

## Grading & Pricing Reference

### Milk Quality Grades
| Grade    | Fat %  | SNF %  |
|----------|--------|--------|
| A        | >= 4.0 | >= 8.5 |
| B        | >= 3.5 | >= 8.0 |
| C        | >= 3.0 | >= 7.5 |
| Rejected | Below C minimums   |

### Fat-Based Pricing
```
rate_per_litre = 30.0 + max(0, fat_pct - 3.0) * 5.0
```
Examples: fat=3.0 -> 30/L, fat=4.0 -> 35/L, fat=5.0 -> 40/L

### Quality Bonus
- Grade A: +2.00/litre
- Grade B: +1.00/litre
- Grade C: no bonus

### Cold Chain Thresholds
- Normal: <= 4.5C
- Warning alert: > 4.5C
- Critical alert: > 8.0C
- Milk rejected: > 8.0C

---

## API Endpoints Summary (40+ endpoints)

### Auth
- `POST /api/v1/auth/send-otp`
- `POST /api/v1/auth/verify-otp`
- `POST /api/v1/auth/refresh`
- `GET  /api/v1/auth/me`

### Farmers & Cattle
- `CRUD /api/v1/farmers`
- `CRUD /api/v1/cattle`
- `GET  /api/v1/farmers/me/dashboard`

### Health & Triage
- `CRUD /api/v1/health-records`
- `POST /api/v1/triage`

### Vet Search & Consultation
- `GET  /api/v1/vets/search` (GPS, pincode, fee, rating filters)
- `POST /api/v1/vets/register`
- `CRUD /api/v1/consultations`

### Milk Collection (NEW)
- `POST /api/v1/collection/centers`
- `GET  /api/v1/collection/centers`
- `GET  /api/v1/collection/centers/{id}/dashboard`
- `POST /api/v1/collection/milk`
- `GET  /api/v1/collection/milk`
- `POST /api/v1/collection/cold-chain/reading`
- `GET  /api/v1/collection/cold-chain/alerts`
- `POST /api/v1/collection/routes`
- `GET  /api/v1/collection/centers/{id}/forecast`
- `GET  /api/v1/collection/centers/{id}/anomaly`

### Payments & Finance (NEW)
- `POST /api/v1/payments/cycles`
- `POST /api/v1/payments/cycles/{id}/process`
- `GET  /api/v1/payments/ledger/{farmer_id}`
- `POST /api/v1/payments/loans/apply`
- `PUT  /api/v1/payments/loans/{id}/approve`
- `POST /api/v1/payments/insurance`
- `POST /api/v1/payments/insurance/{id}/claim`
- `POST /api/v1/payments/subsidies`
- `PUT  /api/v1/payments/subsidies/{id}/status`

### Vendor & Cooperative
- `POST /api/v1/vendor/register`
- `POST /api/v1/cooperative/register`
- Role-specific dashboards

### Admin
- `GET /api/v1/admin/dashboard`
- `GET /api/v1/super-admin/dashboard`

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `Connection refused` on port 5432 | Run `docker compose up -d postgres` |
| `relation does not exist` | Backend auto-creates tables on startup via `init_db()` |
| Tests hang in terminal | Redirect: `python -m pytest > /tmp/out.txt 2>&1` then read the file |
| OTP not working | Use dev phones: `99999xxxxx` with OTP `123456` |
| `'str' object has no attribute 'hex'` | UUID conversion bug - ensure latest code is pulled |
