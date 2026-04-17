"""Dashboard router — worker and admin summary views.

Provides at-a-glance metrics for individual workers (their policy, claims,
payouts) and platform-wide admin statistics (total workers, liability, etc.).
"""

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.claim import Claim
from app.models.payout import Payout
from app.models.policy import Policy
from app.models.worker import Worker
from app.services.mock_event_simulator import next_worker_risk_snapshot
from app.utils.deps import get_current_worker, get_db

router = APIRouter(prefix="/api/v1/dashboard", tags=["Dashboard"])


@router.get("/worker", summary="Worker dashboard summary")
async def worker_dashboard(
    db: AsyncSession = Depends(get_db),
    current_worker: Worker = Depends(get_current_worker),
) -> dict:
    """Return a personalised dashboard for the authenticated worker.

    Includes:
    - Active policy summary
    - Income protected this week
    - Claims this month
    - Total payouts received
    """
    # Active policy
    policy_result = await db.execute(
        select(Policy).where(
            Policy.worker_id == current_worker.id,
            Policy.status == "active",
        )
    )
    active_policy = policy_result.scalar_one_or_none()

    # Claims this month
    month_start = datetime.now(timezone.utc).replace(
        day=1, hour=0, minute=0, second=0, microsecond=0
    )
    claims_result = await db.execute(
        select(func.count(Claim.id)).where(
            Claim.worker_id == current_worker.id,
            Claim.created_at >= month_start,
        )
    )
    claims_this_month = claims_result.scalar() or 0

    # Total payouts
    payout_result = await db.execute(
        select(func.coalesce(func.sum(Payout.amount_inr), 0.0)).where(
            Payout.worker_id == current_worker.id,
            Payout.status == "processed",
        )
    )
    payout_total = payout_result.scalar() or 0.0

    risk_today = await next_worker_risk_snapshot(
        db=db,
        worker=current_worker,
        active_policy=active_policy,
    )

    return {
        "active_policy": {
            "id": str(active_policy.id),
            "weekly_premium_inr": active_policy.weekly_premium_inr,
            "coverage_amount_inr": active_policy.coverage_amount_inr,
            "start_date": active_policy.start_date.isoformat(),
            "end_date": active_policy.end_date.isoformat() if active_policy.end_date else None,
        }
        if active_policy
        else None,
        "income_protected_this_week": active_policy.coverage_amount_inr
        if active_policy
        else 0.0,
        "claims_this_month": claims_this_month,
        "payout_total": float(payout_total),
        "risk_today": risk_today,
    }


@router.get("/admin", summary="Admin dashboard summary")
async def admin_dashboard(
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Return platform-wide admin dashboard metrics.

    Includes:
    - Total registered workers
    - Active policies count
    - Claims triggered today
    - Total payout liability
    - Top disruption event type
    """
    # Total workers
    workers_result = await db.execute(select(func.count(Worker.id)))
    total_workers = workers_result.scalar() or 0

    # Active policies
    policies_result = await db.execute(
        select(func.count(Policy.id)).where(Policy.status == "active")
    )
    active_policies = policies_result.scalar() or 0

    # Claims triggered today
    today_start = datetime.now(timezone.utc).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    claims_today_result = await db.execute(
        select(func.count(Claim.id)).where(Claim.created_at >= today_start)
    )
    claims_triggered_today = claims_today_result.scalar() or 0

    # Total payout liability (sum of pending claim amounts)
    liability_result = await db.execute(
        select(func.coalesce(func.sum(Claim.payout_amount_inr), 0.0)).where(
            Claim.status.in_(["pending", "approved"])
        )
    )
    payout_liability_inr = liability_result.scalar() or 0.0

    # Top disruption event type (most claims)
    top_event_result = await db.execute(
        select(Claim.event_type, func.count(Claim.id).label("cnt"))
        .group_by(Claim.event_type)
        .order_by(func.count(Claim.id).desc())
        .limit(1)
    )
    top_row = top_event_result.first()
    top_disruption_event = top_row[0] if top_row else None

    return {
        "total_workers": total_workers,
        "active_policies": active_policies,
        "claims_triggered_today": claims_triggered_today,
        "payout_liability_inr": float(payout_liability_inr),
        "top_disruption_event": top_disruption_event,
    }
