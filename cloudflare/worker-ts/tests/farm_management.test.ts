import path from 'node:path';
import { describe, it, expect, beforeAll } from 'vitest';
import app from '../src/index.js';
import { MockD1Database } from './helpers/mock_d1.js';
import type { Env } from '../src/types/env.js';

describe('Farm Management & Milk Collection E2E Test Suite', () => {
  let mockDb: MockD1Database;
  let testEnv: Env;
  const farmerUserId = 'farmer-user-1';
  const adminUserId = 'admin-user-1';
  let createdFarmerId = '';
  let createdCattleId = '';
  let createdCenterId = '';

  beforeAll(async () => {
    mockDb = new MockD1Database();
    const migrationsDir = path.resolve('./migrations');
    mockDb.loadMigrations(migrationsDir);

    // Seed test users in customers table
    await mockDb.exec(`
      INSERT OR REPLACE INTO customers (id, phone, full_name, role, is_active)
      VALUES ('${farmerUserId}', '9876500001', 'Ramesh Patel', 'subscriber', 1);

      INSERT OR REPLACE INTO customers (id, phone, full_name, role, is_active)
      VALUES ('${adminUserId}', '9876500002', 'Admin Supervisor', 'admin', 1);
    `);

    testEnv = {
      DB: mockDb as any,
      ENVIRONMENT: 'test',
      STOREFRONT_BASE_URL: 'https://dairyai.local',
    };
  });

  // =========================================================================
  // 1. Farmer Profile Lifecycle
  // =========================================================================

  it('POST /api/v1/farmers/me creates farmer profile', async () => {
    const res = await app.request(
      '/api/v1/farmers/me',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': farmerUserId,
        },
        body: JSON.stringify({
          name: 'Ramesh Patel',
          village: 'Mogar',
          district: 'Anand',
          state: 'Gujarat',
          language: 'gu',
          lat: 22.5645,
          lng: 72.9289,
        }),
      },
      testEnv
    );

    expect(res.status).toBe(201);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.id).toBeDefined();
    expect(data.data.name).toBe('Ramesh Patel');
    createdFarmerId = data.data.id;
  });

  it('GET /api/v1/farmers/me retrieves the authenticated farmer profile', async () => {
    const res = await app.request(
      '/api/v1/farmers/me',
      {
        headers: { 'x-test-customer-id': farmerUserId },
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.id).toBe(createdFarmerId);
    expect(data.data.village).toBe('Mogar');
    expect(data.data.district).toBe('Anand');
    expect(data.data.language).toBe('gu');
    expect(data.data.total_cattle).toBe(0);
  });

  it('PUT /api/v1/farmers/me updates farmer profile details', async () => {
    const res = await app.request(
      '/api/v1/farmers/me',
      {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': farmerUserId,
        },
        body: JSON.stringify({
          village: 'Anand Rural',
        }),
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
  });

  it('GET /api/v1/farmers/:farmer_id allows admin to view any farmer profile', async () => {
    const res = await app.request(
      `/api/v1/farmers/${createdFarmerId}`,
      {
        headers: { 'x-test-customer-id': adminUserId },
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.id).toBe(createdFarmerId);
    expect(data.data.name).toBe('Ramesh Patel');
  });

  // =========================================================================
  // 2. Cattle Lifecycle
  // =========================================================================

  it('POST /api/v1/cattle registers a new cattle and increments total_cattle counter', async () => {
    const res = await app.request(
      '/api/v1/cattle',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': farmerUserId,
        },
        body: JSON.stringify({
          tag_id: 'IN-GJ-00101',
          name: 'Gauri',
          breed: 'gir',
          sex: 'female',
          dob: '2021-03-15',
          weight_kg: 420.5,
          status: 'active',
          lactation_number: 2,
        }),
      },
      testEnv
    );

    expect(res.status).toBe(201);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.tag_id).toBe('IN-GJ-00101');
    expect(data.data.breed).toBe('gir');
    expect(data.data.lactation_number).toBe(2);
    createdCattleId = data.data.id;

    // Verify farmer profile total_cattle was updated
    const farmerRes = await app.request(
      '/api/v1/farmers/me',
      { headers: { 'x-test-customer-id': farmerUserId } },
      testEnv
    );
    const farmerData = (await farmerRes.json()) as any;
    expect(farmerData.data.total_cattle).toBe(1);
  });

  it('GET /api/v1/cattle lists cattle with breed and status filters', async () => {
    const res = await app.request(
      '/api/v1/cattle?breed=gir&status=active',
      {
        headers: { 'x-test-customer-id': farmerUserId },
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.length).toBe(1);
    expect(data.data[0].tag_id).toBe('IN-GJ-00101');
  });

  it('GET /api/v1/cattle/:id returns detailed cattle records', async () => {
    const res = await app.request(
      `/api/v1/cattle/${createdCattleId}`,
      {
        headers: { 'x-test-customer-id': farmerUserId },
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.id).toBe(createdCattleId);
    expect(data.data.name).toBe('Gauri');
  });

  it('GET /api/v1/cattle/stats/dashboard returns herd KPI summary', async () => {
    const res = await app.request(
      '/api/v1/cattle/stats/dashboard',
      {
        headers: { 'x-test-customer-id': farmerUserId },
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.total_cattle).toBe(1);
    expect(data.data.active_cattle).toBe(1);
    expect(data.data.by_breed.gir).toBe(1);
  });

  // =========================================================================
  // 3. Milk Production Records & Forecasting
  // =========================================================================

  it('POST /api/v1/cattle/:cattle_id/milk-records logs morning milk with automated quality grade', async () => {
    const today = new Date().toISOString().slice(0, 10);
    const res = await app.request(
      `/api/v1/cattle/${createdCattleId}/milk-records`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': farmerUserId,
        },
        body: JSON.stringify({
          date: today,
          session: 'morning',
          quantity_litres: 12.5,
          fat_pct: 4.8,
          snf_pct: 8.8,
          price_per_litre: 45.0,
        }),
      },
      testEnv
    );

    expect(res.status).toBe(201);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.quantity_litres).toBe(12.5);
    expect(data.data.total_amount).toBe(562.5);
    expect(data.data.quality_grade).toBe('A');
  });

  it('GET /api/v1/cattle/:cattle_id/milk-records lists cattle milk production history', async () => {
    const res = await app.request(
      `/api/v1/cattle/${createdCattleId}/milk-records?days=7`,
      {
        headers: { 'x-test-customer-id': farmerUserId },
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.length).toBeGreaterThanOrEqual(1);
    expect(data.data[0].quantity_litres).toBe(12.5);
  });

  it('GET /api/v1/farmers/me/milk-summary aggregates today and 7-day milk yield', async () => {
    const res = await app.request(
      '/api/v1/farmers/me/milk-summary',
      {
        headers: { 'x-test-customer-id': farmerUserId },
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.today.total_litres).toBe(12.5);
    expect(data.data.today.revenue).toBe(562.5);
    expect(data.data.last_7_days.total_litres).toBe(12.5);
  });

  it('GET /api/v1/farmers/me/production-forecast returns rolling 7-day projection', async () => {
    const res = await app.request(
      '/api/v1/farmers/me/production-forecast',
      {
        headers: { 'x-test-customer-id': farmerUserId },
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.forecast.length).toBe(7);
    expect(data.data.seven_day_forecast_total).toBeGreaterThan(0);
  });

  // =========================================================================
  // 4. Breeding & Calving Projection
  // =========================================================================

  it('POST /api/v1/cattle/:cattle_id/breeding records AI and projects 283-day expected calving', async () => {
    const res = await app.request(
      `/api/v1/cattle/${createdCattleId}/breeding`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': farmerUserId,
        },
        body: JSON.stringify({
          event_type: 'ai_done',
          date: '2026-10-01',
          bull_id: 'GIR-BULL-BRAHMA-09',
          ai_technician: 'Dr. V. Sharma',
          semen_batch: 'BATCH-2026-Q3-091',
          notes: 'Successful insemination at peak estrus',
        }),
      },
      testEnv
    );

    expect(res.status).toBe(201);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.event_type).toBe('ai_done');
    // 2026-10-01 + 283 days = 2027-07-11
    expect(data.data.expected_calving_date).toBe('2027-07-11');
  });

  it('GET /api/v1/farmers/me/calving-schedule lists expected calvings with days countdown', async () => {
    const res = await app.request(
      '/api/v1/farmers/me/calving-schedule',
      {
        headers: { 'x-test-customer-id': farmerUserId },
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.length).toBe(1);
    expect(data.data[0].cattle_name).toBe('Gauri');
    expect(data.data[0].expected_calving_date).toBe('2027-07-11');
    expect(data.data[0].days_remaining).toBeGreaterThan(0);
  });

  // =========================================================================
  // 5. Health Records & Vaccinations
  // =========================================================================

  it('POST /api/v1/cattle/:cattle_id/health-records logs health checkup', async () => {
    const res = await app.request(
      `/api/v1/cattle/${createdCattleId}/health-records`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': farmerUserId,
        },
        body: JSON.stringify({
          record_type: 'checkup',
          diagnosis: 'Routine postpartum checkup, cattle in excellent health',
          severity: 1,
          resolved: true,
          notes: 'Deworming bolus administered',
        }),
      },
      testEnv
    );

    expect(res.status).toBe(201);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.record_type).toBe('checkup');
  });

  it('POST /api/v1/cattle/:cattle_id/vaccinations records vaccination with due date alert', async () => {
    const res = await app.request(
      `/api/v1/cattle/${createdCattleId}/vaccinations`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': farmerUserId,
        },
        body: JSON.stringify({
          vaccine_name: 'FMD (Foot and Mouth Disease)',
          batch_number: 'FMD-IN-2026-X1',
          date_given: '2026-10-15',
          next_due_date: '2027-04-15',
          administered_by: 'Dr. V. Sharma',
        }),
      },
      testEnv
    );

    expect(res.status).toBe(201);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.vaccine_name).toBe('FMD (Foot and Mouth Disease)');
  });

  it('GET /api/v1/farmers/me/upcoming-vaccinations returns upcoming vaccination alerts', async () => {
    const res = await app.request(
      '/api/v1/farmers/me/upcoming-vaccinations?days=365',
      {
        headers: { 'x-test-customer-id': farmerUserId },
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.length).toBe(1);
    expect(data.data[0].vaccine_name).toBe('FMD (Foot and Mouth Disease)');
    expect(data.data[0].cattle_name).toBe('Gauri');
  });

  // =========================================================================
  // 6. Scientific Dairy Feed Plan
  // =========================================================================

  it('POST /api/v1/cattle/:cattle_id/feed-plan/generate calculates scientific DMI and balanced diet', async () => {
    const res = await app.request(
      `/api/v1/cattle/${createdCattleId}/feed-plan/generate`,
      {
        method: 'POST',
        headers: { 'x-test-customer-id': farmerUserId },
      },
      testEnv
    );

    expect(res.status).toBe(201);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.plan.length).toBe(4);
    expect(data.data.total_cost_per_day).toBeGreaterThan(0);
    expect(data.data.nutrition_score).toBeGreaterThanOrEqual(85);
  });

  it('GET /api/v1/cattle/:cattle_id/feed-plan/current retrieves active feed formulation', async () => {
    const res = await app.request(
      `/api/v1/cattle/${createdCattleId}/feed-plan/current`,
      {
        headers: { 'x-test-customer-id': farmerUserId },
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.plan).toBeDefined();
    expect(data.data.total_cost_per_day).toBeGreaterThan(0);
  });

  // =========================================================================
  // 7. Milk Collection Centers, Intake & Farmer Passbook
  // =========================================================================

  it('POST /api/v1/collection/centers registers a new milk collection center', async () => {
    const res = await app.request(
      '/api/v1/collection/centers',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': adminUserId,
        },
        body: JSON.stringify({
          name: 'Mogar Dairy Cooperative Center #1',
          code: 'MCC-MOGAR-01',
          village: 'Mogar',
          district: 'Anand',
          state: 'Gujarat',
          pincode: '388340',
          capacity_litres: 2500,
          chilling_temp_celsius: 3.8,
          manager_name: 'Dinesh Solanki',
          manager_phone: '9876543299',
        }),
      },
      testEnv
    );

    expect(res.status).toBe(201);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.code).toBe('MCC-MOGAR-01');
    createdCenterId = data.data.id;
  });

  it('GET /api/v1/collection/centers lists active collection centers', async () => {
    const res = await app.request('/api/v1/collection/centers?district=Anand', {}, testEnv);
    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.length).toBe(1);
    expect(data.data[0].code).toBe('MCC-MOGAR-01');
  });

  it('GET /api/v1/collection/centers/:id returns center status and capacity utilization', async () => {
    const res = await app.request(`/api/v1/collection/centers/${createdCenterId}`, {}, testEnv);
    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.name).toBe('Mogar Dairy Cooperative Center #1');
    expect(data.data.capacity_litres).toBe(2500);
    expect(data.data.capacity_utilization_pct).toBe(0);
  });

  it('POST /api/v1/collection/entries records milk intake with automated Grade A evaluation and center stock update', async () => {
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
          quantity_litres: 25.0,
          fat_pct: 4.6,
          snf_pct: 8.7,
          temperature_celsius: 4.2,
        }),
      },
      testEnv
    );

    expect(res.status).toBe(201);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.grade).toBe('A');
    expect(data.data.is_rejected).toBe(false);
    expect(data.data.quality_bonus).toBe(50); // 25L * 2.0 = 50
    expect(data.data.net_amount).toBeGreaterThan(data.data.total_amount);

    // Verify center stock incremented
    const centerRes = await app.request(`/api/v1/collection/centers/${createdCenterId}`, {}, testEnv);
    const centerData = (await centerRes.json()) as any;
    expect(centerData.data.current_stock_litres).toBe(25.0);
    expect(centerData.data.capacity_utilization_pct).toBe(1.0); // 25 / 2500 * 100 = 1.0%
  });

  it('POST /api/v1/collection/entries rejects substandard milk below regulatory threshold', async () => {
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
          shift: 'evening',
          quantity_litres: 10.0,
          fat_pct: 2.1, // Below 3.0% threshold
          snf_pct: 6.8, // Below 7.5% threshold
        }),
      },
      testEnv
    );

    expect(res.status).toBe(201);
    const data = (await res.json()) as any;
    expect(data.data.is_rejected).toBe(true);
    expect(data.data.grade).toBe('rejected');
    expect(data.data.net_amount).toBe(0);
    expect(data.data.rejection_reason).toContain('statutory threshold');

    // Verify center stock was NOT incremented for rejected milk
    const centerRes = await app.request(`/api/v1/collection/centers/${createdCenterId}`, {}, testEnv);
    const centerData = (await centerRes.json()) as any;
    expect(centerData.data.current_stock_litres).toBe(25.0);
  });

  it('GET /api/v1/collection/farmers/me/passbook returns comprehensive farmer passbook and payout ledger', async () => {
    const res = await app.request(
      '/api/v1/collection/farmers/me/passbook',
      {
        headers: { 'x-test-customer-id': farmerUserId },
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.farmer.id).toBe(createdFarmerId);
    expect(data.data.summary.total_entries).toBe(1); // 1 accepted entry
    expect(data.data.summary.total_litres).toBe(25.0);
    expect(data.data.summary.total_net_payout).toBeGreaterThan(1000);
    expect(data.data.summary.average_fat_pct).toBe(4.6);
    expect(data.data.summary.average_snf_pct).toBe(8.7);
    expect(data.data.entries.length).toBe(2); // 1 accepted + 1 rejected
  });

  // =========================================================================
  // 8. Farmer Dashboard Integration & Cattle Cleanup
  // =========================================================================

  it('GET /api/v1/farmers/me/dashboard aggregates total cattle, today milk, and health records', async () => {
    const res = await app.request(
      '/api/v1/farmers/me/dashboard',
      {
        headers: { 'x-test-customer-id': farmerUserId },
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.stats.total_cattle).toBe(1);
    expect(data.data.stats.milk_today_litres).toBe(12.5);
    expect(data.data.stats.total_health_records).toBe(1);
  });

  it('DELETE /api/v1/cattle/:id deletes cattle and decrements total_cattle counter', async () => {
    const res = await app.request(
      `/api/v1/cattle/${createdCattleId}`,
      {
        method: 'DELETE',
        headers: { 'x-test-customer-id': farmerUserId },
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);

    // Verify farmer total_cattle decremented
    const farmerRes = await app.request(
      '/api/v1/farmers/me',
      { headers: { 'x-test-customer-id': farmerUserId } },
      testEnv
    );
    const farmerData = (await farmerRes.json()) as any;
    expect(farmerData.data.total_cattle).toBe(0);
  });
});
