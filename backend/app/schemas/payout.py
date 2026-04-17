"""Pydantic schemas for payouts."""

import uuid
from datetime import datetime

from pydantic import BaseModel


class PayoutResponse(BaseModel):
    """Payout record returned by the API."""

    id: uuid.UUID
    claim_id: uuid.UUID
    worker_id: uuid.UUID
    amount_inr: float
    status: str  # pending / processed / failed
    transaction_id: str | None = None
    payment_method: str
    processed_at: datetime | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


class PayoutProcessResponse(BaseModel):
    """Response from POST /payouts/{claim_id}/process — mock payment result."""

    transaction_id: str
    status: str
    amount_inr: float
