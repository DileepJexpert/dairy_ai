import { Hono } from 'hono';
import { z } from 'zod';
import { hashPassword, verifyPassword, hmacSha256 } from '../utils/crypto.js';
import type { Env } from '../types/env.js';

export const authRouter = new Hono<{ Bindings: Env }>();

const ACCESS_SECONDS = 900; // 15 mins
const SESSION_SECONDS = 30 * 86400; // 30 days

function normalizePhone(value: string): string {
  let clean = value.trim().replace(/[\s-]/g, '');
  if (clean.startsWith('+91')) {
    clean = clean.substring(3);
  }
  return clean;
}

function getAuthSecret(env: Env): string {
  return env.AUTH_SECRET || env.JWT_SECRET || 'milterra-super-secret-auth-key-at-least-32-chars-long';
}

function generateRandomToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(36));
  let str = '';
  for (let i = 0; i < bytes.length; i++) {
    str += String.fromCharCode(bytes[i]);
  }
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

// Schemas
const RegisterSchema = z.object({
  phone: z.string().transform(normalizePhone).refine((val) => /^[6-9][0-9]{9}$/.test(val), {
    message: 'Enter a valid 10-digit Indian mobile number',
  }),
  password: z.string().min(8, 'Password must be at least 8 characters').max(72).refine((val) => val !== 'Password@123', {
    message: 'Choose a password that is not a published demo password',
  }),
  username: z
    .string()
    .transform((v) => v.trim().toLowerCase())
    .refine((v) => v === '' || /^[a-z0-9._-]{2,40}$/.test(v), {
      message: 'Username must be 2-40 characters using letters, numbers, dot, dash, or underscore',
    })
    .optional()
    .nullable(),
  email: z
    .string()
    .transform((v) => v.trim())
    .refine((v) => v === '' || /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v), {
      message: 'Enter a valid email address',
    })
    .optional()
    .nullable(),
  display_name: z.string().max(128).optional().nullable(),
});

const LoginSchema = z.object({
  identifier: z.string().min(3).max(254).optional(),
  phone: z.string().min(3).max(254).optional(),
  password: z.string().min(8).max(72),
}).refine((data) => !!(data.identifier || data.phone), {
  message: 'Identifier or phone is required',
});

const RefreshSchema = z.object({
  refresh_token: z.string().min(32).max(256),
});

const ForgotPasswordSchema = z.object({
  identifier: z.string().min(3).max(254),
});

const ResetPasswordSchema = z.object({
  token: z.string().min(16).max(128),
  new_password: z.string().min(8).max(72).refine((val) => val !== 'Password@123', {
    message: 'Choose a password that is not a published demo password',
  }),
});

const SendOtpSchema = z.object({
  phone: z.string().max(25),
});

const VerifyOtpSchema = z.object({
  phone: z.string().max(25),
  otp: z.string().min(1).max(50),
});

// POST /api/v1/auth/register-password
authRouter.post('/register-password', async (c) => {
  const body = await c.req.json().catch(() => null);
  const parsed = RegisterSchema.safeParse(body);
  if (!parsed.success) {
    const issues = parsed.error.issues;
    const firstMessage = issues[0]?.message || 'Invalid registration details';
    return c.json({ error: 'Validation Error', message: firstMessage, details: parsed.error.format() }, 400);
  }

  const { phone, password, username, email, display_name } = parsed.data;
  const secret = getAuthSecret(c.env);
  const customerId = crypto.randomUUID();
  const accessToken = generateRandomToken();
  const refreshToken = generateRandomToken();
  const accessHash = await hmacSha256(secret, accessToken);
  const refreshHash = await hmacSha256(secret, refreshToken);
  const passwordHash = await hashPassword(password, undefined, c.env.PASSWORD_HASHER);
  const now = Math.floor(Date.now() / 1000);

  try {
    await c.env.DB.batch([
      c.env.DB.prepare(
        `INSERT INTO customers(id, phone, full_name, role) VALUES (?, ?, ?, 'farmer')`
      ).bind(customerId, phone, display_name || null),
      c.env.DB.prepare(
        `INSERT INTO customer_credentials(customer_id, username, email, password_hash) VALUES (?, ?, ?, ?)`
      ).bind(customerId, username || null, email || null, passwordHash),
      c.env.DB.prepare(
        `INSERT INTO customer_sessions(id, customer_id, access_hash, refresh_hash, access_expires_at, expires_at, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)`
      ).bind(crypto.randomUUID(), customerId, accessHash, refreshHash, now + ACCESS_SECONDS, now + SESSION_SECONDS, now),
    ]);

    return c.json(
      {
        success: true,
        data: {
          access_token: accessToken,
          refresh_token: refreshToken,
          token_type: 'bearer',
          role: 'farmer',
          customer_id: customerId,
        },
        access_token: accessToken,
        refresh_token: refreshToken,
        token_type: 'bearer',
        role: 'farmer',
        customer_id: customerId,
      },
      201
    );
  } catch (err: any) {
    if (err?.message?.includes('UNIQUE constraint failed')) {
      return c.json({ error: 'Conflict', message: 'An account already uses these details. Sign in instead.' }, 409);
    }
    return c.json({ error: 'Registration failed', message: err.message }, 500);
  }
});

// POST /api/v1/auth/login-password
authRouter.post('/login-password', async (c) => {
  const body = await c.req.json().catch(() => null);
  const parsed = LoginSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: 'Invalid credentials' }, 401);
  }

  const identifier = (parsed.data.identifier || parsed.data.phone || '').trim();
  const { password } = parsed.data;
  const cleanId = identifier.toLowerCase();
  const phone = normalizePhone(cleanId);
  const secret = getAuthSecret(c.env);

  const row = await c.env.DB.prepare(
    `SELECT c.id, c.is_active, c.role, a.password_hash
     FROM customers c
     JOIN customer_credentials a ON a.customer_id = c.id
     WHERE c.phone = ? OR a.username = ? OR a.email = ?`
  )
    .bind(phone, cleanId, cleanId)
    .first<{
      id: string;
      is_active: number;
      role: string;
      password_hash: string;
    }>();

  // Protect against timing attacks with dummy hash
  const encoded = row?.password_hash || 'pbkdf2_sha256$600000$AAAAAAAAAAAAAAAAAAAAAA==$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';
  const valid = await verifyPassword(password, encoded, c.env.PASSWORD_HASHER);

  if (!valid || !row || !row.is_active) {
    return c.json({ error: 'Unauthorized', message: 'Invalid credentials' }, 401);
  }

  const accessToken = generateRandomToken();
  const refreshToken = generateRandomToken();
  const accessHash = await hmacSha256(secret, accessToken);
  const refreshHash = await hmacSha256(secret, refreshToken);
  const now = Math.floor(Date.now() / 1000);

  await c.env.DB.prepare(
    `INSERT INTO customer_sessions(id, customer_id, access_hash, refresh_hash, access_expires_at, expires_at, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`
  )
    .bind(crypto.randomUUID(), row.id, accessHash, refreshHash, now + ACCESS_SECONDS, now + SESSION_SECONDS, now)
    .run();

  return c.json({
    success: true,
    data: {
      access_token: accessToken,
      refresh_token: refreshToken,
      token_type: 'bearer',
      role: row.role || 'farmer',
      customer_id: row.id,
    },
    access_token: accessToken,
    refresh_token: refreshToken,
    token_type: 'bearer',
    role: row.role || 'farmer',
    customer_id: row.id,
  });
});

// POST /api/v1/auth/refresh
authRouter.post('/refresh', async (c) => {
  const body = await c.req.json().catch(() => null);
  const parsed = RefreshSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: 'Invalid refresh token' }, 400);
  }

  const secret = getAuthSecret(c.env);
  const refreshHash = await hmacSha256(secret, parsed.data.refresh_token);
  const now = Math.floor(Date.now() / 1000);

  const session = await c.env.DB.prepare(
    `SELECT s.id, s.customer_id, c.role
     FROM customer_sessions s
     JOIN customers c ON c.id = s.customer_id
     WHERE s.refresh_hash = ? AND s.expires_at > ? AND c.is_active = 1`
  )
    .bind(refreshHash, now)
    .first<{ id: string; customer_id: string; role: string }>();

  if (!session) {
    return c.json({ error: 'Unauthorized', message: 'Session expired or invalid' }, 401);
  }

  const newAccessToken = generateRandomToken();
  const newAccessHash = await hmacSha256(secret, newAccessToken);

  await c.env.DB.prepare(
    `UPDATE customer_sessions SET access_hash = ?, access_expires_at = ? WHERE id = ?`
  )
    .bind(newAccessHash, now + ACCESS_SECONDS, session.id)
    .run();

  return c.json({
    success: true,
    data: {
      access_token: newAccessToken,
      token_type: 'bearer',
      role: session.role || 'farmer',
    },
    access_token: newAccessToken,
    token_type: 'bearer',
    role: session.role || 'farmer',
  });
});

// GET /api/v1/auth/me
authRouter.get('/me', async (c) => {
  const authHeader = c.req.header('authorization') || '';
  if (!authHeader.startsWith('Bearer ')) {
    return c.json({ error: 'Unauthorized', message: 'Missing or invalid token' }, 401);
  }

  const token = authHeader.substring(7);
  const secret = getAuthSecret(c.env);
  const accessHash = await hmacSha256(secret, token);
  const now = Math.floor(Date.now() / 1000);

  const customer = await c.env.DB.prepare(
    `SELECT c.id, c.phone, c.full_name, c.role, a.username, a.email
     FROM customer_sessions s
     JOIN customers c ON c.id = s.customer_id
     LEFT JOIN customer_credentials a ON a.customer_id = c.id
     WHERE s.access_hash = ? AND s.access_expires_at > ? AND c.is_active = 1`
  )
    .bind(accessHash, now)
    .first<{
      id: string;
      phone: string;
      full_name: string | null;
      role: string;
      username: string | null;
      email: string | null;
    }>();

  if (!customer) {
    return c.json({ error: 'Unauthorized', message: 'Session expired' }, 401);
  }

  return c.json({
    success: true,
    data: {
      id: customer.id,
      phone: customer.phone,
      name: customer.full_name,
      role: customer.role,
      username: customer.username,
      email: customer.email,
    },
    id: customer.id,
    phone: customer.phone,
    name: customer.full_name,
    role: customer.role,
    username: customer.username,
    email: customer.email,
  });
});

// POST /api/v1/auth/logout
authRouter.post('/logout', async (c) => {
  const secret = getAuthSecret(c.env);
  const authHeader = c.req.header('authorization') || '';
  if (authHeader.startsWith('Bearer ')) {
    const token = authHeader.substring(7);
    const accessHash = await hmacSha256(secret, token);
    await c.env.DB.prepare(`DELETE FROM customer_sessions WHERE access_hash = ?`)
      .bind(accessHash)
      .run();
  }

  const body = await c.req.json().catch(() => null);
  if (body && typeof body.refresh_token === 'string') {
    const refreshHash = await hmacSha256(secret, body.refresh_token);
    await c.env.DB.prepare(`DELETE FROM customer_sessions WHERE refresh_hash = ?`)
      .bind(refreshHash)
      .run();
  }

  return c.json({ success: true, message: 'Logged out successfully' });
});

// POST /api/v1/auth/forgot-password
authRouter.post('/forgot-password', async (c) => {
  const body = await c.req.json().catch(() => null);
  const parsed = ForgotPasswordSchema.safeParse(body);
  if (!parsed.success) {
    const issues = parsed.error.issues;
    const firstMessage = issues[0]?.message || 'Invalid registration details';
    return c.json({ error: 'Validation Error', message: firstMessage, details: parsed.error.format() }, 400);
  }

  const identifier = parsed.data.identifier.trim().toLowerCase();
  const phone = normalizePhone(identifier);

  const row = await c.env.DB.prepare(
    `SELECT c.id, c.phone, c.is_active, a.email FROM customers c
     JOIN customer_credentials a ON a.customer_id = c.id
     WHERE c.phone = ? OR a.username = ? OR a.email = ?`
  )
    .bind(phone, identifier, identifier)
    .first<{ id: string; phone: string; is_active: number; email: string | null }>();

  if (!row || !row.is_active) {
    return c.json({ error: 'Not Found', message: 'No registered account found matching that phone, username, or email.' }, 404);
  }

  const token = generateRandomToken();
  const secret = getAuthSecret(c.env);
  const tokenHash = await hmacSha256(secret, token);
  const now = Math.floor(Date.now() / 1000);

  await c.env.DB.prepare(
    `INSERT INTO customer_password_resets(token_hash, customer_id, expires_at, created_at)
     VALUES (?, ?, ?, ?)`
  )
    .bind(tokenHash, row.id, now + 900, now)
    .run();

  const storefrontUrl = c.env.STOREFRONT_BASE_URL || 'https://milterrafoods.com';
  const resetUrl = `${storefrontUrl.replace(/\/+$/, '')}/#/reset-password?token=${token}`;

  return c.json({
    success: true,
    message: 'Password reset token generated successfully.',
    data: {
      reset_token: token,
      reset_url: resetUrl,
      email_sent: false,
    },
  });
});

// POST /api/v1/auth/reset-password
authRouter.post('/reset-password', async (c) => {
  const body = await c.req.json().catch(() => null);
  const parsed = ResetPasswordSchema.safeParse(body);
  if (!parsed.success) {
    const issues = parsed.error.issues;
    const firstMessage = issues[0]?.message || 'Invalid registration details';
    return c.json({ error: 'Validation Error', message: firstMessage, details: parsed.error.format() }, 400);
  }

  const now = Math.floor(Date.now() / 1000);
  const secret = getAuthSecret(c.env);
  const tokenHash = await hmacSha256(secret, parsed.data.token);

  const resetRow = await c.env.DB.prepare(
    `SELECT customer_id FROM customer_password_resets WHERE token_hash = ? AND expires_at > ?`
  )
    .bind(tokenHash, now)
    .first<{ customer_id: string }>();

  if (!resetRow) {
    return c.json({ error: 'Bad Request', message: 'Reset link is invalid or expired' }, 400);
  }

  const encodedPassword = await hashPassword(parsed.data.new_password, undefined, c.env.PASSWORD_HASHER);

  await c.env.DB.batch([
    c.env.DB.prepare(`UPDATE customer_credentials SET password_hash = ? WHERE customer_id = ?`).bind(encodedPassword, resetRow.customer_id),
    c.env.DB.prepare(`DELETE FROM customer_password_resets WHERE customer_id = ?`).bind(resetRow.customer_id),
    c.env.DB.prepare(`DELETE FROM customer_sessions WHERE customer_id = ?`).bind(resetRow.customer_id),
  ]);

  return c.json({ success: true, data: {}, message: 'Password updated successfully' });
});

// POST /api/v1/auth/send-otp
authRouter.post('/send-otp', async (c) => {
  return c.json({ error: 'Service Unavailable', message: 'SMS OTP service is not configured. Please sign in with password.' }, 503);
});

// POST /api/v1/auth/verify-otp
authRouter.post('/verify-otp', async (c) => {
  return c.json({ error: 'Service Unavailable', message: 'SMS OTP service is not configured. Please sign in with password.' }, 503);
});
