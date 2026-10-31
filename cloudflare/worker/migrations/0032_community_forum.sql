-- 0032_community_forum.sql: Community Cattle Social Feed & Doctor Advisory
CREATE TABLE IF NOT EXISTS community_posts (
    id TEXT PRIMARY KEY,
    author_id TEXT NOT NULL REFERENCES customers(id),
    author_name TEXT NOT NULL,
    author_role TEXT DEFAULT 'farmer',
    author_avatar TEXT,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    issue_tag TEXT NOT NULL,
    image_urls TEXT, -- JSON array of image URLs
    cattle_tag TEXT,
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    resolved INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS community_comments (
    id TEXT PRIMARY KEY,
    post_id TEXT NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
    author_id TEXT NOT NULL REFERENCES customers(id),
    author_name TEXT NOT NULL,
    author_role TEXT DEFAULT 'farmer',
    is_verified_vet INTEGER DEFAULT 0,
    vet_qualification TEXT,
    vet_clinic TEXT,
    comment TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Seed Initial High-Quality Case Discussions
INSERT OR REPLACE INTO community_posts (
    id, author_id, author_name, author_role, title, description, issue_tag, image_urls, cattle_tag, likes_count, comments_count, created_at
) VALUES
(
    'post-mastitis-01', 'cust-farmer-ramesh', 'Ramesh Patel', 'farmer',
    'Swelling and heat in rear right quarter after milking, yield dropped by 3 Litres',
    'My 4-year-old Gir cow (Laxmi) developed warm hardness in rear right teat. Morning milk had mild flakes. What immediate first-aid or ethno-veterinary paste can I apply before the doctor visits?',
    'Mastitis & Udder Care',
    '["https://images.unsplash.com/photo-1570042225831-d98fa7577f1e?w=800"]',
    'GIR-0104',
    12, 2, DATETIME('now', '-4 hours')
),
(
    'post-estrus-02', 'cust-farmer-suresh', 'Suresh Yadav', 'farmer',
    'Murrah Buffalo not showing clear estrus heat after 90 days postpartum',
    'Calved 90 days ago, body condition score is good (approx 3.5), but no mucus discharge or bellowing noticed. How to accurately detect silent heat?',
    'Breeding & Infertility',
    '["https://images.unsplash.com/photo-1546445317-29f4545e9d53?w=800"]',
    'MUR-0208',
    8, 1, DATETIME('now', '-8 hours')
),
(
    'post-skin-03', 'cust-farmer-priya', 'Priya Sharma', 'farmer',
    'Small round nodules on neck and shoulder - is this Lumpy Skin Disease (LSD)?',
    'Noticed 5-6 hard nodular bumps on the neck of our 2-year-old heifer. Body temp is 101.8°F. Eating well. Should we isolate her immediately from the main herd?',
    'Skin & Lumpy Disease',
    '["https://images.unsplash.com/photo-1527153857715-3908f2ae5e81?w=800"]',
    'HF-0312',
    15, 1, DATETIME('now', '-18 hours')
);

INSERT OR REPLACE INTO community_comments (
    id, post_id, author_id, author_name, author_role, is_verified_vet, vet_qualification, vet_clinic, comment, created_at
) VALUES
(
    'comm-01', 'post-mastitis-01', 'cust-vet-deshmukh', 'Dr. Hasmukh Deshmukh', 'vet', 1,
    'MVSc Animal Reproduction & Surgery', 'Anand Veterinary Polyclinic',
    'Dr. Deshmukh here. Do not massage the swollen quarter harshly. Strip out the affected quarter completely every 2 hours into a separate bucket (do not mix in milk pool). Apply a fresh paste of Aloe vera (250g) + Turmeric powder (50g) + Chuna/lime (15g) externally around the quarter. If fever rises above 103°F, book an immediate tele-consultation.',
    DATETIME('now', '-3 hours')
),
(
    'comm-02', 'post-mastitis-01', 'cust-farmer-suresh', 'Suresh Yadav', 'farmer', 0,
    NULL, NULL,
    'I had the exact same issue last month with my Murrah buffalo. Regular cold water splashing and turmeric-lime paste brought the swelling down within 24 hours. Follow Dr. Deshmukh’s advice closely.',
    DATETIME('now', '-2 hours')
),
(
    'comm-03', 'post-estrus-02', 'cust-vet-verma', 'Dr. Rakesh Verma', 'vet', 1,
    'PhD Animal Genetics (NDRI)', 'Karnal Bovine Research Center',
    'In high-producing buffaloes, silent estrus is very frequent. Inspect at 5:00 AM and 9:00 PM for subtle vulvar swelling, clear stringy mucus while lying down, and a 10-15% drop in milk yield. Feed 50g chelated mineral mixture with organic chromium daily for 21 days to activate follicles.',
    DATETIME('now', '-7 hours')
),
(
    'comm-04', 'post-skin-03', 'cust-vet-patwardhan', 'Dr. Ananya Patwardhan', 'vet', 1,
    'BVSc & AH Preventive Medicine', 'Baramati Organic Livestock Center',
    'Isolate her immediately in a dry, fly-screened shed. Disinfect pen floors with 1% potassium permanganate or neem decoction. Spray natural fly repellent (cedarwood / neem oil). Administer Vitamin C and liver tonic to strengthen immunity. Monitor rectal temperature twice daily.',
    DATETIME('now', '-16 hours')
);
