-- 0023_farm_management.sql: DairyAI Farm, Cattle, Milk, Breeding, Health, and Collection Schema

CREATE TABLE IF NOT EXISTS farmers (
    id TEXT PRIMARY KEY,
    user_id TEXT UNIQUE NOT NULL REFERENCES customers(id),
    name TEXT NOT NULL,
    village TEXT,
    district TEXT,
    state TEXT,
    language TEXT DEFAULT 'hi',
    lat REAL,
    lng REAL,
    total_cattle INTEGER DEFAULT 0,
    profile_photo_url TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS cattle (
    id TEXT PRIMARY KEY,
    farmer_id TEXT NOT NULL REFERENCES farmers(id) ON DELETE CASCADE,
    tag_id TEXT UNIQUE NOT NULL,
    name TEXT,
    breed TEXT NOT NULL CHECK (breed IN ('gir', 'sahiwal', 'murrah', 'hf_crossbred', 'jersey_crossbred', 'other')),
    sex TEXT DEFAULT 'female' CHECK (sex IN ('female', 'male')),
    dob DATE,
    weight_kg REAL,
    photo_url TEXT,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'sold', 'dead', 'dry')),
    lactation_number INTEGER DEFAULT 0,
    last_calving_date DATE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS milk_records (
    id TEXT PRIMARY KEY,
    cattle_id TEXT NOT NULL REFERENCES cattle(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    session TEXT NOT NULL CHECK (session IN ('morning', 'evening')),
    quantity_litres REAL NOT NULL CHECK (quantity_litres > 0),
    fat_pct REAL,
    snf_pct REAL,
    buyer_name TEXT,
    price_per_litre REAL,
    total_amount REAL,
    quality_grade TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS breeding_records (
    id TEXT PRIMARY KEY,
    cattle_id TEXT NOT NULL REFERENCES cattle(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL CHECK (event_type IN ('heat_detected', 'ai_done', 'pregnancy_confirmed', 'calving', 'abortion')),
    date DATE NOT NULL,
    bull_id TEXT,
    ai_technician TEXT,
    semen_batch TEXT,
    expected_calving_date DATE,
    actual_calving_date DATE,
    calf_id TEXT,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS health_records (
    id TEXT PRIMARY KEY,
    cattle_id TEXT NOT NULL REFERENCES cattle(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    record_type TEXT NOT NULL CHECK (record_type IN ('checkup', 'illness', 'treatment', 'surgery', 'observation')),
    symptoms TEXT,
    diagnosis TEXT,
    treatment TEXT,
    vet_id TEXT,
    severity INTEGER CHECK (severity BETWEEN 1 AND 10),
    resolved INTEGER DEFAULT 0,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS vaccinations (
    id TEXT PRIMARY KEY,
    cattle_id TEXT NOT NULL REFERENCES cattle(id) ON DELETE CASCADE,
    vaccine_name TEXT NOT NULL,
    batch_number TEXT,
    date_given DATE NOT NULL,
    next_due_date DATE,
    administered_by TEXT,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS feed_plans (
    id TEXT PRIMARY KEY,
    cattle_id TEXT NOT NULL REFERENCES cattle(id) ON DELETE CASCADE,
    plan TEXT NOT NULL,
    total_cost_per_day REAL NOT NULL,
    nutrition_score REAL,
    created_by TEXT DEFAULT 'ai',
    valid_from DATE NOT NULL,
    valid_to DATE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS collection_centers (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    code TEXT UNIQUE NOT NULL,
    cooperative_id TEXT,
    address TEXT,
    village TEXT,
    district TEXT,
    state TEXT,
    pincode TEXT,
    lat REAL,
    lng REAL,
    capacity_litres REAL DEFAULT 1000,
    current_stock_litres REAL DEFAULT 0,
    chilling_temp_celsius REAL DEFAULT 4.0,
    has_fat_analyzer INTEGER DEFAULT 1,
    has_snf_analyzer INTEGER DEFAULT 1,
    manager_name TEXT,
    manager_phone TEXT,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'maintenance')),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS milk_collections (
    id TEXT PRIMARY KEY,
    center_id TEXT NOT NULL REFERENCES collection_centers(id),
    farmer_id TEXT NOT NULL REFERENCES farmers(id),
    date DATE NOT NULL,
    shift TEXT NOT NULL CHECK (shift IN ('morning', 'evening')),
    quantity_litres REAL NOT NULL CHECK (quantity_litres > 0),
    fat_pct REAL NOT NULL,
    snf_pct REAL NOT NULL,
    temperature_celsius REAL,
    milk_grade TEXT CHECK (milk_grade IN ('A', 'B', 'C', 'rejected')),
    rate_per_litre REAL NOT NULL,
    total_amount REAL NOT NULL,
    quality_bonus REAL DEFAULT 0,
    deductions REAL DEFAULT 0,
    net_amount REAL NOT NULL,
    is_rejected INTEGER DEFAULT 0,
    rejection_reason TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for optimal performance
CREATE INDEX IF NOT EXISTS idx_cattle_farmer_id ON cattle(farmer_id);
CREATE INDEX IF NOT EXISTS idx_milk_records_cattle_date ON milk_records(cattle_id, date);
CREATE INDEX IF NOT EXISTS idx_breeding_cattle_date ON breeding_records(cattle_id, date);
CREATE INDEX IF NOT EXISTS idx_health_cattle_date ON health_records(cattle_id, date);
CREATE INDEX IF NOT EXISTS idx_vaccinations_cattle_date ON vaccinations(cattle_id, date_given);
CREATE INDEX IF NOT EXISTS idx_feed_plans_cattle_date ON feed_plans(cattle_id, valid_from);
CREATE INDEX IF NOT EXISTS idx_milk_collections_center_date ON milk_collections(center_id, date);
CREATE INDEX IF NOT EXISTS idx_milk_collections_farmer_date ON milk_collections(farmer_id, date);
