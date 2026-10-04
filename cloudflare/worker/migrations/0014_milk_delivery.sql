-- 0014_milk_delivery.sql
-- Last-mile milk delivery management: societies, flats, daily delivery route tracking,
-- subscriber pause/quantity change requests, milkman absence/holidays, and audit logs.

CREATE TABLE IF NOT EXISTS delivery_users (
    id TEXT PRIMARY KEY,
    phone TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    role TEXT NOT NULL CHECK(role IN ('milkman', 'subscriber')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS delivery_societies (
    id TEXT PRIMARY KEY,
    milkman_id TEXT NOT NULL,
    name TEXT NOT NULL,
    address TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS delivery_flats (
    id TEXT PRIMARY KEY,
    society_id TEXT NOT NULL,
    flat_number TEXT NOT NULL,
    owner_name TEXT NOT NULL,
    owner_phone TEXT NOT NULL,
    has_app INTEGER NOT NULL DEFAULT 0,
    default_quantity REAL NOT NULL DEFAULT 1.0,
    price_per_litre REAL NOT NULL DEFAULT 60.0,
    status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active', 'paused', 'stopped')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS delivery_records (
    id TEXT PRIMARY KEY,
    flat_id TEXT NOT NULL,
    date_key TEXT NOT NULL,
    planned_quantity REAL NOT NULL DEFAULT 1.0,
    actual_quantity REAL NOT NULL DEFAULT 0.0,
    status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending', 'delivered', 'skipped', 'custom', 'paused', 'milkmanAbsent')),
    delivered_at TIMESTAMP,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(flat_id, date_key)
);

CREATE TABLE IF NOT EXISTS delivery_change_requests (
    id TEXT PRIMARY KEY,
    flat_id TEXT NOT NULL,
    type TEXT NOT NULL CHECK(type IN ('pauseToday', 'pauseTomorrow', 'pauseRange', 'changeQuantity', 'custom')),
    start_date TEXT NOT NULL,
    end_date TEXT NOT NULL,
    requested_quantity REAL,
    reason TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending', 'applied', 'rejected')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS delivery_absences (
    id TEXT PRIMARY KEY,
    milkman_id TEXT NOT NULL,
    type TEXT NOT NULL CHECK(type IN ('singleDay', 'dateRange', 'recurringDayOfWeek')),
    date_key TEXT,
    start_date TEXT,
    end_date TEXT,
    day_of_week INTEGER,
    reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS delivery_audit_logs (
    id TEXT PRIMARY KEY,
    flat_id TEXT NOT NULL,
    actor_id TEXT NOT NULL,
    actor_name TEXT NOT NULL,
    actor_role TEXT NOT NULL,
    type TEXT NOT NULL,
    old_value TEXT NOT NULL,
    new_value TEXT NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reason TEXT
);

CREATE INDEX IF NOT EXISTS idx_deliv_soc_milkman ON delivery_societies(milkman_id);
CREATE INDEX IF NOT EXISTS idx_deliv_flats_soc ON delivery_flats(society_id);
CREATE INDEX IF NOT EXISTS idx_deliv_flats_phone ON delivery_flats(owner_phone);
CREATE INDEX IF NOT EXISTS idx_deliv_rec_date ON delivery_records(date_key);
CREATE INDEX IF NOT EXISTS idx_deliv_rec_flat ON delivery_records(flat_id);
CREATE INDEX IF NOT EXISTS idx_deliv_cr_flat ON delivery_change_requests(flat_id);
CREATE INDEX IF NOT EXISTS idx_deliv_abs_milkman ON delivery_absences(milkman_id);

-- Seed default users
INSERT OR IGNORE INTO delivery_users (id, phone, name, role) VALUES
    ('milkman-1', '9000000001', 'Ramu Milkman', 'milkman'),
    ('sub-1', '9111111111', 'Asha Sharma', 'subscriber'),
    ('sub-2', '9222222222', 'Rajiv Kumar', 'subscriber');

-- Seed societies
INSERT OR IGNORE INTO delivery_societies (id, milkman_id, name, address) VALUES
    ('soc-1', 'milkman-1', 'Green Park Apartments', 'Sector 12, Noida'),
    ('soc-2', 'milkman-1', 'Lotus Villa', 'MG Road, Bengaluru');

-- Seed flats
INSERT OR IGNORE INTO delivery_flats (id, society_id, flat_number, owner_name, owner_phone, has_app, default_quantity, price_per_litre, status) VALUES
    ('flat-1', 'soc-1', 'A-101', 'Asha Sharma', '9111111111', 1, 1.0, 60.0, 'active'),
    ('flat-2', 'soc-1', 'A-102', 'Vikram Singh', '9333333333', 0, 2.0, 60.0, 'active'),
    ('flat-3', 'soc-1', 'B-204', 'Meera Patel', '9444444444', 0, 0.5, 60.0, 'active'),
    ('flat-4', 'soc-2', '12', 'Rajiv Kumar', '9222222222', 1, 1.5, 65.0, 'active'),
    ('flat-5', 'soc-2', '14', 'Sunita Rao', '9555555555', 0, 1.0, 65.0, 'active');
