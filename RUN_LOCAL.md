# Run Milterra locally on Windows

Use this guide for the current Flutter storefront and FastAPI backend. Commands are for **PowerShell**. Copy only the commands, not the `PS C:\...>` prompt. Paths use `dairy_ai` (no backslash before the underscore).

The examples use **backend port 8001** because Windows refused port 8000 with `WinError 10013`. Flutter runs on **5051**. Keep Docker Desktop, the backend terminal and the Flutter terminal running while testing.

## 1. Start PostgreSQL and Redis

Open Docker Desktop and wait until its engine is running. Then open PowerShell:

```powershell
Set-Location C:\dileepkm\Learning\dairy_ai
docker compose -f infra/docker-compose.yml up -d postgres redis
docker compose -f infra/docker-compose.yml ps postgres redis
```

Both services should show as running. This starts existing containers without resetting data.

## 2. Start the backend — terminal 1

If you have already initialized the database, run:

```powershell
Set-Location C:\dileepkm\Learning\dairy_ai\backend
$env:APP_ENV = 'development'
$env:COMMERCE_TAXONOMY_ENABLED = 'true'
$env:INIT_DB_ON_STARTUP = 'false'
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8001
```

Wait for `Application startup complete`. Open [Backend API docs](http://127.0.0.1:8001/docs). This page is the Python API, **not the shopping UI**.

The backend continuing to occupy the terminal is normal: it is serving requests, not stuck. Leave it open. These environment variables apply to this PowerShell session; run them again in a newly opened terminal.

If the database has never been initialized with the new schema, complete section 5 before starting the backend. A previous `DRY RUN` message did not initialize it.

## 3. Start Flutter — terminal 2

Open a separate PowerShell terminal:

```powershell
Set-Location C:\dileepkm\Learning\dairy_ai\mobile
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5051 --dart-define=API_BASE_URL=http://127.0.0.1:8001
```

Wait for Flutter to report that the web server is ready. In your **usual Chrome profile**, manually open:

- [Milterra shop](http://127.0.0.1:5051/#/shop)
- [Commerce admin](http://127.0.0.1:5051/#/admin/commerce) — requires an authorized admin login

Using `web-server` lets you use your existing Chrome profile. Leave this terminal open too.

Optional: to let Flutter launch its own debugging Chrome window instead, stop the web-server run first and use:

```powershell
flutter run -d chrome --web-port 5051 --dart-define=API_BASE_URL=http://127.0.0.1:8001
```

## 4. Demo login

These accounts are created only when the rebuild is run with `--seed-demo`:

| Account | Phone | Local development OTP |
|---|---|---|
| Commerce admin | `9999900000` | `123456` |
| Vendor | `9999900090` | `123456` |

Request an OTP using the login page before entering it. The fixed demo OTP works only in development/test. Do not use these accounts in production.

Everyone can browse the shop without login. Cart actions require login. The commerce admin currently manages departments/categories; the complete product/offer administration is still being developed.

## 5. Optional: initialize or completely reset the local database

**Destructive: this deletes all current data in the selected database's public schema, including accounts, products, carts and orders. Do not run this on every restart. Successful deletion cannot be undone without a backup.**

Stop the backend and any workers first with `Ctrl+C`, but leave PostgreSQL running. In the backend terminal:

```powershell
Set-Location C:\dileepkm\Learning\dairy_ai\backend
$env:APP_ENV = 'development'

# Preview only: no connection, deletion or schema creation.
python -m scripts.rebuild_local_database
```

Check that the printed target is your intended disposable local `dairy_ai` database. If it is unexpected, stop and inspect your backend `.env` / `DATABASE_URL`; do not confirm a different database blindly.

To actually erase it and create the full current schema, categories and demo products/accounts:

```powershell
python -m scripts.rebuild_local_database --execute --confirm-database dairy_ai --seed-demo
```

Wait for `Rebuild complete`, then run the backend commands from section 2. Refresh the shop and sign in again because the old accounts/tokens may no longer match the fresh database. No `alembic upgrade head` is needed: the current disposable-development workflow builds from all current models, without replaying the historical ALTER migration chain.

Further details: [Database rebuild guide](docs/LOCAL_DATABASE_REBUILD.md).

## 6. Troubleshooting

### `WinError 10013` / port 8000 refused

Use port **8001** as in sections 2 and 3. The backend port and Flutter's `API_BASE_URL` must match. If you change the API URL, stop and restart Flutter with the updated `--dart-define`; a browser refresh alone does not change that build setting. A database reset does not fix a socket/port error.

If 8001 also fails, inspect listeners without stopping unrelated processes:

```powershell
Get-NetTCPConnection -State Listen -LocalPort 8000,8001,5051 -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,OwningProcess
```

No listener does not prove a port is usable; Windows can also reserve ports. Do not disable the firewall or kill unknown processes as a workaround.

### Docker Linux engine pipe not found

Start Docker Desktop, wait for its Linux engine, then repeat section 1. The Compose warning that `version` is obsolete is separate from an engine connection failure.

### Flutter says port 5051 is already in use

Stop the old Flutter/static-server run in its own terminal. Alternatively, use `--web-port 5052` in section 3 and open `http://127.0.0.1:5052/#/shop`. Keep the backend API URL at port 8001.

### `DioException`, network error or CORS message

First check that [API docs](http://127.0.0.1:8001/docs) open and that the backend terminal is still running. Confirm Flutter was launched with `API_BASE_URL=http://127.0.0.1:8001`. The local backend allows localhost/127.0.0.1 browser origins in development mode. If requests still fail, inspect the backend logs and browser network error; do not assume every network error is CORS.

### Python cannot import a dependency

Use the Python environment where this project's dependencies were installed. Activate your existing virtual environment if you use one. Install missing project dependencies with that same interpreter:

```powershell
Set-Location C:\dileepkm\Learning\dairy_ai\backend
python -m pip install -r requirements.txt
```

## 7. Stop and restart safely

- Press `Ctrl+C` in the Flutter and backend terminals to stop their servers.
- To stop just the local database/cache containers without removing data:

```powershell
Set-Location C:\dileepkm\Learning\dairy_ai
docker compose -f infra/docker-compose.yml stop postgres redis
```

Next time, repeat sections **1, 2 and 3**. Skip the reset unless you intentionally want to erase the local data. Do not use `docker compose down -v` for an ordinary shutdown; it removes volumes.
