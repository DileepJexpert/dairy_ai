-- Migration 0027: Vendor Settlements & Payouts Tracking

ALTER TABLE commerce_sellers ADD COLUMN commission_rate REAL NOT NULL DEFAULT 5.0;
ALTER TABLE commerce_sellers ADD COLUMN bank_name TEXT NOT NULL DEFAULT '';
ALTER TABLE commerce_sellers ADD COLUMN account_number TEXT NOT NULL DEFAULT '';
ALTER TABLE commerce_sellers ADD COLUMN ifsc_code TEXT NOT NULL DEFAULT '';
ALTER TABLE commerce_sellers ADD COLUMN upi_id TEXT NOT NULL DEFAULT '';
ALTER TABLE commerce_sellers ADD COLUMN account_holder_name TEXT NOT NULL DEFAULT '';

CREATE TABLE IF NOT EXISTS vendor_payouts (
    id TEXT PRIMARY KEY,
    vendor_id TEXT NOT NULL,
    amount REAL NOT NULL,
    gross_amount REAL NOT NULL DEFAULT 0.0,
    commission_amount REAL NOT NULL DEFAULT 0.0,
    status TEXT NOT NULL DEFAULT 'paid',
    payment_reference TEXT NOT NULL,
    bank_name TEXT NOT NULL DEFAULT '',
    account_number TEXT NOT NULL DEFAULT '',
    remarks TEXT NOT NULL DEFAULT '',
    processed_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_vendor_payouts_vendor ON vendor_payouts(vendor_id, created_at);
