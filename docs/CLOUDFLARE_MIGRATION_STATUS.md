# Milterra Cloudflare migration status

Last updated: 25 September 2026. Source plan: [milterra-cloudflare-development-brief.md](../milterra-cloudflare-development-brief.md).

## Implementation plan

1. Inventory active API routes, Flutter screens, background jobs and integrations. Record parity and Python Workers compatibility findings.
2. Prove a small FastAPI Worker with an existing route contract, D1 parameterized read/write, payment signature verification, a mocked provider call, and upload checks. Run it locally and produce a bundle.
3. Export a sanitized, versioned catalogue from the authoritative store; use it for anonymous browsing and a local basket while keeping server-side checkout validation.
4. Port commerce records and invariants to D1, then the remaining active features, R2 media, and durable scheduled work. Verify payment, shipping, and authorization behavior.
5. Add staged deployment, migration, rollback and cost/performance evidence before replacing the current production service.

## Progress

| Slice | State | Evidence or next check |
| --- | --- | --- |
| Repository and architecture audit | In progress | Current checkout is `f1cad83` on `main`; the existing API uses PostgreSQL, Redis, local media storage and startup loops. |
| Feature parity matrix | In progress | Route and Flutter feature inventory underway. |
| Python Worker / D1 compatibility proof | Not started | Implement an isolated prototype without changing the live commerce API. |
| Static catalogue and local basket | Not started | Requires a single authoritative product export and Flutter integration. |
| D1 commerce correctness | Not started | Design and test stock, idempotency, and webhook invariants in D1. |
| Full parity, staging and release | Not started | Requires compatibility results and Cloudflare staging access. |

The current API remains the commerce authority until the replacement passes its own integration and staging checks. A local prototype is not a production deployment.
