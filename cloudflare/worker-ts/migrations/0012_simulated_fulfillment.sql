-- Test-only movements are separate from real COD remittances and bank refunds.
-- The API gate also requires an isolated test-commerce deployment.
CREATE TABLE simulated_money_movements (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL REFERENCES orders(id),
    kind TEXT NOT NULL CHECK (kind IN ('cod_collection', 'cod_refund')),
    amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
    reference TEXT NOT NULL UNIQUE CHECK (reference LIKE 'SIM-%'),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    UNIQUE (order_id, kind)
);

CREATE TRIGGER simulated_money_test_orders_only
BEFORE INSERT ON simulated_money_movements FOR EACH ROW
BEGIN
    SELECT RAISE(ABORT, 'simulated movement requires a test order')
      WHERE NOT EXISTS (SELECT 1 FROM orders WHERE id=NEW.order_id AND is_test_order=1);
    SELECT RAISE(ABORT, 'simulated collection requires delivered paid COD')
      WHERE NEW.kind='cod_collection' AND NOT EXISTS (
        SELECT 1 FROM orders WHERE id=NEW.order_id AND status='delivered'
        AND payment_method='cod' AND payment_status='paid' AND total_minor=NEW.amount_minor
        AND NOT EXISTS (SELECT 1 FROM order_return_cases
                        WHERE order_id=NEW.order_id AND status!='rejected')
      );
    SELECT RAISE(ABORT, 'simulated refund requires a received return')
      WHERE NEW.kind='cod_refund' AND NOT EXISTS (
        SELECT 1 FROM orders o JOIN order_return_cases r ON r.order_id=o.id
        WHERE o.id=NEW.order_id AND o.payment_status='refunded'
        AND o.payment_method='cod' AND o.total_minor=NEW.amount_minor
        AND r.kind='customer_return' AND r.status='received'
      );
END;

CREATE TRIGGER simulated_money_immutable_update
BEFORE UPDATE ON simulated_money_movements FOR EACH ROW
BEGIN
    SELECT RAISE(ABORT, 'simulated movements are append-only');
END;

CREATE TRIGGER simulated_money_immutable_delete
BEFORE DELETE ON simulated_money_movements FOR EACH ROW
BEGIN
    SELECT RAISE(ABORT, 'simulated movements are append-only');
END;
