# Milterra ecommerce implementation plan

Date: 2026-09-11 | Scope source: [MILTERRA_ECOMMERCE_REQUIREMENTS.md](MILTERRA_ECOMMERCE_REQUIREMENTS.md)

## Delivery approach

Build one tested vertical slice at a time in the existing repository. A partial Phase 1 taxonomy/admin foundation is now implemented; see [ANTIGRAVITY_HANDOFF.md](ANTIGRAVITY_HANDOFF.md) for precise boundaries. Existing storefront/cart/vendor work is reusable, not a reason to mark every phase complete.

Do not start with new microservices, a second frontend framework or a wholesale rewrite of DairyAI modules. Do not create automatic clinical/prescription capabilities, payments, seller approvals or production side effects merely because they appear on this roadmap.

**Mandatory layout constraint:** follow DEC-12 and LAYOUT-01 through LAYOUT-08 in the requirements. Customer pages must use Amazon-style placement, hierarchy, density and shopping flow with Milterra branding. A generic landing page or dashboard is not an acceptable substitute. Capture dated Amazon.in references before each major template; present the first homepage/results/detail templates for user visual acceptance. Existing storefront screenshots are a baseline, not automatic approval of future page templates.

## Phase 0 — Scope and source baseline

Status: documentation complete; runtime baselines must be rerun before implementation.

- Record confirmed open-browsing/authenticated-cart decisions, current gaps, domain boundaries, admin requirements and launch blockers.
- Preserve the dirty worktree; identify overlapping edits before touching source.
- Before Phase 1, run/read the relevant tests, actual migration heads and database schema state. Separate pre-existing repository-wide failures from failures caused by the slice.

Deliverables: requirements document and this plan. No database or runtime changes.

## Phase 1 — Catalogue and permission foundation

Status: partially implemented. Department/category CRUD, server authorization bridge, versioned classification API, public taxonomy integration and shopping-return navigation exist. Full capabilities, typed attributes, product families/variants and manual browser acceptance remain pending.

### Slice 1A: migration and contracts

- Current user decision: no deployment or retained data; use the explicit full-model rebuild in [LOCAL_DATABASE_REBUILD.md](LOCAL_DATABASE_REBUILD.md), not incremental ALTER migrations. Department/category identifiers are implemented; product type/family/variant contracts remain pending.
- Keep seller-owned listing/SKU IDs compatible with existing cart/order references. Make the future shared-variant/multiple-seller distinction explicit before creating tables.
- Specify typed attribute validation, stable catalogue paging/filtering, public publication rules and API response shapes.
- Introduce customer baseline plus explicit commerce staff/seller capability checks; preserve old role routes while transitioning. Test revocation and scope, not just UI visibility.
- Deliver clean rebuild/repeat reset/rollback checks on a dedicated disposable PostgreSQL database; do not reset the user's active database merely to test the script.

Exit: repeatable migration, old API compatibility and negative authorization tests; requirement groups CAT, IAM, MIG and NFR-01 covered for this slice.

### Slice 1B: first usable end-to-end admin operation

- Build protected commerce admin navigation and department/category list/create/edit/archive forms using shared design components.
- Read those categories dynamically in public navigation and server-side catalogue queries.
- Preserve product browsing and Add-to-cart return destinations regardless of user role.
- No clinical services, advanced coupon engine or seller payout work in this slice.

Exit demonstration: owner adds a category in admin; it appears on the public website without a Flutter release; an ordinary customer receives a server-side denial for the same admin mutation. No categories inferred from product names after the reviewed migration.

## Phase 2 — Owner-managed catalogue and listing publication

Status: planned; depends on Phase 1.

- Implement the first-party Milterra seller organization and authorized admin product management.
- Product-family and variant editor: title, SKU, category/type, required attributes, pack options, images, base price and inventory.
- Support draft/save/preview/publish/archive, revision conflict detection and audit events.
- Add actual image-file upload through a storage adapter with validation and owner-scoped assets; select/reorder the gallery.
- Product details consume explicit variant IDs and validated templates. Replace title-based pack matching.
- Load the five Farm Essentials products only with owner-supplied information; otherwise retain drafts clearly flagged as incomplete.

Exit: ACC-03, ACC-07 and ACC-08 for the implemented scope; owner can publish a valid product with two variants from the browser and see the exact images, price and information on the public detail page. Drafts cannot be discovered through list/detail/search/media routes. Client fixtures match real API contracts.

## Phase 3 — Prices, offers and homepage merchandising

Status: planned; depends on Phase 2.

- Central pricing/quote service, decimal-safe display, immutable price history and explicit reference-price policy.
- Admin scheduled campaigns, preview, pause, scope selection and deterministic non-stacking defaults.
- Extend cart and checkout to consume the same quote and require acknowledgement of changed totals. No frontend-only discount calculations.
- Add coupons as a separate tested slice: allocation, limits, atomic reservation/redemption/release, retries and refund treatment.
- Add owner-managed banners and featured collections linking to published catalogue content.
- Build Storefront & Campaigns administration: featured rows/grids, highlighted-product spotlights, Deal of the Day and festival landing pages; configure selection, ordering, placement, draft/preview/publication and schedules.
- Reuse centralized section/layout/theme variants, including festival treatments. Curated selections reference real listing/variant IDs; promotional placements link to authoritative pricing campaigns.
- Filter drafts, inactive sellers and unavailable promotional items; hide empty sections, invalidate affected caches and keep campaign deadlines server-authoritative.

Exit: ACC-05 and ACC-11 through ACC-13, plus boundary, timezone, rounding, zero/negative amount prevention, concurrent coupon/deal-allocation limits and unauthorized campaign/preview tests. Demonstrate an owner publishing a featured section, daily deal and festival campaign without editing Flutter. Changing the displayed promotional banner alone cannot change the amount charged.

## Phase 4 — Production purchase lifecycle and admin operations

Status: planned; depends on stable pricing/contracts and business decisions for live checkout.

- Define order/payment/inventory/shipment state transitions and reconcile the existing pending-order stock decrement with the chosen finite hold model.
- Payment provider adapter, signed callback validation, deduplication, retries and reconciliation; provider sandbox first.
- Shipping/serviceability quotes, multi-seller/handling groups and clear delivery charges; no hardcoded free delivery in production without an approved policy.
- Admin order and inventory workspaces; stock-adjustment reasons, shipment tracking and controlled cancellation/refund operations.
- Customer order tracking and support journey; private access enforced on every read/write.
- Evaluate lot/expiry inventory for the actual launch assortment, including an explicit launch limitation if only one lot is supported.

Exit: ACC-06, ACC-07 and ACC-10; sandbox end-to-end checkout passes failure, duplicate, concurrency, timeout and recovery cases. Real payment enablement remains separately authorized, not implied by the sandbox pass.

## Phase 5 — Third-party seller marketplace

Status: planned; first-party commerce must already be operational. Seller ownership/security foundations begin in Phase 1, not here.

- Seller application, approval/suspension, organization membership and scoped portal.
- Seller-owned listing drafts, upload/edit/price/stock tools, review submissions and approval feedback.
- Platform moderation and explicit audited admin intervention; no cross-seller access.
- Seller fulfillment sees only required order/customer data for its shipments.
- Define commissions, settlement ledger, reconciliation and dispute responsibilities before accepting live third-party paid orders. These terms are not assumed by this plan.

Exit: ACC-02 and ACC-04, seller suspension effects, cross-seller API denial tests and a manually exercised seller-to-admin-to-customer workflow. Production multi-seller launch requires a tested settlement operating model.

## Phase 6 — Growth and additional business workflows

Status: future; individually scoped before development.

- Optional retailer profiles, bulk quantities and agreed price lists without restricting public browsing.
- Verified-purchase reviews/moderation, wishlists, better recommendations, loyalty and subscriptions.
- Veterinary verification and booking after auditing existing DairyAI veterinary modules; separate appointment/payment/cancellation logic and clinical-data permissions.
- Equipment rentals, additional warehouses and other workflows only through explicit domain extensions.
- Public-search discoverability and rich product sharing must be evaluated for the actual Flutter web deployment; any additional rendering layer is a separate architectural decision, not an automatic frontend rewrite.

Exit: each feature has its own requirements, tests and operational acceptance. A menu placeholder is not a completed feature.

## Verification and release checklist for every slice

1. Inspect relevant source, dirty edits, contracts, tests and migration state.
2. Implement the schema/service/API path with ownership checks and transaction boundaries.
3. Build the actual Flutter workflow using the shared theme and reusable form/table components.
4. Test authorization failures, invalid input, empty/error states and concurrency where relevant.
5. Verify API/client agreement using real response shapes, not only mocked frontend fixtures.
6. Run focused analysis/tests and the appropriate full build; report unrelated baseline failures separately.
7. Exercise the workflow in a browser at relevant widths and with multiple authorized/unauthorized users.
8. Record migration/backfill/rollback checks and confirm no existing carts/orders/profile capabilities were lost.
9. Update phase evidence and remaining limitations before starting the next slice.
10. For customer-facing changes, compare Milterra screenshots with the selected reference and the layout contract. Verify 1280/1440 desktop, 768 tablet and 360/390 phone widths, card alignment, search prominence, product-detail columns, keyboard use and enlarged text. Record ACC-14 and the required first-template visual acceptance; do not mark a materially different layout complete because tests pass.

## Acceptance journeys to keep throughout development

- Household shopper: browse ghee without login -> select pack -> Add to cart -> login -> retained shopping intent -> cart -> address -> approved quote -> sandbox payment -> order tracking.
- Farmer shopper: browse Farm Essentials -> buy an animal-nutrition product and household ghee with the same customer account; never forced into a restricted farmer shop.
- Store owner: commerce admin -> category -> product/variants -> upload -> price/stock -> preview -> publish -> live storefront -> featured/spotlight placement -> daily deal/festival campaign -> order management -> audit review.
- Seller: application -> approval -> own draft -> moderation -> public listing -> own shipment; direct requests for another seller's private records fail.
- Staff: merchandising access permits catalogue duties but not granting administrator roles or issuing unauthorized refunds.

## Implementation tracking

| Phase | Status at document creation | Evidence required to mark complete |
| --- | --- | --- |
| 0: Requirements | Documented | Documents linked and scope aligned to current user decisions |
| 1: Foundation | Not started as this new architecture | Migration/contract/auth checks and dynamic admin-to-storefront category workflow |
| 2: Product administration | Not started as full commerce admin | Owner publishes real content/variants end to end |
| 3: Pricing, offers and showcases | Not implemented | Same server price across catalogue/cart/checkout; audited campaigns/coupons; scheduled featured/daily/festival placements |
| 4: Purchase operations | Existing partial foundation; not production accepted | Payment/stock/shipping/refund recovery and sandbox acceptance |
| 5: Seller marketplace | Existing partial vendor tooling; incomplete | Moderated, isolated multi-seller workflow and settlement readiness |
| 6: Extensions | Deferred | Separate feature acceptance, not just reusable schema |

No automatic commit/push, destructive database migration, provider subscription, seller approval or public deployment is authorized merely by listing it here.
