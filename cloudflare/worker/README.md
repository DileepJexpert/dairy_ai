# Isolated Cloudflare Python Worker compatibility proof

## Real COD orders with restricted delivery coverage (27 September 2026)

For customer orders on the current Cloudflare API, keep `CUSTOMER_AUTH_ENABLED=true`, set `TEST_COMMERCE_ENABLED=false`, `LIVE_COD_ENABLED=true`, and set `LIVE_COD_PINCODES` to the explicitly approved six-digit delivery PINs. Each PIN must also have an active `serviceable_pincodes` row with an approved delivery fee. Missing or conflicting switches and an empty/invalid allowlist fail closed. Both the public PIN check and server-side quote/order placement use this allowlist; a D1 row alone does not open a delivery area. Existing test orders retain `is_test_order=1`; new real COD orders have `is_test_order=0` and `payment_status=pending` until seller-recorded collection. The online payment capability remains unavailable. Do not use unverified seeded rates for real customers.

Build the storefront without `TEST_COMMERCE=true` for this mode. Run `tests/test_test_checkout.py` to verify real COD classification, restricted coverage, quote/checkout, idempotent replay, cancellation and stock restoration. The first approved delivery area is PIN `201305` with a zero delivery fee. This release does not book a courier or verify phone/email ownership; fulfill and collect COD through the existing seller operations flow.

## Developer test checkout (26 September 2026)

Migration 0006 adds address metadata/snapshots and `orders.is_test_order`. Set `TEST_COMMERCE_ENABLED=true` only with `ENVIRONMENT=staging`, `local` or `test` to allow the customer password sessions to call the D1 commerce routes. Configure explicit test PIN coverage. Registration, address, cart, authoritative quote, COD checkout, replay, history and cancellation are connected; payment capabilities still advertise online payments unavailable. The Flutter test build uses `TEST_COMMERCE=true` and the Worker origin for both `API_BASE_URL` and `AUTH_API_BASE_URL`.

Run `tests/test_test_checkout.py` with the existing Worker suite. Remote acceptance: `python tests/verify_test_checkout_runtime.py --base-url <worker-url> --product-id <available-inventory-id>`. It creates labelled synthetic data, cancels its order to restore stock, revokes its session and prints record IDs. Keep this data labelled; reset it only with an explicit test-data cleanup operation. `src/location_master.py` is generated from the authoritative bundled `backend/app/data/india_locations.json`; regenerate it when that source changes.

## Customer authentication release (26 September 2026)

Customer password registration, login, profile, refresh and logout now run on this Python Worker with D1 migration `0005_customer_auth.sql`. Set `CUSTOMER_AUTH_ENABLED=true`, provision `AUTH_SECRET` securely with Wrangler, and bind `PASSWORD_HASHER` to the separately deployed [private password helper](../password-hasher/README.md). Do not put secrets in config or Git. Actual remote acceptance passed; this supersedes the earlier disabled-auth infrastructure snapshot below.

Only `/api/v1/auth/*` is enabled for the public client through `AUTH_API_BASE_URL`. Keep the commerce API disabled until separate acceptance passes. New customer accounts have unverified contact details; OTP/password recovery and historical account import are not implemented. The frontend explains this limitation. Tests: `uv run pytest -q tests/test_customer_auth.py tests/test_commerce.py tests/test_api_contract.py tests/test_compat.py`. Runtime acceptance: `uv run python tests/verify_customer_auth_runtime.py --base-url <worker-url> --origin <allowed-origin>`; this creates a synthetic customer whose printed ID must be cleaned up after testing.

Staging infrastructure deployed on 26 September 2026 at `https://milterra-api-staging.todileepmaurya.workers.dev`: all four migrations applied to the separate staging D1, with 93 inventory products and no customers, orders, coupons or serviceable PINs. Remote `/health` and `/ready` return 200; CORS and disabled-auth smoke checks passed. Authentication/provider secrets are absent and the public storefront is not connected. This is not full commerce acceptance. See the [current tracker](../../docs/CLOUDFLARE_MIGRATION_STATUS.md) for evidence and remaining work; the local-proof instructions below describe the earlier compatibility run.

This Worker is a local proof for the [Cloudflare migration brief](../../milterra-cloudflare-development-brief.md), not a replacement for the current commerce API. `/health` preserves the existing FastAPI response. `/ready` checks D1 and required commerce tables and is uncached. The guarded `/__compat/*` endpoints exercise D1 parameter binding, existing-style HS256 access tokens, Razorpay raw-body HMAC verification, a mocked authenticated payment-link request, and the current image-size/format/EXIF-stripping policy. They do not create orders or mark payments as paid. The D1 commerce slice supports **COD only** after an active customer and a serviceable PIN have been imported; missing data fails closed. Online payment capability is false and no payment URL is invented.

Tooling used for the local check: Python `3.13.3`, project-local `uv 0.12.3` (pywrangler requires at least this version), Node `22.16.0`, `workers-py 1.17.4`, Wrangler `4.140.0`, Pyodide `3.14.2`, and compatibility date `2026-09-25`. `uv.lock`, `pylock.toml` and `package-lock.json` pin the tested dependency graph. The D1 ID in `wrangler.toml` is a dummy local-only ID. No production deployment can use it.

From this directory, with `uv >= 0.12.3`, Node and npm on `PATH`:

```powershell
npm ci
uv sync
npx wrangler d1 migrations apply milterra-compat-local --local
Copy-Item dev.vars.example .dev.vars
uv run pywrangler deploy --dry-run --outdir .wrangler/compat-bundle
```

For the runtime integration check, start the following in separate terminals from this directory:

```powershell
python tests/mock_provider.py
uv run pywrangler dev --port 8787
uv run python tests/verify_local_worker.py
```

The last command should print `Worker runtime verified: health, readiness, D1, JWT, HMAC, provider, image, 404`. The mock provider listens on loopback and checks Basic authentication; no external payment request or money movement occurs. Pure contract tests run with `uv run pytest -q -p no:cacheprovider tests/test_compat.py tests/test_api_contract.py`.

The earlier successful dry run reported 523 modules, 11,881 KiB total and 3,147 KiB gzipped. That is a compatibility result, not a performance target for the eventual full API. The first D1 runtime test exposed that `result.results` may already be a Python list; the adapter now accepts either a list or a JS proxy. The full legacy API cannot be imported unchanged: its async SQLAlchemy/PostgreSQL layer, Redis fail-closed auth limiter, filesystem media storage and startup loops require separate replacements. No Cloudflare staging environment or live provider credentials were used.

Before any remote deployment, replace the dummy D1 binding with a staging resource, remove or isolate the probe endpoints, set precise `CORS_ORIGINS`, and implement the remaining authorization, payment, shipping and commerce state transitions. The earlier inventory seed includes a prototype customer/address and coupons; migration `0004_commerce_safety.sql` removes those rows. Future inventory exports omit fixtures. Import actual customer and delivery records privately. Keep staging and production bindings and secrets separate. See the [release gates](../../docs/MILTERRA_CLOUDFLARE_RELEASE_GATES.md).
