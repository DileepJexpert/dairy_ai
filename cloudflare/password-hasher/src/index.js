import { DurableObject } from 'cloudflare:workers';
import { derive } from './kdf.js';

// No public route. Only the Milterra Python Worker's service binding invokes it.
export default {
  async fetch(request, env) {
    if (request.method !== 'POST' || new URL(request.url).pathname !== '/derive') {
      return new Response(null, { status: 404 });
    }
    const body = await request.text();
    if (body.length > 2048) return new Response(null, { status: 413 });
    // A fixed pool bounds namespace growth. No credentials or hashes are stored.
    const shard = crypto.getRandomValues(new Uint8Array(1))[0] % 16;
    return env.KDF.get(env.KDF.idFromName(`pool-${shard}`)).fetch(
      new Request('https://kdf.internal/derive', { method: 'POST', body }),
    );
  },
};

export class PasswordKdf extends DurableObject {
  async fetch(request) {
    try {
      const { password, salt } = await request.json();
      const digest = await derive(password, salt);
      return Response.json({ digest }, { headers: { 'Cache-Control': 'no-store' } });
    } catch {
      // Never log credential inputs or exception details.
      return new Response(null, { status: 400 });
    }
  }
}
