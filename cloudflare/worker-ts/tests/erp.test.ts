import path from 'node:path';
import { describe, it, expect, beforeAll } from 'vitest';
import app from '../src/index.js';
import { MockD1Database } from './helpers/mock_d1.js';
import type { Env } from '../src/types/env.js';

describe('Multi-Tenant Dairy ERP, Auto-Provisioning & Documents Suite', () => {
  let mockDb: MockD1Database;
  let testEnv: Env;
  const newTenantUserId = 'cust-new-tenant-999';

  beforeAll(async () => {
    mockDb = new MockD1Database();
    const migrationsDir = path.resolve('./migrations');
    mockDb.loadMigrations(migrationsDir);

    testEnv = {
      DB: mockDb as any,
      ENVIRONMENT: 'test',
      STOREFRONT_BASE_URL: 'https://farmers.milterrafoods.com',
    };

    // Seed a newly registered customer who does NOT yet have a farmer profile
    await mockDb.exec(`
      INSERT OR REPLACE INTO customers (id, phone, full_name, role, is_active)
      VALUES ('${newTenantUserId}', '9876599999', 'Vikram Singh', 'subscriber', 1);
    `);
  });

  // ---------------------------------------------------------------------------
  // 1. Multi-Tenant Auto-Provisioning
  // ---------------------------------------------------------------------------

  it('automatically provisions an isolated tenant farm profile on first authenticated access', async () => {
    // New user with no pre-existing farmer record
    const res = await app.request(
      '/api/v1/farmers/me',
      {
        method: 'GET',
        headers: {
          'x-test-customer-id': newTenantUserId,
        },
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const body = (await res.json()) as any;
    expect(body.success).toBe(true);
    expect(body.data.user_id).toBe(newTenantUserId);
    expect(body.data.name).toBeDefined();
    expect(body.data.id).toMatch(/^farmer-/);
  });

  // ---------------------------------------------------------------------------
  // 2. Seeded Dummy User Verification
  // ---------------------------------------------------------------------------

  it('has seeded dummy users with isolated herds and initial records', async () => {
    // Ramesh Patel (Farmer 1)
    const res = await app.request(
      '/api/v1/cattle',
      {
        method: 'GET',
        headers: {
          'x-test-customer-id': 'cust-farmer-ramesh',
        },
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const body = (await res.json()) as any;
    expect(body.success).toBe(true);
    expect(body.data.length).toBeGreaterThanOrEqual(3);
    const names = body.data.map((c: any) => c.name);
    expect(names).toContain('Ganga');
    expect(names).toContain('Yamuna');
    expect(names).toContain('Kaveri');
  });

  it('keeps tenants completely isolated from each other', async () => {
    // Suresh Kumar (Farmer 2) should only see his own cattle, not Ramesh's
    const res = await app.request(
      '/api/v1/cattle',
      {
        method: 'GET',
        headers: {
          'x-test-customer-id': 'cust-farmer-suresh',
        },
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const body = (await res.json()) as any;
    expect(body.success).toBe(true);
    expect(body.data.length).toBeGreaterThanOrEqual(1);
    expect(body.data[0].name).toBe('Lakshmi');
  });

  // ---------------------------------------------------------------------------
  // 3. Dairy ERP Transactions & Daily Expenses
  // ---------------------------------------------------------------------------

  it('allows logging daily farm expenses (feed, vet, labour)', async () => {
    const res = await app.request(
      '/api/v1/transactions',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': 'cust-farmer-suresh',
        },
        body: JSON.stringify({
          type: 'expense',
          category: 'feed_cost',
          amount: 1500,
          description: 'Dry fodder and wheat bran purchase',
          date: '2026-10-19',
        }),
      },
      testEnv
    );

    expect(res.status).toBe(201);
    const body = (await res.json()) as any;
    expect(body.success).toBe(true);
    expect(body.data.amount).toBe(1500);
    expect(body.data.category).toBe('feed_cost');
    expect(body.data.type).toBe('expense');
  });

  it('retrieves transaction summary with P&L and category breakdown', async () => {
    const res = await app.request(
      '/api/v1/transactions/summary?month=2026-10',
      {
        method: 'GET',
        headers: {
          'x-test-customer-id': 'cust-farmer-ramesh',
        },
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const body = (await res.json()) as any;
    expect(body.success).toBe(true);
    expect(body.data.total_income).toBeGreaterThan(0);
    expect(body.data.total_expense).toBeGreaterThan(0);
    expect(body.data.net_profit).toBeCloseTo(body.data.total_income - body.data.total_expense, 1);
    expect(body.data.expense_breakdown.length).toBeGreaterThan(0);
  });

  it('provides monthly report and per-cattle cost analysis', async () => {
    const mRes = await app.request(
      '/api/v1/transactions/monthly-report',
      {
        method: 'GET',
        headers: {
          'x-test-customer-id': 'cust-farmer-ramesh',
        },
      },
      testEnv
    );
    expect(mRes.status).toBe(200);
    const mBody = (await mRes.json()) as any;
    expect(mBody.success).toBe(true);
    expect(mBody.data.length).toBeGreaterThan(0);

    const cRes = await app.request(
      '/api/v1/transactions/cattle-cost-analysis',
      {
        method: 'GET',
        headers: {
          'x-test-customer-id': 'cust-farmer-ramesh',
        },
      },
      testEnv
    );
    expect(cRes.status).toBe(200);
    const cBody = (await cRes.json()) as any;
    expect(cBody.success).toBe(true);
    expect(cBody.data.length).toBeGreaterThanOrEqual(3);
  });

  // ---------------------------------------------------------------------------
  // 4. Farm Documents & Charts Upload
  // ---------------------------------------------------------------------------

  it('allows farmers to upload and retrieve charts and documents', async () => {
    // 1. Upload a vaccination chart
    const uploadRes = await app.request(
      '/api/v1/farm/documents',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': 'cust-farmer-suresh',
        },
        body: JSON.stringify({
          title: 'Karnal District Milk Rate Card 2026',
          document_type: 'rate_card',
          file_url: 'https://cdn.milterra.example/rate_card_karnal.pdf',
          file_name: 'RateCard_2026.pdf',
          notes: 'Standard fat 4.0% rate is ₹41.50',
          date: '2026-10-15',
        }),
      },
      testEnv
    );

    expect(uploadRes.status).toBe(201);
    const uploadBody = (await uploadRes.json()) as any;
    expect(uploadBody.success).toBe(true);
    expect(uploadBody.data.title).toBe('Karnal District Milk Rate Card 2026');

    // 2. List documents
    const listRes = await app.request(
      '/api/v1/farm/documents',
      {
        method: 'GET',
        headers: {
          'x-test-customer-id': 'cust-farmer-suresh',
        },
      },
      testEnv
    );

    expect(listRes.status).toBe(200);
    const listBody = (await listRes.json()) as any;
    expect(listBody.success).toBe(true);
    expect(listBody.data.length).toBeGreaterThanOrEqual(1);
    expect(listBody.data[0].title).toBe('Karnal District Milk Rate Card 2026');
  });

  // ---------------------------------------------------------------------------
  // 5. Milk Production Records & Summary Parity
  // ---------------------------------------------------------------------------

  it('records daily milk sales and aggregates summary correctly', async () => {
    const postRes = await app.request(
      '/api/v1/milk-records',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': 'cust-farmer-ramesh',
        },
        body: JSON.stringify({
          cattle_id: 'cattle-ramesh-1',
          date: '2026-10-20',
          session: 'morning',
          quantity_litres: 12.5,
          fat_pct: 4.4,
          snf_pct: 8.6,
          buyer_name: 'Amul Dairy Coop',
          price_per_litre: 44.0,
        }),
      },
      testEnv
    );

    expect(postRes.status).toBe(201);
    const postBody = (await postRes.json()) as any;
    expect(postBody.success).toBe(true);
    expect(postBody.data.quantity_litres).toBe(12.5);

    const summaryRes = await app.request(
      '/api/v1/milk-records/summary?period=weekly',
      {
        method: 'GET',
        headers: {
          'x-test-customer-id': 'cust-farmer-ramesh',
        },
      },
      testEnv
    );

    expect(summaryRes.status).toBe(200);
    const summaryBody = (await summaryRes.json()) as any;
    expect(summaryBody.success).toBe(true);
    expect(summaryBody.data.total_litres).toBeGreaterThanOrEqual(12.5);
  });
});
