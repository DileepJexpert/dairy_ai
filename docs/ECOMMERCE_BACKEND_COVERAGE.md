# Ecommerce backend integration coverage

## Source of truth

FastAPI and PostgreSQL own business records. Flutter renders API responses and
keeps only transient view state (selected tabs, filters, form drafts). Preserve
the Amazon-style store layout and Milterra colour tokens. Do not reintroduce
demo product fallbacks or success notifications after failed saves.

Implemented customer integrations:

- Catalogue, product families, variants, prices, inventory and merchandising.
- Coupon eligibility and checkout discount snapshots.
- Product reviews, concept feedback, published certificates.
- Authenticated wishlist, including non-purchasable family concepts.
- Atomic cart-to-saved and saved-to-cart operations; restoration rechecks stock.
- Customer order history, server timelines, cancellation and pending payment state.
- Pre-launch payment preference saved without card, bank or UPI credentials.
- Admin interest follow-up status and internal notes, with audit records.
- Paid-order operations filtered by vendor ownership or admin role. Real
  tracking references are entered manually; no courier booking is implied.
- Authenticated notifications with correct read/read-all APIs.
- Customer profile/preferences; preferences filter in-app notification types.
- Published help content, authenticated enquiries, admin replies and notifications.
- Seller quick-publish form uses existing backend product/inventory APIs. It
  creates drafts before publishing; inspect saved drafts after a partial failure.

Already integrated admin controls from the previous slice remain: seller approval,
offer pricing/stock, coupons, certificates, product publishing, placements and audit.

## Deliberate limits / remaining work

This is **not a claim that every DairyAI module is production-ready**.

- Wallet status is returned by the backend as unavailable with zero balances;
  there is no financial ledger, gateway, bank payout or automatic milk settlement.
  The separate cooperative milk-intake calculator remains a labelled preview.
- Prelaunch mode captures interest only. Real payment callbacks, refunds,
  invoices, stock release for failed/expired payments and courier integrations
  require their own implementation before real commerce is enabled.
- Multiple sellers' items are isolated in operations views. Dispatch of a
  mixed-vendor basket is blocked until per-seller shipment records are supported;
  one vendor must not overwrite another vendor's courier reference.
- Seller registration requires an existing vendor-role account. Public seller
  applications and role approval are not a self-service role escalation flow.
  Bank payout details are not collected or used by the new commerce APIs.
- Marketing story assets, some informational copy and legal pages remain
  code-managed, not a complete content-management system. FAQs/contact content
  are admin-editable now. Static presentation code is not business-record storage.
- Media remains existing asset/URL based. No paid S3 service was introduced;
  general local file upload/storage lifecycle is a separate feature.
- WhatsApp recovery prepares a backend message with an eligible persisted
  coupon (if any), and copies a link for manual use. It never claims a message
  was sent or a sale recovered. No RECOVER10 coupon is invented.
- Language preference is persisted; it does not by itself translate all content.
- Veterinary, livestock and cooperative workflows outside ecommerce have not
  received full end-to-end acceptance in this slice.

## Schema and testing

Migration head: `customer_commerce_v13`, additive only. For the existing disposable
development database run `python -m scripts.initialize_customer_commerce` after
`initialize_commerce_admin`; no reset is necessary. Seven new tables and missing
initial FAQ content are created. Existing users, products, orders and carts remain.

Tests use disposable in-memory SQLite, not the user's local database. They cover
persistence after commit/provider recreation, ownership, failed writes, stock
validation, cancellation idempotency, prelaunch fulfillment blocking, support and
profile contracts. SQLite tests do not prove PostgreSQL concurrent-lock behaviour.

Manual acceptance after server restart:

1. Customer A saves wishlist/cart/addresses and places an interest; refresh and
   confirm all records return. Customer B must not see A's records.
2. Cancel an unpaid order twice; ensure a single cancellation event, no refund,
   and no stock increment for a prelaunch interest.
3. Admin saves follow-up notes and replies to support; refresh both accounts.
   Customer sees the support reply, never staff-only follow-up notes.
4. Publish an FAQ, coupon, offer or product in admin; confirm storefront reflects it.
5. Check desktop/tablet/mobile, API-offline errors, sign-out and role changes.
6. Test real PostgreSQL concurrent checkout/cancel/save requests before deployment.

Validation on 2026-09-14: full backend suite 254 passed / 1 skipped; the final
orders/customer/analytics regression rerun passed 15 tests after tightening the
prelaunch fulfillment guard. Flutter's focused commerce/catalogue suite passed
36 tests, and the new customer/help test file passed all 7 tests (including 3
additional responsive editor checks). Web release compilation passed; existing
WebAssembly compatibility warnings concern flutter_secure_storage_web, not the
normal JavaScript build. Repository-wide analysis still has existing warnings
and style notices; the source-error-only pass returned no compiler errors.

The local service on port 8002 returned 404 for the new help endpoint before
restart. Database initialization succeeded against localhost:5432/dairy_ai with
APP_ENV=development; browser-to-live-server acceptance remains to be performed
after restarting backend and Flutter. Deployment remains pending.
