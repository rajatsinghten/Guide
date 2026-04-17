"""Claims router.

Primary flow is event-triggered claim creation. A temporary manual claim
endpoint is also exposed until full automation is finalized.
"""

import uuid as _uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.claim import Claim
from app.models.payout import Payout
from app.models.policy import Policy
from app.models.worker import Worker
from app.schemas.claim import ClaimResponse, ManualClaimCreate
from app.services.payout_engine import compute_payout_amount
from app.services.payment_service import disburse_payment
from app.utils.deps import get_current_worker, get_db

router = APIRouter(prefix="/api/v1/claims", tags=["Claims"])


@router.post(
    "/me/manual",
    response_model=ClaimResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Temporarily create a manual claim for the logged-in worker",
)
async def create_manual_claim(
    payload: ManualClaimCreate,
    db: AsyncSession = Depends(get_db),
    current_worker: Worker = Depends(get_current_worker),
) -> Claim:
    """Create a temporary manual claim and auto-disburse payout.

    NOTE: This endpoint is a temporary fallback while event-driven claim
    automation is being finalized.
    """
    policy_result = await db.execute(
        select(Policy)
        .where(
            Policy.worker_id == current_worker.id,
            Policy.status == "active",
        )
        .order_by(Policy.created_at.desc())
    )
    active_policy = policy_result.scalars().first()

    if active_policy is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No active policy found. Buy a policy before claiming.",
        )

    payout_amount = compute_payout_amount(
        coverage_amount_inr=active_policy.coverage_amount_inr,
        severity=payload.severity,
    )

    claim = Claim(
        worker_id=current_worker.id,
        policy_id=active_policy.id,
        claim_type="income_loss",
        event_type="manual",
        event_severity=payload.severity,
        event_description=f"Temporary manual claim created by worker (severity: {payload.severity})",
        status="paid",
        payout_amount_inr=payout_amount,
        fraud_flag=None,
        triggered_at=datetime.now(timezone.utc),
    )

    db.add(claim)
    await db.flush()

    payment_result = await disburse_payment(
        claim_id=claim.id,
        amount_inr=payout_amount,
        payment_method="upi",
    )

    payout = Payout(
        claim_id=claim.id,
        worker_id=current_worker.id,
        amount_inr=payment_result.amount_inr,
        status=payment_result.status,
        transaction_id=payment_result.transaction_id,
        payment_method="upi",
        processed_at=payment_result.processed_at,
    )
    db.add(payout)

    await db.flush()
    await db.refresh(claim)
    return claim


@router.get(
    "/me",
    response_model=list[ClaimResponse],
    summary="Get all claims for the logged-in worker",
)
async def get_my_claims(
    db: AsyncSession = Depends(get_db),
    current_worker: Worker = Depends(get_current_worker),
) -> list[Claim]:
    """Return all claims (pending, approved, paid) for the authenticated worker."""
    result = await db.execute(
        select(Claim)
        .where(Claim.worker_id == current_worker.id)
        .order_by(Claim.created_at.desc())
    )
    return list(result.scalars().all())


@router.get(
    "/{claim_id}",
    response_model=ClaimResponse,
    summary="Get claim detail by ID",
)
async def get_claim(
    claim_id: str,
    db: AsyncSession = Depends(get_db),
    current_worker: Worker = Depends(get_current_worker),
) -> Claim:
    """Return details of a specific claim.

    Workers can only view their own claims.
    """
    try:
        cid = _uuid.UUID(claim_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid claim ID format",
        )

    result = await db.execute(
        select(Claim).where(
            Claim.id == cid,
            Claim.worker_id == current_worker.id,
        )
    )
    claim = result.scalar_one_or_none()
    if claim is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Claim not found",
        )
    return claim
