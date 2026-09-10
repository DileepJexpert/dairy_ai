# Disposable local database: full rebuild

The project is not deployed and local data is disposable. The current workflow is **recreate the complete schema from current SQLAlchemy models**, not a chain of ALTER migrations. Historical Alembic files remain for reference; do not run `alembic upgrade head` against this rebuilt model baseline. A reviewed production baseline must be established before hosting.

## What the command does

- By default: print the target and exit without connecting to the database.
- With explicit execution and exact database-name confirmation: delete the selected local database's `public` schema, create all registered application tables/enums/indexes/constraints, and seed seven department/category nodes plus the taxonomy write lock.
- With `--seed-demo`: also create four classified dairy products with stock, one vendor account and one admin account. No real customer/order data is retained.
- Restrict execution to `APP_ENV=development` or `test`, a loopback PostgreSQL URL, a non-system database, and no connection-query overrides. Refuse extra user schemas; the repository's TimescaleDB extension-owned schemas are supported. Preserve/recreate the installed TimescaleDB extension as needed.
- Run destructive DDL, schema creation and seeds in one PostgreSQL transaction. An error rolls the transaction back; lock contention fails after five seconds. Successful deletion is not recoverable without your own backup.

This is a dedicated, disposable application database tool. It does not reset Redis, uploaded files or other Docker volumes. Stop backend/workers first. Never point a local tunnel at a production database and never run while other applications are using the database. Loopback checks cannot identify the destination behind a tunnel.

## PowerShell: clean reset and start

Start Docker Desktop first. From the repository:

```powershell
Set-Location C:\dileepkm\Learning\dairy_ai
docker compose -f infra/docker-compose.yml up -d postgres redis
Set-Location backend

# Read-only preview: check the printed database name before proceeding.
python -m scripts.rebuild_local_database

# DESTRUCTIVE: delete all current dairy_ai public-schema data and create fresh demo data.
python -m scripts.rebuild_local_database --execute --confirm-database dairy_ai --seed-demo

$env:COMMERCE_TAXONOMY_ENABLED = 'true'
$env:INIT_DB_ON_STARTUP = 'false'
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

The script reads the backend environment/.env. Do not override an unexpected target casually: inspect it. `--confirm-database` must match that configured target exactly. Run the reset command again whenever you deliberately want fresh data; **normal backend startup never calls this script**.

Second terminal, using your usual Chrome profile:

```powershell
Set-Location C:\dileepkm\Learning\dairy_ai\mobile
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5051 --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Open `http://127.0.0.1:5051/#/shop` in Chrome. Stop any old process already listening on 5051 first; do not kill unrelated processes. If 8000 is blocked, use 8001 in **both** backend and Flutter commands.

Demo admin: `9999900000`; demo vendor: `9999900090`. Request an OTP through the login page. Existing local development/test OTP behavior uses `123456` for these demo phone numbers; that shortcut is disabled outside development/test. Do not deploy demo accounts. Logged-in admin can open `/#/admin/commerce`. Everyone can browse `/#/shop`; cart actions require login.

## Development rules

1. Update models and `app/models/__init__.py` first. Keep PostgreSQL enum names unique when definitions differ.
2. Update seed contracts and tests alongside schema changes. Never seed invented clinical claims, nutrition instructions or promotional prices.
3. Use this full rebuild for disposable development data. No hidden reset at startup, no old data backfill assumption and no Alembic stamp pretending historical migrations ran.
4. Once real data must be retained or deployment begins, stop using this workflow and design reviewed versioned migrations/backups.

## Verification

Safety and API tests: `python -m pytest tests/test_database_rebuild.py tests/test_commerce_taxonomy.py tests/test_orders.py tests/test_cart.py tests/test_delivery_addresses.py -q`.

The PostgreSQL rebuild test is skipped unless `REBUILD_TEST_DATABASE_URL` explicitly targets a dedicated local database whose name starts with `milterra_rebuild_verify_`. It deletes that database's public schema while testing fresh creation, repeat reset, enum compatibility and transaction rollback. Never use the application's database for this test.
