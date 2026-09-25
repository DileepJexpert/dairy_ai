# MILTERRA: Cloudflare development brief for Codex

Implementation progress is tracked in [docs/CLOUDFLARE_MIGRATION_STATUS.md](docs/CLOUDFLARE_MIGRATION_STATUS.md). This brief remains the target and acceptance checklist; the status file records completed work, verification, and blockers.

Prepared 25 September 2026. Repository: https://github.com/DileepJexpert/dairy_ai

## Instruction to the coding agent

Use this brief to start implementation in the existing repository. Read the repository instructions, inspect the current code and preserve unrelated work. Produce a short implementation plan, then build and verify the first working slice; do not stop at advice. Continue through the migration in reviewable steps, documenting any genuine blockers. This brief specifies a target architecture, not a claim that the application is already deployed or compatible.

## 1. Goal and constraints

MILTERRA is a single-seller ecommerce business with a small product catalogue. Expected initial traffic is approximately 100 visitors per day. The owner already has a Cloudflare domain and a Flutter web frontend and has invested in a Python FastAPI backend.

Host the application's frontend, API, database, uploaded files and background processing on Cloudflare. Make product browsing fast and available when the commerce API is unavailable. Keep recurring infrastructure costs low and preserve existing working functionality.

Keep Flutter for the initial migration. Do not introduce a marketplace or rewrite the frontend simply because another framework exists. Payment gateways, couriers and messaging providers remain external integrations; their fees are separate from application hosting.

## 2. Target architecture

| Responsibility | Cloudflare component | Implementation direction |
|---|---|---|
| Flutter frontend and public catalogue assets | Pages | Retain the existing static hosting approach; verify the actual project configuration. |
| Dynamic commerce API | Workers | Adapt FastAPI to Python Workers if the compatibility check succeeds. |
| Durable application records | D1 | Replace PostgreSQL persistence with a SQLite-compatible schema and data access layer. |
| Admin uploads and generated files | R2, when needed | Preserve public versus private access and upload validation. |
| Scheduled work | Scheduled Workers | Run bounded batches of durable jobs; do not require a continuously running process. |
| Retriable asynchronous work | Queues, when justified | Use for jobs that need reliable asynchronous delivery; handlers must tolerate duplicates. |
| Caching | Browser HTTP cache and selective Cloudflare caching | Cache public information, with an explicit freshness policy. |

Keep static requests outside the API Worker. Initially use the existing frontend hostname and a dedicated API hostname configured at build time. Document CORS and authentication behavior for these origins. Workers Static Assets is an acceptable alternative if it materially simplifies the existing setup, but do not introduce a second frontend host unnecessarily or run every asset request through application code.

The target does not depend on a Railway server, an external PostgreSQL database, a persistent local disk, Redis or an always-running container. If an active feature needs something outside this architecture, identify the requirement and resolve its replacement explicitly before declaring the migration complete.

## 3. Start with a compatibility check

FastAPI is supported on Python Workers, but the existing Docker/Uvicorn deployment is not a drop-in Workers deployment. Audit the current dependencies and startup behavior.

Build a small Worker demonstrating:

1. One existing FastAPI route with its current request and response format.
2. A D1 binding, a parameterized query and a write.
3. The actual authentication/signature operations and an outbound provider request using test credentials or mocks.
4. Compatibility of required upload validation and image processing.
5. A production bundle and local runtime verification, followed by staging verification when access is available.

Prefer retaining Python/FastAPI when this works. Replace PostgreSQL drivers and database adapters with direct D1 access; do not assume the existing asynchronous SQLAlchemy layer can run unchanged. Cloudflare currently documents an asynchronous SQLAlchemy incompatibility in Python Workers.

If required dependencies cannot be adapted economically, document the concrete blockers and use a TypeScript Workers API with equivalent contracts. Keep the old implementation as a reference during migration. The owner accepts stack changes, but a full rewrite needs evidence and a feature parity plan.

The repository reference checked for this brief was commit `5da367bcccbd2eb2e13d5d55e1e809af8e0992d7`. Reinspect the current checkout before editing; do not overwrite newer work. Pay particular attention to database-specific queries, local product-media storage, background loops and existing payment ownership protections.

## 4. Publish a static catalogue

Use D1 as the authoritative product and variant record store, including current commercial values. Publish a sanitized, versioned catalogue snapshot for the frontend. A seed file can initialize records, but avoid maintaining independent conflicting catalogues in Dart, JSON and the database.

The public snapshot should contain stable product/variant IDs, names, descriptions, categories, ingredients, sizes and image URLs. It may contain display-price snapshots. It must not contain customer records, credentials, supplier costs or private admin information.

Ship the initial snapshot and optimized product images as separate static files with the Flutter deployment. Do not embed all images as base64 inside application code or download every image before rendering.

Browsing, product details, category navigation, local search, filtering and an anonymous basket should work from this snapshot. Save basket product IDs, variant IDs and quantities locally. A local basket is a customer's selection, not a confirmed order or stock reservation.

Admin content edits need an explicit publish operation: update authoritative records, generate and validate the public snapshot, deploy the new assets, then mark the catalogue version as published. Keep the last valid version if publication fails. Explain publication status in the admin interface. Price and stock changes take effect in the backend immediately; stale display prices must be reconciled before payment.

## 5. Separate display information from purchase authority

| Information or action | Frontend behavior | Backend responsibility |
|---|---|---|
| Product story, categories, images and ingredients | Render static content immediately | Publish validated updates |
| Display price | Show the published snapshot; refresh where useful | Supply the current purchasable price |
| Basket editing | Work locally without a login request | Validate selections at checkout |
| Stock, promotions, delivery charges and tax | Treat unverified values as estimates or unknown | Calculate and validate the final quote |
| Login, customer profile and addresses | Fetch when needed | Authenticate and enforce record ownership |
| Orders, payments, refunds and tracking | Display authoritative status | Persist and control all state transitions |
| PIN code master data | Cache public locality data | Recheck actual serviceability and shipping rules |

Never accept a total, discount, payment status or stock value merely because Flutter submitted it. Recalculate the final amount on the server using trusted records. If a price changes, show the change and let the customer accept it before starting payment.

## 6. Load quickly and handle outages clearly

Render the storefront without waiting for authentication, location detection, readiness checks, stock calls or personalized data. Load dynamic information in the background or when the customer enters a flow that requires it.

Use compressed, appropriately sized images and thumbnails. Load below-the-fold images lazily; load video on demand. Defer heavy admin and secondary screens where practical. Measure the release build on a first visit to a mid-range mobile device, not just a warm desktop browser.

Provide a lightweight liveness endpoint and an uncached readiness endpoint that checks required application dependencies. Readiness must not block initial rendering. Avoid continuous polling from every open tab; use a background check at relevant transitions and handle errors on actual requests.

If the API is unavailable, keep the catalogue and basket usable. Show a clear message such as: â€œCheckout is temporarily unavailable. Your basket has been saved.â€ Preserve the basket and offer retry. Do not invent live stock or successful orders.

A timeout after submitting an order or payment means the result may be unknown. Retrieve the original operation's status using its idempotency key instead of blindly creating another order or payment. Reconcile uncertain provider outcomes through durable background work.

API-outage resilience is distinct from full offline operation. A first-time visitor without internet cannot download the site. Do not assume Flutter automatically supplies a managed offline service worker; implement one only if offline browsing is deliberately added and verified.

## 7. Cache policy

These are starting policies to validate against the application's update needs, not platform defaults.

| Data | Suggested policy |
|---|---|
| Content-hashed images and other immutable assets | Long public lifetime, typically one year; new content gets a new URL |
| HTML, application bootstrap and current-catalogue pointer | Revalidate or use a short lifetime so deployments become visible |
| Versioned catalogue snapshot | Immutable URL; switch the current pointer on publication |
| Public category or master-data responses | Cache for 1â€“24 hours where acceptable; version or invalidate changes |
| PIN code locality lookup | Cache successful public results for days; avoid downloading a nationwide dataset on startup |
| Delivery estimate | Short-lived, keyed by all relevant inputs; recalculate at checkout |
| Customer information, orders and payment responses | No shared caching; use appropriate private/no-store headers |
| Health/readiness endpoints | No caching |

Small browser-memory caches help within a session. Worker global memory is temporary and must never hold the only copy of sessions, inventory, orders or jobs. The Workers Cache API is local to a data center and can miss or evict entries; always retain a correct fallback. An in-Worker cache lookup still invokes the Worker.

Add KV or another cache only when a measured need justifies it. Do not add Redis for this initial scale. Cache invalidation and freshness are part of correctness, not just performance.

## 8. Preserve commerce correctness during the D1 migration

Convert schema types, indexes, constraints and queries deliberately. Represent money as integer minor units with an explicit currency. Preserve IDs and timestamps during import. Test foreign keys and uniqueness constraints in D1, rather than relying only on existing SQLite test fixtures.

Inventory reservation, order creation and related records must maintain their invariants under concurrent requests and failures. Never implement stock control as an unprotected read followed by a separate decrement. A conditional stock update that changes zero rows is not automatically a SQL error.

D1 batch operations provide transactional execution, but the application must make a failed business condition abort or otherwise prevent partial success. Choose and demonstrate a valid design using guarded SQL, constraints/triggers and transactional batches where suitable. Introduce Durable Objects only if coordination requirements justify them. Test two customers attempting to buy the last unit and a multi-item order with insufficient stock in one item.

Replace PostgreSQL locking patterns such as `FOR UPDATE SKIP LOCKED` with a supported claim/lease design: conditional transitions, ownership tokens, expiry and recovery. Do not silently remove duplicate-job protection.

Give order creation and externally visible actions idempotency keys. Repeating the same request must recover its original result; reusing a key with a different payload must be rejected. Verify payment webhooks, enforce order/customer ownership, deduplicate notifications and match amount/currency before confirming payment.

External payment and shipping calls cannot be included in a database transaction. Persist their intent and outcome, retry safely and reconcile unknown results. Preserve existing shipping auto-booking switches and recovery behavior. Durable jobs must survive a Worker restart and tolerate repeated execution.

Do not add D1 read replication initially unless measurements support it. If enabled later, design consistency explicitly; checkout and post-write reads must not depend on potentially stale cached or replica values.

## 9. Feature parity and scope

Before migration, inventory screens, routes, background jobs and integrations. Mark each as working, partially implemented, test-only or inactive. Include authentication, addresses, catalogue administration, media, wishlist, basket, discounts, orders, payment/refund flows, delivery rules, tracking and all other active repository modules.

Preserve working behavior and authorization checks. Do not declare a partly wired integration complete simply because its SDK or endpoint exists. Keep incomplete pre-existing functionality visible as a separate backlog item. Do not remove unrelated cooperative, dairy-management or other modules just because the storefront has one seller.

Keep synthetic ratings and reviews behind an explicit development/test setting. Disable them in production; they must not appear as genuine customer feedback.

For R2 uploads, preserve file-size/type checks and required sanitization. Separate published product images from private previews or documents. Ensure private objects cannot be accessed through a public bucket hostname.

Keep demo login, prelaunch mode and provider test modes explicit per environment. Production configuration must not silently inherit development defaults. Store API credentials and signing secrets in Worker secrets, never in Flutter assets or public JSON.

## 10. Implementation sequence and deliverables

1. **Audit and compatibility:** produce the feature matrix and dependency findings; prove FastAPI, D1 and representative authentication/provider operations in a Worker.
2. **Static browsing:** implement catalogue export, optimized assets, local browsing/basket and clear API-failure states without changing existing checkout contracts unnecessarily.
3. **First commerce slice:** implement current price/stock lookup, quote validation and idempotent order creation using D1; demonstrate concurrency and failure behavior.
4. **Complete parity:** migrate remaining active API routes, media and scheduled work; preserve payment/shipping reconciliation and ownership restrictions.
5. **Deployment setup:** add versioned Wrangler configuration, environment examples without secrets, D1 migrations, seeds/import tools, catalogue publication and reproducible Flutter/API builds.
6. **Staging verification:** exercise the full customer/admin journeys, provider sandbox webhooks, cold page load, API outage and recovery in the Cloudflare runtime.
7. **Release preparation:** provide exact deployment commands, required bindings/secrets/domains, a data migration plan, backup/restore instructions and a rollback procedure.

Use separate staging and production resources. Pin supported tool/runtime versions and a tested Worker compatibility date. Deploy compatible database/API changes before a frontend that requires them. Keep an older frontend/API version functional during rollout where practical; avoid destructive schema changes that prevent rollback.

Ensure unknown API routes return API errors rather than the Flutter HTML shell. Ensure intended frontend deep links load correctly. Configure allowed origins precisely. Keep logs useful for failed orders and jobs without logging credentials or complete customer/payment payloads.

At minimum, deliver architecture notes, the feature parity matrix, source changes, migration/export scripts, deployment configuration, meaningful integration tests, a deployment runbook and measured performance/usage results. If account access is unavailable, finish the local implementation and dry runs and list the exact remaining deployment steps without claiming a live deployment.

## 11. Completion checks

- A fresh visitor can see products without any API request succeeding.
- Local search, filtering, product details and basket editing work during an API outage.
- Checkout uses trusted price, stock and delivery information and reports changed values clearly.
- Simultaneous purchases cannot oversell; repeated submissions and webhooks do not duplicate orders or charges.
- An uncertain payment/shipping result can be reconciled after interruption.
- Existing working admin/customer features and ownership protections have equivalent behavior.
- Catalogue updates publish consistently; old cached assets do not break the new release.
- No production feature depends on a local disk or an always-running background loop.
- Fake reviews and demo authentication are absent from the production experience.
- Relevant tests pass in the actual Workers/D1 environment, and the deployment/rollback steps are reproducible.

Record first-screen timing, useful-content timing, shipped asset sizes and representative API latency before and after the change. Agree numeric targets after the baseline; do not promise a fixed load time without measurements. If Flutter still misses the business's performance or search-discovery needs, evaluate a separate pre-rendered public storefront as a later decision.

## 12. Cost expectations

Aim for free static hosting and low metered backend usage. Workers Paid currently starts at US$5 per month; this is a base charge, not an all-services spending cap. A free deployment is possible only if runtime, storage and usage limits fit the actual application. Domain registration does not include unlimited backend compute.

At approximately 100 visitors/day, this architecture should be inexpensive, but visitor count alone does not determine the bill. Measure API requests, CPU, database rows read/written, storage and job activity; include bots and scheduled jobs. R2, Queues, optional services and usage beyond included allowances can add charges. Payment, courier and messaging fees are separate.

Provide a cost estimate from the measured workload before launch. Do not rewrite the whole system solely to promise an unverified zero-rupee monthly bill.

## Official implementation references

Verify current limits and syntax during implementation:

- [FastAPI on Python Workers](https://developers.cloudflare.com/workers/languages/python/packages/fastapi/)
- [Python Workers database compatibility](https://developers.cloudflare.com/hyperdrive/examples/python-workers/)
- [D1 database binding and batch operations](https://developers.cloudflare.com/d1/worker-api/d1-database/)
- [Wrangler configuration](https://developers.cloudflare.com/workers/wrangler/configuration/)
- [Pages asset serving](https://developers.cloudflare.com/pages/configuration/serving-pages/)
- [Workers Cache API](https://developers.cloudflare.com/workers/runtime-apis/cache/)
- [R2 public bucket access](https://developers.cloudflare.com/r2/buckets/public-buckets/)
- [Flutter web FAQ](https://docs.flutter.dev/platform-integration/web/faq)
- [Workers pricing](https://developers.cloudflare.com/workers/platform/pricing/)
- [D1 pricing](https://developers.cloudflare.com/d1/platform/pricing/)
- [R2 pricing](https://developers.cloudflare.com/r2/pricing/)
- [Queues pricing](https://developers.cloudflare.com/queues/platform/pricing/)
