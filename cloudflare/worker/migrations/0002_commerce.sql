-- D1 Commerce Schema: Customers, Addresses, Inventory, Reservations, Orders, Order Lines

CREATE TABLE IF NOT EXISTS customers (
    id TEXT PRIMARY KEY,
    phone TEXT UNIQUE NOT NULL,
    full_name TEXT,
    role TEXT NOT NULL DEFAULT 'farmer',
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE TABLE IF NOT EXISTS customer_addresses (
    id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    recipient_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    address_line1 TEXT NOT NULL,
    address_line2 TEXT,
    city TEXT NOT NULL,
    state TEXT NOT NULL,
    pincode TEXT NOT NULL,
    is_default INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE TABLE IF NOT EXISTS inventory (
    product_id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    available_units INTEGER NOT NULL CHECK (available_units >= 0),
    price_minor INTEGER NOT NULL CHECK (price_minor >= 0),
    currency TEXT NOT NULL CHECK (currency = 'INR'),
    is_active INTEGER NOT NULL DEFAULT 1,
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE TABLE IF NOT EXISTS cart_items (
    id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    product_id TEXT NOT NULL REFERENCES inventory(product_id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    UNIQUE (customer_id, product_id)
);

CREATE TABLE IF NOT EXISTS reservations (
    id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL REFERENCES customers(id),
    idempotency_key TEXT NOT NULL,
    payload_sha256 TEXT NOT NULL CHECK (length(payload_sha256) = 64),
    expected_lines INTEGER NOT NULL CHECK (expected_lines > 0),
    status TEXT NOT NULL DEFAULT 'CREATING'
        CHECK (status IN ('CREATING', 'RESERVED', 'CONVERTED', 'CANCELLED')),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    UNIQUE (customer_id, idempotency_key)
);

CREATE TABLE IF NOT EXISTS reservation_lines (
    reservation_id TEXT NOT NULL REFERENCES reservations(id) ON DELETE RESTRICT,
    product_id TEXT NOT NULL REFERENCES inventory(product_id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price_minor INTEGER NOT NULL CHECK (unit_price_minor >= 0),
    currency TEXT NOT NULL CHECK (currency = 'INR'),
    PRIMARY KEY (reservation_id, product_id)
);

CREATE TRIGGER IF NOT EXISTS trg_reserve_line BEFORE INSERT ON reservation_lines
BEGIN
    SELECT RAISE(ABORT, 'reservation is closed')
      WHERE NOT EXISTS (
          SELECT 1 FROM reservations
           WHERE id = NEW.reservation_id AND status = 'CREATING'
      );
    SELECT RAISE(ABORT, 'unknown product or inactive')
      WHERE NOT EXISTS (
          SELECT 1 FROM inventory WHERE product_id = NEW.product_id AND is_active = 1
      );
    SELECT RAISE(ABORT, 'price changed')
      WHERE NOT EXISTS (
          SELECT 1 FROM inventory
           WHERE product_id = NEW.product_id
             AND price_minor = NEW.unit_price_minor
             AND currency = NEW.currency
      );
    UPDATE inventory
       SET available_units = available_units - NEW.quantity,
           updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
     WHERE product_id = NEW.product_id
       AND available_units >= NEW.quantity;
    SELECT RAISE(ABORT, 'insufficient stock') WHERE changes() <> 1;
END;

CREATE TABLE IF NOT EXISTS reservation_seals (
    reservation_id TEXT PRIMARY KEY REFERENCES reservations(id) ON DELETE RESTRICT,
    sealed_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE TRIGGER IF NOT EXISTS trg_seal_before_insert BEFORE INSERT ON reservation_seals
BEGIN
    SELECT RAISE(ABORT, 'incomplete reservation')
      WHERE NOT EXISTS (
          SELECT 1 FROM reservations
           WHERE id = NEW.reservation_id AND status = 'CREATING'
      ) OR (
          SELECT COUNT(*) FROM reservation_lines
           WHERE reservation_id = NEW.reservation_id
      ) <> (
          SELECT expected_lines FROM reservations
           WHERE id = NEW.reservation_id
      );
END;

CREATE TRIGGER IF NOT EXISTS trg_seal_after_insert AFTER INSERT ON reservation_seals
BEGIN
    UPDATE reservations SET status = 'RESERVED'
     WHERE id = NEW.reservation_id AND status = 'CREATING';
    SELECT RAISE(ABORT, 'invalid reservation state') WHERE changes() <> 1;
END;

CREATE TABLE IF NOT EXISTS orders (
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
        CHECK (status IN ('placed', 'confirmed', 'shipped', 'delivered', 'cancelled')),
    payment_status TEXT NOT NULL DEFAULT 'pending'
        CHECK (payment_status IN ('pending', 'paid', 'failed', 'refunded')),
    payment_method TEXT NOT NULL DEFAULT 'cod'
        CHECK (payment_method IN ('cod', 'wallet', 'upi', 'card', 'netbanking')),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    UNIQUE (customer_id, idempotency_key)
);

CREATE TABLE IF NOT EXISTS order_lines (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id TEXT NOT NULL REFERENCES inventory(product_id),
    product_title TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price_minor INTEGER NOT NULL CHECK (unit_price_minor >= 0),
    total_minor INTEGER NOT NULL CHECK (total_minor >= 0),
    currency TEXT NOT NULL CHECK (currency = 'INR')
);

CREATE TABLE IF NOT EXISTS coupons (
    code TEXT PRIMARY KEY,
    description TEXT,
    discount_type TEXT NOT NULL CHECK (discount_type IN ('percentage', 'flat')),
    discount_value REAL NOT NULL CHECK (discount_value >= 0),
    min_order_value REAL NOT NULL DEFAULT 0,
    max_discount_cap REAL,
    is_active INTEGER NOT NULL DEFAULT 1
);

CREATE TRIGGER IF NOT EXISTS trg_cancel_order BEFORE UPDATE OF status ON orders
FOR EACH ROW
WHEN NEW.status = 'cancelled'
BEGIN
    SELECT RAISE(ABORT, 'only placed or confirmed orders can be cancelled')
     WHERE OLD.status NOT IN ('placed', 'confirmed');
END;

