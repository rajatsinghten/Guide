"""FastAPI dependency injection helpers.

Provides reusable ``Depends`` callables for database sessions and
authenticated worker extraction from JWT tokens.
"""

import uuid

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import async_session_factory
from app.models.worker import Worker
from app.utils.auth import decode_access_token

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/workers/login")


async def get_db() -> AsyncSession:  # type: ignore[misc]
    """Yield an async database session, ensuring proper cleanup."""
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


async def get_current_worker(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> Worker:
    """Extract and validate the authenticated worker from a JWT bearer token.

    Raises:
        HTTPException 401: If the token is invalid or the worker is not found.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    payload = decode_access_token(token)
    if payload is None:
        raise credentials_exception

    worker_id_str: str | None = payload.get("sub")
    if worker_id_str is None:
        raise credentials_exception

    try:
        worker_id = uuid.UUID(worker_id_str)
    except ValueError:
        raise credentials_exception

    result = await db.execute(select(Worker).where(Worker.id == worker_id))
    worker = result.scalar_one_or_none()
    if worker is None:
        raise credentials_exception

    return worker
