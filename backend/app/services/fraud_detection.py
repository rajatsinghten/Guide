"""Basic fraud detection stubs for Phase 1.

Two checks are implemented as placeholders:

1. **Duplicate claim window** — Flags a claim if the same worker already has
   a claim for the same event type within the last 48 hours.
2. **Location mismatch** — Flags a claim if the worker's registered GPS zone
   does not match the city of the disruption event (stub: always passes in
   Phase 1, since live GPS is not available).

Both checks return ``None`` (clean) or a human-readable flag string.
"""

import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.claim import Claim
from app.utils.constants import DUPLICATE_CLAIM_WINDOW_HOURS

_FRAUD_FLAG_MAX_LEN = getattr(Claim.__table__.c.fraud_flag.type, "length", 100) or 100


def _fit_fraud_flag(flag: str) -> str:
    """Clamp fraud flags to the DB column limit to avoid insert failures."""
    return flag[:_FRAUD_FLAG_MAX_LEN]


async def check_duplicate_claim(
    db: AsyncSession,
    worker_id: uuid.UUID,
    event_type: str,
) -> str | None:
    """Check for duplicate claims within the 48-hour window.

    Args:
        db: Async database session.
        worker_id: The worker's UUID.
        event_type: Type of disruption event.

    Returns:
        A fraud flag string if a duplicate is found, otherwise ``None``.
    """
    cutoff = datetime.now(timezone.utc) - timedelta(hours=DUPLICATE_CLAIM_WINDOW_HOURS)

    stmt = select(Claim).where(
        Claim.worker_id == worker_id,
        Claim.event_type == event_type,
        Claim.triggered_at >= cutoff,
    )
    result = await db.execute(stmt)
    existing = result.scalars().first()

    if existing is not None:
        return _fit_fraud_flag(
            f"DUPLICATE_CLAIM_{DUPLICATE_CLAIM_WINDOW_HOURS}H:"
            f"{event_type}:{existing.id}"
        )
    return None


async def check_location_mismatch(
    worker_id: uuid.UUID,
    city: str,
) -> str | None:
    """Check if the worker's GPS zone matches the disruption city.

    Phase 1 stub: Always returns ``None`` (no mismatch detected) because
    live GPS tracking is not yet integrated.  In Phase 2, this will compare
    the worker's last-known latitude/longitude against the event city's
    geographic bounds.

    Args:
        worker_id: The worker's UUID.
        city: City where the disruption event occurred.

    Returns:
        A fraud flag string if a mismatch is detected, otherwise ``None``.
    """
    # Phase 1 stub — always clean
    return None


async def run_fraud_checks(
    db: AsyncSession,
    worker_id: uuid.UUID,
    city: str,
    event_type: str,
) -> str | None:
    """Run all Phase 1 fraud checks for a claim.

    Returns the first fraud flag encountered, or ``None`` if all checks pass.

    Args:
        db: Async database session.
        worker_id: The worker's UUID.
        city: City where the disruption event occurred.
        event_type: Type of disruption event.

    Returns:
        A fraud flag string, or ``None`` if clean.
    """
    # Check 1: Duplicate claim within 48 h
    flag = await check_duplicate_claim(db, worker_id, event_type)
    if flag:
        return _fit_fraud_flag(flag)

    # Check 2: GPS location mismatch
    flag = await check_location_mismatch(worker_id, city)
    if flag:
        return _fit_fraud_flag(flag)

    return None
