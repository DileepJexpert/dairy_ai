# Milterra commerce foundation handoff

## Latest checkpoint: luxury storefront refinement

The user now prioritizes an atmospheric homepage and familiar Amazon-style shopping pages. Column counts are flexible; preserve purchasing clarity and responsive behavior. See the root [ANTIGRAVITY_PROMPT.md](../ANTIGRAVITY_PROMPT.md) for the next task. This direction supersedes earlier requirements for an identical fixed three-column template.

The current design checkpoint adds bundled Cormorant Garamond headings, generated packaging concepts, visual category tiles, compact selectable-pack cards, shared header/search/navigation, a responsive two-column detail layout with accordions, a mobile purchase bar and an authenticated cart drawer. It preserves backend prices/content and checkout endpoints. Existing title/vendor-based pack matching remains an interim presentation rule.

Full browser visual acceptance is still pending. The sections below describe the earlier commerce foundation and its dated validation, not automatic acceptance of the latest design. Local backend examples now use port 8001.

### Luxury checkpoint checks: 2026-09-11

- Flutter: 23 tests passed, including responsive layouts at 360/390/768/1024/1440 logical pixels, real pack ID/price selection, return-to-catalogue state and a mocked authenticated cart drawer flow.
- Focused analysis: no issues in the shared theme/router/navigation, marketplace, cart drawer, commerce module and changed storefront/foundation tests.
- JavaScript debug web build succeeded with `API_BASE_URL=http://127.0.0.1:8001` and `--no-wasm-dry-run`. This does not validate WebAssembly or production release performance.
- Backend assertions: 38 focused rebuild-guard/taxonomy/cart/order/address/auth tests passed using the in-memory test database. The PostgreSQL destructive rebuild test was deliberately deselected; no local database reset was needed. Existing multipart/datetime deprecation warnings remain. After reporting the results, the pytest process stalled during shutdown and was interrupted; this was not a clean process exit. Investigate test-runner/background-resource teardown when next working on backend validation.
- The current design has not completed real-browser visual, keyboard/accessibility or authenticated end-to-end cart/checkout acceptance. Generated packaging is concept artwork, not approved product photography. No deployment, payment or push was performed.

## Start here

Read `MILTERRA_ECOMMERCE_REQUIREMENTS.md`, `MILTERRA_IMPLEMENTATION_PLAN.md`, `MILTERRA_UI_DESIGN.md`, then `LOCAL_DATABASE_REBUILD.md`. This handoff accompanies the local checkpoint commit; inspect `git status` and preserve any later changes. Flutter/Riverpod/Dio + FastAPI/async SQLAlchemy remain the architecture. Do not introduce React, microservices or a second commerce backend for this work.

## Implemented foundation (partial Phase 1)

- Public shopping remains role-neutral. `/shop` loads all legacy product categories, not only FEED_NUTRITION. Login resumes an allowlisted shopping destination rather than forcing the user's role dashboard. Authentication is still required for cart/order operations.
- New `commerce_taxonomy_nodes` supports departments and nested categories with stable IDs, unique slugs, ordering and archive state. `commerce_product_classifications` links existing product IDs without changing inventory/cart/order identifiers.
- Public `GET /api/v1/marketplace/taxonomy`; product list/detail include authoritative taxonomy metadata when enabled. Product list supports `taxonomy_id` (department descendants included). Stock/subcategory/rental filters run before server totals/pagination.
- Admin `GET/POST /api/v1/admin/commerce/taxonomy`, `PUT /{node_id}`, catalogue search `GET /api/v1/admin/commerce/catalogue`, classification `PUT /catalogue/{product_id}/category`. Use schemas/services, not direct frontend database operations.
- `GET /api/v1/commerce/access` tells the frontend whether the current active database user can manage taxonomy. Existing `admin`/`super_admin` roles are an interim server-enforced bridge, **not** a completed multi-capability model.
- Mutation service validates tree shape, active parents, cycles, slug collisions, archive dependencies and optimistic versions; a shared row lock serializes tree/classification changes and each mutation writes an audit event in the same transaction.
- Flutter `/admin/commerce` is a department/category editor using shared store tokens and Material controls. It is not yet the full listing/price/media/offer admin. Classification currently has an API, not an admin editor.
- `COMMERCE_TAXONOMY_ENABLED` defaults false to avoid querying absent tables on an old database. After the explicit full rebuild, enable it. Enabled taxonomy never guesses an unclassified product's category from its title; legacy display fallback remains only for old API data.
- Clean local schema build uses all current models and deterministic taxonomy seeds, without ALTER migration replay. Database reset is opt-in, guarded and separate from startup.

## Ownership map

| Concern | Source |
|---|---|
| Global colors, typography, spacing, breakpoints | `mobile/lib/app/store_theme.dart` |
| Shared shopping header, panels, product presentation helpers | `mobile/lib/features/marketplace/widgets/store_design.dart` |
| Routes and post-login destination | `mobile/lib/app/router.dart`, `shopping_navigation.dart` |
| Taxonomy API client/models/admin UI | `mobile/lib/features/commerce/` |
| Public shop and detail templates | `mobile/lib/features/marketplace/screens/` |
| Taxonomy persistence, validation, authorization | `backend/app/models/commerce_taxonomy.py`, `schemas/commerce_taxonomy.py`, `services/commerce_taxonomy_service.py`, `api/commerce_taxonomy.py` |
| Disposable full schema and demo setup | `backend/scripts/rebuild_local_database.py` |

## Next functional slice (after design acceptance)

Finish product-family / variant / product-type contracts, then build an owner-managed listing editor using those contracts. Keep the existing Product ID as the sellable listing identity referenced by cart/order. Give pack variants explicit IDs instead of the current title/vendor matching. Add category assignment to that editor using the existing versioned API. Test one real admin-created product end-to-end before expanding.

Deferred: full capability/multi-role memberships; typed attributes; explicit product families; listing draft/publication policy; binary media upload/storage; authoritative pricing/offer engine; featured placements/Deal of the Day/festival campaigns; signed payments/refunds; veterinary services. The five named farm supplements must not be published with fabricated prices, ingredients, efficacy or usage details.

## Known limits / acceptance boundaries

- Public Flutter product provider still downloads catalogue pages and filters locally. Connect UI pagination/filter state to server search before a large catalogue rollout. Product enrichment also needs batched metadata reads to remove N+1 queries at scale.
- Legacy seller publication behavior remains; taxonomy is not a complete visibility policy. Unclassified active products can appear under All products. Legacy feed/equipment routes remain narrower than `/shop`.
- Preserve Amazon-style shopping placement/density with Milterra branding and shared styling. Do not turn the shop into a role dashboard. No new storefront layout was visually accepted during this foundation slice.
- Category/API safety tests and Flutter widget tests are not full browser checkout/admin acceptance or production readiness. Existing historical Alembic chain is not the new full-model baseline.
- This checkpoint is committed locally at the user's request. Deployment, payment-provider configuration, customer-data reset and pushing are not part of this checkpoint.

## Repeatable validation

Backend: see `LOCAL_DATABASE_REBUILD.md`; run focused taxonomy/cart/order/address tests, plus the explicit disposable PostgreSQL rebuild test.

Flutter: `flutter test --no-pub`; `flutter analyze --no-pub lib/app/store_theme.dart lib/app/router.dart lib/app/shopping_navigation.dart lib/features/marketplace lib/features/cart/widgets lib/features/commerce test/storefront_test.dart test/commerce_foundation_test.dart`; then `flutter build web --debug --no-wasm-dry-run --dart-define=API_BASE_URL=http://127.0.0.1:8001`.

Manual before marking Phase 1 complete: clean rebuild, public browse as guest, admin creates department/category, storefront shows it without app release, customer/vendor direct API writes denied, stale edits rejected, cart login returns to shopping, mobile and desktop browser inspection. Record actual evidence, not assumptions from fixture tests.

### Earlier foundation validation: 2026-09-11

- Backend: 39 focused rebuild/taxonomy/cart/order/address/auth tests passed in the final combined run (existing datetime/multipart deprecation warnings remain).
- Flutter: all 20 tests passed; focused analysis reported no issues; debug web build succeeded using API port 8000.
- Actual PostgreSQL/TimescaleDB: complete 61-table schema creation, four demo products/classifications, seven taxonomy nodes, repeat reset and failed-seed transaction rollback passed on a separate disposable verification database. Shopping and farmer payment enum types coexist.
- The user's `dairy_ai` database was not reset. Full manual browser acceptance and repository-wide backend testing were not performed in this slice.
