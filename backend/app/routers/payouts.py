"""Payouts router — view payout history and process payments.

Workers can view their payout history.  The process endpoint triggers the
mock payment gateway to disburse funds for an approved claim.
"""

import uuid as _uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.claim import Claim
from app.models.payout import Payout
from app.models.worker import Worker
from app.schemas.payout import PayoutProcessResponse, PayoutResponse
from app.utils.deps import get_current_worker, get_db

router = APIRouter(prefix="/api/v1/payouts", tags=["Payouts"])


@router.get(
    "/me",
    response_model=list[PayoutResponse],
    summary="Get payout history for the logged-in worker",
)
async def get_my_payouts(
    db: AsyncSession = Depends(get_db),
    current_worker: Worker = Depends(get_current_worker),
) -> list[Payout]:
    """Return all payouts for the worker.

    Backfills legacy claims that predate auto-disbursement.
    """
    approved_claims_without_payout = await db.execute(
        select(Claim).where(
            Claim.worker_id == current_worker.id,
            Claim.status.in_(["approved", "paid"]),
            ~Claim.payout.has(),
        )
    )
    missing_claims = list(approved_claims_without_payout.scalars().all())

    if missing_claims:
        for claim in missing_claims:
            db.add(
                Payout(
                    claim_id=claim.id,
                    worker_id=current_worker.id,
                    amount_inr=claim.payout_amount_inr,
                    status="processed",
                    transaction_id=f"legacy_{claim.id.hex[:12]}",
                    payment_method="upi",
                    processed_at=claim.created_at,
                )
            )
            claim.status = "paid"
        await db.flush()

    result = await db.execute(
        select(Payout)
        .where(Payout.worker_id == current_worker.id)
        .order_by(Payout.created_at.desc())
    )
    return list(result.scalars().all())


@router.post(
    "/{claim_id}/process",
    response_model=PayoutProcessResponse,
    summary="Process payout for an approved claim",
)
async def process_payout(
    claim_id: str,
    db: AsyncSession = Depends(get_db),
    current_worker: Worker = Depends(get_current_worker),
) -> dict:
    """Deprecated: payouts are now auto-disbursed when claims are created."""
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="Payouts are now sent automatically. Manual processing is no longer needed.",
    )
