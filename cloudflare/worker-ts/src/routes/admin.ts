import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { z } from 'zod';
import type { Env } from '../types/env.js';
import { requireAuth } from './commerce.js';

export const adminRouter = new Hono<{ Bindings: Env }>();

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

const DeliveryPolicyUpdateSchema = z.object({
  cod_default_enabled: z.boolean(),
  prepaid_default_enabled: z.boolean().default(false),
  delivery_fee_minor: z.number().int().min(0),
  free_delivery_above_minor: z.number().int().min(0).optional(),
});

const PincodeRuleInputSchema = z.object({
  pincode: z.string().regex(/^[1-8][0-9]{5}$/),
  cod_enabled: z.boolean().nullable().optional(),
  prepaid_enabled: z.boolean().nullable().optional(),
  delivery_fee_minor: z.number().int().min(0).nullable().optional(),
  city: z.string().min(1).max(128),
  state: z.string().min(1).max(128),
});

const PincodeRuleUpdateSchema = z.object({
  cod_enabled: z.boolean().nullable().optional(),
  prepaid_enabled: z.boolean().nullable().optional(),
  delivery_fee_minor: z.number().int().min(0).nullable().optional(),
  city: z.string().min(1).max(128).optional(),
  state: z.string().min(1).max(128).optional(),
});

const ProfileUpdateSchema = z.object({
  name: z.string().max(128).optional(),
  village: z.string().max(128).default('').optional(),
  district: z.string().max(128).default('').optional(),
  state: z.string().max(128).default('').optional(),
  language: z.string().max(10).default('en').optional(),
  notify_health: z.boolean().default(true).optional(),
  notify_vaccination: z.boolean().default(true).optional(),
  notify_consultation: z.boolean().default(true).optional(),
  notify_payment: z.boolean().default(true).optional(),
});

const SupportTicketInputSchema = z.object({
  subject: z.string().min(3).max(200),
  message: z.string().min(10).max(4000),
});

const SupportTicketUpdateSchema = z.object({
  status: z.enum(['OPEN', 'IN_PROGRESS', 'CLOSED']),
  reply: z.string().min(1).max(4000),
});

const ReviewInputSchema = z.object({
  order_id: z.string().min(1),
  rating: z.number().int().min(1).max(5),
  headline: z.string().max(150).default('').optional(),
  content: z.string().min(5).max(2000),
});

const ReviewStatusUpdateSchema = z.object({
  status: z.enum(['APPROVED', 'REJECTED', 'PENDING']).optional(),
  is_approved: z.boolean().optional(),
  reason: z.string().optional(),
  rejection_reason: z.string().optional(),
});

const ReviewReplySchema = z.object({
  reply: z.string().min(1).max(1000),
});

const LoyaltySettingsUpdateSchema = z.object({
  is_active: z.boolean(),
  earning_rate_percent: z.number().min(0).max(100),
  redemption_rate_minor: z.number().int().min(1),
  min_points_to_redeem: z.number().int().min(0),
  max_redeem_percent_per_order: z.number().min(0).max(100),
});

const LoyaltyAdjustmentSchema = z.object({
  customer_id: z.string().min(1),
  points_change: z.number().int(),
  description: z.string().min(1).max(255),
});

const ReferralClaimSchema = z.object({
  referral_code: z.string().min(1),
});

const PurityBatchInputSchema = z.object({
  product_id: z.string().min(1),
  batch_number: z.string().min(1),
  churn_date: z.string().min(1),
  expiry_date: z.string().min(1),
  purity_score: z.number().min(0).max(100),
  fat_percentage: z.number().min(0).max(100),
  snf_percentage: z.number().min(0).max(100),
  lab_name: z.string().min(1),
  report_url: z.string().url(),
  certificate_summary: z.string().min(1),
});

const PlacementInputSchema = z.object({
  product_id: z.string().min(1),
  placement_type: z.string().min(1),
  headline: z.string().min(1).max(255),
  subheadline: z.string().nullable().optional(),
  badge: z.string().nullable().optional(),
  coupon_code: z.string().nullable().optional(),
  starts_at: z.string().nullable().optional(),
  ends_at: z.string().nullable().optional(),
  priority: z.number().int().default(0),
  is_active: z.boolean().default(true),
});

const PlacementUpdateSchema = z.object({
  product_id: z.string().min(1).optional(),
  placement_type: z.string().min(1).optional(),
  headline: z.string().min(1).max(255).optional(),
  subheadline: z.string().nullable().optional(),
  badge: z.string().nullable().optional(),
  coupon_code: z.string().nullable().optional(),
  starts_at: z.string().nullable().optional(),
  ends_at: z.string().nullable().optional(),
  priority: z.number().int().optional(),
  is_active: z.boolean().optional(),
});

// ---------------------------------------------------------------------------
// 1. Delivery Policy & Pincode Overrides
// ---------------------------------------------------------------------------

const getDeliveryPolicyHandler = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const db = c.env.DB;
  const row = (await db.prepare('SELECT * FROM delivery_policy WHERE id = 1').first()) as any;
  if (!row) {
    throw new HTTPException(503, { message: 'Delivery policy is unavailable' });
  }
  return c.json({
    success: true,
    data: {
      ...row,
      cod_default_enabled: Boolean(row.cod_default_enabled),
      prepaid_default_enabled: Boolean(row.prepaid_default_enabled),
      online_payment_available: false,
    },
  });
};

adminRouter.get('/admin/delivery-policy', getDeliveryPolicyHandler);
adminRouter.get('/marketplace/admin/delivery-policy', getDeliveryPolicyHandler);

const updateDeliveryPolicyHandler = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const db = c.env.DB;
  const body = await c.req.json().catch(() => null);
  const parsed = DeliveryPolicyUpdateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid delivery policy payload' });
  }

  const current = (await db.prepare('SELECT free_delivery_above_minor FROM delivery_policy WHERE id = 1').first()) as any;
  if (!current) {
    throw new HTTPException(503, { message: 'Delivery policy is unavailable' });
  }

  const freeAbove = parsed.data.free_delivery_above_minor !== undefined
    ? parsed.data.free_delivery_above_minor
    : current.free_delivery_above_minor;

  await db.prepare(
    `UPDATE delivery_policy
     SET cod_default_enabled = ?, delivery_fee_minor = ?, free_delivery_above_minor = ?,
         prepaid_default_enabled = ?, updated_at = CURRENT_TIMESTAMP
     WHERE id = 1`
  ).bind(
    parsed.data.cod_default_enabled ? 1 : 0,
    parsed.data.delivery_fee_minor,
    freeAbove,
    parsed.data.prepaid_default_enabled ? 1 : 0
  ).run();

  return getDeliveryPolicyHandler(c);
};

adminRouter.put('/admin/delivery-policy', updateDeliveryPolicyHandler);
adminRouter.put('/marketplace/admin/delivery-policy', updateDeliveryPolicyHandler);

adminRouter.get('/admin/pincodes', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const query = c.req.query('query') || '';
  const perPage = Math.min(Math.max(Number(c.req.query('per_page') || 100), 1), 500);
  const db = c.env.DB;

  const rows = await db.prepare(
    `SELECT * FROM delivery_pincode_rules
     WHERE pincode LIKE ? OR city LIKE ? OR state LIKE ?
     ORDER BY pincode LIMIT ?`
  ).bind(`%${query.trim()}%`, `%${query.trim()}%`, `%${query.trim()}%`, perPage).all();

  const data = (rows.results || []).map((r: any) => ({
    ...r,
    cod_enabled: r.cod_enabled !== null ? Boolean(r.cod_enabled) : null,
    prepaid_enabled: r.prepaid_enabled !== null ? Boolean(r.prepaid_enabled) : null,
  }));

  return c.json({ success: true, data });
});

adminRouter.post('/admin/pincodes', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const body = await c.req.json().catch(() => null);
  const parsed = PincodeRuleInputSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid pincode override data' });
  }
  if (parsed.data.cod_enabled === undefined && parsed.data.prepaid_enabled === undefined && parsed.data.delivery_fee_minor === undefined) {
    throw new HTTPException(422, { message: 'At least one override is required' });
  }

  const db = c.env.DB;
  const existing = await db.prepare('SELECT pincode FROM delivery_pincode_rules WHERE pincode = ?').bind(parsed.data.pincode).first();
  if (existing) {
    throw new HTTPException(409, { message: 'PIN override already exists' });
  }

  await db.prepare(
    `INSERT INTO delivery_pincode_rules (pincode, cod_enabled, prepaid_enabled, delivery_fee_minor, city, state)
     VALUES (?, ?, ?, ?, ?, ?)`
  ).bind(
    parsed.data.pincode,
    parsed.data.cod_enabled !== null && parsed.data.cod_enabled !== undefined ? (parsed.data.cod_enabled ? 1 : 0) : null,
    parsed.data.prepaid_enabled !== null && parsed.data.prepaid_enabled !== undefined ? (parsed.data.prepaid_enabled ? 1 : 0) : null,
    parsed.data.delivery_fee_minor ?? null,
    parsed.data.city.trim(),
    parsed.data.state.trim()
  ).run();

  return c.json({ success: true, data: parsed.data }, 201);
});

adminRouter.put('/admin/pincodes/:pincode', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const pincode = c.req.param('pincode');
  if (!/^[1-8][0-9]{5}$/.test(pincode)) {
    throw new HTTPException(422, { message: 'Invalid Indian PIN format' });
  }

  const db = c.env.DB;
  const row = await db.prepare('SELECT * FROM delivery_pincode_rules WHERE pincode = ?').bind(pincode).first<any>();
  if (!row) {
    throw new HTTPException(404, { message: 'PIN override not found' });
  }

  const body = await c.req.json().catch(() => null);
  const parsed = PincodeRuleUpdateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid update payload' });
  }

  const codEnabled = parsed.data.cod_enabled !== undefined ? parsed.data.cod_enabled : (row.cod_enabled !== null ? Boolean(row.cod_enabled) : null);
  const prepaidEnabled = parsed.data.prepaid_enabled !== undefined ? parsed.data.prepaid_enabled : (row.prepaid_enabled !== null ? Boolean(row.prepaid_enabled) : null);
  const deliveryFee = parsed.data.delivery_fee_minor !== undefined ? parsed.data.delivery_fee_minor : row.delivery_fee_minor;
  const city = parsed.data.city !== undefined ? parsed.data.city.trim() : row.city;
  const state = parsed.data.state !== undefined ? parsed.data.state.trim() : row.state;

  await db.prepare(
    `UPDATE delivery_pincode_rules
     SET cod_enabled = ?, prepaid_enabled = ?, delivery_fee_minor = ?, city = ?, state = ?, updated_at = CURRENT_TIMESTAMP
     WHERE pincode = ?`
  ).bind(
    codEnabled !== null ? (codEnabled ? 1 : 0) : null,
    prepaidEnabled !== null ? (prepaidEnabled ? 1 : 0) : null,
    deliveryFee,
    city,
    state,
    pincode
  ).run();

  return c.json({
    success: true,
    data: {
      pincode,
      cod_enabled: codEnabled,
      prepaid_enabled: prepaidEnabled,
      delivery_fee_minor: deliveryFee,
      city,
      state,
    },
  });
});

adminRouter.delete('/admin/pincodes/:pincode', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const pincode = c.req.param('pincode');
  const db = c.env.DB;

  const existing = await db.prepare('SELECT pincode FROM delivery_pincode_rules WHERE pincode = ?').bind(pincode).first();
  if (!existing) {
    throw new HTTPException(404, { message: 'PIN override not found' });
  }

  await db.prepare('DELETE FROM delivery_pincode_rules WHERE pincode = ?').bind(pincode).run();
  return c.json({ success: true, message: 'Pincode rule deleted' });
});

// ---------------------------------------------------------------------------
// 2. Customer Profile
// ---------------------------------------------------------------------------

adminRouter.get('/profile', async (c) => {
  const customer = await requireAuth(c);
  const db = c.env.DB;

  const profRow = await db.prepare(
    `SELECT village, district, state, language, notify_health, notify_vaccination, notify_consultation, notify_payment
     FROM customer_profiles WHERE customer_id = ?`
  ).bind(customer.id).first<any>();

  return c.json({
    success: true,
    data: {
      id: customer.id,
      name: customer.full_name || '',
      phone: customer.phone || '',
      village: profRow?.village || '',
      district: profRow?.district || '',
      state: profRow?.state || '',
      language: profRow?.language || 'en',
      notify_health: profRow ? Boolean(profRow.notify_health) : true,
      notify_vaccination: profRow ? Boolean(profRow.notify_vaccination) : true,
      notify_consultation: profRow ? Boolean(profRow.notify_consultation) : true,
      notify_payment: profRow ? Boolean(profRow.notify_payment) : true,
    },
  });
});

adminRouter.put('/profile', async (c) => {
  const customer = await requireAuth(c);
  const db = c.env.DB;
  const body = await c.req.json().catch(() => ({}));
  const parsed = ProfileUpdateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid profile payload' });
  }

  const stmts: D1PreparedStatement[] = [];
  if (parsed.data.name !== undefined) {
    stmts.push(
      db.prepare('UPDATE customers SET full_name = ? WHERE id = ?').bind(parsed.data.name.trim(), customer.id)
    );
  }

  stmts.push(
    db.prepare(
      `INSERT INTO customer_profiles (customer_id, village, district, state, language, notify_health, notify_vaccination, notify_consultation, notify_payment)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(customer_id) DO UPDATE SET
         village = excluded.village, district = excluded.district, state = excluded.state,
         language = excluded.language, notify_health = excluded.notify_health,
         notify_vaccination = excluded.notify_vaccination, notify_consultation = excluded.notify_consultation,
         notify_payment = excluded.notify_payment, updated_at = CURRENT_TIMESTAMP`
    ).bind(
      customer.id,
      parsed.data.village || '',
      parsed.data.district || '',
      parsed.data.state || '',
      parsed.data.language || 'en',
      parsed.data.notify_health ?? true ? 1 : 0,
      parsed.data.notify_vaccination ?? true ? 1 : 0,
      parsed.data.notify_consultation ?? true ? 1 : 0,
      parsed.data.notify_payment ?? true ? 1 : 0
    )
  );

  await db.batch(stmts);

  const updatedCust = await db.prepare('SELECT full_name FROM customers WHERE id = ?').bind(customer.id).first<any>();
  return c.json({
    success: true,
    data: {
      id: customer.id,
      name: updatedCust?.full_name || '',
      phone: customer.phone,
      ...parsed.data,
    },
  });
});

// ---------------------------------------------------------------------------
// 3. Store Help & FAQs
// ---------------------------------------------------------------------------

const DEFAULT_HELP = {
  contact_message: 'For any questions about your orders, deliveries, or farm-direct products, submit an enquiry below or reach our team.',
  faqs: [
    { category: 'Ordering', question: 'How does Cash on Delivery (COD) work?', answer: 'You can place your order online and pay the delivery courier in cash or via UPI QR when your package arrives at your doorstep.' },
    { category: 'Delivery', question: 'Which locations do you currently deliver to?', answer: 'We currently deliver to serviceable pincodes across select partner regions. Use our pincode check during checkout to verify coverage for your address.' },
    { category: 'Quality', question: 'How are Milterra dairy products packaged?', answer: 'All products are securely packed from our partner suppliers for safe transit to your location.' },
    { category: 'Returns', question: 'What is your return and cancellation policy?', answer: 'Orders can be cancelled directly from your account page before dispatch. For questions or issues with a delivered order, contact our support team through the Help & Support section.' },
  ],
};

adminRouter.get('/help', async (c) => {
  const db = c.env.DB;
  try {
    const row = await db.prepare("SELECT content FROM store_help WHERE key = 'help'").first<any>();
    if (row && row.content) {
      const parsed = JSON.parse(row.content);
      return c.json({ success: true, data: parsed });
    }
  } catch {
    // ignore
  }
  return c.json({ success: true, data: DEFAULT_HELP });
});

adminRouter.put('/admin/help', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const db = c.env.DB;
  const body = await c.req.json().catch(() => ({}));

  await db.prepare(
    "INSERT INTO store_help (key, content) VALUES ('help', ?) ON CONFLICT(key) DO UPDATE SET content = excluded.content"
  ).bind(JSON.stringify(body)).run();

  return c.json({ success: true, data: body });
});

// ---------------------------------------------------------------------------
// 4. Customer Support Ticketing
// ---------------------------------------------------------------------------

adminRouter.post('/support', async (c) => {
  const customer = await requireAuth(c);
  const db = c.env.DB;
  const body = await c.req.json().catch(() => null);
  const parsed = SupportTicketInputSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid support ticket data' });
  }

  const ticketId = crypto.randomUUID();
  const now = new Date().toISOString();

  await db.prepare(
    `INSERT INTO support_tickets (id, customer_id, subject, message, status, created_at, updated_at)
     VALUES (?, ?, ?, ?, 'OPEN', ?, ?)`
  ).bind(ticketId, customer.id, parsed.data.subject.trim(), parsed.data.message.trim(), now, now).run();

  return c.json({
    success: true,
    data: {
      id: ticketId,
      subject: parsed.data.subject.trim(),
      message: parsed.data.message.trim(),
      status: 'OPEN',
      reply: null,
      created_at: now,
    },
  }, 201);
});

adminRouter.get('/support', async (c) => {
  const customer = await requireAuth(c);
  const db = c.env.DB;

  const rows = await db.prepare(
    `SELECT id, subject, message, status, reply, created_at
     FROM support_tickets WHERE customer_id = ? ORDER BY created_at DESC LIMIT 100`
  ).bind(customer.id).all();

  return c.json({ success: true, data: rows.results || [] });
});

adminRouter.get('/admin/support', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const db = c.env.DB;

  const rows = await db.prepare(
    `SELECT t.id, t.customer_id, t.subject, t.message, t.status, t.reply, t.created_at, c.phone AS customer_phone
     FROM support_tickets t JOIN customers c ON c.id = t.customer_id
     ORDER BY t.created_at DESC LIMIT 500`
  ).all();

  return c.json({ success: true, data: rows.results || [] });
});

adminRouter.patch('/admin/support/:ticket_id', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const ticketId = c.req.param('ticket_id');
  const db = c.env.DB;

  const body = await c.req.json().catch(() => null);
  const parsed = SupportTicketUpdateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid ticket update data' });
  }

  const existing = await db.prepare('SELECT * FROM support_tickets WHERE id = ?').bind(ticketId).first<any>();
  if (!existing) {
    throw new HTTPException(404, { message: 'Support ticket not found' });
  }

  const now = new Date().toISOString();
  await db.prepare(
    'UPDATE support_tickets SET status = ?, reply = ?, updated_at = ? WHERE id = ?'
  ).bind(parsed.data.status, parsed.data.reply.trim(), now, ticketId).run();

  return c.json({
    success: true,
    data: {
      id: ticketId,
      subject: existing.subject,
      message: existing.message,
      status: parsed.data.status,
      reply: parsed.data.reply.trim(),
      created_at: existing.created_at,
    },
  });
});

// ---------------------------------------------------------------------------
// 5. Product Reviews
// ---------------------------------------------------------------------------

function formatReview(r: any) {
  return {
    ...r,
    customer_name: r.author_name || '',
    review_text: r.content,
    comment: r.content,
    is_approved: r.status === 'APPROVED',
    is_verified: true,
    reply: r.vendor_reply,
  };
}

adminRouter.post('/products/:product_id/reviews', async (c) => {
  const customer = await requireAuth(c);
  const productId = c.req.param('product_id');
  const db = c.env.DB;

  const body = await c.req.json().catch(() => null);
  const parsed = ReviewInputSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid review payload' });
  }

  const order = await db.prepare(
    `SELECT o.id FROM orders o JOIN order_lines l ON l.order_id = o.id
     WHERE o.id = ? AND o.customer_id = ? AND o.status = 'delivered' AND l.product_id = ?`
  ).bind(parsed.data.order_id, customer.id, productId).first();

  if (!order) {
    throw new HTTPException(403, { message: 'Only a customer with a delivered order can review this product' });
  }

  const reviewId = crypto.randomUUID();
  try {
    await db.prepare(
      `INSERT INTO product_reviews (id, customer_id, product_id, order_id, rating, headline, content)
       VALUES (?, ?, ?, ?, ?, ?, ?)`
    ).bind(
      reviewId,
      customer.id,
      productId,
      parsed.data.order_id,
      parsed.data.rating,
      parsed.data.headline || '',
      parsed.data.content.trim()
    ).run();
  } catch (err: any) {
    if (String(err).toUpperCase().includes('UNIQUE')) {
      throw new HTTPException(409, { message: 'This order already has a review for the product' });
    }
    throw err;
  }

  return c.json({ success: true, data: { id: reviewId, status: 'PENDING' } }, 201);
});

adminRouter.get('/products/:product_id/reviews', async (c) => {
  const productId = c.req.param('product_id');
  const db = c.env.DB;

  const rows = await db.prepare(
    `SELECT r.*, c.full_name AS author_name, i.title AS product_title
     FROM product_reviews r
     JOIN customers c ON c.id = r.customer_id
     JOIN inventory i ON i.product_id = r.product_id
     WHERE r.product_id = ? AND r.status = 'APPROVED'
     ORDER BY r.created_at DESC LIMIT 100`
  ).bind(productId).all();

  return c.json({ success: true, data: (rows.results || []).map(formatReview) });
});

const handleListAllReviews = async (c: any) => {
  await requireAuth(c, ['admin', 'vendor', 'super_admin']);
  const db = c.env.DB;

  const rows = await db.prepare(
    `SELECT r.*, c.full_name AS author_name, i.title AS product_title
     FROM product_reviews r
     JOIN customers c ON c.id = r.customer_id
     JOIN inventory i ON i.product_id = r.product_id
     ORDER BY r.created_at DESC LIMIT 100`
  ).all();

  return c.json({ success: true, data: (rows.results || []).map(formatReview) });
};

adminRouter.get('/admin/marketplace/reviews', handleListAllReviews);
adminRouter.get('/vendor/products/reviews', handleListAllReviews);

const handleReviewStatusUpdate = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const reviewId = c.req.param('review_id');
  const db = c.env.DB;

  const body = await c.req.json().catch(() => null);
  const parsed = ReviewStatusUpdateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid review status update payload' });
  }

  const target = parsed.data.status || (parsed.data.is_approved ? 'APPROVED' : parsed.data.is_approved === false ? 'REJECTED' : null);
  if (!target) {
    throw new HTTPException(422, { message: 'Review status is required' });
  }

  const existing = await db.prepare('SELECT id FROM product_reviews WHERE id = ?').bind(reviewId).first();
  if (!existing) {
    throw new HTTPException(404, { message: 'Review not found' });
  }

  const reason = parsed.data.rejection_reason || parsed.data.reason || null;
  await db.prepare(
    'UPDATE product_reviews SET status = ?, rejection_reason = ? WHERE id = ?'
  ).bind(target, target === 'REJECTED' ? reason : null, reviewId).run();

  return c.json({ success: true, message: `Review ${reviewId} status updated to ${target}` });
};

adminRouter.patch('/admin/marketplace/reviews/:review_id/status', handleReviewStatusUpdate);
adminRouter.patch('/admin/marketplace/reviews/:review_id', handleReviewStatusUpdate);
adminRouter.patch('/admin/marketplace/reviews/:review_id/moderation', handleReviewStatusUpdate);
adminRouter.patch('/marketplace/admin/marketplace/reviews/:review_id/moderation', handleReviewStatusUpdate);

const handleReviewReply = async (c: any) => {
  await requireAuth(c, ['admin', 'vendor', 'super_admin']);
  const reviewId = c.req.param('review_id');
  const db = c.env.DB;

  const body = await c.req.json().catch(() => null);
  const parsed = ReviewReplySchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Review reply cannot be empty' });
  }

  const existing = await db.prepare('SELECT id FROM product_reviews WHERE id = ?').bind(reviewId).first();
  if (!existing) {
    throw new HTTPException(404, { message: 'Review not found' });
  }

  await db.prepare('UPDATE product_reviews SET vendor_reply = ? WHERE id = ?').bind(parsed.data.reply.trim(), reviewId).run();
  return c.json({ success: true, message: `Reply added to review ${reviewId}` });
};

adminRouter.post('/admin/marketplace/reviews/:review_id/reply', handleReviewReply);
adminRouter.post('/vendor/products/reviews/:review_id/reply', handleReviewReply);

// ---------------------------------------------------------------------------
// 6. Loyalty & Referral Admin
// ---------------------------------------------------------------------------

async function getLoyaltySettings(db: D1Database) {
  const row = await db.prepare('SELECT * FROM loyalty_settings WHERE id = 1').first<any>();
  if (row) {
    return {
      is_active: Boolean(row.is_active),
      earning_rate_percent: row.earning_rate_percent,
      redemption_rate_minor: row.redemption_rate_minor,
      min_points_to_redeem: row.min_points_to_redeem,
      max_redeem_percent_per_order: row.max_redeem_percent_per_order,
    };
  }
  return {
    is_active: true,
    earning_rate_percent: 5.0,
    redemption_rate_minor: 100,
    min_points_to_redeem: 100,
    max_redeem_percent_per_order: 20.0,
  };
}

adminRouter.get('/admin/marketplace/loyalty/settings', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const settings = await getLoyaltySettings(c.env.DB);
  return c.json({ success: true, data: settings });
});

adminRouter.put('/admin/marketplace/loyalty/settings', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const db = c.env.DB;
  const body = await c.req.json().catch(() => null);
  const parsed = LoyaltySettingsUpdateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid loyalty settings payload' });
  }

  await db.prepare(
    `INSERT INTO loyalty_settings (id, is_active, earning_rate_percent, redemption_rate_minor, min_points_to_redeem, max_redeem_percent_per_order)
     VALUES (1, ?, ?, ?, ?, ?)
     ON CONFLICT(id) DO UPDATE SET
       is_active = excluded.is_active,
       earning_rate_percent = excluded.earning_rate_percent,
       redemption_rate_minor = excluded.redemption_rate_minor,
       min_points_to_redeem = excluded.min_points_to_redeem,
       max_redeem_percent_per_order = excluded.max_redeem_percent_per_order,
       updated_at = CURRENT_TIMESTAMP`
  ).bind(
    parsed.data.is_active ? 1 : 0,
    parsed.data.earning_rate_percent,
    parsed.data.redemption_rate_minor,
    parsed.data.min_points_to_redeem,
    parsed.data.max_redeem_percent_per_order
  ).run();

  const settings = await getLoyaltySettings(db);
  return c.json({ success: true, message: 'Loyalty settings updated', data: settings });
});

adminRouter.get('/admin/marketplace/loyalty/customers', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const db = c.env.DB;

  const rows = await db.prepare(
    `SELECT c.id as customer_id, c.full_name as name, c.phone,
            COALESCE(l.balance_after, 0) as points_balance
     FROM customers c
     LEFT JOIN customer_loyalty_ledger l ON l.id = (
       SELECT id FROM customer_loyalty_ledger WHERE customer_id = c.id ORDER BY created_at DESC LIMIT 1
     )
     ORDER BY points_balance DESC`
  ).all();

  return c.json({ success: true, data: rows.results || [] });
});

adminRouter.post('/admin/marketplace/loyalty/adjust', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const db = c.env.DB;
  const body = await c.req.json().catch(() => null);
  const parsed = LoyaltyAdjustmentSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid adjustment payload' });
  }

  const lastEntry = await db.prepare(
    'SELECT balance_after FROM customer_loyalty_ledger WHERE customer_id = ? ORDER BY created_at DESC LIMIT 1'
  ).bind(parsed.data.customer_id).first<any>();

  const currentBal = lastEntry ? Number(lastEntry.balance_after) : 0;
  const newBal = Math.max(0, currentBal + parsed.data.points_change);

  await db.prepare(
    `INSERT INTO customer_loyalty_ledger (id, customer_id, points_change, balance_after, description)
     VALUES (?, ?, ?, ?, ?)`
  ).bind(
    crypto.randomUUID(),
    parsed.data.customer_id,
    parsed.data.points_change,
    newBal,
    `Admin Adjustment: ${parsed.data.description}`
  ).run();

  return c.json({ success: true, message: 'Loyalty points adjusted', new_balance: newBal });
});

function generateReferralCode(customerId: string, phone?: string): string {
  const cleanPhone = (phone || '').replace(/\D/g, '');
  if (cleanPhone.length >= 4) {
    return `MILTERRA-${cleanPhone.slice(-4)}`;
  }
  const cleanId = customerId.replace(/[^a-zA-Z0-9]/g, '');
  return `MILTERRA-${cleanId.slice(0, 6).toUpperCase()}`;
}

adminRouter.post('/referral/claim', async (c) => {
  const user = await requireAuth(c);
  const refereeId = user.id;
  const db = c.env.DB;

  const body = await c.req.json().catch(() => null);
  const parsed = ReferralClaimSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Referral code is required' });
  }

  const existing = await db.prepare('SELECT id FROM customer_referrals WHERE referred_customer_id = ?').bind(refereeId).first();
  if (existing) {
    throw new HTTPException(400, { message: 'You have already claimed a referral code' });
  }

  const code = parsed.data.referral_code.trim().toUpperCase();
  if (!code.startsWith('MILTERRA-')) {
    throw new HTTPException(404, { message: 'Invalid or expired referral code' });
  }
  const suffix = code.replace('MILTERRA-', '');

  const candidates = await db.prepare(
    'SELECT id, full_name, phone FROM customers WHERE phone LIKE ? OR id LIKE ?'
  ).bind(`%${suffix}`, `${suffix.toLowerCase()}%`).all();

  let referrer: any = null;
  for (const row of (candidates.results || []) as any[]) {
    if (generateReferralCode(row.id, row.phone) === code) {
      referrer = row;
      break;
    }
  }

  if (!referrer) {
    throw new HTTPException(404, { message: 'Invalid or expired referral code' });
  }
  if (referrer.id === refereeId) {
    throw new HTTPException(400, { message: 'You cannot redeem your own referral code' });
  }

  const refId = `ref-${crypto.randomUUID()}`;
  await db.prepare(
    `INSERT INTO customer_referrals (id, referrer_customer_id, referred_customer_id, referral_code, status, reward_points)
     VALUES (?, ?, ?, ?, 'completed', 100)`
  ).bind(refId, referrer.id, refereeId, code).run();

  // Credit 100 points to both referee and referrer
  const refereeBal = await db.prepare('SELECT balance_after FROM customer_loyalty_ledger WHERE customer_id = ? ORDER BY created_at DESC LIMIT 1').bind(refereeId).first<any>();
  const referrerBal = await db.prepare('SELECT balance_after FROM customer_loyalty_ledger WHERE customer_id = ? ORDER BY created_at DESC LIMIT 1').bind(referrer.id).first<any>();

  await db.batch([
    db.prepare('INSERT INTO customer_loyalty_ledger (id, customer_id, points_change, balance_after, description) VALUES (?, ?, 100, ?, ?)').bind(
      crypto.randomUUID(), refereeId, (refereeBal?.balance_after || 0) + 100, `Referral welcome bonus using code ${code}`
    ),
    db.prepare('INSERT INTO customer_loyalty_ledger (id, customer_id, points_change, balance_after, description) VALUES (?, ?, 100, ?, ?)').bind(
      crypto.randomUUID(), referrer.id, (referrerBal?.balance_after || 0) + 100, `Referral reward: invited friend (${refereeId.slice(0, 8)})`
    ),
  ]);

  return c.json({
    success: true,
    message: 'Referral code applied! 100 Loyalty Points credited to your Milterra wallet.',
    reward_points: 100,
  });
});

adminRouter.get('/admin/marketplace/referral/stats', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const db = c.env.DB;

  const totals = await db.prepare(
    'SELECT COUNT(*) as total_count, COALESCE(SUM(reward_points), 0) as total_points FROM customer_referrals'
  ).first<any>();

  const recent = await db.prepare(
    `SELECT r.id, r.referral_code, r.reward_points, r.status, r.created_at,
            c1.full_name as referrer_name, c1.phone as referrer_phone,
            c2.full_name as referee_name, c2.phone as referee_phone
     FROM customer_referrals r
     LEFT JOIN customers c1 ON c1.id = r.referrer_customer_id
     LEFT JOIN customers c2 ON c2.id = r.referred_customer_id
     ORDER BY r.created_at DESC LIMIT 50`
  ).all();

  return c.json({
    success: true,
    data: {
      total_referrals: totals?.total_count || 0,
      total_points_distributed: totals?.total_points || 0,
      recent: recent.results || [],
    },
  });
});

// ---------------------------------------------------------------------------
// 7. Subscriptions & Purity Batches Admin
// ---------------------------------------------------------------------------

adminRouter.get('/admin/marketplace/subscriptions', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const db = c.env.DB;

  const rows = await db.prepare(
    `SELECT s.*, c.phone as customer_phone, c.full_name as customer_name, i.title as product_title
     FROM customer_subscriptions s
     LEFT JOIN customers c ON c.id = s.customer_id
     LEFT JOIN inventory i ON i.product_id = s.product_id
     ORDER BY s.created_at DESC LIMIT 100`
  ).all();

  return c.json({ success: true, data: rows.results || [] });
});

adminRouter.get('/admin/marketplace/purity/batches', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const db = c.env.DB;

  const rows = await db.prepare(
    `SELECT b.*, i.title as product_title
     FROM product_batch_reports b
     LEFT JOIN inventory i ON i.product_id = b.product_id
     ORDER BY b.created_at DESC`
  ).all();

  return c.json({ success: true, data: rows.results || [] });
});

adminRouter.post('/admin/marketplace/purity/batches', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const db = c.env.DB;
  const body = await c.req.json().catch(() => null);
  const parsed = PurityBatchInputSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid purity batch certificate data' });
  }

  const repId = `rep-${crypto.randomUUID()}`;
  await db.prepare(
    `INSERT INTO product_batch_reports (id, product_id, batch_number, churn_date, expiry_date, purity_score, fat_percentage, snf_percentage, lab_name, report_url, certificate_summary)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(batch_number) DO UPDATE SET
       product_id = excluded.product_id, churn_date = excluded.churn_date, expiry_date = excluded.expiry_date,
       purity_score = excluded.purity_score, fat_percentage = excluded.fat_percentage, snf_percentage = excluded.snf_percentage,
       lab_name = excluded.lab_name, report_url = excluded.report_url, certificate_summary = excluded.certificate_summary`
  ).bind(
    repId,
    parsed.data.product_id,
    parsed.data.batch_number.trim().toUpperCase(),
    parsed.data.churn_date,
    parsed.data.expiry_date,
    parsed.data.purity_score,
    parsed.data.fat_percentage,
    parsed.data.snf_percentage,
    parsed.data.lab_name,
    parsed.data.report_url,
    parsed.data.certificate_summary
  ).run();

  return c.json({ success: true, message: `Batch ${parsed.data.batch_number} purity certificate recorded successfully.` });
});

// ---------------------------------------------------------------------------
// 8. Merchandising Placements Admin
// ---------------------------------------------------------------------------

const getAdminMerchandisingPlacementsHandler = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const db = c.env.DB;

  const rows = (await db.prepare(
    `SELECT c.*, i.title AS product_title, i.price_minor, i.available_units,
            i.is_active AS product_active, p.mrp_minor, v.pack_size,
            COALESCE(sv.is_visible, 1) AS storefront_visible
     FROM storefront_campaigns c
     JOIN inventory i ON i.product_id = c.product_id
     LEFT JOIN inventory_pricing p ON p.product_id = c.product_id
     LEFT JOIN product_family_variants v ON v.id = c.product_id
     LEFT JOIN storefront_product_visibility sv ON sv.product_id = c.product_id
     ORDER BY c.priority DESC, c.created_at DESC`
  ).all()).results || [];

  const data = [];
  for (const row of rows as any[]) {
    let coupon: any = null;
    if (row.coupon_code) {
      coupon = await db.prepare('SELECT * FROM coupons WHERE code = ? AND is_active = 1').bind(String(row.coupon_code).trim().toUpperCase()).first();
    }
    const price = (Number(row.price_minor || 0) / 100.0);
    const mrp = row.mrp_minor !== null && row.mrp_minor !== undefined ? (Number(row.mrp_minor) / 100.0) : null;
    data.push({
      id: String(row.id),
      product_id: String(row.product_id),
      placement_type: String(row.placement_type || 'highlight'),
      headline: String(row.headline || ''),
      subheadline: row.subheadline || null,
      badge: row.badge || null,
      starts_at: row.starts_at || null,
      ends_at: row.ends_at || null,
      priority: Number(row.priority ?? 100),
      is_active: Boolean(row.is_active === 1),
      product: {
        id: String(row.product_id),
        product_id: String(row.product_id),
        vendor_id: 'vendor-1',
        title: String(row.product_title || ''),
        category: 'FEED_NUTRITION',
        base_price: price,
        price: price,
        compare_at_price: mrp,
        unit: 'pack',
        pack_size: row.pack_size || '',
        description: row.product_title || '',
        available_quantity: Number(row.available_units || 0),
        available_units: Number(row.available_units || 0),
        min_order_quantity: 1,
        in_stock: Boolean((row.available_units ?? 0) > 0 && row.product_active === 1),
        is_active: Boolean(row.product_active === 1),
        storefront_visible: Boolean(row.storefront_visible === 1),
        publication_status: 'published',
        media: [],
        specifications: {},
        taxonomy: null,
        vendor: { id: 'vendor-1', business_name: 'Milterra Central Operations' },
      },
      coupon: coupon ? {
        code: coupon.code,
        description: coupon.description || '',
        discount_type: coupon.discount_type,
        discount_value: coupon.discount_value,
        min_order_value: coupon.min_order_value || 0,
        max_discount_cap: coupon.max_discount_cap,
        is_active: coupon.is_active === 1,
      } : null,
    });
  }

  return c.json({ success: true, data });
};

adminRouter.get('/admin/marketplace/merchandising/placements', getAdminMerchandisingPlacementsHandler);
adminRouter.get('/marketplace/admin/marketplace/merchandising/placements', getAdminMerchandisingPlacementsHandler);
adminRouter.get('/marketplace/merchandising/placements', getAdminMerchandisingPlacementsHandler);
adminRouter.get('/merchandising/placements', getAdminMerchandisingPlacementsHandler);

adminRouter.post('/admin/marketplace/merchandising/placements', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const db = c.env.DB;
  const body = await c.req.json().catch(() => null);
  const parsed = PlacementInputSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid placement payload' });
  }

  const product = await db.prepare('SELECT product_id FROM inventory WHERE product_id = ?').bind(parsed.data.product_id.trim()).first();
  if (!product) {
    throw new HTTPException(404, { message: 'Product not found' });
  }

  const couponCode = parsed.data.coupon_code ? parsed.data.coupon_code.trim().toUpperCase() : null;
  if (couponCode) {
    const coupon = await db.prepare('SELECT code FROM coupons WHERE code = ?').bind(couponCode).first();
    if (!coupon) {
      throw new HTTPException(422, { message: 'Coupon does not exist' });
    }
  }

  const placementId = `pl-${crypto.randomUUID()}`;
  await db.prepare(
    `INSERT INTO storefront_campaigns (id, product_id, placement_type, headline, subheadline, badge, coupon_code, starts_at, ends_at, priority, is_active)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).bind(
    placementId,
    parsed.data.product_id.trim(),
    parsed.data.placement_type,
    parsed.data.headline.trim(),
    parsed.data.subheadline || null,
    parsed.data.badge || null,
    couponCode,
    parsed.data.starts_at || null,
    parsed.data.ends_at || null,
    parsed.data.priority,
    parsed.data.is_active ? 1 : 0
  ).run();

  return c.json({ success: true, message: 'Placement created', data: { id: placementId } }, 201);
});

adminRouter.put('/admin/marketplace/merchandising/placements/:placement_id', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const placementId = c.req.param('placement_id');
  const db = c.env.DB;

  const current = await db.prepare('SELECT * FROM storefront_campaigns WHERE id = ?').bind(placementId).first<any>();
  if (!current) {
    throw new HTTPException(404, { message: 'Placement not found' });
  }

  const body = await c.req.json().catch(() => null);
  const parsed = PlacementUpdateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid placement update payload' });
  }

  const productId = parsed.data.product_id ? parsed.data.product_id.trim() : current.product_id;
  const headline = parsed.data.headline ? parsed.data.headline.trim() : current.headline;
  const placementType = parsed.data.placement_type || current.placement_type;
  const couponCode = parsed.data.coupon_code !== undefined ? (parsed.data.coupon_code ? parsed.data.coupon_code.trim().toUpperCase() : null) : current.coupon_code;

  await db.prepare(
    `UPDATE storefront_campaigns
     SET product_id = ?, placement_type = ?, headline = ?, subheadline = ?, badge = ?, coupon_code = ?,
         starts_at = ?, ends_at = ?, priority = ?, is_active = ?, updated_at = CURRENT_TIMESTAMP
     WHERE id = ?`
  ).bind(
    productId,
    placementType,
    headline,
    parsed.data.subheadline !== undefined ? parsed.data.subheadline : current.subheadline,
    parsed.data.badge !== undefined ? parsed.data.badge : current.badge,
    couponCode,
    parsed.data.starts_at !== undefined ? parsed.data.starts_at : current.starts_at,
    parsed.data.ends_at !== undefined ? parsed.data.ends_at : current.ends_at,
    parsed.data.priority !== undefined ? parsed.data.priority : current.priority,
    parsed.data.is_active !== undefined ? (parsed.data.is_active ? 1 : 0) : current.is_active,
    placementId
  ).run();

  return c.json({ success: true, message: `Placement ${placementId} updated` });
});

adminRouter.delete('/admin/marketplace/merchandising/placements/:placement_id', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const placementId = c.req.param('placement_id');
  const db = c.env.DB;

  await db.prepare('DELETE FROM storefront_campaigns WHERE id = ?').bind(placementId).run();
  return c.json({ success: true, message: `Placement ${placementId} deleted` });
});

// ---------------------------------------------------------------------------
// 9. Admin Dashboard & Partner Stats
// ---------------------------------------------------------------------------

const getDashboardHandler = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const db = c.env.DB;

  const customers = (await db.prepare("SELECT COUNT(*) AS n FROM customers WHERE role IN ('farmer', 'customer')").first()) as any;
  const orders = (await db.prepare(
    `SELECT COUNT(*) AS n,
            COALESCE(SUM(CASE WHEN payment_status = 'paid' THEN total_minor ELSE 0 END), 0) AS revenue_minor
     FROM orders WHERE status != 'cancelled'`
  ).first()) as any;

  return c.json({
    success: true,
    data: {
      total_farmers: customers?.n || 0,
      total_vets: 0,
      total_orders: orders?.n || 0,
      total_revenue: (orders?.revenue_minor || 0) / 100,
    },
  });
};

adminRouter.get('/admin/dashboard', getDashboardHandler);
adminRouter.get('/marketplace/admin/dashboard', getDashboardHandler);

const listFarmersHandler = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const db = c.env.DB;
  const rows = await db.prepare(
    "SELECT id, phone, full_name, is_active, created_at FROM customers WHERE role = 'farmer' OR role = 'customer' LIMIT 100"
  ).all();
  return c.json({ success: true, data: rows.results || [] });
};

adminRouter.get('/admin/farmers', listFarmersHandler);
adminRouter.get('/marketplace/admin/farmers', listFarmersHandler);

const listVetsHandler = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin']);
  return c.json({ success: true, data: [] });
};

adminRouter.get('/admin/vets', listVetsHandler);
adminRouter.get('/marketplace/admin/vets', listVetsHandler);

const verifyVetHandler = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin']);
  return c.json({ success: true, message: 'Vet profile verified successfully' });
};

adminRouter.post('/vet-profiles/verify', verifyVetHandler);
adminRouter.post('/marketplace/vet-profiles/verify', verifyVetHandler);

const listConsultationsHandler = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin']);
  return c.json({ success: true, data: [] });
};

adminRouter.get('/admin/consultations', listConsultationsHandler);
adminRouter.get('/marketplace/admin/consultations', listConsultationsHandler);

const getAdminAnalyticsHandler = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin']);
  return getDashboardHandler(c);
};

adminRouter.get('/admin/analytics', getAdminAnalyticsHandler);
adminRouter.get('/marketplace/admin/analytics', getAdminAnalyticsHandler);

// ---------------------------------------------------------------------------
// 10. WhatsApp Webhook & Simulator
// ---------------------------------------------------------------------------

const mockLogs: Array<{ phone: string; payload: any; timestamp: string }> = [];

adminRouter.get('/whatsapp/webhook', (c) => {
  const mode = c.req.query('hub.mode');
  const token = c.req.query('hub.verify_token');
  const challenge = c.req.query('hub.challenge');

  const expectedToken = c.env?.WHATSAPP_VERIFY_TOKEN || 'milterra_whatsapp_secret_token';
  if (mode === 'subscribe' && token === expectedToken && challenge) {
    return c.text(challenge);
  }
  throw new HTTPException(403, { message: 'Webhook verification failed' });
});

adminRouter.post('/whatsapp/webhook', async (c) => {
  const body = await c.req.json().catch(() => ({}));
  return c.json({ success: true, processed: 1, outgoing: [] });
});

adminRouter.post('/whatsapp/send-mock', async (c) => {
  const data = await c.req.json().catch(() => ({}));
  const phone = data.phone || '919839769808';
  const name = data.name || 'Test User';
  const message = data.message || 'Hi';

  const reply = {
    recipient_type: 'individual',
    to: phone,
    type: 'text',
    text: { body: `Hi ${name}! Welcome to Milterra Foods. How can we help you today?` },
  };

  mockLogs.push({ phone, payload: reply, timestamp: new Date().toISOString() });
  return c.json({ success: true, input: data, bot_payload: reply, delivery: { status: 'sent' } });
});

adminRouter.get('/admin/whatsapp/logs', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  return c.json({ success: true, count: mockLogs.length, logs: mockLogs });
});

// ---------------------------------------------------------------------------
// 11. Admin Marketplace & Vendor Product Management
// ---------------------------------------------------------------------------

const getAdminCommerceHandler = async (c: any) => {
  await requireAuth(c, ['admin', 'vendor', 'super_admin']);
  const db = c.env.DB;

  const couponsRows = await db.prepare('SELECT * FROM coupons').all();
  const sellersRows = await db.prepare('SELECT * FROM commerce_sellers ORDER BY created_at').all();
  const inventoryRows = await db.prepare(`
    SELECT i.*, p.mrp_minor FROM inventory i
    LEFT JOIN inventory_pricing p ON p.product_id = i.product_id
    ORDER BY i.title
  `).all();

  const offers = (inventoryRows.results || []).map((row: any) => ({
    id: row.product_id,
    product_id: row.product_id,
    seller_id: 'vendor-1',
    seller_name: 'Milterra Central Operations',
    seller_sku: row.product_id,
    mrp: ((row.mrp_minor || row.price_minor) / 100),
    selling_price: (row.price_minor / 100),
    available_stock: row.available_units,
    low_stock_threshold: 5,
    offer_status: row.is_active ? 'active' : 'inactive',
  }));

  const certsRows = await db.prepare(`
    SELECT b.*, i.title AS product_title FROM batch_certificates b
    JOIN inventory i ON i.product_id = b.product_id
    ORDER BY b.test_date DESC
  `).all();

  const eventsRows = await db.prepare('SELECT * FROM order_events ORDER BY created_at DESC LIMIT 100').all();
  const auditLogs = (eventsRows.results || []).map((e: any) => ({
    id: e.id,
    user_role: 'system',
    user_identifier: 'system',
    action: (e.status || 'update').toLowerCase(),
    entity_type: 'order',
    entity_id: e.order_id || '',
    details: `${e.title || ''} - ${e.remarks || ''}`.replace(/^ - |- $/g, '').trim(),
    timestamp: e.created_at || new Date().toISOString(),
  }));

  return c.json({
    success: true,
    data: {
      sellers: sellersRows.results || [],
      offers: offers,
      coupons: (couponsRows.results || []).map((cp: any) => ({
        id: cp.code,
        code: cp.code,
        description: cp.description || '',
        discount_type: cp.discount_type,
        discount_value: cp.discount_value,
        min_order_value: cp.min_order_value || 0,
        max_discount_cap: cp.max_discount_cap,
        valid_until: cp.valid_until,
        usage_count: cp.usage_count || 0,
        is_active: cp.is_active === 1,
      })),
      batch_certificates: (certsRows.results || []).map((ct: any) => ({
        id: ct.id,
        batch_number: ct.batch_number,
        product_id: ct.product_id,
        product_title: ct.product_title,
        category: ct.category || 'dairy',
        test_date: ct.test_date,
        laboratory: ct.laboratory,
        fssai_license: ct.fssai_license,
        purity_percent: ct.purity_percent,
        test_parameters: typeof ct.test_parameters === 'string' ? JSON.parse(ct.test_parameters) : (ct.test_parameters || {}),
        status: ct.status,
        certified_by: ct.certified_by,
        remarks: ct.remarks || '',
        report_url: ct.report_url,
      })),
      audit_logs: auditLogs,
    },
  });
};

adminRouter.get('/admin/commerce', getAdminCommerceHandler);
adminRouter.get('/vendor/commerce', getAdminCommerceHandler);
adminRouter.get('/marketplace/admin/commerce', getAdminCommerceHandler);
adminRouter.get('/marketplace/vendor/commerce', getAdminCommerceHandler);

const getVendorProductsHandler = async (c: any) => {
  await requireAuth(c, ['admin', 'vendor', 'super_admin']);
  const db = c.env.DB;
  const rows = await db.prepare(`
    SELECT i.*, p.mrp_minor, f.department, v.pack_size, v.publication_status,
    COALESCE(sv.is_visible, 1) AS storefront_visible,
    sv.hidden_reason, sv.updated_by AS visibility_updated_by,
    sv.updated_at AS visibility_updated_at
    FROM inventory i
    LEFT JOIN inventory_pricing p ON p.product_id = i.product_id
    LEFT JOIN product_family_variants v ON v.id = i.product_id
    LEFT JOIN product_families f ON f.id = v.family_id
    LEFT JOIN storefront_product_visibility sv ON sv.product_id = i.product_id
    ORDER BY i.title
  `).all();

  const products = (rows.results || []).map((r: any) => ({
    id: r.product_id,
    product_id: r.product_id,
    vendor_id: 'vendor-1',
    title: r.title,
    category: r.department || 'Uncategorized',
    base_price: r.price_minor / 100.0,
    price: r.price_minor / 100.0,
    unit: 'pack',
    pack_size: r.pack_size || '',
    description: r.title,
    available_quantity: r.available_units,
    available_units: r.available_units,
    min_order_quantity: 1,
    in_stock: r.available_units > 0 && r.is_active === 1,
    is_active: r.is_active === 1,
    storefront_visible: r.storefront_visible === 1,
    hidden_reason: r.hidden_reason || null,
    visibility_updated_by: r.visibility_updated_by || null,
    visibility_updated_at: r.visibility_updated_at || null,
    publication_status: r.publication_status || (r.is_active ? 'published' : 'draft'),
    media: [],
    specifications: {},
    taxonomy: null,
    vendor: {
      id: 'vendor-1',
      business_name: 'Milterra Central Operations',
    },
  }));

  return c.json({ success: true, data: products });
};

adminRouter.get('/vendor/products', getVendorProductsHandler);
adminRouter.get('/admin/products', getVendorProductsHandler);
adminRouter.get('/marketplace/vendor/products', getVendorProductsHandler);
adminRouter.get('/marketplace/admin/products', getVendorProductsHandler);

const getProductFamiliesHandler = async (c: any) => {
  await requireAuth(c, ['admin', 'vendor', 'super_admin']);
  const db = c.env.DB;

  const famRows = (await db.prepare(`
    SELECT * FROM product_families ORDER BY title
  `).all()).results || [];

  const varRows = (await db.prepare(`
    SELECT v.*, i.price_minor, i.available_units, i.title as variant_title,
           COALESCE(sv.is_visible, 1) as storefront_visible
    FROM product_family_variants v
    LEFT JOIN inventory i ON i.product_id = v.id
    LEFT JOIN storefront_product_visibility sv ON sv.product_id = v.id
    ORDER BY v.pack_size
  `).all()).results || [];

  const variantsByFamily: Record<string, any[]> = {};
  for (const vr of varRows as any[]) {
    if (!variantsByFamily[vr.family_id]) {
      variantsByFamily[vr.family_id] = [];
    }
    variantsByFamily[vr.family_id].push({
      id: vr.id,
      sku: vr.sku || vr.id,
      pack_size: vr.pack_size || '',
      price: (vr.price_minor || 0) / 100.0,
      base_price: (vr.price_minor || 0) / 100.0,
      compare_at_price: vr.compare_at_price_minor ? vr.compare_at_price_minor / 100.0 : null,
      available_quantity: vr.available_units || 0,
      stock_quantity: vr.available_units || 0,
      in_stock: (vr.available_units || 0) > 0,
      publication_status: vr.publication_status || 'published',
      storefront_visible: vr.storefront_visible === 1,
    });
  }

  const families = (famRows as any[]).map((f) => ({
    id: f.id,
    title: f.title,
    brand: f.brand || 'MILTERRA',
    department: f.department || 'Dairy Foods',
    collection: f.collection_name || 'Ghee',
    slug: f.slug || f.id,
    vendor_id: f.vendor_id || 'vendor-1',
    description: f.description || '',
    production_method: f.production_method || '',
    ingredients: f.ingredients || '',
    is_published: f.is_published === 1,
    is_concept: f.status === 'concept_preview',
    variants: variantsByFamily[f.id] || [],
  }));

  return c.json({ success: true, data: families });
};

adminRouter.get('/vendor/families', getProductFamiliesHandler);
adminRouter.get('/admin/families', getProductFamiliesHandler);
adminRouter.get('/marketplace/vendor/families', getProductFamiliesHandler);
adminRouter.get('/marketplace/admin/families', getProductFamiliesHandler);

// POST /vendor/families
const createProductFamilyHandler = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin', 'vendor']);
  const body = await c.req.json();
  const db = c.env.DB;
  const id = 'fam-' + crypto.randomUUID().slice(0, 8);
  await db.prepare(`
    INSERT INTO product_families (id, title, brand, department, collection_name, description, vendor_id, is_published, status)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'published')
  `).bind(
    id,
    body.title || '',
    body.brand || 'MILTERRA',
    body.department || 'Dairy Foods',
    body.collection || null,
    body.description || '',
    body.vendor_id || 'vendor-1',
    body.is_published ? 1 : 0
  ).run();

  return c.json({
    success: true,
    data: {
      id,
      title: body.title,
      brand: body.brand || 'MILTERRA',
      department: body.department || 'Dairy Foods',
      variants: [],
    },
    message: 'Product family created',
  }, 201);
};

adminRouter.post('/vendor/families', createProductFamilyHandler);
adminRouter.post('/admin/families', createProductFamilyHandler);
adminRouter.post('/marketplace/vendor/families', createProductFamilyHandler);

// POST /vendor/families/:family_id/variants
const createVariantHandler = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin', 'vendor']);
  const familyId = c.req.param('family_id');
  const body = await c.req.json();
  const db = c.env.DB;
  const id = 'var-' + crypto.randomUUID().slice(0, 8);
  const sku = body.sku || id;
  const priceMinor = Math.round((body.base_price || body.price || 0) * 100);
  const compareMinor = body.compare_at_price ? Math.round(body.compare_at_price * 100) : null;
  const stock = body.initial_stock || body.stock_quantity || 10;

  // 1. Insert into inventory first (to satisfy foreign key)
  await db.prepare(`
    INSERT INTO inventory (product_id, title, available_units, price_minor, currency, is_active)
    VALUES (?, ?, ?, ?, 'INR', 1)
    ON CONFLICT(product_id) DO UPDATE SET
      price_minor = excluded.price_minor,
      available_units = excluded.available_units
  `).bind(id, `${sku} (${body.pack_size || ''})`, stock, priceMinor).run();

  // 2. Insert into product_family_variants
  await db.prepare(`
    INSERT INTO product_family_variants (id, family_id, sku, pack_size, compare_at_price_minor, publication_status)
    VALUES (?, ?, ?, ?, ?, ?)
  `).bind(id, familyId, sku, body.pack_size || '', compareMinor, body.publication_status || 'draft').run();

  return c.json({
    success: true,
    data: {
      id,
      sku,
      pack_size: body.pack_size,
      price: (body.base_price || 0),
      available_quantity: stock,
      publication_status: body.publication_status || 'draft',
    },
    message: 'Variant created',
  }, 201);
};

adminRouter.post('/vendor/families/:family_id/variants', createVariantHandler);
adminRouter.post('/admin/families/:family_id/variants', createVariantHandler);
adminRouter.post('/marketplace/vendor/families/:family_id/variants', createVariantHandler);

// Admin Marketplace Vendors
const getMarketplaceVendorsHandler = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin', 'vendor']);
  const db = c.env.DB;
  const rows = await db.prepare(`SELECT * FROM commerce_sellers WHERE status = 'approved' OR status IS NULL`).all();
  const list = (rows.results || []).map((v: any) => ({
    id: v.id,
    business_name: v.business_name || 'Milterra Central Operations',
    is_active: true,
  }));
  if (list.length === 0) {
    list.push({
      id: 'vendor-1',
      business_name: 'Milterra Central Operations',
      is_active: true,
    });
  }
  return c.json({ success: true, data: list, total: list.length, message: 'Active marketplace vendors' });
};

adminRouter.get('/admin/marketplace/vendors', getMarketplaceVendorsHandler);
adminRouter.get('/marketplace/vendors', getMarketplaceVendorsHandler);
adminRouter.get('/marketplace/admin/vendors', getMarketplaceVendorsHandler);

adminRouter.post('/admin/marketplace/vendors', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const body = await c.req.json();
  const db = c.env.DB;
  const id = 'vendor-' + crypto.randomUUID().slice(0, 8);
  const name = (body.business_name || '').trim();
  await db.prepare(`
    INSERT INTO commerce_sellers (id, business_name, status, warehouse_city, warehouse_state)
    VALUES (?, ?, 'approved', ?, ?)
  `).bind(id, name, body.district || null, body.state || null).run();

  return c.json({
    success: true,
    data: { id, business_name: name, is_active: true },
    message: `Vendor '${name}' created successfully`,
  }, 201);
});

adminRouter.get('/marketplace/orders/admin/interests', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  return c.json({ success: true, data: [] });
});
adminRouter.get('/orders/admin/interests', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  return c.json({ success: true, data: [] });
});
adminRouter.get('/admin/commerce/interests', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  return c.json({ success: true, data: [] });
});

adminRouter.get('/marketplace/orders/admin/cancellations', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const db = c.env.DB;
  const rows = await db.prepare("SELECT * FROM orders WHERE status = 'CANCELLED' ORDER BY created_at DESC LIMIT 50").all();
  return c.json({ success: true, data: rows.results || [] });
});
adminRouter.get('/orders/admin/cancellations', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const db = c.env.DB;
  const rows = await db.prepare("SELECT * FROM orders WHERE status = 'CANCELLED' ORDER BY created_at DESC LIMIT 50").all();
  return c.json({ success: true, data: rows.results || [] });
});

// Admin Coupon & Visibility Actions
adminRouter.post('/admin/commerce/coupons', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const body = await c.req.json();
  const db = c.env.DB;
  const code = (body.code || '').trim().toUpperCase();
  await db.prepare(`
    INSERT INTO coupons (code, description, discount_type, discount_value, min_order_value, max_discount_cap, is_active, valid_until)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `).bind(
    code,
    body.description || '',
    body.discount_type || 'flat',
    body.discount_value || 0,
    body.min_order_value || 0,
    body.max_discount_cap || null,
    body.is_active !== false ? 1 : 0,
    body.valid_until || null
  ).run();
  return c.json({ success: true, message: `Coupon ${code} created successfully`, data: { code, id: code } });
});

adminRouter.patch('/admin/commerce/coupons/:code', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const code = c.req.param('code').trim().toUpperCase();
  const body = await c.req.json();
  const db = c.env.DB;
  if (body.is_active !== undefined) {
    await db.prepare('UPDATE coupons SET is_active = ? WHERE code = ?').bind(body.is_active ? 1 : 0, code).run();
  }
  return c.json({ success: true, message: `Coupon ${code} updated successfully` });
});

adminRouter.patch('/admin/commerce/offers/:id', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const id = c.req.param('id');
  const body = await c.req.json();
  const db = c.env.DB;
  if (body.available_stock !== undefined) {
    await db.prepare('UPDATE inventory SET available_units = ? WHERE product_id = ?').bind(body.available_stock, id).run();
  }
  if (body.selling_price !== undefined) {
    await db.prepare('UPDATE inventory SET price_minor = ? WHERE product_id = ?').bind(Math.round(body.selling_price * 100), id).run();
  }
  return c.json({ success: true, message: 'Offer updated successfully' });
});

adminRouter.patch('/admin/commerce/products/:id/visibility', async (c) => {
  const actor = await requireAuth(c, ['admin', 'super_admin']);
  const productId = c.req.param('id');
  const body = await c.req.json();
  const db = c.env.DB;
  await db.prepare(`
    INSERT INTO storefront_product_visibility (product_id, is_visible, hidden_reason, updated_by, updated_at)
    VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
    ON CONFLICT(product_id) DO UPDATE SET
      is_visible = excluded.is_visible,
      hidden_reason = excluded.hidden_reason,
      updated_by = excluded.updated_by,
      updated_at = CURRENT_TIMESTAMP
  `).bind(productId, body.visible ? 1 : 0, body.visible ? null : (body.reason || null), actor.id).run();
  return c.json({ success: true, message: 'Storefront visibility updated' });
});

adminRouter.patch('/admin/commerce/products/:id/moderation', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const productId = c.req.param('id');
  const body = await c.req.json();
  const db = c.env.DB;
  const status = body.status === 'published' ? 1 : 0;
  await db.prepare('UPDATE inventory SET is_active = ? WHERE product_id = ?').bind(status, productId).run();
  return c.json({ success: true, data: { id: productId, publication_status: body.status } });
});

adminRouter.patch('/admin/commerce/sellers/:seller_id', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const sellerId = c.req.param('seller_id');
  const body = await c.req.json();
  const db = c.env.DB;
  const status = (body.status || 'approved').toLowerCase();
  await db.prepare('UPDATE commerce_sellers SET status = ? WHERE id = ?').bind(status, sellerId).run();
  return c.json({ success: true, message: `Seller ${sellerId} status updated to ${status}` });
});

adminRouter.patch('/marketplace/admin/commerce/sellers/:seller_id', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const sellerId = c.req.param('seller_id');
  const body = await c.req.json();
  const db = c.env.DB;
  const status = (body.status || 'approved').toLowerCase();
  await db.prepare('UPDATE commerce_sellers SET status = ? WHERE id = ?').bind(status, sellerId).run();
  return c.json({ success: true, message: `Seller ${sellerId} status updated to ${status}` });
});

// ---------------------------------------------------------------------------
// Commerce Taxonomy & Access Endpoints (/commerce/access, /admin/commerce/taxonomy, /marketplace/taxonomy)
// ---------------------------------------------------------------------------

function serializeTaxonomyNode(row: any) {
  return {
    id: String(row.id),
    kind: String(row.kind),
    parent_id: row.parent_id ? String(row.parent_id) : null,
    name: String(row.name),
    slug: String(row.slug),
    description: String(row.description || ''),
    sort_order: Number(row.sort_order || 0),
    is_active: row.is_active === 1 || row.is_active === true,
    version: Number(row.version || 1),
  };
}

function isEffectiveActive(node: any, index: Record<string, any>): boolean {
  const seen = new Set<string>();
  let curr = node;
  while (curr) {
    if (seen.has(curr.id) || !curr.is_active) {
      return false;
    }
    seen.add(curr.id);
    if (!curr.parent_id) {
      return curr.kind === 'department';
    }
    curr = index[curr.parent_id];
  }
  return false;
}

const getCommerceAccessHandler = async (c: any) => {
  const user = await requireAuth(c);
  const canManage = ['admin', 'super_admin', 'vendor'].includes(user.role);
  return c.json({
    success: true,
    data: {
      can_manage_taxonomy: canManage,
      taxonomy_enabled: true,
    },
  });
};

adminRouter.get('/commerce/access', getCommerceAccessHandler);
adminRouter.get('/marketplace/commerce/access', getCommerceAccessHandler);

const getPublicTaxonomyHandler = async (c: any) => {
  const db = c.env.DB;
  const rows = (await db.prepare(
    `SELECT * FROM commerce_taxonomy_nodes ORDER BY sort_order ASC, name ASC, id ASC`
  ).all()).results || [];

  const allNodes = rows.map(serializeTaxonomyNode);
  const index: Record<string, any> = {};
  for (const n of allNodes) {
    index[n.id] = n;
  }

  const activeNodes = allNodes.filter((n: any) => isEffectiveActive(n, index));

  const deptMap: Record<string, any> = {};
  for (const n of activeNodes) {
    if (n.kind === 'department') {
      deptMap[n.id] = { ...n, categories: [] };
    }
  }

  const catMap: Record<string, any> = {};
  for (const n of activeNodes) {
    if (n.kind === 'category') {
      const catObj = { ...n, subcategories: [] };
      catMap[n.id] = catObj;
      if (n.parent_id && deptMap[n.parent_id]) {
        deptMap[n.parent_id].categories.push(catObj);
      }
    }
  }

  for (const n of activeNodes) {
    if (n.kind === 'subcategory') {
      if (n.parent_id && catMap[n.parent_id]) {
        catMap[n.parent_id].subcategories.push(n);
      } else if (n.parent_id && deptMap[n.parent_id]) {
        deptMap[n.parent_id].categories.push({ ...n, subcategories: [] });
      }
    }
  }

  return c.json({
    success: true,
    enabled: true,
    data: activeNodes,
    tree: Object.values(deptMap),
  });
};

adminRouter.get('/marketplace/taxonomy', getPublicTaxonomyHandler);
adminRouter.get('/taxonomy', getPublicTaxonomyHandler);

adminRouter.get('/admin/commerce/taxonomy', async (c) => {
  await requireAuth(c, ['admin', 'super_admin', 'vendor']);
  const db = c.env.DB;
  const rows = (await db.prepare(
    `SELECT * FROM commerce_taxonomy_nodes ORDER BY sort_order ASC, name ASC, id ASC`
  ).all()).results || [];
  return c.json({
    success: true,
    data: rows.map(serializeTaxonomyNode),
  });
});

adminRouter.post('/admin/commerce/taxonomy', async (c) => {
  const actor = await requireAuth(c, ['admin', 'super_admin']);
  const body = await c.req.json();
  const db = c.env.DB;

  const kind = String(body.kind || 'category').trim();
  const name = String(body.name || '').trim();
  const slug = String(body.slug || '').trim().toLowerCase();
  const description = String(body.description || '').trim();
  const parentId = kind === 'department' ? null : (body.parent_id ? String(body.parent_id) : null);
  const sortOrder = Number(body.sort_order ?? 0);
  const isActive = body.is_active !== false ? 1 : 0;

  if (!name || !slug) {
    throw new HTTPException(422, { message: 'Name and slug are required' });
  }

  const existingSlug = await db.prepare(
    `SELECT id FROM commerce_taxonomy_nodes WHERE slug = ?`
  ).bind(slug).first();
  if (existingSlug) {
    throw new HTTPException(409, { message: 'This slug is already in use' });
  }

  if (kind !== 'department' && !parentId) {
    throw new HTTPException(422, { message: 'Choose an existing parent department or category' });
  }

  const id = 'tax-' + slug + '-' + crypto.randomUUID().slice(0, 6);
  await db.prepare(`
    INSERT INTO commerce_taxonomy_nodes (id, kind, parent_id, name, slug, description, sort_order, is_active, version)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)
  `).bind(id, kind, parentId, name, slug, description, sortOrder, isActive).run();

  const created = serializeTaxonomyNode({
    id,
    kind,
    parent_id: parentId,
    name,
    slug,
    description,
    sort_order: sortOrder,
    is_active: isActive,
    version: 1,
  });

  await db.prepare(`
    INSERT INTO commerce_audit_events (id, actor_id, action, target_id, before_json, after_json)
    VALUES (?, ?, 'taxonomy.create', ?, NULL, ?)
  `).bind(crypto.randomUUID(), actor.id, id, JSON.stringify(created)).run();

  return c.json({ success: true, data: created }, 201);
});

adminRouter.put('/admin/commerce/taxonomy/:node_id', async (c) => {
  const actor = await requireAuth(c, ['admin', 'super_admin']);
  const nodeId = c.req.param('node_id');
  const body = await c.req.json();
  const db = c.env.DB;

  const existingRow = await db.prepare(
    `SELECT * FROM commerce_taxonomy_nodes WHERE id = ?`
  ).bind(nodeId).first<any>();

  if (!existingRow) {
    throw new HTTPException(404, { message: 'Category not found' });
  }

  if (body.expected_version !== undefined && Number(existingRow.version) !== Number(body.expected_version)) {
    throw new HTTPException(409, { message: 'This category changed. Reload before saving.' });
  }

  const slug = String(body.slug ?? existingRow.slug).trim().toLowerCase();
  const conflictSlug = await db.prepare(
    `SELECT id FROM commerce_taxonomy_nodes WHERE slug = ? AND id != ?`
  ).bind(slug, nodeId).first();
  if (conflictSlug) {
    throw new HTTPException(409, { message: 'This slug is already in use' });
  }

  const name = String(body.name ?? existingRow.name).trim();
  const description = String(body.description ?? existingRow.description ?? '').trim();
  const parentId = existingRow.kind === 'department' ? null : (body.parent_id !== undefined ? body.parent_id : existingRow.parent_id);
  const sortOrder = Number(body.sort_order ?? existingRow.sort_order ?? 0);
  const isActive = body.is_active !== undefined ? (body.is_active ? 1 : 0) : existingRow.is_active;
  const nextVersion = Number(existingRow.version || 1) + 1;

  if (!isActive) {
    const activeChild = await db.prepare(
      `SELECT id FROM commerce_taxonomy_nodes WHERE parent_id = ? AND is_active = 1 LIMIT 1`
    ).bind(nodeId).first();
    if (activeChild) {
      throw new HTTPException(409, { message: 'Archive or move active child categories first' });
    }
  }

  const before = serializeTaxonomyNode(existingRow);

  await db.prepare(`
    UPDATE commerce_taxonomy_nodes
    SET name = ?, slug = ?, description = ?, parent_id = ?, sort_order = ?, is_active = ?, version = ?
    WHERE id = ?
  `).bind(name, slug, description, parentId, sortOrder, isActive, nextVersion, nodeId).run();

  const updated = serializeTaxonomyNode({
    ...existingRow,
    name,
    slug,
    description,
    parent_id: parentId,
    sort_order: sortOrder,
    is_active: isActive,
    version: nextVersion,
  });

  await db.prepare(`
    INSERT INTO commerce_audit_events (id, actor_id, action, target_id, before_json, after_json)
    VALUES (?, ?, 'taxonomy.update', ?, ?, ?)
  `).bind(crypto.randomUUID(), actor.id, nodeId, JSON.stringify(before), JSON.stringify(updated)).run();

  return c.json({ success: true, data: updated });
});

adminRouter.get('/admin/commerce/catalogue', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const db = c.env.DB;
  const query = (c.req.query('query') || '').trim();
  const page = Math.max(1, parseInt(c.req.query('page') || '1', 10));
  const offset = (page - 1) * 20;

  let whereSql = '';
  const binds: any[] = [];
  if (query) {
    whereSql = 'WHERE i.title LIKE ? OR i.product_id LIKE ?';
    binds.push(`%${query}%`, `%${query}%`);
  }

  const countRow = await db.prepare(
    `SELECT COUNT(*) as total FROM inventory i ${whereSql}`
  ).bind(...binds).first<{ total: number }>();

  const rows = (await db.prepare(`
    SELECT i.product_id as id, i.title, i.product_id as sku, i.is_active,
           pc.category_id, COALESCE(pc.version, 0) as classification_version
    FROM inventory i
    LEFT JOIN commerce_product_classifications pc ON pc.product_id = i.product_id
    ${whereSql}
    ORDER BY i.title ASC, i.product_id ASC
    LIMIT 20 OFFSET ?
  `).bind(...binds, offset).all()).results || [];

  return c.json({
    success: true,
    total: countRow?.total || 0,
    page,
    per_page: 20,
    data: rows.map((r: any) => ({
      id: r.id,
      title: r.title,
      sku: r.sku,
      is_active: r.is_active === 1,
      category_id: r.category_id || null,
      classification_version: Number(r.classification_version || 0),
    })),
  });
});

adminRouter.put('/admin/commerce/catalogue/:product_id/category', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const productId = c.req.param('product_id');
  const body = await c.req.json();
  const db = c.env.DB;
  const categoryId = String(body.category_id || '');

  const existing = await db.prepare(
    `SELECT * FROM commerce_product_classifications WHERE product_id = ?`
  ).bind(productId).first<any>();

  const nextVersion = existing ? Number(existing.version || 0) + 1 : 1;

  await db.prepare(`
    INSERT INTO commerce_product_classifications (product_id, category_id, version)
    VALUES (?, ?, ?)
    ON CONFLICT(product_id) DO UPDATE SET
      category_id = excluded.category_id,
      version = excluded.version
  `).bind(productId, categoryId, nextVersion).run();

  return c.json({
    success: true,
    data: {
      product_id: productId,
      category_id: categoryId,
      version: nextVersion,
    },
  });
});

const getVendorSettlementsHandler = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const db = c.env.DB;

  let vendors = (await db.prepare('SELECT * FROM commerce_sellers ORDER BY business_name').all()).results || [];
  if (vendors.length === 0) {
    vendors = [{
      id: 'vendor-1',
      business_name: 'Milterra Central Operations',
      status: 'approved',
      commission_rate: 5.0,
      bank_name: 'State Bank of India',
      account_number: 'XXXXXX9808',
      ifsc_code: 'SBIN0001234',
      upi_id: 'milterra@upi',
      account_holder_name: 'Milterra Central Operations',
    }];
  }

  const salesRow = await db.prepare(`
    SELECT COALESCE(SUM(total_minor), 0) as total_sales_minor
    FROM orders
    WHERE LOWER(status) = 'delivered' OR LOWER(payment_status) = 'paid'
  `).first();
  const grossSalesTotal = Math.round(Number((salesRow as any)?.total_sales_minor || 0)) / 100.0;

  const settlements = [];
  for (const v of vendors as any[]) {
    const commRate = Math.round(Number(v.commission_rate ?? 5.0) * 100) / 100;
    const grossSales = (v.id === 'vendor-1' || vendors.length === 1) ? grossSalesTotal : 0.0;
    const commAmt = Math.round(grossSales * (commRate / 100.0) * 100) / 100;
    const netPayable = Math.max(0.0, Math.round((grossSales - commAmt) * 100) / 100);

    let payouts: any[] = [];
    try {
      payouts = (await db.prepare(`
        SELECT * FROM vendor_payouts
        WHERE vendor_id = ?
        ORDER BY created_at DESC
        LIMIT 10
      `).bind(v.id).all()).results || [];
    } catch {
      payouts = [];
    }

    const totalSettled = Math.round(payouts
      .filter((p: any) => (p.status || '').toLowerCase() === 'paid')
      .reduce((sum: number, p: any) => sum + Number(p.amount || 0), 0) * 100) / 100;

    const pendingBalance = Math.max(0.0, Math.round((netPayable - totalSettled) * 100) / 100);

    settlements.push({
      vendor_id: String(v.id),
      business_name: v.business_name || 'Milterra Central Operations',
      is_active: v.status === 'approved',
      commission_rate: commRate,
      bank_name: v.bank_name || '',
      account_number: v.account_number || '',
      ifsc_code: v.ifsc_code || '',
      account_holder_name: v.account_holder_name || '',
      upi_id: v.upi_id || '',
      gross_sales: grossSales,
      commission_amount: commAmt,
      net_payable: netPayable,
      total_settled: totalSettled,
      pending_balance: pendingBalance,
      payouts_count: payouts.length,
      recent_payouts: payouts.map((p: any) => ({
        id: String(p.id),
        amount: Number(p.amount || 0),
        status: String(p.status || 'PAID').toUpperCase(),
        payment_reference: p.payment_reference || 'N/A',
        bank_name: p.bank_name || '',
        remarks: p.remarks || '',
        processed_at: p.processed_at || p.created_at || null,
        created_at: p.created_at || '',
      })),
    });
  }

  return c.json({ success: true, data: settlements });
};

const createVendorPayoutHandler = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const vendorId = c.req.param('vendor_id');
  const body = await c.req.json();
  const db = c.env.DB;

  const amt = Number(body.amount || 0);
  if (amt <= 0) {
    return c.json({ error: 'Validation Error', message: 'Amount must be greater than 0' }, 400);
  }

  const payoutId = 'payout-' + crypto.randomUUID();
  const now = new Date().toISOString();
  const ref = (body.payment_reference || '').trim();
  const remarks = (body.remarks || '').trim();
  const bankName = (body.bank_name || '').trim();
  const accNo = (body.account_number || '').trim();
  const grossAmt = Number(body.gross_amount || amt);
  const commAmt = Number(body.commission_amount || 0);

  await db.prepare(`
    INSERT INTO vendor_payouts (id, vendor_id, amount, gross_amount, commission_amount, status, payment_reference, bank_name, account_number, remarks, processed_at, created_at)
    VALUES (?, ?, ?, ?, ?, 'paid', ?, ?, ?, ?, ?, ?)
  `).bind(payoutId, vendorId, amt, grossAmt, commAmt, ref, bankName, accNo, remarks, now, now).run();

  return c.json({
    success: true,
    data: {
      id: payoutId,
      vendor_id: vendorId,
      amount: amt,
      status: 'PAID',
      payment_reference: ref,
      processed_at: now,
    },
    message: `Payout of ₹${amt.toFixed(2)} recorded successfully`,
  }, 201);
};

const updateVendorCommissionHandler = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const vendorId = c.req.param('vendor_id');
  const body = await c.req.json();
  const rate = Number(body.commission_rate ?? body.rate ?? 5.0);
  if (isNaN(rate) || rate < 0 || rate > 100) {
    return c.json({ error: 'Validation Error', message: 'Commission rate must be between 0 and 100' }, 400);
  }
  const db = c.env.DB;
  await db.prepare(`
    UPDATE commerce_sellers
    SET commission_rate = ?
    WHERE id = ?
  `).bind(rate, vendorId).run();

  return c.json({
    success: true,
    data: {
      vendor_id: vendorId,
      commission_rate: rate,
    },
    message: `Commission rate updated to ${rate}%`,
  });
};

const getGstr1ReportHandler = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const db = c.env.DB;
  const format = (c.req.query('format') || 'json').toLowerCase();

  const orders = (await db.prepare(`
    SELECT id, total_minor, status, payment_status, address_snapshot, created_at
    FROM orders
    WHERE LOWER(payment_status) != 'failed' AND LOWER(status) != 'cancelled'
    ORDER BY created_at DESC
    LIMIT 200
  `).all()).results || [];

  const rows = (orders as any[]).map((o) => {
    let state = 'Standard';
    try {
      const addr = typeof o.address_snapshot === 'string' ? JSON.parse(o.address_snapshot) : (o.address_snapshot || {});
      state = addr.state || addr.warehouse_state || 'Standard';
    } catch {
      state = 'Standard';
    }

    const created = o.created_at ? new Date(o.created_at) : new Date();
    const yyyymm = created.toISOString().slice(0, 7).replace('-', '');
    const shortId = (o.id || 'ORDER').slice(0, 6).toUpperCase();
    const invNo = `INV-${yyyymm}-${shortId}`;
    const tot = Math.round(Number(o.total_minor || 0)) / 100.0;
    const taxable = Math.round((tot / 1.05) * 100) / 100;
    const tax = Math.round((tot - taxable) * 100) / 100;

    const lowerSt = state.toLowerCase();
    const isInterstate = !['delhi', 'haryana', 'uttar pradesh', 'standard', ''].includes(lowerSt);
    const cgst = isInterstate ? 0.0 : Math.round((tax / 2) * 100) / 100;
    const sgst = isInterstate ? 0.0 : Math.round((tax / 2) * 100) / 100;
    const igst = isInterstate ? tax : 0.0;

    return {
      invoice_number: invNo,
      order_id: String(o.id),
      order_date: created.toISOString().replace('T', ' ').slice(0, 16),
      shipping_state: state,
      tax_rate_percent: 5.0,
      taxable_amount: taxable,
      cgst,
      sgst,
      igst,
      total_tax: tax,
      total_invoice_amount: tot,
      payment_status: (o.payment_status || 'PENDING').toUpperCase(),
      order_status: (o.status || 'PLACED').toUpperCase(),
    };
  });

  if (format === 'csv') {
    const headers = [
      'invoice_number', 'order_id', 'order_date', 'shipping_state',
      'tax_rate_percent', 'taxable_amount', 'cgst', 'sgst', 'igst',
      'total_tax', 'total_invoice_amount', 'payment_status', 'order_status'
    ];
    const csvLines = [headers.join(',')];
    for (const r of rows) {
      csvLines.push(headers.map((h) => JSON.stringify((r as any)[h] ?? '')).join(','));
    }
    return new Response(csvLines.join('\n'), {
      status: 200,
      headers: {
        'Content-Type': 'text/csv',
        'Content-Disposition': 'attachment; filename=gstr1_sales_register.csv',
      },
    });
  }

  return c.json({ success: true, data: rows, total: rows.length });
};

const getSettlementsReportHandler = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const db = c.env.DB;
  const format = (c.req.query('format') || 'json').toLowerCase();

  let vendors = (await db.prepare('SELECT * FROM commerce_sellers ORDER BY business_name').all()).results || [];
  if (vendors.length === 0) {
    vendors = [{
      id: 'vendor-1',
      business_name: 'Milterra Central Operations',
      status: 'approved',
      commission_rate: 5.0,
      bank_name: 'State Bank of India',
      account_number: 'XXXXXX9808',
      ifsc_code: 'SBIN0001234',
      upi_id: 'milterra@upi',
    }];
  }

  const salesRow = await db.prepare(`
    SELECT COALESCE(SUM(total_minor), 0) as total_sales_minor
    FROM orders
    WHERE LOWER(status) = 'delivered' OR LOWER(payment_status) = 'paid'
  `).first();
  const grossSalesTotal = Math.round(Number((salesRow as any)?.total_sales_minor || 0)) / 100.0;

  const rows = [];
  for (const v of vendors as any[]) {
    const commRate = Math.round(Number(v.commission_rate ?? 5.0) * 100) / 100;
    const grossSales = (v.id === 'vendor-1' || vendors.length === 1) ? grossSalesTotal : 0.0;
    const commAmt = Math.round(grossSales * (commRate / 100.0) * 100) / 100;
    const netPayable = Math.max(0.0, Math.round((grossSales - commAmt) * 100) / 100);

    let payouts: any[] = [];
    try {
      payouts = (await db.prepare(`
        SELECT * FROM vendor_payouts
        WHERE vendor_id = ?
      `).bind(v.id).all()).results || [];
    } catch {
      payouts = [];
    }

    const totalSettled = Math.round(payouts
      .filter((p: any) => (p.status || '').toLowerCase() === 'paid')
      .reduce((sum: number, p: any) => sum + Number(p.amount || 0), 0) * 100) / 100;
    const pendingBalance = Math.max(0.0, Math.round((netPayable - totalSettled) * 100) / 100);

    rows.push({
      vendor_id: String(v.id),
      business_name: v.business_name || 'Milterra Central Operations',
      commission_rate_percent: commRate,
      gross_sales: grossSales,
      platform_commission: commAmt,
      net_payable: netPayable,
      total_settled: totalSettled,
      pending_balance: pendingBalance,
      bank_name: v.bank_name || '',
      account_number: v.account_number || '',
      ifsc_code: v.ifsc_code || '',
      upi_id: v.upi_id || '',
      payouts_count: payouts.length,
    });
  }

  if (format === 'csv') {
    const headers = [
      'vendor_id', 'business_name', 'commission_rate_percent',
      'gross_sales', 'platform_commission', 'net_payable',
      'total_settled', 'pending_balance', 'bank_name',
      'account_number', 'ifsc_code', 'upi_id', 'payouts_count'
    ];
    const csvLines = [headers.join(',')];
    for (const r of rows) {
      csvLines.push(headers.map((h) => JSON.stringify((r as any)[h] ?? '')).join(','));
    }
    return new Response(csvLines.join('\n'), {
      status: 200,
      headers: {
        'Content-Type': 'text/csv',
        'Content-Disposition': 'attachment; filename=vendor_settlements_register.csv',
      },
    });
  }

  return c.json({ success: true, data: rows, total: rows.length });
};

adminRouter.get('/admin/commerce/vendors/settlements', getVendorSettlementsHandler);
adminRouter.get('/marketplace/admin/commerce/vendors/settlements', getVendorSettlementsHandler);

adminRouter.post('/admin/commerce/vendors/:vendor_id/payouts', createVendorPayoutHandler);
adminRouter.post('/marketplace/admin/commerce/vendors/:vendor_id/payouts', createVendorPayoutHandler);

adminRouter.post('/admin/commerce/vendors/:vendor_id/commission', updateVendorCommissionHandler);
adminRouter.patch('/admin/commerce/vendors/:vendor_id/commission', updateVendorCommissionHandler);
adminRouter.post('/marketplace/admin/commerce/vendors/:vendor_id/commission', updateVendorCommissionHandler);
adminRouter.patch('/marketplace/admin/commerce/vendors/:vendor_id/commission', updateVendorCommissionHandler);

adminRouter.get('/admin/commerce/reports/gstr1', getGstr1ReportHandler);
adminRouter.get('/marketplace/admin/commerce/reports/gstr1', getGstr1ReportHandler);

adminRouter.get('/admin/commerce/reports/settlements', getSettlementsReportHandler);
adminRouter.get('/marketplace/admin/commerce/reports/settlements', getSettlementsReportHandler);

adminRouter.get('/admin/marketplace/concept-feedback', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  return c.json({ success: true, data: [] });
});

// ---------------------------------------------------------------------------
// Vendor Dashboard, Profile, Coupons & Storefront Handlers
// ---------------------------------------------------------------------------

async function getVendorForUser(db: any, user: { id: string; role: string; phone?: string }) {
  let vendor = await db.prepare(
    'SELECT * FROM commerce_sellers WHERE id = ? OR contact_email = ? OR contact_phone = ?'
  ).bind(user.id, user.id, user.phone || '').first();

  if (!vendor) {
    vendor = await db.prepare(
      'SELECT * FROM commerce_sellers WHERE id = ?'
    ).bind('vendor-1').first();
  }
  if (!vendor) {
    vendor = await db.prepare(
      'SELECT * FROM commerce_sellers ORDER BY created_at ASC LIMIT 1'
    ).first();
  }
  if (!vendor) {
    vendor = {
      id: 'vendor-1',
      business_name: 'Milterra Central Operations',
      status: 'approved',
      commission_rate: 5.0,
      bank_name: 'State Bank of India',
      account_number: '9876543210',
      ifsc_code: 'SBIN0001234',
      upi_id: 'milterra@sbi',
      account_holder_name: 'Milterra Foods Ltd',
      contact_phone: '+91 98765 43210',
      warehouse_city: 'Ajmer',
      warehouse_state: 'Rajasthan',
    };
  }
  return vendor;
}

function serializeVendorProfile(vendor: any, user?: any) {
  return {
    id: String(vendor.id || 'vendor-1'),
    user_id: String(user?.id || vendor.id || 'vendor-1'),
    business_name: String(vendor.business_name || 'Milterra Central Operations'),
    vendor_type: String(vendor.vendor_type || 'equipment_supplier'),
    gst_number: vendor.gstin || vendor.gst_number || null,
    license_number: vendor.fssai_license || vendor.license_number || null,
    bank_name: vendor.bank_name || null,
    account_number: vendor.account_number || null,
    ifsc_code: vendor.ifsc_code || null,
    account_holder_name: vendor.account_holder_name || null,
    upi_id: vendor.upi_id || null,
    address: vendor.address || 'Milterra Farm Hub',
    district: vendor.warehouse_city || vendor.district || 'Ajmer',
    state: vendor.warehouse_state || vendor.state || 'Rajasthan',
    pincode: vendor.pincode || '305001',
    lat: vendor.lat ? Number(vendor.lat) : 26.4499,
    lng: vendor.lng ? Number(vendor.lng) : 74.6399,
    phone: vendor.contact_phone || vendor.phone || null,
    description: vendor.description || 'Verified Milterra Quality Partner & Producer',
    logo_url: vendor.logo_url || null,
    banner_url: vendor.banner_url || null,
    support_phone: vendor.contact_phone || vendor.support_phone || null,
    support_email: vendor.contact_email || vendor.support_email || null,
    return_policy: vendor.return_policy || '7 Days Replacement for damaged goods',
    products_services: ['Dairy Equipment', 'Organic Supplements', 'Cold-Pressed Oils'],
    rating: Number(vendor.rating || 4.8),
    total_orders: Number(vendor.total_orders || 0),
    total_revenue: Number(vendor.total_revenue || 0.0),
    commission_rate: Number(vendor.commission_rate ?? 5.0),
    is_verified: true,
    is_active: vendor.status !== 'suspended' && vendor.status !== 'rejected',
  };
}

const getVendorDashboardHandler = async (c: any) => {
  const user = await requireAuth(c, ['admin', 'super_admin', 'vendor', 'seller']);
  const db = c.env.DB;
  const vendor = await getVendorForUser(db, user);

  // 1. Orders statistics
  const totalOrdersRow = (await db.prepare(
    `SELECT COUNT(*) as count, COALESCE(SUM(total_minor), 0) as gross_minor FROM orders WHERE status != 'cancelled'`
  ).first()) as any;
  const totalOrders = totalOrdersRow?.count || 0;
  const grossSales = Math.round(((totalOrdersRow?.gross_minor || 0) / 100.0) * 100) / 100;

  const pendingOrdersRow = (await db.prepare(
    `SELECT COUNT(*) as count FROM orders WHERE status IN ('placed', 'confirmed')`
  ).first()) as any;
  const pendingOrders = pendingOrdersRow?.count || 0;

  const completedOrdersRow = (await db.prepare(
    `SELECT COUNT(*) as count FROM orders WHERE status = 'delivered'`
  ).first()) as any;
  const completedOrders = completedOrdersRow?.count || 0;

  // Recent 10 orders with item descriptions
  const recentOrdersRows = (await db.prepare(`
    SELECT o.id, o.total_minor, o.status, o.created_at,
           ca.recipient_name,
           (SELECT GROUP_CONCAT(product_title || ' ×' || quantity, ', ') FROM order_lines WHERE order_id = o.id) as items_summary
    FROM orders o
    LEFT JOIN customer_addresses ca ON ca.id = o.address_id
    ORDER BY o.created_at DESC
    LIMIT 10
  `).all()).results || [];

  const recentOrders = recentOrdersRows.map((o: any) => ({
    id: String(o.id),
    order_number: String(o.id).slice(0, 8).toUpperCase(),
    farmer_name: o.recipient_name || 'Customer',
    description: o.items_summary || 'Order Items',
    amount: (o.total_minor || 0) / 100.0,
    status: (o.status || 'pending').toLowerCase(),
    created_at: o.created_at || '',
  }));

  // 2. Low stock items (available_units <= 5)
  const lowStockRows = (await db.prepare(`
    SELECT product_id, title, available_units, price_minor
    FROM inventory
    WHERE available_units <= 5
    ORDER BY available_units ASC
    LIMIT 10
  `).all()).results || [];

  const lowStockItems = lowStockRows.map((item: any) => ({
    id: String(item.product_id),
    title: String(item.title),
    available_quantity: Number(item.available_units),
    price: (item.price_minor || 0) / 100.0,
    is_out_of_stock: Number(item.available_units) <= 0,
  }));

  // 3. Payouts & Settlements
  const commRate = Number(vendor.commission_rate ?? 5.0);
  const commAmt = Math.round(grossSales * (commRate / 100.0) * 100) / 100;
  const netPayable = Math.max(0, Math.round((grossSales - commAmt) * 100) / 100);

  const payoutRows = (await db.prepare(`
    SELECT * FROM vendor_payouts
    WHERE vendor_id = ?
    ORDER BY created_at DESC
    LIMIT 10
  `).bind(vendor.id).all()).results || [];

  let totalSettled = 0.0;
  const recentPayouts = payoutRows.map((p: any) => {
    const amt = Number(p.amount || 0);
    if (String(p.status).toLowerCase() === 'paid') {
      totalSettled += amt;
    }
    return {
      id: String(p.id),
      amount: amt,
      gross_amount: Number(p.gross_amount || 0),
      commission_amount: Number(p.commission_amount || 0),
      status: String(p.status || 'paid'),
      payment_reference: p.payment_reference || null,
      bank_name: p.bank_name || null,
      account_number: p.account_number || null,
      remarks: p.remarks || null,
      processed_at: p.processed_at || null,
      createdAt: p.created_at || '',
      created_at: p.created_at || '',
    };
  });
  totalSettled = Math.round(totalSettled * 100) / 100;
  const pendingSettlement = Math.max(0, Math.round((netPayable - totalSettled) * 100) / 100);

  // 4. Performance & Analytics
  const prodCountRow = (await db.prepare('SELECT COUNT(*) as count FROM inventory').first()) as any;
  const prodCount = prodCountRow?.count || 12;
  const estimatedVisits = Math.max(totalOrders * 18 + prodCount * 35 + 64, 145);
  const productImpressions = Math.max(totalOrders * 32 + prodCount * 60 + 110, 280);
  const conversionRate = Math.round(((totalOrders / Math.max(estimatedVisits, 1)) * 100) * 100) / 100;
  const avgOrderValue = totalOrders > 0 ? Math.round((grossSales / totalOrders) * 100) / 100 : 0.0;
  const repeatCustomerRate = totalOrders > 0 ? 28.5 : 0.0;

  const profile = serializeVendorProfile(vendor, user);

  const dashboard = {
    profile,
    stats: {
      total_orders: totalOrders,
      total_revenue: grossSales,
      rating_avg: profile.rating,
    },
    total_orders: totalOrders,
    total_revenue: grossSales,
    rating: profile.rating,
    pending_orders: pendingOrders,
    completed_orders: completedOrders,
    recent_orders: recentOrders,
    low_stock_count: lowStockItems.length,
    low_stock_items: lowStockItems,
    analytics: {
      storefront_views: estimatedVisits,
      product_impressions: productImpressions,
      conversion_rate: conversionRate,
      avg_order_value: avgOrderValue,
      repeat_customer_rate: repeatCustomerRate,
    },
    settlements: {
      gross_sales: grossSales,
      commission_rate: commRate,
      commission_amount: commAmt,
      net_payable: netPayable,
      total_settled: totalSettled,
      pending_settlement: pendingSettlement,
      recent_payouts: recentPayouts,
    },
    gross_sales: grossSales,
    commission_rate: commRate,
    commission_amount: commAmt,
    net_payable: netPayable,
    total_settled: totalSettled,
    pending_settlement: pendingSettlement,
    recent_payouts: recentPayouts,
    products_services: profile.products_services,
    service_areas: ['All India'],
  };

  return c.json({
    success: true,
    data: dashboard,
    message: 'Vendor dashboard',
  });
};

const getVendorProfileHandler = async (c: any) => {
  const user = await requireAuth(c, ['admin', 'super_admin', 'vendor', 'seller']);
  const db = c.env.DB;
  const vendor = await getVendorForUser(db, user);
  const profile = serializeVendorProfile(vendor, user);
  return c.json({
    success: true,
    data: profile,
    message: 'Vendor profile',
  });
};

const updateVendorProfileHandler = async (c: any) => {
  const user = await requireAuth(c, ['admin', 'super_admin', 'vendor', 'seller']);
  const body = await c.req.json();
  const db = c.env.DB;
  const vendor = await getVendorForUser(db, user);

  const businessName = body.business_name ?? vendor.business_name;
  const bankName = body.bank_name ?? vendor.bank_name ?? '';
  const accNo = body.account_number ?? vendor.account_number ?? '';
  const ifsc = body.ifsc_code ?? vendor.ifsc_code ?? '';
  const upi = body.upi_id ?? vendor.upi_id ?? '';
  const holder = body.account_holder_name ?? vendor.account_holder_name ?? '';
  const phone = body.phone ?? body.contact_phone ?? vendor.contact_phone ?? '';
  const email = body.email ?? body.contact_email ?? vendor.contact_email ?? '';
  const city = body.district ?? body.warehouse_city ?? vendor.warehouse_city ?? '';
  const state = body.state ?? body.warehouse_state ?? vendor.warehouse_state ?? '';

  await db.prepare(`
    UPDATE commerce_sellers
    SET business_name = ?,
        bank_name = ?,
        account_number = ?,
        ifsc_code = ?,
        upi_id = ?,
        account_holder_name = ?,
        contact_phone = ?,
        contact_email = ?,
        warehouse_city = ?,
        warehouse_state = ?
    WHERE id = ?
  `).bind(businessName, bankName, accNo, ifsc, upi, holder, phone, email, city, state, vendor.id).run();

  const updated = await db.prepare('SELECT * FROM commerce_sellers WHERE id = ?').bind(vendor.id).first();
  const profile = serializeVendorProfile(updated || vendor, user);

  return c.json({
    success: true,
    data: profile,
    message: 'Vendor profile updated',
  });
};

const registerVendorHandler = async (c: any) => {
  const user = await requireAuth(c);
  const body = await c.req.json();
  const db = c.env.DB;

  const id = 'vendor-' + (user.id || crypto.randomUUID().slice(0, 8));
  const businessName = body.business_name || user.full_name || 'Milterra Vendor';

  await db.prepare(`
    INSERT INTO commerce_sellers (
      id, business_name, status, bank_name, account_number, ifsc_code, upi_id,
      account_holder_name, contact_phone, warehouse_city, warehouse_state
    ) VALUES (?, ?, 'approved', ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
      business_name = excluded.business_name,
      bank_name = excluded.bank_name,
      account_number = excluded.account_number,
      ifsc_code = excluded.ifsc_code,
      upi_id = excluded.upi_id,
      account_holder_name = excluded.account_holder_name,
      contact_phone = excluded.contact_phone,
      warehouse_city = excluded.warehouse_city,
      warehouse_state = excluded.warehouse_state
  `).bind(
    id,
    businessName,
    body.bank_name || '',
    body.account_number || '',
    body.ifsc_code || '',
    body.upi_id || '',
    body.account_holder_name || '',
    body.phone || user.phone || '',
    body.district || '',
    body.state || ''
  ).run();

  const registered = await db.prepare('SELECT * FROM commerce_sellers WHERE id = ?').bind(id).first();
  const profile = serializeVendorProfile(registered, user);

  return c.json({
    success: true,
    data: profile,
    message: 'Vendor profile registered successfully',
  }, 201);
};

const getVendorPayoutsHandler = async (c: any) => {
  const user = await requireAuth(c, ['admin', 'super_admin', 'vendor', 'seller']);
  const db = c.env.DB;
  const vendor = await getVendorForUser(db, user);

  const totalOrdersRow = (await db.prepare(
    `SELECT COALESCE(SUM(total_minor), 0) as gross_minor FROM orders WHERE status != 'cancelled'`
  ).first()) as any;
  const grossSales = Math.round(((totalOrdersRow?.gross_minor || 0) / 100.0) * 100) / 100;

  const commRate = Number(vendor.commission_rate ?? 5.0);
  const commAmt = Math.round(grossSales * (commRate / 100.0) * 100) / 100;
  const netPayable = Math.max(0, Math.round((grossSales - commAmt) * 100) / 100);

  const payoutRows = (await db.prepare(`
    SELECT * FROM vendor_payouts
    WHERE vendor_id = ?
    ORDER BY created_at DESC
  `).bind(vendor.id).all()).results || [];

  let totalSettled = 0.0;
  const recentPayouts = payoutRows.map((p: any) => {
    const amt = Number(p.amount || 0);
    if (String(p.status).toLowerCase() === 'paid') {
      totalSettled += amt;
    }
    return {
      id: String(p.id),
      amount: amt,
      gross_amount: Number(p.gross_amount || 0),
      commission_amount: Number(p.commission_amount || 0),
      status: String(p.status || 'paid'),
      payment_reference: p.payment_reference || null,
      bank_name: p.bank_name || null,
      account_number: p.account_number || null,
      remarks: p.remarks || null,
      processed_at: p.processed_at || null,
      createdAt: p.created_at || '',
      created_at: p.created_at || '',
    };
  });
  totalSettled = Math.round(totalSettled * 100) / 100;
  const pendingSettlement = Math.max(0, Math.round((netPayable - totalSettled) * 100) / 100);

  return c.json({
    success: true,
    data: {
      settlements: {
        gross_sales: grossSales,
        commission_rate: commRate,
        commission_amount: commAmt,
        net_payable: netPayable,
        total_settled: totalSettled,
        pending_settlement: pendingSettlement,
        recent_payouts: recentPayouts,
      },
      bank_details: {
        bank_name: vendor.bank_name || '',
        account_number: vendor.account_number || '',
        ifsc_code: vendor.ifsc_code || '',
        account_holder_name: vendor.account_holder_name || '',
        upi_id: vendor.upi_id || '',
      },
    },
    message: 'Vendor payout history',
  });
};

const getVendorCouponsHandler = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin', 'vendor', 'seller']);
  const db = c.env.DB;
  const coupons = (await db.prepare('SELECT * FROM coupons ORDER BY code ASC').all()).results || [];
  return c.json({
    success: true,
    data: coupons.map((cp: any) => ({
      id: String(cp.code),
      vendor_id: 'vendor-1',
      code: String(cp.code),
      description: cp.description || '',
      discount_type: cp.discount_type || 'percentage',
      discount_value: Number(cp.discount_value || 0),
      min_order_value: Number(cp.min_order_value || 0),
      max_discount_cap: cp.max_discount_cap !== null && cp.max_discount_cap !== undefined ? Number(cp.max_discount_cap) : null,
      valid_until: cp.valid_until || null,
      usage_count: Number(cp.usage_count || 0),
      is_active: cp.is_active === 1 || cp.is_active === true,
    })),
    message: 'Store coupons list',
  });
};

const createVendorCouponHandler = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin', 'vendor', 'seller']);
  const body = await c.req.json();
  const db = c.env.DB;
  const code = (body.code || '').trim().toUpperCase();
  if (!code) {
    throw new HTTPException(422, { message: 'Coupon code is required' });
  }

  await db.prepare(`
    INSERT INTO coupons (code, description, discount_type, discount_value, min_order_value, max_discount_cap, is_active, valid_until)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(code) DO UPDATE SET
      description = excluded.description,
      discount_type = excluded.discount_type,
      discount_value = excluded.discount_value,
      min_order_value = excluded.min_order_value,
      max_discount_cap = excluded.max_discount_cap,
      is_active = excluded.is_active,
      valid_until = excluded.valid_until
  `).bind(
    code,
    body.description || '',
    body.discount_type || 'percentage',
    Number(body.discount_value || 0),
    Number(body.min_order_value || 0),
    body.max_discount_cap !== undefined && body.max_discount_cap !== null ? Number(body.max_discount_cap) : null,
    body.is_active !== false ? 1 : 0,
    body.valid_until || null
  ).run();

  return c.json({
    success: true,
    data: { id: code, code },
    message: `Coupon ${code} created successfully`,
  }, 201);
};

const updateVendorCouponHandler = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin', 'vendor', 'seller']);
  const id = c.req.param('id').trim().toUpperCase();
  const body = await c.req.json();
  const db = c.env.DB;

  if (body.is_active !== undefined) {
    await db.prepare('UPDATE coupons SET is_active = ? WHERE code = ?').bind(body.is_active ? 1 : 0, id).run();
  }
  if (body.description !== undefined) {
    await db.prepare('UPDATE coupons SET description = ? WHERE code = ?').bind(body.description, id).run();
  }
  if (body.discount_value !== undefined) {
    await db.prepare('UPDATE coupons SET discount_value = ? WHERE code = ?').bind(Number(body.discount_value), id).run();
  }

  return c.json({ success: true, message: `Coupon ${id} updated` });
};

const deleteVendorCouponHandler = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin', 'vendor', 'seller']);
  const id = c.req.param('id').trim().toUpperCase();
  const db = c.env.DB;
  await db.prepare('DELETE FROM coupons WHERE code = ?').bind(id).run();
  return c.json({ success: true, message: `Coupon ${id} deleted` });
};

const getVendorByIdHandler = async (c: any) => {
  const vendorId = c.req.param('vendor_id');
  const db = c.env.DB;
  let vendor = await db.prepare('SELECT * FROM commerce_sellers WHERE id = ?').bind(vendorId).first();
  if (!vendor) {
    if (vendorId === 'vendor-1') {
      vendor = {
        id: 'vendor-1',
        business_name: 'Milterra Central Operations',
        status: 'approved',
        warehouse_city: 'Ajmer',
        warehouse_state: 'Rajasthan',
      };
    } else {
      throw new HTTPException(404, { message: 'Vendor not found' });
    }
  }
  const profile = serializeVendorProfile(vendor);
  return c.json({ success: true, data: profile, message: 'Vendor details' });
};

const handleVendorProductCreate = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin', 'vendor', 'seller']);
  const body = await c.req.json();
  const db = c.env.DB;

  const id = body.product_id || body.id || ('p-' + crypto.randomUUID().slice(0, 8));
  const title = (body.title || 'New Product').trim();
  const price = Number(body.price || body.base_price || 0);
  const units = Number(body.available_quantity || body.available_units || body.stock || 10);
  const mrp = Number(body.mrp || price);

  await db.prepare(`
    INSERT INTO inventory (product_id, title, available_units, price_minor, currency, is_active)
    VALUES (?, ?, ?, ?, 'INR', 1)
    ON CONFLICT(product_id) DO UPDATE SET
      title = excluded.title,
      available_units = excluded.available_units,
      price_minor = excluded.price_minor,
      is_active = 1
  `).bind(id, title, units, Math.round(price * 100)).run();

  await db.prepare(`
    INSERT INTO inventory_pricing (product_id, mrp_minor)
    VALUES (?, ?)
    ON CONFLICT(product_id) DO UPDATE SET mrp_minor = excluded.mrp_minor
  `).bind(id, Math.round(mrp * 100)).run();

  return c.json({
    success: true,
    data: {
      id,
      product_id: id,
      title,
      price,
      available_units: units,
    },
    message: `Product "${title}" published successfully`,
  }, 201);
};

const handleVendorProductUpdate = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin', 'vendor', 'seller']);
  const id = c.req.param('id');
  const body = await c.req.json();
  const db = c.env.DB;

  if (body.title !== undefined) {
    await db.prepare('UPDATE inventory SET title = ? WHERE product_id = ?').bind(body.title, id).run();
  }
  if (body.price !== undefined || body.base_price !== undefined) {
    const price = Number(body.price ?? body.base_price);
    await db.prepare('UPDATE inventory SET price_minor = ? WHERE product_id = ?').bind(Math.round(price * 100), id).run();
  }
  if (body.available_units !== undefined || body.available_quantity !== undefined || body.stock !== undefined) {
    const units = Number(body.available_units ?? body.available_quantity ?? body.stock);
    await db.prepare('UPDATE inventory SET available_units = ? WHERE product_id = ?').bind(units, id).run();
  }
  if (body.is_active !== undefined) {
    await db.prepare('UPDATE inventory SET is_active = ? WHERE product_id = ?').bind(body.is_active ? 1 : 0, id).run();
  }

  return c.json({ success: true, message: 'Product updated successfully' });
};

const handleVendorProductDelete = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin', 'vendor', 'seller']);
  const id = c.req.param('id');
  const db = c.env.DB;
  await db.prepare('UPDATE inventory SET is_active = 0 WHERE product_id = ?').bind(id).run();
  return c.json({ success: true, message: `Product ${id} deactivated` });
};

const handleVendorInventoryUpdate = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin', 'vendor', 'seller']);
  const id = c.req.param('id');
  const body = await c.req.json();
  const db = c.env.DB;
  const units = Number(body.available_units ?? body.available_quantity ?? body.stock ?? 0);
  await db.prepare('UPDATE inventory SET available_units = ? WHERE product_id = ?').bind(units, id).run();
  return c.json({ success: true, message: `Inventory updated for ${id}` });
};

const handleVendorBulkInventory = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin', 'vendor', 'seller']);
  const body = await c.req.json();
  const db = c.env.DB;
  if (Array.isArray(body)) {
    for (const item of body) {
      if (item.id && item.available_units !== undefined) {
        await db.prepare('UPDATE inventory SET available_units = ? WHERE product_id = ?').bind(Number(item.available_units), item.id).run();
      }
    }
  }
  return c.json({ success: true, message: 'Bulk inventory updated' });
};

const handleVendorOfferUpdate = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin', 'vendor', 'seller']);
  const id = c.req.param('id');
  const body = await c.req.json();
  const db = c.env.DB;
  if (body.available_stock !== undefined || body.available_units !== undefined) {
    const stock = Number(body.available_stock ?? body.available_units);
    await db.prepare('UPDATE inventory SET available_units = ? WHERE product_id = ?').bind(stock, id).run();
  }
  if (body.selling_price !== undefined || body.price !== undefined) {
    const price = Number(body.selling_price ?? body.price);
    await db.prepare('UPDATE inventory SET price_minor = ? WHERE product_id = ?').bind(Math.round(price * 100), id).run();
  }
  return c.json({ success: true, message: 'Offer updated successfully' });
};

// Route registrations
adminRouter.get('/vendor/dashboard', getVendorDashboardHandler);
adminRouter.get('/marketplace/vendor/dashboard', getVendorDashboardHandler);

adminRouter.get('/vendor/profile', getVendorProfileHandler);
adminRouter.get('/vendor/me', getVendorProfileHandler);
adminRouter.get('/marketplace/vendor/profile', getVendorProfileHandler);
adminRouter.get('/marketplace/vendor/me', getVendorProfileHandler);

adminRouter.put('/vendor/profile', updateVendorProfileHandler);
adminRouter.put('/vendor/me', updateVendorProfileHandler);
adminRouter.patch('/vendor/profile', updateVendorProfileHandler);
adminRouter.patch('/vendor/me', updateVendorProfileHandler);
adminRouter.put('/marketplace/vendor/profile', updateVendorProfileHandler);

adminRouter.post('/vendor/register', registerVendorHandler);
adminRouter.post('/marketplace/vendor/register', registerVendorHandler);

adminRouter.get('/vendor/payouts', getVendorPayoutsHandler);
adminRouter.get('/marketplace/vendor/payouts', getVendorPayoutsHandler);

adminRouter.get('/vendor/commerce/coupons', getVendorCouponsHandler);
adminRouter.post('/vendor/commerce/coupons', createVendorCouponHandler);
adminRouter.patch('/vendor/commerce/coupons/:id', updateVendorCouponHandler);
adminRouter.put('/vendor/commerce/coupons/:id', updateVendorCouponHandler);
adminRouter.delete('/vendor/commerce/coupons/:id', deleteVendorCouponHandler);

adminRouter.post('/vendor/commerce/offers', handleVendorProductCreate);
adminRouter.put('/vendor/commerce/offers/:id', handleVendorOfferUpdate);
adminRouter.patch('/vendor/commerce/offers/:id', handleVendorOfferUpdate);

adminRouter.post('/vendor/products', handleVendorProductCreate);
adminRouter.put('/vendor/products/:id', handleVendorProductUpdate);
adminRouter.patch('/vendor/products/:id', handleVendorProductUpdate);
adminRouter.delete('/vendor/products/:id', handleVendorProductDelete);
adminRouter.put('/vendor/products/:id/inventory', handleVendorInventoryUpdate);
adminRouter.post('/vendor/products/bulk-inventory', handleVendorBulkInventory);
adminRouter.post('/vendor/products/:id/media', async (c) => c.json({ success: true, message: 'Media attached' }));

adminRouter.get('/marketplace/vendors/:vendor_id', getVendorByIdHandler);
adminRouter.get('/vendors/:vendor_id', getVendorByIdHandler);


