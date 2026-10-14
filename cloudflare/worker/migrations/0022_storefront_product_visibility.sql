-- Storefront publication is independent from stock availability. A missing row
-- means visible so existing catalogue products remain unchanged after migration.
CREATE TABLE IF NOT EXISTS storefront_product_visibility (
    product_id TEXT PRIMARY KEY,
    is_visible INTEGER NOT NULL DEFAULT 1 CHECK (is_visible IN (0, 1)),
    hidden_reason TEXT,
    updated_by TEXT,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES inventory(product_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_storefront_product_visibility_visible
    ON storefront_product_visibility(is_visible, updated_at DESC);

-- Close the race between checkout validation and atomic reservation creation.
CREATE TRIGGER IF NOT EXISTS trg_reserve_line_storefront_visibility
BEFORE INSERT ON reservation_lines
WHEN EXISTS (
    SELECT 1 FROM storefront_product_visibility
    WHERE product_id = NEW.product_id AND is_visible = 0
)
BEGIN
    SELECT RAISE(ABORT, 'product hidden from storefront');
END;
