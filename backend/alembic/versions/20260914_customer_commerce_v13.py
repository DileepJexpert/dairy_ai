"""Persistent customer commerce state (additive tables only)."""
from alembic import op
from app.models.customer_commerce import WishlistEntry, SavedCartItem, OrderContact, OrderEvent, StoreHelp, SupportTicket, CustomerPreferences

revision = 'customer_commerce_v13'
down_revision = 'commerce_admin_v12'
branch_labels = None
depends_on = None

def upgrade():
    for model in (WishlistEntry, SavedCartItem, OrderContact, OrderEvent, StoreHelp, SupportTicket, CustomerPreferences):
        model.__table__.create(op.get_bind(), checkfirst=True)

def downgrade():
    for model in (CustomerPreferences, SupportTicket, StoreHelp, OrderEvent, OrderContact, SavedCartItem, WishlistEntry):
        model.__table__.drop(op.get_bind(), checkfirst=True)
