import path from 'node:path';
import { describe, it, expect, beforeAll } from 'vitest';
import app from '../src/index.js';
import { MockD1Database } from './helpers/mock_d1.js';
import type { Env } from '../src/types/env.js';

describe('Full End-to-End D1 Integration & Parity Test Suite', () => {
  let mockDb: MockD1Database;
  let testEnv: Env;

  beforeAll(async () => {
    mockDb = new MockD1Database();
    const migrationsDir = path.resolve('./migrations');
    mockDb.loadMigrations(migrationsDir);

    // Seed test fixtures
    await mockDb.exec(`
      INSERT OR REPLACE INTO customers (id, phone, full_name, role, is_active)
      VALUES ('user-1', '9876543210', 'Test Farmer User', 'subscriber', 1);

      INSERT OR REPLACE INTO customer_addresses (id, customer_id, recipient_name, phone, address_line1, city, state, pincode, is_default)
      VALUES ('addr-1', 'user-1', 'Test User Farm', '9876543210', 'Farm House 12, Village Road', 'Anand', 'Gujarat', '388001', 1);

      INSERT OR REPLACE INTO serviceable_pincodes (pincode, city, state, is_serviceable, delivery_fee_minor)
      VALUES ('388001', 'Anand', 'Gujarat', 1, 0);

      INSERT OR REPLACE INTO coupons (code, discount_type, discount_value, min_order_value, max_discount_cap, is_active)
      VALUES ('MILTERRA10', 'percentage', 10, 499, 250, 1);

      INSERT OR REPLACE INTO inventory (product_id, title, available_units, price_minor, currency, is_active)
      VALUES ('p-test', 'Organic A2 Cow Ghee 500ml', 10, 65000, 'INR', 1);
    `);

    testEnv = {
      DB: mockDb as any,
      ENVIRONMENT: 'test',
      STOREFRONT_BASE_URL: 'https://milterrafoods.com',
    };
  });

  it('GET /ready verifies all required tables are healthy and ready', async () => {
    const res = await app.request('/ready', {}, testEnv);
    expect(res.status).toBe(200);
    const data = (await res.json()) as { success: boolean; message: string };
    expect(data.success).toBe(true);
    expect(data.message).toBe('Ready');
    expect(res.headers.get('cache-control')).toBe('no-store');
  });

  it('GET /api/v1/marketplace/inventory/p-test retrieves authoritative live stock', async () => {
    const res = await app.request('/api/v1/marketplace/inventory/p-test', {}, testEnv);
    expect(res.status).toBe(200);
    const data = (await res.json()) as { success: boolean; data: any };
    expect(data.success).toBe(true);
    expect(data.data.product_id).toBe('p-test');
    expect(data.data.available_units).toBe(10);
    expect(data.data.price).toBe(650);
    expect(data.data.in_stock).toBe(true);
  });

  it('POST /api/v1/marketplace/cart/items adds an item to customer cart', async () => {
    const res = await app.request(
      '/api/v1/marketplace/cart/items',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': 'user-1',
        },
        body: JSON.stringify({ product_id: 'p-test', quantity: 2 }),
      },
      testEnv
    );
    expect(res.status).toBe(201);
    const data = (await res.json()) as { success: boolean };
    expect(data.success).toBe(true);
  });

  it('GET /api/v1/marketplace/cart returns cart contents with accurate subtotal', async () => {
    const res = await app.request(
      '/api/v1/marketplace/cart',
      {
        headers: { 'x-test-customer-id': 'user-1' },
      },
      testEnv
    );
    expect(res.status).toBe(200);
    const data = (await res.json()) as { success: boolean; data: any };
    expect(data.data.item_count).toBe(2);
    expect(data.data.subtotal).toBe(1300);
    expect(data.data.items[0].product_id).toBe('p-test');
  });

  it('POST /api/v1/marketplace/checkout/quote accurately applies coupon discounts', async () => {
    const res = await app.request(
      '/api/v1/marketplace/checkout/quote',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': 'user-1',
        },
        body: JSON.stringify({
          delivery_address_id: 'addr-1',
          coupon_code: 'MILTERRA10',
          payment_method: 'cod',
        }),
      },
      testEnv
    );
    expect(res.status).toBe(200);
    const data = (await res.json()) as { success: boolean; data: any };
    expect(data.data.subtotal).toBe(1300);
    expect(data.data.discount).toBe(130); // 10% of 1300
    expect(data.data.delivery_fee).toBe(0);
    expect(data.data.total).toBe(1170);
  });

  let createdOrderId = '';

  it('POST /api/v1/marketplace/checkout atomically creates order and decrements stock', async () => {
    const res = await app.request(
      '/api/v1/marketplace/checkout',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': 'user-1',
        },
        body: JSON.stringify({
          idempotency_key: 'test-idem-key-001',
          delivery_address_id: 'addr-1',
          payment_method: 'cod',
          coupon_code: 'MILTERRA10',
          expected_total: 1170,
        }),
      },
      testEnv
    );
    expect(res.status).toBe(201);
    const data = (await res.json()) as any;
    expect(data.status).toBe('CONFIRMED');
    expect(data.total).toBe(1170);
    createdOrderId = data.id;

    // Verify inventory decremented from 10 to 8 (quantity was 2)
    const invRow = await mockDb.prepare('SELECT available_units FROM inventory WHERE product_id = ?')
      .bind('p-test')
      .first<{ available_units: number }>();
    expect(invRow?.available_units).toBe(8);

    // Verify cart was cleared
    const cartCount = await mockDb.prepare('SELECT COUNT(*) as cnt FROM cart_items WHERE customer_id = ?')
      .bind('user-1')
      .first<{ cnt: number }>();
    expect(cartCount?.cnt).toBe(0);
  });

  it('POST /api/v1/marketplace/checkout replays idempotently without double-deduction', async () => {
    const res = await app.request(
      '/api/v1/marketplace/checkout',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': 'user-1',
        },
        body: JSON.stringify({
          idempotency_key: 'test-idem-key-001',
          delivery_address_id: 'addr-1',
          payment_method: 'cod',
          coupon_code: 'MILTERRA10',
          expected_total: 1170,
        }),
      },
      testEnv
    );
    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.id).toBe(createdOrderId);

    // Stock must remain unchanged at 8
    const invRow = await mockDb.prepare('SELECT available_units FROM inventory WHERE product_id = ?')
      .bind('p-test')
      .first<{ available_units: number }>();
    expect(invRow?.available_units).toBe(8);
  });

  it('GET /api/v1/marketplace/orders/:order_id returns complete order details and timeline', async () => {
    const res = await app.request(
      `/api/v1/marketplace/orders/${createdOrderId}`,
      {
        headers: { 'x-test-customer-id': 'user-1' },
      },
      testEnv
    );
    expect(res.status).toBe(200);
    const data = (await res.json()) as { success: boolean; data: any };
    expect(data.data.id).toBe(createdOrderId);
    expect(data.data.items.length).toBe(1);
    expect(data.data.items[0].product_id).toBe('p-test');
    expect(data.data.timeline.length).toBeGreaterThan(0);
  });

  it('POST /api/v1/marketplace/orders/:order_id/cancel cancels order and restores reserved stock', async () => {
    const res = await app.request(
      `/api/v1/marketplace/orders/${createdOrderId}/cancel`,
      {
        method: 'POST',
        headers: { 'x-test-customer-id': 'user-1' },
      },
      testEnv
    );
    expect(res.status).toBe(200);

    // Verify order status is cancelled
    const orderRow = await mockDb.prepare('SELECT status FROM orders WHERE id = ?')
      .bind(createdOrderId)
      .first<{ status: string }>();
    expect(orderRow?.status).toBe('cancelled');

    // Verify stock is restored from 8 back to 10
    const invRow = await mockDb.prepare('SELECT available_units FROM inventory WHERE product_id = ?')
      .bind('p-test')
      .first<{ available_units: number }>();
    expect(invRow?.available_units).toBe(10);
  });

  it('Milk Delivery flow: societies, flats, and daily delivery records', async () => {
    // 1. Create Society
    const socRes = await app.request(
      '/api/v1/delivery/societies',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': 'milkman-101',
        },
        body: JSON.stringify({ name: 'Gokul Dham Society', address: 'Main Gate Sector 4' }),
      },
      testEnv
    );
    expect(socRes.status).toBe(200);
    const socData = (await socRes.json()) as { success: boolean; society: any };
    const societyId = socData.society.id;
    expect(socData.society.name).toBe('Gokul Dham Society');

    // 2. Create Flat in Society
    const flatRes = await app.request(
      `/api/v1/delivery/societies/${societyId}/flats`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          flat_number: 'A-101',
          owner_name: 'Babita Iyer',
          owner_phone: '9876500001',
          has_app: true,
          default_quantity: 1.5,
          price_per_litre: 64.0,
        }),
      },
      testEnv
    );
    expect(flatRes.status).toBe(200);
    const flatData = (await flatRes.json()) as { success: boolean; flat: any };
    const flatId = flatData.flat.id;
    expect(flatData.flat.flat_number).toBe('A-101');

    // 3. Batch Record Deliveries
    const delivRes = await app.request(
      '/api/v1/delivery/deliveries/batch',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': 'milkman-101',
        },
        body: JSON.stringify({
          deliveries: [
            {
              flat_id: flatId,
              date_key: '2026-10-15',
              planned_quantity: 1.5,
              actual_quantity: 1.5,
              status: 'delivered',
            },
          ],
        }),
      },
      testEnv
    );
    expect(delivRes.status).toBe(200);
    const delivData = (await delivRes.json()) as { success: boolean; count: number };
    expect(delivData.count).toBe(1);

    // 4. Remote Sync Hydration
    const syncRes = await app.request(
      '/api/v1/delivery/sync?date_key=2026-10-15',
      {
        headers: { 'x-user-id': 'milkman-101' },
      },
      testEnv
    );
    expect(syncRes.status).toBe(200);
    const syncData = (await syncRes.json()) as any;
    expect(syncData.success).toBe(true);
    expect(syncData.role).toBe('milkman');
    expect(syncData.societies.length).toBeGreaterThan(0);
    expect(syncData.flats.length).toBeGreaterThan(0);
    expect(syncData.deliveries.length).toBe(1);
    expect(syncData.deliveries[0].actual_quantity).toBe(1.5);
  });

  it('Courier & COD Simulator flow: dispatch, events, collection, and ledger', async () => {
    // 1. Seed an admin customer and packed test order
    await mockDb.exec(`
      INSERT OR REPLACE INTO customers (id, phone, full_name, role, is_active)
      VALUES ('admin-1', '9876599999', 'Super Admin User', 'admin', 1);

      INSERT OR REPLACE INTO orders (id, customer_id, idempotency_key, checkout_request_fingerprint, address_id, subtotal_minor, delivery_fee_minor, discount_minor, total_minor, currency, status, payment_status, payment_method, is_test_order)
      VALUES ('test-order-sim', 'user-1', 'test-sim-idem-001', 'test-fingerprint-001', 'addr-1', 65000, 0, 0, 65000, 'INR', 'packed', 'pending', 'cod', 1);
    `);

    // 2. Dispatch Order
    const dispatchRes = await app.request(
      '/api/v1/marketplace/orders/admin/simulator/test-order-sim/dispatch',
      {
        method: 'POST',
        headers: { 'x-test-customer-id': 'admin-1' },
      },
      testEnv
    );
    expect(dispatchRes.status).toBe(200);
    const dispatchData = (await dispatchRes.json()) as any;
    expect(dispatchData.success).toBe(true);
    expect(dispatchData.data.status).toBe('shipped');
    expect(dispatchData.data.carrier).toContain('Milterra Test Courier');

    // 3. Courier Event: OUT_FOR_DELIVERY
    const outRes = await app.request(
      '/api/v1/marketplace/orders/admin/simulator/test-order-sim/event',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': 'admin-1',
        },
        body: JSON.stringify({ event: 'OUT_FOR_DELIVERY' }),
      },
      testEnv
    );
    expect(outRes.status).toBe(200);
    const outData = (await outRes.json()) as any;
    expect(outData.data.status).toBe('out_for_delivery');

    // 4. Courier Event: DELIVERED
    const delivRes = await app.request(
      '/api/v1/marketplace/orders/admin/simulator/test-order-sim/event',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': 'admin-1',
        },
        body: JSON.stringify({ event: 'DELIVERED' }),
      },
      testEnv
    );
    expect(delivRes.status).toBe(200);
    const delivData = (await delivRes.json()) as any;
    expect(delivData.data.status).toBe('delivered');

    // 5. COD Payment Collection
    const collectRes = await app.request(
      '/api/v1/marketplace/orders/admin/simulator/test-order-sim/collect',
      {
        method: 'POST',
        headers: { 'x-test-customer-id': 'admin-1' },
      },
      testEnv
    );
    expect(collectRes.status).toBe(200);
    const collectData = (await collectRes.json()) as any;
    expect(collectData.success).toBe(true);
    expect(collectData.data.payment_status).toBe('paid');

    // 6. Inspect Simulated Money Ledger
    const ledgerRes = await app.request(
      '/api/v1/marketplace/orders/admin/simulator/test-order-sim/ledger',
      {
        headers: { 'x-test-customer-id': 'admin-1' },
      },
      testEnv
    );
    expect(ledgerRes.status).toBe(200);
    const ledgerData = (await ledgerRes.json()) as any;
    expect(ledgerData.success).toBe(true);
    expect(ledgerData.data.length).toBeGreaterThan(0);
    expect(ledgerData.data[0].kind).toBe('cod_collection');
    expect(ledgerData.data[0].amount).toBe(650);
  });

  it('Fulfillment operations flow: PACKED -> SHIPPED -> OUT_FOR_DELIVERY -> DELIVERED -> COD collect', async () => {
    // 1. Seed a test order in 'placed' state
    const orderId = 'test-ops-order-1';
    await mockDb.exec(`
      INSERT OR REPLACE INTO orders (id, customer_id, idempotency_key, checkout_request_fingerprint, address_id, subtotal_minor, delivery_fee_minor, discount_minor, total_minor, currency, status, payment_status, payment_method)
      VALUES ('${orderId}', 'user-1', 'test-ops-idem-1', 'fingerprint-ops-1', 'addr-1', 120000, 0, 0, 120000, 'INR', 'placed', 'pending', 'cod');
    `);

    // 2. Transition: created -> PACKED
    const packRes = await app.request(
      `/api/v1/marketplace/orders/operations/${orderId}`,
      {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': 'admin-1',
        },
        body: JSON.stringify({
          status: 'PACKED',
          location: 'Pune Processing Hub',
          remarks: 'Packed with cold insulation gel',
        }),
      },
      testEnv
    );
    expect(packRes.status).toBe(200);
    const packData = (await packRes.json()) as any;
    expect(packData.data.status).toBe('PACKED');

    // 3. Transition: packed -> SHIPPED (with carrier and tracking number)
    const shipRes = await app.request(
      `/api/v1/marketplace/orders/operations/${orderId}`,
      {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': 'admin-1',
        },
        body: JSON.stringify({
          status: 'SHIPPED',
          carrier: 'BlueDart Express',
          tracking_number: 'BD-99887766',
          remarks: 'Dispatched from central warehouse',
        }),
      },
      testEnv
    );
    expect(shipRes.status).toBe(200);
    const shipData = (await shipRes.json()) as any;
    expect(shipData.data.status).toBe('SHIPPED');
    expect(shipData.data.carrier).toBe('BlueDart Express');
    expect(shipData.data.tracking_number).toBe('BD-99887766');

    // 4. Transition: shipped -> OUT_FOR_DELIVERY
    const outRes = await app.request(
      `/api/v1/marketplace/orders/operations/${orderId}`,
      {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': 'admin-1',
        },
        body: JSON.stringify({
          status: 'OUT_FOR_DELIVERY',
          remarks: 'Courier delivery agent on route',
        }),
      },
      testEnv
    );
    expect(outRes.status).toBe(200);
    const outData = (await outRes.json()) as any;
    expect(outData.data.status).toBe('OUT_FOR_DELIVERY');

    // 5. Transition: out_for_delivery -> DELIVERED
    const delivRes = await app.request(
      `/api/v1/marketplace/orders/operations/${orderId}`,
      {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': 'admin-1',
        },
        body: JSON.stringify({
          status: 'DELIVERED',
          remarks: 'Delivered and signed by recipient',
        }),
      },
      testEnv
    );
    expect(delivRes.status).toBe(200);
    const delivData = (await delivRes.json()) as any;
    expect(delivData.data.status).toBe('DELIVERED');

    // 6. COD Remittance Collection
    const collectRes = await app.request(
      `/api/v1/marketplace/orders/admin/cod/${orderId}/collect`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': 'admin-1',
        },
        body: JSON.stringify({
          remittance_reference: 'REMIT-HDFC-998811',
        }),
      },
      testEnv
    );
    expect(collectRes.status).toBe(200);
    const collectData = (await collectRes.json()) as any;
    expect(collectData.data.payment_status).toBe('PAID');
  });

  it('Customer return and admin return processing flow', async () => {
    // 1. Seed a delivered order with order lines
    const retOrderId = 'test-return-order-1';
    await mockDb.exec(`
      INSERT OR REPLACE INTO orders (id, customer_id, idempotency_key, checkout_request_fingerprint, address_id, subtotal_minor, delivery_fee_minor, discount_minor, total_minor, currency, status, payment_status, payment_method)
      VALUES ('${retOrderId}', 'user-1', 'ret-idem-1', 'ret-fp-1', 'addr-1', 65000, 0, 0, 65000, 'INR', 'delivered', 'paid', 'cod');

      INSERT OR REPLACE INTO order_lines (id, order_id, product_id, product_title, quantity, unit_price_minor, total_minor, currency)
      VALUES ('line-ret-1', '${retOrderId}', 'p-test', 'Vedic Bilona Ghee 500ml', 1, 65000, 65000, 'INR');
    `);

    // 2. Customer submits return request
    const retReqRes = await app.request(
      `/api/v1/marketplace/orders/${retOrderId}/return-request`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': 'user-1',
        },
        body: JSON.stringify({
          reason: 'Jar seal slightly broken upon opening',
          remarks: 'Product unused',
        }),
      },
      testEnv
    );
    expect(retReqRes.status).toBe(201);
    const retReqData = (await retReqRes.json()) as any;
    expect(retReqData.success).toBe(true);
    expect(retReqData.data.return_status).toBe('RETURN_REQUESTED');

    // 3. Admin lists returns
    const listRetRes = await app.request(
      '/api/v1/marketplace/orders/admin/returns',
      {
        headers: { 'x-test-customer-id': 'admin-1' },
      },
      testEnv
    );
    expect(listRetRes.status).toBe(200);
    const listRetData = (await listRetRes.json()) as any;
    expect(listRetData.data.length).toBeGreaterThan(0);

    // 4. Admin processes and accepts return with restock
    const procRes = await app.request(
      `/api/v1/marketplace/orders/admin/returns/${retOrderId}/process`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': 'admin-1',
        },
        body: JSON.stringify({
          action: 'confirm_received_refund',
          refund_reference: 'REFUND-IMPS-887711',
          remarks: 'Jar inspected and refund completed',
          restock_inventory: true,
        }),
      },
      testEnv
    );
    expect(procRes.status).toBe(200);
    const procData = (await procRes.json()) as any;
    expect(procData.data.return_status).toBe('RETURN_COMPLETED');
  });

  it('Admin Delivery Policy and Pincode rule overrides flow', async () => {
    // 1. Get Delivery Policy
    const polRes = await app.request(
      '/api/v1/marketplace/admin/delivery-policy',
      {
        headers: { 'x-test-customer-id': 'admin-1' },
      },
      testEnv
    );
    expect(polRes.status).toBe(200);
    const polData = (await polRes.json()) as any;
    expect(polData.success).toBe(true);

    // 2. Update Delivery Policy
    const updatePolRes = await app.request(
      '/api/v1/marketplace/admin/delivery-policy',
      {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': 'admin-1',
        },
        body: JSON.stringify({
          cod_default_enabled: true,
          prepaid_default_enabled: false,
          delivery_fee_minor: 6000,
          free_delivery_above_minor: 50000,
        }),
      },
      testEnv
    );
    expect(updatePolRes.status).toBe(200);

    // 3. Add custom Pincode Override
    const pinRes = await app.request(
      '/api/v1/marketplace/admin/pincodes',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': 'admin-1',
        },
        body: JSON.stringify({
          pincode: '411038',
          city: 'Pune Kothrud',
          state: 'Maharashtra',
          cod_enabled: true,
          prepaid_enabled: false,
          delivery_fee_minor: 4000,
        }),
      },
      testEnv
    );
    expect(pinRes.status).toBe(201);

    // 4. Search Pincode Overrides
    const searchPinRes = await app.request(
      '/api/v1/marketplace/admin/pincodes?query=411038',
      {
        headers: { 'x-test-customer-id': 'admin-1' },
      },
      testEnv
    );
    expect(searchPinRes.status).toBe(200);
    const searchPinData = (await searchPinRes.json()) as any;
    expect(searchPinData.data.some((p: any) => p.pincode === '411038')).toBe(true);

    // 5. Delete Pincode Override
    const delPinRes = await app.request(
      '/api/v1/marketplace/admin/pincodes/411038',
      {
        method: 'DELETE',
        headers: { 'x-test-customer-id': 'admin-1' },
      },
      testEnv
    );
    expect(delPinRes.status).toBe(200);
  });

  it('Product review lifecycle: submit review -> moderate status -> public fetch', async () => {
    // 1. Customer reviews delivered product
    const revRes = await app.request(
      '/api/v1/marketplace/products/p-test/reviews',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': 'user-1',
        },
        body: JSON.stringify({
          order_id: 'test-return-order-1',
          rating: 5,
          headline: 'Exceptional purity and aroma',
          content: 'The authentic Vedic bilona aroma is distinct and heavenly. Highly recommended!',
        }),
      },
      testEnv
    );
    expect(revRes.status).toBe(201);
    const revData = (await revRes.json()) as any;
    const reviewId = revData.data.id;

    // 2. Admin moderates and approves review
    const modRes = await app.request(
      `/api/v1/marketplace/admin/marketplace/reviews/${reviewId}/status`,
      {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': 'admin-1',
        },
        body: JSON.stringify({ status: 'APPROVED' }),
      },
      testEnv
    );
    expect(modRes.status).toBe(200);

    // 3. Public lists approved reviews for product
    const pubRevRes = await app.request(
      '/api/v1/marketplace/products/p-test/reviews',
      {},
      testEnv
    );
    expect(pubRevRes.status).toBe(200);
    const pubRevData = (await pubRevRes.json()) as any;
    expect(pubRevData.data.some((r: any) => r.id === reviewId)).toBe(true);
  });

  it('Analytics telemetry flow: visit registration, clickstream events, and traffic summary', async () => {
    const sessionId = 'test-session-telemetry-001';

    // 1. Register Visit
    const visRes = await app.request(
      '/api/v1/marketplace/analytics/visit',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-milterra-cf-city': 'Mumbai',
          'x-milterra-cf-region': 'Maharashtra',
        },
        body: JSON.stringify({
          session_id: sessionId,
          referrer: 'https://instagram.com',
          landing_page: '/shop',
          device_type: 'mobile',
        }),
      },
      testEnv
    );
    expect(visRes.status).toBe(200);
    const visData = (await visRes.json()) as any;
    expect(visData.success).toBe(true);
    expect(visData.data.city).toBe('Mumbai');

    // 2. Ingest Clickstream Events
    const evRes = await app.request(
      '/api/v1/marketplace/analytics/events',
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          events: [
            {
              session_id: sessionId,
              event_type: 'PAGE_VIEW',
              page_url: '/shop/a2-ghee',
            },
            {
              session_id: sessionId,
              event_type: 'ADD_TO_CART',
              page_url: '/shop/a2-ghee',
              target_id: 'btn-add-cart',
            },
          ],
        }),
      },
      testEnv
    );
    expect(evRes.status).toBe(200);
    const evData = (await evRes.json()) as any;
    expect(evData.data.processed).toBe(2);

    // 3. Admin Traffic Analytics
    const trafRes = await app.request(
      '/api/v1/marketplace/admin/ecommerce/analytics/traffic',
      {
        headers: { 'x-test-customer-id': 'admin-1' },
      },
      testEnv
    );
    expect(trafRes.status).toBe(200);
    const trafData = (await trafRes.json()) as any;
    expect(trafData.data.total_visitors).toBeGreaterThan(0);
    expect(trafData.data.total_page_views).toBeGreaterThan(0);
    expect(Array.isArray(trafData.data.top_cities)).toBe(true);
    expect(trafData.data.top_cities.length).toBeGreaterThan(0);
    expect(Array.isArray(trafData.data.top_states)).toBe(true);
    expect(trafData.data.top_states.length).toBeGreaterThan(0);
    expect(Array.isArray(trafData.data.top_referrers)).toBe(true);
    expect(trafData.data.device_breakdown).toBeDefined();
  });

  it('Customer Profile and Support Tickets flow', async () => {
    // 1. Get and update customer profile
    const profRes = await app.request(
      '/api/v1/marketplace/profile',
      {
        headers: { 'x-test-customer-id': 'user-1' },
      },
      testEnv
    );
    expect(profRes.status).toBe(200);

    const updateProfRes = await app.request(
      '/api/v1/marketplace/profile',
      {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': 'user-1',
        },
        body: JSON.stringify({
          name: 'Jane Customer Updated',
          village: 'Shirdi',
          district: 'Ahmednagar',
          state: 'Maharashtra',
          language: 'mr',
        }),
      },
      testEnv
    );
    expect(updateProfRes.status).toBe(200);
    const profData = (await updateProfRes.json()) as any;
    expect(profData.data.village).toBe('Shirdi');

    // 2. Create customer support ticket
    const supRes = await app.request(
      '/api/v1/marketplace/support',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-test-customer-id': 'user-1',
        },
        body: JSON.stringify({
          subject: 'Delivery timing inquiry',
          message: 'Can the morning milk be delivered prior to 7:00 AM please?',
        }),
      },
      testEnv
    );
    expect(supRes.status).toBe(201);
    const supData = (await supRes.json()) as any;
    expect(supData.data.status).toBe('OPEN');
  });

  it('Admin Commerce & Vendor Catalogue endpoints resolve properly with admin auth', async () => {
    // 1. GET /vendor/products and /api/v1/vendor/products
    const vendorProds1 = await app.request('/vendor/products', {
      headers: { 'x-test-customer-id': 'admin-1' },
    }, testEnv);
    expect(vendorProds1.status).toBe(200);
    const vData1 = (await vendorProds1.json()) as any;
    expect(vData1.success).toBe(true);
    expect(Array.isArray(vData1.data)).toBe(true);
    expect(vData1.data.length).toBeGreaterThan(0);
    expect(vData1.data.some((p: any) => p.id === 'p-test')).toBe(true);

    const vendorProds2 = await app.request('/api/v1/vendor/products', {
      headers: { 'x-test-customer-id': 'admin-1' },
    }, testEnv);
    expect(vendorProds2.status).toBe(200);

    // 2. GET /admin/commerce and /api/v1/admin/commerce
    const adminCommerce1 = await app.request('/admin/commerce', {
      headers: { 'x-test-customer-id': 'admin-1' },
    }, testEnv);
    expect(adminCommerce1.status).toBe(200);
    const cData1 = (await adminCommerce1.json()) as any;
    expect(cData1.success).toBe(true);
    expect(cData1.data).toHaveProperty('sellers');
    expect(cData1.data).toHaveProperty('offers');
    expect(cData1.data).toHaveProperty('coupons');
    expect(cData1.data).toHaveProperty('batch_certificates');
    expect(cData1.data).toHaveProperty('audit_logs');

    const adminCommerce2 = await app.request('/api/v1/admin/commerce', {
      headers: { 'x-test-customer-id': 'admin-1' },
    }, testEnv);
    expect(adminCommerce2.status).toBe(200);

    // 3. GET /vendor/families
    const familiesRes = await app.request('/vendor/families', {
      headers: { 'x-test-customer-id': 'admin-1' },
    }, testEnv);
    expect(familiesRes.status).toBe(200);
    const famData = (await familiesRes.json()) as any;
    expect(famData.success).toBe(true);

    // 4. Coupons and Offers mutation
    const createCouponRes = await app.request('/admin/commerce/coupons', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-test-customer-id': 'admin-1',
      },
      body: JSON.stringify({
        code: 'ADMINFEST50',
        description: 'Admin festival special discount',
        discount_type: 'flat',
        discount_value: 50,
        min_order_value: 200,
      }),
    }, testEnv);
    expect(createCouponRes.status).toBe(200);

    const updateOfferRes = await app.request('/admin/commerce/offers/p-test', {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'x-test-customer-id': 'admin-1',
      },
      body: JSON.stringify({
        available_stock: 42,
        selling_price: 680,
      }),
    }, testEnv);
    expect(updateOfferRes.status).toBe(200);

    const updateVisibilityRes = await app.request('/admin/commerce/products/p-test/visibility', {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'x-test-customer-id': 'admin-1',
      },
      body: JSON.stringify({
        visible: false,
        reason: 'Undergoing quality inspection',
      }),
    }, testEnv);
    expect(updateVisibilityRes.status).toBe(200);
  });

  it('Vendor Settlements, Payouts, Commissions and Tax Reports workflow', async () => {
    // 1. Fetch settlements
    const settlementsRes = await app.request('/admin/commerce/vendors/settlements', {
      headers: { 'x-test-customer-id': 'admin-1' },
    }, testEnv);
    expect(settlementsRes.status).toBe(200);
    const settlementsData = (await settlementsRes.json()) as any;
    expect(settlementsData.success).toBe(true);
    expect(Array.isArray(settlementsData.data)).toBe(true);
    expect(settlementsData.data.length).toBeGreaterThan(0);
    const vendorSettlement = settlementsData.data[0];
    expect(vendorSettlement.vendor_id).toBe('vendor-1');
    expect(typeof vendorSettlement.gross_sales).toBe('number');
    expect(typeof vendorSettlement.commission_rate).toBe('number');
    expect(typeof vendorSettlement.pending_balance).toBe('number');

    // 2. Disburse a payout
    const payoutRes = await app.request('/admin/commerce/vendors/vendor-1/payouts', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-test-customer-id': 'admin-1',
      },
      body: JSON.stringify({
        amount: 2500,
        gross_amount: 3000,
        commission_amount: 150,
        payment_reference: 'UTR99887766',
        remarks: 'Weekly seller payout',
        bank_name: 'State Bank of India',
        account_number: '1234567890',
      }),
    }, testEnv);
    expect(payoutRes.status).toBe(201);
    const payoutData = (await payoutRes.json()) as any;
    expect(payoutData.success).toBe(true);
    expect(payoutData.data.amount).toBe(2500);
    expect(payoutData.data.payment_reference).toBe('UTR99887766');

    // 3. Update commission rate
    const commRes = await app.request('/admin/commerce/vendors/vendor-1/commission', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-test-customer-id': 'admin-1',
      },
      body: JSON.stringify({ commission_rate: 6.5 }),
    }, testEnv);
    expect(commRes.status).toBe(200);
    const commData = (await commRes.json()) as any;
    expect(commData.success).toBe(true);
    expect(commData.data.commission_rate).toBe(6.5);

    // 4. Update seller status
    const sellerStatusRes = await app.request('/admin/commerce/sellers/vendor-1', {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'x-test-customer-id': 'admin-1',
      },
      body: JSON.stringify({ status: 'approved' }),
    }, testEnv);
    expect(sellerStatusRes.status).toBe(200);

    // 5. GSTR-1 Tax Report (JSON & CSV)
    const gstr1JsonRes = await app.request('/admin/commerce/reports/gstr1?format=json', {
      headers: { 'x-test-customer-id': 'admin-1' },
    }, testEnv);
    expect(gstr1JsonRes.status).toBe(200);
    const gstr1Json = (await gstr1JsonRes.json()) as any;
    expect(gstr1Json.success).toBe(true);
    expect(Array.isArray(gstr1Json.data)).toBe(true);

    const gstr1CsvRes = await app.request('/admin/commerce/reports/gstr1?format=csv', {
      headers: { 'x-test-customer-id': 'admin-1' },
    }, testEnv);
    expect(gstr1CsvRes.status).toBe(200);
    expect(gstr1CsvRes.headers.get('content-type')).toContain('text/csv');
    const gstr1CsvText = await gstr1CsvRes.text();
    expect(gstr1CsvText).toContain('invoice_number');

    // 6. Settlements Report (JSON & CSV)
    const settleJsonRes = await app.request('/admin/commerce/reports/settlements?format=json', {
      headers: { 'x-test-customer-id': 'admin-1' },
    }, testEnv);
    expect(settleJsonRes.status).toBe(200);
    const settleJson = (await settleJsonRes.json()) as any;
    expect(settleJson.success).toBe(true);
    expect(Array.isArray(settleJson.data)).toBe(true);

    const settleCsvRes = await app.request('/admin/commerce/reports/settlements?format=csv', {
      headers: { 'x-test-customer-id': 'admin-1' },
    }, testEnv);
    expect(settleCsvRes.status).toBe(200);
    expect(settleCsvRes.headers.get('content-type')).toContain('text/csv');
    const settleCsvText = await settleCsvRes.text();
    expect(settleCsvText).toContain('vendor_id');
  });

  it('Merchandising Placements lifecycle (Banners & Deals)', async () => {
    // 1. Initial list (admin and public)
    const adminPlacementsRes = await app.request('/admin/marketplace/merchandising/placements', {
      headers: { 'x-test-customer-id': 'admin-1' },
    }, testEnv);
    expect(adminPlacementsRes.status).toBe(200);
    const adminData = (await adminPlacementsRes.json()) as any;
    expect(adminData.success).toBe(true);
    expect(Array.isArray(adminData.data)).toBe(true);

    // 2. Create placement
    const createRes = await app.request('/admin/marketplace/merchandising/placements', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-test-customer-id': 'admin-1',
      },
      body: JSON.stringify({
        product_id: 'p-test',
        placement_type: 'highlight',
        headline: 'Pure Gir Cow Cultured Ghee - Festive Offer',
        subheadline: 'Flat 10% off with coupon MILTERRA10',
        badge: 'Deal of the Day',
        coupon_code: 'MILTERRA10',
        priority: 500,
        is_active: true,
      }),
    }, testEnv);
    expect(createRes.status).toBe(201);
    const created = (await createRes.json()) as any;
    expect(created.success).toBe(true);
    const placementId = created.data.id;

    // 3. Verify placement returned with full Product model structure
    const listAfterRes = await app.request('/admin/marketplace/merchandising/placements', {
      headers: { 'x-test-customer-id': 'admin-1' },
    }, testEnv);
    expect(listAfterRes.status).toBe(200);
    const listAfter = (await listAfterRes.json()) as any;
    expect(listAfter.data.length).toBeGreaterThan(0);
    const item = listAfter.data.find((p: any) => p.id === placementId);
    expect(item).toBeDefined();
    expect(item.headline).toBe('Pure Gir Cow Cultured Ghee - Festive Offer');
    expect(item.product).toBeDefined();
    expect(item.product.id).toBe('p-test');
    expect(typeof item.product.base_price).toBe('number');
    expect(typeof item.product.price).toBe('number');
    expect(item.product.vendor).toBeDefined();
    expect(item.coupon).toBeDefined();
    expect(item.coupon.code).toBe('MILTERRA10');

    // 4. Update placement active status
    const updateRes = await app.request(`/admin/marketplace/merchandising/placements/${placementId}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'x-test-customer-id': 'admin-1',
      },
      body: JSON.stringify({ is_active: false }),
    }, testEnv);
    expect(updateRes.status).toBe(200);

    // 5. Delete placement
    const deleteRes = await app.request(`/admin/marketplace/merchandising/placements/${placementId}`, {
      method: 'DELETE',
      headers: { 'x-test-customer-id': 'admin-1' },
    }, testEnv);
    expect(deleteRes.status).toBe(200);
  });

  it('Vendor Portal Workflow: Dashboard, Profile, Payouts, Coupons and Public Storefront', async () => {
    // 1. GET /vendor/dashboard
    const dashRes = await app.request('/vendor/dashboard', {
      headers: { 'x-test-customer-id': 'admin-1' },
    }, testEnv);
    expect(dashRes.status).toBe(200);
    const dash = (await dashRes.json()) as any;
    expect(dash.success).toBe(true);
    expect(dash.data).toBeDefined();
    expect(dash.data.profile).toBeDefined();
    expect(dash.data.stats).toBeDefined();
    expect(typeof dash.data.stats.total_orders).toBe('number');
    expect(typeof dash.data.stats.total_revenue).toBe('number');
    expect(dash.data.settlements).toBeDefined();
    expect(dash.data.analytics).toBeDefined();
    expect(Array.isArray(dash.data.low_stock_items)).toBe(true);
    expect(Array.isArray(dash.data.recent_orders)).toBe(true);

    // 2. GET /vendor/profile
    const profRes = await app.request('/vendor/profile', {
      headers: { 'x-test-customer-id': 'admin-1' },
    }, testEnv);
    expect(profRes.status).toBe(200);
    const prof = (await profRes.json()) as any;
    expect(prof.success).toBe(true);
    expect(prof.data.id).toBeDefined();
    expect(prof.data.business_name).toBeDefined();
    expect(prof.data.vendor_type).toBeDefined();

    // 3. PUT /vendor/profile
    const updateProfRes = await app.request('/vendor/profile', {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'x-test-customer-id': 'admin-1',
      },
      body: JSON.stringify({
        business_name: 'Milterra Foods & Organics',
        bank_name: 'HDFC Bank',
        account_number: '50100234567890',
        ifsc_code: 'HDFC0001234',
        upi_id: 'milterra@hdfc',
        account_holder_name: 'Milterra Foods Ltd',
      }),
    }, testEnv);
    expect(updateProfRes.status).toBe(200);
    const updatedProf = (await updateProfRes.json()) as any;
    expect(updatedProf.data.business_name).toBe('Milterra Foods & Organics');
    expect(updatedProf.data.bank_name).toBe('HDFC Bank');

    // 4. GET /vendor/payouts
    const payoutsRes = await app.request('/vendor/payouts', {
      headers: { 'x-test-customer-id': 'admin-1' },
    }, testEnv);
    expect(payoutsRes.status).toBe(200);
    const payoutsData = (await payoutsRes.json()) as any;
    expect(payoutsData.success).toBe(true);
    expect(payoutsData.data.settlements).toBeDefined();
    expect(payoutsData.data.bank_details.bank_name).toBe('HDFC Bank');

    // 5. Vendor Coupons Lifecycle
    const createCouponRes = await app.request('/vendor/commerce/coupons', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-test-customer-id': 'admin-1',
      },
      body: JSON.stringify({
        code: 'VENDORFEST20',
        description: 'Vendor Fest 20% discount',
        discount_type: 'percentage',
        discount_value: 20,
        min_order_value: 399,
        max_discount_cap: 150,
      }),
    }, testEnv);
    expect(createCouponRes.status).toBe(201);

    const getCouponsRes = await app.request('/vendor/commerce/coupons', {
      headers: { 'x-test-customer-id': 'admin-1' },
    }, testEnv);
    expect(getCouponsRes.status).toBe(200);
    const couponsList = (await getCouponsRes.json()) as any;
    expect(couponsList.success).toBe(true);
    expect(couponsList.data.some((c: any) => c.code === 'VENDORFEST20')).toBe(true);

    const toggleCouponRes = await app.request('/vendor/commerce/coupons/VENDORFEST20', {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'x-test-customer-id': 'admin-1',
      },
      body: JSON.stringify({ is_active: false }),
    }, testEnv);
    expect(toggleCouponRes.status).toBe(200);

    const deleteCouponRes = await app.request('/vendor/commerce/coupons/VENDORFEST20', {
      method: 'DELETE',
      headers: { 'x-test-customer-id': 'admin-1' },
    }, testEnv);
    expect(deleteCouponRes.status).toBe(200);

    // 6. Public Storefront: GET /marketplace/vendors/:vendor_id
    const publicVendorRes = await app.request('/marketplace/vendors/vendor-1', {}, testEnv);
    expect(publicVendorRes.status).toBe(200);
    const publicVendorData = (await publicVendorRes.json()) as any;
    expect(publicVendorData.success).toBe(true);
    expect(publicVendorData.data.id).toBe('vendor-1');
  });
});


