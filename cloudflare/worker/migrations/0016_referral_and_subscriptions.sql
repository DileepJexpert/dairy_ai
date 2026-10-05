-- Migration 0016: Referral Program, Subscriptions, and Batch Purity Certificates

-- 1. Customer Referrals Tracking
CREATE TABLE IF NOT EXISTS customer_referrals (
    id TEXT PRIMARY KEY,
    referrer_customer_id TEXT NOT NULL,
    referred_customer_id TEXT NOT NULL,
    referral_code TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'completed',
    reward_points INTEGER NOT NULL DEFAULT 100,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(referrer_customer_id) REFERENCES customers(id),
    FOREIGN KEY(referred_customer_id) REFERENCES customers(id)
);

CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON customer_referrals(referrer_customer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referred ON customer_referrals(referred_customer_id);

-- 2. Customer Recurring Subscriptions (Daily Milk, Weekly Ghee, Butter)
CREATE TABLE IF NOT EXISTS customer_subscriptions (
    id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    delivery_address_id TEXT,
    frequency TEXT NOT NULL DEFAULT 'daily', -- 'daily', 'alternate_days', 'custom'
    custom_days TEXT DEFAULT '', -- e.g. 'MON,WED,FRI'
    quantity REAL NOT NULL DEFAULT 1.0,
    status TEXT NOT NULL DEFAULT 'active', -- 'active', 'paused', 'cancelled'
    start_date TEXT NOT NULL,
    pause_start_date TEXT,
    pause_end_date TEXT,
    payment_mode TEXT NOT NULL DEFAULT 'wallet_or_cod',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(customer_id) REFERENCES customers(id),
    FOREIGN KEY(product_id) REFERENCES inventory(product_id)
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_customer ON customer_subscriptions(customer_id, status);

-- 3. Batch Quality & Lab Purity Reports (Social Proof & Trust)
CREATE TABLE IF NOT EXISTS product_batch_reports (
    id TEXT PRIMARY KEY,
    product_id TEXT NOT NULL,
    batch_number TEXT UNIQUE NOT NULL,
    churn_date TEXT,
    expiry_date TEXT,
    purity_score REAL DEFAULT 99.8,
    fat_percentage REAL DEFAULT 99.7,
    snf_percentage REAL,
    lab_name TEXT DEFAULT 'National Dairy Testing Laboratory',
    report_url TEXT,
    certificate_summary TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(product_id) REFERENCES inventory(product_id)
);

CREATE INDEX IF NOT EXISTS idx_batch_reports_lookup ON product_batch_reports(batch_number);

-- Seed default lab purity batch for A2 Cow Ghee
INSERT OR IGNORE INTO product_batch_reports (
    id, product_id, batch_number, churn_date, expiry_date, purity_score, fat_percentage, lab_name, certificate_summary
) VALUES (
    'rep-ghee-oct26',
    'ffd7186f-6cee-4b8e-9a87-6af173aabffd',
    'MIL-GHEE-2026-10',
    '2026-10-01',
    '2027-10-01',
    99.9,
    99.85,
    'FSSAI Certified NABL Laboratory',
    'Zero adulteration, 100% Beta-Casein A2 certified, handcrafted via traditional wooden bilona churning.'
);
