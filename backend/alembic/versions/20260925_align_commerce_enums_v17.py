"""Align commerce enum types, values, and casing with ORM.

Revision ID: align_commerce_enums_v17
Revises: order_inventory_release_v16
"""
from alembic import op
import sqlalchemy as sa

revision = "align_commerce_enums_v17"
down_revision = "order_inventory_release_v16"
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    dialect = conn.dialect.name

    if dialect == "postgresql":
        # 1. Drop column defaults before altering types
        op.execute("ALTER TABLE orders ALTER COLUMN status DROP DEFAULT;")
        op.execute("ALTER TABLE orders ALTER COLUMN payment_status DROP DEFAULT;")
        op.execute("ALTER TABLE order_items ALTER COLUMN fulfillment_status DROP DEFAULT;")

        # 2. Convert enum columns to text to detach from old types
        op.execute("ALTER TABLE orders ALTER COLUMN status TYPE text USING status::text;")
        op.execute("ALTER TABLE orders ALTER COLUMN payment_status TYPE text USING payment_status::text;")
        op.execute("ALTER TABLE order_items ALTER COLUMN fulfillment_status TYPE text USING fulfillment_status::text;")

        # 3. Normalize existing values to canonical uppercase
        op.execute("""
            UPDATE orders SET status = CASE
                WHEN upper(status) IN ('CONFIRMED', 'COMPLETED') THEN 'CONFIRMED'
                WHEN upper(status) IN ('CANCELLED', 'CANCELED') THEN 'CANCELLED'
                ELSE 'PENDING_PAYMENT'
            END;
        """)
        op.execute("""
            UPDATE orders SET payment_status = CASE
                WHEN upper(payment_status) = 'PAID' THEN 'PAID'
                WHEN upper(payment_status) = 'FAILED' THEN 'FAILED'
                WHEN upper(payment_status) = 'REFUNDED' THEN 'REFUNDED'
                ELSE 'PENDING'
            END;
        """)
        op.execute("""
            UPDATE order_items SET fulfillment_status = CASE
                WHEN upper(fulfillment_status) = 'CONFIRMED' THEN 'CONFIRMED'
                WHEN upper(fulfillment_status) = 'PACKED' THEN 'PACKED'
                WHEN upper(fulfillment_status) = 'SHIPPED' THEN 'SHIPPED'
                WHEN upper(fulfillment_status) = 'DELIVERED' THEN 'DELIVERED'
                WHEN upper(fulfillment_status) = 'CANCELLED' THEN 'CANCELLED'
                ELSE 'PENDING'
            END;
        """)

        # 4. Cleanly recreate enum types with uppercase values
        op.execute("DROP TYPE IF EXISTS orderstatus CASCADE;")
        op.execute("CREATE TYPE orderstatus AS ENUM ('PENDING_PAYMENT', 'CONFIRMED', 'CANCELLED');")
        op.execute("DROP TYPE IF EXISTS commerce_payment_status CASCADE;")
        op.execute("CREATE TYPE commerce_payment_status AS ENUM ('PENDING', 'PAID', 'FAILED', 'REFUNDED');")
        op.execute("DROP TYPE IF EXISTS fulfillmentstatus CASCADE;")
        op.execute("CREATE TYPE fulfillmentstatus AS ENUM ('PENDING', 'CONFIRMED', 'PACKED', 'SHIPPED', 'DELIVERED', 'CANCELLED');")

        # 5. Convert columns to new enum types
        op.execute("ALTER TABLE orders ALTER COLUMN status TYPE orderstatus USING status::orderstatus;")
        op.execute("ALTER TABLE orders ALTER COLUMN payment_status TYPE commerce_payment_status USING payment_status::commerce_payment_status;")
        op.execute("ALTER TABLE order_items ALTER COLUMN fulfillment_status TYPE fulfillmentstatus USING fulfillment_status::fulfillmentstatus;")

        # 6. Restore defaults
        op.execute("ALTER TABLE orders ALTER COLUMN status SET DEFAULT 'PENDING_PAYMENT'::orderstatus;")
        op.execute("ALTER TABLE orders ALTER COLUMN payment_status SET DEFAULT 'PENDING'::commerce_payment_status;")
        op.execute("ALTER TABLE order_items ALTER COLUMN fulfillment_status SET DEFAULT 'PENDING'::fulfillmentstatus;")


def downgrade() -> None:
    pass
