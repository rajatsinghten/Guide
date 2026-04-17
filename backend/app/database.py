"""SQLAlchemy async engine and session factory.

Provides `async_engine`, `async_session_factory`, and the declarative `Base`
used by all ORM models throughout the GigShield platform.
"""

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.config import settings

async_engine = create_async_engine(
    settings.database_url,
    echo=False,
    future=True,
)

async_session_factory = async_sessionmaker(
    bind=async_engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    """Declarative base for all GigShield ORM models."""
    pass


async def init_database() -> None:
    """Ensure database schema exists for local/dev environments.

    Imports models so SQLAlchemy metadata is populated, then creates any
    missing tables. This avoids runtime failures when migrations have not
    been generated/applied yet.
    """
    from app.models.claim import Claim  # noqa: F401
    from app.models.payout import Payout  # noqa: F401
    from app.models.policy import Policy  # noqa: F401
    from app.models.worker import Worker  # noqa: F401

    async with async_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
