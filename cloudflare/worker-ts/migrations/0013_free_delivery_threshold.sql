-- An optional cart-subtotal threshold for free delivery. NULL keeps a flat fee.
-- Apply after 0011_delivery_policy.sql; the owner configures the live amount.
ALTER TABLE delivery_policy ADD COLUMN free_delivery_above_minor INTEGER
    CHECK (free_delivery_above_minor IS NULL OR free_delivery_above_minor >= 0);
