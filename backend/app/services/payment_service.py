"""Mock payment gateway integration.

Simulates a Razorpay-like payment disbursement flow for Phase 1.  When
``USE_MOCK_APIS=true``, the gateway returns deterministic success responses
with mock transaction IDs.  The interface is designed for drop-in replacement
with the real Razorpay Payouts API in Phase 2.
"""

import uuid
from dataclasses import dataclass
from datetime import datetime, timezone

from app.config import settings


@dataclass
class PaymentResult:
    """Result of a payment disbursement attempt."""

    transaction_id: str
    status: str  # processed / failed
    amount_inr: float
    processed_at: datetime


async def disburse_payment(
    claim_id: uuid.UUID,
    amount_inr: float,
    payment_method: str = "upi",
) -> PaymentResult:
    """Disburse a payout to a worker's account.

    In mock mode, always returns a successful transaction.  In production,
    this would call the Razorpay Payouts API to initiate a UPI or bank
    transfer.

    Args:
        claim_id: The claim this payment is for (used for idempotency).
        amount_inr: Amount to disburse in INR.
        payment_method: ``upi`` or ``bank_transfer``.

    Returns:
        A ``PaymentResult`` with transaction details.
    """
    if settings.use_mock_apis:
        return PaymentResult(
            transaction_id=f"mock_txn_{uuid.uuid4().hex[:12]}",
            status="processed",
            amount_inr=amount_inr,
            processed_at=datetime.now(timezone.utc),
        )

    # ── Live Razorpay integration placeholder ───────────────────────────
    # In Phase 2, use httpx to call:
    #   POST https://api.razorpay.com/v1/payouts
    #   Headers: Authorization: Basic <key_id:key_secret>
    #   Body: { account_number, fund_account_id, amount, currency, mode, purpose }
    import httpx

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            "https://api.razorpay.com/v1/payouts",
            auth=(settings.razorpay_key_id, settings.razorpay_key_secret),
            json={
                "amount": int(amount_inr * 100),  # Razorpay uses paise
                "currency": "INR",
                "mode": payment_method.upper(),
                "purpose": "payout",
                "reference_id": str(claim_id),
            },
        )
        response.raise_for_status()
        data = response.json()

        return PaymentResult(
            transaction_id=data.get("id", "unknown"),
            status="processed" if data.get("status") == "processed" else "failed",
            amount_inr=amount_inr,
            processed_at=datetime.now(timezone.utc),
        )
