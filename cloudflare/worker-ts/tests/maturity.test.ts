import { describe, it, expect } from 'vitest';
import { Hono } from 'hono';
import { maturityRouter } from '../src/routes/maturity.js';

describe('Enterprise Maturity Suite Endpoints', () => {
  const app = new Hono();
  app.route('/api/v1', maturityRouter);

  it('POST /api/v1/slips/thermal/format formats 58mm ESC/POS slip with barcode', async () => {
    const res = await app.request('/api/v1/slips/thermal/format', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        farmer_name: 'Dileep Patel',
        shift: 'MORNING',
        quantity_litres: 10.0,
        fat_pct: 6.5,
        snf_pct: 9.0,
        rate_per_litre: 60.0,
      }),
    });

    expect(res.status).toBe(200);
    const json = await res.json() as any;
    expect(json.success).toBe(true);
    expect(json.data.total_amount).toBe(600.0);
    expect(json.data.formatted_text).toContain('MILTERRA DAIRY');
    expect(json.data.formatted_text).toContain('Dileep Patel');
    expect(json.data.escpos_hex).toBeDefined();
    expect(json.data.printer_standard).toContain('ESC/POS');
  });

  it('POST /api/v1/slips/whatsapp/format generates valid WhatsApp sharing deep link and UPI link', async () => {
    const res = await app.request('/api/v1/slips/whatsapp/format', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        farmer_name: 'Ramesh Patel',
        quantity_litres: 8.5,
        rate_per_litre: 58.5,
      }),
    });

    expect(res.status).toBe(200);
    const json = await res.json() as any;
    expect(json.success).toBe(true);
    expect(json.data.whatsapp_deep_link).toContain('https://api.whatsapp.com/send');
    expect(json.data.message_text).toContain('MILTERRA');
    expect(json.data.upi_payment_link).toContain('upi://pay');
  });

  it('GET /api/v1/breeding/heat-alerts returns active estrus detections with countdown', async () => {
    const res = await app.request('/api/v1/breeding/heat-alerts');
    expect(res.status).toBe(200);
    const json = await res.json() as any;
    expect(json.success).toBe(true);
    expect(json.total_active_alerts).toBeGreaterThan(0);
    const alert = json.alerts[0];
    expect(alert.heat_status).toBe('HEAT_DETECTED');
    expect(alert.hours_remaining).toBeGreaterThan(0);
    expect(alert.sire_recommendations.length).toBeGreaterThan(0);
    expect(alert.sire_recommendations[0].semen_type).toContain('Sexed Semen');
  });

  it('GET /api/v1/cold-chain/bmc-status returns chilling tank telemetry under 4 degrees C', async () => {
    const res = await app.request('/api/v1/cold-chain/bmc-status');
    expect(res.status).toBe(200);
    const json = await res.json() as any;
    expect(json.success).toBe(true);
    expect(json.data.current_temperature_c).toBeLessThanOrEqual(4.0);
    expect(json.data.status).toBe('OPTIMAL_CHILLED');
    expect(json.data.agitator_status).toBe('ACTIVE_NORMAL');
    expect(json.data.hourly_telemetry.length).toBeGreaterThan(0);
  });

  it('GET /api/v1/sustainability/gobardhan-credits computes dung, biogas and carbon offsets', async () => {
    const res = await app.request('/api/v1/sustainability/gobardhan-credits');
    expect(res.status).toBe(200);
    const json = await res.json() as any;
    expect(json.success).toBe(true);
    expect(json.data.daily_dung_output_kg).toBeGreaterThan(0);
    expect(json.data.carbon_mitigation.total_carbon_credits_earned).toBeGreaterThan(0);
    expect(json.data.total_monthly_circular_income_inr).toBeGreaterThan(0);
  });

  it('POST /api/v1/insurance/claims/muzzle-verify processes biometric muzzle claim verification', async () => {
    const res = await app.request('/api/v1/insurance/claims/muzzle-verify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ cattle_id: 'MIL-0842' }),
    });

    expect(res.status).toBe(200);
    const json = await res.json() as any;
    expect(json.success).toBe(true);
    expect(json.data.biometric_verification.match_confidence_pct).toBeGreaterThan(95);
    expect(json.data.claim_status).toBe('PRE_APPROVED_FOR_DISBURSAL');
    expect(json.data.disbursal_amount).toBe(75000);
  });

  it('GET /api/v1/feed/group-pools and POST /join manages community buying pools', async () => {
    const listRes = await app.request('/api/v1/feed/group-pools');
    expect(listRes.status).toBe(200);
    const listJson = await listRes.json() as any;
    expect(listJson.success).toBe(true);
    expect(listJson.pools.length).toBeGreaterThan(0);

    const joinRes = await app.request('/api/v1/feed/group-pools/join', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        pool_id: 'POOL-SILAGE-ANAND-01',
        quantity_kg: 500,
        farmer_name: 'Dileep Patel',
      }),
    });
    expect(joinRes.status).toBe(200);
    const joinJson = await joinRes.json() as any;
    expect(joinJson.success).toBe(true);
    expect(joinJson.total_saved_inr).toBeGreaterThan(0);
  });

  it('GET /api/v1/health/multi-crisis-alert returns correlated multi-emergency bovine telemetry', async () => {
    const res = await app.request('/api/v1/health/multi-crisis-alert');
    expect(res.status).toBe(200);
    const json = await res.json() as any;
    expect(json.success).toBe(true);
    expect(json.data.emergency_level).toBe('CODE_RED_CRITICAL');
    expect(json.data.vitals.temperature_c).toBe(40.8);
    expect(json.data.vitals.no_movement_minutes).toBe(125);
    expect(json.data.vitals.rumination_minutes_5h).toBe(0);
    expect(json.data.alerts.length).toBe(5);
    expect(json.data.ai_clinical_triage.diagnosis).toContain('थनैला');
  });
});
