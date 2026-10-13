-- Persistent storefront merchandising. Product facts remain in the published
-- catalogue/inventory; this table stores campaign presentation only.
CREATE TABLE IF NOT EXISTS storefront_campaigns (
    id TEXT PRIMARY KEY,
    product_id TEXT NOT NULL,
    placement_type TEXT NOT NULL DEFAULT 'highlight'
        CHECK (placement_type IN ('highlight', 'deal', 'new_launch', 'featured')),
    headline TEXT NOT NULL,
    subheadline TEXT,
    badge TEXT,
    coupon_code TEXT,
    starts_at TEXT,
    ends_at TEXT,
    priority INTEGER NOT NULL DEFAULT 100,
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES inventory(product_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_storefront_campaigns_public
    ON storefront_campaigns(is_active, priority DESC, starts_at, ends_at);
CREATE INDEX IF NOT EXISTS idx_storefront_campaigns_product
    ON storefront_campaigns(product_id);
