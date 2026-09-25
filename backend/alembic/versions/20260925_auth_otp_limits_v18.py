"""Persist resend cooldown and failed verification count for login codes.

Revision ID: auth_otp_limits_v18
Revises: align_commerce_enums_v17
"""
from alembic import op
import sqlalchemy as sa

revision = "auth_otp_limits_v18"
down_revision = "align_commerce_enums_v17"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("otp_last_sent_at", sa.DateTime(), nullable=True))
    op.add_column("users", sa.Column("otp_failed_attempts", sa.Integer(), nullable=False, server_default="0"))


def downgrade() -> None:
    op.drop_column("users", "otp_failed_attempts")
    op.drop_column("users", "otp_last_sent_at")
