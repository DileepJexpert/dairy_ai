import { describe, it, expect } from 'vitest';
import app from '../src/index.js';

describe('Milterra TypeScript Worker - Health Check', () => {
  it('GET / should return healthy status and service info', async () => {
    const res = await app.request('/');
    expect(res.status).toBe(200);

    const data = await res.json() as Record<string, any>;
    expect(data.service).toBe('milterra-api-ts');
    expect(data.status).toBe('healthy');
    expect(data.runtime).toBe('cloudflare-workers-v8');
  });

  it('GET /unknown-path should return 404', async () => {
    const res = await app.request('/unknown-path');
    expect(res.status).toBe(404);

    const data = await res.json() as Record<string, any>;
    expect(data.error).toBe('Not Found');
  });

  it('GET /api/v1/health/diseases should return full livestock disease directory', async () => {
    const res = await app.request('/api/v1/health/diseases');
    expect(res.status).toBe(200);

    const body = (await res.json()) as any;
    expect(body.success).toBe(true);
    expect(body.total).toBeGreaterThanOrEqual(10);
    expect(body.data[0]).toHaveProperty('id');
    expect(body.data[0]).toHaveProperty('name');
    expect(body.data[0]).toHaveProperty('hindiName');
    expect(body.data[0]).toHaveProperty('goldenHourTiming');
    expect(body.data[0]).toHaveProperty('firstAid');
    expect(body.data[0]).toHaveProperty('suggestedMedicines');
  });

  it('GET /api/v1/health/diseases with filters should return targeted diseases', async () => {
    // Filter by cow & bacterial
    const res = await app.request('/api/v1/health/diseases?animal=cow&category=bacterial');
    expect(res.status).toBe(200);
    const body = (await res.json()) as any;
    expect(body.success).toBe(true);
    expect(body.data.every((d: any) => d.animalTypes.includes('cow') && d.category === 'bacterial')).toBe(true);

    // Filter by search query (Hindi & English)
    const resSearch = await app.request('/api/v1/health/diseases?search=थनैला');
    expect(resSearch.status).toBe(200);
    const bodySearch = (await resSearch.json()) as any;
    expect(bodySearch.data.some((d: any) => d.id === 'bovine-mastitis')).toBe(true);

    // Get single disease by ID
    const resSingle = await app.request('/api/v1/health/diseases/milk-fever');
    expect(resSingle.status).toBe(200);
    const bodySingle = (await resSingle.json()) as any;
    expect(bodySingle.data.id).toBe('milk-fever');
    expect(bodySingle.data.severity).toBe('emergency');
  });
});
