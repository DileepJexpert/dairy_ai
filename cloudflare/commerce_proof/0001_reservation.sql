-- Compatibility proof only. These tables do not replace the live commerce schema.
-- Every reservation, line and seal must be sent in one D1Database.batch() call.

CREATE TABLE proof_inventory (
    product_id TEXT PRIMARY KEY,
    available_units INTEGER NOT NULL CHECK (available_units >= 0),
    price_minor INTEGER NOT NULL CHECK (price_minor >= 0),
    currency TEXT NOT NULL CHECK (currency = 'INR')
);

CREATE TABLE proof_reservations (
    id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL,
    idempotency_key TEXT NOT NULL,
    payload_sha256 TEXT NOT NULL CHECK (length(payload_sha256) = 64),
    expected_lines INTEGER NOT NULL CHECK (expected_lines > 0),
    status TEXT NOT NULL DEFAULT 'CREATING'
        CHECK (status IN ('CREATING', 'RESERVED')),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    UNIQUE (customer_id, idempotency_key)
);

CREATE TABLE proof_reservation_lines (
    reservation_id TEXT NOT NULL REFERENCES proof_reservations(id) ON DELETE RESTRICT,
    product_id TEXT NOT NULL REFERENCES proof_inventory(product_id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price_minor INTEGER NOT NULL CHECK (unit_price_minor >= 0),
    currency TEXT NOT NULL CHECK (currency = 'INR'),
    PRIMARY KEY (reservation_id, product_id)
);

-- A conditional UPDATE returning zero affected rows is not a SQL error.
-- RAISE(ABORT) turns that business failure into a D1 batch rollback.
CREATE TRIGGER proof_reserve_line BEFORE INSERT ON proof_reservation_lines
BEGIN
    SELECT RAISE(ABORT, 'reservation is closed')
      WHERE NOT EXISTS (
          SELECT 1 FROM proof_reservations
           WHERE id = NEW.reservation_id AND status = 'CREATING'
      );
    SELECT RAISE(ABORT, 'unknown product')
      WHERE NOT EXISTS (
          SELECT 1 FROM proof_inventory WHERE product_id = NEW.product_id
      );
    SELECT RAISE(ABORT, 'price changed')
      WHERE NOT EXISTS (
          SELECT 1 FROM proof_inventory
           WHERE product_id = NEW.product_id
             AND price_minor = NEW.unit_price_minor
             AND currency = NEW.currency
      );
    UPDATE proof_inventory
       SET available_units = available_units - NEW.quantity
     WHERE product_id = NEW.product_id
       AND available_units >= NEW.quantity;
    SELECT RAISE(ABORT, 'insufficient stock') WHERE changes() <> 1;
END;

CREATE TABLE proof_reservation_seals (
    reservation_id TEXT PRIMARY KEY REFERENCES proof_reservations(id) ON DELETE RESTRICT,
    sealed_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- The final batch statement must insert a seal. Missing lines or a wrong
-- reservation ID cause an SQL error and roll back every prior stock decrement.
CREATE TRIGGER proof_seal_before_insert BEFORE INSERT ON proof_reservation_seals
BEGIN
    SELECT RAISE(ABORT, 'incomplete reservation')
      WHERE NOT EXISTS (
          SELECT 1 FROM proof_reservations
           WHERE id = NEW.reservation_id AND status = 'CREATING'
      ) OR (
          SELECT COUNT(*) FROM proof_reservation_lines
           WHERE reservation_id = NEW.reservation_id
      ) <> (
          SELECT expected_lines FROM proof_reservations
           WHERE id = NEW.reservation_id
      );
END;

CREATE TRIGGER proof_seal_after_insert AFTER INSERT ON proof_reservation_seals
BEGIN
    UPDATE proof_reservations SET status = 'RESERVED'
     WHERE id = NEW.reservation_id AND status = 'CREATING';
    SELECT RAISE(ABORT, 'invalid reservation state') WHERE changes() <> 1;
END;
