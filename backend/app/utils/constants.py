"""Constants used across the GigShield platform.

Centralises disruption thresholds, coverage tiers, and pricing multipliers
so that business rules are easy to audit and adjust.
"""

from dataclasses import dataclass

# ── Parametric Trigger Thresholds ───────────────────────────────────────────

RAINFALL_THRESHOLD_MM = 50.0      # mm rainfall in 24 h
AQI_THRESHOLD = 300               # Air Quality Index
CURFEW_STRIKE_FLAG = True          # Boolean trigger

# ── Coverage Tiers ──────────────────────────────────────────────────────────

COVERAGE_RATIO = 0.80  # 80 % income replacement

# ── Pricing Constants ───────────────────────────────────────────────────────

BASE_PREMIUM_RATE = 0.03  # 3 % of avg weekly income

# Zone risk multipliers — keyed by city, values 1.0 → 1.5
ZONE_RISK_MULTIPLIERS: dict[str, float] = {
    "mumbai": 1.50,
    "chennai": 1.40,
    "kolkata": 1.35,
    "delhi": 1.20,
    "bangalore": 1.10,
    "hyderabad": 1.15,
    "pune": 1.25,
    "ahmedabad": 1.10,
}
DEFAULT_ZONE_RISK_MULTIPLIER = 1.0

# Weather risk factors — keyed by season / city, values 1.0 → 1.3
WEATHER_RISK_FACTORS: dict[str, float] = {
    "mumbai_monsoon": 1.30,
    "chennai_monsoon": 1.25,
    "kolkata_monsoon": 1.20,
    "delhi_winter": 1.15,
    "bangalore_monsoon": 1.10,
}
DEFAULT_WEATHER_RISK_FACTOR = 1.0

# ── Payout Severity Multipliers ────────────────────────────────────────────

SEVERITY_PAYOUT_RATIOS: dict[str, float] = {
    "low": 0.25,
    "medium": 0.50,
    "high": 0.75,
    "critical": 1.00,
}

# ── Fraud Detection ────────────────────────────────────────────────────────

DUPLICATE_CLAIM_WINDOW_HOURS = 48


@dataclass(frozen=True)
class DisruptionThreshold:
    """Immutable record describing a parametric trigger threshold."""

    event_type: str
    threshold_description: str
    auto_action: str


DISRUPTION_THRESHOLDS: list[DisruptionThreshold] = [
    DisruptionThreshold(
        event_type="rainfall",
        threshold_description=f">{RAINFALL_THRESHOLD_MM} mm in 24 h in worker's city",
        auto_action="Auto-create income_loss claim for all active policies in affected city",
    ),
    DisruptionThreshold(
        event_type="aqi",
        threshold_description=f"AQI > {AQI_THRESHOLD} in worker's zone",
        auto_action="Auto-create income_loss claim for all active policies in affected city",
    ),
    DisruptionThreshold(
        event_type="curfew_strike",
        threshold_description="Curfew / strike flag = true for worker's city",
        auto_action="Auto-create income_loss claim for all active policies in affected city",
    ),
]
