import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { z } from 'zod';
import type { Env } from '../types/env.js';
import { requireAuth } from './commerce.js';
import { getFarmerByUserId } from './farmers.js';

export const collectionRouter = new Hono<{ Bindings: Env }>();

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

const CenterCreateSchema = z.object({
  name: z.string().min(2).max(200),
  code: z.string().min(2).max(50),
  cooperative_id: z.string().max(100).nullable().optional(),
  address: z.string().max(500).nullable().optional(),
  village: z.string().max(100).nullable().optional(),
  district: z.string().max(100).nullable().optional(),
  state: z.string().max(100).nullable().optional(),
  pincode: z.string().max(20).nullable().optional(),
  lat: z.number().nullable().optional(),
  lng: z.number().nullable().optional(),
  capacity_litres: z.number().positive().default(1000).optional(),
  chilling_temp_celsius: z.number().default(4.0).optional(),
  has_fat_analyzer: z.boolean().default(true).optional(),
  has_snf_analyzer: z.boolean().default(true).optional(),
  manager_name: z.string().max(100).nullable().optional(),
  manager_phone: z.string().max(20).nullable().optional(),
  status: z.enum(['active', 'inactive', 'maintenance']).default('active').optional(),
});

const CenterUpdateSchema = z.object({
  name: z.string().min(2).max(200).optional(),
  address: z.string().max(500).nullable().optional(),
  village: z.string().max(100).nullable().optional(),
  district: z.string().max(100).nullable().optional(),
  state: z.string().max(100).nullable().optional(),
  pincode: z.string().max(20).nullable().optional(),
  lat: z.number().nullable().optional(),
  lng: z.number().nullable().optional(),
  capacity_litres: z.number().positive().optional(),
  chilling_temp_celsius: z.number().optional(),
  has_fat_analyzer: z.boolean().optional(),
  has_snf_analyzer: z.boolean().optional(),
  manager_name: z.string().max(100).nullable().optional(),
  manager_phone: z.string().max(20).nullable().optional(),
  status: z.enum(['active', 'inactive', 'maintenance']).optional(),
});

const ShiftEnum = z.enum(['morning', 'evening']);

const MilkCollectionCreateSchema = z.object({
  center_id: z.string().min(1),
  farmer_id: z.string().min(1),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).default(() => new Date().toISOString().slice(0, 10)),
  shift: ShiftEnum,
  quantity_litres: z.number().positive(),
  fat_pct: z.number().min(0).max(15),
  snf_pct: z.number().min(0).max(15),
  temperature_celsius: z.number().nullable().optional(),
  rate_per_litre: z.number().positive().nullable().optional(),
  quality_bonus: z.number().nonnegative().nullable().optional(),
  deductions: z.number().nonnegative().nullable().optional(),
});

// ---------------------------------------------------------------------------
// Business Logic: Quality Evaluation & Price Determination
// ---------------------------------------------------------------------------

export interface QualityEvaluation {
  grade: 'A' | 'B' | 'C' | 'rejected';
  ratePerLitre: number;
  qualityBonus: number;
  deductions: number;
  totalAmount: number;
  netAmount: number;
  isRejected: boolean;
  rejectionReason: string | null;
}

export function evaluateMilkIntake(
  quantityLitres: number,
  fatPct: number,
  snfPct: number,
  overrideRate?: number | null,
  overrideBonus?: number | null,
  overrideDeductions?: number | null
): QualityEvaluation {
  // Statutory minimum standard for cow/buffalo milk collection:
  // Fat >= 3.0%, SNF >= 7.5%
  if (fatPct < 3.0 || snfPct < 7.5) {
    return {
      grade: 'rejected',
      ratePerLitre: 0,
      qualityBonus: 0,
      deductions: 0,
      totalAmount: 0,
      netAmount: 0,
      isRejected: true,
      rejectionReason: 'Milk quality below statutory threshold (Minimum Fat: 3.0%, SNF: 7.5%)',
    };
  }

  let grade: 'A' | 'B' | 'C';
  let defaultBonus = 0;
  let defaultDeductions = 0;

  if (fatPct >= 4.5 && snfPct >= 8.5) {
    grade = 'A';
    defaultBonus = Math.round(quantityLitres * 2.0 * 100) / 100; // Rs 2.00/L incentive for Grade A
  } else if (fatPct >= 3.8 && snfPct >= 8.2) {
    grade = 'B';
    defaultBonus = 0;
  } else {
    grade = 'C';
    defaultDeductions = Math.round(quantityLitres * 1.0 * 100) / 100; // Rs 1.00/L penalty for Grade C
  }

  const bonus = overrideBonus != null ? overrideBonus : defaultBonus;
  const deductions = overrideDeductions != null ? overrideDeductions : defaultDeductions;

  // Standard cooperative two-axis pricing formula: Fat * 6.50 + SNF * 2.20
  const computedRate = Math.round((fatPct * 6.5 + snfPct * 2.2) * 100) / 100;
  const ratePerLitre = overrideRate != null && overrideRate > 0 ? overrideRate : computedRate;

  const totalAmount = Math.round(quantityLitres * ratePerLitre * 100) / 100;
  const netAmount = Math.max(0, Math.round((totalAmount + bonus - deductions) * 100) / 100);

  return {
    grade,
    ratePerLitre,
    qualityBonus: bonus,
    deductions,
    totalAmount,
    netAmount,
    isRejected: false,
    rejectionReason: null,
  };
}

export function formatWhatsAppSlip(params: {
  farmerName: string;
  shift: string;
  quantityLitres: number;
  fatPct: number;
  snfPct: number;
  grade: string;
  ratePerLitre: number;
  netAmount: number;
  date: string;
  centerName?: string;
  centerCode?: string;
  isRejected?: boolean;
  rejectionReason?: string | null;
  walletBalance?: number;
  phone?: string;
}): { text: string; url: string; phone: string } {
  const shiftTitle = params.shift === 'evening' ? 'Evening' : 'Morning';
  const centerInfo = params.centerName ? `${params.centerName}${params.centerCode ? ` (${params.centerCode})` : ''}` : 'Milterra BMC';
  const cleanPhone = (params.phone || '').replace(/\D/g, '');
  const phoneParam = cleanPhone ? (cleanPhone.startsWith('91') ? cleanPhone : `91${cleanPhone}`) : '';

  if (params.isRejected) {
    const text = `⚠️ *MILTERRA MILK COLLECTION NOTICE*\n\nNamaste *${params.farmerName} ji*!\nYour ${shiftTitle} milk intake of *${params.quantityLitres} L* could not be accepted.\nReason: ${params.rejectionReason || 'Quality below statutory limits'}\n📍 Center: *${centerInfo}*\n📅 Date: *${params.date}*\n\n_Milterra Dairy Services_`;
    return {
      text,
      url: phoneParam
        ? `https://api.whatsapp.com/send?phone=${phoneParam}&text=${encodeURIComponent(text)}`
        : `https://api.whatsapp.com/send?text=${encodeURIComponent(text)}`,
      phone: cleanPhone,
    };
  }

  const walletLine = params.walletBalance != null
    ? `\n💰 *Milterra Wallet Balance:* ₹${params.walletBalance.toFixed(2)}`
    : '';

  const text = `🥛 *MILTERRA DAIRY COLLECTION SLIP*\n\nNamaste *${params.farmerName} ji*! ${shiftTitle} collection: *${params.quantityLitres} Litres* | Fat: *${params.fatPct}%* | SNF: *${params.snfPct}%* | Payout: *₹${params.netAmount.toFixed(2)}* credited to Milterra Wallet.\n\n📊 *Quality Grade:* Grade ${params.grade}\n⚡ *Rate:* ₹${params.ratePerLitre.toFixed(2)}/L${walletLine}\n📍 *Center:* ${centerInfo}\n📅 *Date:* ${params.date} (${shiftTitle})\n\n📲 View passbook & 1-Click UPI withdrawal:\nhttps://farmers.milterrafoods.com/#/wallet\n\n_Milterra Foods • Pure Dairy Direct From Farmers_`;

  return {
    text,
    url: phoneParam
      ? `https://api.whatsapp.com/send?phone=${phoneParam}&text=${encodeURIComponent(text)}`
      : `https://api.whatsapp.com/send?text=${encodeURIComponent(text)}`,
    phone: cleanPhone,
  };
}

// ---------------------------------------------------------------------------
// 1. Collection Centers Management
// ---------------------------------------------------------------------------

collectionRouter.post('/centers', async (c) => {
  await requireAuth(c);
  const db = c.env.DB;

  const body = await c.req.json().catch(() => null);
  const parsed = CenterCreateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid collection center details' });
  }

  const centerId = crypto.randomUUID();
  const code = parsed.data.code.trim().toUpperCase();

  try {
    await db.prepare(
      `INSERT INTO collection_centers (
        id, name, code, cooperative_id, address, village, district, state, pincode,
        lat, lng, capacity_litres, chilling_temp_celsius, has_fat_analyzer, has_snf_analyzer,
        manager_name, manager_phone, status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).bind(
      centerId,
      parsed.data.name.trim(),
      code,
      parsed.data.cooperative_id || null,
      parsed.data.address || null,
      parsed.data.village || null,
      parsed.data.district || null,
      parsed.data.state || null,
      parsed.data.pincode || null,
      parsed.data.lat ?? null,
      parsed.data.lng ?? null,
      parsed.data.capacity_litres ?? 1000,
      parsed.data.chilling_temp_celsius ?? 4.0,
      parsed.data.has_fat_analyzer ? 1 : 0,
      parsed.data.has_snf_analyzer ? 1 : 0,
      parsed.data.manager_name || null,
      parsed.data.manager_phone || null,
      parsed.data.status || 'active'
    ).run();
  } catch (err: any) {
    if (String(err).toUpperCase().includes('UNIQUE')) {
      throw new HTTPException(409, { message: 'Collection center code already registered' });
    }
    throw err;
  }

  return c.json(
    {
      success: true,
      data: {
        id: centerId,
        code,
        name: parsed.data.name.trim(),
        capacity_litres: parsed.data.capacity_litres ?? 1000,
      },
      message: 'Collection center registered',
    },
    201
  );
});

collectionRouter.get('/centers', async (c) => {
  const db = c.env.DB;
  const status = c.req.query('status');
  const district = c.req.query('district');
  const village = c.req.query('village');

  let query = 'SELECT * FROM collection_centers WHERE 1=1';
  const params: any[] = [];

  if (status) {
    query += ' AND status = ?';
    params.push(status);
  }
  if (district) {
    query += ' AND district = ?';
    params.push(district);
  }
  if (village) {
    query += ' AND village = ?';
    params.push(village);
  }

  query += ' ORDER BY name ASC';

  const rows = await db.prepare(query).bind(...params).all();

  return c.json({
    success: true,
    data: (rows.results || []).map((r: any) => ({
      id: r.id,
      name: r.name,
      code: r.code,
      village: r.village,
      district: r.district,
      state: r.state,
      capacity_litres: r.capacity_litres,
      current_stock_litres: r.current_stock_litres,
      chilling_temp_celsius: r.chilling_temp_celsius,
      has_fat_analyzer: Boolean(r.has_fat_analyzer),
      has_snf_analyzer: Boolean(r.has_snf_analyzer),
      manager_name: r.manager_name,
      manager_phone: r.manager_phone,
      status: r.status,
    })),
    message: 'Collection centers',
  });
});

collectionRouter.get('/centers/:id', async (c) => {
  const centerId = c.req.param('id');
  const db = c.env.DB;

  const center = (await db.prepare('SELECT * FROM collection_centers WHERE id = ?').bind(centerId).first()) as any;
  if (!center) {
    throw new HTTPException(404, { message: 'Collection center not found' });
  }

  const utilization = center.capacity_litres > 0
    ? Math.round((center.current_stock_litres / center.capacity_litres) * 1000) / 10
    : 0;

  return c.json({
    success: true,
    data: {
      id: center.id,
      name: center.name,
      code: center.code,
      address: center.address,
      village: center.village,
      district: center.district,
      state: center.state,
      pincode: center.pincode,
      capacity_litres: center.capacity_litres,
      current_stock_litres: center.current_stock_litres,
      capacity_utilization_pct: utilization,
      chilling_temp_celsius: center.chilling_temp_celsius,
      has_fat_analyzer: Boolean(center.has_fat_analyzer),
      has_snf_analyzer: Boolean(center.has_snf_analyzer),
      manager_name: center.manager_name,
      manager_phone: center.manager_phone,
      status: center.status,
      created_at: center.created_at,
    },
    message: 'Collection center details',
  });
});

collectionRouter.put('/centers/:id', async (c) => {
  await requireAuth(c);
  const centerId = c.req.param('id');
  const db = c.env.DB;

  const center = (await db.prepare('SELECT * FROM collection_centers WHERE id = ?').bind(centerId).first()) as any;
  if (!center) {
    throw new HTTPException(404, { message: 'Collection center not found' });
  }

  const body = await c.req.json().catch(() => ({}));
  const parsed = CenterUpdateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid update details' });
  }

  const name = parsed.data.name !== undefined ? parsed.data.name.trim() : center.name;
  const address = parsed.data.address !== undefined ? parsed.data.address : center.address;
  const village = parsed.data.village !== undefined ? parsed.data.village : center.village;
  const district = parsed.data.district !== undefined ? parsed.data.district : center.district;
  const state = parsed.data.state !== undefined ? parsed.data.state : center.state;
  const pincode = parsed.data.pincode !== undefined ? parsed.data.pincode : center.pincode;
  const lat = parsed.data.lat !== undefined ? parsed.data.lat : center.lat;
  const lng = parsed.data.lng !== undefined ? parsed.data.lng : center.lng;
  const capacity = parsed.data.capacity_litres !== undefined ? parsed.data.capacity_litres : center.capacity_litres;
  const temp = parsed.data.chilling_temp_celsius !== undefined ? parsed.data.chilling_temp_celsius : center.chilling_temp_celsius;
  const hasFat = parsed.data.has_fat_analyzer !== undefined ? (parsed.data.has_fat_analyzer ? 1 : 0) : center.has_fat_analyzer;
  const hasSnf = parsed.data.has_snf_analyzer !== undefined ? (parsed.data.has_snf_analyzer ? 1 : 0) : center.has_snf_analyzer;
  const managerName = parsed.data.manager_name !== undefined ? parsed.data.manager_name : center.manager_name;
  const managerPhone = parsed.data.manager_phone !== undefined ? parsed.data.manager_phone : center.manager_phone;
  const status = parsed.data.status !== undefined ? parsed.data.status : center.status;

  await db.prepare(
    `UPDATE collection_centers
     SET name = ?, address = ?, village = ?, district = ?, state = ?, pincode = ?,
         lat = ?, lng = ?, capacity_litres = ?, chilling_temp_celsius = ?,
         has_fat_analyzer = ?, has_snf_analyzer = ?, manager_name = ?, manager_phone = ?,
         status = ?, updated_at = CURRENT_TIMESTAMP
     WHERE id = ?`
  ).bind(
    name, address, village, district, state, pincode,
    lat, lng, capacity, temp, hasFat, hasSnf, managerName, managerPhone,
    status, centerId
  ).run();

  return c.json({
    success: true,
    data: { id: centerId, name, status },
    message: 'Collection center updated',
  });
});

// ---------------------------------------------------------------------------
// 2. Milk Intake Entry Recording
// ---------------------------------------------------------------------------

collectionRouter.post('/entries', async (c) => {
  await requireAuth(c);
  const db = c.env.DB;

  const body = await c.req.json().catch(() => null);
  const parsed = MilkCollectionCreateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid collection intake details' });
  }

  // Validate Center
  const center = (await db.prepare('SELECT id, status FROM collection_centers WHERE id = ?').bind(parsed.data.center_id).first()) as any;
  if (!center) {
    throw new HTTPException(404, { message: 'Collection center not found' });
  }
  if (center.status !== 'active') {
    throw new HTTPException(400, { message: `Center is currently ${center.status}` });
  }

  // Validate Farmer
  const farmer = (await db.prepare('SELECT id, name, user_id, phone FROM farmers WHERE id = ?').bind(parsed.data.farmer_id).first()) as any;
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer not found' });
  }

  let farmerPhone = farmer.phone || '';
  if (!farmerPhone && farmer.user_id) {
    const cust = (await db.prepare('SELECT phone FROM customers WHERE id = ?').bind(farmer.user_id).first()) as any;
    if (cust?.phone) farmerPhone = cust.phone;
  }

  const evaluation = evaluateMilkIntake(
    parsed.data.quantity_litres,
    parsed.data.fat_pct,
    parsed.data.snf_pct,
    parsed.data.rate_per_litre,
    parsed.data.quality_bonus,
    parsed.data.deductions
  );

  const entryId = crypto.randomUUID();
  const ledgerId = crypto.randomUUID();

  // Compute current wallet balance for slip preview
  const prevEarnings = (await db.prepare(
    `SELECT COALESCE(SUM(net_amount), 0) as total FROM milk_collections WHERE farmer_id = ? AND is_rejected = 0`
  ).bind(parsed.data.farmer_id).first()) as any;
  const newWalletEstimate = Number(prevEarnings?.total || 0) + (evaluation.isRejected ? 0 : evaluation.netAmount);

  const slip = formatWhatsAppSlip({
    farmerName: farmer.name,
    shift: parsed.data.shift,
    quantityLitres: parsed.data.quantity_litres,
    fatPct: parsed.data.fat_pct,
    snfPct: parsed.data.snf_pct,
    grade: evaluation.grade,
    ratePerLitre: evaluation.ratePerLitre,
    netAmount: evaluation.netAmount,
    date: parsed.data.date,
    centerName: center.name,
    centerCode: center.code,
    isRejected: evaluation.isRejected,
    rejectionReason: evaluation.rejectionReason,
    walletBalance: newWalletEstimate,
    phone: farmerPhone,
  });

  const stmts: D1PreparedStatement[] = [
    db.prepare(
      `INSERT INTO milk_collections (
        id, center_id, farmer_id, date, shift, quantity_litres, fat_pct, snf_pct,
        temperature_celsius, milk_grade, rate_per_litre, total_amount, quality_bonus,
        deductions, net_amount, is_rejected, rejection_reason, whatsapp_slip_sent, whatsapp_slip_text
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)`
    ).bind(
      entryId,
      parsed.data.center_id,
      parsed.data.farmer_id,
      parsed.data.date,
      parsed.data.shift,
      parsed.data.quantity_litres,
      parsed.data.fat_pct,
      parsed.data.snf_pct,
      parsed.data.temperature_celsius ?? null,
      evaluation.grade,
      evaluation.ratePerLitre,
      evaluation.totalAmount,
      evaluation.qualityBonus,
      evaluation.deductions,
      evaluation.netAmount,
      evaluation.isRejected ? 1 : 0,
      evaluation.rejectionReason,
      slip.text
    ),
  ];

  // If milk is accepted, increment center current stock and credit farmer wallet ledger
  if (!evaluation.isRejected) {
    stmts.push(
      db.prepare(
        'UPDATE collection_centers SET current_stock_litres = current_stock_litres + ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?'
      ).bind(parsed.data.quantity_litres, parsed.data.center_id)
    );
    stmts.push(
      db.prepare(
        `INSERT INTO farmer_wallet_ledger (
          id, farmer_id, type, amount, balance_after, reference_id, title, description, status, metadata
        ) VALUES (?, ?, 'milk_payout', ?, ?, ?, ?, ?, 'completed', ?)`
      ).bind(
        ledgerId,
        parsed.data.farmer_id,
        evaluation.netAmount,
        newWalletEstimate,
        entryId,
        `${parsed.data.shift === 'morning' ? 'Morning' : 'Evening'} Milk Collection (${parsed.data.quantity_litres} L)`,
        `Grade ${evaluation.grade} • Fat ${parsed.data.fat_pct}% • SNF ${parsed.data.snf_pct}% @ ₹${evaluation.ratePerLitre}/L`,
        JSON.stringify({ center_id: parsed.data.center_id, date: parsed.data.date, shift: parsed.data.shift })
      )
    );
  }

  await db.batch(stmts);

  return c.json(
    {
      success: true,
      data: {
        id: entryId,
        farmer_id: parsed.data.farmer_id,
        farmer_name: farmer.name,
        farmer_phone: farmerPhone,
        date: parsed.data.date,
        shift: parsed.data.shift,
        quantity_litres: parsed.data.quantity_litres,
        fat_pct: parsed.data.fat_pct,
        snf_pct: parsed.data.snf_pct,
        grade: evaluation.grade,
        rate_per_litre: evaluation.ratePerLitre,
        total_amount: evaluation.totalAmount,
        quality_bonus: evaluation.qualityBonus,
        deductions: evaluation.deductions,
        net_amount: evaluation.netAmount,
        is_rejected: evaluation.isRejected,
        rejection_reason: evaluation.rejectionReason,
        wallet_balance: newWalletEstimate,
        whatsapp_slip: {
          text: slip.text,
          url: slip.url,
          phone: slip.phone,
          status: 'ready',
        },
      },
      message: evaluation.isRejected ? 'Milk batch rejected due to quality standards' : 'Milk collection recorded',
    },
    201
  );
});

// ---------------------------------------------------------------------------
// 3. List Collection Entries
// ---------------------------------------------------------------------------

collectionRouter.get('/entries', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const centerId = c.req.query('center_id');
  let farmerId = c.req.query('farmer_id');
  // Non-admin callers can only ever see their own farm's slips.
  if (user.role !== 'admin') {
    const ownFarmer = await getFarmerByUserId(db, user.id);
    if (!ownFarmer) {
      return c.json({ success: true, data: [], message: 'Milk collection entries' });
    }
    farmerId = ownFarmer.id;
  }
  const date = c.req.query('date');
  const shift = c.req.query('shift');
  const limit = Math.min(Math.max(Number(c.req.query('limit') || 50), 1), 200);
  const offset = Math.max(Number(c.req.query('offset') || 0), 0);

  let query = `
    SELECT m.*, f.name as farmer_name, c.name as center_name
    FROM milk_collections m
    JOIN farmers f ON f.id = m.farmer_id
    JOIN collection_centers c ON c.id = m.center_id
    WHERE 1=1
  `;
  const params: any[] = [];

  if (centerId) {
    query += ' AND m.center_id = ?';
    params.push(centerId);
  }
  if (farmerId) {
    query += ' AND m.farmer_id = ?';
    params.push(farmerId);
  }
  if (date) {
    query += ' AND m.date = ?';
    params.push(date);
  }
  if (shift) {
    query += ' AND m.shift = ?';
    params.push(shift);
  }

  query += ' ORDER BY m.date DESC, m.created_at DESC LIMIT ? OFFSET ?';
  params.push(limit, offset);

  const rows = await db.prepare(query).bind(...params).all();

  return c.json({
    success: true,
    data: (rows.results || []).map((r: any) => ({
      id: r.id,
      center_id: r.center_id,
      center_name: r.center_name,
      farmer_id: r.farmer_id,
      farmer_name: r.farmer_name,
      date: r.date,
      shift: r.shift,
      quantity_litres: r.quantity_litres,
      fat_pct: r.fat_pct,
      snf_pct: r.snf_pct,
      grade: r.milk_grade,
      rate_per_litre: r.rate_per_litre,
      net_amount: r.net_amount,
      is_rejected: Boolean(r.is_rejected),
      rejection_reason: r.rejection_reason,
      created_at: r.created_at,
    })),
    message: 'Milk collection entries',
  });
});

collectionRouter.get('/entries/:id', async (c) => {
  await requireAuth(c);
  const entryId = c.req.param('id');
  const db = c.env.DB;

  const row = (await db.prepare(
    `SELECT m.*, f.name as farmer_name, f.village as farmer_village, c.name as center_name, c.code as center_code
     FROM milk_collections m
     JOIN farmers f ON f.id = m.farmer_id
     JOIN collection_centers c ON c.id = m.center_id
     WHERE m.id = ?`
  ).bind(entryId).first()) as any;

  if (!row) {
    throw new HTTPException(404, { message: 'Milk collection receipt not found' });
  }

  return c.json({
    success: true,
    data: {
      id: row.id,
      center: {
        id: row.center_id,
        name: row.center_name,
        code: row.center_code,
      },
      farmer: {
        id: row.farmer_id,
        name: row.farmer_name,
        village: row.farmer_village,
      },
      date: row.date,
      shift: row.shift,
      quantity_litres: row.quantity_litres,
      fat_pct: row.fat_pct,
      snf_pct: row.snf_pct,
      temperature_celsius: row.temperature_celsius,
      grade: row.milk_grade,
      rate_per_litre: row.rate_per_litre,
      total_amount: row.total_amount,
      quality_bonus: row.quality_bonus,
      deductions: row.deductions,
      net_amount: row.net_amount,
      is_rejected: Boolean(row.is_rejected),
      rejection_reason: row.rejection_reason,
      created_at: row.created_at,
    },
    message: 'Milk collection receipt',
  });
});

collectionRouter.get('/entries/:id/whatsapp-slip', async (c) => {
  const entryId = c.req.param('id');
  const db = c.env.DB;

  const row = (await db.prepare(
    `SELECT m.*, f.name as farmer_name, f.phone as farmer_phone, f.user_id as farmer_user_id,
            c.name as center_name, c.code as center_code
     FROM milk_collections m
     JOIN farmers f ON f.id = m.farmer_id
     JOIN collection_centers c ON c.id = m.center_id
     WHERE m.id = ?`
  ).bind(entryId).first()) as any;

  if (!row) {
    throw new HTTPException(404, { message: 'Collection entry not found' });
  }

  let phone = row.farmer_phone || '';
  if (!phone && row.farmer_user_id) {
    const cust = (await db.prepare('SELECT phone FROM customers WHERE id = ?').bind(row.farmer_user_id).first()) as any;
    if (cust?.phone) phone = cust.phone;
  }

  const walletSum = (await db.prepare(
    `SELECT COALESCE(SUM(net_amount), 0) as total FROM milk_collections WHERE farmer_id = ? AND is_rejected = 0`
  ).bind(row.farmer_id).first()) as any;

  const slip = formatWhatsAppSlip({
    farmerName: row.farmer_name,
    shift: row.shift,
    quantityLitres: row.quantity_litres,
    fatPct: row.fat_pct,
    snfPct: row.snf_pct,
    grade: row.milk_grade,
    ratePerLitre: row.rate_per_litre,
    netAmount: row.net_amount,
    date: row.date,
    centerName: row.center_name,
    centerCode: row.center_code,
    isRejected: Boolean(row.is_rejected),
    rejectionReason: row.rejection_reason,
    walletBalance: Number(walletSum?.total || 0),
    phone,
  });

  return c.json({
    success: true,
    data: {
      id: row.id,
      slip_text: slip.text,
      whatsapp_url: slip.url,
      phone: slip.phone,
      farmer_name: row.farmer_name,
      already_sent: Boolean(row.whatsapp_slip_sent),
    },
    message: 'WhatsApp milk collection slip',
  });
});

collectionRouter.get('/records/:id/whatsapp-slip', async (c) => {
  return c.redirect(`/api/v1/collection/entries/${c.req.param('id')}/whatsapp-slip`);
});

collectionRouter.post('/entries/:id/share-whatsapp', async (c) => {
  const entryId = c.req.param('id');
  const db = c.env.DB;

  const row = (await db.prepare(
    `SELECT m.*, f.name as farmer_name, f.phone as farmer_phone, f.user_id as farmer_user_id,
            c.name as center_name, c.code as center_code
     FROM milk_collections m
     JOIN farmers f ON f.id = m.farmer_id
     JOIN collection_centers c ON c.id = m.center_id
     WHERE m.id = ?`
  ).bind(entryId).first()) as any;

  if (!row) {
    throw new HTTPException(404, { message: 'Collection entry not found' });
  }

  let phone = row.farmer_phone || '';
  if (!phone && row.farmer_user_id) {
    const cust = (await db.prepare('SELECT phone FROM customers WHERE id = ?').bind(row.farmer_user_id).first()) as any;
    if (cust?.phone) phone = cust.phone;
  }

  const walletSum = (await db.prepare(
    `SELECT COALESCE(SUM(net_amount), 0) as total FROM milk_collections WHERE farmer_id = ? AND is_rejected = 0`
  ).bind(row.farmer_id).first()) as any;

  const slip = formatWhatsAppSlip({
    farmerName: row.farmer_name,
    shift: row.shift,
    quantityLitres: row.quantity_litres,
    fatPct: row.fat_pct,
    snfPct: row.snf_pct,
    grade: row.milk_grade,
    ratePerLitre: row.rate_per_litre,
    netAmount: row.net_amount,
    date: row.date,
    centerName: row.center_name,
    centerCode: row.center_code,
    isRejected: Boolean(row.is_rejected),
    rejectionReason: row.rejection_reason,
    walletBalance: Number(walletSum?.total || 0),
    phone,
  });

  await db.prepare(
    `UPDATE milk_collections SET whatsapp_slip_sent = 1, whatsapp_sent_at = CURRENT_TIMESTAMP WHERE id = ?`
  ).bind(entryId).run();

  return c.json({
    success: true,
    data: {
      id: row.id,
      slip_text: slip.text,
      whatsapp_url: slip.url,
      phone: slip.phone,
      sent: true,
    },
    message: 'WhatsApp slip dispatch logged',
  });
});

collectionRouter.post('/records/:id/share-whatsapp', async (c) => {
  return c.redirect(`/api/v1/collection/entries/${c.req.param('id')}/share-whatsapp`);
});

// ---------------------------------------------------------------------------
// 4. Farmer Passbook
// ---------------------------------------------------------------------------

async function getFarmerPassbookData(db: D1Database, farmerId: string, startDate?: string, endDate?: string) {
  let dateClause = '';
  const params: any[] = [farmerId];

  if (startDate) {
    dateClause += ' AND date >= ?';
    params.push(startDate);
  }
  if (endDate) {
    dateClause += ' AND date <= ?';
    params.push(endDate);
  }

  // Summary aggregation
  const summaryRow = (await db.prepare(
    `SELECT COUNT(*) as total_entries,
            COALESCE(SUM(quantity_litres), 0) as total_litres,
            COALESCE(SUM(net_amount), 0) as total_net_payout,
            COALESCE(AVG(fat_pct), 0) as avg_fat,
            COALESCE(AVG(snf_pct), 0) as avg_snf
     FROM milk_collections
     WHERE farmer_id = ? AND is_rejected = 0 ${dateClause}`
  ).bind(...params).first()) as any;

  // Entries
  const entriesRows = await db.prepare(
    `SELECT id, center_id, date, shift, quantity_litres, fat_pct, snf_pct, milk_grade, rate_per_litre, net_amount, is_rejected
     FROM milk_collections
     WHERE farmer_id = ? ${dateClause}
     ORDER BY date DESC, shift DESC`
  ).bind(...params).all();

  return {
    summary: {
      total_entries: summaryRow?.total_entries || 0,
      total_litres: Math.round(Number(summaryRow?.total_litres || 0) * 100) / 100,
      total_net_payout: Math.round(Number(summaryRow?.total_net_payout || 0) * 100) / 100,
      average_fat_pct: Math.round(Number(summaryRow?.avg_fat || 0) * 10) / 10,
      average_snf_pct: Math.round(Number(summaryRow?.avg_snf || 0) * 10) / 10,
    },
    entries: (entriesRows.results || []).map((r: any) => ({
      id: r.id,
      center_id: r.center_id,
      date: r.date,
      shift: r.shift,
      quantity_litres: r.quantity_litres,
      fat_pct: r.fat_pct,
      snf_pct: r.snf_pct,
      grade: r.milk_grade,
      rate_per_litre: r.rate_per_litre,
      net_amount: r.net_amount,
      is_rejected: Boolean(r.is_rejected),
    })),
  };
}

collectionRouter.get('/farmers/me/passbook', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const startDate = c.req.query('start_date');
  const endDate = c.req.query('end_date');

  const data = await getFarmerPassbookData(db, farmer.id, startDate, endDate);

  return c.json({
    success: true,
    data: {
      farmer: {
        id: farmer.id,
        name: farmer.name,
        village: farmer.village,
      },
      ...data,
    },
    message: 'Farmer collection passbook',
  });
});

collectionRouter.get('/farmers/:farmer_id/passbook', async (c) => {
  await requireAuth(c);
  const farmerId = c.req.param('farmer_id');
  const db = c.env.DB;

  const farmer = (await db.prepare('SELECT id, name, village FROM farmers WHERE id = ?').bind(farmerId).first()) as any;
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer not found' });
  }

  const startDate = c.req.query('start_date');
  const endDate = c.req.query('end_date');

  const data = await getFarmerPassbookData(db, farmerId, startDate, endDate);

  return c.json({
    success: true,
    data: {
      farmer: {
        id: farmer.id,
        name: farmer.name,
        village: farmer.village,
      },
      ...data,
    },
    message: 'Farmer collection passbook',
  });
});
