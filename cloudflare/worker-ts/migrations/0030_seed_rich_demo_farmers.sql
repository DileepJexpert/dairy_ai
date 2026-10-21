-- 0030_seed_rich_demo_farmers.sql: Rich Demo Data for Ramesh, Suresh, and Priya
-- Designed for live user demos covering: Herd Registry, Milk Logs, BMC WhatsApp Collections,
-- Breeding AI, Health/Vaccines, Feed Plans, IoT Smart Collar, Digital Wallet, UPI Payouts,
-- Kisan Credit Loans, Dairy ERP Transactions (Income/Expense/P&L), and Farm Documents/Charts.

-- ============================================================================
-- 1. COLLECTION CENTERS (Anand, Karnal, Baramati)
-- ============================================================================
INSERT OR REPLACE INTO collection_centers (
    id, name, code, cooperative_id, address, village, district, state, pincode,
    lat, lng, capacity_litres, current_stock_litres, chilling_temp_celsius,
    has_fat_analyzer, has_snf_analyzer, manager_name, manager_phone, status
) VALUES
(
    'bmc-anand-01', 'Milterra BMC Anand Chilling Hub', 'BMC-GJ-01', 'coop-amul-01',
    'Amul Dairy Road, Mogar Cross', 'Anand', 'Anand Rural', 'Gujarat', '388001',
    22.5645, 72.9289, 5000.0, 3420.0, 3.8, 1, 1, 'Hasmukh Bhai', '9825012345', 'active'
),
(
    'bmc-karnal-01', 'Milterra BMC Karnal Milk Center', 'BMC-HR-01', 'coop-vita-01',
    'NDRI Link Road, Model Town', 'Karnal', 'Karnal', 'Haryana', '132001',
    29.6857, 76.9905, 3000.0, 1850.0, 4.0, 1, 1, 'Satpal Singh', '9812034567', 'active'
),
(
    'bmc-baramati-01', 'Milterra Organic Baramati Chilling Center', 'BMC-MH-01', 'coop-baramati-01',
    'MIDC Agri Processing Zone', 'Baramati', 'Pune', 'Maharashtra', '413133',
    18.1517, 74.5768, 4000.0, 2600.0, 3.5, 1, 1, 'Pravin Shinde', '9822078901', 'active'
);

-- ============================================================================
-- 2. FARMER PROFILES & BANK / UPI CREDENTIALS
-- ============================================================================
-- Farmer 1: Ramesh Patel (Progressive Commercial Dairy Farmer - Anand, Gujarat)
UPDATE farmers SET
    name = 'Ramesh Patel',
    phone = '9876510001',
    village = 'Mogar, Anand',
    district = 'Anand',
    state = 'Gujarat',
    upi_id = 'ramesh@okhdfcbank',
    bank_account = '501004589214',
    bank_ifsc = 'HDFC0000123',
    bank_name = 'HDFC Bank, Anand Main Branch',
    total_cattle = 4,
    lat = 22.5645,
    lng = 72.9289,
    profile_photo_url = 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80'
WHERE id = 'farmer-ramesh';

-- Farmer 2: Suresh Kumar (Smallholder Traditional Dairy - Karnal, Haryana)
UPDATE farmers SET
    name = 'Suresh Kumar',
    phone = '9876510002',
    village = 'Uchana, Karnal',
    district = 'Karnal',
    state = 'Haryana',
    upi_id = 'suresh@okaxis',
    bank_account = '918010045612',
    bank_ifsc = 'UTIB0000412',
    bank_name = 'Axis Bank, Karnal GT Road',
    total_cattle = 2,
    lat = 29.6857,
    lng = 76.9905,
    profile_photo_url = 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&auto=format&fit=crop&q=80'
WHERE id = 'farmer-suresh';

-- Farmer 3: Priya Sharma (Sunrise Organic A2 Dairy - Baramati, Maharashtra)
UPDATE farmers SET
    name = 'Priya Sharma',
    phone = '9876510003',
    village = 'Malegaon Budruk, Baramati',
    district = 'Pune',
    state = 'Maharashtra',
    upi_id = 'priya@oksbi',
    bank_account = '30894561234',
    bank_ifsc = 'SBIN0001245',
    bank_name = 'State Bank of India, Baramati Agri Branch',
    total_cattle = 3,
    lat = 18.1517,
    lng = 74.5768,
    profile_photo_url = 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=400&auto=format&fit=crop&q=80'
WHERE id = 'farmer-priya';

-- ============================================================================
-- 3. HERD REGISTRY (Cattle with Photos, Breeds, Weights, and Calving Dates)
-- ============================================================================
-- RAMESH's HERD (4 Cattle: Gir, Murrah Buffalo, HF Crossbred, Pregnant Gir)
INSERT OR REPLACE INTO cattle (
    id, farmer_id, tag_id, name, breed, sex, dob, weight_kg, photo_url, status, lactation_number, last_calving_date
) VALUES
(
    'cattle-ramesh-1', 'farmer-ramesh', 'COW-GJ-01', 'Ganga', 'gir', 'female',
    '2022-03-15', 425.0,
    'https://images.unsplash.com/photo-1546445317-29f4545e9d53?w=800&auto=format&fit=crop&q=80',
    'active', 2, '2026-03-10'
),
(
    'cattle-ramesh-2', 'farmer-ramesh', 'BUF-GJ-02', 'Yamuna', 'murrah', 'female',
    '2021-08-10', 520.0,
    'https://images.unsplash.com/photo-1596733430284-f7437764b1a9?w=800&auto=format&fit=crop&q=80',
    'active', 3, '2026-02-04'
),
(
    'cattle-ramesh-3', 'farmer-ramesh', 'COW-GJ-03', 'Kaveri', 'hf_crossbred', 'female',
    '2023-01-20', 470.0,
    'https://images.unsplash.com/photo-1570042225831-d98fa7577f1e?w=800&auto=format&fit=crop&q=80',
    'active', 1, '2026-05-18'
),
(
    'cattle-ramesh-4', 'farmer-ramesh', 'COW-GJ-04', 'Saraswati', 'gir', 'female',
    '2022-11-05', 390.0,
    'https://images.unsplash.com/photo-1527153857715-3908f2ae5e81?w=800&auto=format&fit=crop&q=80',
    'dry', 1, '2025-08-14'
);

-- SURESH's HERD (2 Sahiwal Cows)
INSERT OR REPLACE INTO cattle (
    id, farmer_id, tag_id, name, breed, sex, dob, weight_kg, photo_url, status, lactation_number, last_calving_date
) VALUES
(
    'cattle-suresh-1', 'farmer-suresh', 'COW-HR-01', 'Lakshmi', 'sahiwal', 'female',
    '2021-06-18', 395.0,
    'https://images.unsplash.com/photo-1527153857715-3908f2ae5e81?w=800&auto=format&fit=crop&q=80',
    'active', 3, '2026-04-02'
),
(
    'cattle-suresh-2', 'farmer-suresh', 'COW-HR-02', 'Radha', 'sahiwal', 'female',
    '2022-09-12', 415.0,
    'https://images.unsplash.com/photo-1546445317-29f4545e9d53?w=800&auto=format&fit=crop&q=80',
    'active', 2, '2026-01-25'
);

-- PRIYA's HERD (3 Elite Organic A2 Gir Cows)
INSERT OR REPLACE INTO cattle (
    id, farmer_id, tag_id, name, breed, sex, dob, weight_kg, photo_url, status, lactation_number, last_calving_date
) VALUES
(
    'cattle-priya-1', 'farmer-priya', 'COW-MH-01', 'Surabhi', 'gir', 'female',
    '2022-04-10', 440.0,
    'https://images.unsplash.com/photo-1546445317-29f4545e9d53?w=800&auto=format&fit=crop&q=80',
    'active', 2, '2026-02-19'
),
(
    'cattle-priya-2', 'farmer-priya', 'COW-MH-02', 'Nandini', 'gir', 'female',
    '2021-12-05', 455.0,
    'https://images.unsplash.com/photo-1500595046743-cd271d694d30?w=800&auto=format&fit=crop&q=80',
    'active', 3, '2026-03-30'
),
(
    'cattle-priya-3', 'farmer-priya', 'COW-MH-03', 'Devi', 'gir', 'female',
    '2023-02-14', 405.0,
    'https://images.unsplash.com/photo-1527153857715-3908f2ae5e81?w=800&auto=format&fit=crop&q=80',
    'active', 1, '2026-06-08'
);

-- ============================================================================
-- 4. INDIVIDUAL CATTLE DAILY MILK RECORDS (Morning & Evening Logs)
-- ============================================================================
-- Ramesh - Daily Milking Entries
INSERT OR REPLACE INTO milk_records (
    id, cattle_id, date, session, quantity_litres, fat_pct, snf_pct, buyer_name, price_per_litre, total_amount, quality_grade
) VALUES
('mr-ramesh-01', 'cattle-ramesh-1', '2026-10-20', 'morning', 12.5, 4.4, 8.7, 'Amul BMC Anand', 44.50, 556.25, 'A'),
('mr-ramesh-02', 'cattle-ramesh-1', '2026-10-20', 'evening', 11.8, 4.5, 8.8, 'Amul BMC Anand', 45.20, 533.36, 'A'),
('mr-ramesh-03', 'cattle-ramesh-2', '2026-10-20', 'morning', 8.5, 7.8, 9.2, 'Amul BMC Anand (Buffalo)', 62.00, 527.00, 'A'),
('mr-ramesh-04', 'cattle-ramesh-2', '2026-10-20', 'evening', 7.9, 7.9, 9.3, 'Amul BMC Anand (Buffalo)', 62.80, 496.12, 'A'),
('mr-ramesh-05', 'cattle-ramesh-3', '2026-10-20', 'morning', 14.5, 3.9, 8.5, 'Milterra Direct', 41.00, 594.50, 'B'),
('mr-ramesh-06', 'cattle-ramesh-3', '2026-10-20', 'evening', 13.8, 4.0, 8.6, 'Milterra Direct', 41.50, 572.70, 'B'),
-- Previous Day
('mr-ramesh-07', 'cattle-ramesh-1', '2026-10-19', 'morning', 12.8, 4.3, 8.6, 'Amul BMC Anand', 44.00, 563.20, 'A'),
('mr-ramesh-08', 'cattle-ramesh-1', '2026-10-19', 'evening', 12.0, 4.4, 8.7, 'Amul BMC Anand', 44.50, 534.00, 'A'),
('mr-ramesh-09', 'cattle-ramesh-2', '2026-10-19', 'morning', 8.2, 7.7, 9.1, 'Amul BMC Anand (Buffalo)', 61.50, 504.30, 'A'),
('mr-ramesh-10', 'cattle-ramesh-3', '2026-10-19', 'morning', 14.0, 4.0, 8.5, 'Milterra Direct', 41.20, 576.80, 'B');

-- Suresh - Daily Milking Entries
INSERT OR REPLACE INTO milk_records (
    id, cattle_id, date, session, quantity_litres, fat_pct, snf_pct, buyer_name, price_per_litre, total_amount, quality_grade
) VALUES
('mr-suresh-01', 'cattle-suresh-1', '2026-10-20', 'morning', 8.5, 4.6, 8.8, 'Mother Dairy Karnal', 46.50, 395.25, 'A'),
('mr-suresh-02', 'cattle-suresh-1', '2026-10-20', 'evening', 7.8, 4.7, 8.9, 'Mother Dairy Karnal', 47.00, 366.60, 'A'),
('mr-suresh-03', 'cattle-suresh-2', '2026-10-20', 'morning', 9.2, 4.5, 8.7, 'Mother Dairy Karnal', 45.80, 421.36, 'A'),
('mr-suresh-04', 'cattle-suresh-2', '2026-10-20', 'evening', 8.6, 4.6, 8.8, 'Mother Dairy Karnal', 46.50, 399.90, 'A'),
('mr-suresh-05', 'cattle-suresh-1', '2026-10-19', 'morning', 8.4, 4.6, 8.8, 'Mother Dairy Karnal', 46.50, 390.60, 'A'),
('mr-suresh-06', 'cattle-suresh-2', '2026-10-19', 'morning', 9.0, 4.5, 8.7, 'Mother Dairy Karnal', 45.80, 412.20, 'A');

-- Priya - Premium Organic A2 Milk Entries
INSERT OR REPLACE INTO milk_records (
    id, cattle_id, date, session, quantity_litres, fat_pct, snf_pct, buyer_name, price_per_litre, total_amount, quality_grade
) VALUES
('mr-priya-01', 'cattle-priya-1', '2026-10-20', 'morning', 13.0, 4.8, 9.0, 'Milterra Organic A2 Direct', 75.00, 975.00, 'A'),
('mr-priya-02', 'cattle-priya-1', '2026-10-20', 'evening', 12.2, 4.9, 9.1, 'Milterra Organic A2 Direct', 76.50, 933.30, 'A'),
('mr-priya-03', 'cattle-priya-2', '2026-10-20', 'morning', 14.2, 4.7, 8.9, 'Milterra Organic A2 Direct', 74.00, 1050.80, 'A'),
('mr-priya-04', 'cattle-priya-2', '2026-10-20', 'evening', 13.5, 4.8, 9.0, 'Milterra Organic A2 Direct', 75.00, 1012.50, 'A'),
('mr-priya-05', 'cattle-priya-3', '2026-10-20', 'morning', 9.5, 4.6, 8.8, 'Milterra Organic A2 Direct', 72.50, 688.75, 'A'),
('mr-priya-06', 'cattle-priya-1', '2026-10-19', 'morning', 12.8, 4.8, 9.0, 'Milterra Organic A2 Direct', 75.00, 960.00, 'A');

-- ============================================================================
-- 5. BMC MILK COLLECTIONS WITH WHATSAPP SLIPS
-- ============================================================================
-- Ramesh's BMC Collections
INSERT OR REPLACE INTO milk_collections (
    id, center_id, farmer_id, date, shift, quantity_litres, fat_pct, snf_pct,
    temperature_celsius, milk_grade, rate_per_litre, total_amount, quality_bonus,
    deductions, net_amount, is_rejected, whatsapp_slip_sent, whatsapp_sent_at, whatsapp_slip_text
) VALUES
(
    'col-ramesh-1', 'bmc-anand-01', 'farmer-ramesh', '2026-10-20', 'morning',
    35.5, 4.4, 8.7, 4.2, 'A', 45.20, 1604.60, 50.0, 0.0, 1654.60, 0,
    1, '2026-10-20 07:45:00',
    'Namaste Ramesh ji! Morning collection: 35.5 Litres | Fat: 4.4% | SNF: 8.7 | Payout: ₹1,654.60 credited to Milterra Wallet.'
),
(
    'col-ramesh-2', 'bmc-anand-01', 'farmer-ramesh', '2026-10-19', 'morning',
    35.0, 4.3, 8.6, 4.0, 'A', 44.50, 1557.50, 40.0, 0.0, 1597.50, 0,
    1, '2026-10-19 07:50:00',
    'Namaste Ramesh ji! Morning collection: 35.0 Litres | Fat: 4.3% | SNF: 8.6 | Payout: ₹1,597.50 credited to Milterra Wallet.'
),
(
    'col-ramesh-3', 'bmc-anand-01', 'farmer-ramesh', '2026-10-18', 'morning',
    34.8, 4.4, 8.7, 4.1, 'A', 45.00, 1566.00, 40.0, 0.0, 1606.00, 0,
    1, '2026-10-18 07:42:00',
    'Namaste Ramesh ji! Morning collection: 34.8 Litres | Fat: 4.4% | SNF: 8.7 | Payout: ₹1,606.00 credited to Milterra Wallet.'
);

-- Suresh's BMC Collections
INSERT OR REPLACE INTO milk_collections (
    id, center_id, farmer_id, date, shift, quantity_litres, fat_pct, snf_pct,
    temperature_celsius, milk_grade, rate_per_litre, total_amount, quality_bonus,
    deductions, net_amount, is_rejected, whatsapp_slip_sent, whatsapp_sent_at, whatsapp_slip_text
) VALUES
(
    'col-suresh-1', 'bmc-karnal-01', 'farmer-suresh', '2026-10-20', 'morning',
    17.7, 4.6, 8.8, 4.4, 'A', 46.50, 823.05, 25.0, 0.0, 848.05, 0,
    1, '2026-10-20 08:15:00',
    'Namaste Suresh ji! Morning collection: 17.7 Litres | Fat: 4.6% | SNF: 8.8 | Payout: ₹848.05 credited to Milterra Wallet.'
);

-- Priya's Organic A2 BMC Collections
INSERT OR REPLACE INTO milk_collections (
    id, center_id, farmer_id, date, shift, quantity_litres, fat_pct, snf_pct,
    temperature_celsius, milk_grade, rate_per_litre, total_amount, quality_bonus,
    deductions, net_amount, is_rejected, whatsapp_slip_sent, whatsapp_sent_at, whatsapp_slip_text
) VALUES
(
    'col-priya-1', 'bmc-baramati-01', 'farmer-priya', '2026-10-20', 'morning',
    36.7, 4.8, 9.0, 3.8, 'A', 75.00, 2752.50, 100.0, 0.0, 2852.50, 0,
    1, '2026-10-20 07:15:00',
    'Namaste Priya ji! Morning A2 Organic: 36.7 Litres | Fat: 4.8% | SNF: 9.0 | Payout: ₹2,852.50 credited to Milterra Organic Ledger.'
);

-- ============================================================================
-- 6. BREEDING & ARTIFICIAL INSEMINATION (AI) RECORDS
-- ============================================================================
-- Ramesh's Breeding Logs
INSERT OR REPLACE INTO breeding_records (
    id, cattle_id, event_type, date, bull_id, ai_technician, semen_batch, expected_calving_date, actual_calving_date, notes
) VALUES
(
    'br-ramesh-1', 'cattle-ramesh-4', 'heat_detected', '2026-03-01', NULL, NULL, NULL, NULL, NULL,
    'Clear estrus signs observed during morning milking.'
),
(
    'br-ramesh-2', 'cattle-ramesh-4', 'ai_done', '2026-03-02', 'BULL-GIR-BAIF-702',
    'Dr. Deshmukh', 'GIR-SX-2025-09', '2026-12-10', NULL,
    'Sexed semen AI performed successfully at 14 hours post onset.'
),
(
    'br-ramesh-3', 'cattle-ramesh-4', 'pregnancy_confirmed', '2026-05-15', 'BULL-GIR-BAIF-702',
    'Dr. Deshmukh', 'GIR-SX-2025-09', '2026-12-10', NULL,
    'Per-rectal and ultrasound examination confirmed positive 75-day gestation.'
),
(
    'br-ramesh-4', 'cattle-ramesh-1', 'calving', '2026-03-10', 'BULL-GIR-AMUL-108',
    'Self Assisted', 'GIR-STD-88', NULL, '2026-03-10',
    'Delivered healthy female calf (32kg). Placenta expelled within 3 hours.'
);

-- Suresh's Breeding Logs
INSERT OR REPLACE INTO breeding_records (
    id, cattle_id, event_type, date, bull_id, ai_technician, semen_batch, expected_calving_date, notes
) VALUES
(
    'br-suresh-1', 'cattle-suresh-1', 'ai_done', '2026-07-12', 'BULL-SAHIWAL-NDRI-14',
    'Shri Rakesh Verma (NDRI)', 'SAH-NDRI-77', '2027-04-20',
    'High genetic pedigree NDRI Sahiwal semen administered.'
);

-- Priya's Breeding Logs
INSERT OR REPLACE INTO breeding_records (
    id, cattle_id, event_type, date, bull_id, ai_technician, semen_batch, expected_calving_date, notes
) VALUES
(
    'br-priya-1', 'cattle-priya-2', 'pregnancy_confirmed', '2026-06-25', 'BULL-GIR-ORGANIC-09',
    'Dr. Patwardhan', 'GIR-ORG-A2-44', '2027-01-05',
    'Verified 100% pure A2/A2 genotype donor bull.'
);

-- ============================================================================
-- 7. HEALTH & MEDICAL CHECKUPS
-- ============================================================================
INSERT OR REPLACE INTO health_records (
    id, cattle_id, date, record_type, symptoms, diagnosis, treatment, severity, resolved, notes
) VALUES
(
    'hr-ramesh-1', 'cattle-ramesh-1', '2026-09-15', 'checkup',
    'Routine pre-winter preventive screening', 'Healthy lactation state',
    'Deworming with Albendazole bolus + Mineral bolus', 1, 1,
    'Negative for subclinical mastitis (California Mastitis Test Score 0).'
),
(
    'hr-ramesh-2', 'cattle-ramesh-2', '2026-08-20', 'treatment',
    'Mild hoof tenderness in hind left leg', 'Interdigital dermatitis / footrot',
    'Copper sulfate footbath & antiseptic zinc spray applied for 4 days', 3, 1,
    'Full recovery confirmed; normal gait restored.'
),
(
    'hr-suresh-1', 'cattle-suresh-1', '2026-09-02', 'checkup',
    'Appetite assessment', 'Good digestive health',
    'Rumen buffer yeast probiotic culture 50g/day', 1, 1,
    'Rumination rate 490 mins/day within optimal range.'
),
(
    'hr-priya-1', 'cattle-priya-1', '2026-08-10', 'observation',
    'Organic herbal udder conditioning', 'Preventive care',
    'Topical turmeric & aloe vera udder rub after each milking', 1, 1,
    'Zero synthetic chemicals used. Certified organic compliant.'
);

-- ============================================================================
-- 8. VACCINATIONS (FMD, HS, BQ, Brucellosis, LSD)
-- ============================================================================
INSERT OR REPLACE INTO vaccinations (
    id, cattle_id, vaccine_name, batch_number, date_given, next_due_date, administered_by, notes
) VALUES
-- Ramesh
('vac-ramesh-1', 'cattle-ramesh-1', 'FMD (Foot & Mouth Disease - Quadrivalent)', 'FMD-2026-88B', '2026-08-15', '2027-02-15', 'National Animal Disease Control Govt Camp', 'Ear tag verified'),
('vac-ramesh-2', 'cattle-ramesh-2', 'HS + BQ Combined Vaccine', 'HSBQ-441-26', '2026-07-20', '2027-07-20', 'Dr. Deshmukh', 'Pre-monsoon immunity booster'),
('vac-ramesh-3', 'cattle-ramesh-3', 'Brucellosis S19 (Calfhood)', 'BRU-19-09', '2023-06-10', NULL, 'Govt Veterinary Hospital Anand', 'Life-long immunity conferred'),
('vac-ramesh-4', 'cattle-ramesh-4', 'FMD (Foot & Mouth Disease - Quadrivalent)', 'FMD-2026-88B', '2026-08-15', '2027-02-15', 'National Animal Disease Control Govt Camp', 'Administered safely during 2nd trimester'),
-- Suresh
('vac-suresh-1', 'cattle-suresh-1', 'Lumpy Skin Disease (LSD) Heterologous Booster', 'LSD-2026-KRL', '2026-06-12', '2027-06-12', 'Govt Vet Polyclinic Karnal', 'Annual booster given'),
('vac-suresh-2', 'cattle-suresh-2', 'FMD (Foot & Mouth Disease)', 'FMD-2026-88B', '2026-08-18', '2027-02-18', 'Govt Vet Polyclinic Karnal', 'Booster up to date'),
-- Priya
('vac-priya-1', 'cattle-priya-1', 'FMD (Foot & Mouth Disease)', 'FMD-2026-90M', '2026-09-05', '2027-03-05', 'Animal Husbandry Dept Baramati', 'All herd animals vaccinated together'),
('vac-priya-2', 'cattle-priya-2', 'Anthrax Spore Vaccine', 'ANT-2026-MH', '2026-05-10', '2027-05-10', 'Animal Husbandry Dept Baramati', 'Endemic zone seasonal prophylaxis');

-- ============================================================================
-- 9. BALANCED FEED & RATION NUTRITION PLANS
-- ============================================================================
INSERT OR REPLACE INTO feed_plans (
    id, cattle_id, plan, total_cost_per_day, nutrition_score, created_by, valid_from, valid_to
) VALUES
(
    'fp-ramesh-1', 'cattle-ramesh-1',
    'High Yield Gir Ration: 25kg Green Super Napier, 5kg Dry Wheat Straw, 4.5kg Milterra LactoFeed 22% Protein, 100g Chelated Mineral Mixture, 50g Salt.',
    145.0, 93.5, 'ai', '2026-10-01', '2026-12-31'
),
(
    'fp-ramesh-2', 'cattle-ramesh-2',
    'Murrah Buffalo Milk Ration: 30kg Green Lucerne, 6kg Paddy Straw, 5.5kg Cottonseed Cake + Crushed Maize Blend, 120g Mineral Supplement.',
    175.0, 91.0, 'ai', '2026-10-01', '2026-12-31'
),
(
    'fp-suresh-1', 'cattle-suresh-1',
    'Desi Sahiwal Ration: 20kg Green Sorghum/Jowar, 5kg Wheat Straw, 3.5kg Mustard Cake + Wheat Bran mash, 60g Mineral Mixture.',
    115.0, 89.0, 'ai', '2026-10-01', '2026-12-31'
),
(
    'fp-priya-1', 'cattle-priya-1',
    'Certified Organic A2 Ration: 22kg Hydroponic Maize Fodder, 5kg Organic Moringa Leaf Meal, 3kg Sprouted Barley Mash, Pink Himalayan Rock Salt Lick.',
    185.0, 96.0, 'ai', '2026-10-01', '2026-12-31'
);

-- ============================================================================
-- 10. DIGITAL WALLET & TRANSACTION LEDGER
-- ============================================================================
-- Ramesh's Wallet Balance: ₹12,450.00
INSERT OR REPLACE INTO farmer_wallet_ledger (
    id, farmer_id, type, amount, balance_after, reference_id, title, description, status, created_at
) VALUES
('wl-ramesh-1', 'farmer-ramesh', 'milk_payout', 15660.0, 15660.0, 'col-amul-cycle-28', 'Amul BMC 10-Day Payout', 'Milk collection settlement cycle Oct 01-10 (348 Litres)', 'completed', '2026-10-11 11:30:00'),
('wl-ramesh-2', 'farmer-ramesh', 'upi_withdrawal', -10000.0, 5660.0, 'payout-ramesh-1', '1-Click UPI Transfer to HDFC Bank', 'Transferred to ramesh@okhdfcbank via instant IMPS/UPI', 'completed', '2026-10-12 14:15:00'),
('wl-ramesh-3', 'farmer-ramesh', 'feed_purchase', -3800.0, 1860.0, 'ord-milterra-feed-99', 'Milterra Superfeed 50kg (x2)', 'Direct debit for 2 bags of cattle concentrate', 'completed', '2026-10-15 09:20:00'),
('wl-ramesh-4', 'farmer-ramesh', 'milk_payout', 14500.0, 16360.0, 'col-amul-cycle-29', 'Amul BMC 10-Day Payout', 'Milk collection settlement cycle Oct 11-20 (322 Litres)', 'completed', '2026-10-20 10:00:00'),
('wl-ramesh-5', 'farmer-ramesh', 'loan_repayment', -3910.0, 12450.0, 'loan-emi-ramesh-1', 'Kisan Credit Loan Auto-Deduction', '10% milk collection auto-recovery for Oct cycle', 'completed', '2026-10-20 10:05:00');

-- Suresh's Wallet Balance: ₹4,350.00
INSERT OR REPLACE INTO farmer_wallet_ledger (
    id, farmer_id, type, amount, balance_after, reference_id, title, description, status, created_at
) VALUES
('wl-suresh-1', 'farmer-suresh', 'milk_payout', 8400.0, 8400.0, 'col-vita-cycle-12', 'Mother Dairy Collection Payout', '10-day pouring settlement', 'completed', '2026-10-12 10:00:00'),
('wl-suresh-2', 'farmer-suresh', 'upi_withdrawal', -5000.0, 3400.0, 'payout-suresh-1', 'Instant UPI Transfer to Axis Bank', 'Transferred to suresh@okaxis', 'completed', '2026-10-13 16:30:00'),
('wl-suresh-3', 'farmer-suresh', 'milk_payout', 3050.0, 6450.0, 'col-vita-cycle-13', 'Mid-cycle Milk Settlement', 'Pouring cycle settlement Oct 13-17', 'completed', '2026-10-18 11:00:00'),
('wl-suresh-4', 'farmer-suresh', 'feed_purchase', -2100.0, 4350.0, 'ord-feed-suresh-01', 'Green Fodder & Mustard Cake Supply', 'Local feed depot settlement', 'completed', '2026-10-19 15:45:00');

-- Priya's Wallet Balance: ₹18,900.00
INSERT OR REPLACE INTO farmer_wallet_ledger (
    id, farmer_id, type, amount, balance_after, reference_id, title, description, status, created_at
) VALUES
('wl-priya-1', 'farmer-priya', 'loan_disbursement', 50000.0, 50000.0, 'loan-priya-solar-01', 'Kisan Credit Equipment Loan Disbursed', 'Milterra pre-approved 0% processing fee credit', 'completed', '2026-10-05 10:00:00'),
('wl-priya-2', 'farmer-priya', 'equipment', -38500.0, 11500.0, 'inv-solar-chill-01', 'Solar Milk Chilling Bulk Cooler Unit', 'Paid to AgriTech Soltech Ltd for 200L solar chiller', 'completed', '2026-10-06 12:30:00'),
('wl-priya-3', 'farmer-priya', 'milk_payout', 27400.0, 38900.0, 'col-priya-a2-cycle-1', 'Milterra Premium A2 Direct Settlement', 'Premium organic procurement (365 Litres @ ₹75/L)', 'completed', '2026-10-15 14:00:00'),
('wl-priya-4', 'farmer-priya', 'upi_withdrawal', -20000.0, 18900.0, 'payout-priya-1', '1-Click Instant UPI Transfer to SBI', 'Transferred to priya@oksbi', 'completed', '2026-10-16 11:20:00');

-- ============================================================================
-- 11. 1-CLICK UPI PAYOUT REQUESTS WITH UTR NUMBERS
-- ============================================================================
INSERT OR REPLACE INTO farmer_payout_requests (
    id, farmer_id, amount, payout_method, upi_id, bank_account, bank_ifsc, status, utr_number, notes, created_at
) VALUES
('payout-ramesh-1', 'farmer-ramesh', 10000.0, 'upi', 'ramesh@okhdfcbank', '501004589214', 'HDFC0000123', 'success', 'UTR2026101298451201', 'Instant 1-Click transfer completed in 2.3 seconds', '2026-10-12 14:15:00'),
('payout-suresh-1', 'farmer-suresh', 5000.0, 'upi', 'suresh@okaxis', '918010045612', 'UTIB0000412', 'success', 'UTR2026101377412890', 'Instant 1-Click transfer completed in 1.8 seconds', '2026-10-13 16:30:00'),
('payout-priya-1', 'farmer-priya', 20000.0, 'upi', 'priya@oksbi', '30894561234', 'SBIN0001245', 'success', 'UTR2026101688523104', 'Instant 1-Click transfer completed in 2.1 seconds', '2026-10-16 11:20:00');

-- ============================================================================
-- 12. VERIFIED MILK-BACKED MICRO-LOANS (KISAN CREDIT)
-- ============================================================================
INSERT OR REPLACE INTO farmer_loans (
    id, farmer_id, loan_type, principal_amount, outstanding_amount, interest_rate_pct,
    tenure_months, emi_amount, milk_deduction_pct, status, purpose, created_at
) VALUES
(
    'loan-ramesh-01', 'farmer-ramesh', 'silage', 45000.0, 31200.0, 7.0,
    6, 7650.0, 10.0, 'disbursed',
    'Seasonal corn silage bunker purchase & dry season fodder stocking',
    '2026-08-15 10:00:00'
),
(
    'loan-priya-01', 'farmer-priya', 'equipment', 100000.0, 85000.0, 6.5,
    12, 8850.0, 8.0, 'disbursed',
    'Solar powered direct chilling unit (200L) & automatic vacuum milking claws',
    '2026-09-01 11:30:00'
);

-- ============================================================================
-- 13. DAIRY ERP TRANSACTIONS (P&L, Monthly Ledger, Category Breakdown)
-- ============================================================================
-- Ramesh Patel - Current Month Dairy ERP
INSERT OR REPLACE INTO farm_transactions (
    id, farmer_id, type, category, amount, description, date, cattle_id
) VALUES
('tx-ram-01', 'farmer-ramesh', 'income', 'milk_sales', 1654.60, 'BMC Morning Milk Collection Slip (35.5L @ ₹45.20)', '2026-10-20', 'cattle-ramesh-1'),
('tx-ram-02', 'farmer-ramesh', 'income', 'milk_sales', 1597.50, 'BMC Morning Milk Collection Slip (35.0L @ ₹44.50)', '2026-10-19', 'cattle-ramesh-1'),
('tx-ram-03', 'farmer-ramesh', 'income', 'milk_sales', 15660.00, 'Amul BMC 10-day collection cycle payout', '2026-10-18', NULL),
('tx-ram-04', 'farmer-ramesh', 'expense', 'feed_cost', 4800.00, 'Milterra Cattle Superfeed 50kg bag (x2) & Mineral Mix', '2026-10-15', NULL),
('tx-ram-05', 'farmer-ramesh', 'expense', 'vet_fees', 950.00, 'Dr. Deshmukh routine deworming & preventive checkup', '2026-10-14', 'cattle-ramesh-2'),
('tx-ram-06', 'farmer-ramesh', 'expense', 'medicine', 520.00, 'Calcium & Mineral supplement bolus pack', '2026-10-12', 'cattle-ramesh-1'),
('tx-ram-07', 'farmer-ramesh', 'expense', 'labour', 3500.00, 'Milking helper & shed sanitation wages (1st half Oct)', '2026-10-10', NULL),
('tx-ram-08', 'farmer-ramesh', 'expense', 'equipment', 850.00, 'Milking bucket sanitization kit & teat dip cup', '2026-10-09', NULL),
('tx-ram-09', 'farmer-ramesh', 'income', 'cattle_sale', 35000.00, 'Sale of mature crossbred heifer to certified dairy breeder', '2026-10-05', NULL),
('tx-ram-10', 'farmer-ramesh', 'income', 'milk_sales', 6200.00, 'Local dairy society evening milk delivery', '2026-10-04', 'cattle-ramesh-3');

-- Suresh Kumar - Current Month Dairy ERP
INSERT OR REPLACE INTO farm_transactions (
    id, farmer_id, type, category, amount, description, date, cattle_id
) VALUES
('tx-sur-01', 'farmer-suresh', 'income', 'milk_sales', 848.05, 'Mother Dairy collection payout (17.7L @ ₹46.50)', '2026-10-20', 'cattle-suresh-1'),
('tx-sur-02', 'farmer-suresh', 'income', 'milk_sales', 8400.00, 'Mother Dairy 10-day collection cycle payout', '2026-10-16', 'cattle-suresh-1'),
('tx-sur-03', 'farmer-suresh', 'expense', 'feed_cost', 2800.00, 'Green fodder jowar bundle supply & mustard cake', '2026-10-13', NULL),
('tx-sur-04', 'farmer-suresh', 'expense', 'vet_fees', 600.00, 'Govt Vet Polyclinic seasonal vaccination & tag check', '2026-10-09', 'cattle-suresh-2'),
('tx-sur-05', 'farmer-suresh', 'expense', 'medicine', 350.00, 'Probiotic rumen buffer supplement pack', '2026-10-06', 'cattle-suresh-1');

-- Priya Sharma - Current Month Dairy ERP
INSERT OR REPLACE INTO farm_transactions (
    id, farmer_id, type, category, amount, description, date, cattle_id
) VALUES
('tx-pri-01', 'farmer-priya', 'income', 'milk_sales', 2852.50, 'Milterra Organic A2 Collection (36.7L @ ₹75.00)', '2026-10-20', 'cattle-priya-1'),
('tx-pri-02', 'farmer-priya', 'income', 'milk_sales', 38500.00, 'Milterra Premium A2 Farmgate procurement payout', '2026-10-15', NULL),
('tx-pri-03', 'farmer-priya', 'income', 'milk_sales', 24000.00, 'Direct B2B Organic Ghee Butterfat Supply settlement', '2026-10-08', NULL),
('tx-pri-04', 'farmer-priya', 'expense', 'feed_cost', 6200.00, 'Certified organic fodder bundle & moringa leaf meal', '2026-10-17', NULL),
('tx-pri-05', 'farmer-priya', 'expense', 'labour', 6000.00, 'Organic farm caretaker & herd manager salary', '2026-10-10', NULL),
('tx-pri-06', 'farmer-priya', 'expense', 'equipment', 1800.00, 'Solar chiller coolant routine maintenance & filter swap', '2026-10-07', NULL),
('tx-pri-07', 'farmer-priya', 'expense', 'vet_fees', 1200.00, 'Dr. Patwardhan quarterly organic compliance inspection', '2026-10-03', NULL);

-- ============================================================================
-- 14. FARM DOCUMENTS & CHARTS (Vaccination, Rate Cards, Lab Reports, Certificates)
-- ============================================================================
-- Ramesh's Charts & Documents
INSERT OR REPLACE INTO farm_documents (
    id, farmer_id, title, document_type, file_url, file_name, notes, date
) VALUES
(
    'doc-ramesh-1', 'farmer-ramesh', 'Annual Herd Vaccination Schedule 2026', 'vaccination_chart',
    'https://images.unsplash.com/photo-1570042225831-d98fa7577f1e?w=800&auto=format&fit=crop&q=80',
    'Vaccination_Schedule_2026.png',
    'FMD & HS boosters administered; next round due Feb 2027.', '2026-10-01'
),
(
    'doc-ramesh-2', 'farmer-ramesh', 'Amul Milk Fat & SNF Rate Chart (Oct 2026)', 'rate_card',
    'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?w=800&auto=format&fit=crop&q=80',
    'Amul_Rate_Card_Oct2026.png',
    'Base ₹42.00/L at 4.2% Fat / 8.5% SNF. Premium ₹0.40 per 0.1% Fat point.', '2026-10-05'
),
(
    'doc-ramesh-3', 'farmer-ramesh', 'Fodder Ration & Balanced Nutrition Plan', 'feed_plan',
    'https://images.unsplash.com/photo-1500595046743-cd271d694d30?w=800&auto=format&fit=crop&q=80',
    'Fodder_Ration_Plan_Q4.png',
    'Daily 25kg green super napier + 5kg dry wheat straw + 4.5kg concentrate.', '2026-10-08'
),
(
    'doc-ramesh-4', 'farmer-ramesh', 'Milk Purity & Antibiotic-Free Lab Report', 'lab_report',
    'https://images.unsplash.com/photo-1584467735871-8e85353a8413?w=800&auto=format&fit=crop&q=80',
    'NABL_Lab_Report_Oct2026.pdf',
    'Zero antibiotic residue detected. Somatic cell count 140,000 cells/ml (Grade A Premium).', '2026-10-14'
);

-- Suresh's Charts & Documents
INSERT OR REPLACE INTO farm_documents (
    id, farmer_id, title, document_type, file_url, file_name, notes, date
) VALUES
(
    'doc-suresh-1', 'farmer-suresh', 'Mother Dairy Karnal Milk Rate Matrix', 'rate_card',
    'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?w=800&auto=format&fit=crop&q=80',
    'Mother_Dairy_Rate_Matrix.png',
    'Sahiwal cow rate card starting at ₹45.50/L at 4.5% Fat.', '2026-10-04'
),
(
    'doc-suresh-2', 'farmer-suresh', 'NDRI Sahiwal Pedigree Breed Certificate', 'cattle_certificate',
    'https://images.unsplash.com/photo-1527153857715-3908f2ae5e81?w=800&auto=format&fit=crop&q=80',
    'Sahiwal_Breed_Pedigree.pdf',
    'Certified pure indigenous Sahiwal strain with verified 18L peak yield lineage.', '2026-10-07'
);

-- Priya's Charts & Documents
INSERT OR REPLACE INTO farm_documents (
    id, farmer_id, title, document_type, file_url, file_name, notes, date
) VALUES
(
    'doc-priya-1', 'farmer-priya', 'NPOP & ISO Certified 100% Organic Dairy Certificate', 'other',
    'https://images.unsplash.com/photo-1584467735871-8e85353a8413?w=800&auto=format&fit=crop&q=80',
    'NPOP_Organic_Certificate_2026.pdf',
    'National Programme for Organic Production verified zero chemical farm accreditation.', '2026-10-02'
),
(
    'doc-priya-2', 'farmer-priya', 'A2 Beta-Casein DNA Genotype Certification', 'lab_report',
    'https://images.unsplash.com/photo-1584467735871-8e85353a8413?w=800&auto=format&fit=crop&q=80',
    'A2_DNA_Test_Report.pdf',
    'All herd cows verified 100% A2/A2 homozygous for beta-casein gene.', '2026-10-06'
),
(
    'doc-priya-3', 'farmer-priya', 'Milterra Premium A2 Procurement Rate Card', 'rate_card',
    'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?w=800&auto=format&fit=crop&q=80',
    'Milterra_A2_Premium_Card.png',
    'Premium procurement base rate of ₹75.00/L at 4.8% Fat & 9.0% SNF.', '2026-10-10'
);

-- ============================================================================
-- 15. IOT SMART COLLAR TELEMETRY & ALERTS (For Ganga & Lakshmi)
-- ============================================================================
INSERT OR REPLACE INTO sensor_readings (
    id, cattle_id, temperature, heart_rate, activity_level, rumination_minutes, battery_pct, rssi, created_at
) VALUES
('sr-1', 'cattle-ramesh-1', 38.6, 68, 85, 485.0, 94, -62, '2026-10-20 08:00:00'),
('sr-2', 'cattle-ramesh-1', 38.7, 70, 90, 502.0, 93, -60, '2026-10-20 12:00:00'),
('sr-3', 'cattle-ramesh-2', 38.4, 62, 75, 460.0, 89, -65, '2026-10-20 12:00:00'),
('sr-4', 'cattle-suresh-1', 38.5, 66, 82, 492.0, 91, -58, '2026-10-20 12:00:00'),
('sr-5', 'cattle-priya-1', 38.6, 69, 88, 515.0, 97, -55, '2026-10-20 12:00:00');
