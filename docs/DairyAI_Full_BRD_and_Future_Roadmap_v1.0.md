# DairyAI - Business Requirements Document (BRD) & Future Product Roadmap

**Version:** 1.0  
**Baseline:** GitHub `main` commit `fbde8b4fa0145e43a3e522de585073d27a7624ff` (4 September 2026)  
**Product thesis:** Dairy Operating System + Trusted Commerce Network for the Indian dairy ecosystem.  
**Roadmap horizon:** September 2026 onward, with farm-pilot readiness targeted around May 2027.

## Executive Summary

DairyAI should be treated as one connected platform, not a collection of unrelated features. The platform records what happens on the farm, turns those records into timely decisions, connects trusted professionals and buyers/sellers, and closes the loop through commerce, collection and payments. Its strongest long-term differentiator is the trust layer: marketplace claims can be supported by real milk, health, vaccination, breeding, sensor and professional-verification records rather than seller-entered text alone.

The project is organized into four pillars: **Farm OS**, **Health & Intelligence**, **Market & Money**, and **Network & Trust**. Product commerce and livestock commerce remain separate business workflows. Within product commerce, ordinary goods, prescription supplies, genetics/cold-chain and equipment rental have different state machines.

## Current Implementation Baseline

- **Identity & role routing - Implemented foundation:** OTP/JWT, farmer/vet/admin roles; super-admin/vendor/cooperative modules exist. Next: Harden sessions, delegated staff, verification workflow.

- **Farm & herd - Implemented MVP:** Farmer/cattle APIs and Flutter herd flows exist. Next: Unify longitudinal animal timeline and ownership transfer.

- **Health/vaccination - Implemented MVP:** Health, vaccinations, triage, withdrawal/outbreak modules exist. Next: Clinical audit UX, action inbox, production validation.

- **IoT - Implemented MVP:** ESP32/MQTT ingestion, sensor processing and alerts exist. Next: Device management, connectivity/offline, calibration and fleet ops.

- **Milk - Implemented MVP:** Milk recording/summary and price capabilities exist. Next: Collection reconciliation and buyer settlement depth.

- **Feed/breeding/finance - Implemented MVP:** Core APIs/services/mobile features exist. Next: Real-world validation and stronger unit economics.

- **Vet Connect - Implemented foundation:** Vet profile/consultation/prescription flows exist. Next: Scheduling, video hardening, field/paravet operations.

- **Cooperative/collection/payments - Implemented foundation:** Dedicated API/mobile modules are registered. Next: Production settlement, reconciliation and operator workflows.

- **Livestock marketplace - Phase 1 implemented:** Listings, filters, favorites, inquiries, sold status, health flags. Next: Herd-prefill, evidence verification, visits/reservation/transfer.

- **Product marketplace - In progress:** Product catalog, inventory, media, cart and saved addresses committed. Next: Orders/checkout, payments, delivery, vendor fulfillment.

- **Milk purity public tool - Implemented foundation:** Search, score, comparison/leaderboard foundation exists. Next: Source governance, legal review, lab/regulatory ingestion.

- **Vision/ML - Prototype/foundation:** Disease/feed/yield/vision components exist. Next: Data collection, validation, MLOps, confidence/drift monitoring.

- **Schemes/mandi/Pashu Aadhaar/carbon - Implemented foundation:** Backend modules exist. Next: Authoritative data integrations and freshness governance.

- **WhatsApp/Bhashini/partner APIs - Integration foundation:** Connectors/config patterns exist. Next: Production credentials, consent, retries, quotas and monitoring.

## Future Roadmap

- **0. Consolidate baseline (Sep 2026) - Stabilize architecture and tests:** Full suite reliability; API inventory; migration chain; error model; observability baseline; BRD becomes source of scope truth. Exit: No unresolved critical data-integrity defects.

- **1. Commerce spine (Sep-Oct 2026) - Complete product purchase lifecycle:** Order schema/snapshots; checkout; idempotency; inventory transition; order history; payment state model; Flutter checkout/success. Exit: End-to-end test: catalog → cart → address → order → payment pending/paid.

- **2. Vendor fulfillment (Nov-Dec 2026) - Make orders operable, not just creatable:** Vendor sub-orders; fulfillment status; delivery zones/charges; cancellations/refunds; payout reconciliation; media upload; vendor order console. Exit: A real pilot vendor can fulfill and reconcile orders without DB intervention.

- **3. Specialized commerce (Dec 2026-Feb 2027) - Add domain-specific transaction types:** Prescription approval; genetics provenance/cold chain; equipment rental booking/deposit; paravet allocation where needed. Exit: Each category has its own valid business state machine and tests.

- **4. Trusted livestock marketplace (Jan-Mar 2027) - Move from classifieds to evidence-backed animal commerce:** Herd-to-listing prefill; milk/health/breeding evidence; verified claim badges; inspection/visit; reservation; sale/transfer history; transport checklist. Exit: Buyer can distinguish claimed vs recorded vs professionally verified information.

- **5. Farm pilot readiness (Apr-May 2027) - Make daily farm use reliable:** Offline queue/sync; multilingual/voice; unified action inbox; staff delegation; daily farm dashboard; backup/restore; mobile UX polish. Exit: A working dairy can run daily records with minimal spreadsheet dependence.

- **6. Cooperative & collection network (Jun-Sep 2027) - Connect farmer production to milk procurement/payout:** Collection slips; quality/rate calculation; settlement; member ledger; route/center reconciliation; dispute handling; partner APIs. Exit: Farmer and collection center see matching, reconcilable transactions.

- **7. Predictive intelligence (Oct-Dec 2027) - Turn accumulated data into validated predictive value:** Health anomaly models; yield forecast; feed optimization; breeding insights; MLOps; model monitoring; human review. Exit: Models beat defined baselines on real held-out/pilot data and fail safely.

- **8. Platform scale (2028+) - Build network effects and partner ecosystem:** Multi-tenant SaaS; partner APIs; stronger search; logistics/lab integrations; optional insurance/credit referrals; sustainability analytics. Exit: Economics and operations justify scale architecture changes.

## Detailed Functional Requirements

### Identity, Access & Profile

- `FR-IAM-001` **MUST** - Authenticate primarily by mobile OTP and issue secure access/refresh tokens.

- `FR-IAM-002` **MUST** - Support role-aware experiences for farmer, veterinarian, vendor, cooperative/collection operator, admin and super-admin.

- `FR-IAM-003` **MUST** - Enforce ownership and tenant isolation on every farmer, cattle, listing, order, consultation and financial record.

- `FR-IAM-004` **MUST** - Allow profile, language, farm location and notification preferences to be managed independently from authentication.

- `FR-IAM-005` **SHOULD** - Support delegated farm staff access with least-privilege permissions and an audit trail.

- `FR-IAM-006` **SHOULD** - Support account recovery, device/session revocation and suspicious-login controls.

### Farm, Herd & Animal Digital Record

- `FR-HERD-001` **MUST** - Maintain a unique digital record for every animal with tag/identity, breed, sex, age/date of birth, lifecycle status and ownership.

- `FR-HERD-002` **MUST** - Show a herd dashboard with lactating, dry, pregnant, sick, due and attention-required animals.

- `FR-HERD-003` **MUST** - Link milk, health, vaccination, breeding, feed, sensor and marketplace history to the same animal identity.

- `FR-HERD-004` **SHOULD** - Store photos/documents and support ear-tag/QR/NFC association where practical.

- `FR-HERD-005` **SHOULD** - Support ownership-transfer history so a sold animal keeps a tamper-evident history while private farmer data remains protected.

- `FR-HERD-006` **COULD** - Integrate authorized government livestock identity systems such as Bharat Pashudhan/Pashu Aadhaar when official access is available.

### Milk Production, Quality & Sale

- `FR-MILK-001` **MUST** - Record per-animal milk by date/session and aggregate at animal, herd and farm level.

- `FR-MILK-002` **MUST** - Capture fat/SNF, buyer, realized price and rejection/quality notes when available.

- `FR-MILK-003` **MUST** - Show daily/weekly/monthly production trends and compare yield with feed/health/breeding events.

- `FR-MILK-004` **SHOULD** - Track buyer prices and recommend net realized options after transport/collection costs.

- `FR-MILK-005` **SHOULD** - Support cooperative/collection-center receipt, quality testing, deductions and payout reconciliation.

- `FR-MILK-006` **COULD** - Support direct subscriptions/B2B milk routes and farm-output storefronts after licensing and fulfillment controls are ready.

### Feed, Nutrition & Cost

- `FR-FEED-001` **MUST** - Generate and store animal-level feed plans using weight/lactation/yield/condition and locally available inputs.

- `FR-FEED-002` **MUST** - Show feed cost per animal/day and feed cost per litre of milk.

- `FR-FEED-003` **SHOULD** - Compare planned versus actual ration and detect cost or nutrient deviation.

- `FR-FEED-004` **SHOULD** - Use mandi/vendor prices to optimize ration cost subject to nutritional constraints.

- `FR-FEED-005` **COULD** - Connect farm feed inventory, reorder alerts and vendor marketplace purchase suggestions.

### Breeding & Reproduction

- `FR-BREED-001` **MUST** - Track heat, insemination, pregnancy check, expected calving, calving outcome and dry-off events.

- `FR-BREED-002` **MUST** - Generate due reminders for pregnancy checks, repeat heat and calving preparation.

- `FR-BREED-003` **SHOULD** - Maintain sire/semen provenance and genetic attributes when genetics products are used.

- `FR-BREED-004` **SHOULD** - Provide reproductive performance indicators and flag repeated failures for professional review.

- `FR-BREED-005` **COULD** - Recommend compatible sires/genetics based on breed goal, inbreeding avoidance and production traits using validated data.

### Health, Vaccination, Withdrawal & Outbreak

- `FR-HEALTH-001` **MUST** - Maintain health events, symptoms, diagnosis, treatment, medicine, vet and follow-up records.

- `FR-HEALTH-002` **MUST** - Schedule and alert vaccination/deworming due dates.

- `FR-HEALTH-003` **MUST** - Track medicine withdrawal periods and block/flag unsafe milk sale records during active withdrawal windows.

- `FR-HEALTH-004` **SHOULD** - Provide herd-level outbreak alerts using geography and reported disease signals with appropriate confidence.

- `FR-HEALTH-005` **SHOULD** - Create one action inbox combining sensor, vaccination, breeding and clinical reminders.

- `FR-HEALTH-006` **MUST** - Clearly distinguish AI advisory output from veterinarian diagnosis and preserve the source of each clinical assertion.

### IoT, Sensors & Alerts

- `FR-IOT-001` **MUST** - Ingest cattle sensor telemetry through MQTT/HTTP with device and animal identity.

- `FR-IOT-002` **MUST** - Store time-series readings and expose latest values, trends and alert history.

- `FR-IOT-003` **MUST** - Validate readings, reject malformed data and deduplicate repeated events.

- `FR-IOT-004` **SHOULD** - Detect deviations in temperature/activity and route prioritized alerts with cooldown/dedup logic.

- `FR-IOT-005` **SHOULD** - Track device battery/connectivity and provide device-health alerts.

- `FR-IOT-006` **COULD** - Support edge inference and store-and-forward behavior for farms with intermittent connectivity.

### AI, Vision, Chat & Voice

- `FR-AI-001` **MUST** - Provide explainable symptom triage with severity, red flags, rationale and recommended next action.

- `FR-AI-002` **MUST** - Keep model/rule version, input provenance and confidence metadata for material AI outputs.

- `FR-AI-003` **SHOULD** - Provide phone-camera assessments for body condition, skin, lameness, udder and other validated visual use cases.

- `FR-AI-004` **SHOULD** - Provide yield forecasting and feed optimization only after validation against real farm data.

- `FR-AI-005` **MUST** - Support multilingual interaction and simple language; voice should be a channel over the same trusted domain data.

- `FR-AI-006` **MUST** - Never let the LLM invent medication dosage, lab results, government eligibility or marketplace verification.

- `FR-AI-007` **SHOULD** - Use retrieval from the farmer/animal record so answers are contextual and traceable.

### Vet / Paravet Network

- `FR-VET-001` **MUST** - Allow verified veterinarians to maintain profile, qualifications, availability and service fee.

- `FR-VET-002` **MUST** - Support consultation request, accept, start, end, prescription, follow-up and rating lifecycle.

- `FR-VET-003` **SHOULD** - Support video/voice consultation and attachment sharing where connectivity permits.

- `FR-VET-004` **SHOULD** - Allow paravet/AI-tech allocation for field activities such as sample collection, vaccination, insemination or inspection where the operating model permits.

- `FR-VET-005` **MUST** - Preserve clinical audit history and actor identity for prescriptions and approvals.

### Finance & Farm Economics

- `FR-FIN-001` **MUST** - Record farm income and expense transactions with categories and dates.

- `FR-FIN-002` **MUST** - Provide farm P&L and unit economics including feed cost/litre and animal-level profitability where data is sufficient.

- `FR-FIN-003` **SHOULD** - Reconcile milk collection payouts, marketplace orders, refunds, commissions and vendor payouts.

- `FR-FIN-004` **SHOULD** - Support cash-flow view and upcoming obligations.

- `FR-FIN-005` **COULD** - Enable opt-in partner financing/insurance referrals only with explicit consent and regulated partners; DairyAI should not become the lender/insurer in early phases.

### Cooperative & Milk Collection

- `FR-COOP-001` **MUST** - Support cooperative/collection-center identity, member mapping and collection points.

- `FR-COOP-002` **MUST** - Record farmer milk receipt with quantity, quality, rate, deductions and net payable.

- `FR-COOP-003` **MUST** - Provide shift/day reconciliation and farmer payout status.

- `FR-COOP-004` **SHOULD** - Support route/collection-center analytics, exception handling and bulk settlement exports/APIs.

- `FR-COOP-005` **SHOULD** - Make farmer-visible collection data consistent with cooperative records to reduce disputes.

### Livestock Marketplace

- `FR-LIVE-001` **MUST** - Keep livestock commerce separate from ordinary product cart commerce.

- `FR-LIVE-002` **MUST** - Support cattle listing search/detail, filters, favorites, inquiries, seller response and sold/cancelled lifecycle.

- `FR-LIVE-003` **MUST** - Allow a listing to be generated from a farmer-owned animal record and copy relevant history as a listing snapshot.

- `FR-LIVE-004` **MUST** - Show provenance of claims such as milk yield, pregnancy, vaccination and health verification rather than a single unqualified verified badge.

- `FR-LIVE-005` **SHOULD** - Support farm visit/inspection booking, veterinarian inspection report and reservation/deposit.

- `FR-LIVE-006` **SHOULD** - Support negotiated sale, buyer/seller identity checks, transport/fitness documentation and ownership transfer.

- `FR-LIVE-007` **MUST** - Protect seller privacy; direct phone/address exposure should be controlled rather than public by default.

- `FR-LIVE-008` **COULD** - Provide price intelligence by breed, age, lactation, region and verified production history.

### Product Marketplace & Specialized Commerce

- `FR-COM-001` **MUST** - Support vendor-managed product catalog, inventory, media, price, tax, pack/unit and active status.

- `FR-COM-002` **MUST** - Support cart validation using authoritative server price, minimum quantity, stock and active-product state.

- `FR-COM-003` **MUST** - Support saved delivery addresses with one safe default and ownership isolation.

- `FR-COM-004` **MUST** - Implement transactional checkout: validate cart, snapshot address/items, calculate totals, create order and clear cart atomically.

- `FR-COM-005` **MUST** - Make checkout idempotent and safe against double taps/retries.

- `FR-COM-006` **SHOULD** - Reserve/decrement inventory through a consistent order lifecycle rather than at cart time.

- `FR-COM-007` **SHOULD** - Split fulfillment into vendor sub-orders when one customer order contains multiple vendors.

- `FR-COM-008` **SHOULD** - Support standard goods such as feed/nutrition and equipment through normal order fulfillment.

- `FR-COM-009` **SHOULD** - Support prescription-controlled veterinary supplies with prescription upload/approval and restricted fulfillment rules.

- `FR-COM-010` **SHOULD** - Support genetics/semen as a specialized cold-chain order with sire/provenance and cryogenic handling metadata.

- `FR-COM-011` **SHOULD** - Support equipment rental as availability booking with deposit, time/acre pricing and return condition rather than a normal sale.

- `FR-COM-012` **COULD** - Support farm outputs such as branded ghee, milk, compost or feed only after applicable food/product compliance and fulfillment capabilities are in place.

### Orders, Payments, Delivery, Returns & Payouts

- `FR-ORD-001` **MUST** - Maintain immutable order and item snapshots independent of later product/address changes.

- `FR-ORD-002` **MUST** - Separate order status from payment status and expose a clear state machine.

- `FR-ORD-003` **MUST** - Calculate price, delivery, discounts/tax on the server; never trust client totals.

- `FR-ORD-004` **SHOULD** - Integrate payment gateway with idempotent initiation, webhook verification and reconciliation.

- `FR-ORD-005` **SHOULD** - Support COD or alternative rails only when operationally justified and risk-controlled.

- `FR-ORD-006` **SHOULD** - Support delivery zones, charges, shipment/tracking, failed delivery and proof of delivery.

- `FR-ORD-007` **SHOULD** - Support cancellation, return/refund rules by product type and vendor payout holds.

- `FR-ORD-008` **SHOULD** - Support escrow-like payout-state tracking for marketplace trust, subject to payment-partner/legal design.

### Government Schemes, Mandi & External Knowledge

- `FR-EXT-001` **SHOULD** - Provide scheme discovery with eligibility questions, source links, document checklist and application status where supported.

- `FR-EXT-002` **MUST** - Clearly label government information source and freshness; do not hallucinate eligibility or benefits.

- `FR-EXT-003` **SHOULD** - Provide mandi/feed ingredient price history and trends with location/date provenance.

- `FR-EXT-004` **COULD** - Use these feeds in decision support such as feed optimization, procurement and farm cash planning.

### Milk Purity / Public Trust Tool

- `FR-PURITY-001` **SHOULD** - Maintain public brand search, comparison, score breakdown and methodology transparency.

- `FR-PURITY-002` **MUST** - Separate verified lab/regulatory facts from illustrative/demo data and user submissions.

- `FR-PURITY-003` **MUST** - Preserve source/date/version for every score input and support correction/dispute workflow.

- `FR-PURITY-004` **SHOULD** - Use the public tool as acquisition into the broader platform without compromising data integrity.

### Carbon & Sustainability

- `FR-CARB-001` **COULD** - Estimate farm carbon footprint from documented methodology and clearly label assumptions.

- `FR-CARB-002` **COULD** - Track interventions such as feed efficiency, manure/biogas and energy use over time.

- `FR-CARB-003` **COULD** - Delay carbon-credit monetization until data quality, verification and partner methodology are mature.

### Notifications & Engagement

- `FR-NOTIF-001` **MUST** - Provide in-app notifications with read/unread state and deep links to the action.

- `FR-NOTIF-002` **SHOULD** - Use FCM/WhatsApp/voice channels based on user preference, urgency and consent.

- `FR-NOTIF-003` **MUST** - Deduplicate noisy alerts and support quiet hours/non-critical digesting.

- `FR-NOTIF-004` **SHOULD** - Prioritize action-required messages over generic engagement notifications.

### Admin, Trust, Operations & Support

- `FR-ADM-001` **MUST** - Provide admin/super-admin visibility into users, vets, vendors, cooperatives, listings, orders and risk flags.

- `FR-ADM-002` **MUST** - Support verification workflow for vets/vendors and evidence review with audit logs.

- `FR-ADM-003` **SHOULD** - Provide dispute, refund, listing-report and content moderation workflows.

- `FR-ADM-004` **SHOULD** - Expose operational dashboards for failed payments, stuck orders, inactive devices and overdue farm actions.

- `FR-ADM-005` **MUST** - All privileged actions must be attributable to an operator and timestamp.

## Non-Functional Requirements

- **Availability:** Pilot target 99.5%; scale target 99.9% for customer-facing APIs. Degraded external integrations must not take down core farm records.

- **Performance:** Proposed p95: normal reads <500 ms, normal writes <1 s on healthy network excluding media/external APIs. Use async jobs for expensive work.

- **Offline/low bandwidth:** Critical farmer and collection actions should cache, queue and sync safely; avoid mandatory high-resolution media for core operations.

- **Security:** TLS, secure secret storage, JWT rotation, RBAC/ABAC, rate limits, input validation, webhook signatures, dependency scanning and audit logs.

- **Privacy:** Data minimization, explicit purpose/consent, user-visible deletion/export pathways, restricted precise location/phone exposure and DPDP readiness.

- **Data integrity:** UUID/unique constraints, transactions, idempotency, immutable financial/order snapshots, migration discipline and reconciliation.

- **Observability:** Structured logs with correlation IDs, metrics, tracing, alerting, failed-job queues, payment/order reconciliation dashboards.

- **Scalability:** Keep modular monolith while small; scale stateless API horizontally; isolate time-series and async workloads; extract services only with measurable need.

- **Localization:** Hindi + English first; architecture should allow Indian-language packs and Bhashini/voice without duplicating business logic.

- **Accessibility/usability:** Large touch targets, simple language, icon+text, low cognitive load, clear offline/loading/error states.

- **Testability:** Every critical state transition gets unit + API tests; checkout/payment/transfer paths require concurrency/idempotency tests.

- **Auditability:** All verification, clinical, money, listing status and privileged admin actions record actor, time, source and before/after state where material.

## Risks and Mitigations

- **Feature sprawl / “feature museum” (High):** Many modules exist before a few core workflows are production-deep. Mitigation: Roadmap by vertical journeys; freeze new modules until order, livestock trust and farm daily-use flows are complete.

- **Unverified marketplace claims (High):** Animal production/health claims can be inaccurate. Mitigation: Evidence levels: seller-claimed, system-recorded, vet/lab verified; immutable snapshots; dispute path.

- **AI overreach (High):** Health/feed/genetic recommendations can be wrong without validated data. Mitigation: Human-in-loop, confidence, source/version, conservative red flags, no fabricated dosage/facts.

- **Payment/order inconsistency (High):** Retries/webhooks can create duplicates or mismatched payout state. Mitigation: Idempotency keys, transactional outbox, gateway signature verification, reconciliation jobs.

- **Inventory race conditions (High):** Cart does not reserve stock; concurrent checkout can oversell. Mitigation: Authoritative checkout validation + atomic reservation/decrement with row locking/versioning.

- **Poor rural connectivity (High):** Mobile workflows can fail at the farm/collection point. Mitigation: Offline-first queue, local cache, resumable uploads, sync conflict rules, lightweight screens.

- **Data privacy (High):** Phone, location, farm economics, health records and seller identity are sensitive. Mitigation: Purpose limitation, consent, least privilege, encryption, retention/deletion controls and DPDP readiness.

- **Regulatory expansion (Medium-High):** Food, veterinary products, payments and identity integrations have different obligations. Mitigation: Category-specific launch gates and legal/compliance review; do not switch on regulated flows only because code exists.

- **External API dependency (Medium):** Government, Bhashini, WhatsApp, payments and logistics can fail/change. Mitigation: Adapter layer, timeouts, retries, circuit limits, cached/fallback UX and integration monitoring.

- **Operational verification cost (Medium):** Vet inspection, vendor verification and dispute resolution can become expensive. Mitigation: Risk-based verification tiers, paid inspection, partner network and evidence reuse.

## Success Metrics

- **Farmer value:** Weekly active farms; % active animals with complete records; milk records per lactating animal; feed cost/litre visibility; overdue action completion.

- **Animal health:** Vaccination on-time rate; alert-to-review time; repeat health events; % AI alerts reviewed/confirmed; withdrawal-rule compliance.

- **Vet network:** Consult request acceptance time; consultation completion; follow-up completion; verified-vet coverage by district.

- **Commerce:** Product browse→cart→checkout conversion; payment success; order fill rate; cancellation/refund rate; vendor SLA; repeat purchase.

- **Livestock trust:** % listings linked to herd record; % claims system-backed; % inspected; inquiry→visit→sale conversion; dispute rate.

- **Collection/finance:** Milk receipt reconciliation rate; payout timeliness; unresolved payout exceptions; farmer-visible net price accuracy.

- **Platform:** Crash-free sessions; API p95; error rate; sync failure; MQTT ingest success; notification delivery; test pass rate.

- **Business:** GMV, net revenue, marketplace take rate, SaaS ARR, CAC/payback, contribution margin by transaction type.

## Monetization Options

- **Farmer Pro - Subscription:** Advanced analytics, predictive alerts, finance, multi-staff, reports; core recordkeeping should remain accessible.

- **Vet Connect - Platform/service fee:** Fee on completed consultations or SaaS tools for vets; transparent to both parties.

- **Marketplace - Commission / service fee:** Commission on completed product and livestock-assisted transactions; category-specific fee structure.

- **Vendor / Cooperative SaaS - Subscription + transaction:** Order/collection/settlement console, analytics, inventory, member management.

- **IoT - Hardware + recurring:** Collar/device margin plus monitoring subscription/service plan.

- **Verification services - Per service:** Vet inspection, lab test, animal verification, cold-chain handling or logistics coordination.

- **Partner referrals - Referral fee:** Insurance/finance/logistics only with consent, transparent partner identity and appropriate regulatory structure.
