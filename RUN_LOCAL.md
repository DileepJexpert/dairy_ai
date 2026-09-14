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

### Product image uploads (new)

Update dependencies once, then restart your usual backend and Flutter commands:

```powershell
Set-Location C:\dileepkm\Learning\dairy_ai\backend
python -m pip install -r requirements.txt

Set-Location C:\dileepkm\Learning\dairy_ai\mobile
flutter pub get
```

No new database migration or rebuild is needed for image uploads. Open admin
**Products → Manage product images** (photo icon), or seller **Catalogue → Images**.
Upload a JPEG, PNG or WebP, choose the primary image, and refresh the storefront.
The full admin catalogue also has photo icons on its SKU/variant rows.
Draft previews require your authenticated admin/seller session.

Files are saved under `backend/storage/product-media` when running from the
backend directory. Set `PRODUCT_MEDIA_DIR` to an absolute folder if desired.
Back up this folder **and PostgreSQL together**. Files are excluded from Git;
committing code does not back up uploaded photos. Docker Compose uses its
`product_media` volume; do not remove volumes when restarting services.
No S3 account is used. On hosting, this directory requires persistent disk.
Removing an image detaches it from that product; original bytes are retained
so other seller offers using the image do not break. Orphan-file cleanup is
not automatic. Uploads are limited to 12 images per SKU, 5 MB per upload,
16 million pixels and still images only. Concept families without SKUs retain
their current URL/asset-based images in this slice.

### One-time setup for backend-managed admin controls

With PostgreSQL running, stop the backend and run this **once** for an existing database:

```powershell
Set-Location C:\dileepkm\Learning\dairy_ai\backend
python -m scripts.initialize_commerce_admin
python -m scripts.initialize_customer_commerce
```

This creates only the four new commerce tables (coupons, coupon redemptions,
batch certificates and audit history). It does not reset products, users, carts,
or orders. Optional test coupons can be inserted with
`python -m scripts.initialize_commerce_admin --seed-demo`; existing coupon edits
are never overwritten. A fresh `rebuild_local_database --seed-demo` also includes
these tables and coupons. Do not run a rebuild merely to add these tables.

Restart the backend and Flutter after setup. Admin **Seller Offers**, **Inventory**,
**Coupons**, **Batch Certificates**, **Sellers & KYC**, and **Audit Trail** now use
database records. Coupons can be edited or paused; checkout revalidates their
expiry, minimum and cap. Certificates remain private until marked `CERTIFIED`
with a report URL and certifier. The storefront's Quality & Research links load
the published reports from the backend. No paid storage service is required.

The live shop no longer falls back to Flutter demo products when the API fails.
Only persisted products and published concept families appear. Add missing
catalogue content in admin or seed it explicitly; API errors now show a retry state.

The second initializer adds seven customer-commerce tables without deleting or
altering existing records: wishlist, saved cart items, order contact notes,
order events, help content, support enquiries, and customer preferences. It seeds
initial pre-launch FAQs only if help content is absent. It is safe to rerun.

After restarting both servers, test:

1. Sign in, save a wishlist item, refresh Chrome, and confirm it remains saved.
2. Move a cart item to Saved for later and back. These are atomic server actions.
3. Complete pre-launch checkout. Your Orders reloads its history from the server;
   cancelling an interest persists and does not create a payment or refund.
4. In admin ecommerce, open Purchase Interests and click a customer row to save
   contact status and internal notes. Notes are never returned to customers.
5. Use the admin header's support-agent icon to edit FAQs/contact content and
   reply to enquiries. Customers can read saved replies on the Help page and in
   notifications; there is no paid messaging service.
6. Seller/admin fulfillment lists only paid commercial orders. Pre-launch
   interests cannot be shipped. Courier references must be entered manually.
7. Profile name/location/language and notification visibility preferences save
   to the backend. Wallet funding and payouts are explicitly unavailable.

See [Backend integration coverage](docs/ECOMMERCE_BACKEND_COVERAGE.md) for scope,
remaining preview features, and manual acceptance checks.

If you have already initialized the database, run:

```powershell
Set-Location C:\dileepkm\Learning\dairy_ai\backend
$env:APP_ENV = 'development'
$env:COMMERCE_TAXONOMY_ENABLED = 'true'
$env:PRELAUNCH_MODE = 'true'
$env:INIT_DB_ON_STARTUP = 'false'
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8001

# Optional Gmail SMTP for password reset email (use a Gmail App Password,
# never your normal Gmail password). Leave blank to receive a local reset link.
# $env:SMTP_HOST = 'smtp.gmail.com'
# $env:SMTP_PORT = '587'
# $env:SMTP_USERNAME = 'your-account@gmail.com'
# $env:SMTP_PASSWORD = 'your-app-password'
# $env:SMTP_FROM_EMAIL = 'your-account@gmail.com'
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

## 4. Login

Customers create an account with a 10-digit mobile number and a password of at least 8 characters. Customer sign-in does not send an SMS and does not require a paid OTP provider.

These staff accounts are created only when the rebuild is run with `--seed-demo`:

| Account | Phone | Local development OTP |
|---|---|---|
| Commerce admin | `9999900000` | `123456` |
| Vendor | `9999900090` | `123456` |

Request an OTP using the staff login page before entering it. The fixed demo OTP works only in development/test. Do not use these staff accounts in production.

Everyone can browse the shop without login. Cart and interest registration require login. In pre-launch mode, checkout stores the requested items and callback details in PostgreSQL; it does not collect payment, reduce inventory or create a shipment. Admin product publishing uses the backend catalogue screen at `/#/admin/commerce/products`.

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
