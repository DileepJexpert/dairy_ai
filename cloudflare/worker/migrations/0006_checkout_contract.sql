-- Preserve delivery details when a saved address is edited or removed.
ALTER TABLE customer_addresses ADD COLUMN district TEXT NOT NULL DEFAULT '';
ALTER TABLE customer_addresses ADD COLUMN landmark TEXT;
ALTER TABLE orders ADD COLUMN address_snapshot TEXT NOT NULL DEFAULT '{}';
ALTER TABLE orders ADD COLUMN is_test_order INTEGER NOT NULL DEFAULT 0 CHECK (is_test_order IN (0, 1));

CREATE TRIGGER snapshot_order_address AFTER INSERT ON orders
BEGIN
  UPDATE orders SET address_snapshot = COALESCE((
    SELECT json_object('recipient_name', recipient_name, 'phone', phone,
      'address_line1', address_line1, 'address_line2', address_line2,
      'village_or_city', city, 'district', district, 'state', state,
      'postal_code', pincode, 'landmark', landmark)
    FROM customer_addresses WHERE id = NEW.address_id
  ), '{}') WHERE id = NEW.id;
END;
