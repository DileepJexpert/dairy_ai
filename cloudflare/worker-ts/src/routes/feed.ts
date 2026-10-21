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
