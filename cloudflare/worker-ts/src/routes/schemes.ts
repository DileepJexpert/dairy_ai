import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { z } from 'zod';
import type { Env } from '../types/env.js';
import { requireAuth } from './commerce.js';
import { getFarmerByUserId } from './farmers.js';

export const schemesRouter = new Hono<{ Bindings: Env }>();

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

const SchemeApplicationSchema = z.object({
  cattle_count: z.number().int().positive(),
  documents_submitted: z.record(z.any()).default({}),
  remarks: z.string().max(1000).optional(),
});

// ---------------------------------------------------------------------------
// Default Indian Government Dairy Schemes Seed Data
// ---------------------------------------------------------------------------

export const DEFAULT_SCHEMES = [
  {
    id: 'scheme-rgm',
    name: 'Rashtriya Gokul Mission (RGM)',
    short_name: 'RGM',
    category: 'breed_multiplication',
    level: 'central',
    description: 'Development and conservation of indigenous bovine breeds, genetic upgradation, and sex-sorted semen subsidy.',
    benefits: '50% capital subsidy up to ₹2 Crore for establishing breed multiplication farms of indigenous Gir, Sahiwal, Red Sindhi, and Murrah.',
    subsidy_amount_max: 20000000.0,
    subsidy_percentage: 50.0,
    required_documents: JSON.stringify(['Aadhaar Card', 'Land Ownership Records', 'Bank Account Passbook', 'Cattle Tag IDs']),
    applicable_states: JSON.stringify(['ALL']),
    min_cattle_count: 5,
    max_cattle_count: 500,
    nodal_agency: 'Department of Animal Husbandry and Dairying (DAHD)',
    application_url: 'https://dahd.nic.in/schemes/programmes/rashtriya-gokul-mission',
    helpline: '1800-180-1551',
  },
  {
    id: 'scheme-ahidf',
    name: 'Animal Husbandry Infrastructure Development Fund (AHIDF)',
    short_name: 'AHIDF',
    category: 'infrastructure',
    level: 'central',
    description: 'Incentivizing investments by individual entrepreneurs, FPOs, and dairy cooperatives in dairy processing and value addition.',
    benefits: '3% interest subvention on bank loan and credit guarantee up to 25% of the credit facility.',
    subsidy_amount_max: 10000000.0,
    subsidy_percentage: 3.0,
    required_documents: JSON.stringify(['PAN Card', 'DPR (Detailed Project Report)', 'Bank Loan Approval Letter', 'FSSAI License']),
    applicable_states: JSON.stringify(['ALL']),
    min_cattle_count: 10,
    max_cattle_count: 10000,
    nodal_agency: 'DAHD / NABARD / SIDBI',
    application_url: 'https://ahidf.udyamimitra.in',
    helpline: '011-23386035',
  },
  {
    id: 'scheme-nlm',
    name: 'National Livestock Mission (NLM) - Fodder and Feed Development',
    short_name: 'NLM',
    category: 'feed_fodder',
    level: 'central',
    description: 'Financial assistance for silage making units, total mixed ration (TMR) plants, and certified fodder seed production.',
    benefits: '50% back-ended capital subsidy up to ₹50 Lakh for fodder block making and silage units.',
    subsidy_amount_max: 5000000.0,
    subsidy_percentage: 50.0,
    required_documents: JSON.stringify(['Aadhaar Card', 'Land Lease Agreement (min 5 years)', 'Bank Details']),
    applicable_states: JSON.stringify(['ALL']),
    min_cattle_count: 5,
    max_cattle_count: 500,
    nodal_agency: 'National Livestock Mission Directorate',
    application_url: 'https://nlm.udyamimitra.in',
    helpline: '1800-180-1551',
  },
  {
    id: 'scheme-kisan-credit-card',
    name: 'Kisan Credit Card (KCC) for Animal Husbandry & Dairying',
    short_name: 'KCC Dairy',
    category: 'credit_working_capital',
    level: 'central',
    description: 'Short term collateral-free working capital loan for milk production, cattle feed, medicines, and veterinary charges.',
    benefits: 'Collateral-free loan up to ₹1.60 Lakh (or ₹3.0 Lakh with tie-up) at an effective interest rate of 4% per annum upon timely repayment.',
    subsidy_amount_max: 300000.0,
    subsidy_percentage: 3.0,
    required_documents: JSON.stringify(['Aadhaar Card', 'Land Records / Milk Pouring Passbook', 'Passport Photo']),
    applicable_states: JSON.stringify(['ALL']),
    min_cattle_count: 1,
    max_cattle_count: 50,
    nodal_agency: 'Reserve Bank of India / NABARD / Commercial Banks',
    application_url: 'https://pmkisan.gov.in',
    helpline: '155261',
  },
];

// Helper: Seed Default Schemes if empty
async function ensureSchemesSeeded(db: D1Database): Promise<void> {
  const existing = (await db.prepare('SELECT COUNT(*) as count FROM government_schemes').first()) as any;
  if (!existing || Number(existing.count) === 0) {
    for (const s of DEFAULT_SCHEMES) {
      await db.prepare(
        `INSERT OR IGNORE INTO government_schemes (
          id, name, short_name, category, level, description, benefits, subsidy_amount_max,
          subsidy_percentage, required_documents, applicable_states, min_cattle_count,
          max_cattle_count, nodal_agency, application_url, helpline, is_active
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)`
      ).bind(
        s.id, s.name, s.short_name, s.category, s.level, s.description, s.benefits,
        s.subsidy_amount_max, s.subsidy_percentage, s.required_documents, s.applicable_states,
        s.min_cattle_count, s.max_cattle_count, s.nodal_agency, s.application_url, s.helpline
      ).run();
    }
  }
}

// ---------------------------------------------------------------------------
// Endpoints
// ---------------------------------------------------------------------------

schemesRouter.get('/schemes', async (c) => {
  const db = c.env.DB;
  await ensureSchemesSeeded(db);

  const category = c.req.query('category');
  const level = c.req.query('level');

  let query = 'SELECT * FROM government_schemes WHERE is_active = 1';
  const params: any[] = [];

  if (category) {
    query += ' AND category = ?';
    params.push(category);
  }
  if (level) {
    query += ' AND level = ?';
    params.push(level);
  }

  query += ' ORDER BY subsidy_amount_max DESC';

  const rows = await db.prepare(query).bind(...params).all();

  return c.json({
    success: true,
    data: (rows.results || []).map((r: any) => ({
      id: r.id,
      name: r.name,
      short_name: r.short_name,
      category: r.category,
      level: r.level,
      description: r.description,
      subsidy_amount_max: r.subsidy_amount_max,
      subsidy_percentage: r.subsidy_percentage,
      nodal_agency: r.nodal_agency,
      min_cattle_count: r.min_cattle_count,
      max_cattle_count: r.max_cattle_count,
    })),
    message: 'Government schemes',
  });
});

schemesRouter.get('/schemes/:scheme_id', async (c) => {
  const db = c.env.DB;
  await ensureSchemesSeeded(db);
  const schemeId = c.req.param('scheme_id');

  const s = (await db.prepare('SELECT * FROM government_schemes WHERE id = ?').bind(schemeId).first()) as any;
  if (!s) {
    throw new HTTPException(404, { message: 'Scheme not found' });
  }

  let requiredDocs: string[] = [];
  try {
    requiredDocs = JSON.parse(s.required_documents || '[]');
  } catch {
    requiredDocs = [];
  }

  return c.json({
    success: true,
    data: {
      id: s.id,
      name: s.name,
      short_name: s.short_name,
      category: s.category,
      level: s.level,
      description: s.description,
      benefits: s.benefits,
      subsidy_amount_max: s.subsidy_amount_max,
      subsidy_percentage: s.subsidy_percentage,
      required_documents: requiredDocs,
      nodal_agency: s.nodal_agency,
      min_cattle_count: s.min_cattle_count,
      max_cattle_count: s.max_cattle_count,
      application_url: s.application_url,
      helpline: s.helpline,
    },
    message: s.name,
  });
});

schemesRouter.get('/schemes/:scheme_id/eligibility/:farmer_id', async (c) => {
  const db = c.env.DB;
  await ensureSchemesSeeded(db);
  const schemeId = c.req.param('scheme_id');
  const farmerId = c.req.param('farmer_id');

  const scheme = (await db.prepare('SELECT * FROM government_schemes WHERE id = ?').bind(schemeId).first()) as any;
  if (!scheme) {
    throw new HTTPException(404, { message: 'Scheme not found' });
  }

  const farmer = (await db.prepare('SELECT id, name, state, total_cattle FROM farmers WHERE id = ?').bind(farmerId).first()) as any;
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer not found' });
  }

  const cattleCount = Number(farmer.total_cattle || 0);
  const reasons: string[] = [];
  let isEligible = true;

  if (cattleCount < scheme.min_cattle_count) {
    isEligible = false;
    reasons.push(`Minimum ${scheme.min_cattle_count} cattle required. Farmer currently has ${cattleCount}.`);
  }
  if (scheme.max_cattle_count && cattleCount > scheme.max_cattle_count) {
    isEligible = false;
    reasons.push(`Maximum cattle limit is ${scheme.max_cattle_count}. Farmer has ${cattleCount}.`);
  }

  let states: string[] = [];
  try {
    states = JSON.parse(scheme.applicable_states || '["ALL"]');
  } catch {
    states = ['ALL'];
  }

  if (!states.includes('ALL') && farmer.state && !states.includes(farmer.state)) {
    isEligible = false;
    reasons.push(`Scheme is not applicable in ${farmer.state}.`);
  }

  return c.json({
    success: true,
    data: {
      scheme_id: scheme.id,
      scheme_name: scheme.name,
      farmer_id: farmer.id,
      farmer_name: farmer.name,
      farmer_cattle_count: cattleCount,
      is_eligible: isEligible,
      reasons: reasons.length > 0 ? reasons : ['All eligibility criteria satisfied'],
      estimated_subsidy: isEligible ? Math.min(scheme.subsidy_amount_max || 100000, cattleCount * 25000) : 0,
    },
    message: 'Eligibility evaluation complete',
  });
});

schemesRouter.get('/schemes/recommendations/:farmer_id', async (c) => {
  const db = c.env.DB;
  await ensureSchemesSeeded(db);
  const farmerId = c.req.param('farmer_id');

  const farmer = (await db.prepare('SELECT total_cattle, state FROM farmers WHERE id = ?').bind(farmerId).first()) as any;
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer not found' });
  }

  const cattleCount = Number(farmer.total_cattle || 0);
  const rows = await db.prepare(
    `SELECT * FROM government_schemes
     WHERE is_active = 1 AND min_cattle_count <= ?
     ORDER BY subsidy_amount_max DESC`
  ).bind(cattleCount).all();

  return c.json({
    success: true,
    data: {
      farmer_cattle_count: cattleCount,
      recommended_schemes: (rows.results || []).map((r: any) => ({
        id: r.id,
        name: r.name,
        short_name: r.short_name,
        category: r.category,
        subsidy_amount_max: r.subsidy_amount_max,
        subsidy_percentage: r.subsidy_percentage,
        benefits: r.benefits,
      })),
    },
    message: `Found ${(rows.results || []).length} recommended schemes`,
  });
});

schemesRouter.post('/schemes/:scheme_id/apply/:farmer_id', async (c) => {
  await requireAuth(c);
  const db = c.env.DB;
  await ensureSchemesSeeded(db);
  const schemeId = c.req.param('scheme_id');
  const farmerId = c.req.param('farmer_id');

  const scheme = (await db.prepare('SELECT * FROM government_schemes WHERE id = ?').bind(schemeId).first()) as any;
  if (!scheme) {
    throw new HTTPException(404, { message: 'Scheme not found' });
  }

  const body = await c.req.json().catch(() => null);
  const parsed = SchemeApplicationSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid application submission details' });
  }

  const appId = crypto.randomUUID();
  const estimatedSubsidy = Math.min(scheme.subsidy_amount_max || 50000, parsed.data.cattle_count * 20000);

  await db.prepare(
    `INSERT INTO scheme_applications (id, scheme_id, farmer_id, status, cattle_count, estimated_subsidy, documents_submitted, remarks)
     VALUES (?, ?, ?, 'submitted', ?, ?, ?, ?)`
  ).bind(
    appId,
    schemeId,
    farmerId,
    parsed.data.cattle_count,
    estimatedSubsidy,
    JSON.stringify(parsed.data.documents_submitted),
    parsed.data.remarks || null
  ).run();

  return c.json(
    {
      success: true,
      data: {
        application_id: appId,
        scheme_name: scheme.name,
        status: 'submitted',
        estimated_subsidy: estimatedSubsidy,
      },
      message: 'Government scheme application submitted successfully',
    },
    201
  );
});

schemesRouter.get('/schemes/applications/:farmer_id', async (c) => {
  await requireAuth(c);
  const db = c.env.DB;
  const farmerId = c.req.param('farmer_id');

  const rows = await db.prepare(
    `SELECT a.*, s.name as scheme_name, s.short_name, s.subsidy_percentage
     FROM scheme_applications a
     JOIN government_schemes s ON s.id = a.scheme_id
     WHERE a.farmer_id = ?
     ORDER BY a.created_at DESC`
  ).bind(farmerId).all();

  return c.json({
    success: true,
    data: (rows.results || []).map((r: any) => ({
      id: r.id,
      scheme_id: r.scheme_id,
      scheme_name: r.scheme_name,
      short_name: r.short_name,
      status: r.status,
      cattle_count: r.cattle_count,
      estimated_subsidy: r.estimated_subsidy,
      submitted_at: r.created_at,
    })),
    message: 'Farmer scheme applications',
  });
});
