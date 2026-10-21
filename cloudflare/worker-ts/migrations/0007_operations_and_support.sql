-- Migration 0007: Seller fulfillment operations, shipment tracking, customer support, and delivery coverage

-- 1. Upgrade orders table with 'packed' and 'out_for_delivery' in status CHECK constraint, tracking, and COD remittance fields.
-- Recreate order_lines pointing to orders_new simultaneously to preserve all line items without cascade deletion.

CREATE TABLE orders_new (
    id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL REFERENCES customers(id),
    reservation_id TEXT REFERENCES reservations(id),
    idempotency_key TEXT NOT NULL,
    checkout_request_fingerprint TEXT NOT NULL,
    address_id TEXT REFERENCES customer_addresses(id),
    subtotal_minor INTEGER NOT NULL CHECK (subtotal_minor >= 0),
    delivery_fee_minor INTEGER NOT NULL CHECK (delivery_fee_minor >= 0),
    discount_minor INTEGER NOT NULL DEFAULT 0 CHECK (discount_minor >= 0),
    total_minor INTEGER NOT NULL CHECK (total_minor >= 0),
    currency TEXT NOT NULL CHECK (currency = 'INR'),
    status TEXT NOT NULL DEFAULT 'placed'
        CHECK (status IN ('placed', 'confirmed', 'packed', 'shipped', 'out_for_delivery', 'delivered', 'cancelled')),
    payment_status TEXT NOT NULL DEFAULT 'pending'
        CHECK (payment_status IN ('pending', 'paid', 'failed', 'refunded')),
    payment_method TEXT NOT NULL DEFAULT 'cod'
        CHECK (payment_method IN ('cod', 'wallet', 'upi', 'card', 'netbanking')),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    address_snapshot TEXT NOT NULL DEFAULT '{}',
    is_test_order INTEGER NOT NULL DEFAULT 0 CHECK (is_test_order IN (0, 1)),
    carrier TEXT NOT NULL DEFAULT '',
    tracking_number TEXT NOT NULL DEFAULT '',
    dispatched_at TEXT,
    delivered_at TEXT,
    remittance_reference TEXT,
    UNIQUE (customer_id, idempotency_key)
);

CREATE TABLE order_lines_new (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL REFERENCES orders_new(id) ON DELETE CASCADE,
    product_id TEXT NOT NULL REFERENCES inventory(product_id),
    product_title TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price_minor INTEGER NOT NULL CHECK (unit_price_minor >= 0),
    total_minor INTEGER NOT NULL CHECK (total_minor >= 0),
    currency TEXT NOT NULL CHECK (currency = 'INR')
);

INSERT INTO orders_new (
    id, customer_id, reservation_id, idempotency_key, checkout_request_fingerprint,
    address_id, subtotal_minor, delivery_fee_minor, discount_minor, total_minor,
    currency, status, payment_status, payment_method, created_at, address_snapshot,
    is_test_order, carrier, tracking_number, dispatched_at, delivered_at, remittance_reference
)
SELECT
    id, customer_id, reservation_id, idempotency_key, checkout_request_fingerprint,
    address_id, subtotal_minor, delivery_fee_minor, discount_minor, total_minor,
    currency, status, payment_status, payment_method, created_at, address_snapshot,
    is_test_order, '', '', NULL, NULL, NULL
FROM orders;

INSERT INTO order_lines_new (
    id, order_id, product_id, product_title, quantity, unit_price_minor, total_minor, currency
)
SELECT id, order_id, product_id, product_title, quantity, unit_price_minor, total_minor, currency
FROM order_lines;

DROP TRIGGER IF EXISTS trg_cancel_order;
DROP TRIGGER IF EXISTS snapshot_order_address;

DROP TABLE order_lines;
DROP TABLE orders;

ALTER TABLE orders_new RENAME TO orders;
ALTER TABLE order_lines_new RENAME TO order_lines;

CREATE INDEX IF NOT EXISTS idx_order_lines_order ON order_lines(order_id);

CREATE TRIGGER IF NOT EXISTS trg_cancel_order BEFORE UPDATE OF status ON orders
FOR EACH ROW
WHEN NEW.status = 'cancelled'
BEGIN
    SELECT RAISE(ABORT, 'only placed or confirmed orders can be cancelled')
     WHERE OLD.status NOT IN ('placed', 'confirmed');
END;

CREATE TRIGGER IF NOT EXISTS snapshot_order_address AFTER INSERT ON orders
BEGIN
  UPDATE orders SET address_snapshot = COALESCE((
    SELECT json_object('recipient_name', recipient_name, 'phone', phone,
      'address_line1', address_line1, 'address_line2', address_line2,
      'village_or_city', city, 'district', district, 'state', state,
      'postal_code', pincode, 'landmark', landmark)
    FROM customer_addresses WHERE id = NEW.address_id
  ), '{}') WHERE id = NEW.id;
END;

-- 2. Chronological order milestone events
CREATE TABLE IF NOT EXISTS order_events (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    status TEXT NOT NULL,
    title TEXT NOT NULL,
    location TEXT NOT NULL DEFAULT '',
    remarks TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);
CREATE INDEX IF NOT EXISTS idx_order_events_order ON order_events(order_id, created_at);

-- 3. Customer support enquiries and replies
CREATE TABLE IF NOT EXISTS support_tickets (
    id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    subject TEXT NOT NULL,
    message TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'IN_PROGRESS', 'CLOSED')),
    reply TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);
CREATE INDEX IF NOT EXISTS idx_support_tickets_customer ON support_tickets(customer_id, created_at);

-- 4. Storefront Help & FAQ content with honest operational statements
CREATE TABLE IF NOT EXISTS store_help (
    key TEXT PRIMARY KEY,
    content TEXT NOT NULL
);

INSERT OR REPLACE INTO store_help (key, content) VALUES ('help', json_object(
    'contact_message', 'For any questions about your orders, deliveries, or farm-direct products, submit an enquiry below or reach our team.',
    'faqs', json_array(
        json_object('category', 'Ordering', 'question', 'How does Cash on Delivery (COD) work?', 'answer', 'You can place your order online and pay the delivery courier in cash or via UPI QR when your package arrives at your doorstep.'),
        json_object('category', 'Delivery', 'question', 'Which locations do you currently deliver to?', 'answer', 'We currently deliver to serviceable pincodes across select partner regions. Use our pincode check during checkout to verify coverage for your address.'),
        json_object('category', 'Quality', 'question', 'How are Milterra dairy products packaged?', 'answer', 'All products are securely packed from our partner suppliers for safe transit to your location.'),
        json_object('category', 'Returns', 'question', 'What is your return and cancellation policy?', 'answer', 'Orders can be cancelled directly from your account page before dispatch. For questions or issues with a delivered order, contact our support team through the Help & Support section.')
    )
));

-- 5. Seed authoritative delivery coverage for major hubs
INSERT OR REPLACE INTO serviceable_pincodes (pincode, city, state, is_serviceable, delivery_fee_minor, delivery_days_min, delivery_days_max) VALUES
    ('110001', 'New Delhi', 'Delhi', 1, 4000, 1, 2),
    ('201301', 'Noida', 'Uttar Pradesh', 1, 3000, 1, 2),
    ('122001', 'Gurugram', 'Haryana', 1, 4000, 1, 2),
    ('226001', 'Lucknow', 'Uttar Pradesh', 1, 5000, 2, 3),
    ('400001', 'Mumbai', 'Maharashtra', 1, 6000, 3, 4),
    ('560001', 'Bengaluru', 'Karnataka', 1, 6000, 3, 4);

-- 6. Customer profile preferences and password resets
CREATE TABLE IF NOT EXISTS customer_profiles (
    customer_id TEXT PRIMARY KEY REFERENCES customers(id) ON DELETE CASCADE,
    village TEXT NOT NULL DEFAULT '',
    district TEXT NOT NULL DEFAULT '',
    state TEXT NOT NULL DEFAULT '',
    language TEXT NOT NULL DEFAULT 'en',
    notify_health INTEGER NOT NULL DEFAULT 1 CHECK (notify_health IN (0, 1)),
    notify_vaccination INTEGER NOT NULL DEFAULT 1 CHECK (notify_vaccination IN (0, 1)),
    notify_consultation INTEGER NOT NULL DEFAULT 1 CHECK (notify_consultation IN (0, 1)),
    notify_payment INTEGER NOT NULL DEFAULT 1 CHECK (notify_payment IN (0, 1)),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE TABLE IF NOT EXISTS customer_password_resets (
    token_hash TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    expires_at INTEGER NOT NULL,
    created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_customer_password_resets_expiry ON customer_password_resets(expires_at);
