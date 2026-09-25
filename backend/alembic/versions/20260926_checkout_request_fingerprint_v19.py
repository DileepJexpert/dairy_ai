"""Bind order idempotency keys to the checkout request that created them.

Revision ID: checkout_request_fingerprint_v19
Revises: auth_otp_limits_v18
"""
from alembic import op
import sqlalchemy as sa

revision = "checkout_request_fingerprint_v19"
down_revision = "auth_otp_limits_v18"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Existing orders have no original request payload. Their retries are
    # checked against saved address, contact, coupon, and total instead.
    op.add_column("orders", sa.Column("checkout_request_fingerprint", sa.String(64), nullable=True))


def downgrade() -> None:
    op.drop_column("orders", "checkout_request_fingerprint")
