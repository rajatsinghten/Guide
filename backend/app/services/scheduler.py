"""APScheduler jobs for periodic tasks.

Phase 1 includes a single scheduled job that simulates weekly premium
deduction (burn simulation).  In production, this would integrate with
the payment service to actually charge premiums from worker wallets.

The scheduler is started/stopped via the FastAPI lifespan context manager
in ``main.py``.
"""

import logging
from datetime import datetime, timezone

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from sqlalchemy import select

from app.database import async_session_factory
from app.models.policy import Policy

logger = logging.getLogger("gigshield.scheduler")

scheduler = AsyncIOScheduler()


async def weekly_premium_burn() -> None:
    """Simulate weekly premium deduction for all active policies.

    This job runs every Monday at 00:00 UTC.  In Phase 1 it simply logs the
    deduction; in Phase 2 it will call the payment service to charge the
    worker's linked payment method.

    The job:
    1. Fetches all active policies.
    2. Logs the premium amount that would be charged.
    3. Skips policies whose coverage has not started yet.
    4. Marks expired policies (those past their ``end_date``).
    """
    logger.info("Running weekly premium burn simulation…")

    async with async_session_factory() as session:
        result = await session.execute(
            select(Policy).where(Policy.status == "active")
        )
        active_policies = result.scalars().all()
        now = datetime.now(timezone.utc)

        total_burn = 0.0
        expired_count = 0
        billed_count = 0
        upcoming_count = 0

        for policy in active_policies:
            if policy.end_date and policy.end_date <= now:
                policy.status = "expired"
                expired_count += 1
                continue

            if policy.start_date > now:
                upcoming_count += 1
                continue

            total_burn += policy.weekly_premium_inr
            billed_count += 1
            logger.info(
                "Premium burn: ₹%.2f for policy %s (worker %s)",
                policy.weekly_premium_inr,
                policy.id,
                policy.worker_id,
            )

        await session.commit()

    logger.info(
        "Weekly burn complete: ₹%.2f total from %d billed policies, %d expired, %d upcoming skipped",
        total_burn,
        billed_count,
        expired_count,
        upcoming_count,
    )


def start_scheduler() -> None:
    """Configure and start the APScheduler.

    Adds the weekly premium burn job scheduled for every Monday at midnight UTC.
    """
    scheduler.add_job(
        weekly_premium_burn,
        trigger="cron",
        day_of_week="mon",
        hour=0,
        minute=0,
        id="weekly_premium_burn",
        replace_existing=True,
    )
    scheduler.start()
    logger.info("Scheduler started — weekly premium burn job registered")


def stop_scheduler() -> None:
    """Gracefully shut down the scheduler."""
    if scheduler.running:
        scheduler.shutdown(wait=False)
        logger.info("Scheduler stopped")
