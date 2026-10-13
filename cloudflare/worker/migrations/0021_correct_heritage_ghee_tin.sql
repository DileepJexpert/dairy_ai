-- Align live inventory with the intended 2 litre heritage ghee tin catalogue SKU.
-- Preserve the existing product UUID so carts and order history remain linked.
UPDATE inventory
SET title = 'Milterra A2 Sahiwal Cow Ghee (Heritage Tin)',
    price_minor = 299900,
    currency = 'INR',
    is_active = 1
WHERE product_id = '0e12db10-a3a8-40c2-a004-6ccdcb9d710b';
