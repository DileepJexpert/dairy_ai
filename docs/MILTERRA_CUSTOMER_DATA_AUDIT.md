# Milterra customer data and admin access audit

Historical read-only snapshot: 29 September 2026, before the owner-requested account reset below. Source: the Cloudflare D1 Console for the database named `milterra-staging`, which currently backs `milterrafoods.com`. This file is an inventory and operational note, not a customer-data export.

## Owner-requested account reset — 29 September 2026

The owner authorized deleting all customer and administrator accounts together with their sessions, credentials, addresses, carts, orders, order lines/events, reservations, reviews, returns, support records and authentication rate-limit rows. The reset ran against the existing live D1; its schema and migrations were retained. Remote verification immediately afterward showed **zero rows in every account-related table**. The product inventory remained at 93 rows and 4,418 available units; one seller, one delivery policy, one delivery-PIN rule and seven serviceable-PIN rows remained. Inventory counts were deliberately not recalculated from deleted historical orders.

There is now **no administrator account**. New registrations use the normal customer role. After the owner registers a new account with a new password, that specific account must be promoted through a controlled D1 operation before it can use the admin panel, and the owner must sign in again for a fresh role-bearing session. Do not rerun the old seeded-admin migration or reuse its exposed password. Cloudflare D1 Time Travel had a pre-reset recovery bookmark; availability depends on the account's retention window. The tables and figures below document the former records and must not be treated as current.

## Administrator access

- One active seeded staff administrator is present. The customer account used by the owner also has the `admin` role. Staff authorization and customer account roles should be reviewed together before adding other administrators.
- The seeded administrator's **live password hash matched the seed in migration `0009_seed_admin_account.sql`** at the time of inspection. That migration contains the seed password in plaintext. Treat it as exposed: rotate the Milterra administrator password, review any other accounts where the same password was reused, and change the seed process so future deployments cannot restore the known password. Do not put the replacement password in this repository.
- Customer passwords cannot be read from D1 as plaintext. `customer_credentials` stores password hashes; `customer_sessions` stores session material. Neither belongs in a GitHub report.

## Customer accounts

Seven customer rows and seven credential rows were present. The labels below distinguish the records without publishing contact information or account identifiers.

| Record | Account description | State | Phone verified | Email verified |
| --- | --- | --- | --- | --- |
| 1 | Earlier synthetic COD acceptance account | Disabled | No | No |
| 2 | Checkout browser test account | Disabled | No | No |
| 3 | Ravi customer account A | Active | No | No |
| 4 | Account UI review account | Disabled | No | No |
| 5 | Owner administrator customer account | Active | No | No |
| 6 | Later synthetic COD acceptance account with a non-deliverable test email | Active | No | No |
| 7 | Ravi customer account B | Active | No | No |

The two Ravi rows are separate accounts. Do not merge or delete either based only on a matching first name. The active synthetic account should be disabled or removed through a deliberate cleanup before relying on customer counts or notifications.

## Related data in the same D1 database

| Data | Rows | Observation |
| --- | ---: | --- |
| Saved customer addresses | 6 | Includes owner, customer and test addresses. |
| Customer sessions | 4 | Existing sessions should be invalidated as part of administrator credential rotation. |
| Basket items | 5 | Baskets exist for customer and test accounts. |
| Orders | 7 | Includes historical test and non-test COD orders. |
| Order lines | 10 | Items across those orders. |
| Order events | 8 | Status history stored for orders. |
| Customer profiles | 0 | No separate profile rows. |
| Support tickets | 0 | None recorded. |
| Product reviews | 0 | None recorded. |
| Return cases | 0 | None recorded. |
| Simulated money movements | 0 | None recorded. |
| Password-reset records | 0 | None recorded. |

Order states at the snapshot: three cancelled historical test orders, one confirmed historical test order, two confirmed non-test COD orders, and one delivered non-test COD order. The delivered order's payment remained `pending` in D1, so delivery must not be presented as confirmed COD collection. A stored carrier or tracking reference is not proof of courier acceptance without independent verification.

## Access and handling

The full names, phone numbers, email addresses, addresses, order details, password hashes and session values remain in the access-controlled [Cloudflare D1 Console](https://dash.cloudflare.com/24e366c9448ef4c466bffe6f17efa51b/workers/d1/databases/a21abccf-65eb-4305-b27d-5c04efad65b1/console). They are intentionally omitted here to avoid copying live customer data and credentials into Git history. Use the console with an authorized account when an individual record needs investigation.

This audit did not change customer records, credentials, orders, Worker configuration or the live storefront.
