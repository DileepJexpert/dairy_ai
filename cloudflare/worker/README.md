# Isolated Cloudflare Python Worker compatibility proof

## Isolated courier and refund simulation (28 September 2026)

Migration `0012_simulated_fulfillment.sql` adds an append-only **simulated** COD movement ledger. The simulator API is hidden (404) unless all of `ENVIRONMENT=staging|test|local`, `TEST_COMMERCE_ENABLED=true`, `LIVE_COD_ENABLED=false`, and `SIMULATION_ENABLED=true` are set. It additionally requires an authenticated admin and an `is_test_order=1` order. Keep it on a **separate preview Worker and D1**, with a separate Pages origin; the existing `milterra-api-staging` Worker serves the real COD site and must retain `SIMULATION_ENABLED=false`. Use [wrangler.simulator.example.toml](wrangler.simulator.example.toml) as the reviewed template for a new preview configuration. Do not turn the live Worker into test commerce or reuse its D1 for this preview. The simulator never calls a courier, bank or payment provider.

After a test customer places a COD order, the customer can cancel it before packing through `POST /api/v1/marketplace/orders/{id}/cancel`; stock is restored and no refund exists. For the longer flow, an admin packs it with `PUT /api/v1/marketplace/orders/operations/{id}` and `{"status":"PACKED"}`, then uses these **admin-only** test routes:

| Action | Route | Result |
| --- | --- | --- |
| Book fake shipment | `POST /api/v1/marketplace/orders/admin/simulator/{id}/dispatch` | `SIM-AWB-...` tracking, `[SIMULATED]` timeline event, shipped status |
| Advance fake courier | `POST /api/v1/marketplace/orders/admin/simulator/{id}/event` | Body `{"event":"OUT_FOR_DELIVERY"}` or `{"event":"DELIVERED"}` |
| Fail fake delivery | Same event route | `{"event":"DELIVERY_FAILED","reason":"Address unavailable"}` opens an RTO case; use the existing admin return process to mark received and restock |
| Record fake COD collection | `POST /api/v1/marketplace/orders/admin/simulator/{id}/collect` | Paid status and `SIM-COD-...` ledger entry; **no cash is collected** |
| Complete fake refund | `POST /api/v1/marketplace/orders/admin/simulator/{id}/refund` | After a delivered customer's `/orders/{id}/return-request`, marks it received/refunded and writes `SIM-REFUND-...`; **no money is sent** |
| Inspect fake ledger | `GET /api/v1/marketplace/orders/admin/simulator/{id}/ledger` | Both simulated amounts and references |

The customer can see the order and timeline via the ordinary order endpoints. Test records are tagged `is_test_order=true`; simulated tracking, events and references carry unmistakable `SIM-` or `[SIMULATED]` markers. A packed test order cannot use the simple customer cancellation endpoint; a dispatched failed delivery must go through RTO. The simulator has no prepaid path, so a provider-verified prepaid refund still needs its own integration and acceptance. Run `\.venv\Scripts\python.exe -m pytest -q -p no:cacheprovider tests/test_simulated_fulfillment.py` locally; the full Worker suite also loads every migration in order.

The separate browser preview is [milterra-flow-preview.pages.dev](https://milterra-flow-preview.pages.dev/#/shop), connected only to `milterra-api-flow-preview.todileepmaurya.workers.dev` and its own D1. Build that preview with `API_BASE_URL` and `AUTH_API_BASE_URL` set to the preview Worker and `FLOW_SIMULATION=true`; this adds a persistent test banner and admin action buttons for fake dispatch, delivery, failure, COD collection and refund. Leave `FLOW_SIMULATION` unset for the real site. A test customer can place or cancel a COD order at PIN `201305`; for the longer flow, the owner signs into the preview admin account using the ignored local credential file `cloudflare/worker/.wrangler/flow-preview-admin.txt`, packs the order, uses the simulation buttons, then processes the customer's return in the admin Returns tab. Use separate browser sessions or sign out between customer and admin roles. The preview admin credentials and Worker auth secret are not in Git. The full HTTP acceptance script is `tests/verify_flow_preview_runtime.py`; its test orders are retained in the isolated preview D1 for audit. See the [design and manual test guide](../../docs/MILTERRA_FLOW_PREVIEW.md) for the purpose, safety boundaries, exact customer/admin steps, and expected outcomes.

## Real COD orders with configurable delivery policy (28 September 2026)

For customer orders on the current Cloudflare API, keep `CUSTOMER_AUTH_ENABLED=true`, `TEST_COMMERCE_ENABLED=false`, and `LIVE_COD_ENABLED=true`. D1 `delivery_policy` sets the national default and fee; `delivery_pincode_rules` can override individual PINs. `LIVE_COD_PINCODES` is obsolete. The national default remains off until the owner confirms its fee; PIN `201305` is explicitly open with free delivery. Both public PIN checks and quote/order placement use this policy. Existing test orders retain `is_test_order=1`; new real COD orders have `is_test_order=0` and `payment_status=pending` until seller-recorded collection. The online payment capability remains unavailable. A valid PIN format is not proof of postal existence or courier reach.

Build the storefront without `TEST_COMMERCE=true` for this mode. Run `tests/test_test_checkout.py` to verify real COD classification, policy coverage, quote/checkout, idempotent replay, cancellation and stock restoration. This release does not book a courier or verify phone/email ownership; fulfill and collect COD through the existing seller operations flow.

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
