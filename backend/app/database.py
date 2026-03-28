import logging
from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import declarative_base

from app.config import settings

logger = logging.getLogger("dairy_ai.database")

logger.info(f"Creating async engine with DATABASE_URL={settings.DATABASE_URL[:30]}...")
engine = create_async_engine(settings.DATABASE_URL, echo=False)

async_session_factory = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)
logger.info("Async session factory created")

Base = declarative_base()


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    logger.debug("Opening new database session")
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
            logger.debug("Database session committed successfully")
        except Exception as e:
            logger.error(f"Database session error, rolling back: {e}")
            await session.rollback()
            raise


async def init_db() -> None:
    logger.info("Running Base.metadata.create_all to ensure all tables exist...")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("All database tables created/verified")
