-- Persist the single-seller admin controls and delivery exceptions.
CREATE TABLE IF NOT EXISTS inventory_pricing (
    product_id TEXT PRIMARY KEY REFERENCES inventory(product_id),
    mrp_minor INTEGER NOT NULL CHECK (mrp_minor >= 0)
);
ALTER TABLE coupons ADD COLUMN valid_until TEXT;
ALTER TABLE coupons ADD COLUMN usage_count INTEGER NOT NULL DEFAULT 0 CHECK (usage_count >= 0);

CREATE TABLE IF NOT EXISTS order_return_cases (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL UNIQUE REFERENCES orders(id),
    kind TEXT NOT NULL CHECK (kind IN ('rto', 'customer_return')),
    status TEXT NOT NULL DEFAULT 'requested' CHECK (status IN ('requested', 'received', 'rejected')),
    reason TEXT NOT NULL,
    remarks TEXT NOT NULL DEFAULT '',
    refund_reference TEXT,
    restocked INTEGER NOT NULL DEFAULT 0 CHECK (restocked IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    resolved_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_order_return_cases_status ON order_return_cases(status, created_at);

CREATE TRIGGER IF NOT EXISTS trg_return_case_open
BEFORE INSERT ON order_return_cases FOR EACH ROW
BEGIN
    SELECT RAISE(ABORT, 'RTO requires an in-transit order')
      WHERE NEW.kind='rto' AND NOT EXISTS (
        SELECT 1 FROM orders WHERE id=NEW.order_id AND status IN ('shipped','out_for_delivery')
      );
    SELECT RAISE(ABORT, 'customer return requires a delivered order')
      WHERE NEW.kind='customer_return' AND NOT EXISTS (
        SELECT 1 FROM orders WHERE id=NEW.order_id AND status='delivered'
      );
END;

CREATE TRIGGER IF NOT EXISTS trg_return_case_finalize
BEFORE UPDATE OF status ON order_return_cases FOR EACH ROW
WHEN OLD.status != 'requested' OR NEW.status NOT IN ('received', 'rejected')
BEGIN
    SELECT RAISE(ABORT, 'return case already finalized or invalid transition');
END;

CREATE TRIGGER IF NOT EXISTS trg_return_case_blocks_delivery
BEFORE UPDATE OF status ON orders FOR EACH ROW
WHEN NEW.status IN ('shipped', 'out_for_delivery', 'delivered')
 AND EXISTS (SELECT 1 FROM order_return_cases WHERE order_id = OLD.id AND status != 'rejected')
BEGIN
    SELECT RAISE(ABORT, 'order has a return or failed-delivery case');
END;

CREATE TABLE IF NOT EXISTS product_reviews (
    id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL REFERENCES customers(id),
    product_id TEXT NOT NULL REFERENCES inventory(product_id),
    order_id TEXT NOT NULL REFERENCES orders(id),
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    headline TEXT NOT NULL DEFAULT '',
    content TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    rejection_reason TEXT,
    vendor_reply TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    UNIQUE (customer_id, product_id, order_id)
);
CREATE INDEX IF NOT EXISTS idx_product_reviews_product ON product_reviews(product_id, status);

CREATE TABLE IF NOT EXISTS batch_certificates (
    id TEXT PRIMARY KEY,
    product_id TEXT NOT NULL REFERENCES inventory(product_id),
    batch_number TEXT NOT NULL,
    test_date TEXT NOT NULL,
    laboratory TEXT NOT NULL,
    fssai_license TEXT NOT NULL DEFAULT '',
    purity_percent REAL,
    test_parameters TEXT NOT NULL DEFAULT '{}',
    status TEXT NOT NULL CHECK (status IN ('PENDING_REVIEW', 'CERTIFIED', 'REJECTED')),
    certified_by TEXT NOT NULL DEFAULT '',
    remarks TEXT NOT NULL DEFAULT '',
    report_url TEXT,
    UNIQUE (product_id, batch_number)
);

CREATE TABLE IF NOT EXISTS product_families (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    brand TEXT NOT NULL DEFAULT '',
    department TEXT NOT NULL DEFAULT '',
    collection_name TEXT,
    description TEXT NOT NULL DEFAULT '',
    production_method TEXT,
    supporting_documents TEXT NOT NULL DEFAULT '{}',
    status TEXT NOT NULL DEFAULT 'concept_preview',
    vendor_id TEXT NOT NULL DEFAULT 'vendor-1',
    is_published INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);
CREATE TABLE IF NOT EXISTS product_family_variants (
    id TEXT PRIMARY KEY REFERENCES inventory(product_id),
    family_id TEXT NOT NULL REFERENCES product_families(id),
    sku TEXT NOT NULL UNIQUE,
    pack_size TEXT NOT NULL,
    compare_at_price_minor INTEGER,
    publication_status TEXT NOT NULL DEFAULT 'draft'
);

CREATE TABLE IF NOT EXISTS commerce_sellers (
    id TEXT PRIMARY KEY,
    business_name TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('approved', 'suspended', 'rejected')),
    gstin TEXT,
    fssai_license TEXT,
    contact_email TEXT,
    contact_phone TEXT,
    warehouse_city TEXT,
    warehouse_state TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);
INSERT OR IGNORE INTO commerce_sellers(id, business_name, status)
VALUES ('vendor-1', 'Milterra', 'approved');
