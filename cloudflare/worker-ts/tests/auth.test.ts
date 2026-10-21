import { describe, it, expect } from 'vitest';
import app from '../src/index.js';

describe('Auth Route Handlers', () => {
  it('POST /api/v1/auth/register-password rejects invalid phone number', async () => {
    const res = await app.request('/api/v1/auth/register-password', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        phone: '12345',
        password: 'SecurePassword@123',
      }),
    });
    expect(res.status).toBe(400);
    const data = await res.json() as { error: string };
    expect(data.error).toBe('Validation Error');
  });

  it('POST /api/v1/auth/register-password rejects demo password', async () => {
    const res = await app.request('/api/v1/auth/register-password', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        phone: '9876543210',
        password: 'Password@123',
      }),
    });
    expect(res.status).toBe(400);
  });

  it('POST /api/v1/auth/send-otp returns 503 service unavailable as per design', async () => {
    const res = await app.request('/api/v1/auth/send-otp', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        phone: '9876543210',
      }),
    });
    expect(res.status).toBe(503);
    const data = await res.json() as { message: string };
    expect(data.message).toContain('SMS OTP service is not configured');
  });

  it('POST /api/v1/auth/verify-otp returns 503 service unavailable as per design', async () => {
    const res = await app.request('/api/v1/auth/verify-otp', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        phone: '9876543210',
        otp: '123456',
      }),
    });
    expect(res.status).toBe(503);
  });
});
