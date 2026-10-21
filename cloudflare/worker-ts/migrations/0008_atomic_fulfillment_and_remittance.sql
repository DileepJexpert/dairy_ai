-- Migration 0008: Enforce atomic state transitions and guards on orders and COD remittance
CREATE TRIGGER IF NOT EXISTS trg_order_fulfillment_transition
BEFORE UPDATE OF status ON orders
FOR EACH ROW
BEGIN
    SELECT RAISE(ABORT, 'cannot modify cancelled order')
     WHERE OLD.status = 'cancelled' AND NEW.status != 'cancelled';

    SELECT RAISE(ABORT, 'cannot modify delivered order')
     WHERE OLD.status = 'delivered' AND NEW.status != 'delivered';

    SELECT RAISE(ABORT, 'cannot pack unless placed or confirmed')
     WHERE NEW.status = 'packed' AND OLD.status NOT IN ('placed', 'confirmed');

    SELECT RAISE(ABORT, 'cannot ship unless packed')
     WHERE NEW.status = 'shipped' AND OLD.status != 'packed';

    SELECT RAISE(ABORT, 'cannot mark out for delivery unless shipped')
     WHERE NEW.status = 'out_for_delivery' AND OLD.status != 'shipped';

    SELECT RAISE(ABORT, 'cannot deliver unless shipped or out for delivery')
     WHERE NEW.status = 'delivered' AND OLD.status NOT IN ('shipped', 'out_for_delivery');
END;

CREATE TRIGGER IF NOT EXISTS trg_order_remittance
BEFORE UPDATE OF payment_status ON orders
FOR EACH ROW
WHEN NEW.payment_status = 'paid' AND NEW.payment_method = 'cod'
BEGIN
    SELECT RAISE(ABORT, 'order must be delivered before COD remittance')
     WHERE OLD.status != 'delivered' AND NEW.status != 'delivered';

    SELECT RAISE(ABORT, 'COD order is already paid')
     WHERE OLD.payment_status = 'paid';
END;
