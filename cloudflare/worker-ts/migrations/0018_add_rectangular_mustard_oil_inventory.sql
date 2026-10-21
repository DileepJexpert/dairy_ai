-- Keep the live inventory index aligned with the published catalogue.
-- Stock starts at zero because no authoritative on-hand quantity was supplied.
INSERT INTO inventory (
    product_id,
    title,
    available_units,
    price_minor,
    currency,
    is_active
) VALUES (
    'e7c41a29-8f3b-410a-b28e-5b12da612002',
    'Kacchi Ghani Black Mustard Oil (Rectangular Tin)',
    0,
    43000,
    'INR',
    1
) ON CONFLICT(product_id) DO UPDATE SET
    title = excluded.title,
    price_minor = excluded.price_minor,
    currency = excluded.currency,
    is_active = excluded.is_active;
