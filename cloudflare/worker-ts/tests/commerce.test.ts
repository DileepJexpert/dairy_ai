import { describe, it, expect } from 'vitest';
import app from '../src/index.js';

describe('Commerce Route Handlers', () => {
  it('GET /health returns DairyAI API running status', async () => {
    const res = await app.request('/health');
    expect(res.status).toBe(200);
    const data = await res.json() as { success: boolean; message: string };
    expect(data.success).toBe(true);
    expect(data.message).toBe('DairyAI API is running');
    expect(res.headers.get('cache-control')).toBe('no-store');
  });

  it('GET /api/v1/marketplace/orders/payment-capabilities returns capability info', async () => {
    const res = await app.request('/api/v1/marketplace/orders/payment-capabilities');
    expect(res.status).toBe(200);
    const data = await res.json() as { success: boolean; data: any };
    expect(data.success).toBe(true);
    expect(data.data.is_prelaunch_interest).toBe(false);
    expect(data.data.online_payment_available).toBe(false);
  });

  it('POST /api/v1/marketplace/cart/items rejects unauthenticated request with 401', async () => {
    const res = await app.request('/api/v1/marketplace/cart/items', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ product_id: 'prod-1', quantity: 2 }),
    });
    expect(res.status).toBe(401);
  });

  it('POST /api/v1/marketplace/checkout/quote rejects unauthenticated request with 401', async () => {
    const res = await app.request('/api/v1/marketplace/checkout/quote', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ delivery_address_id: 'addr-1', payment_method: 'cod' }),
    });
    expect(res.status).toBe(401);
  });

  it('POST /api/v1/marketplace/checkout rejects unauthenticated request with 401', async () => {
    const res = await app.request('/api/v1/marketplace/checkout', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        idempotency_key: 'idem-12345678',
        delivery_address_id: 'addr-1',
        payment_method: 'cod',
      }),
    });
    expect(res.status).toBe(401);
  });

  it('GET /api/v1/marketplace/pincode/check returns unserviceable for invalid pincode', async () => {
    const res = await app.request('/api/v1/marketplace/pincode/check?pincode=000000');
    expect(res.status).toBe(200);
    const data = await res.json() as { is_serviceable: boolean; message: string };
    expect(data.is_serviceable).toBe(false);
  });
});
