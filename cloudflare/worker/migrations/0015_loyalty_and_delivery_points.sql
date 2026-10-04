-- Loyalty Program & Delivery Points System Migration

-- 1. Customer Loyalty Points Ledger
CREATE TABLE IF NOT EXISTS customer_loyalty_ledger (
    id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL,
    order_id TEXT,
    points_change INTEGER NOT NULL,
    balance_after INTEGER NOT NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_loyalty_customer ON customer_loyalty_ledger(customer_id, created_at DESC);

-- 2. Global Loyalty Settings
CREATE TABLE IF NOT EXISTS loyalty_settings (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    is_active INTEGER NOT NULL DEFAULT 1,
    earning_rate_percent REAL NOT NULL DEFAULT 2.0,
    redemption_rate_minor INTEGER NOT NULL DEFAULT 100,
    min_points_to_redeem INTEGER NOT NULL DEFAULT 10,
    max_redeem_percent_per_order REAL NOT NULL DEFAULT 50.0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT OR IGNORE INTO loyalty_settings (id, is_active, earning_rate_percent, redemption_rate_minor, min_points_to_redeem, max_redeem_percent_per_order)
VALUES (1, 1, 2.0, 100, 10, 50.0);

-- 3. Delivery Partner Points Collection Table
CREATE TABLE IF NOT EXISTS delivery_partner_points (
    id TEXT PRIMARY KEY,
    milkman_id TEXT NOT NULL,
    delivery_record_id TEXT,
    flat_id TEXT,
    points_earned INTEGER NOT NULL DEFAULT 10,
    delivered_date TEXT NOT NULL,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_delivery_points_milkman ON delivery_partner_points(milkman_id, created_at DESC);
