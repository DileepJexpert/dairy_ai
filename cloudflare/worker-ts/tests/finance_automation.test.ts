import path from 'node:path';
import { describe, it, expect, beforeAll } from 'vitest';
import app from '../src/index.js';
import { MockD1Database } from './helpers/mock_d1.js';
import type { Env } from '../src/types/env.js';

describe('Financial & Milk Collection Automation E2E Suite', () => {
  let mockDb: MockD1Database;
  let testEnv: Env;
  const farmerUserId = 'farmer-user-fin-1';
  const adminUserId = 'admin-user-fin-1';
  let createdFarmerId = '';
  let createdCenterId = '';
  let createdEntryId = '';

  beforeAll(async () => {
    mockDb = new MockD1Database();
    const migrationsDir = path.resolve('./migrations');
    mockDb.loadMigrations(migrationsDir);

    // Seed test users in customers table
    await mockDb.exec(`
      INSERT OR REPLACE INTO customers (id, phone, full_name, role, is_active)
      VALUES ('${farmerUserId}', '9876500001', 'Ramesh Patel', 'subscriber', 1);

      INSERT OR REPLACE INTO customers (id, phone, full_name, role, is_active)
      VALUES ('${adminUserId}', '9876500002', 'BMC Supervisor', 'admin', 1);
    `);

    testEnv = {
      DB: mockDb as any,
      ENVIRONMENT: 'test',
      STOREFRONT_BASE_URL: 'https://farmers.milterrafoods.com',
    };

    // Create farmer profile
    const farmerRes = await app.request(
      '/api/v1/farmers/me',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': farmerUserId,
        },
        body: JSON.stringify({
          name: 'Ramesh Patel',
          village: 'Anand BMC Center',
          district: 'Anand',
          state: 'Gujarat',
          phone: '9876500001',
          upi_id: 'ramesh@okhdfcbank',
        }),
      },
      testEnv
    );
    const farmerData = (await farmerRes.json()) as any;
    createdFarmerId = farmerData.data.id;

    // Create BMC collection center
    const centerRes = await app.request(
      '/api/v1/collection/centers',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': adminUserId,
        },
        body: JSON.stringify({
          name: 'BMC Mogar Chilling Hub',
          code: 'BMC-MOG-01',
          village: 'Mogar',
          district: 'Anand',
          state: 'Gujarat',
          capacity_litres: 5000,
          manager_name: 'Dinesh BMC Operator',
          manager_phone: '9876543299',
        }),
      },
      testEnv
    );
    const centerData = (await centerRes.json()) as any;
    createdCenterId = centerData.data.id;
  });

  // =========================================================================
  // 1. WhatsApp Daily Milk Slips
  // =========================================================================

  it('POST /api/v1/collection/entries generates instant WhatsApp daily milk slip and credits wallet', async () => {
    const today = new Date().toISOString().slice(0, 10);
    const res = await app.request(
      '/api/v1/collection/entries',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': adminUserId,
        },
        body: JSON.stringify({
          center_id: createdCenterId,
          farmer_id: createdFarmerId,
          date: today,
          shift: 'morning',
          quantity_litres: 14.5,
          fat_pct: 4.4,
          snf_pct: 8.6,
          temperature_celsius: 4.0,
        }),
      },
      testEnv
    );

    expect(res.status).toBe(201);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.id).toBeDefined();
    createdEntryId = data.data.id;

    // Verify slip structure matches user specification:
    // "Namaste Ramesh ji! Morning collection: 14.5 Litres | Fat: 4.4% | SNF: 8.6 | Payout: ₹... credited to Milterra Wallet."
    expect(data.data.whatsapp_slip).toBeDefined();
    expect(data.data.whatsapp_slip.text).toContain('Namaste *Ramesh Patel ji*!');
    expect(data.data.whatsapp_slip.text).toContain('Morning collection: *14.5 Litres*');
    expect(data.data.whatsapp_slip.text).toContain('Fat: *4.4%*');
    expect(data.data.whatsapp_slip.text).toContain('SNF: *8.6%*');
    expect(data.data.whatsapp_slip.text).toContain('credited to Milterra Wallet');
    expect(data.data.whatsapp_slip.url).toContain('api.whatsapp.com/send');
    expect(data.data.net_amount).toBeGreaterThan(500);
  });

  it('GET /api/v1/collection/entries/:id/whatsapp-slip returns deep link and formatted message', async () => {
    const res = await app.request(`/api/v1/collection/entries/${createdEntryId}/whatsapp-slip`, {}, testEnv);
    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.slip_text).toContain('MILTERRA DAIRY COLLECTION SLIP');
    expect(data.data.whatsapp_url).toContain('whatsapp.com');
  });

  it('POST /api/v1/collection/entries/:id/share-whatsapp marks slip as dispatched', async () => {
    const res = await app.request(
      `/api/v1/collection/entries/${createdEntryId}/share-whatsapp`,
      { method: 'POST' },
      testEnv
    );
    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.sent).toBe(true);
  });

  // =========================================================================
  // 2. Milterra Wallet & 1-Click UPI Payouts
  // =========================================================================

  it('GET /api/v1/finance/wallet retrieves farmer wallet balance and collection earnings', async () => {
    const res = await app.request(
      '/api/v1/finance/wallet',
      {
        headers: { 'x-test-customer-id': farmerUserId },
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.enabled).toBe(true);
    expect(data.data.total_balance).toBeGreaterThan(500);
    expect(data.data.milk_payout_balance).toBeGreaterThan(500);
    expect(data.data.transactions.length).toBeGreaterThan(0);
    expect(data.data.current_cycle.type).toBe('10_day');
  });

  it('POST /api/v1/finance/payout/upi rejects invalid UPI ID format', async () => {
    const res = await app.request(
      '/api/v1/finance/payout/upi',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': farmerUserId,
        },
        body: JSON.stringify({
          amount: 200,
          upi_id: 'invalid-vpa-without-at',
        }),
      },
      testEnv
    );

    expect(res.status).toBe(422);
  });

  it('POST /api/v1/finance/payout/upi processes 1-click UPI instant payout with mock UTR', async () => {
    const res = await app.request(
      '/api/v1/finance/payout/upi',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': farmerUserId,
        },
        body: JSON.stringify({
          amount: 300,
          upi_id: 'ramesh@okhdfcbank',
          notes: 'Dugdhadhara withdrawal',
        }),
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.utr_number).toContain('UPI/');
    expect(data.data.amount).toBe(300);
    expect(data.data.status).toBe('success');

    // Verify wallet balance decremented
    const walletRes = await app.request(
      '/api/v1/finance/wallet',
      {
        headers: { 'x-test-customer-id': farmerUserId },
      },
      testEnv
    );
    const walletData = (await walletRes.json()) as any;
    expect(walletData.data.transactions[0].type).toBe('payouts');
    expect(walletData.data.transactions[0].title).toContain('1-Click UPI');
  });

  it('GET /api/v1/finance/cycles lists Dugdhadhara 10-day payment cycles', async () => {
    const res = await app.request('/api/v1/finance/cycles', {}, testEnv);
    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.length).toBeGreaterThanOrEqual(3);
    expect(data.data[0].cycle_type).toBe('10_day');
  });

  // =========================================================================
  // 3. Verified Milk-Backed Micro-Loans (Kisan Credit Engine)
  // =========================================================================

  it('GET /api/v1/finance/loans/kisan-credit computes 90-day milk deposit records and pre-approved limit', async () => {
    const res = await app.request(
      '/api/v1/finance/loans/kisan-credit',
      {
        headers: { 'x-test-customer-id': farmerUserId },
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.eligible).toBe(true);
    expect(data.data.pre_approved_limit).toBeGreaterThanOrEqual(15000);
    expect(data.data.interest_rate_pct).toBe(7.0);
    expect(data.data.metrics_90d.total_litres).toBeGreaterThan(0);
    expect(data.data.eligible_purposes.length).toBeGreaterThan(0);
    expect(data.data.repayment_model).toContain('10-day Dugdhadhara');
  });

  it('POST /api/v1/finance/loans/apply instantly disburses pre-approved feed credit to wallet', async () => {
    const res = await app.request(
      '/api/v1/finance/loans/apply',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': farmerUserId,
        },
        body: JSON.stringify({
          loan_type: 'feed_advance',
          principal_amount: 15000,
          tenure_months: 6,
          purpose: 'Pashu Aahar feed purchase for winter season',
        }),
      },
      testEnv
    );

    expect(res.status).toBe(201);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.status).toBe('approved');
    expect(data.data.principal_amount).toBe(15000);
    expect(data.data.emi_amount).toBeGreaterThan(0);
    expect(data.data.disbursed_to_wallet).toBe(true);

    // Verify wallet received the loan disbursement as store credit
    const walletRes = await app.request(
      '/api/v1/finance/wallet',
      {
        headers: { 'x-test-customer-id': farmerUserId },
      },
      testEnv
    );
    const walletData = (await walletRes.json()) as any;
    expect(walletData.data.store_credit_balance).toBe(15000);
    expect(walletData.data.total_balance).toBeGreaterThan(15000);
  });

  it('GET /api/v1/finance/ledger/:farmer_id returns unified ledger for mobile app', async () => {
    const res = await app.request(`/api/v1/finance/ledger/${createdFarmerId}`, {}, testEnv);
    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.farmer_id).toBe(createdFarmerId);
    expect(data.data.loans.length).toBe(1);
    expect(data.data.loans[0].loan_type).toBe('feed_advance');
  });
});
