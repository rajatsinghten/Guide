"""Payout computation logic.

Computes the payout amount for an approved parametric claim based on the
policy's coverage amount and the severity of the disruption event.  The
severity-to-payout mapping ensures proportional payouts:

    low      → 25 % of coverage
    medium   → 50 % of coverage
    high     → 75 % of coverage
    critical → 100 % of coverage
"""

from app.utils.constants import SEVERITY_PAYOUT_RATIOS


def compute_payout_amount(coverage_amount_inr: float, severity: str) -> float:
    """Compute the payout amount for a claim.

    The payout is a fraction of the policy's coverage amount, scaled by
    event severity.

    Args:
        coverage_amount_inr: The policy's maximum coverage (80 % of weekly income).
        severity: Event severity level (``low`` / ``medium`` / ``high`` / ``critical``).

    Returns:
        The payout amount in INR, rounded to 2 decimal places.
    """
    ratio = SEVERITY_PAYOUT_RATIOS.get(severity, 0.0)
    return round(coverage_amount_inr * ratio, 2)
