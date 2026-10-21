import { describe, it, expect } from 'vitest';
import app from '../src/index.js';

describe('Locations Route Handlers', () => {
  it('GET /api/v1/locations/states returns all Indian states', async () => {
    const res = await app.request('/api/v1/locations/states');
    expect(res.status).toBe(200);

    const data = await res.json() as { states: string[]; count: number; snapshot_date: string };
    expect(Array.isArray(data.states)).toBe(true);
    expect(data.count).toBeGreaterThan(25);
    expect(data.states).toContain('Maharashtra');
    expect(data.states).toContain('Karnataka');
  });

  it('GET /api/v1/locations/districts/:state returns districts for valid state', async () => {
    const res = await app.request('/api/v1/locations/districts/Maharashtra');
    expect(res.status).toBe(200);

    const data = await res.json() as { state: string; districts: string[]; count: number };
    expect(data.state).toBe('Maharashtra');
    expect(data.districts).toContain('Pune');
    expect(data.districts).toContain('Mumbai');
    expect(data.districts).toContain('Mumbai Suburban');
  });

  it('GET /api/v1/locations/districts/:state returns 404 for unknown state', async () => {
    const res = await app.request('/api/v1/locations/districts/Atlantis');
    expect(res.status).toBe(404);
  });

  it('GET /api/v1/locations/serviceability/:pincode handles invalid pincode format', async () => {
    const res = await app.request('/api/v1/locations/serviceability/invalid-pin');
    expect(res.status).toBe(200);

    const data = await res.json() as { is_serviceable: boolean; message: string };
    expect(data.is_serviceable).toBe(false);
    expect(data.message).toContain('Invalid 6-digit Indian PIN code format');
  });
});
