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
});
