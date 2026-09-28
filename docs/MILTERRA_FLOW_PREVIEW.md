# Milterra order-flow preview: purpose, design, and test guide

Updated 28 September 2026. This guide describes the **separate test preview** at [milterra-flow-preview.pages.dev](https://milterra-flow-preview.pages.dev/#/shop). It is not the COD site at `milterrafoods.com`.

## Why it exists

Milterra needs to exercise the whole customer and seller workflow before a courier account or payment provider is available: checkout, cancellation, packing, tracking, failed delivery, COD collection, customer return, refund, and stock recovery. A static fake QR or a customer click cannot prove payment, and a test order must not accidentally become a real shipment or a real paid/refunded order. The preview therefore runs the existing commerce flow against **its own Worker and D1** and substitutes clearly marked courier and money events only at the external-service boundary.

This verifies our order state changes, authorization, timeline, inventory, and UI wiring. It does **not** verify courier coverage or booking, cash collection, bank settlement, Razorpay, or a real refund. Those require provider accounts and separate acceptance tests.

## How it is isolated

| Component | Preview behavior |
| --- | --- |
| Pages | `milterra-flow-preview.pages.dev` serves a Flutter build with `FLOW_SIMULATION=true`, a persistent test banner, and test-only admin buttons. Both API base URLs target the preview Worker. |
| Worker | `milterra-api-flow-preview.todileepmaurya.workers.dev` runs customer auth and test commerce. Online payment is unavailable. |
| D1 | `milterra-flow-preview` contains separate inventory, accounts, orders, and the simulated money ledger. PIN `201305` is enabled with a ₹0 delivery fee for this preview. |
| Credentials | A unique preview admin account was provisioned. Its username/password are in the developer machine's ignored `cloudflare/worker/.wrangler/flow-preview-admin.txt`; the Worker auth key is a Cloudflare secret. Neither is in Git. Customer testers create their own preview accounts. |

The simulator in [`simulation.py`](../cloudflare/worker/src/simulation.py) returns 404 unless `ENVIRONMENT` is `staging`, `test`, or `local`, `TEST_COMMERCE_ENABLED=true`, `LIVE_COD_ENABLED=false`, and `SIMULATION_ENABLED=true`. Every action also requires an authenticated admin and an order marked `is_test_order=1`. The real COD Worker keeps simulation disabled. Its Pages project and D1 were not changed for this preview.

Migration [`0012_simulated_fulfillment.sql`](../cloudflare/worker/migrations/0012_simulated_fulfillment.sql) creates a separate append-only ledger for fake COD collection/refund. Database checks reject movements on non-test orders, duplicate kinds, premature collection, and refunds without a received customer return. Order/payment changes, their events, and the ledger insert are made in a D1 batch so a failed ledger write rolls the change back. Fake tracking and money references start with `SIM-`; timeline entries say `[SIMULATED]`. The preview never calls a courier, bank, or payment provider.

The existing customer cancellation endpoint handles an unpaid order before packing: it releases reserved stock and leaves payment pending, so **there is no refund to issue**. A packed order follows fulfillment or return handling instead. The simulator adds these admin-only transitions:

```text
Customer COD order -> admin packs -> fake dispatch (SIM-AWB)
  -> fake out-for-delivery -> fake delivered -> fake COD collection (SIM-COD)
  -> customer requests return -> admin marks received + fake refund (SIM-REFUND)

Alternative after fake dispatch: fake delivery failure -> return-to-origin case
  -> admin records receipt/restock; no COD collection or refund.
```

## Manual browser test

Use [the preview storefront](https://milterra-flow-preview.pages.dev/#/shop), not `milterrafoods.com`. Use fictitious customer and address details; the address PIN must be `201305`. The yellow **MILTERRA TEST PREVIEW** banner should stay visible. Use separate browser profiles or sign out between the customer and admin roles. Do not place a real order or enter bank/payment details.

### A. Unpaid cancellation

1. Register a new customer in the preview and sign in. Add an available product to the cart. Add a delivery address with PIN `201305`.
2. At checkout choose **Cash on Delivery**, check the server-calculated total, and place the order. Save the order ID. The order should be marked as a test order and its payment should be pending.
3. Open **Your Orders**, open that order, and choose **Cancel Order** before an admin packs it. Refresh the order details.
4. Expect **CANCELLED**, payment still **PENDING**, a cancellation timeline event, and restored stock. There must be no collection or refund reference. The customer should not see a refund claim for unpaid COD.

### B. Delivery, collection, return, and refund

1. Place a **second** COD test order as the customer. Leave it uncancelled and save its order ID.
2. Sign in as admin on the same preview at `#/admin/login`. On the developer machine, read the login from `cloudflare/worker/.wrangler/flow-preview-admin.txt`. Another tester needs a separately provisioned preview admin account; do not copy credentials into tickets or Git.
3. Open **Orders** from the admin control panel, or go to `#/admin/commerce/orders`. Find the saved order ID. Use **Update** to move `PENDING` to `CONFIRMED` if shown, then `CONFIRMED` to `PACKED`. Do not use the normal dispatch action for this simulation.
4. Choose **Simulate dispatch**. Expect `SHIPPED` and a `SIM-AWB-...` tracking number. Choose **Simulate out for delivery**, then **Simulate delivery**. Expect `OUT_FOR_DELIVERY` and then `DELIVERED` in order tracking.
5. Choose **Simulate COD collection**. Expect payment **PAID** with a `SIM-COD-...` reference. This records test ledger data; it does not receive cash.
6. As the customer, open the delivered order and choose **Request return**. Give a reason. As admin, open **Shipments & Logistics** in the admin control panel, refresh **Customer Returns & RTO Queue**, and process the request with **Simulate received item and COD refund**. Select restock only if the simulated goods are reusable.
7. Refresh the customer's order. Expect the return marked received, payment **REFUNDED**, a `[SIMULATED]` refund timeline event, and a `SIM-REFUND-...` reference. The fake refund amount must equal the fake COD collection amount. No money was transferred.

### C. Failed-delivery branch (optional third order)

Place another order and pack/dispatch it. Choose **Simulate failed delivery** before delivery. Expect an RTO case; delivery and COD collection should then be rejected. In **Shipments & Logistics**, record receipt and restock if appropriate. The simulated money ledger should remain empty for this order.

If a button is missing, first confirm you are on the **preview URL**, the test banner is visible, you have the correct role, and the order is at the required state. Refresh the order/admin list after each action. A `409` means the transition is not valid for the current order state; a `404` on a simulator route means its safety gates are off or the order is not a test order.

## Automated verification

From `cloudflare/worker` in PowerShell, the local test suite exercises the state machine, role checks, D1 safety checks, and rollback:

```powershell
.\.venv\Scripts\python.exe -m pytest -q -p no:cacheprovider tests/test_simulated_fulfillment.py
.\.venv\Scripts\python.exe -m pytest -q -p no:cacheprovider tests
```

The remote acceptance script is deliberately restricted to URLs containing `flow-preview`. It creates synthetic customer accounts and orders in the **preview D1** and prints their IDs; it does not clean those audit records up. It checks registration, COD checkout/cancellation, fake shipment, collection, return, refund, and the customer-visible final status:

```powershell
.\.venv\Scripts\python.exe tests/verify_flow_preview_runtime.py `
  --base-url https://milterra-api-flow-preview.todileepmaurya.workers.dev `
  --origin https://milterra-flow-preview.pages.dev `
  --admin-file .wrangler/flow-preview-admin.txt
```

Run the remote script only when you intend to add test records to the preview. The latest recorded acceptance consisted of two passing remote runs and a visible homepage/banner check; the **signed-in manual browser walkthrough above has not yet been recorded as passed**. See the dated evidence in [the migration tracker](CLOUDFLARE_MIGRATION_STATUS.md).

## What remains before real external-service acceptance

The preview demonstrates the *internal* order flow, not all-India deliverability. A courier agreement/API is still needed to validate destination PINs, rates, booking, real AWBs, tracking webhooks, and return pickup. A payment provider/bank integration is needed before a prepaid order or an actual refund can be marked successful. Keep the simulator confined to its separate test resources; leave `FLOW_SIMULATION` off on the real storefront and `SIMULATION_ENABLED=false` on its Worker. When the test is finished, disable the preview simulator or retire those separate resources without changing the real site.
