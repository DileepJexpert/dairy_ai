import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { z } from 'zod';
import type { Env } from '../types/env.js';
import { requireAuth } from './commerce.js';
import { getFarmerByUserId } from './farmers.js';

export const erpRouter = new Hono<{ Bindings: Env }>();

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

const TransactionCreateSchema = z.object({
  type: z.enum(['income', 'expense']),
  category: z.enum([
    'milk_sales',
    'feed_cost',
    'vet_fees',
    'medicine',
    'cattle_purchase',
    'cattle_sale',
    'equipment',
    'labour',
    'other',
  ]),
  amount: z.number().positive(),
  description: z.string().max(500).optional().nullable(),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).default(() => new Date().toISOString().slice(0, 10)),
  cattle_id: z.string().max(100).optional().nullable(),
});

const DocumentCreateSchema = z.object({
  title: z.string().min(1).max(200),
  document_type: z.enum([
    'vaccination_chart',
    'rate_card',
    'feed_plan',
    'lab_report',
    'cattle_certificate',
    'other',
  ]),
  file_url: z.string().min(1),
  file_name: z.string().max(200).optional().nullable(),
  notes: z.string().max(500).optional().nullable(),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).default(() => new Date().toISOString().slice(0, 10)),
});

// ---------------------------------------------------------------------------
// 1. Transactions List (Supports ?month=YYYY-MM, ?type=, ?category=)
// ---------------------------------------------------------------------------

erpRouter.get('/transactions', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;
  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const month = c.req.query('month');
  const type = c.req.query('type');
  const category = c.req.query('category');
  const cattleId = c.req.query('cattle_id');

  let query = `
    SELECT t.id, t.farmer_id, t.type, t.category, t.amount, t.description,
           t.date, t.cattle_id, t.created_at, c.name as cattle_name
    FROM farm_transactions t
    LEFT JOIN cattle c ON c.id = t.cattle_id
    WHERE t.farmer_id = ?
  `;
  const params: any[] = [farmer.id];

  if (month && /^\d{4}-\d{2}$/.test(month)) {
    query += ` AND strftime('%Y-%m', t.date) = ?`;
    params.push(month);
  }
  if (type) {
    query += ` AND t.type = ?`;
    params.push(type);
  }
  if (category) {
    query += ` AND t.category = ?`;
    params.push(category);
  }
  if (cattleId) {
    query += ` AND t.cattle_id = ?`;
    params.push(cattleId);
  }

  query += ` ORDER BY t.date DESC, t.created_at DESC`;

  const rows = await db.prepare(query).bind(...params).all();

  return c.json({
    success: true,
    data: (rows.results || []).map((r: any) => ({
      id: r.id,
      farmer_id: r.farmer_id,
      type: r.type,
      category: r.category,
      amount: Number(r.amount),
      description: r.description || null,
      date: r.date,
      cattle_id: r.cattle_id || null,
      cattle_name: r.cattle_name || null,
      created_at: r.created_at,
    })),
    message: 'Transactions list',
  });
});

// ---------------------------------------------------------------------------
// 2. Add Transaction
// ---------------------------------------------------------------------------

erpRouter.post('/transactions', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;
  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const body = await c.req.json().catch(() => null);
  const parsed = TransactionCreateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid transaction details' });
  }

  const id = `tx-${crypto.randomUUID()}`;
  let cattleName: string | null = null;

  if (parsed.data.cattle_id) {
    const cattleRow = (await db.prepare('SELECT name FROM cattle WHERE id = ? AND farmer_id = ?').bind(parsed.data.cattle_id, farmer.id).first()) as any;
    cattleName = cattleRow?.name || null;
  }

  await db.prepare(
    `INSERT INTO farm_transactions (id, farmer_id, type, category, amount, description, date, cattle_id)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
  ).bind(
    id,
    farmer.id,
    parsed.data.type,
    parsed.data.category,
    parsed.data.amount,
    parsed.data.description || null,
    parsed.data.date,
    parsed.data.cattle_id || null
  ).run();

  const transaction = {
    id,
    farmer_id: farmer.id,
    type: parsed.data.type,
    category: parsed.data.category,
    amount: parsed.data.amount,
    description: parsed.data.description || null,
    date: parsed.data.date,
    cattle_id: parsed.data.cattle_id || null,
    cattle_name: cattleName,
    created_at: new Date().toISOString(),
  };

  return c.json(
    {
      success: true,
      data: transaction,
      message: 'Transaction saved',
    },
    201
  );
});

// ---------------------------------------------------------------------------
// 3. Transactions Summary (P&L & Category Breakdown for Current / Selected Month)
// ---------------------------------------------------------------------------

erpRouter.get('/transactions/summary', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;
  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const targetMonth = c.req.query('month') || new Date().toISOString().slice(0, 7);

  const rows = (await db.prepare(
    `SELECT type, category, COALESCE(SUM(amount), 0) as total_amt
     FROM farm_transactions
     WHERE farmer_id = ? AND strftime('%Y-%m', date) = ?
     GROUP BY type, category`
  ).bind(farmer.id, targetMonth).all()).results || [];

  let totalIncome = 0;
  let totalExpense = 0;
  const incomeCategorySums: Record<string, number> = {};
  const expenseCategorySums: Record<string, number> = {};

  for (const r of rows as any[]) {
    const amt = Number(r.total_amt);
    if (r.type === 'income') {
      totalIncome += amt;
      incomeCategorySums[r.category] = (incomeCategorySums[r.category] || 0) + amt;
    } else {
      totalExpense += amt;
      expenseCategorySums[r.category] = (expenseCategorySums[r.category] || 0) + amt;
    }
  }

  const incomeBreakdown = Object.entries(incomeCategorySums).map(([cat, amt]) => ({
    category: cat,
    amount: Math.round(amt * 100) / 100,
    percentage: totalIncome > 0 ? Math.round((amt / totalIncome) * 1000) / 10 : 0,
  }));

  const expenseBreakdown = Object.entries(expenseCategorySums).map(([cat, amt]) => ({
    category: cat,
    amount: Math.round(amt * 100) / 100,
    percentage: totalExpense > 0 ? Math.round((amt / totalExpense) * 1000) / 10 : 0,
  }));

  return c.json({
    success: true,
    data: {
      total_income: Math.round(totalIncome * 100) / 100,
      total_expense: Math.round(totalExpense * 100) / 100,
      net_profit: Math.round((totalIncome - totalExpense) * 100) / 100,
      month: targetMonth,
      income_breakdown: incomeBreakdown,
      expense_breakdown: expenseBreakdown,
    },
    message: 'Finance summary',
  });
});

// ---------------------------------------------------------------------------
// 4. Monthly Reports (Multi-Month P&L History)
// ---------------------------------------------------------------------------

erpRouter.get('/transactions/monthly-report', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;
  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const rows = (await db.prepare(
    `SELECT strftime('%Y-%m', date) as mth,
            COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) as inc,
            COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) as exp
     FROM farm_transactions
     WHERE farmer_id = ?
     GROUP BY mth
     ORDER BY mth DESC
     LIMIT 12`
  ).bind(farmer.id).all()).results || [];

  const list = (rows as any[]).map((r) => {
    const inc = Math.round(Number(r.inc) * 100) / 100;
    const exp = Math.round(Number(r.exp) * 100) / 100;
    return {
      month: r.mth,
      income: inc,
      expense: exp,
      profit: Math.round((inc - exp) * 100) / 100,
    };
  });

  return c.json({
    success: true,
    data: list,
    message: 'Monthly reports',
  });
});

// ---------------------------------------------------------------------------
// 5. Per-Cattle Cost & Profit Analysis
// ---------------------------------------------------------------------------

erpRouter.get('/transactions/cattle-cost-analysis', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;
  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const rows = (await db.prepare(
    `SELECT c.id as cattle_id, c.name as cattle_name,
            COALESCE(SUM(CASE WHEN t.type = 'income' THEN t.amount ELSE 0 END), 0) as inc,
            COALESCE(SUM(CASE WHEN t.type = 'expense' THEN t.amount ELSE 0 END), 0) as exp
     FROM cattle c
     LEFT JOIN farm_transactions t ON t.cattle_id = c.id
     WHERE c.farmer_id = ?
     GROUP BY c.id, c.name
     ORDER BY c.name ASC`
  ).bind(farmer.id).all()).results || [];

  const list = (rows as any[]).map((r) => {
    const inc = Math.round(Number(r.inc) * 100) / 100;
    const exp = Math.round(Number(r.exp) * 100) / 100;
    return {
      cattle_id: r.cattle_id,
      cattle_name: r.cattle_name || 'Unnamed',
      total_income: inc,
      total_expense: exp,
      net_profit: Math.round((inc - exp) * 100) / 100,
    };
  });

  return c.json({
    success: true,
    data: list,
    message: 'Cattle cost analysis',
  });
});

// ---------------------------------------------------------------------------
// 6. Farm Documents & Charts (Upload, List, Delete)
// ---------------------------------------------------------------------------

erpRouter.get('/farm/documents', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;
  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const docType = c.req.query('type');
  let query = 'SELECT * FROM farm_documents WHERE farmer_id = ?';
  const params: any[] = [farmer.id];

  if (docType) {
    query += ' AND document_type = ?';
    params.push(docType);
  }

  query += ' ORDER BY date DESC, created_at DESC';

  const rows = await db.prepare(query).bind(...params).all();

  return c.json({
    success: true,
    data: rows.results || [],
    message: 'Farm documents',
  });
});

erpRouter.post('/farm/documents', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;
  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const body = await c.req.json().catch(() => null);
  const parsed = DocumentCreateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid document details' });
  }

  const id = `doc-${crypto.randomUUID()}`;

  await db.prepare(
    `INSERT INTO farm_documents (id, farmer_id, title, document_type, file_url, file_name, notes, date)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
  ).bind(
    id,
    farmer.id,
    parsed.data.title,
    parsed.data.document_type,
    parsed.data.file_url,
    parsed.data.file_name || null,
    parsed.data.notes || null,
    parsed.data.date
  ).run();

  const doc = {
    id,
    farmer_id: farmer.id,
    title: parsed.data.title,
    document_type: parsed.data.document_type,
    file_url: parsed.data.file_url,
    file_name: parsed.data.file_name || null,
    notes: parsed.data.notes || null,
    date: parsed.data.date,
    created_at: new Date().toISOString(),
  };

  return c.json(
    {
      success: true,
      data: doc,
      message: 'Document saved',
    },
    201
  );
});

erpRouter.delete('/farm/documents/:id', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;
  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const docId = c.req.param('id');
  await db.prepare('DELETE FROM farm_documents WHERE id = ? AND farmer_id = ?').bind(docId, farmer.id).run();

  return c.json({
    success: true,
    message: 'Document deleted',
  });
});
