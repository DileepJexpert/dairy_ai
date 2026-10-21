import { describe, it, expect } from 'vitest';
import app from '../src/index.js';

describe('Milk Delivery Route Handlers', () => {
  it('POST /api/v1/delivery/auth/login rejects wrong OTP', async () => {
    const res = await app.request('/api/v1/delivery/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        phone: '9876543210',
        otp: '999999',
        name: 'Test Milkman',
        role: 'milkman',
      }),
    });
    expect(res.status).toBe(400);
    const data = await res.json() as { message: string };
    expect(data.message).toContain('Invalid OTP');
  });

  it('POST /api/v1/delivery/societies rejects empty body with 400', async () => {
    const res = await app.request('/api/v1/delivery/societies', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    });
    expect(res.status).toBe(400);
    const data = await res.json() as { error: string };
    expect(data.error).toBe('Validation Error');
  });

  it('POST /api/v1/delivery/change-requests validates allowed request types', async () => {
    const res = await app.request('/api/v1/delivery/change-requests', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        flat_id: 'flat-123',
        type: 'invalidType',
        start_date: '2026-10-15',
        end_date: '2026-10-16',
      }),
    });
    expect(res.status).toBe(400);
  });

  it('POST /api/v1/delivery/absences validates allowed absence types', async () => {
    const res = await app.request('/api/v1/delivery/absences', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        type: 'invalidAbsence',
      }),
    });
    expect(res.status).toBe(400);
  });

  it('POST /api/v1/delivery/sync/drain validates queue items structure', async () => {
    const res = await app.request('/api/v1/delivery/sync/drain', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        items: [
          {
            op: 'invalid_op',
            collection: 'societies',
            data: {},
          },
        ],
      }),
    });
    expect(res.status).toBe(400);
  });
});
