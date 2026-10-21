import { describe, it, expect } from 'vitest';
import { hashPassword, verifyPassword, hmacSha256 } from '../src/utils/crypto.js';

describe('Crypto Utilities - Web Crypto Native Implementation', () => {
  it('hashes and successfully verifies a customer password', async () => {
    const password = 'SecurePassword@2026';
    const hash = await hashPassword(password);

    expect(hash).toMatch(/^pbkdf2_sha256\$600000\$.+\$.+$/);

    const valid = await verifyPassword(password, hash);
    expect(valid).toBe(true);

    const wrong = await verifyPassword('WrongPassword123', hash);
    expect(wrong).toBe(false);
  });

  it('computes correct HMAC-SHA256 hex signature', async () => {
    const secret = 'test-secret-key-12345';
    const message = 'customer-session-token';
    const hex = await hmacSha256(secret, message);

    expect(hex).toHaveLength(64);
    expect(hex).toMatch(/^[0-9a-f]{64}$/);
  });
});
