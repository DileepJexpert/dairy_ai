# Milterra Cloudflare migration status

Last updated: 26 September 2026. Source plan: [milterra-cloudflare-development-brief.md](../milterra-cloudflare-development-brief.md).

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
| Static catalogue and local basket | Exporter implemented; storefront pending | [DB-driven exporter](../backend/scripts/STATIC_CATALOGUE_EXPORT.md) and focused tests are present. No authoritative DB/media was available to generate a production snapshot. Flutter still depends on live catalogue and server cart. |
| D1 commerce correctness | Not started | Design and test stock, idempotency, and webhook invariants in D1. |
| Full parity, staging and release | Not started | Requires compatibility results and Cloudflare staging access. |

The current API remains the commerce authority until the replacement passes its own integration and staging checks. A local prototype is not a production deployment.

## Findings that affect the next slices

- Python FastAPI, D1, Pillow, PyJWT and an outbound authenticated HTTP request work together in the tested local Workers runtime. The probe is **not** proof that the full legacy backend can bundle or run unchanged. Cloudflare's Python Workers currently do not support async SQLAlchemy ORM; replace that data layer explicitly.
- The current order idempotency key can return an earlier order when the same key is reused with a different payload. D1 order creation must store and compare a canonical request hash before accepting a retry.
- Existing approved reviews include illustrative/seeded feedback, and the review route can approve anonymous submissions. The static exporter therefore omits ratings and reviews entirely until genuine purchase provenance can be enforced.
- The static exporter is read-only against PostgreSQL and writes a deterministic, sanitized JSON snapshot. It does not upload media to R2 or publish a Cloudflare Pages release; those steps remain required.
- Backend catalogue tests reported seven passes, but the pytest process lingered after its summary on this Windows host. Worker contract tests passed cleanly (six tests), and the full local runtime script passed after fixing D1 result conversion.

## Next reviewable step

Publish one real catalogue snapshot with its images from the authoritative database, then wire Flutter browsing and an anonymous local basket to that version. The present workspace has no reachable PostgreSQL database or Cloudflare staging account, so a customer-visible outage-resilient catalogue cannot be claimed yet. In parallel, design the first D1 commerce schema and test guarded inventory/idempotency behavior before any checkout traffic is moved.
