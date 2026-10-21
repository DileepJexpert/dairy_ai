-- Migration 0013: Commerce Taxonomy & Product Classification Tables

CREATE TABLE IF NOT EXISTS commerce_taxonomy_nodes (
  id TEXT PRIMARY KEY,
  kind TEXT NOT NULL,
  parent_id TEXT REFERENCES commerce_taxonomy_nodes(id),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  description TEXT NOT NULL DEFAULT '',
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1,
  version INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_commerce_taxonomy_parent ON commerce_taxonomy_nodes(parent_id);

CREATE TABLE IF NOT EXISTS commerce_product_classifications (
  product_id TEXT PRIMARY KEY,
  category_id TEXT NOT NULL REFERENCES commerce_taxonomy_nodes(id),
  version INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_commerce_product_class_cat ON commerce_product_classifications(category_id);

CREATE TABLE IF NOT EXISTS commerce_audit_events (
  id TEXT PRIMARY KEY,
  actor_id TEXT NOT NULL,
  action TEXT NOT NULL,
  target_id TEXT NOT NULL,
  before_json TEXT,
  after_json TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Seed Departments
INSERT OR IGNORE INTO commerce_taxonomy_nodes (id, kind, parent_id, name, slug, description, sort_order, is_active, version) VALUES
  ('tax-dairy-foods', 'department', NULL, 'Dairy Foods', 'dairy-foods', 'Pure A2 cultured bilona ghee, fresh malai paneer & probiotic dairy', 0, 1, 1),
  ('tax-artisanal-dairy', 'department', NULL, 'Artisanal Dairy & Cultured', 'artisanal-dairy', 'Vedic Bilona Ghee, Cultured Mattha, Curd Chillies & Washed Ghee', 1, 1, 1),
  ('tax-cold-pressed-oils-sweeteners', 'department', NULL, 'Wood-Pressed Oils & Pure Sweeteners', 'cold-pressed-oils-sweeteners', 'Lakdi Ghani Cooking Oils, NMR Raw Honey & Unbleached Sweeteners', 2, 1, 1),
  ('tax-fresh-chakki-flours', 'department', NULL, 'Stone-Ground Chakki Atta & Flours', 'fresh-chakki-flours', 'Heritage Khapli Wheat, 72h-Milled Sharbati & Diabetic Flour Blends', 3, 1, 1),
  ('tax-fresh-living-harvest', 'department', NULL, 'Fresh Living Harvest (Microgreens)', 'fresh-living-harvest', 'Living microgreen trays with roots intact, grown without soil or chemicals', 4, 1, 1),
  ('tax-terroir-salts-spices', 'department', NULL, 'Terroir Salts & Native Spices', 'terroir-salts-spices', 'Crushed Himalayan pink salt, wild roasted black salt & >5% curcumin haldi', 5, 1, 1),
  ('tax-living-balcony-soil', 'department', NULL, 'Apartment Balcony & Living Soil', 'living-balcony-soil', 'Odorless elevator-safe vermicompost, potting booster & heirloom seed kits', 6, 1, 1),
  ('tax-curated-combos', 'department', NULL, 'Curated Kitchen & Wellness Boxes', 'curated-combos', 'Starter upgrade boxes and high-AOV wellness bundles', 7, 1, 1),
  ('tax-botanical-skincare', 'department', NULL, 'Vedic Skincare & Botanicals', 'botanical-skincare', '100-times washed pure ghee cream, cold-process goat milk soaps and living botanicals', 8, 1, 1),
  ('tax-puja-hawan-samagri', 'department', NULL, 'Puja & Hawan Samagri', 'puja-hawan-samagri', 'Sacred hawan ghee, cow dung cakes, natural dhoop & kapoor', 9, 1, 1),
  ('tax-farm-essentials', 'department', NULL, 'Farm Essentials', 'farm-essentials', 'Animal nutrition supplements and dairy farm equipment', 10, 1, 1);

-- Seed Categories
INSERT OR IGNORE INTO commerce_taxonomy_nodes (id, kind, parent_id, name, slug, description, sort_order, is_active, version) VALUES
  ('tax-all-ghee', 'category', 'tax-dairy-foods', 'All Ghee', 'all-ghee', 'Complete collection of cow, buffalo and herbal bilona ghee', 11, 1, 1),
  ('tax-cow-ghee', 'category', 'tax-dairy-foods', 'Cow ghee', 'cow-ghee', 'Slow-simmered A2 desi cow bilona ghee', 12, 1, 1),
  ('tax-buffalo-ghee', 'category', 'tax-dairy-foods', 'Buffalo ghee', 'buffalo-ghee', 'Granular white Murrah buffalo bilona ghee', 13, 1, 1),
  ('tax-herbal-ghee', 'category', 'tax-dairy-foods', 'Herbal Ghee', 'herbal-ghee', 'Ayurvedic infused ghrita preparations', 14, 1, 1),
  ('tax-paneer', 'category', 'tax-dairy-foods', 'Paneer', 'paneer', 'Fresh farm kitchen whole-milk malai paneer', 15, 1, 1),
  ('tax-vedic-ghee', 'category', 'tax-artisanal-dairy', 'Vedic Bilona Ghee', 'vedic-ghee', 'Artisanal wooden bilona churned A2 cow and buffalo ghee', 16, 1, 1),
  ('tax-probiotic-dairy', 'category', 'tax-artisanal-dairy', 'Cultured Probiotic Dairy', 'probiotic-dairy', 'Live-culture spiced mattha, fresh paneer and makhan', 17, 1, 1),
  ('tax-curd-chillies-category', 'category', 'tax-artisanal-dairy', 'Traditional Curd Chillies', 'curd-chillies-category', 'Sun-dried buttermilk soaked green chillies (Mor Milagai)', 18, 1, 1),
  ('tax-shata-dhauta-ghrita-category', 'category', 'tax-botanical-skincare', 'Vedic Skincare & Goat Milk Soaps', 'shata-dhauta-ghrita-category', '100-times washed pure ghee skin moisturizer & cold-process goat milk soaps', 19, 1, 1),
  ('tax-lakdi-ghani-oils', 'category', 'tax-cold-pressed-oils-sweeteners', 'Cold-Pressed Cooking Oils', 'lakdi-ghani-oils', 'Traditional wooden kolhu extracted mustard, sesame and groundnut oils', 20, 1, 1),
  ('tax-raw-honey-category', 'category', 'tax-cold-pressed-oils-sweeteners', 'Raw NMR-Tested Honey', 'raw-honey-category', 'Unheated, unpasteurized honey with natural pollen', 21, 1, 1),
  ('tax-heritage-sweeteners', 'category', 'tax-cold-pressed-oils-sweeteners', 'Unbleached Heritage Sweeteners', 'heritage-sweeteners', 'Unbleached organic gur, bone-char free desi khand and dhage wali mishri', 22, 1, 1),
  ('tax-heritage-wheat', 'category', 'tax-fresh-chakki-flours', 'Ancient & Heritage Atta', 'heritage-wheat', 'Low GI Khapli emmer wheat and 72h-milled Sharbati whole wheat', 23, 1, 1),
  ('tax-millets-sattu', 'category', 'tax-fresh-chakki-flours', 'Millets & High-Protein Flours', 'millets-sattu', 'Multi-millet diabetic blends and clay-oven roasted chana sattu', 24, 1, 1),
  ('tax-live-punnets', 'category', 'tax-fresh-living-harvest', 'Live Microgreen Punnets', 'live-punnets', 'Live radish, sunflower, pea shoots and broccoli greens', 25, 1, 1),
  ('tax-unrefined-salts', 'category', 'tax-terroir-salts-spices', 'Himalayan & Black Salts', 'unrefined-salts', 'Pure mineral rock salts free from synthetic anti-caking agents', 26, 1, 1),
  ('tax-native-spices', 'category', 'tax-terroir-salts-spices', 'High-Curcumin Spices', 'native-spices', 'Single-origin haldi and native spices', 27, 1, 1),
  ('tax-balcony-fertilizers', 'category', 'tax-living-balcony-soil', 'Odorless Soil Boosters', 'balcony-fertilizers', 'Apartment-friendly, elevator-safe vermicompost and potting mix', 28, 1, 1),
  ('tax-bio-plant-defense', 'category', 'tax-living-balcony-soil', 'Organic Plant Defense & Seeds', 'bio-plant-defense', 'Fermented copper buttermilk spray and 5-in-1 heirloom seeds', 29, 1, 1),
  ('tax-pure-aloe-botanicals', 'category', 'tax-living-balcony-soil', 'Pure Aloe Vera & Living Botanicals', 'pure-aloe-botanicals', 'Cold-stabilized 99% inner-leaf aloe gel, fibrous digestive juice, and live potted balcony aloe plants', 30, 1, 1),
  ('tax-pantry-combos', 'category', 'tax-curated-combos', 'Kitchen Starter & Upgrade Boxes', 'pantry-combos', 'Curated high-AOV bundles for complete kitchen detox', 31, 1, 1),
  ('tax-hawan-yajna-ghee', 'category', 'tax-puja-hawan-samagri', 'Hawan & Yajna Ghee', 'hawan-yajna-ghee', 'Pure cow ghee formulated for sacred hawan and yajna rituals', 32, 1, 1),
  ('tax-cow-dung-products', 'category', 'tax-puja-hawan-samagri', 'Cow Dung Sacred Products', 'cow-dung-products', 'Sun-dried indigenous cow dung cakes and sambrani cups', 33, 1, 1),
  ('tax-dhoop-agarbatti', 'category', 'tax-puja-hawan-samagri', 'Natural Dhoop & Agarbatti', 'dhoop-agarbatti', 'Charcoal-free herbal dhoop cones and sticks', 34, 1, 1),
  ('tax-kapoor-samagri', 'category', 'tax-puja-hawan-samagri', 'Bhimseni Kapoor & Samagri', 'kapoor-samagri', '100% pure pine-derived Bhimseni camphor and hawan samagri', 35, 1, 1),
  ('tax-animal-nutrition', 'category', 'tax-farm-essentials', 'Animal nutrition', 'animal-nutrition', 'Chelated mineral mixtures, calcium tonics and transition supplements', 36, 1, 1),
  ('tax-equipment', 'category', 'tax-farm-essentials', 'Equipment', 'equipment', 'Dairy farm equipment and smart collar accessories', 37, 1, 1);
