-- 0025_extended_services.sql: Vets, Tele-consultations, Schemes, Mandi, Pashu Aadhaar, Purity, Outbreak, Withdrawal

CREATE TABLE IF NOT EXISTS vets (
    id TEXT PRIMARY KEY,
    user_id TEXT UNIQUE NOT NULL REFERENCES customers(id),
    license_number TEXT UNIQUE NOT NULL,
    qualification TEXT NOT NULL,
    specializations TEXT,
    experience_years INTEGER DEFAULT 0,
    languages TEXT,
    consultation_fee REAL DEFAULT 200.0,
    rating_avg REAL DEFAULT 0.0,
    total_consultations INTEGER DEFAULT 0,
    total_earnings REAL DEFAULT 0.0,
    is_verified INTEGER DEFAULT 0,
    is_available INTEGER DEFAULT 1,
    bio TEXT,
    pincode TEXT,
    city TEXT,
    district TEXT,
    state TEXT,
    lat REAL,
    lng REAL,
    service_radius_km REAL DEFAULT 25.0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS consultations (
    id TEXT PRIMARY KEY,
    farmer_id TEXT NOT NULL REFERENCES farmers(id),
    cattle_id TEXT NOT NULL REFERENCES cattle(id),
    vet_id TEXT REFERENCES vets(id),
    consultation_type TEXT DEFAULT 'video' CHECK (consultation_type IN ('video', 'audio', 'chat', 'in_person')),
    status TEXT DEFAULT 'requested' CHECK (status IN ('requested', 'accepted', 'in_progress', 'completed', 'cancelled', 'rejected')),
    symptoms TEXT,
    vet_diagnosis TEXT,
    vet_notes TEXT,
    started_at DATETIME,
    ended_at DATETIME,
    duration_seconds INTEGER DEFAULT 0,
    fee_amount REAL DEFAULT 0.0,
    platform_fee REAL DEFAULT 0.0,
    vet_payout REAL DEFAULT 0.0,
    farmer_rating INTEGER,
    farmer_review TEXT,
    follow_up_date DATE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS prescriptions (
    id TEXT PRIMARY KEY,
    consultation_id TEXT NOT NULL REFERENCES consultations(id),
    cattle_id TEXT NOT NULL REFERENCES cattle(id),
    vet_id TEXT NOT NULL REFERENCES vets(id),
    medicines TEXT NOT NULL,
    instructions TEXT,
    follow_up_date DATE,
    is_fulfilled INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS government_schemes (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    short_name TEXT,
    category TEXT NOT NULL,
    level TEXT DEFAULT 'central' CHECK (level IN ('central', 'state')),
    description TEXT,
    benefits TEXT,
    subsidy_amount_max REAL,
    subsidy_percentage REAL,
    required_documents TEXT,
    applicable_states TEXT,
    min_cattle_count INTEGER DEFAULT 1,
    max_cattle_count INTEGER,
    nodal_agency TEXT,
    application_url TEXT,
    helpline TEXT,
    is_active INTEGER DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS scheme_applications (
    id TEXT PRIMARY KEY,
    scheme_id TEXT NOT NULL REFERENCES government_schemes(id),
    farmer_id TEXT NOT NULL REFERENCES farmers(id),
    status TEXT DEFAULT 'submitted' CHECK (status IN ('submitted', 'under_review', 'approved', 'rejected', 'disbursed')),
    cattle_count INTEGER NOT NULL,
    estimated_subsidy REAL,
    documents_submitted TEXT,
    remarks TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS mandi_prices (
    id TEXT PRIMARY KEY,
    commodity TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('feed', 'fodder', 'cattle', 'milk')),
    district TEXT NOT NULL,
    state TEXT NOT NULL,
    mandi_name TEXT,
    min_price REAL NOT NULL,
    max_price REAL NOT NULL,
    modal_price REAL NOT NULL,
    unit TEXT DEFAULT 'quintal',
    price_date DATE NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS pashu_aadhaar_records (
    id TEXT PRIMARY KEY,
    cattle_id TEXT UNIQUE NOT NULL REFERENCES cattle(id),
    farmer_id TEXT NOT NULL REFERENCES farmers(id),
    pashu_aadhaar_number TEXT UNIQUE NOT NULL,
    ear_tag_number TEXT UNIQUE NOT NULL,
    species TEXT DEFAULT 'cattle',
    breed_govt TEXT,
    color TEXT,
    status TEXT DEFAULT 'active',
    inaph_sync_status TEXT DEFAULT 'synced',
    last_synced_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS milk_purity_brands (
    id TEXT PRIMARY KEY,
    slug TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    parent_company TEXT,
    variant TEXT DEFAULT 'toned',
    purity_score REAL DEFAULT 95.0,
    tested_batches INTEGER DEFAULT 0,
    last_tested_date DATE,
    is_fssai_compliant INTEGER DEFAULT 1,
    fssai_license TEXT,
    summary TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS milk_purity_reports (
    id TEXT PRIMARY KEY,
    brand_id TEXT NOT NULL REFERENCES milk_purity_brands(id),
    batch_number TEXT,
    report_date DATE NOT NULL,
    lab_name TEXT NOT NULL,
    lab_accreditation TEXT DEFAULT 'NABL',
    actual_fat_pct REAL,
    actual_snf_pct REAL,
    urea_detected INTEGER DEFAULT 0,
    detergent_detected INTEGER DEFAULT 0,
    starch_detected INTEGER DEFAULT 0,
    added_water_pct REAL DEFAULT 0.0,
    antibiotic_residue INTEGER DEFAULT 0,
    overall_grade TEXT DEFAULT 'Safe',
    report_pdf_url TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS outbreak_reports (
    id TEXT PRIMARY KEY,
    farmer_id TEXT NOT NULL REFERENCES farmers(id),
    disease_name TEXT NOT NULL,
    severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    affected_count INTEGER DEFAULT 1,
    lat REAL NOT NULL,
    lng REAL NOT NULL,
    village TEXT,
    district TEXT,
    state TEXT,
    status TEXT DEFAULT 'reported' CHECK (status IN ('reported', 'verified', 'contained', 'resolved')),
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS withdrawal_records (
    id TEXT PRIMARY KEY,
    cattle_id TEXT NOT NULL REFERENCES cattle(id),
    farmer_id TEXT NOT NULL REFERENCES farmers(id),
    medicine_name TEXT NOT NULL,
    active_ingredient TEXT NOT NULL,
    treatment_start_date DATE NOT NULL,
    treatment_end_date DATE NOT NULL,
    milk_withdrawal_days INTEGER NOT NULL,
    milk_safe_date DATE NOT NULL,
    meat_withdrawal_days INTEGER DEFAULT 28,
    meat_safe_date DATE NOT NULL,
    is_active INTEGER DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_vets_district ON vets(district, is_available);
CREATE INDEX IF NOT EXISTS idx_consultations_farmer ON consultations(farmer_id, status);
CREATE INDEX IF NOT EXISTS idx_consultations_vet ON consultations(vet_id, status);
CREATE INDEX IF NOT EXISTS idx_mandi_district ON mandi_prices(district, commodity, price_date);
CREATE INDEX IF NOT EXISTS idx_purity_slug ON milk_purity_brands(slug);
CREATE INDEX IF NOT EXISTS idx_outbreak_loc ON outbreak_reports(district, state, severity);
CREATE INDEX IF NOT EXISTS idx_withdrawal_cattle ON withdrawal_records(cattle_id, is_active);
