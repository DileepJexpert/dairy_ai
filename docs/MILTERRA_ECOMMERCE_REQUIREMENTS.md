# Milterra ecommerce: requirements and extensible architecture

Version: 1.0 | Date: 2026-09-11 | Status: requirements baseline and proposed technical design

This document translates the current user decisions into an implementation contract. It is not a claim that the features below are built. Delivery order and acceptance gates are in [MILTERRA_IMPLEMENTATION_PLAN.md](MILTERRA_IMPLEMENTATION_PLAN.md).

## 1. Product direction and confirmed decisions

Milterra is one ecommerce marketplace for household consumers, dairy farmers, retailers and other buyers. The customer-facing layout must follow Amazon-style ecommerce structure, hierarchy and shopping interactions, not merely provide similar features inside a different layout. Retain Milterra branding and its own colour theme. This layout requirement does not promise every Amazon business feature in the first release.

| ID | Confirmed requirement |
| --- | --- |
| DEC-01 | One public website and shared backend; no separate domain or duplicate application per customer type. |
| DEC-02 | Everyone can browse all published departments, categories and products without login. No mandatory farmer/retailer/household selection. |
| DEC-03 | Login is required before Add to cart mutates a cart, and for checkout, addresses and personal order history. Guest checkout is not requested. |
| DEC-04 | Every authenticated, active customer can buy across departments regardless of professional role. |
| DEC-05 | Seller, veterinarian and staff permissions unlock workspaces, not separate customer catalogues. Permissions remain enforced by the server. |
| DEC-06 | Product browsing and shopping-triggered login must not redirect customers to a farmer/vendor/vet dashboard. |
| DEC-07 | The owner needs an ecommerce admin panel to manage product listings, images, prices, inventory, offers and publication. |
| DEC-08 | Retain Flutter, Riverpod, Dio, GoRouter, FastAPI, async SQLAlchemy and PostgreSQL. Reuse existing commerce and design-system code. |
| DEC-09 | Shared theme, layout tokens and reusable components control presentation; do not duplicate component-level visual rules across screens. |
| DEC-10 | The architecture must accommodate new product types, multiple sellers and future veterinary services without rebuilding the storefront. |
| DEC-11 | The owner can showcase featured/highlighted products, Deal of the Day and festival offers through admin-managed storefront merchandising. |
| DEC-12 | Amazon-style customer-facing layout is a mandatory acceptance criterion, not optional inspiration. Do not substitute a generic landing page, dashboard, oversized product list or sparse boutique layout. |

These decisions supersede the earlier food-only Milterra proposal and the subsequently rejected guest-checkout proposal. Older DairyAI BRD sections remain context for farm operations, not authority to add unrelated farm features to this commerce release.

## 2. Current implementation: inspected source, not production acceptance

The worktree contains substantial existing uncommitted work. Preserve it. This baseline comes from current source inspection; no full security, live payment or production readiness audit was performed for this document.

| Area | Existing foundation | Required extension |
| --- | --- | --- |
| Storefront | Public `/shop`, product details, client-side search/filter/sort, illustrations and shared theme | Data-driven departments/categories, server-side pagination/filtering, published content and real media |
| Catalogue | Seller-owned Product, enum categories `EQUIPMENT` and `FEED_NUTRITION`, free-form specifications, pack text | Explicit product families/variants, typed attributes, taxonomy and publication workflow |
| Grouping | Dairy browsing groups inferred from names; pack choices match exact title and seller | Persistent category and family/variant identifiers; no name inference |
| Identity | OTP/JWT, one `User.role`, protected backend routes | Customer baseline plus multiple approved capabilities; preserve existing role access during migration |
| Seller tooling | Vendor product create/update/inventory/media endpoints and basic Flutter product UI | Complete editing, actual file uploads, drafts, moderation, submission and operational feedback |
| Administration | DairyAI dashboards, user management and vet verification | Dedicated ecommerce merchandising workspace; existing admin screens do not constitute this panel |
| Prices | Product base price and cart price-change information | Price history, optional reference price, scheduled promotions, coupons and shared server quote calculation |
| Checkout/orders | Address and item snapshots, idempotency key, row locking, inventory decrement, pending-payment state, vendor fulfillment | Concurrent retry acceptance, customer-approved repricing, payment callback lifecycle, reservation expiry, shipping charges, cancellation/refunds |
| Payments | Dairy operations payment endpoints and commerce payment-state fields | Production goods-checkout payment integration and reconciliation; do not assume existing milk-payment APIs cover it |

Source anchors: `backend/app/models/{user,product,order}.py`, `backend/app/api/{products,orders,admin,super_admin,payments}.py`, `backend/app/schemas/product.py`, `backend/app/services/cart_service.py`, `backend/app/dependencies.py`, `mobile/lib/app/router.dart`, `mobile/lib/features/auth/screens/otp_screen.dart`, and `mobile/lib/features/marketplace/`. See also [MILTERRA_UI_DESIGN.md](MILTERRA_UI_DESIGN.md).

## 3. Shopping departments and catalogue governance

Initial public departments:

- **Dairy Foods:** ghee, paneer and later other dairy foods.
- **Farm Essentials:** animal nutrition, feed, equipment and other dairy-farm supplies.
- **Veterinary Care:** future service directory/booking area, hidden until operational; not a fake shop category with inactive buttons.

The first Farm Essentials product names supplied by the user are MILTERRA CALCI-PRO, MILTERRA MINERA-360, MILTERRA LACTA-PRO, MILTERRA RUMEN-PRO and MILTERRA HEAT-GUARD. Names alone are insufficient to publish them. Prices, pack sizes, composition, intended use, manufacturer information, directions and images must be supplied or approved by the owner. Do not infer health claims or feeding directions from their names.

Requirements:

- CAT-01: Admin-managed department/category records with stable IDs, slugs, labels, descriptions, images, parent relationships, ordering and active/archived state. Disallow category cycles and duplicate slugs within the defined scope.
- CAT-02: New categories and ordinary attribute definitions within existing supported field types require no Flutter release. New business workflows or attribute rendering types can still require code.
- CAT-03: A product type defines validated attribute fields, required flags, units and filterability. No executable code or arbitrary HTML supplied as a template.
- CAT-04: Food, animal-nutrition and equipment templates share the detail layout but have different fields. Clearly distinguish animal-use goods from human food.
- CAT-05: Product-family identity and variants are explicit. Pack size, unit and variant options must not be parsed from titles. Each sellable listing has a unique SKU, seller, price and inventory identity.
- CAT-06: Archive rather than delete referenced records; preserve historical orders. Define replacement/reassignment before archiving a category that still contains live listings.
- CAT-07: A mixed-department cart is valid. Delivery compatibility is checked at shipment/checkout level, not inferred from whether the buyer is a farmer.

## 4. Customers, permissions and navigation

All active registered users have customer shopping capabilities. Farmer/retailer interests may be optional profile preferences; they are neither signup gates nor authorization roles. Preserve existing farm profiles without automatically showing farm dashboards to retail shoppers.

| Action | Visitor | Any signed-in customer | Approved seller | Commerce staff |
| --- | --- | --- | --- | --- |
| Browse all published goods, prices and sellers | Yes | Yes | Yes | Yes |
| Add/update cart; checkout; personal addresses/orders | Sign in first | Own only | Own customer purchases | Own customer purchases |
| Manage merchant listings, stock and fulfillment | No | No | Own seller organization only | Explicit permission and scope |
| Publish platform content or campaigns | No | No | No platform-wide rights | Authorized merchandising staff |
| Grant staff/seller/vet capabilities | No | No | No | Authorized owner/security administrator |

- IAM-01: Model user-to-role/capability membership separately from customer preferences. Seller membership includes organization scope. Approval or revocation does not erase the person's shopping account.
- IAM-02: Backend checks active membership and record ownership on every protected operation. Role selection in signup, URL parameters, or local browser storage cannot grant authority.
- IAM-03: A visitor selecting Add to cart signs in and resumes the original product/pack/quantity intent. Revalidate availability and price and apply the requested add at most once. If safely resuming is impossible, return to the product with a clear Add button, never silently lose the destination.
- IAM-04: Allowlist internal return routes; reject external URLs and unauthorized workspace destinations. Ordinary sign-in returns to the storefront, not a role dashboard. Workspaces are explicit navigation choices.
- IAM-05: Session expiry preserves harmless navigation/intent, not tokens in URLs. Logout must not expose the previous customer's cart, addresses or orders to the next user.
- IAM-06: Staff login requires stronger protections than public browsing, including MFA for privileged accounts, rate limiting and auditability. Define token/session revocation and server-side access checks.

## 5. Public storefront and purchase journey

- SHOP-01: Configurable home sections, department navigation, search, breadcrumbs, product cards and clear seller identity. No mandatory login splash or buyer-type chooser.
- SHOP-02: Search and filters operate server-side over the full published catalogue, with consistent totals, stable sorting/tie-breakers and pagination. Global search can cover all goods; department filters are user-controlled, not role restrictions.
- SHOP-03: Product details include ordered image gallery, title, brand, selected variant, genuine price/reference price when supplied, stock, seller, relevant attributes, delivery information and purchase controls.
- SHOP-04: Related products use explicit catalogue data. Do not invent ratings, scarcity, discounts, delivery guarantees or customer reviews. Review submission/moderation is a later capability.
- SHOP-05: Cart and checkout display authoritative item prices, applicable discounts, tax treatment, shipping and payable total. Surface any change since the customer last reviewed the quote before payment.
- SHOP-06: One account and cart work across Dairy Foods and Farm Essentials. Shipping groups can differ by seller, origin and handling needs, with clear charges before confirmation.
- SHOP-07: Personal orders support item/shipment tracking and eligible cancellation/return actions. Customer order data remains private even when someone knows an order ID or phone number.
- SHOP-08: Public product URLs are bookmarkable and refresh-safe. Responsive layouts, keyboard use, visible focus, semantic labels and recoverable loading/error/empty states are mandatory.

### Mandatory Amazon-style layout contract

The following defines the required Milterra layout. Validate it against dated Amazon.in page references during implementation rather than assuming a remembered layout is exact. Amazon content may vary by date, location, account and experiment; capture the chosen reference before building each major page template. Milterra keeps its own logo, palette, typography and original/licensed assets. Do not copy Amazon trademarks, customer reviews or unsupported product claims.

| Page/region | Required layout and hierarchy |
| --- | --- |
| Global desktop header | Compact brand at left, prominent wide search in the centre, account/orders/cart at right; a second horizontal row for departments/categories. Keep shopping navigation readily accessible while scrolling. Delivery-location controls appear when supported, without invented serviceability. |
| Homepage | A shopping-led page with a restrained campaign banner, category discovery blocks, featured-product rows/grids, highlighted products, daily deals and festival sections. Show multiple useful shopping choices early; do not turn the page into one oversized hero followed by marketing text. |
| Category/search results | Desktop filter sidebar on the left, result count and sort controls above a space-efficient product grid on the right. Consistent image areas, title limits, variant/pack labels, price hierarchy, availability and actions. Desktop must not fall back to full-width list tiles for ordinary products. |
| Product detail | At wide desktop sizes, three zones: image gallery/thumbnails on the left; title, brand, variant selection, price and about/specification summary in the centre; a visually distinct purchase panel on the right with availability, seller, quantity and cart/checkout actions. Detailed information, relevant specifications, seller/policy information, related products and supported review content continue below. |
| Cart | Clear item rows with image, title, selected variant, unit price, quantity and remove action; desktop order-summary panel on the right with totals and checkout action. Surface unavailable items and price changes near the affected line. |
| Checkout | A focused address/delivery/payment/review sequence with a persistent, accurate order summary where space permits. Clearly identify the final commitment action; do not disguise an order/payment step as ordinary navigation. |
| Mobile/tablet | Preserve the same shopping hierarchy while reflowing. Search remains prominent; category navigation can scroll; filters use an accessible sheet/drawer; product details and checkout stack in a logical order. Do not shrink desktop columns into unreadable panels or allow horizontal overflow. |

- LAYOUT-01: Similarity is evaluated on placement, hierarchy, information density and interaction flow, not on colour matching. Different Milterra colours are expected; a different overall shopping structure requires explicit user approval.
- LAYOUT-02: Put breakpoints, maximum widths, spacing, type scale, image aspect ratios, card treatment and purchase-panel sizing in the shared design system. Use reusable header, product-card, result-layout, gallery, purchase-panel and order-summary components. Pages supply content and behavior, not independent copies of styling rules.
- LAYOUT-03: Cards in the same row align their image regions, title areas, prices and actions despite different title lengths, pack sizes or missing images. No stretched product photographs, inconsistent gutters, overlapping badges, clipped prices or unexplained large empty regions.
- LAYOUT-04: Featured rows, highlighted cards, Deal of the Day and festival sections use centrally supported ecommerce templates. Admins select content, order and approved template options, not arbitrary layouts/CSS that break the agreed shopping structure.
- LAYOUT-05: Use only information actually supported by product data and features. Missing reviews, offers or delivery policies must not be fabricated to make the layout resemble a reference screenshot. Loading, empty, unavailable and error states retain the page hierarchy.
- LAYOUT-06: Before accepting each major customer template, record the reference, provide a Milterra screenshot comparison and check real interactions. Include desktop widths of 1280 and 1440, tablet width 768 and phone widths 360/390; also check meaningful enlarged text and keyboard access. Passing compilation alone is insufficient.
- LAYOUT-07: Present the first completed homepage, results and product-detail templates to the user for visual acceptance before treating their layout as approved. Fix material departures from this contract; do not silently redefine 'Amazon-style' after implementation.
- LAYOUT-08: The commerce admin remains a practical operational workspace with navigation, tables, forms and previews using shared design tokens. Do not assume Amazon's public shopping pages specify its private seller/admin interface. Public storefront layout acceptance and admin workflow acceptance are separate gates.

## 6. Ecommerce admin panel

Proposed workspace: `/admin/commerce`. It is part of the same application but protected independently from the public storefront. Navigation labels below describe the target, not currently implemented screens.

### Product and merchandising workspace

- ADM-01: Searchable, paginated product list with SKU, seller, department/category, variant, price, stock and publication status; filters and clear edit/preview actions.
- ADM-02: Create and edit Milterra-owned listings without a terminal or developer. Assign them to an explicit first-party Milterra seller organization; do not represent ownership using a null vendor or impersonate another seller.
- ADM-03: Product editor sections: basics; department/category/type; attributes; variants/SKUs; media; pricing; inventory; delivery/handling; publication. Validate in the backend as well as the form.
- ADM-04: Upload files, select primary image, reorder and remove media. Enforce ownership, allowed formats/content, size limits and safe storage keys. Publishing requires approved required content. Label incomplete drafts rather than invent values.
- ADM-05: Draft, pending review, published, rejected and archived listing states. First-party authorized publishers can publish valid drafts; third-party sellers submit for approval. Define which sensitive edits require re-review, and keep the approved version public until replacement approval.
- ADM-06: Manage categories, brands, attribute definitions, featured collections, banners and department order. Preview before publishing; campaign links must point to valid, permitted destinations.

### Pricing and offers workspace

- ADM-07: Set listing sale price and optional genuine reference/MRP value when applicable; retain effective time, actor, reason and before/after history. Show conflicting edits instead of last-writer-wins overwrites.
- ADM-08: Create scheduled percentage or fixed-amount campaigns scoped to explicit listings, categories or sellers. Configure eligible dates, minimum spend, caps, priority and active/paused state.
- ADM-09: Manage coupon codes with eligibility, start/end, global and per-customer usage limits, maximum discount and redemption history. A banner alone never changes checkout pricing.
- ADM-10: Preview a campaign's affected listings and calculated customer totals before activation. Bulk operations show scope, validation results and confirmation; irreversible operations are not a single unguarded click.

### Operations and administration

- ADM-11: Orders workspace with customer/seller filters, payment and fulfillment states, shipments and an event timeline. Staff see only personal data needed for their assigned work.
- ADM-12: Inventory adjustments require reasons and an audit trail. Preserve reserved quantities; concurrent purchases and edits cannot create negative available stock. Batch/expiry tracking must support multiple lots before selling expiry-controlled stock at scale.
- ADM-13: Seller onboarding, approval/suspension, organization members and listing moderation. An authorized admin intervention in another seller's price/content is explicit, scoped and auditable.
- ADM-14: Support cancellation, return/refund requests and payment reconciliation through controlled state transitions. Never provide an unrestricted 'mark paid' shortcut.
- ADM-15: Manage staff permissions, delivery/serviceability configuration, store contact/policy content and feature visibility. Secrets remain in secure deployment configuration, never readable back from ordinary settings pages.
- ADM-16: Dashboard metrics distinguish paid sales, pending orders, cancellations and refunds. Basic operational counts come first; advanced analytics are not a launch dependency.

### Featured products, daily deals and festival campaigns

Merchandising decides what is showcased and where. Pricing decides the amount a customer pays. These are linked but separate: featuring a product does not automatically discount it, and a banner must not create an unsupported savings claim.

| Showcase type | Customer presentation | Admin controls |
| --- | --- | --- |
| Featured products | Curated product row/grid on home or department pages | Select published listings/variants, heading, ordering, placement and visibility dates |
| Highlighted product | Larger spotlight card with image, approved benefit/description and Shop now action | Product/variant, approved copy, asset, destination and schedule |
| Deal of the Day | Time-limited collection of genuine active offers | Listings, linked pricing campaign, start/end, discount, optional tested deal-quantity cap and display priority |
| Festival offers | Themed campaign page, banners and product collection, such as Diwali | Campaign title/slug, approved artwork/copy, dates, eligible listings/categories, promotion/coupon linkage and placement |
| Other curated sections | New arrivals, seasonal essentials, bundles-as-collections and department picks | Reusable section type, selected products or supported query rules, limits, order and archive/publish controls |

- MERCH-01: Add an admin **Storefront & Campaigns** workspace with section list, add/edit, reorder, draft/save, preview, publish, pause and archive. Owners can manage multiple homepage/department sections without a Flutter code change.
- MERCH-02: A placement has a page/surface, supported layout template, heading, optional copy/art, product selection, item limit, display order, schedule, state and revision. Support the same product in multiple curated sections without duplicating its listing, price or inventory.
- MERCH-03: Select a sellable listing/variant explicitly for a price-bearing card or deal. Where a family card shows a starting price, compute it from eligible published variants and link to the corresponding selection. Do not highlight a nonexistent cheap variant.
- MERCH-04: Deal of the Day must reference a valid active pricing campaign. Default daily schedule is the chosen date from 00:00 to the next 00:00 in Asia/Kolkata, stored as UTC start-inclusive/end-exclusive instants. Custom windows must be labelled accurately; no countdown resets on refresh.
- MERCH-05: Festival campaigns have shareable landing pages and real start/end times, independently configurable per festival/year. Upcoming campaigns stay non-public unless explicitly published as an upcoming event with accurate dates; paused/expired offers cannot be redeemed.
- MERCH-06: Offer badges, genuine reference prices, savings and any countdown derive from server campaign data. Display remaining deal quantity only if a separate atomic campaign-allocation limit is implemented; ordinary available inventory is not proof of a limited promotional allocation.
- MERCH-07: Do not invent bestseller, most-loved, verified, organic, health-benefit or review claims. Editorial selections use labels such as Featured or Our picks; sales-based rankings require a defined real-data metric and period before use.
- MERCH-08: Public section resolution rechecks publication, seller eligibility, schedule and product availability. By default omit unavailable items from promotional slots; ordinary catalogue/detail pages can show honest unavailable states. Hide an empty section without leaving a blank carousel or broken link.
- MERCH-09: Supported dynamic collections can use category, brand or explicitly defined new-arrival rules. Stable tie-breakers, limits and fallback behavior are required. No arbitrary admin-entered SQL or executable filtering code.
- MERCH-10: Owner preview shows selected date/time, mobile/desktop layouts, affected products and effective customer prices. Draft preview is authorized and cannot be accessed through a guessed public link. Publishing and reordering are audited and protected against concurrent overwrites.
- MERCH-11: Section layouts use shared Flutter widgets for product rails/grids, spotlights and campaign banners. Festival styling uses centrally defined theme variants/tokens, not scattered component colours or uploaded executable markup. Banners have meaningful alternative text; carousels remain keyboard-usable and do not obscure navigation.
- MERCH-12: Cache invalidation covers publication, ordering, campaign expiry, price and eligibility changes. A delayed background job must never prolong a discount: the authoritative quote service evaluates the actual current time. Old product/cart views require repricing acknowledgement as described in PRICE-07.
- MERCH-13: Customers of every type can see the same public showcases and festival campaigns. Department-specific placement is navigation organization, not farmer/retailer permission gating. Paid sponsored placements and personalized advertising are separate future features, not implied by Featured.

Example owner workflow: select Storefront & Campaigns -> create a Diwali campaign draft -> select real ghee listings/variants -> attach an approved discount/coupon rule -> upload a banner -> set dates and homepage position -> preview -> publish. The product price, cart quote and checkout must agree throughout its active window; expiry removes the offer automatically without editing Flutter.

## 7. Price, promotion and transaction rules

The following are proposed initial implementation defaults; business changes must be explicit and tested.

- PRICE-01: All backend calculations use Decimal or integer minor units, never binary floating point. APIs transmit decimal strings or a documented minor-unit shape. INR display preserves paise when present.
- PRICE-02: A single pricing service calculates catalogue display prices, cart quotes and checkout totals. Storefront and admin do not independently implement discount arithmetic.
- PRICE-03: Distinguish seller listings (an offer to sell a variant) from promotions (a discount campaign). A shared catalogue variant can eventually have multiple sellers; each listing's price/stock stays seller-owned.
- PRICE-04: Baseline rule: apply one eligible automatic campaign per line using explicit priority and deterministic tie-breaking. Coupons do not stack with automatic discounts unless the campaign explicitly permits it. Define allocation, rounding and refund treatment for any stacking before enabling it.
- PRICE-05: Schedule boundaries use UTC instants; admin shows Asia/Kolkata times and the timezone clearly. Use start-inclusive/end-exclusive intervals. API quote checks determine eligibility even if a scheduler/cache is delayed.
- PRICE-06: Discounts cannot produce a negative payable amount; all displayed savings derive from genuine recorded values. Tax inclusion, shipping basis and reference-price policy must be approved before taking real orders.
- PRICE-07: Quote expiry, pricing version and item-level discount allocation are explicit. At checkout the server detects changed prices, expired offers, stock or shipping changes and requires customer review before charging a different total.
- PRICE-08: Coupon usage is reserved/redeemed atomically with the order lifecycle. Retries do not double-redeem, failed/expired attempts follow defined release rules, and per-customer limits are enforced server-side.
- PRICE-09: Completed orders snapshot product/variant labels, seller, quantities, prices, applied promotions, taxes, shipping and address. Later admin edits do not change historic invoices/order amounts.
- ORDER-01: Define a finite inventory hold for unpaid orders, with expiry/release and cancellation recovery. The current checkout decrements stock at pending-order creation; reconcile this deliberately during migration rather than adding a second decrement/reservation on top.
- ORDER-02: Payment attempts, refunds, order status and shipment status are separate state machines. Only verified gateway events and controlled reconciliation can confirm payment; signatures, amounts, currency and order mapping must be checked.
- ORDER-03: Checkout, callbacks and refunds are idempotent under concurrent requests and duplicate/out-of-order events. Persist deduplication keys; test rollback and recovery, not just sequential retries.

## 8. Architecture and data boundaries

Use a modular monolith: one deployable FastAPI backend and one PostgreSQL database with clear module ownership. Reuse existing modules and add responsibilities incrementally rather than performing a broad folder rewrite. Flutter remains the client for storefront and protected workspaces. Redis/background workers and media storage are infrastructure, not separate business backends.

| Module | Owns | Boundary |
| --- | --- | --- |
| Identity/access | Users, membership, capabilities, sessions | Other modules request authorization; browsing does not depend on user type |
| Catalogue | Departments, categories, brands, attribute definitions, product families/variants | Public API returns published data; no cart/payment logic |
| Merchant listings | Seller-owned SKUs, listing versions, publish approvals | Shared variant metadata and seller-specific commercial data are distinct |
| Media | Upload intents, verified assets, ownership and ordering | Storage adapter; no arbitrary cross-seller asset attachment |
| Pricing/promotions | Price versions, campaigns, eligibility, quote calculation | Sole authority for monetary calculations |
| Inventory | Stock, lots, reservations and adjustment ledger | Transactional availability checks; no editable derived stock counters |
| Orders/fulfillment | Order snapshots, shipment groups, state transitions | Coordinates purchase transactions; retains immutable history |
| Payments | Attempts, provider events, refunds and reconciliation | Gateway adapters; never trusts browser success messages |
| Content/admin | Banners, featured/spotlight sections, daily deals, festival landing pages, placements, settings and audit views | References listings and pricing campaigns; calls domain services, not ad-hoc direct table updates |
| Veterinary services, future | Professional verification, availability, booking and consultation records | Shares identity/provider abstractions where appropriate; does not become a physical-product SKU |

Future entity map, to be introduced only when its phase needs it:

- `Department`, `Category`, `Brand`, `ProductType`, versioned `AttributeDefinition`.
- `ProductFamily`, `ProductVariant`, seller-owned listing preserving current `Product.id` compatibility where practical. Use a mapping/adapter before deciding to rename any table; never duplicate live stock identities accidentally.
- `SellerOrganization`, `SellerMembership`, `UserCapability` and optional buyer profile/preferences.
- `MediaAsset`, `ListingRevision`, `ListingApproval`, `PriceVersion`, `Promotion`, `Coupon`, `Redemption`.
- `StorefrontSection`, `SectionItem`, `Placement` and `MerchandisingCampaign` reference published listings and optional pricing promotions. They never own a second copy of a product price or inventory quantity.
- `InventoryLot`, `StockMovement`, `Reservation`, `Order`, `OrderItem`, `Shipment`, `PaymentAttempt`, `Refund`, `AuditEvent`.
- Future `VeterinaryProfile`, `AvailabilitySlot`, `Appointment` and restricted clinical records. Existing DairyAI veterinary modules require a reuse/parity audit first.

Adding a new category should be a data operation. Adding a new workflow, such as consultations, rentals or subscription deliveries, is a deliberate module extension with its own states and tests; metadata alone does not make arbitrary future functionality automatic.

### API and UI contracts

- Preserve the existing `/api/v1/marketplace/products`, cart, address and order contracts while introducing additive IDs and metadata. Publish changed shapes and deprecation rules before retiring fields.
- Add scoped admin commerce endpoints and public taxonomy endpoints; do not bypass seller-only handlers by having admins pretend to be sellers. Reuse domain services underneath both authorized paths.
- Define stable pagination, error codes, validation paths, price types and optimistic-concurrency versions in schemas. Test actual API responses against Flutter parsers.
- Keep public routes under `/shop` and existing compatible product URLs; protected commerce admin, seller and future vet workspaces have explicit navigation. Route names alone are not security boundaries.
- Global Flutter design system remains `mobile/lib/app/store_theme.dart`. Extend shared widgets for page containers, forms, data tables, status badges, galleries, prices and empty/error states. Seller/admin pages share tokens but use task-appropriate layouts.
- Public descriptions and images have semantic labels. Validate search discoverability, share previews, canonical URLs and metadata for the Flutter web delivery model; do not claim an HTML wrapper alone provides product SEO.

## 9. Migration, reliability and launch gates

- MIG-01 (updated user decision, 2026-09-11): Until deployment or data retention is required, use an explicit clean full-schema rebuild from current models, not incremental ALTER migrations. Local data is disposable. See LOCAL_DATABASE_REBUILD.md; never reset on ordinary startup. MIG-02 through MIG-04 apply when retained data/production migrations are introduced, not to the disposable local reset workflow.
- MIG-02: Backfill the four known Milterra food demo SKUs by reviewed IDs/SKUs, not broad title heuristics. Review all existing feed/equipment products before mapping legacy categories. Re-runs must be safe.
- MIG-03: Backfill existing roles into capability memberships without silently promoting users. Legacy routes continue working until every corresponding authorization path is tested; avoid inconsistent dual sources of authority.
- MIG-04: Take and test a backup; run migrations on a populated disposable copy. Verify row counts, references, old/new API compatibility and recovery strategy before applying to the live local or production database.
- NFR-01: Backend authorization tests cover anonymous users, ordinary buyers, approved/unapproved sellers, cross-seller IDs, staff scopes and revoked users. Draft media and personal data must not leak through public APIs or caches.
- NFR-02: Validate uploads by content and size, generate storage keys, restrict access and clean abandoned uploads. Do not server-fetch arbitrary user-provided URLs without SSRF protection.
- NFR-03: Rate-limit authentication and sensitive writes; do not log OTPs, access tokens or unnecessary phone/address data. Audit privileged changes with actor, target, time, reason and relevant before/after values.
- NFR-04: Request IDs, structured errors, health checks and monitoring cover order/payment failures and background jobs. Persist recoverable work; use an outbox/idempotent handlers if asynchronous events cross transaction boundaries.
- NFR-05: Define measurable performance targets before load acceptance; test bounded server queries, indexed filters, image sizing and pagination against a representative catalogue. Remove fetch-all client filtering before a large catalogue launch.
- NFR-06: Verify responsive public and admin flows at phone, tablet and desktop widths, keyboard navigation and meaningful text scaling. A clean focused analyzer run is not proof that every old DairyAI screen is healthy.
- LAUNCH-01: Real payment confirmation, reservation recovery, shipping/serviceability, cancellation/refund handling, customer support, approved policies, required product content and backup/restore are release gates for taking real money.
- LAUNCH-02: Production uses HTTPS, explicit allowed origins, secure secrets, no demo OTP bypass and no debug-mode customer deployment. Credentials, provider activation, domain configuration and real transactions require separate explicit operational approval.

## 10. Deferred capabilities and business decisions

Architect for these without pretending they exist: third-party seller payouts/commissions, negotiated retailer price lists, bulk packs, verified-purchase reviews, wishlists, subscriptions, loyalty, advanced search, warehouse expansion, veterinary booking, clinical access controls and equipment rentals. Audience-specific commercial terms must never hide ordinary public products merely because of a profile label.

Decisions needed at their implementation boundary, not to block catalogue/admin foundations:

1. Launch with Milterra-owned stock only, or immediately approve third-party sellers? Proposed first delivery: first-party admin merchandising; preserve seller isolation for the next phase.
2. Supply actual product data/images for the five named Farm Essentials products; unconfirmed items remain drafts.
3. Approve tax/reference-price policy, delivery geography/charges, cold-chain constraints and return/refund rules before live checkout.
4. Choose/activate payment and storage providers, notification channels and cash-on-delivery policy before enabling them. Do not assume credit terms, payouts or SMS spending.
5. Confirm promotion stacking rules before enabling stacked discounts; initial non-stacking behavior is specified above.
6. Define verification criteria and permissions before onboarding sellers, staff or veterinary professionals to production.

## 11. End-to-end acceptance examples

- ACC-01: A household visitor in Lucknow can browse ghee and CALCI-PRO without login or selecting a customer type. Add to cart prompts login; the chosen variant/quantity is retained and the customer stays in shopping, not a farm dashboard.
- ACC-02: A farmer, seller, retailer and future verified vet can each buy across both departments with one account. An ordinary buyer cannot access product administration by changing a URL or API payload.
- ACC-03: An authorized owner creates a category, product family and two variants, uploads photos, sets prices and stock, previews and publishes from the admin UI. Public listing/detail/search update without a Flutter code change.
- ACC-04: An incomplete or rejected seller draft is invisible publicly. Seller A cannot read or alter seller B's protected listing revisions, media, inventory or order data.
- ACC-05: A scheduled offer changes the same authoritative price on listing, detail, cart and checkout. On expiry or price change during checkout, customers review a new quote before being charged.
- ACC-06: Concurrent purchases of the last available unit and concurrent final coupon redemptions respect stock/usage limits. Callback retries do not create additional orders, stock movements or charges.
- ACC-07: After an order is placed, changing a product title, pack size, seller price or campaign leaves the order's recorded details and amount unchanged.
- ACC-08: Changing shared theme tokens updates the new storefront and commerce admin components consistently. Tests catch overflow, inaccessible controls and inconsistent price formatting.
- ACC-09: For the current disposable local workflow, a confirmed rebuild creates all current tables and reviewed demo data, a repeat reset leaves no previous data, and a failed rebuild rolls back. When retained data is introduced, migrations must preserve identities and history. Existing compatible API contracts and URLs remain functional.
- ACC-10: Unpaid expired orders release their holds exactly once; verified payments, cancellations and refunds follow the documented lifecycle. No browser-only action marks an order paid.
- ACC-11: The owner features a product, reorders its section and publishes a spotlight entirely in admin; home/department pages update without a Flutter release. Archiving the listing removes it from every public showcase.
- ACC-12: A daily deal starts/ends at its configured boundary, including a page left open across expiry. Refreshing cannot reset its deadline; checkout rejects an expired discount and requests review of the new total. Any deal-allocation limit survives concurrent purchases and retries.
- ACC-13: A festival campaign has a working shareable page and scheduled banners. Draft previews stay private; unpublished products never leak; pause/expiry removes the promotion from all purchase surfaces. All buyer types can browse it.
- ACC-14: Homepage, results, product detail, cart and checkout satisfy the mandatory Amazon-style layout contract, with dated references and Milterra screenshots. The product-detail desktop view has the required gallery/information/purchase zones; results have sidebar filtering and aligned product cards. Responsive checks show no clipped or overlapping content. First-template visual acceptance is recorded rather than inferred from passing tests.

## 12. Definition of done

A phase is complete only when its backend contract, authorization, migration (if needed), usable Flutter workflow, focused automated tests, negative cases and manual acceptance all pass. Customer-facing slices must also pass the mandatory Amazon-style layout contract and applicable visual acceptance. Record what was checked and what remains unverified. Requirements, screen mockups, endpoint presence or a successful build alone are not completion. No commit, push, deployment or real payment is implied by this planning document.
