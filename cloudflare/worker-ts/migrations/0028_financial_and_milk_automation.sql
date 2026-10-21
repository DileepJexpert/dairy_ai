-- Migration 0028: Financial & Milk Collection Automation
-- WhatsApp Daily Milk Slips, 1-Click UPI Payouts, and Verified Milk-Backed Micro-Loans (Kisan Credit)

-- 1. Extend Farmers Profile with Payout Details
ALTER TABLE farmers ADD COLUMN phone TEXT DEFAULT '';
ALTER TABLE farmers ADD COLUMN upi_id TEXT DEFAULT '';
ALTER TABLE farmers ADD COLUMN bank_account TEXT DEFAULT '';
ALTER TABLE farmers ADD COLUMN bank_ifsc TEXT DEFAULT '';
ALTER TABLE farmers ADD COLUMN bank_name TEXT DEFAULT '';

-- 2. Extend Milk Collections with WhatsApp Slip Tracking
ALTER TABLE milk_collections ADD COLUMN whatsapp_slip_sent INTEGER DEFAULT 0;
ALTER TABLE milk_collections ADD COLUMN whatsapp_sent_at DATETIME;
ALTER TABLE milk_collections ADD COLUMN whatsapp_slip_text TEXT;

-- 3. Farmer Wallet & Payout Ledger
CREATE TABLE IF NOT EXISTS farmer_wallet_ledger (
    id TEXT PRIMARY KEY,
    farmer_id TEXT NOT NULL REFERENCES farmers(id),
    type TEXT NOT NULL, -- 'milk_payout', 'upi_withdrawal', 'loan_disbursement', 'loan_repayment', 'feed_purchase', 'cashback'
    amount REAL NOT NULL, -- positive for credit, negative for debit
    balance_after REAL NOT NULL DEFAULT 0.0,
    reference_id TEXT,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    status TEXT DEFAULT 'completed',
    metadata TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_wallet_ledger_farmer ON farmer_wallet_ledger(farmer_id, created_at DESC);

-- 4. 1-Click UPI & Bank Payout Requests
CREATE TABLE IF NOT EXISTS farmer_payout_requests (
    id TEXT PRIMARY KEY,
    farmer_id TEXT NOT NULL REFERENCES farmers(id),
    amount REAL NOT NULL,
    payout_method TEXT DEFAULT 'upi',
    upi_id TEXT,
    bank_account TEXT,
    bank_ifsc TEXT,
    status TEXT DEFAULT 'success',
    utr_number TEXT NOT NULL,
    payment_cycle_id TEXT,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_payout_requests_farmer ON farmer_payout_requests(farmer_id, created_at DESC);

-- 5. Dugdhadhara 10-Day & Periodic Payment Cycles
CREATE TABLE IF NOT EXISTS farmer_payment_cycles (
    id TEXT PRIMARY KEY,
    cycle_code TEXT UNIQUE NOT NULL,
    cycle_type TEXT DEFAULT '10_day',
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    status TEXT DEFAULT 'pending', -- 'pending', 'processing', 'completed'
    total_litres REAL DEFAULT 0.0,
    total_amount REAL DEFAULT 0.0,
    total_deductions REAL DEFAULT 0.0,
    total_bonuses REAL DEFAULT 0.0,
    net_payout REAL DEFAULT 0.0,
    farmers_count INTEGER DEFAULT 0,
    settled_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 6. Verified Milk-Backed Micro-Loans (Kisan Credit)
CREATE TABLE IF NOT EXISTS farmer_loans (
    id TEXT PRIMARY KEY,
    farmer_id TEXT NOT NULL REFERENCES farmers(id),
    loan_type TEXT NOT NULL, -- 'feed_advance', 'silage', 'cattle_purchase', 'equipment', 'emergency'
    principal_amount REAL NOT NULL,
    outstanding_amount REAL NOT NULL,
    interest_rate_pct REAL DEFAULT 7.0,
    tenure_months INTEGER DEFAULT 6,
    emi_amount REAL NOT NULL,
    milk_deduction_pct REAL DEFAULT 10.0,
    status TEXT DEFAULT 'approved', -- 'pending', 'approved', 'disbursed', 'closed', 'rejected'
    purpose TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_farmer_loans_farmer ON farmer_loans(farmer_id, status);
