-- Fail closed until real customer identities and delivery coverage are imported.
ALTER TABLE customers ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1));

CREATE TABLE serviceable_pincodes (
    pincode TEXT PRIMARY KEY CHECK (length(pincode) = 6 AND pincode NOT GLOB '*[^0-9]*'),
    city TEXT NOT NULL,
    state TEXT NOT NULL,
    is_serviceable INTEGER NOT NULL DEFAULT 0 CHECK (is_serviceable IN (0, 1)),
    delivery_fee_minor INTEGER NOT NULL DEFAULT 0 CHECK (delivery_fee_minor >= 0),
    delivery_days_min INTEGER NOT NULL DEFAULT 1,
    delivery_days_max INTEGER NOT NULL DEFAULT 2
);

-- Earlier prototype seed rows must never become real customer/coupon records.
DELETE FROM customer_addresses WHERE id IN ('addr-1', 'addr-2') AND customer_id = 'user-1';
DELETE FROM customers WHERE id = 'user-1' AND phone = '+919999900000';
DELETE FROM coupons WHERE code = 'MILTERRA10'
    AND description = '10% off on orders above Rs 499'
    AND discount_type = 'percentage' AND discount_value = 10.0 AND min_order_value = 499.0;
DELETE FROM coupons WHERE code = 'FARMER50'
    AND description = 'Rs 50 off on orders above Rs 299'
    AND discount_type = 'flat' AND discount_value = 50.0 AND min_order_value = 299.0;
