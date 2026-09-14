"""Add customer username, email, profile name, and password recovery fields.

Revision ID: customer_identity_v10
Revises: merchandising_placements_v9
"""

from alembic import op
import sqlalchemy as sa


revision = "customer_identity_v10"
down_revision = "merchandising_placements_v9"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("username", sa.String(50), nullable=True))
    op.add_column("users", sa.Column("email", sa.String(254), nullable=True))
    op.add_column("users", sa.Column("display_name", sa.String(120), nullable=True))
    op.add_column(
        "users", sa.Column("password_reset_token_hash", sa.String(64), nullable=True)
    )
    op.add_column(
        "users", sa.Column("password_reset_expires_at", sa.DateTime(), nullable=True)
    )
    op.create_index("ix_users_username", "users", ["username"], unique=True)
    op.create_index("ix_users_email", "users", ["email"], unique=True)
    op.create_unique_constraint(
        "uq_users_password_reset_token_hash", "users", ["password_reset_token_hash"]
    )


def downgrade() -> None:
    op.drop_constraint(
        "uq_users_password_reset_token_hash", "users", type_="unique"
    )
    op.drop_index("ix_users_email", table_name="users")
    op.drop_index("ix_users_username", table_name="users")
    op.drop_column("users", "password_reset_expires_at")
    op.drop_column("users", "password_reset_token_hash")
    op.drop_column("users", "display_name")
    op.drop_column("users", "email")
    op.drop_column("users", "username")
