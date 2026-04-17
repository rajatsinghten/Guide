"""Pricing engine for weekly parametric income-loss insurance.

Implements the exact pricing formula specified for GigShield Phase 1:

    base_premium   = avg_weekly_income × 0.03
    zone_risk_mult = 1.0 – 1.5  (city-based flood history)
    weather_risk   = 1.0 – 1.3  (season / city)
    weekly_premium = base_premium × zone_risk_mult × weather_risk
    coverage       = avg_weekly_income × 0.80  (80 % income replacement)

The engine returns a ``PremiumBreakdown`` containing every component of the
calculation so that the result is fully auditable.
"""

from dataclasses import dataclass, field

from app.utils.constants import (
    BASE_PREMIUM_RATE,
    COVERAGE_RATIO,
    DEFAULT_WEATHER_RISK_FACTOR,
    DEFAULT_ZONE_RISK_MULTIPLIER,
    WEATHER_RISK_FACTORS,
    ZONE_RISK_MULTIPLIERS,
)


@dataclass(frozen=True)
class RiskFactor:
    """A single risk factor that influences the premium calculation.

    Attributes:
        name: Human-readable name of the risk factor.
        value: The numeric multiplier or metric associated with this factor.
        description: Explanation of why this factor matters.
    """

    name: str
    value: float
    description: str


@dataclass
class PremiumBreakdown:
    """Complete breakdown of a weekly premium calculation.

    Every field of the pricing formula is exposed so that the result can be
    displayed transparently to the worker and audited by regulators.
    """

    weekly_premium_inr: float
    coverage_amount_inr: float
    risk_score: float
    base_premium: float
    zone_risk_multiplier: float
    weather_risk_factor: float
    risk_factors: list[RiskFactor] = field(default_factory=list)


def _get_current_season() -> str:
    """Return a rough season label for India based on the current month.

    Used to look up weather risk factors.  A simple heuristic for Phase 1.
    """
    from datetime import datetime, timezone

    month = datetime.now(timezone.utc).month
    if month in (6, 7, 8, 9):
        return "monsoon"
    elif month in (11, 12, 1, 2):
        return "winter"
    return "summer"


def calculate_premium(
    avg_weekly_income_inr: float,
    city: str,
    pincode: str,
) -> PremiumBreakdown:
    """Calculate the weekly insurance premium for a delivery worker.

    This is the core pricing function of GigShield.  It applies the
    three-factor formula (base × zone × weather) and returns a fully
    transparent ``PremiumBreakdown``.

    Args:
        avg_weekly_income_inr: Worker's self-reported average weekly income.
        city: Worker's registered city (used for zone risk lookup).
        pincode: Worker's registered pincode (reserved for future use).

    Returns:
        A ``PremiumBreakdown`` with all calculation components.
    """
    risk_factors: list[RiskFactor] = []
    city_lower = city.lower()

    # ── Step 1: Base Premium ────────────────────────────────────────────
    base_premium = avg_weekly_income_inr * BASE_PREMIUM_RATE

    # ── Step 2: Zone Risk Multiplier ────────────────────────────────────
    zone_risk_multiplier = ZONE_RISK_MULTIPLIERS.get(
        city_lower, DEFAULT_ZONE_RISK_MULTIPLIER
    )
    if zone_risk_multiplier > 1.0:
        risk_factors.append(
            RiskFactor(
                name="flood_zone_history",
                value=zone_risk_multiplier,
                description=f"{city} has elevated historical flood risk "
                f"(multiplier {zone_risk_multiplier}×)",
            )
        )

    # ── Step 3: Weather Risk Factor ─────────────────────────────────────
    season = _get_current_season()
    weather_key = f"{city_lower}_{season}"
    weather_risk_factor = WEATHER_RISK_FACTORS.get(
        weather_key, DEFAULT_WEATHER_RISK_FACTOR
    )
    if weather_risk_factor > 1.0:
        risk_factors.append(
            RiskFactor(
                name="seasonal_weather_risk",
                value=weather_risk_factor,
                description=f"Current {season} season in {city} increases risk "
                f"(factor {weather_risk_factor}×)",
            )
        )

    # ── Step 4: Final Calculation ───────────────────────────────────────
    weekly_premium = round(base_premium * zone_risk_multiplier * weather_risk_factor, 2)
    coverage_amount = round(avg_weekly_income_inr * COVERAGE_RATIO, 2)

    # Risk score: normalised 0-10 based on combined multipliers
    combined_multiplier = zone_risk_multiplier * weather_risk_factor
    risk_score = round(min((combined_multiplier - 1.0) * 10 / 0.95, 10.0), 2)

    return PremiumBreakdown(
        weekly_premium_inr=weekly_premium,
        coverage_amount_inr=coverage_amount,
        risk_score=risk_score,
        base_premium=round(base_premium, 2),
        zone_risk_multiplier=zone_risk_multiplier,
        weather_risk_factor=weather_risk_factor,
        risk_factors=risk_factors,
    )
