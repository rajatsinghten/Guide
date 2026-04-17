"""Disruption event detection and auto-claim creation engine.

This is the heart of the parametric insurance model.  When an external event
(rainfall, AQI spike, curfew/strike) crosses a defined threshold, the event
engine automatically creates income-loss claims for every worker with an active
policy in the affected city — no manual claim filing required.

Phase 1 Triggers:
    • Rainfall > 50 mm in 24 h in worker's city
    • AQI > 300 in worker's zone
    • Curfew / strike flag for worker's city
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.claim import Claim
from app.models.payout import Payout
from app.models.policy import Policy
from app.models.worker import Worker
from app.services.fraud_detection import run_fraud_checks
from app.services.payment_service import disburse_payment
from app.services.payout_engine import compute_payout_amount
from app.utils.constants import AQI_THRESHOLD, RAINFALL_THRESHOLD_MM


def evaluate_threshold(event_type: str, severity: str) -> bool:
    """Determine whether the event meets the parametric trigger threshold.

    In Phase 1, any event ingested via the trigger endpoint is assumed to have
    already been validated against external data.  The severity determines
    whether the threshold is crossed:

        • ``high`` and ``critical`` always trigger.
        • ``medium`` triggers for rainfall and AQI.
        • ``low`` does not trigger.

    Args:
        event_type: One of ``rainfall``, ``aqi``, ``curfew_strike``.
        severity: One of ``low``, ``medium``, ``high``, ``critical``.

    Returns:
        ``True`` if the threshold is met and claims should be created.
    """
    if severity in ("high", "critical"):
        return True
    if severity == "medium" and event_type in ("rainfall", "aqi"):
        return True
    return False


async def process_event(
    db: AsyncSession,
    event_type: str,
    city: str,
    severity: str,
    timestamp: datetime,
) -> list[uuid.UUID]:
    """Process a disruption event and create claims for eligible workers.

    This function:
    1. Checks if the event meets the parametric trigger threshold.
    2. Finds all workers in the affected city with active policies.
    3. Runs Phase 1 fraud checks on each worker.
    4. Computes the payout amount based on severity and coverage.
    5. Auto-disburses payment and creates ``Payout`` records.
    6. Creates ``Claim`` records for eligible workers.

    Args:
        db: Async database session.
        event_type: Type of disruption event.
        city: Affected city.
        severity: Event severity level.
        timestamp: When the event occurred.

    Returns:
        List of created claim UUIDs.
    """
    normalized_city = city.strip()
    if not normalized_city:
        return []

    if not evaluate_threshold(event_type, severity):
        return []

    # Find active policies for workers in the affected city
    stmt = (
        select(Policy)
        .join(Worker, Policy.worker_id == Worker.id)
        .where(
            func.lower(func.trim(Worker.city)) == normalized_city.lower(),
            Policy.status == "active",
        )
    )
    result = await db.execute(stmt)
    policies = result.scalars().all()

    claim_ids: list[uuid.UUID] = []

    for policy in policies:
        # Run fraud checks
        fraud_flag = await run_fraud_checks(
            db=db,
            worker_id=policy.worker_id,
            city=normalized_city,
            event_type=event_type,
        )

        # Compute payout
        payout_amount = compute_payout_amount(
            coverage_amount_inr=policy.coverage_amount_inr,
            severity=severity,
        )

        # Flagged claims are recorded but not auto-paid.
        if fraud_flag is not None:
            claim = Claim(
                worker_id=policy.worker_id,
                policy_id=policy.id,
                claim_type="income_loss",
                event_type=event_type,
                event_severity=severity,
                event_description=(
                    f"{event_type.replace('_', ' ').title()} event in {normalized_city} — "
                    f"severity: {severity}"
                ),
                status="rejected",
                payout_amount_inr=0.0,
                fraud_flag=fraud_flag,
                triggered_at=timestamp,
            )
            db.add(claim)
            await db.flush()
            claim_ids.append(claim.id)
            continue

        event_description = (
            f"{event_type.replace('_', ' ').title()} event in {normalized_city} — "
            f"severity: {severity}"
        )

        claim = Claim(
            worker_id=policy.worker_id,
            policy_id=policy.id,
            claim_type="income_loss",
            event_type=event_type,
            event_severity=severity,
            event_description=event_description,
            status="paid",
            payout_amount_inr=payout_amount,
            fraud_flag=None,
            triggered_at=timestamp,
        )
        db.add(claim)
        await db.flush()

        payment_result = await disburse_payment(
            claim_id=claim.id,
            amount_inr=payout_amount,
            payment_method="upi",
        )

        if payment_result.status != "processed":
            claim.status = "rejected"

        payout = Payout(
            claim_id=claim.id,
            worker_id=policy.worker_id,
            amount_inr=payment_result.amount_inr,
            status=payment_result.status,
            transaction_id=payment_result.transaction_id,
            payment_method="upi",
            processed_at=payment_result.processed_at,
        )
        db.add(payout)

        claim_ids.append(claim.id)

    return claim_ids
