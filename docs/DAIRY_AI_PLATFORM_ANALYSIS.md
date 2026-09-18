# DairyAI & MILTERRA — Platform Overview & Architecture Analysis

## 1. Executive Summary & Product Thesis

**DairyAI & MILTERRA** is India's first full-stack **Dairy Operating System + Trusted Commerce & Healthcare Network**. Rather than serving merely as an informational advisory chatbot or standalone catalog, the platform connects the complete physical lifecycle of dairy farming in India:

```
                            ┌─────────────────────────────────────────────────────────┐
                            │                    DairyAI & MILTERRA                   │
                            │        India's First Full-Stack Dairy Problem Solver    │
                            └─────────────────────────────────────────────────────────┘
                                                         │
         ┌─────────────────────────┬─────────────────────┴───────────────────┬────────────────────────┐
         ▼                         ▼                                         ▼                        ▼
  🌾 1. Farm OS          🩺 2. Health & AI                        🛒 3. Market & Money        🤝 4. Network & Trust
  • Cattle herd digital    • Rule + ML disease triage             • Milterra D2C Storefront   • Vet Connect ("Practo for
    records & timelines      (Mastitis, FMD, HS, BQ, Theileriosis)  (A2 Ghee, Cultured          Cattle" tele-triage & video)
  • Milk yield tracking    • ESP32 IoT Collar telemetry             Butter, Paneer, Feed)     • Cooperative & BMC network
    (Fat/SNF & session)      (Temp, pulse, rumination, activity)  • Pack variants & cart        (Intake slips, cold chain)
  • Ration & feed planner  • Medicine withdrawal safety             drawer (Amazon-style)     • Public Milk Purity Tool
  • Breeding & heat cycle    (Blocks milk sale if treated)        • Vendor Fulfillment Hub      (FSSAI tracker, lab reports)
  • Farm P&L & transactions• Vision BCS & udder scoring             (AWB, shipping labels)    • Bharat Pashudhan (INAPH)
```

The platform's primary long-term differentiator is its **Trust Layer**: marketplace claims, milk quality, and animal health assertions are grounded in verifiable longitudinal records (milk logs, veterinary prescriptions, temperature/activity telemetry, vaccination dates, and government Pashu Aadhaar records) rather than seller-entered marketing text.

---

## 2. The Four Strategic Pillars

### 🌾 Pillar 1: Farm OS (Farmer Operating System)
- **Longitudinal Animal Health Records**: Digital identities for cattle tracking breed, age, reproductive state (lactating, pregnant, dry, sick), and pedigree.
- **Milk Recording & Economics**: Session-by-session milk logging (morning/evening sessions, fat %, SNF %, buyer details, realized net payouts).
- **AI Ration & Feed Optimizer**: Stage-based nutrition plans accounting for cattle weight, lactation phase, and local mandi ingredient prices.
- **Breeding & Reproduction Tracking**: Milestones for heat detection, artificial insemination (AI), pregnancy verification, expected calving dates, and dry-off cycles.
- **Farm Finance & Unit Economics**: Automated farm P&L reports, feed cost per litre calculations, and financial ledger management.

### 🩺 Pillar 2: Health & Intelligence
- **Intelligent Disease Triage**: Diagnostic algorithms covering critical bovine conditions (Mastitis, Foot & Mouth Disease, Hemorrhagic Septicemia, Black Quarter, Theileriosis).
- **IoT Collar Telemetry**: Continuous real-time sensor streams (DS18B20 body temperature, heart rate, MPU6050 accelerometer for rumination/activity).
- **Food Safety & Medicine Withdrawal Windows**: Active tracking of antibiotic and pharmaceutical withdrawal periods, programmatically flagging and blocking unsafe milk entries from cooperative collection or market sales.
- **Computer Vision Scoring**: Mobile camera analysis for Body Condition Scoring (BCS 1–5), udder health, and lameness detection.
- **Multilingual AI Assistant**: Contextual chat and voice interaction powered by LLM integration and the Indian Government's Bhashini (ULCA/Dhruva) platform.

### 🛒 Pillar 3: Market & Money (Commerce Spine)
- **MILTERRA Pure Dairy Storefront**: Consumer-facing luxury storefront selling verified A2 Sahiwal cow ghee, artisanal bilona ghee, Murrah buffalo ghee, and fresh paneer with batch-level lab certificates.
- **Livestock Marketplace**: Evidence-backed cattle trading featuring verified milk yield history and veterinary inspection badges.
- **Cattle Nutrition & Farm Supplies**: Farm inputs, stage-specific feed, and mineral supplements with pre-launch demand validation mode (`PRELAUNCH_MODE=true`).
- **Vendor Fulfillment Console**: Seller portal for inventory management, AWB generation, shipping label printing, and lab certificate management.

### 🤝 Pillar 4: Network & Trust
- **Vet Connect ("Practo for Cattle")**: Telehealth network with verified veterinarians, appointment scheduling, Agora RTC live video calls, and digital prescription creation.
- **Dairy Cooperative & BMC Network**: Operations for Bulk Milk Chilling (BMC) centers, electronic milk collection slips, automatic quality-based rate chart calculations, route logistics, and chilling vat temperature monitors.
- **Public Milk Purity Checker**: Consumer transparency portal allowing users to search commercial milk brands, inspect lab test reports, track FSSAI violations, and compare purity scores.
- **Government & Ecosystem Integrations**: Pashu Aadhaar (12-digit national animal UID via INAPH/Pashudhan Sanjivani), Mandi ingredient price feeds, and Government subsidy discovery.

---

## 3. The Five Role-Based Personas (Flutter Navigation Shells)

The frontend uses a single Flutter codebase with role-based shell routing (`lib/app/router.dart`):

| Persona | Shell / Entry Route | Primary Capabilities |
|---|---|---|
| **Farmer** | `FarmerShell` (`/home`) | Herd management, milk recording, feed plans, breeding alerts, IoT collar status, farm ledger, and AI chat. |
| **Veterinarian** | `VetShell` (`/vet-dashboard`) | Consultation queue, video calls via Agora RTC, digital prescriptions with withdrawal notices. |
| **Vendor / Seller** | `VendorShell` (`/vendor-dashboard`) | Catalog management, local product image uploads, order fulfillment, AWB generation, and batch certificates. |
| **Cooperative Operator** | `CooperativeShell` (`/cooperative-dashboard`) | BMC intake slips, fat/SNF entry, rate chart settlement, member ledgers, and cold-chain temperature telemetry. |
| **Platform Administrator** | `AdminShell` (`/admin-dashboard`, `/admin/ecommerce`) | Vet/vendor KYC verification, dynamic taxonomy/category tree editor, coupon management, clickstream analytics, and audit logs. |
| **Public Guest / Consumer** | Public Routes (`/shop`, `/purity`) | Atmospheric luxury storefront, pack selection, cart drawer, checkout, order tracking, and public milk brand purity search. |

---

## 4. System Architecture & Technical Stack

```
[Flutter 3.x Mobile & Web (Riverpod, GoRouter, Dio, Cormorant Garamond / StoreTheme)]
                                    │ (REST / JSON)
                                    ▼
       [FastAPI Backend (Python 3.12, 100% Async, Repository Pattern)]
                                    │
    ┌───────────────────────────────┼───────────────────────────────┬──────────────────────────┐
    ▼                               ▼                               ▼                          ▼
[PostgreSQL 16 +              [MQTT Broker]                   [Redis / Celery]         [External APIs]
 TimescaleDB                   (Eclipse Mosquitto)             (Background queues)      • WhatsApp Cloud API
 (60+ Relational Tables        Port 1883/9001                   (Lab Tier profile)      • Bhashini (ULCA Indian Lang)
 + Sensor Hypertables)]             ▲                                                   • Agora RTC (Video)
                                    │                                                   • Razorpay (Payments)
                            [ESP32 Collars]                                             • Bharat Pashudhan (INAPH)
                            (C++ Firmware / DS18B20,
                             Pulse, MPU6050 Accelerometer)
```

### Two-Tier Operational Model
1. **Tier 1: Cloud / MILTERRA Storefront (Production Mode)**
   - Optimized for near **₹0/month** operational cost using serverless scale-to-zero compute (Cloud Run / Railway).
   - Flags: `IOT_ENABLED=false`, `MQTT_ENABLED=false`, `REDIS_ENABLED=false`, `TIMESCALE_FEATURES_ENABLED=false`.
   - FastAPI boots instantly without cold-start dependencies on MQTT or Redis brokers.
2. **Tier 2: Local Lab / Engineering Mode**
   - Full hardware simulation and telemetry environment using Docker Compose profiles (`docker compose --profile iot up`).
   - Activates Mosquitto MQTT broker, Redis cache/queues, TimescaleDB hypertables, and simulated collar telemetry (`backend/scripts/mock_sensor_simulator.py`).

### Technology Stack Summary
- **Backend**: Python 3.12, FastAPI, SQLAlchemy 2.0 (async with `mapped_column`), Pydantic v2, PostgreSQL 16 + TimescaleDB.
- **Frontend**: Flutter 3.x, Riverpod (state management), GoRouter, Dio (HTTP client), Freezed / JSON Serializable.
- **IoT Firmware**: ESP32 C++ (PlatformIO / Arduino), DS18B20 temperature probe, analog pulse sensor, MPU6050 accelerometer, MQTT publish/subscribe.
- **Design System**: `mobile/lib/app/store_theme.dart` (Cormorant Garamond serif headings, forest green, warm cream, restrained gold accents).
- **Integrations**: WhatsApp Business Cloud API, Bhashini ULCA/Dhruva STT/TTS, Agora RTC, Razorpay, Bharat Pashudhan (INAPH).

---

## 5. Current Codebase State & Recent Milestones

- **Git Status**: Clean working tree on `main` (ahead of origin by 2 local commits).
- **Recent Implementations**:
  1. Local product image upload and static media serving (`/api/v1/product-media`).
  2. Vendor Order Fulfillment Hub with AWB generation and shipping slip generation.
  3. Batch Quality Lab Test Certificate management with public verification endpoints.
  4. Amazon-style pack variant selection and cart drawer integration.
  5. Admin clickstream analytics, cart intelligence, and traffic origin tracking.
  6. Resolved authentication redirect loops across admin, seller, and storefront routes.
