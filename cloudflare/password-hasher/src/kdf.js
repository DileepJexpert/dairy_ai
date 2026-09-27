import { pbkdf2Async } from '@noble/hashes/pbkdf2.js';
import { sha256 } from '@noble/hashes/sha2.js';
import { bytesToHex, hexToBytes } from '@noble/hashes/utils.js';

export async function derive(password, salt) {
  if (typeof password !== 'string' || password.length < 8 || password.length > 144 ||
      typeof salt !== 'string' || !/^[0-9a-f]{32}$/.test(salt)) {
    throw new Error('Invalid derivation input');
  }
  const input = new TextEncoder().encode(password);
  try {
    // Same standard PBKDF2 parameters and output as the existing Python backend.
    return bytesToHex(await pbkdf2Async(sha256, input, hexToBytes(salt), {
      c: 600_000, dkLen: 32, asyncTick: 10,
    }));
  } finally {
    input.fill(0);
  }
}
