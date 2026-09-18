# ==============================================================================
# Milterra & Katixo - All-in-One Dev Startup Script (PowerShell)
# ==============================================================================

Write-Host ">>> 1. Starting TimescaleDB/PostgreSQL via Docker Compose..." -ForegroundColor Green
Set-Location -Path "c:\dileepkm\Learning\dairy_ai-with-backend"
docker compose -f infra/docker-compose.yml up -d postgres

Write-Host ">>> 2. Launching FastAPI Backend (Port 8000)..." -ForegroundColor Green
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location -Path 'c:\dileepkm\Learning\dairy_ai-with-backend\backend'; Write-Host '--- FastAPI Backend (http://localhost:8000) ---' -ForegroundColor Cyan; uvicorn app.main:app --reload --port 8000"

Write-Host ">>> 3. Launching Flutter Web Frontend (Port 5051)..." -ForegroundColor Green
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location -Path 'c:\dileepkm\Learning\dairy_ai-with-backend\mobile'; Write-Host '--- Milterra & Katixo Storefront (http://localhost:5051) ---' -ForegroundColor Cyan; flutter run -d chrome --web-port 5051"

Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Yellow
Write-Host "All services started successfully!" -ForegroundColor Yellow
Write-Host "1. Milterra D2C Ghee Storefront:  http://localhost:5051/shop" -ForegroundColor Yellow
Write-Host "2. Katixo Farmer & Machinery Hub: http://localhost:5051/marketplace" -ForegroundColor Yellow
Write-Host "3. Backend API Documentation:     http://localhost:8000/docs" -ForegroundColor Yellow
Write-Host "4. PostgreSQL Database:           localhost:5432 (DB: dairy_ai)" -ForegroundColor Yellow
Write-Host "==============================================================================" -ForegroundColor Yellow
