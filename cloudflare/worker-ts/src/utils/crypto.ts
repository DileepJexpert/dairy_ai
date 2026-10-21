/**
 * Web Crypto PBKDF2 & HMAC utilities matching Python hashlib / Pyodide implementation,
 * with support for Cloudflare's dedicated PASSWORD_HASHER Durable Object service binding
 * to bypass Worker CPU timeout limits during 600,000-iteration PBKDF2 hashing.
 */

const ITERATIONS = 600_000;

export function bufferToUrlSafeBase64(buf: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < buf.length; i++) {
    binary += String.fromCharCode(buf[i]);
  }
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_');
}

export function urlSafeBase64ToBuffer(b64: string): Uint8Array {
  let standard = b64.replace(/-/g, '+').replace(/_/g, '/');
  while (standard.length % 4 !== 0) {
    standard += '=';
  }
  const binary = atob(standard);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

export async function hashPassword(
  password: string,
  saltBytes?: Uint8Array,
  hasher?: Fetcher
): Promise<string> {
  const salt = saltBytes || crypto.getRandomValues(new Uint8Array(16));

  if (hasher) {
    try {
      const saltHex = Array.from(salt)
        .map((b) => b.toString(16).padStart(2, '0'))
        .join('');
      const response = await hasher.fetch('https://kdf.internal/derive', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ password, salt: saltHex }),
      });
      if (response.ok) {
        const data = (await response.json()) as { digest?: string };
        if (data?.digest && data.digest.length === 64) {
          const digestBytes = new Uint8Array(
            data.digest.match(/.{1,2}/g)!.map((byte) => parseInt(byte, 16))
          );
          const saltB64 = bufferToUrlSafeBase64(salt);
          const digestB64 = bufferToUrlSafeBase64(digestBytes);
          return `pbkdf2_sha256$${ITERATIONS}$${saltB64}$${digestB64}`;
        }
      }
    } catch (err) {
      console.warn('PASSWORD_HASHER service call failed, falling back to Web Crypto:', err);
    }
  }

  // Fallback to native Web Crypto PBKDF2 (works locally in tests/Node)
  const keyMaterial = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(password),
    { name: 'PBKDF2' },
    false,
    ['deriveBits']
  );

  const derived = await crypto.subtle.deriveBits(
    {
      name: 'PBKDF2',
      salt: salt,
      iterations: ITERATIONS,
      hash: 'SHA-256',
    },
    keyMaterial,
    256
  );

  const saltB64 = bufferToUrlSafeBase64(salt);
  const digestB64 = bufferToUrlSafeBase64(new Uint8Array(derived));
  return `pbkdf2_sha256$${ITERATIONS}$${saltB64}$${digestB64}`;
}

export async function verifyPassword(
  password: string,
  encoded: string,
  hasher?: Fetcher
): Promise<boolean> {
  try {
    const parts = encoded.split('$');
    if (parts.length !== 4 || parts[0] !== 'pbkdf2_sha256' || parseInt(parts[1], 10) !== ITERATIONS) {
      return false;
    }
    const saltBytes = urlSafeBase64ToBuffer(parts[2]);
    const computed = await hashPassword(password, saltBytes, hasher);
    return computed === encoded;
  } catch (err) {
    console.error('verifyPassword error:', err);
    return false;
  }
}

export async function hmacSha256(secret: string, message: string): Promise<string> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    enc.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  const signature = await crypto.subtle.sign('HMAC', key, enc.encode(message));
  const bytes = new Uint8Array(signature);
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}
