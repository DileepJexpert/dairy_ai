# Milterra customer data and admin access audit

Read-only snapshot: 29 September 2026. Source: the Cloudflare D1 Console for the database named `milterra-staging`, which currently backs `milterrafoods.com`. These counts can change as the store is used. This file is an inventory and operational note, not a customer-data export.

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
