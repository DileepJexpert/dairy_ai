-- Nationwide COD defaults and explicit PIN exceptions. Historical hub rows are
-- location hints only; their prototype fees must not become live charges.
CREATE TABLE delivery_policy (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    cod_default_enabled INTEGER NOT NULL DEFAULT 0 CHECK (cod_default_enabled IN (0, 1)),
    delivery_fee_minor INTEGER NOT NULL DEFAULT 0 CHECK (delivery_fee_minor >= 0),
    prepaid_default_enabled INTEGER NOT NULL DEFAULT 0 CHECK (prepaid_default_enabled IN (0, 1)),
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO delivery_policy (id) VALUES (1);

CREATE TABLE delivery_pincode_rules (
    pincode TEXT PRIMARY KEY CHECK (length(pincode) = 6 AND pincode GLOB '[1-8][0-9][0-9][0-9][0-9][0-9]'),
    cod_enabled INTEGER CHECK (cod_enabled IN (0, 1)),
    prepaid_enabled INTEGER CHECK (prepaid_enabled IN (0, 1)),
    delivery_fee_minor INTEGER CHECK (delivery_fee_minor >= 0),
    city TEXT NOT NULL DEFAULT '',
    state TEXT NOT NULL DEFAULT '',
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (cod_enabled IS NOT NULL OR prepaid_enabled IS NOT NULL OR delivery_fee_minor IS NOT NULL)
);
-- Preserve the owner's previously confirmed free-delivery PIN.
INSERT INTO delivery_pincode_rules (pincode, cod_enabled, delivery_fee_minor, city, state)
VALUES ('201305', 1, 0, 'Noida', 'Uttar Pradesh');
