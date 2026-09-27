-- Migration 0009: Seed dedicated admin account for 9839769808 with password Astra@9808
INSERT OR IGNORE INTO customers (id, phone, full_name, role, is_active)
VALUES ('admin-9839769808', '9839769808', 'Milterra Admin', 'admin', 1);

UPDATE customers SET role = 'admin', is_active = 1, full_name = 'Milterra Admin' WHERE phone IN ('9839769808', '+919839769808');

INSERT INTO customer_credentials (customer_id, username, email, password_hash)
SELECT id, 'admin.9839769808', 'admin.9839769808@milterrafoods.com', 'pbkdf2_sha256$600000$MTIzNDU2Nzg5MDEyMzQ1Ng==$rUBL0Mp7JYYWcsh2jZJP20NAT5pOj1aqFu__bZLRhEk='
FROM customers WHERE phone IN ('9839769808', '+919839769808')
ON CONFLICT(customer_id) DO UPDATE SET
    password_hash = 'pbkdf2_sha256$600000$MTIzNDU2Nzg5MDEyMzQ1Ng==$rUBL0Mp7JYYWcsh2jZJP20NAT5pOj1aqFu__bZLRhEk=';
