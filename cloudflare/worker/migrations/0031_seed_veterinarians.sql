-- 0031_seed_veterinarians.sql: Seed Certified Veterinarians for Open Portal & Tele-Consult
INSERT OR IGNORE INTO customers (id, phone, full_name, role, is_active) VALUES
('cust-vet-deshmukh', '9825099001', 'Dr. Hasmukh Deshmukh', 'vet', 1),
('cust-vet-verma', '9825099002', 'Dr. Rakesh Verma', 'vet', 1),
('cust-vet-patwardhan', '9825099003', 'Dr. Ananya Patwardhan', 'vet', 1);

INSERT OR REPLACE INTO vets (
    id, user_id, license_number, qualification, specializations, experience_years,
    languages, consultation_fee, rating_avg, total_consultations, is_verified, is_available,
    bio, pincode, city, district, state, lat, lng, service_radius_km
) VALUES
(
    'vet-deshmukh', 'cust-vet-deshmukh', 'VET-GJ-2014-88', 'MVSc Animal Reproduction & Surgery',
    'Bovine Infertility, Gynecological Ultrasound, Mastitis Control, Calving Emergencies',
    12, 'Hindi, Gujarati, English', 250.0, 4.9, 184, 1, 1,
    'Chief Veterinary Surgeon with 12+ years experience serving commercial dairy herds across Anand and Kheda districts.',
    '388001', 'Anand', 'Anand', 'Gujarat', 22.5645, 72.9289, 40.0
),
(
    'vet-verma', 'cust-vet-verma', 'VET-HR-2011-42', 'PhD Animal Genetics & Breeding (NDRI)',
    'Pedigree Insemination, Pure Sahiwal & Murrah Lineage, Livestock Nutrition & TMR Rations',
    15, 'Hindi, Punjabi, English', 300.0, 4.9, 240, 1, 1,
    'Former NDRI Scientist specializing in high-yield genetic selection, balanced total mixed rations, and herd productivity.',
    '132001', 'Karnal', 'Karnal', 'Haryana', 29.6857, 76.9905, 50.0
),
(
    'vet-patwardhan', 'cust-vet-patwardhan', 'VET-MH-2018-91', 'BVSc & AH Preventive Veterinary Medicine',
    'Organic Herd Health, Antibiotic Stewardship, Herbal Udder Care, Calfhood Vaccines',
    8, 'Marathi, Hindi, English', 200.0, 4.8, 112, 1, 1,
    'Certified Organic Dairy Consultant focusing on preventive biosecurity, zero-antibiotic protocols, and herbal ethno-veterinary care.',
    '413133', 'Baramati', 'Pune', 'Maharashtra', 18.1517, 74.5768, 35.0
);
