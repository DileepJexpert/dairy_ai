import path from 'node:path';
import { describe, it, expect, beforeAll } from 'vitest';
import app from '../src/index.js';
import { MockD1Database } from './helpers/mock_d1.js';
import type { Env } from '../src/types/env.js';

describe('Extended Services Suite (Vets, Schemes, Mandi, Pashu Aadhaar, Purity, Outbreak, Withdrawal)', () => {
  let mockDb: MockD1Database;
  let testEnv: Env;
  const farmerUserId = 'farmer-ext-user';
  const vetUserId = 'vet-ext-user';
  const adminUserId = 'admin-ext-user';
  let testFarmerId = '';
  let testCattleId = '';
  let createdVetId = '';
  let consultationId = '';

  beforeAll(async () => {
    mockDb = new MockD1Database();
    const migrationsDir = path.resolve('./migrations');
    mockDb.loadMigrations(migrationsDir);

    // Seed test users
    await mockDb.exec(`
      INSERT OR REPLACE INTO customers (id, phone, full_name, role, is_active)
      VALUES ('${farmerUserId}', '9876500088', 'Gopal Bhai', 'subscriber', 1);

      INSERT OR REPLACE INTO customers (id, phone, full_name, role, is_active)
      VALUES ('${vetUserId}', '9876500089', 'Dr. Rajesh Verma', 'vet', 1);

      INSERT OR REPLACE INTO customers (id, phone, full_name, role, is_active)
      VALUES ('${adminUserId}', '9876500090', 'Admin Supervisor', 'admin', 1);

      INSERT OR REPLACE INTO farmers (id, user_id, name, village, district, state, total_cattle)
      VALUES ('farmer-ext-1', '${farmerUserId}', 'Gopal Bhai', 'Mogar', 'Anand', 'Gujarat', 6);

      INSERT OR REPLACE INTO cattle (id, farmer_id, tag_id, name, breed, sex, weight_kg, status)
      VALUES ('cattle-ext-1', 'farmer-ext-1', 'IN-GJ-EXT-01', 'Radha', 'gir', 'female', 430.0, 'active');
    `);

    testFarmerId = 'farmer-ext-1';
    testCattleId = 'cattle-ext-1';

    testEnv = {
      DB: mockDb as any,
      ENVIRONMENT: 'test',
      STOREFRONT_BASE_URL: 'https://dairyai.local',
    };
  });

  // =========================================================================
  // 1. Veterinarians & Consultations Workflow
  // =========================================================================

  it('POST /api/v1/vets/register registers a qualified veterinarian', async () => {
    const res = await app.request(
      '/api/v1/vets/register',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': vetUserId,
        },
        body: JSON.stringify({
          license_number: 'VET-IN-GJ-1092',
          qualification: 'B.V.Sc & A.H., M.V.Sc (Bovine Surgery)',
          specializations: ['Bovine Infertility', 'Surgery', 'Nutrition'],
          experience_years: 12,
          consultation_fee: 250.0,
          pincode: '388001',
          city: 'Anand',
          district: 'Anand',
          state: 'Gujarat',
        }),
      },
      testEnv
    );

    expect(res.status).toBe(201);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.id).toBeDefined();
    createdVetId = data.data.id;
  });

  it('GET /api/v1/vets/search finds registered vets in district', async () => {
    const res = await app.request('/api/v1/vets/search?district=Anand', {}, testEnv);
    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.length).toBeGreaterThanOrEqual(1);
    expect(data.data.some((v: any) => v.license_number === 'VET-IN-GJ-1092' || v.license_number === 'VET-GJ-2014-88')).toBe(true);
  });

  it('POST /api/v1/consultations creates a tele-consultation request', async () => {
    const res = await app.request(
      '/api/v1/consultations',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': farmerUserId,
        },
        body: JSON.stringify({
          cattle_id: testCattleId,
          consultation_type: 'video',
          symptoms: 'Cow has elevated body temperature and reduced feed intake since morning.',
          vet_id: createdVetId,
        }),
      },
      testEnv
    );

    expect(res.status).toBe(201);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.status).toBe('requested');
    consultationId = data.data.id;
  });

  it('PUT /api/v1/consultations/:id/accept allows vet to accept consultation', async () => {
    const res = await app.request(
      `/api/v1/consultations/${consultationId}/accept`,
      {
        method: 'PUT',
        headers: { 'x-test-customer-id': vetUserId },
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
  });

  it('PUT /api/v1/consultations/:id/end completes consultation with diagnosis', async () => {
    const res = await app.request(
      `/api/v1/consultations/${consultationId}/end`,
      {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': vetUserId,
        },
        body: JSON.stringify({
          vet_diagnosis: 'Mild ephemeral fever; rumen motility slightly depressed.',
          vet_notes: 'Advised rest, oral electrolytes, and antipyretic bolus for 3 days.',
        }),
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
  });

  it('POST /api/v1/consultations/:id/prescription issues a medical prescription', async () => {
    const res = await app.request(
      `/api/v1/consultations/${consultationId}/prescription`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': vetUserId,
        },
        body: JSON.stringify({
          medicines: [
            { name: 'Meloxicam + Paracetamol Bolus', dosage: '1 bolus twice daily', duration_days: 3 },
            { name: 'Rumen Supportive Yeast Bolus', dosage: '2 boluses once daily', duration_days: 4 },
          ],
          instructions: 'Administer after green fodder feeding. Keep cattle in shade.',
          follow_up_date: '2026-10-20',
        }),
      },
      testEnv
    );

    expect(res.status).toBe(201);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.medicines.length).toBe(2);
  });

  it('PUT /api/v1/consultations/:id/rate allows farmer to submit 5-star rating', async () => {
    const res = await app.request(
      `/api/v1/consultations/${consultationId}/rate`,
      {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': farmerUserId,
        },
        body: JSON.stringify({
          rating: 5,
          review: 'Very experienced vet! Gave prompt advice on video call.',
        }),
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
  });

  // =========================================================================
  // 2. Government Schemes & Subsidies Navigator
  // =========================================================================

  it('GET /api/v1/schemes returns seeded national dairy schemes', async () => {
    const res = await app.request('/api/v1/schemes', {}, testEnv);
    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.length).toBeGreaterThanOrEqual(4);
    const names = data.data.map((s: any) => s.short_name);
    expect(names).toContain('RGM');
    expect(names).toContain('AHIDF');
  });

  it('GET /api/v1/schemes/:id/eligibility/:farmer_id verifies farmer eligibility based on cattle count', async () => {
    const res = await app.request(
      `/api/v1/schemes/scheme-rgm/eligibility/${testFarmerId}`,
      {},
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    // Farmer has 6 cattle, RGM requires min 5 -> Eligible!
    expect(data.data.is_eligible).toBe(true);
    expect(data.data.estimated_subsidy).toBeGreaterThan(0);
  });

  it('POST /api/v1/schemes/:id/apply/:farmer_id submits subsidy application', async () => {
    const res = await app.request(
      `/api/v1/schemes/scheme-rgm/apply/${testFarmerId}`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': farmerUserId,
        },
        body: JSON.stringify({
          cattle_count: 6,
          documents_submitted: {
            aadhaar_verified: true,
            land_records_uploaded: true,
          },
          remarks: 'Applying for indigenous Gir breed multiplication subsidy.',
        }),
      },
      testEnv
    );

    expect(res.status).toBe(201);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.status).toBe('submitted');
  });

  // =========================================================================
  // 3. Mandi Market Prices & Trends
  // =========================================================================

  it('GET /api/v1/mandi/feed-prices returns live APMC feed commodity rates', async () => {
    const res = await app.request('/api/v1/mandi/feed-prices?district=Anand', {}, testEnv);
    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.count).toBeGreaterThanOrEqual(4);
  });

  it('GET /api/v1/mandi/cattle-prices returns market prices for dairy cattle', async () => {
    const res = await app.request('/api/v1/mandi/cattle-prices', {}, testEnv);
    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.count).toBeGreaterThanOrEqual(2);
  });

  it('GET /api/v1/mandi/feed-prices/trend returns price trend history', async () => {
    const res = await app.request('/api/v1/mandi/feed-prices/trend?commodity=Mustard', {}, testEnv);
    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.trend.length).toBeGreaterThan(0);
  });

  // =========================================================================
  // 4. Pashu Aadhaar & INAPH Tag Verification
  // =========================================================================

  it('POST /api/v1/pashu-aadhaar/register assigns 12-digit UID and ear tag', async () => {
    const res = await app.request(
      '/api/v1/pashu-aadhaar/register',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': farmerUserId,
        },
        body: JSON.stringify({
          cattle_id: testCattleId,
          pashu_aadhaar_number: '100892019482',
          ear_tag_number: 'IN-GJ-TAG-99128',
          breed_govt: 'Gir Purebred',
          color: 'Reddish Brown',
        }),
      },
      testEnv
    );

    expect(res.status).toBe(201);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.pashu_aadhaar_number).toBe('100892019482');
  });

  it('GET /api/v1/pashu-aadhaar/lookup/:uid retrieves cattle pedigree and owner info', async () => {
    const res = await app.request('/api/v1/pashu-aadhaar/lookup/100892019482', {}, testEnv);
    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.cattle_name).toBe('Radha');
    expect(data.data.farmer.name).toBe('Gopal Bhai');
  });

  // =========================================================================
  // 5. Consumer Milk Brand Purity Checker
  // =========================================================================

  it('GET /api/v1/purity/search searches brands with purity scores', async () => {
    const res = await app.request('/api/v1/purity/search?q=Milterra', {}, testEnv);
    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.length).toBeGreaterThanOrEqual(1);
    expect(data.data[0].purity_score).toBeGreaterThan(95);
  });

  it('GET /api/v1/purity/brand/:slug returns itemized NABL lab reports', async () => {
    const res = await app.request('/api/v1/purity/brand/milterra-organic-a2', {}, testEnv);
    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.brand.name).toContain('Milterra');
    expect(data.data.latest_lab_report.adulterants_tested.urea_detected).toBe(false);
    expect(data.data.latest_lab_report.adulterants_tested.detergent_detected).toBe(false);
    expect(data.data.latest_lab_report.adulterants_tested.antibiotic_residue).toBe(false);
  });

  // =========================================================================
  // 6. Outbreak Radar & Antibiotic Milk Withdrawal Calculator
  // =========================================================================

  it('POST /api/v1/outbreak/report logs disease outbreak incident', async () => {
    const res = await app.request(
      '/api/v1/outbreak/report',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': farmerUserId,
        },
        body: JSON.stringify({
          disease_name: 'Lumpy Skin Disease (LSD)',
          severity: 'high',
          affected_count: 2,
          lat: 22.5645,
          lng: 72.9289,
          village: 'Mogar',
          district: 'Anand',
          state: 'Gujarat',
          notes: 'Nodular skin lesions observed on buffaloes.',
        }),
      },
      testEnv
    );

    expect(res.status).toBe(201);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.status).toBe('reported');
  });

  it('GET /api/v1/outbreak/map returns disease cluster map data', async () => {
    const res = await app.request('/api/v1/outbreak/map?district=Anand', {}, testEnv);
    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.length).toBeGreaterThanOrEqual(1);
  });

  it('POST /api/v1/withdrawal/record calculates milk safe date after antibiotic treatment', async () => {
    const today = new Date();
    const startStr = today.toISOString().slice(0, 10);
    const end = new Date(today);
    end.setDate(end.getDate() + 2);
    const endStr = end.toISOString().slice(0, 10);
    const expectedSafe = new Date(end);
    expectedSafe.setDate(expectedSafe.getDate() + 3);
    const expectedSafeStr = expectedSafe.toISOString().slice(0, 10);

    const res = await app.request(
      '/api/v1/withdrawal/record',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': farmerUserId,
        },
        body: JSON.stringify({
          cattle_id: testCattleId,
          medicine_name: 'Ceftiofur Sodium Injection',
          active_ingredient: 'Ceftiofur',
          treatment_start_date: startStr,
          treatment_end_date: endStr,
          milk_withdrawal_days: 3,
        }),
      },
      testEnv
    );

    expect(res.status).toBe(201);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.milk_safe_date).toBe(expectedSafeStr);
  });

  it('GET /api/v1/withdrawal/active-alerts warns against selling milk during withdrawal period', async () => {
    const res = await app.request(
      '/api/v1/withdrawal/active-alerts',
      {
        headers: { 'x-test-customer-id': farmerUserId },
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.length).toBeGreaterThanOrEqual(1);
    expect(data.data[0].warning).toContain('DO NOT SELL OR CONSUME MILK');
  });

  // =========================================================================
  // 7. AI Clinical Triage & Pashu Mitra Chat Assistant
  // =========================================================================

  it('POST /api/v1/triage evaluates symptoms and returns clinical severity and recommended action', async () => {
    const res = await app.request(
      '/api/v1/triage',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': farmerUserId,
        },
        body: JSON.stringify({
          cattle_id: testCattleId,
          symptoms: 'Swollen udder with abnormal milk clots, cow is off feed and has mild fever.',
        }),
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.preliminary_diagnosis).toContain('Mastitis');
    expect(data.data.severity).toBeGreaterThanOrEqual(5);
    expect(['video_consult', 'emergency']).toContain(data.data.recommended_action);
    expect(data.data.health_record_id).toBeDefined();
  });

  it('POST /api/v1/chat/message provides AI expert guidance to dairy farmers', async () => {
    const res = await app.request(
      '/api/v1/chat/message',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': farmerUserId,
        },
        body: JSON.stringify({
          message: 'What is the recommended feed quantity for high yielding cows?',
          cattle_id: testCattleId,
        }),
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.response).toContain('Green Fodder');
    expect(data.data.response).toContain('bypass protein');
  });
});
