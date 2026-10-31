-- ============================================================================
-- Migration 0033: Dedicated Multi-Tenant Demo Farmer Account
-- ============================================================================
-- Demo Account Credentials:
--   Phone:      9876543210
--   Username:   demo.farmer
--   Email:      demo.farmer@milterrafoods.com
--   Password:   Farmer@123
--
-- PBKDF2-SHA256 Hash for 'Farmer@123' (600,000 iterations, WebCrypto / Node compatible):
--   pbkdf2_sha256$600000$MTIzNDU2Nzg5MDEyMzQ1Ng==$dRS7tNJ0SPDF1ewBnY_lO_PnWx55vqHz5_udkiJcbyA=
--
-- Multi-Tenant Isolation:
--   All herd, milk logs, wallet transactions, health records, breeding events,
--   farm P&L entries, and farm documents are strictly bound to 'farmer-demo-01'.
-- ============================================================================

-- 1. Ensure clean slate for demo farmer credentials
DELETE FROM customer_sessions WHERE customer_id IN (
    SELECT id FROM customers WHERE phone = '9876543210' OR id = 'cust-demo-farmer-01'
);

DELETE FROM customer_credentials WHERE customer_id IN (
    SELECT id FROM customers WHERE phone = '9876543210' OR id = 'cust-demo-farmer-01'
);

DELETE FROM customers WHERE phone = '9876543210' AND id != 'cust-demo-farmer-01';

-- 2. Customer Profile
INSERT OR REPLACE INTO customers (id, phone, full_name, role, is_active)
VALUES (
    'cust-demo-farmer-01',
    '9876543210',
    'Vikram Singh (Adarsh Dairy Farm)',
    'farmer',
    1
);

-- 3. Customer Credentials
INSERT OR REPLACE INTO customer_credentials (customer_id, username, email, password_hash, phone_verified, email_verified)
VALUES (
    'cust-demo-farmer-01',
    'demo.farmer',
    'demo.farmer@milterrafoods.com',
    'pbkdf2_sha256$600000$MTIzNDU2Nzg5MDEyMzQ1Ng==$dRS7tNJ0SPDF1ewBnY_lO_PnWx55vqHz5_udkiJcbyA=',
    1,
    1
);

-- 4. Farmer Profile & Bank / UPI Details
INSERT OR REPLACE INTO farmers (
    id, user_id, name, phone, village, district, state,
    upi_id, bank_account, bank_ifsc, bank_name, total_cattle,
    lat, lng, profile_photo_url
) VALUES (
    'farmer-demo-01',
    'cust-demo-farmer-01',
    'Vikram Singh (Adarsh Dairy Farm)',
    '9876543210',
    'Samaspur, Meerut',
    'Meerut',
    'Uttar Pradesh',
    'vikram.dairy@okhdfcbank',
    '501004928172',
    'HDFC0001042',
    'HDFC Bank, Meerut Bypass Hub',
    5,
    28.9845,
    77.7064,
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80'
);

-- 5. Collection Center for Meerut Chilling Hub
INSERT OR REPLACE INTO collection_centers (
    id, name, code, cooperative_id, address, village, district, state, pincode,
    lat, lng, capacity_litres, current_stock_litres, chilling_temp_celsius,
    has_fat_analyzer, has_snf_analyzer, manager_name, manager_phone, status
) VALUES (
    'bmc-meerut-01',
    'Milterra BMC Meerut Chilling Hub',
    'BMC-UP-01',
    'coop-meerut-01',
    'Delhi-Meerut Expressway Link Road',
    'Samaspur',
    'Meerut',
    'Uttar Pradesh',
    '250001',
    28.9845,
    77.7064,
    4500.0,
    2980.0,
    3.7,
    1,
    1,
    'Rajesh Verma',
    '9876501122',
    'active'
);

-- 6. Herd Registry (5 Diverse Commercial Dairy Animals)
INSERT OR REPLACE INTO cattle (
    id, farmer_id, tag_id, name, breed, sex, dob, weight_kg, photo_url, status, lactation_number, last_calving_date
) VALUES
(
    'cattle-demo-01',
    'farmer-demo-01',
    'COW-IN-101',
    'Kasturi',
    'sahiwal',
    'female',
    '2022-04-10',
    430.0,
    'https://images.unsplash.com/photo-1546445317-29f4545e9d53?w=800&auto=format&fit=crop&q=80',
    'active',
    3,
    '2026-03-12'
),
(
    'cattle-demo-02',
    'farmer-demo-01',
    'COW-IN-102',
    'Surabhi',
    'gir',
    'female',
    '2022-11-20',
    450.0,
    'https://images.unsplash.com/photo-1527153857715-3908f2ae5e81?w=800&auto=format&fit=crop&q=80',
    'active',
    2,
    '2026-02-18'
),
(
    'cattle-demo-03',
    'farmer-demo-01',
    'BUF-IN-103',
    'Kali',
    'murrah',
    'female',
    '2021-08-15',
    535.0,
    'https://images.unsplash.com/photo-1596733430284-f7437764b1a9?w=800&auto=format&fit=crop&q=80',
    'active',
    4,
    '2026-01-20'
),
(
    'cattle-demo-04',
    'farmer-demo-01',
    'COW-IN-104',
    'Laxmi',
    'hf_crossbred',
    'female',
    '2023-01-14',
    480.0,
    'https://images.unsplash.com/photo-1570042225831-d98fa7577f1e?w=800&auto=format&fit=crop&q=80',
    'active',
    1,
    '2026-05-10'
),
(
    'cattle-demo-05',
    'farmer-demo-01',
    'COW-IN-105',
    'Gauri',
    'gir',
    'female',
    '2024-04-15',
    260.0,
    'https://images.unsplash.com/photo-1500595046743-cd271d694d30?w=800&auto=format&fit=crop&q=80',
    'active',
    0,
    NULL
);

-- 7. Individual Cattle Daily Milk Logs (Morning & Evening Sessions)
INSERT OR REPLACE INTO milk_records (
    id, cattle_id, date, session, quantity_litres, fat_pct, snf_pct, buyer_name, price_per_litre, total_amount, quality_grade
) VALUES
-- Day 1
('mr-demo-01', 'cattle-demo-01', '2026-10-31', 'morning', 7.2, 4.5, 8.8, 'Milterra Meerut BMC', 48.00, 345.60, 'A'),
('mr-demo-02', 'cattle-demo-01', '2026-10-31', 'evening', 6.8, 4.6, 8.9, 'Milterra Meerut BMC', 48.80, 331.84, 'A'),
('mr-demo-03', 'cattle-demo-02', '2026-10-31', 'morning', 8.5, 4.8, 9.0, 'Milterra Meerut BMC', 52.00, 442.00, 'A'),
('mr-demo-04', 'cattle-demo-02', '2026-10-31', 'evening', 7.9, 4.9, 9.1, 'Milterra Meerut BMC', 53.00, 418.70, 'A'),
('mr-demo-05', 'cattle-demo-03', '2026-10-31', 'morning', 6.5, 7.6, 9.3, 'Milterra Buffalo Procurement', 68.00, 442.00, 'A'),
('mr-demo-06', 'cattle-demo-03', '2026-10-31', 'evening', 5.8, 7.8, 9.4, 'Milterra Buffalo Procurement', 70.00, 406.00, 'A'),
('mr-demo-07', 'cattle-demo-04', '2026-10-31', 'morning', 11.5, 3.8, 8.5, 'Milterra Direct Bulk', 42.00, 483.00, 'B'),
('mr-demo-08', 'cattle-demo-04', '2026-10-31', 'evening', 10.2, 3.9, 8.6, 'Milterra Direct Bulk', 42.50, 433.50, 'B'),
-- Day 2 (Previous day)
('mr-demo-09', 'cattle-demo-01', '2026-10-30', 'morning', 7.0, 4.5, 8.8, 'Milterra Meerut BMC', 48.00, 336.00, 'A'),
('mr-demo-10', 'cattle-demo-02', '2026-10-30', 'morning', 8.4, 4.8, 9.0, 'Milterra Meerut BMC', 52.00, 436.80, 'A'),
('mr-demo-11', 'cattle-demo-03', '2026-10-30', 'morning', 6.4, 7.6, 9.3, 'Milterra Buffalo Procurement', 68.00, 435.20, 'A'),
('mr-demo-12', 'cattle-demo-04', '2026-10-30', 'morning', 11.2, 3.8, 8.5, 'Milterra Direct Bulk', 42.00, 470.40, 'B');

-- 8. BMC Milk Procurement Collections with WhatsApp Slips
INSERT OR REPLACE INTO milk_collections (
    id, center_id, farmer_id, date, shift, quantity_litres, fat_pct, snf_pct,
    temperature_celsius, milk_grade, rate_per_litre, total_amount, quality_bonus,
    deductions, net_amount, is_rejected, whatsapp_slip_sent, whatsapp_sent_at, whatsapp_slip_text
) VALUES
(
    'col-demo-01', 'bmc-meerut-01', 'farmer-demo-01', '2026-10-31', 'morning',
    33.7, 4.8, 8.9, 4.1, 'A', 47.50, 1600.75, 50.0, 0.0, 1650.75, 0,
    1, '2026-10-31 07:35:00',
    'Namaste Vikram ji! Morning Collection: 33.7 Litres | Fat: 4.8% | SNF: 8.9 | Rate: ₹47.50/L | Payout: ₹1,650.75 credited to your Milterra Smart Wallet.'
),
(
    'col-demo-02', 'bmc-meerut-01', 'farmer-demo-01', '2026-10-30', 'morning',
    33.0, 4.7, 8.8, 4.0, 'A', 46.80, 1544.40, 45.0, 0.0, 1589.40, 0,
    1, '2026-10-30 07:40:00',
    'Namaste Vikram ji! Morning Collection: 33.0 Litres | Fat: 4.7% | SNF: 8.8 | Rate: ₹46.80/L | Payout: ₹1,589.40 credited to your Milterra Smart Wallet.'
),
(
    'col-demo-03', 'bmc-meerut-01', 'farmer-demo-01', '2026-10-29', 'morning',
    32.8, 4.8, 8.9, 3.9, 'A', 47.20, 1548.16, 50.0, 0.0, 1598.16, 0,
    1, '2026-10-29 07:42:00',
    'Namaste Vikram ji! Morning Collection: 32.8 Litres | Fat: 4.8% | SNF: 8.9 | Rate: ₹47.20/L | Payout: ₹1,598.16 credited to your Milterra Smart Wallet.'
);

-- 9. Digital Wallet Ledger (Credits, Debits & Healthy Running Balance)
INSERT OR REPLACE INTO farmer_wallet_ledger (
    id, farmer_id, type, amount, balance_after, reference_id, title, description, status, created_at
) VALUES
('wl-demo-01', 'farmer-demo-01', 'milk_payout', 15400.0, 15400.0, 'col-cycle-oct10', 'Milterra BMC 10-Day Milk Settlement', 'Milk collection settlement cycle Oct 01-10 (325 Litres)', 'completed', '2026-10-10 10:00:00'),
('wl-demo-02', 'farmer-demo-01', 'upi_withdrawal', -10000.0, 5400.0, 'payout-demo-01', 'Instant 1-Click UPI Transfer', 'Transferred to vikram.dairy@okhdfcbank via instant IMPS/UPI', 'completed', '2026-10-12 14:15:00'),
('wl-demo-03', 'farmer-demo-01', 'feed_purchase', -3850.0, 1550.0, 'ord-demo-feed-01', 'Milterra Cattle Superfeed & Mineral Mix', 'Direct debit for 2 bags Superfeed 50kg + 5kg Chelated Mineral Mix', 'completed', '2026-10-15 09:30:00'),
('wl-demo-04', 'farmer-demo-01', 'milk_payout', 17250.0, 18800.0, 'col-cycle-oct20', 'Milterra BMC 10-Day Milk Settlement', 'Milk collection settlement cycle Oct 11-20 (362 Litres)', 'completed', '2026-10-20 10:00:00'),
('wl-demo-05', 'farmer-demo-01', 'feed_purchase', -1200.0, 17600.0, 'ord-demo-feed-02', 'Milterra Bypass Protein Pellet 25kg', 'Direct debit for 1 bag Bypass Protein cattle ration', 'completed', '2026-10-25 11:20:00'),
('wl-demo-06', 'farmer-demo-01', 'milk_payout', 16800.0, 34400.0, 'col-cycle-oct30', 'Milterra BMC 10-Day Milk Settlement', 'Milk collection settlement cycle Oct 21-30 (350 Litres)', 'completed', '2026-10-30 10:00:00'),
('wl-demo-07', 'farmer-demo-01', 'upi_withdrawal', -15000.0, 19400.0, 'payout-demo-02', 'Instant 1-Click UPI Transfer', 'Transferred to vikram.dairy@okhdfcbank via instant IMPS/UPI', 'completed', '2026-10-31 16:45:00');

-- 10. Instant UPI Payout Requests (Verified UTR Logs)
INSERT OR REPLACE INTO farmer_payout_requests (
    id, farmer_id, amount, payout_method, upi_id, bank_account, bank_ifsc, status, utr_number, notes, created_at
) VALUES
('payout-demo-01', 'farmer-demo-01', 10000.0, 'upi', 'vikram.dairy@okhdfcbank', '501004928172', 'HDFC0001042', 'success', 'UTR20261012998811', 'Instant 1-Click transfer completed in 1.8 seconds', '2026-10-12 14:15:00'),
('payout-demo-02', 'farmer-demo-01', 15000.0, 'upi', 'vikram.dairy@okhdfcbank', '501004928172', 'HDFC0001042', 'success', 'UTR20261031445522', 'Instant 1-Click transfer completed in 2.1 seconds', '2026-10-31 16:45:00');

-- 11. Cattle Health & Medical Checkups
INSERT OR REPLACE INTO health_records (
    id, cattle_id, date, record_type, symptoms, diagnosis, treatment, severity, resolved, notes
) VALUES
(
    'hr-demo-01', 'cattle-demo-01', '2026-10-15', 'checkup',
    'Routine pre-winter preventive screening', 'Healthy lactation state',
    'Deworming with Albendazole bolus + Mineral bolus booster', 1, 1,
    'Negative for subclinical mastitis (California Mastitis Test Score 0). Teat condition excellent.'
),
(
    'hr-demo-02', 'cattle-demo-03', '2026-09-20', 'treatment',
    'Mild hoof tenderness in hind left leg', 'Interdigital dermatitis / footrot',
    'Copper sulfate footbath & antiseptic zinc spray applied for 4 days', 3, 1,
    'Full recovery confirmed; normal gait restored. Milk yield steady.'
),
(
    'hr-demo-03', 'cattle-demo-04', '2026-10-22', 'observation',
    'High milk yield metabolic check', 'Peak lactation',
    'Administered oral calcium gel bolus and liver tonic 100ml/day', 1, 1,
    'Daily yield 21.7L maintained with optimal rumen buffering.'
);

-- 12. Vaccinations (FMD, HS/BQ, Brucellosis, LSD)
INSERT OR REPLACE INTO vaccinations (
    id, cattle_id, vaccine_name, batch_number, date_given, next_due_date, administered_by, notes
) VALUES
('vac-demo-01', 'cattle-demo-01', 'FMD (Foot & Mouth Disease - Quadrivalent)', 'FMD-2026-92C', '2026-08-20', '2027-02-20', 'Govt Animal Husbandry Camp Meerut', 'Ear tag COW-IN-101 verified'),
('vac-demo-02', 'cattle-demo-02', 'HS + BQ Combined Vaccine', 'HSBQ-2026-11', '2026-07-15', '2027-07-15', 'Dr. Rakesh Verma', 'Annual pre-monsoon booster'),
('vac-demo-03', 'cattle-demo-03', 'FMD (Foot & Mouth Disease - Quadrivalent)', 'FMD-2026-92C', '2026-08-20', '2027-02-20', 'Govt Animal Husbandry Camp Meerut', 'Administered safely'),
('vac-demo-04', 'cattle-demo-04', 'Lumpy Skin Disease (LSD) Heterologous Booster', 'LSD-2026-UP', '2026-06-10', '2027-06-10', 'Dr. Rakesh Verma', 'Annual booster given'),
('vac-demo-05', 'cattle-demo-05', 'Brucellosis S19 (Calfhood)', 'BRU-19-102', '2024-09-15', NULL, 'Govt Veterinary Hospital Meerut', 'Lifelong immunity established');

-- 13. Breeding & Artificial Insemination Records
INSERT OR REPLACE INTO breeding_records (
    id, cattle_id, event_type, date, bull_id, ai_technician, semen_batch, expected_calving_date, actual_calving_date, calf_id, notes
) VALUES
(
    'br-demo-01', 'cattle-demo-01', 'ai_done', '2026-08-15',
    'NDRI-Sahiwal-B14', 'Dr. Rakesh Verma', 'SAH-NDRI-2026-08',
    '2027-05-22', NULL, NULL,
    'Artificially inseminated with elite pedigree Sahiwal semen (dam yield >3500 kg).'
),
(
    'br-demo-02', 'cattle-demo-01', 'pregnancy_confirmed', '2026-10-20',
    'NDRI-Sahiwal-B14', 'Dr. Rakesh Verma', 'SAH-NDRI-2026-08',
    '2027-05-22', NULL, NULL,
    'Confirmed pregnant (65 days) via ultrasound. Single healthy fetus observed.'
),
(
    'br-demo-03', 'cattle-demo-02', 'heat_detected', '2026-10-28',
    NULL, NULL, NULL,
    NULL, NULL, NULL,
    'Standing estrus heat with clear mucus discharge detected at 6 AM. Scheduled for Gir AI.'
);

-- 14. Balanced Feed Nutrition Plans
INSERT OR REPLACE INTO feed_plans (
    id, cattle_id, plan, total_cost_per_day, nutrition_score, created_by, valid_from, valid_to
) VALUES
(
    'fp-demo-01', 'cattle-demo-01',
    'High Yield Sahiwal Ration: 25kg Green Super Napier, 5kg Dry Wheat Straw, 4.5kg Milterra LactoFeed 22% Protein, 100g Chelated Mineral Mixture, 50g Salt.',
    142.0, 94.5, 'ai', '2026-10-01', '2026-12-31'
),
(
    'fp-demo-02', 'cattle-demo-03',
    'Murrah Buffalo Milk Ration: 30kg Green Lucerne, 6kg Paddy Straw, 5.5kg Cottonseed Cake + Crushed Maize Blend, 120g Mineral Supplement.',
    158.0, 95.0, 'ai', '2026-10-01', '2026-12-31'
);

-- 15. Farm ERP Financial Transactions (Complete Income & Expense Ledger)
INSERT OR REPLACE INTO farm_transactions (
    id, farmer_id, type, category, amount, description, date, cattle_id
) VALUES
('tx-demo-01', 'farmer-demo-01', 'income', 'milk_sales', 16800.00, 'Milterra BMC 10-day collection cycle payout (Oct 21-30)', '2026-10-30', NULL),
('tx-demo-02', 'farmer-demo-01', 'income', 'other', 4500.00, 'Sale of 3 trolleys vermicompost organic cow manure to nursery', '2026-10-28', NULL),
('tx-demo-03', 'farmer-demo-01', 'expense', 'feed_cost', 1200.00, 'Milterra Bypass Protein Pellet 25kg bag', '2026-10-25', NULL),
('tx-demo-04', 'farmer-demo-01', 'expense', 'vet_fees', 650.00, 'Dr. Rakesh Verma routine ultrasound pregnancy diagnosis', '2026-10-20', 'cattle-demo-01'),
('tx-demo-05', 'farmer-demo-01', 'income', 'milk_sales', 17250.00, 'Milterra BMC 10-day collection cycle payout (Oct 11-20)', '2026-10-20', NULL),
('tx-demo-06', 'farmer-demo-01', 'expense', 'feed_cost', 3850.00, 'Milterra Cattle Superfeed 50kg bag (x2) & Mineral Mix 5kg', '2026-10-15', NULL),
('tx-demo-07', 'farmer-demo-01', 'expense', 'medicine', 480.00, 'Calcium gel & vitamin H mineral supplement boluses', '2026-10-12', 'cattle-demo-04'),
('tx-demo-08', 'farmer-demo-01', 'expense', 'labour', 3500.00, 'Milking helper & shed sanitation wages (1st half Oct)', '2026-10-10', NULL);

-- 16. Farm Documents & Reference Charts
INSERT OR REPLACE INTO farm_documents (
    id, farmer_id, title, document_type, file_url, file_name, notes, date
) VALUES
(
    'doc-demo-01', 'farmer-demo-01', 'Annual Herd Vaccination Schedule 2026-27', 'vaccination_chart',
    'https://images.unsplash.com/photo-1570042225831-d98fa7577f1e?w=800&auto=format&fit=crop&q=80',
    'Herd_Vaccination_Schedule_2026.png',
    'FMD and HS/BQ booster schedule up to date. Next due Feb 2027.', '2026-10-01'
),
(
    'doc-demo-02', 'farmer-demo-01', 'Milterra BMC Fat & SNF Milk Rate Chart (Oct 2026)', 'rate_card',
    'https://images.unsplash.com/photo-1527153857715-3908f2ae5e81?w=800&auto=format&fit=crop&q=80',
    'Milterra_BMC_Rate_Matrix_Oct2026.png',
    'Base rate ₹45.00/L at 4.5% Fat & 8.5% SNF with incentive bonus.', '2026-10-05'
),
(
    'doc-demo-03', 'farmer-demo-01', 'NDRI Certified Balanced TMR Feed Ration Plan', 'feed_plan',
    'https://images.unsplash.com/photo-1500595046743-cd271d694d30?w=800&auto=format&fit=crop&q=80',
    'Feed_Nutrition_Ration_Plan.png',
    'Daily 25kg green fodder + 5kg dry wheat straw + 4.5kg concentrate.', '2026-10-08'
),
(
    'doc-demo-04', 'farmer-demo-01', 'Milk Purity & Antibiotic-Free Lab Analysis Report', 'lab_report',
    'https://images.unsplash.com/photo-1584467735871-8e85353a8413?w=800&auto=format&fit=crop&q=80',
    'Milk_Purity_Lab_Certificate.pdf',
    'Zero antibiotic residue, MBRT > 5 hours, Grade A certified.', '2026-10-18'
);

-- 17. Kisan Credit Loan Facility
INSERT OR REPLACE INTO farmer_loans (
    id, farmer_id, loan_type, principal_amount, outstanding_amount, interest_rate_pct,
    tenure_months, emi_amount, milk_deduction_pct, status, purpose, created_at
) VALUES (
    'loan-demo-01',
    'farmer-demo-01',
    'silage',
    50000.0,
    32500.0,
    7.0,
    12,
    4320.0,
    10.0,
    'disbursed',
    'Silage Bunker Pit & Modern Chaff Cutter',
    '2026-06-15 10:00:00'
);

-- 18. IoT Smart Collar Telemetry & Health Readings
INSERT OR REPLACE INTO sensor_readings (
    id, cattle_id, temperature, heart_rate, activity_level, rumination_minutes, battery_pct, rssi, created_at
) VALUES
('sr-demo-01', 'cattle-demo-01', 38.6, 68, 85, 490.0, 95, -60, '2026-10-31 08:00:00'),
('sr-demo-02', 'cattle-demo-02', 38.8, 74, 98, 470.0, 92, -58, '2026-10-31 08:00:00'),
('sr-demo-03', 'cattle-demo-03', 38.4, 64, 78, 465.0, 90, -62, '2026-10-31 08:00:00');
