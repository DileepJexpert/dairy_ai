# Milterra Cloudflare migration status

Last updated: 26 September 2026. Source plan: [milterra-cloudflare-development-brief.md](../milterra-cloudflare-development-brief.md). This is the handoff tracker for the next implementation agent. Update each row with source, tests, and staging evidence before marking it complete.

## Implementation plan

1. Inventory active API routes, Flutter screens, background jobs and integrations. Record parity and Python Workers compatibility findings.
2. Prove a small FastAPI Worker with an existing route contract, D1 parameterized read/write, payment signature verification, a mocked provider call, and upload checks. Run it locally and produce a bundle.
3. Export a sanitized, versioned catalogue from the authoritative store; use it for anonymous browsing and a local basket while keeping server-side checkout validation.
4. Port commerce records and invariants to D1, then the remaining active features, R2 media, and durable scheduled work. Verify payment, shipping, and authorization behavior.
5. Add staged deployment, migration, rollback and cost/performance evidence before replacing the current production service.

## Progress

| Slice | State | Evidence or next check |
| --- | --- | --- |
| Repository and architecture audit | Complete for first slice | [Feature matrix](MILTERRA_CLOUDFLARE_FEATURE_MATRIX.md) records PostgreSQL, Redis, local media, background loops and all registered route families. |
| Feature parity matrix | First pass complete | [Source-backed matrix](MILTERRA_CLOUDFLARE_FEATURE_MATRIX.md); refresh as each module migrates. |
| Python Worker / D1 compatibility proof | Local proof complete | [Isolated Worker](../cloudflare/worker/README.md): production dry-run bundle and local runtime checks passed for `/health`, D1, JWT, HMAC, mocked provider call, Pillow image processing and unknown-route 404. No staging run. |
| Static catalogue publication | Catalogue snapshot generated & published locally | 93 products and 3 product families published to `mobile/web/catalogue/products-5d73251f255d961dcb21b04d76094ebdcf73b93670f246f2c85894e270fcee26.json` and `current.json` via `scripts.publish_static_catalogue`. Referenced JPEGs verified; snapshot bundled in `mobile/assets/catalogue/products.json`. |
| Flutter static browsing | Code and focused checks complete; live acceptance pending | The storefront loads the same-origin pointer and snapshot for product lists/details and local filtering, then falls back to the existing API while no snapshot exists. Four focused Flutter tests passed; targeted analysis found no issues. Stock remains unknown in a snapshot; cart/checkout still call the API. |
| Anonymous local basket and outage UX | Complete for storefront & reconciliation slice | Anonymous users can add to basket, adjust quantities, and remove items locally without requiring auth or API connectivity (backed by `FlutterSecureStorage` and in-memory cache). Outage resilience ensures the basket is preserved and editable when API is unreachable. Visiting checkout initiates backend reconciliation against `/marketplace/cart/items` to verify live prices, stock, and delivery quotes. Checkout quote errors display a retry state ("Checkout is temporarily unavailable. Your basket has been saved.") and unverified orders are never shown as confirmed. Suite of 3 unit tests in `mobile/test/local_basket_test.dart` covers local basket CRUD, offline editing during outage, and backend reconciliation. Targeted `flutter analyze` passed with 0 issues. |
| Current PostgreSQL checkout idempotency | Code complete; migration not applied to a live DB | Checkout stores a normalized request fingerprint and rejects reuse of the same key with different inputs; legacy rows compare saved inputs. Alembic `checkout_request_fingerprint_v19` is the sole head. The order/checkout tests printed 21 passes; the Windows pytest process lingered after summary and was interrupted. |
| D1 commerce correctness | Isolated local proof complete; real API pending | [Reservation proof](../cloudflare/commerce_proof/README.md) demonstrates guarded stock, multi-line rollback, same-key replay, payload conflict, and stale-price rejection. Seven Python tests and a local D1/workerd test passed. It is not connected to checkout or a remote D1 database. |
| Full parity, staging and release | Not started | Requires compatibility results and Cloudflare staging access. |

The current API remains the commerce authority until the replacement passes its own integration and staging checks. A local prototype is not a production deployment.

## Findings that affect the next slices

- Python FastAPI, D1, Pillow, PyJWT and an outbound authenticated HTTP request work together in the tested local Workers runtime. The probe is **not** proof that the full legacy backend can bundle or run unchanged. Cloudflare's Python Workers currently do not support async SQLAlchemy ORM; replace that data layer explicitly.
- The previous checkout idempotency key could return an earlier order when reused with a different payload. The current PostgreSQL path now compares the new fingerprint (or saved fields for legacy rows); the D1 port must preserve this behavior and cover provider actions too.
- Existing approved reviews include illustrative/seeded feedback, and the review route can approve anonymous submissions. The static exporter therefore omits ratings and reviews entirely until genuine purchase provenance can be enforced.
- The static exporter is read-only against PostgreSQL and writes a deterministic, sanitized JSON snapshot. The local Pages publisher checks local images and moves its pointer last, but it does not upload to R2, deploy Pages, or record an admin publication state.
- Backend catalogue tests reported seven passes, but the pytest process lingered after its summary on this Windows host. Worker contract tests passed cleanly (six tests), and the full local runtime script passed after fixing D1 result conversion.
- The existing Dart sample product list remains in source as a legacy fallback. It must not become an independent live catalogue; remove or confine it after the authoritative snapshot is published and its outage behavior is accepted.
- Wrangler authentication is expired in this workspace. The local configuration uses a dummy D1 ID, so no Cloudflare staging or production deployment has been attempted.

## Next tasks for Antigravity

1. Apply `checkout_request_fingerprint_v19` to a backed-up **staging** PostgreSQL database, then rerun the checkout tests against that schema. Keep the current backend as the commerce authority throughout the migration.
2. [Completed locally] Generated real catalogue snapshot (93 products, 3 families) and published via `python -m scripts.publish_static_catalogue --output-dir ../mobile/web/catalogue` and bundled in `mobile/assets/catalogue/products.json`. Next check: deploy to a Pages staging site when Cloudflare credentials are provided.
3. [Completed locally] Completed anonymous local basket and checkout-reconciliation flow in Flutter storefront. Basket persists in `FlutterSecureStorage` (in-memory cache fallback), remains editable during API outage, and reconciles with server checkout quote upon navigating to checkout. Checkout displays retry state on outage without confirming unverified orders.
4. Turn the isolated D1 proof into the first authenticated commerce API slice: current price/stock, quote, guarded reservation, idempotent order creation, cancellation/release and migration/import of real records. Add concurrent last-unit, multi-item rollback, retry and payload-conflict integration tests against staging D1. Do not redirect checkout merely because the local proof passes.
5. Port remaining active routes and durable jobs from the [feature matrix](MILTERRA_CLOUDFLARE_FEATURE_MATRIX.md), including auth, addresses, customer/admin ownership, payment webhooks and reconciliation, shipping, media, refunds, and scheduled work. Replace PostgreSQL locks, Redis and local-disk dependencies explicitly.
6. Restore Wrangler authentication and create separate staging bindings/secrets; replace the dummy D1 ID. Verify the full customer/admin journeys, webhook/provider sandbox flows, performance, backup/restore and rollback in Cloudflare staging. Only then plan a production cutover. Record each result and any blocker in this tracker.

The present workspace has no reachable authoritative PostgreSQL database/media or Cloudflare staging access. Local proofs and code checks do not establish customer-visible availability or production readiness.
