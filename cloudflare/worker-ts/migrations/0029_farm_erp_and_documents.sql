-- 0029_farm_erp_and_documents.sql: Dairy ERP Transactions, Farm Documents/Charts & Multi-Tenant Dummy Accounts

-- 1. Farm Transactions (Daily Expense & Income ERP)
CREATE TABLE IF NOT EXISTS farm_transactions (
    id TEXT PRIMARY KEY,
    farmer_id TEXT NOT NULL REFERENCES farmers(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
    category TEXT NOT NULL CHECK (category IN (
        'milk_sales', 'feed_cost', 'vet_fees', 'medicine',
        'cattle_purchase', 'cattle_sale', 'equipment', 'labour', 'other'
    )),
    amount REAL NOT NULL CHECK (amount >= 0),
    description TEXT,
    date DATE NOT NULL,
    cattle_id TEXT REFERENCES cattle(id) ON DELETE SET NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_farm_tx_farmer_date ON farm_transactions(farmer_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_farm_tx_cattle ON farm_transactions(cattle_id);
CREATE INDEX IF NOT EXISTS idx_farm_tx_category ON farm_transactions(farmer_id, category);

-- 2. Farm Documents & Charts (Vaccination Charts, Rate Cards, Lab Test Reports)
CREATE TABLE IF NOT EXISTS farm_documents (
    id TEXT PRIMARY KEY,
    farmer_id TEXT NOT NULL REFERENCES farmers(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    document_type TEXT NOT NULL CHECK (document_type IN (
        'vaccination_chart', 'rate_card', 'feed_plan', 'lab_report', 'cattle_certificate', 'other'
    )),
    file_url TEXT NOT NULL,
    file_name TEXT,
    notes TEXT,
    date DATE NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_farm_docs_farmer ON farm_documents(farmer_id, date DESC);

-- 3. Seed Multi-Tenant Dummy Users (Password for all: Password@123)
-- Hash for 'Password@123': pbkdf2_sha256$600000$MTIzNDU2Nzg5MDEyMzQ1Ng==$v-o0X3aQFvP4wfkFobSSFTuVswjAP9t37wO9Mo-cS2k=

-- Farmer 1: Ramesh Patel (Dairy Farm 1 - Multi-Cattle & Milk ERP)
INSERT OR IGNORE INTO customers (id, phone, full_name, role, is_active)
VALUES ('cust-farmer-ramesh', '9876510001', 'Ramesh Patel', 'farmer', 1);

INSERT INTO customer_credentials (customer_id, username, email, password_hash)
VALUES (
    'cust-farmer-ramesh',
    'ramesh.dairy',
    'ramesh@milterrafoods.com',
    'pbkdf2_sha256$600000$MTIzNDU2Nzg5MDEyMzQ1Ng==$v-o0X3aQFvP4wfkFobSSFTuVswjAP9t37wO9Mo-cS2k='
)
ON CONFLICT(customer_id) DO UPDATE SET
    password_hash = 'pbkdf2_sha256$600000$MTIzNDU2Nzg5MDEyMzQ1Ng==$v-o0X3aQFvP4wfkFobSSFTuVswjAP9t37wO9Mo-cS2k=';

INSERT OR IGNORE INTO farmers (id, user_id, name, phone, village, district, state, upi_id, total_cattle)
VALUES (
    'farmer-ramesh',
    'cust-farmer-ramesh',
    'Ramesh Patel',
    '9876510001',
    'Anand',
    'Anand',
    'Gujarat',
    'ramesh@okhdfcbank',
    3
);

-- Farmer 2: Suresh Kumar (Dairy Farm 2 - Sahiwal Herd)
INSERT OR IGNORE INTO customers (id, phone, full_name, role, is_active)
VALUES ('cust-farmer-suresh', '9876510002', 'Suresh Kumar', 'farmer', 1);

INSERT INTO customer_credentials (customer_id, username, email, password_hash)
VALUES (
    'cust-farmer-suresh',
    'suresh.dairy',
    'suresh@milterrafoods.com',
    'pbkdf2_sha256$600000$MTIzNDU2Nzg5MDEyMzQ1Ng==$v-o0X3aQFvP4wfkFobSSFTuVswjAP9t37wO9Mo-cS2k='
)
ON CONFLICT(customer_id) DO UPDATE SET
    password_hash = 'pbkdf2_sha256$600000$MTIzNDU2Nzg5MDEyMzQ1Ng==$v-o0X3aQFvP4wfkFobSSFTuVswjAP9t37wO9Mo-cS2k=';

INSERT OR IGNORE INTO farmers (id, user_id, name, phone, village, district, state, upi_id, total_cattle)
VALUES (
    'farmer-suresh',
    'cust-farmer-suresh',
    'Suresh Kumar',
    '9876510002',
    'Karnal',
    'Karnal',
    'Haryana',
    'suresh@okaxis',
    1
);

-- Farmer 3: Priya Sharma (Sunrise Organic Dairy - Fresh New Tenant)
INSERT OR IGNORE INTO customers (id, phone, full_name, role, is_active)
VALUES ('cust-farmer-priya', '9876510003', 'Priya Sharma', 'farmer', 1);

INSERT INTO customer_credentials (customer_id, username, email, password_hash)
VALUES (
    'cust-farmer-priya',
    'priya.dairy',
    'priya@milterrafoods.com',
    'pbkdf2_sha256$600000$MTIzNDU2Nzg5MDEyMzQ1Ng==$v-o0X3aQFvP4wfkFobSSFTuVswjAP9t37wO9Mo-cS2k='
)
ON CONFLICT(customer_id) DO UPDATE SET
    password_hash = 'pbkdf2_sha256$600000$MTIzNDU2Nzg5MDEyMzQ1Ng==$v-o0X3aQFvP4wfkFobSSFTuVswjAP9t37wO9Mo-cS2k=';

INSERT OR IGNORE INTO farmers (id, user_id, name, phone, village, district, state, upi_id, total_cattle)
VALUES (
    'farmer-priya',
    'cust-farmer-priya',
    'Priya Sharma',
    '9876510003',
    'Baramati',
    'Pune',
    'Maharashtra',
    'priya@oksbi',
    0
);

-- 4. Seed Cattle for Ramesh
INSERT OR IGNORE INTO cattle (id, farmer_id, tag_id, name, breed, sex, weight_kg, status)
VALUES
    ('cattle-ramesh-1', 'farmer-ramesh', 'COW-GJ-01', 'Ganga', 'gir', 'female', 420.0, 'active'),
    ('cattle-ramesh-2', 'farmer-ramesh', 'BUF-GJ-02', 'Yamuna', 'murrah', 'female', 510.0, 'active'),
    ('cattle-ramesh-3', 'farmer-ramesh', 'COW-GJ-03', 'Kaveri', 'hf_crossbred', 'female', 465.0, 'active');

-- Seed Cattle for Suresh
INSERT OR IGNORE INTO cattle (id, farmer_id, tag_id, name, breed, sex, weight_kg, status)
VALUES
    ('cattle-suresh-1', 'farmer-suresh', 'COW-HR-01', 'Lakshmi', 'sahiwal', 'female', 390.0, 'active');

-- 5. Seed Initial ERP Transactions for Ramesh (Current Month)
INSERT OR IGNORE INTO farm_transactions (id, farmer_id, type, category, amount, description, date, cattle_id)
VALUES
    ('tx-ramesh-1', 'farmer-ramesh', 'income', 'milk_sales', 14500.0, 'Amul BMC 10-day collection cycle payout', '2026-10-18', 'cattle-ramesh-1'),
    ('tx-ramesh-2', 'farmer-ramesh', 'expense', 'feed_cost', 3800.0, 'Milterra Cattle Superfeed 50kg bag (x2)', '2026-10-15', NULL),
    ('tx-ramesh-3', 'farmer-ramesh', 'expense', 'vet_fees', 850.0, 'Dr. Deshmukh routine deworming & health checkup', '2026-10-14', 'cattle-ramesh-2'),
    ('tx-ramesh-4', 'farmer-ramesh', 'expense', 'medicine', 450.0, 'Calcium & Mineral supplement bolus pack', '2026-10-12', 'cattle-ramesh-1'),
    ('tx-ramesh-5', 'farmer-ramesh', 'expense', 'labour', 2500.0, 'Milking helper & shed sanitation wage', '2026-10-10', NULL),
    ('tx-ramesh-6', 'farmer-ramesh', 'income', 'milk_sales', 6200.0, 'Local dairy society evening milk delivery', '2026-10-08', 'cattle-ramesh-3');

-- Seed Transactions for Suresh
INSERT OR IGNORE INTO farm_transactions (id, farmer_id, type, category, amount, description, date, cattle_id)
VALUES
    ('tx-suresh-1', 'farmer-suresh', 'income', 'milk_sales', 8200.0, 'Mother Dairy collection payout', '2026-10-16', 'cattle-suresh-1'),
    ('tx-suresh-2', 'farmer-suresh', 'expense', 'feed_cost', 2100.0, 'Green fodder supply & mustard cake', '2026-10-11', 'cattle-suresh-1');

-- 6. Seed Sample Farm Documents & Charts for Ramesh
INSERT OR IGNORE INTO farm_documents (id, farmer_id, title, document_type, file_url, file_name, notes, date)
VALUES
    ('doc-ramesh-1', 'farmer-ramesh', 'Annual Herd Vaccination Schedule 2026', 'vaccination_chart', 'https://images.unsplash.com/photo-1570042225831-d98fa7577f1e?w=800&auto=format&fit=crop&q=60', 'Vaccination_Chart_2026.png', 'FMD & HS boosters due in Nov 2026', '2026-10-01'),
    ('doc-ramesh-2', 'farmer-ramesh', 'Amul Milk Fat & SNF Rate Chart (Oct 2026)', 'rate_card', 'https://images.unsplash.com/photo-1527153857715-3908f2ae5e81?w=800&auto=format&fit=crop&q=60', 'Milk_Rate_Chart_Oct2026.png', 'Base ₹42/L at 4.2% Fat / 8.5% SNF', '2026-10-05'),
    ('doc-ramesh-3', 'farmer-ramesh', 'Fodder Ration & Balanced Nutrition Plan', 'feed_plan', 'https://images.unsplash.com/photo-1500595046743-cd271d694d30?w=800&auto=format&fit=crop&q=60', 'Feed_Nutrition_Plan.png', 'Daily 25kg green fodder + 5kg dry + 4kg concentrate', '2026-10-08');
