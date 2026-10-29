import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import type { Env } from '../types/env.js';
import { requireAuth } from './commerce.js';
import { getFarmerByUserId } from './farmers.js';

export const feedRouter = new Hono<{ Bindings: Env }>();

interface FeedIngredient {
  ingredient: string;
  category: 'green_fodder' | 'dry_fodder' | 'concentrate' | 'supplement';
  quantity_kg: number;
  cost_per_kg: number;
  cost_per_day: number;
}

function computeFeedPlan(weightKg: number, status: string, lactationNumber: number): {
  plan: FeedIngredient[];
  totalCostPerDay: number;
  nutritionScore: number;
} {
  const isLactating = status === 'active';
  const weight = Math.max(250, Math.min(weightKg || 400, 700));

  // Scientific baseline for dairy cattle:
  // DMI ~ 2.5 - 3.2% of body weight
  const greenKg = Math.round((weight * 0.04) * 10) / 10; // ~16-20 kg green fodder
  const dryKg = Math.round((weight * 0.012) * 10) / 10;   // ~4.8-6 kg dry fodder
  const concentrateKg = isLactating ? Math.round((3.0 + lactationNumber * 0.5) * 10) / 10 : 1.5;
  const mineralKg = 0.1; // 100g mineral mixture

  const ingredients: FeedIngredient[] = [
    {
      ingredient: 'Green Fodder (Hybrid Napier / Lucerne)',
      category: 'green_fodder',
      quantity_kg: greenKg,
      cost_per_kg: 2.5,
      cost_per_day: Math.round(greenKg * 2.5 * 100) / 100,
    },
    {
      ingredient: 'Dry Fodder (Wheat / Paddy Straw)',
      category: 'dry_fodder',
      quantity_kg: dryKg,
      cost_per_kg: 5.0,
      cost_per_day: Math.round(dryKg * 5.0 * 100) / 100,
    },
    {
      ingredient: 'Dairy Cattle Feed Concentrate (Bypass Protein 20%)',
      category: 'concentrate',
      quantity_kg: concentrateKg,
      cost_per_kg: 28.0,
      cost_per_day: Math.round(concentrateKg * 28.0 * 100) / 100,
    },
    {
      ingredient: 'Chelated Mineral Mixture + Salt',
      category: 'supplement',
      quantity_kg: mineralKg,
      cost_per_kg: 80.0,
      cost_per_day: Math.round(mineralKg * 80.0 * 100) / 100,
    },
  ];

  const totalCost = ingredients.reduce((sum, item) => sum + item.cost_per_day, 0);
  const nutritionScore = isLactating ? 92.5 : 88.0;

  return {
    plan: ingredients,
    totalCostPerDay: Math.round(totalCost * 100) / 100,
    nutritionScore,
  };
}

// ---------------------------------------------------------------------------
// 1. Generate Feed Plan
// ---------------------------------------------------------------------------

feedRouter.post('/cattle/:cattle_id/feed-plan/generate', async (c) => {
  const user = await requireAuth(c);
  const cattleId = c.req.param('cattle_id');
  const db = c.env.DB;

  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const cattle = (await db.prepare('SELECT * FROM cattle WHERE id = ? AND farmer_id = ?').bind(cattleId, farmer.id).first()) as any;
  if (!cattle) {
    throw new HTTPException(404, { message: 'Cattle not found' });
  }

  const { plan, totalCostPerDay, nutritionScore } = computeFeedPlan(
    cattle.weight_kg || 420,
    cattle.status || 'active',
    cattle.lactation_number || 1
  );

  const planId = crypto.randomUUID();
  const todayStr = new Date().toISOString().slice(0, 10);
  const validToStr = new Date(Date.now() + 30 * 86400000).toISOString().slice(0, 10);

  await db.prepare(
    `INSERT INTO feed_plans (id, cattle_id, plan, total_cost_per_day, nutrition_score, created_by, valid_from, valid_to)
     VALUES (?, ?, ?, ?, ?, 'ai', ?, ?)`
  ).bind(
    planId,
    cattleId,
    JSON.stringify(plan),
    totalCostPerDay,
    nutritionScore,
    todayStr,
    validToStr
  ).run();

  return c.json(
    {
      success: true,
      data: {
        id: planId,
        cattle_id: cattleId,
        plan,
        total_cost_per_day: totalCostPerDay,
        nutrition_score: nutritionScore,
        valid_from: todayStr,
        valid_to: validToStr,
      },
      message: 'Feed plan generated',
    },
    201
  );
});

// ---------------------------------------------------------------------------
// 2. Get Current Feed Plan
// ---------------------------------------------------------------------------

feedRouter.get('/cattle/:cattle_id/feed-plan/current', async (c) => {
  const user = await requireAuth(c);
  const cattleId = c.req.param('cattle_id');
  const db = c.env.DB;

  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const cattle = (await db.prepare('SELECT id FROM cattle WHERE id = ? AND farmer_id = ?').bind(cattleId, farmer.id).first()) as any;
  if (!cattle) {
    throw new HTTPException(404, { message: 'Cattle not found' });
  }

  const row = (await db.prepare(
    `SELECT * FROM feed_plans
     WHERE cattle_id = ?
     ORDER BY created_at DESC LIMIT 1`
  ).bind(cattleId).first()) as any;

  if (!row) {
    return c.json({ success: true, data: null, message: 'No feed plan' });
  }

  let planParsed: any = [];
  try {
    planParsed = JSON.parse(row.plan);
  } catch {
    planParsed = [];
  }

  return c.json({
    success: true,
    data: {
      id: row.id,
      cattle_id: row.cattle_id,
      plan: planParsed,
      total_cost_per_day: row.total_cost_per_day,
      nutrition_score: row.nutrition_score,
      valid_from: row.valid_from,
      valid_to: row.valid_to,
    },
    message: 'Current feed plan',
  });
});

// ---------------------------------------------------------------------------
// 3. Cattle Feed & Mineral Mixture Marketplace, Promotion & Vendor Listings
// ---------------------------------------------------------------------------

async function ensureFeedMarketplaceTables(db: any) {
  try {
    await db.prepare(`
      CREATE TABLE IF NOT EXISTS feed_marketplace_products (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        brand TEXT NOT NULL,
        category TEXT NOT NULL,
        price REAL NOT NULL,
        original_price REAL,
        unit TEXT NOT NULL,
        min_order_qty INTEGER DEFAULT 1,
        rating REAL DEFAULT 4.8,
        reviews_count INTEGER DEFAULT 24,
        protein_pct REAL,
        calcium_pct REAL,
        phosphorus_pct REAL,
        dosage_info TEXT,
        benefits TEXT,
        seller_name TEXT NOT NULL,
        seller_phone TEXT NOT NULL,
        seller_type TEXT DEFAULT 'fpo',
        location TEXT,
        badge TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    `).run();

    await db.prepare(`
      CREATE TABLE IF NOT EXISTS feed_farmer_orders (
        id TEXT PRIMARY KEY,
        farmer_id TEXT,
        farmer_name TEXT,
        farmer_phone TEXT,
        product_id TEXT,
        product_title TEXT,
        quantity INTEGER,
        total_amount REAL,
        payment_method TEXT,
        delivery_address TEXT,
        status TEXT DEFAULT 'confirmed',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    `).run();

    // Check if initial products exist; if not seed them
    const existing = (await db.prepare('SELECT count(*) as cnt FROM feed_marketplace_products').first()) as any;
    if (!existing || existing.cnt === 0) {
      const initialProducts = [
        {
          id: 'feed-p01',
          title: 'Milterra Chelated Mineral Gold (चिलेटेड मिनरल मिक्सर)',
          brand: 'Milterra Nutrition',
          category: 'mineral_mixture',
          price: 135.0,
          original_price: 220.0,
          unit: '1 kg Pouch',
          min_order_qty: 1,
          rating: 4.9,
          reviews_count: 86,
          protein_pct: 0.0,
          calcium_pct: 28.5,
          phosphorus_pct: 14.2,
          dosage_info: '50 ग्राम प्रतिदिन प्रति वयस्क गाय/भैंस। दाने या चोकर में मिलाकर दें।',
          benefits: '1.2 से 1.5L दूध वृद्धि, बांझपन व रिपीट ब्रीडिंग की रोकथाम, चमकती त्वचा।',
          seller_name: 'हरियाणा डेयरी विकास संघ (HDDC FPO)',
          seller_phone: '9876501122',
          seller_type: 'fpo',
          location: 'करनाल, हरियाणा (Karnal Hub)',
          badge: 'BESTSELLER • 38% OFF',
        },
        {
          id: 'feed-p02',
          title: 'Milterra Chelated Gold Bucket (5kg बाल्टी)',
          brand: 'Milterra Nutrition',
          category: 'mineral_mixture',
          price: 620.0,
          original_price: 950.0,
          unit: '5 kg Bucket',
          min_order_qty: 1,
          rating: 4.9,
          reviews_count: 54,
          protein_pct: 0.0,
          calcium_pct: 28.5,
          phosphorus_pct: 14.2,
          dosage_info: '100 दिन की खुराक। 50g प्रतिदिन।',
          benefits: 'बड़ी बाल्टी पैक में ₹330 की सीधी बचत + एयरटाइट सील सुरक्षा।',
          seller_name: 'किसान शक्ति एग्रो FPO',
          seller_phone: '9876502233',
          seller_type: 'fpo',
          location: 'लुधियाना, पंजाब (Punjab Cluster)',
          badge: 'SUPER VALUE BUCKET',
        },
        {
          id: 'feed-p03',
          title: 'Calci-Lact Strong Liquid Calcium (मिल्क फीवर बचाव)',
          brand: 'Pashu Raksha Vet',
          category: 'calcium_supplement',
          price: 780.0,
          original_price: 1150.0,
          unit: '5 Litre Can',
          min_order_qty: 1,
          rating: 4.8,
          reviews_count: 42,
          protein_pct: 0.0,
          calcium_pct: 35.0,
          phosphorus_pct: 17.5,
          dosage_info: '100ml प्रतिदिन ब्याने के 10 दिन पहले और 30 दिन बाद तक।',
          benefits: 'ब्याने के बाद कैल्शियम की कमी (मिल्क फीवर) से 100% सुरक्षा व दूध पीक पर ले जाए।',
          seller_name: 'शर्मा वेटरनरी मेडिकल्स',
          seller_phone: '9876503344',
          seller_type: 'dealer',
          location: 'मेरठ, उत्तर प्रदेश (UP West)',
          badge: 'VET RECOMMENDED',
        },
        {
          id: 'feed-p04',
          title: 'Energy-Bypass Fat 99% (फैट बढ़ाने वाला स्पेशल फीड)',
          brand: 'GoldDairy Bio',
          category: 'bypass_fat',
          price: 1450.0,
          original_price: 1950.0,
          unit: '25 kg Bag',
          min_order_qty: 1,
          rating: 4.7,
          reviews_count: 31,
          protein_pct: 0.0,
          calcium_pct: 9.0,
          phosphorus_pct: 0.0,
          dosage_info: '100-150 ग्राम प्रतिदिन अधिक दूध देने वाले पशुओं के लिए।',
          benefits: 'दूध का फैट 0.6% से 1.2% तक बढ़ाए, ऊर्जा की कमी रोके और तेजी से वजन सुधारे।',
          seller_name: 'प्रोग्रेसिव डेयरी फार्मर एसोसिएशन',
          seller_phone: '9876504455',
          seller_type: 'fpo',
          location: 'अंबाला, हरियाणा',
          badge: 'HIGH FAT BOOST',
        },
        {
          id: 'feed-p05',
          title: 'Kisan Dhenu Balanced Pellets 22% CP (संतुलित पशुआहार)',
          brand: 'Kisan Dhenu Feed',
          category: 'cattle_feed',
          price: 1320.0,
          original_price: 1680.0,
          unit: '50 kg Bag',
          min_order_qty: 2,
          rating: 4.8,
          reviews_count: 118,
          protein_pct: 22.0,
          calcium_pct: 1.8,
          phosphorus_pct: 0.9,
          dosage_info: 'प्रति 1L दूध पर 400g दाना + 1.5kg शरीर रक्षा के लिए।',
          benefits: 'मक्का दरिया, बिनौला, सरसों खल, गेहूं चोकर व मिनरल्स का संतुलित मिश्रण।',
          seller_name: 'श्री बालाजी कैटल फीड मिल्स',
          seller_phone: '9876505566',
          seller_type: 'manufacturer',
          location: 'जींद, हरियाणा (Direct Mill Rate)',
          badge: 'DIRECT FACTORY RATE',
        },
        {
          id: 'feed-p06',
          title: 'Green Corn Silage Bales (मक्का साइलेज गांठ 60kg)',
          brand: 'GreenField Silage',
          category: 'silage',
          price: 390.0,
          original_price: 520.0,
          unit: '60 kg Bale',
          min_order_qty: 5,
          rating: 4.9,
          reviews_count: 67,
          protein_pct: 8.5,
          calcium_pct: 0.5,
          phosphorus_pct: 0.3,
          dosage_info: '15-20 किलो प्रतिदिन प्रति गाय/भैंस।',
          benefits: '100% ताजे मीठे मक्का का साइलेज। गर्मियों में हरा चारा न होने पर भी दूध कम नहीं होने देता।',
          seller_name: 'पंजाब साइलेज फार्म्स क्लस्टर',
          seller_phone: '9876506677',
          seller_type: 'farmer',
          location: 'पटियाला, पंजाब',
          badge: 'SWEET CORN SILAGE',
        },
        {
          id: 'feed-p07',
          title: 'Free Mineral Mix Trial Pack 500g (मुफ़्त मिनरल मिक्स ट्रायल)',
          brand: 'Milterra Nutrition',
          category: 'trial_pack',
          price: 0.0,
          original_price: 110.0,
          unit: '500g Trial Sample',
          min_order_qty: 1,
          rating: 5.0,
          reviews_count: 240,
          protein_pct: 0.0,
          calcium_pct: 28.5,
          phosphorus_pct: 14.2,
          dosage_info: '10 दिन तक 50g रोज देकर खुद दूध में फर्क देखें।',
          benefits: 'पूरी तरह मुफ्त नमूना! किसान केवल ₹30 गांव पिकअप डिलीवरी शुल्क वहन करें।',
          seller_name: 'मिल्टेरा किसान सहायता मिशन',
          seller_phone: '9876500000',
          seller_type: 'fpo',
          location: 'अखिल भारतीय (All Districts)',
          badge: '100% FREE SAMPLE',
        },
      ];

      for (const p of initialProducts) {
        await db.prepare(`
          INSERT INTO feed_marketplace_products (
            id, title, brand, category, price, original_price, unit, min_order_qty,
            rating, reviews_count, protein_pct, calcium_pct, phosphorus_pct,
            dosage_info, benefits, seller_name, seller_phone, seller_type, location, badge
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `).bind(
          p.id, p.title, p.brand, p.category, p.price, p.original_price, p.unit, p.min_order_qty,
          p.rating, p.reviews_count, p.protein_pct, p.calcium_pct, p.phosphorus_pct,
          p.dosage_info, p.benefits, p.seller_name, p.seller_phone, p.seller_type, p.location, p.badge
        ).run();
      }
    }
  } catch (err) {
    console.error('ensureFeedMarketplaceTables error:', err);
  }
}

// ---------------------------------------------------------------------------
// GET /feed/products (or /feed-marketplace/products)
// ---------------------------------------------------------------------------

feedRouter.get('/feed/products', async (c) => {
  const db = c.env.DB;
  await ensureFeedMarketplaceTables(db);

  const category = c.req.query('category') || 'all';
  const query = (c.req.query('q') || '').trim().toLowerCase();

  let sql = 'SELECT * FROM feed_marketplace_products WHERE 1=1';
  const params: any[] = [];

  if (category !== 'all' && category !== '') {
    sql += ' AND category = ?';
    params.push(category);
  }

  if (query) {
    sql += ' AND (LOWER(title) LIKE ? OR LOWER(brand) LIKE ? OR LOWER(benefits) LIKE ?)';
    params.push(`%${query}%`, `%${query}%`, `%${query}%`);
  }

  sql += ' ORDER BY CASE WHEN badge LIKE "%BESTSELLER%" OR badge LIKE "%FREE%" THEN 0 ELSE 1 END, price ASC';

  const rows = (await db.prepare(sql).bind(...params).all()).results || [];

  return c.json({
    success: true,
    data: {
      total: rows.length,
      category,
      products: rows,
    },
    message: 'Feed products fetched successfully',
  });
});

// ---------------------------------------------------------------------------
// POST /feed/products (Vendor / FPO Onboarding & Feed Promotion)
// ---------------------------------------------------------------------------

feedRouter.post('/feed/products', async (c) => {
  const db = c.env.DB;
  await ensureFeedMarketplaceTables(db);

  let body: any = {};
  try {
    body = await c.req.json();
  } catch {
    throw new HTTPException(400, { message: 'Invalid JSON payload' });
  }

  const {
    title,
    brand,
    category,
    price,
    original_price,
    unit,
    min_order_qty,
    protein_pct,
    calcium_pct,
    phosphorus_pct,
    dosage_info,
    benefits,
    seller_name,
    seller_phone,
    seller_type,
    location,
    badge,
  } = body;

  if (!title || !price || !unit || !seller_name || !seller_phone) {
    throw new HTTPException(400, { message: 'Title, price, unit, seller_name, and seller_phone are required' });
  }

  const id = `feed-p-${Date.now().toString(36)}-${Math.random().toString(36).slice(-4)}`;

  await db.prepare(`
    INSERT INTO feed_marketplace_products (
      id, title, brand, category, price, original_price, unit, min_order_qty,
      rating, reviews_count, protein_pct, calcium_pct, phosphorus_pct,
      dosage_info, benefits, seller_name, seller_phone, seller_type, location, badge
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 5.0, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).bind(
    id,
    title,
    brand || seller_name,
    category || 'mineral_mixture',
    parseFloat(price) || 0.0,
    original_price ? parseFloat(original_price) : (parseFloat(price) * 1.25),
    unit,
    parseInt(min_order_qty, 10) || 1,
    protein_pct ? parseFloat(protein_pct) : 0.0,
    calcium_pct ? parseFloat(calcium_pct) : 0.0,
    phosphorus_pct ? parseFloat(phosphorus_pct) : 0.0,
    dosage_info || 'प्रतिदिन 50-100 ग्राम दाने में मिलाकर दें।',
    benefits || 'दूध वृद्धि व पशु स्वास्थ्य के लिए उत्तम।',
    seller_name,
    seller_phone,
    seller_type || 'fpo',
    location || 'स्थानीय FPO/डीलर',
    badge || 'NEW SELLER VERIFIED'
  ).run();

  return c.json({
    success: true,
    data: {
      id,
      title,
      price,
      seller_name,
      message: 'आपका पशुआहार उत्पाद सफलतापूर्वक लिस्ट और प्रमोट हो गया है!',
    },
  }, 201);
});

// ---------------------------------------------------------------------------
// POST /feed/roi-calculator (Milk Yield & Supplement Profitability Engine)
// ---------------------------------------------------------------------------

feedRouter.post('/feed/roi-calculator', async (c) => {
  let body: any = {};
  try {
    body = await c.req.json();
  } catch {
    body = {};
  }

  const animalType = (body.animal_type || 'cow').toLowerCase(); // 'cow' or 'buffalo'
  const currentMilkLitres = parseFloat(body.current_milk_litres) || 10.0;
  const supplement = body.supplement || 'mineral_mixture'; // 'mineral_mixture', 'calcium', 'bypass_fat'

  let dailyDoseGram = 50;
  let dailySupplementCost = 4.0;
  let expectedMilkGainLitres = 1.25;
  let milkRatePerLitre = animalType === 'cow' ? 38.50 : 62.00;

  if (supplement === 'calcium') {
    dailyDoseGram = 100;
    dailySupplementCost = 15.60;
    expectedMilkGainLitres = 1.80;
  } else if (supplement === 'bypass_fat') {
    dailyDoseGram = 100;
    dailySupplementCost = 12.00;
    expectedMilkGainLitres = 1.50;
  } else {
    // Standard chelated mineral mixture
    dailyDoseGram = 50;
    dailySupplementCost = 3.85; // 50g at ~₹77/kg
    expectedMilkGainLitres = 1.30;
  }

  const dailyGrossGain = Math.round(expectedMilkGainLitres * milkRatePerLitre * 100) / 100;
  const dailyNetProfit = Math.round((dailyGrossGain - dailySupplementCost) * 100) / 100;
  const monthlyNetProfit = Math.round(dailyNetProfit * 30 * 100) / 100;
  const roiMultiplier = Math.round((dailyGrossGain / dailySupplementCost) * 10) / 10;

  return c.json({
    success: true,
    data: {
      animal_type: animalType,
      current_milk_litres: currentMilkLitres,
      supplement,
      daily_dosage_gram: dailyDoseGram,
      daily_cost_rs: dailySupplementCost,
      expected_milk_increase_litres: expectedMilkGainLitres,
      milk_rate_rs_per_litre: milkRatePerLitre,
      daily_extra_revenue_rs: dailyGrossGain,
      daily_net_profit_rs: dailyNetProfit,
      monthly_net_profit_rs: monthlyNetProfit,
      roi_multiplier: `${roiMultiplier}x`,
      summary_hindi: `मात्र ₹${dailySupplementCost}/दिन का मिनरल मिक्स खिलाने पर रोज़ाना ₹${dailyGrossGain} का अतिरिक्त दूध मिलेगा। महीने का शुद्ध अतिरिक्त मुनाफा ₹${monthlyNetProfit} per animal होगा!`,
    },
  });
});

// ---------------------------------------------------------------------------
// POST /feed/orders (Farmer Feed Booking with CoD / Milk Bill Deduction)
// ---------------------------------------------------------------------------

feedRouter.post('/feed/orders', async (c) => {
  const db = c.env.DB;
  await ensureFeedMarketplaceTables(db);

  let body: any = {};
  try {
    body = await c.req.json();
  } catch {
    throw new HTTPException(400, { message: 'Invalid JSON payload' });
  }

  const {
    farmer_id,
    farmer_name,
    farmer_phone,
    product_id,
    product_title,
    quantity,
    total_amount,
    payment_method, // 'cod', 'upi', 'milk_payout_deduction'
    delivery_address,
  } = body;

  if (!product_id || !quantity || !total_amount) {
    throw new HTTPException(400, { message: 'product_id, quantity, and total_amount are required' });
  }

  const orderId = `feed-ord-${Date.now().toString(36)}-${Math.random().toString(36).slice(-4)}`;

  await db.prepare(`
    INSERT INTO feed_farmer_orders (
      id, farmer_id, farmer_name, farmer_phone, product_id, product_title,
      quantity, total_amount, payment_method, delivery_address, status
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'confirmed')
  `).bind(
    orderId,
    farmer_id || 'guest-farmer',
    farmer_name || 'किसान साथी',
    farmer_phone || '9876543210',
    product_id,
    product_title || 'Cattle Feed / Mineral Mixture',
    parseInt(quantity, 10) || 1,
    parseFloat(total_amount) || 0.0,
    payment_method || 'milk_payout_deduction',
    delivery_address || 'गांव डेयरी समिति पिकअप सेंटर'
  ).run();

  return c.json({
    success: true,
    data: {
      order_id: orderId,
      status: 'confirmed',
      payment_method: payment_method || 'milk_payout_deduction',
      total_amount,
      delivery_address: delivery_address || 'गांव डेयरी समिति पिकअप सेंटर',
      message: payment_method === 'milk_payout_deduction'
        ? 'ऑर्डर सफल! यह राशि आपके 10-दिवसीय दूध बिल से स्वतः समायोजित हो जाएगी।'
        : 'ऑर्डर सफल! आपके गांव में 24-48 घंटे में डिलीवरी कर दी जाएगी।',
    },
  }, 201);
});

