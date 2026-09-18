# Milterra & Katixo - Development Commands Reference

This guide contains full, ready-to-run copy-paste commands with explicit directory locations (`Set-Location`) for starting all services, databases, and running tests.

---

## ⚡ Option 1: Start Everything in One Go (One-Click)

Run this single PowerShell script from the repository root:

```powershell
Set-Location -Path "c:\dileepkm\Learning\dairy_ai-with-backend"
.\start-dev.ps1
```

Or execute the one-liner directly in PowerShell:

```powershell
Set-Location -Path "c:\dileepkm\Learning\dairy_ai-with-backend"; docker compose -f infra/docker-compose.yml up -d postgres; Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location -Path 'c:\dileepkm\Learning\dairy_ai-with-backend\backend'; uvicorn app.main:app --reload --port 8000"; Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location -Path 'c:\dileepkm\Learning\dairy_ai-with-backend\mobile'; flutter run -d chrome --web-port 5051"
```

---

## 🛠️ Option 2: Step-by-Step Commands (Individual Terminals)

### 1. Start PostgreSQL / TimescaleDB Database
```powershell
Set-Location -Path "c:\dileepkm\Learning\dairy_ai-with-backend"
docker compose -f infra/docker-compose.yml up -d postgres
```
- **DB Host:** `localhost:5432`
- **Database:** `dairy_ai` | **User:** `dairy` | **Password:** `dairy123`
- **Check DB Status:** `docker compose -f infra/docker-compose.yml ps`
- **Stop DB:** `docker compose -f infra/docker-compose.yml stop postgres`

---

### 2. Start FastAPI Backend
```powershell
Set-Location -Path "c:\dileepkm\Learning\dairy_ai-with-backend\backend"
uvicorn app.main:app --reload --port 8000
```
- **Backend API:** [http://localhost:8000](http://localhost:8000)
- **Interactive Swagger Docs:** [http://localhost:8000/docs](http://localhost:8000/docs)

---

### 3. Start Flutter Frontend (Web Storefront)
```powershell
Set-Location -Path "c:\dileepkm\Learning\dairy_ai-with-backend\mobile"
flutter run -d chrome --web-port 5051
```
*(To use Microsoft Edge instead: `flutter run -d edge --web-port 5051`)*

- **Milterra D2C Vedic Ghee Storefront:** [http://localhost:5051/shop](http://localhost:5051/shop)
- **Katixo Farmer & Machinery Hub:** [http://localhost:5051/marketplace](http://localhost:5051/marketplace)

---

## 🧪 Verification & Test Commands

### Run Frontend Tests & Static Analysis
```powershell
Set-Location -Path "c:\dileepkm\Learning\dairy_ai-with-backend\mobile"
flutter analyze lib/features/milterra/ lib/features/farmer_hub/ lib/features/marketplace/ lib/app/router.dart
flutter test test/commerce_foundation_test.dart
```

### Run Backend Tests
```powershell
Set-Location -Path "c:\dileepkm\Learning\dairy_ai-with-backend\backend"
pytest tests/test_commerce_taxonomy.py
```
