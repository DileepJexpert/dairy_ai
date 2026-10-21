import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import type { Env } from './types/env.js';
import { locationsRouter } from './routes/locations.js';
import { authRouter } from './routes/auth.js';
import { deliveryRouter } from './routes/delivery.js';
import { commerceRouter } from './routes/commerce.js';
import { operationsRouter } from './routes/operations.js';
import { adminRouter } from './routes/admin.js';
import { analyticsRouter } from './routes/analytics.js';
import { simulationRouter } from './routes/simulation.js';
import { farmersRouter } from './routes/farmers.js';
import { cattleRouter } from './routes/cattle.js';
import { milkRouter } from './routes/milk.js';
import { breedingRouter } from './routes/breeding.js';
import { healthRouter } from './routes/health.js';
import { feedRouter } from './routes/feed.js';
import { collectionRouter } from './routes/collection.js';
import { iotRouter } from './routes/iot.js';
import { vetRouter } from './routes/vet.js';
import { schemesRouter } from './routes/schemes.js';
import { mandiRouter } from './routes/mandi.js';
import { pashuAadhaarRouter } from './routes/pashu_aadhaar.js';
import { milkPurityRouter } from './routes/milk_purity.js';
import { outbreakRouter } from './routes/outbreak.js';
import { aiChatRouter } from './routes/ai_chat.js';
import { financeRouter } from './routes/finance.js';
import { erpRouter } from './routes/erp.js';
import { communityRouter } from './routes/community.js';

const app = new Hono<{ Bindings: Env }>();

// Global Middleware
app.use('*', logger());
app.use('*', cors({
  origin: (origin) => origin || '*',
  allowHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'x-customer-id', 'x-test-customer-id', 'x-user-id'],
  allowMethods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  exposeHeaders: ['Content-Length', 'X-Kuma-Revision'],
  maxAge: 600,
  credentials: true,
}));

// Root and Health Endpoints
app.get('/', (c) => {
  return c.json({
    service: 'milterra-api-ts',
    status: 'healthy',
    runtime: 'cloudflare-workers-v8',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
  });
});

app.get('/health', (c) => {
  return c.json({ success: true, message: 'DairyAI API is running' }, 200, {
    'Cache-Control': 'no-store',
  });
});

app.get('/ready', async (c) => {
  try {
    for (const table of [
      'customers',
      'inventory',
      'orders',
      'coupons',
      'serviceable_pincodes',
      'delivery_policy',
      'delivery_pincode_rules',
      'storefront_product_visibility',
      'farmers',
      'cattle',
      'milk_records',
      'breeding_records',
      'health_records',
      'vaccinations',
      'feed_plans',
      'collection_centers',
      'milk_collections',
      'sensor_readings',
      'sensor_anomalies',
      'iot_device_commands',
      'vets',
      'consultations',
      'government_schemes',
      'mandi_prices',
      'pashu_aadhaar_records',
      'milk_purity_brands',
      'outbreak_reports',
      'withdrawal_records',
      'farmer_wallet_ledger',
      'farmer_payout_requests',
      'farmer_payment_cycles',
      'farmer_loans',
      'farm_transactions',
      'farm_documents',
    ]) {
      await c.env.DB.prepare(`SELECT 1 FROM ${table} LIMIT 1`).first();
    }
    return c.json({ success: true, message: 'Ready' }, 200, {
      'Cache-Control': 'no-store',
    });
  } catch (err) {
    return c.json({ success: false, message: 'Database unavailable' }, 503, {
      'Cache-Control': 'no-store',
    });
  }
});

app.get('/api/v1/health', async (c) => {
  let dbStatus = 'disconnected';
  try {
    const result = await c.env.DB.prepare('SELECT 1 as ok').first();
    if (result && result.ok === 1) {
      dbStatus = 'connected';
    }
  } catch (err) {
    dbStatus = `error: ${(err as Error).message}`;
  }

  return c.json({
    status: 'healthy',
    service: 'milterra-api-ts',
    database: dbStatus,
    timestamp: new Date().toISOString(),
  });
});

// Mount Routes
app.route('/api/v1/locations', locationsRouter);
app.route('/api/v1/auth', authRouter);
app.route('/auth', authRouter);
app.route('/api/v1/delivery', deliveryRouter);
app.route('/api/v1/marketplace/orders/admin/simulator', simulationRouter);
app.route('/api/v1/orders/admin/simulator', simulationRouter);
app.route('/api/v1/marketplace', commerceRouter);
app.route('/api/v1', commerceRouter);
app.route('/api/v1/marketplace', operationsRouter);
app.route('/api/v1', operationsRouter);
app.route('/api/v1/marketplace', adminRouter);
app.route('/api/v1', adminRouter);
app.route('/', adminRouter);
app.route('/api/v1/marketplace', analyticsRouter);
app.route('/api/v1', analyticsRouter);
app.route('/analytics', analyticsRouter);
app.route('/', analyticsRouter);

// Farm Management Routes
app.route('/api/v1/farmers', farmersRouter);
app.route('/api/v1/cattle', cattleRouter);
app.route('/api/v1', milkRouter);
app.route('/api/v1/milk', milkRouter);
app.route('/api/v1', breedingRouter);
app.route('/api/v1/breeding', breedingRouter);
app.route('/api/v1/health', healthRouter);
app.route('/api/v1', healthRouter);
app.route('/api/v1', feedRouter);
app.route('/api/v1/collection', collectionRouter);
app.route('/api/v1', collectionRouter);

// IoT Smart Collar & Sensor Routes
app.route('/api/v1/iot', iotRouter);
app.route('/api/v1', iotRouter);

// Veterinarian Network & Consultations
app.route('/api/v1', vetRouter);
app.route('/api/v1/vet', vetRouter);

// Government Schemes & Subsidies
app.route('/api/v1', schemesRouter);

// Mandi Commodity Market Prices
app.route('/api/v1', mandiRouter);

// Pashu Aadhaar & INAPH Tag Identification
app.route('/api/v1', pashuAadhaarRouter);

// Consumer Milk Purity & Lab Reports
app.route('/api/v1', milkPurityRouter);
app.route('/purity', milkPurityRouter);

// Disease Outbreak Radar & Antibiotic Withdrawal
app.route('/api/v1', outbreakRouter);

// AI Clinical Triage & Pashu Mitra Chat Assistant
app.route('/api/v1', aiChatRouter);

// Financial & Milk Collection Automation (Wallet, 1-Click UPI, Kisan Credit Micro-Loans)
app.route('/api/v1/finance', financeRouter);
app.route('/api/v1/payments', financeRouter);
app.route('/payments', financeRouter);
app.route('/api/v1/marketplace/wallet', financeRouter);
app.route('/marketplace/wallet', financeRouter);

// Dairy ERP Transactions & Farm Documents
app.route('/api/v1', erpRouter);
app.route('/transactions', erpRouter);
app.route('/farm', erpRouter);

// Farmer Community Social Feed & Doctor Advisory
app.route('/api/v1', communityRouter);
app.route('/community', communityRouter);

// Parity Milk Records & Prices
app.route('/milk-records', milkRouter);
app.route('/milk-prices', milkRouter);

// Global 404 Handler
app.notFound((c) => {
  return c.json(
    {
      error: 'Not Found',
      message: `Route ${c.req.method} ${c.req.path} not found on milterra-api-ts`,
    },
    404
  );
});

// Global Error Handler
app.onError((err, c) => {
  if (err instanceof HTTPException) {
    return c.json(
      {
        error: err.message || 'HTTP Error',
        message: err.message || 'An HTTP error occurred',
      },
      err.status
    );
  }

  console.error('Unhandled Worker Exception:', err);
  return c.json(
    {
      error: 'Internal Server Error',
      message: err.message || 'An unexpected error occurred',
    },
    500
  );
});

export default app;
