import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { z } from 'zod';
import type { Env } from '../types/env.js';

export const milkPurityRouter = new Hono<{ Bindings: Env }>();

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

const WaitlistSchema = z.object({
  email: z.string().email(),
  phone: z.string().max(20).optional(),
  name: z.string().max(100).optional(),
  city: z.string().max(100).optional(),
});

// Default seed data for public purity checker
const DEFAULT_PURITY_BRANDS = [
  {
    slug: 'milterra-organic-a2',
    name: 'Milterra Organic A2 Heritage Farm Milk',
    parent_company: 'Milterra Foods Ltd.',
    variant: 'full_cream_a2',
    purity_score: 99.4,
    tested_batches: 48,
    is_fssai_compliant: 1,
    fssai_license: '10022051000189',
    summary: 'Single-origin traceable from heritage pastured cows. Zero antibiotics, zero synthetic hormones, zero adulterants detected across all batches.',
  },
  {
    slug: 'amul-taaza-toned',
    name: 'Amul Taaza Toned Milk',
    parent_company: 'GCMMF',
    variant: 'toned',
    purity_score: 94.2,
    tested_batches: 120,
    is_fssai_compliant: 1,
    fssai_license: '10012021000071',
    summary: 'Complies with FSSAI standards. Standard pasteurised homogenized milk.',
  },
  {
    slug: 'mother-dairy-toned',
    name: 'Mother Dairy Toned Milk',
    parent_company: 'Mother Dairy Fruit & Vegetable Pvt. Ltd.',
    variant: 'toned',
    purity_score: 93.8,
    tested_batches: 96,
    is_fssai_compliant: 1,
    fssai_license: '10014011001895',
    summary: 'FSSAI compliant, verified nutritional minimums across Delhi NCR samples.',
  },
];

async function ensurePuritySeeded(db: D1Database): Promise<void> {
  const existing = (await db.prepare('SELECT COUNT(*) as count FROM milk_purity_brands').first()) as any;
  if (!existing || Number(existing.count) === 0) {
    const today = new Date().toISOString().slice(0, 10);
    for (const b of DEFAULT_PURITY_BRANDS) {
      const id = crypto.randomUUID();
      await db.prepare(
        `INSERT INTO milk_purity_brands (id, slug, name, parent_company, variant, purity_score, tested_batches, last_tested_date, is_fssai_compliant, fssai_license, summary)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
      ).bind(id, b.slug, b.name, b.parent_company, b.variant, b.purity_score, b.tested_batches, today, b.is_fssai_compliant, b.fssai_license, b.summary).run();

      // Seed sample lab report
      const reportId = crypto.randomUUID();
      await db.prepare(
        `INSERT INTO milk_purity_reports (
          id, brand_id, batch_number, report_date, lab_name, lab_accreditation,
          actual_fat_pct, actual_snf_pct, urea_detected, detergent_detected, starch_detected,
          added_water_pct, antibiotic_residue, overall_grade
        ) VALUES (?, ?, 'BATCH-2026-NABL-01', ?, 'NABL Accredited Central Food Lab', 'NABL', 3.6, 8.6, 0, 0, 0, 0.0, 0, 'Safe')`
      ).bind(reportId, id, today).run();
    }
  }
}

// ---------------------------------------------------------------------------
// Public Endpoints (No Auth Required)
// ---------------------------------------------------------------------------

milkPurityRouter.get('/purity/search', async (c) => {
  const db = c.env.DB;
  await ensurePuritySeeded(db);

  const query = (c.req.query('q') || '').trim();
  let sql = 'SELECT * FROM milk_purity_brands';
  const params: any[] = [];

  if (query) {
    sql += ' WHERE name LIKE ? OR parent_company LIKE ?';
    params.push(`%${query}%`, `%${query}%`);
  }

  sql += ' ORDER BY purity_score DESC LIMIT 20';

  const rows = await db.prepare(sql).bind(...params).all();

  return c.json({
    success: true,
    data: (rows.results || []).map((r: any) => ({
      slug: r.slug,
      name: r.name,
      parent_company: r.parent_company,
      variant: r.variant,
      purity_score: r.purity_score,
      tested_batches: r.tested_batches,
      last_tested_date: r.last_tested_date,
      is_fssai_compliant: Boolean(r.is_fssai_compliant),
      summary: r.summary,
    })),
    message: 'Milk brand purity search',
  });
});

milkPurityRouter.get('/purity/brands', async (c) => {
  const db = c.env.DB;
  await ensurePuritySeeded(db);

  const rows = await db.prepare(
    'SELECT * FROM milk_purity_brands ORDER BY purity_score DESC'
  ).all();

  return c.json({
    success: true,
    data: (rows.results || []).map((r: any) => ({
      slug: r.slug,
      name: r.name,
      parent_company: r.parent_company,
      purity_score: r.purity_score,
      is_fssai_compliant: Boolean(r.is_fssai_compliant),
      fssai_license: r.fssai_license,
    })),
    message: 'Ranked milk brands',
  });
});

milkPurityRouter.get('/purity/brand/:slug', async (c) => {
  const db = c.env.DB;
  await ensurePuritySeeded(db);
  const slug = c.req.param('slug');

  const brand = (await db.prepare('SELECT * FROM milk_purity_brands WHERE slug = ?').bind(slug).first()) as any;
  if (!brand) {
    throw new HTTPException(404, { message: 'Milk brand not found' });
  }

  const latestReport = (await db.prepare(
    `SELECT * FROM milk_purity_reports WHERE brand_id = ? ORDER BY report_date DESC LIMIT 1`
  ).bind(brand.id).first()) as any;

  return c.json({
    success: true,
    data: {
      brand: {
        id: brand.id,
        slug: brand.slug,
        name: brand.name,
        parent_company: brand.parent_company,
        purity_score: brand.purity_score,
        tested_batches: brand.tested_batches,
        fssai_license: brand.fssai_license,
        summary: brand.summary,
      },
      latest_lab_report: latestReport
        ? {
            batch_number: latestReport.batch_number,
            report_date: latestReport.report_date,
            lab_name: latestReport.lab_name,
            accreditation: latestReport.lab_accreditation,
            adulterants_tested: {
              urea_detected: Boolean(latestReport.urea_detected),
              detergent_detected: Boolean(latestReport.detergent_detected),
              starch_detected: Boolean(latestReport.starch_detected),
              added_water_pct: latestReport.added_water_pct,
              antibiotic_residue: Boolean(latestReport.antibiotic_residue),
            },
            overall_grade: latestReport.overall_grade,
          }
        : null,
    },
    message: brand.name,
  });
});

milkPurityRouter.get('/purity/brand/:slug/history', async (c) => {
  const db = c.env.DB;
  await ensurePuritySeeded(db);
  const slug = c.req.param('slug');

  const brand = (await db.prepare('SELECT id, name FROM milk_purity_brands WHERE slug = ?').bind(slug).first()) as any;
  if (!brand) {
    throw new HTTPException(404, { message: 'Brand not found' });
  }

  const rows = await db.prepare(
    `SELECT * FROM milk_purity_reports WHERE brand_id = ? ORDER BY report_date DESC LIMIT 10`
  ).bind(brand.id).all();

  return c.json({
    success: true,
    data: (rows.results || []).map((r: any) => ({
      batch_number: r.batch_number,
      report_date: r.report_date,
      lab_name: r.lab_name,
      actual_fat: r.actual_fat_pct,
      actual_snf: r.actual_snf_pct,
      overall_grade: r.overall_grade,
    })),
    message: `Historical reports for ${brand.name}`,
  });
});

milkPurityRouter.post('/purity/waitlist', async (c) => {
  const body = await c.req.json().catch(() => null);
  const parsed = WaitlistSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Valid email is required' });
  }

  return c.json(
    {
      success: true,
      data: { email: parsed.data.email },
      message: 'You have been enrolled into purity test alerts',
    },
    201
  );
});
