# Milterra Cloudflare release gates

The current Worker is a **local COD commerce proof**, not the live API. Keep the Flutter storefront's `API_BASE_URL` pointed at the existing FastAPI service. Do not replace the API DNS record or run a production D1 import yet.

## Verified locally on 26 September 2026

- The Worker tests pass with a disposable SQLite/D1-compatible schema (`23 passed`). This is not a remote D1 concurrency test. `/ready` reports unavailable when a required commerce table is missing.
- Checkout now requires an active D1 customer, an owned address and a serviceable PIN with a configured delivery fee. Missing coverage rejects checkout. Online payment returns unavailable until a provider-issued link and payment lifecycle exist.
- The browser CORS handler permits only origins in `CORS_ORIGINS`; Pages `_headers` revalidates the app shell/current catalogue pointer and makes versioned catalogue snapshots immutable.
- The Python Worker dry-run bundle passed (524 modules, about 3.15 MiB gzip). The Flutter release web build passed and copied `_headers`; its main JavaScript output was 5,298,449 bytes before transfer compression. Cold-visit timing remains unmeasured.
- All four migrations applied to a fresh local Wrangler D1 store. It contained 93 products and zero customers, coupons and serviceable PINs after cleanup. A separate older local D1 store has schema drift and must not be treated as migration proof.

## Required before staging

1. The separate Direct Upload Pages project `milterra-staging` now serves the homepage preview at `https://milterra-staging.pages.dev/#/shop`. Its build uses an intentionally invalid example API origin and cannot accept orders. Wrangler access is restored for account/user read and Pages write only. The separate `milterra-staging` D1 database has been created with an Asia Pacific hint; it is empty. The ignored local staging config has the real binding and passed a fresh Worker dry run. Establish backend deployment permissions, apply the staging migrations, and create the separate staging Worker and any required R2 buckets. R2 is not enabled; subscription activation needs separate approval. Copy `cloudflare/worker/wrangler.staging.example.toml` to a private config, replace the deliberately invalid D1 ID and storefront origin, and set required secrets with Wrangler. Keep production IDs and secrets out of Git.
2. Import users (including active/disabled state), addresses, current inventory, coupons and serviceable PINs from a backed-up authoritative database through a private data-transfer process. The committed prototype seed is not a customer import. `backend/scripts/export_delivery_coverage_to_d1.py --output-sql <private-path>` prepares coverage SQL from PostgreSQL; review it before `wrangler d1 execute ... --remote --file <private-path>`. Never commit a SQL file containing phone numbers or addresses.
3. Port login/OTP and shared rate limiting or define a proven temporary legacy-auth boundary. An access JWT alone is insufficient without the matching active D1 customer. Preserve role checks from D1, not from the token claim.
4. Implement real Razorpay link creation, durable link identity and attempts, raw-body webhook signature verification, provider fetch, amount/currency/payment reference checks, idempotent confirmation, expiration and refund reconciliation. Test retries and uncertain provider responses. Do not enable the online payment capability until these pass in Razorpay sandbox.
5. Port shipping coverage/quotes, manual shipment updates and the enabled courier adapters. Keep auto-booking off until durable claims, retries, label retrieval and unknown-result reconciliation work.
6. Port the Milterra account/admin/wishlist/catalogue publication/media routes needed by the storefront. Keep other app modules on the existing backend unless they have explicit route parity. Design a split API hostname or client routing contract before switching only commerce traffic.
7. Add R2 public/private media policies and bounded scheduled jobs. Prove no required feature depends on PostgreSQL, Redis, local media files or a continuously running loop.

## Staging acceptance

- Apply D1 migrations and private import to staging. Check row counts, foreign keys, sample ownership, disabled-user rejection, out-of-coverage PIN rejection and rollback from a backup.
- Deploy the Worker to staging; verify `/health`, `/ready`, exact CORS preflight and 404 for unknown API routes. Verify the Python Worker against real D1 and two buyers competing for the last unit.
- Build Flutter with an explicit staging `API_BASE_URL` and deploy its `mobile/build/web` output to Pages. Check `_headers`, deep links, a cold mobile visit, static browsing during API outage, local basket recovery and a full customer/admin order journey.
- Exercise Razorpay sandbox paid, failed, duplicate, late and invalid-signature webhooks; check no client action can mark an order paid. Exercise courier sandbox/controlled manual shipment and an interrupted booking retry.
- Measure asset bytes, first useful content, API latency, Worker CPU, D1 reads/writes, storage and expected monthly use at the intended traffic level.

## Production cutover and rollback

The purchased `milterrafoods.com` domain now serves the existing Pages browsing preview with HTTPS. Its `www` alias is also configured and returns HTTP 200 over HTTPS. This domain connection is not a backend or commerce cutover. Deployments to the `milterra-staging` project now change the website on the purchased domain; isolate unfinished work in a separate preview deployment/project.

After staging passes, back up authoritative data, establish a write freeze or change capture for orders/inventory/customers, import final deltas, and verify counts. Deploy backward-compatible database/API changes before the frontend. Switch only the tested Milterra API routes, observe errors/orders/payments and retain the legacy backend until settlement and shipment records reconcile. Roll back frontend/API routing to the legacy service if acceptance fails; do not replay paid orders or replace inventory with an older seed. Reconcile provider and courier operations before any data rollback.

Pages site assets are deployed: 93 files, Cloudflare success confirmation, homepage HTTP 200 and browser rendering with images verified on 26 September 2026. The root response revalidates its cache. Wrangler login succeeded with account/user read, Pages write and background access after user approval. The Milterra staging D1 resource now exists but is empty. Backend authorization, schema application, the Worker resource, private imports and provider sandbox access remain pending. No API or database migration has been deployed remotely; commerce acceptance is incomplete.
