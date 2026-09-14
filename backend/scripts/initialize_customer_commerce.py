"""Add customer commerce tables without resetting existing records."""
import asyncio
import app.models  # noqa: F401
from app.database import engine
from app.database import async_session_factory
from app.models.customer_commerce import WishlistEntry, SavedCartItem, OrderContact, OrderEvent, StoreHelp, SupportTicket, CustomerPreferences

MODELS = (WishlistEntry, SavedCartItem, OrderContact, OrderEvent, StoreHelp, SupportTicket, CustomerPreferences)

async def initialize():
    async with engine.begin() as connection:
        for model in MODELS:
            await connection.run_sync(lambda conn, table=model.__table__: table.create(conn, checkfirst=True))
    async with async_session_factory() as db:
        if not await db.get(StoreHelp, 'help'):
            db.add(StoreHelp(key='help', content={
                'contact_message': 'Milterra is preparing for launch. Leave an enquiry below and check this page for our reply. No payment is collected and deliveries have not started.',
                'faqs': [
                    {'category': 'Pre-launch', 'question': 'Can I place an order now?', 'answer': 'You can browse, save products and complete the checkout preview to register purchase interest. This is not a paid order or a delivery commitment.'},
                    {'category': 'Quality', 'question': 'Where can I see product test reports?', 'answer': 'Product pages link to available published reports. Where reports are not available, Quality & Research explains the current status. Concept packaging is illustrative.'},
                    {'category': 'Account', 'question': 'How can I contact Milterra?', 'answer': 'Sign in and submit an enquiry here. Your enquiry and our reply are saved in your account; no SMS payment is required.'},
                ],
            }))
            await db.commit()
    print('Customer commerce tables ready; existing data preserved.')

if __name__ == '__main__':
    asyncio.run(initialize())
