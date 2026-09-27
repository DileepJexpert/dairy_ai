import { test } from 'node:test';
import assert from 'node:assert/strict';
import { pbkdf2Sync } from 'node:crypto';
import { derive } from './src/kdf.js';

for (const password of ['test-password-one', 'unicode-\u0917\u093e\u092f-\ud83d\udd10']) {
  test(`matches native PBKDF2 for ${password.startsWith('unicode') ? 'Unicode' : 'ASCII'}`, async () => {
    const salt = '00112233445566778899aabbccddeeff';
    const expected = pbkdf2Sync(password, Buffer.from(salt, 'hex'), 600000, 32, 'sha256').toString('hex');
    assert.equal(await derive(password, salt), expected);
  });
}
test('rejects malformed and oversized requests', async () => {
  await assert.rejects(derive('short', '00'.repeat(16)));
  await assert.rejects(derive('valid-password', 'invalid'));
  await assert.rejects(derive('x'.repeat(145), '00'.repeat(16)));
});
