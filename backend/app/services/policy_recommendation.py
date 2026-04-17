"""Policy recommendation service.

Always generates exactly 3 plans (Basic, Standard, High) tailored to the
worker profile using a normalized risk score and expected value estimation.
"""

from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache

from app.external.platform_api import get_delivery_activity
from app.external.weather_api import get_weather
from app.models.worker import Worker
from app.schemas.policy import PolicyRecommendation


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


@dataclass(frozen=True)
class PlanConfig:
    premium_rate: float
    max_payout_ratio: float
    trigger_sensitivity: float
    avg_payout_ratio: float


PLAN_CONFIGS: dict[str, PlanConfig] = {
    "Basic": PlanConfig(
        premium_rate=0.018,
        max_payout_ratio=0.55,
        trigger_sensitivity=0.68,
        avg_payout_ratio=0.72,
    ),
    "Standard": PlanConfig(
        premium_rate=0.026,
        max_payout_ratio=0.82,
        trigger_sensitivity=0.95,
        avg_payout_ratio=0.62,
    ),
    "High": PlanConfig(
        premium_rate=0.034,
        max_payout_ratio=1.10,
        trigger_sensitivity=1.22,
        avg_payout_ratio=0.50,
    ),
}


@lru_cache(maxsize=128)
def _get_city_disruption_frequency(city: str) -> float:
    """Return normalized local disruption frequency for a city (0-1)."""
    disruption_map = {
        "mumbai": 0.78,
        "chennai": 0.72,
        "delhi": 0.70,
        "kolkata": 0.68,
        "pune": 0.52,
        "hyderabad": 0.50,
        "bangalore": 0.46,
        "ahmedabad": 0.44,
    }
    return disruption_map.get(city.lower(), 0.40)


def _income_affordability_multiplier(avg_weekly_income_inr: float) -> float:
    if avg_weekly_income_inr < 6000:
        return 0.92
    if avg_weekly_income_inr <= 10000:
        return 1.0
    return 1.08


def _explanation(plan_type: str, risk_score: float) -> str:
    if plan_type == "Basic":
        return "Keeps your weekly cost low while still helping on tough disruption days."
    if plan_type == "Standard":
        return "Balances affordable payments with stronger support when work gets disrupted."
    if risk_score >= 0.6:
        return "Best if your work gets affected often, with frequent payouts even on mild issues."
    return "Gives frequent payouts even for small disruptions so your income stays steady."


async def _get_activity_adjustment(worker: Worker) -> float:
    """Return optional risk adjustment from recent earnings volatility (0-0.08)."""
    try:
        activity = await get_delivery_activity(worker.phone)
    except NotImplementedError:
        return 0.0

    reported_income = max(worker.avg_weekly_income_inr, 1.0)
    observed_income = max(activity.earnings_last_7_days_inr, 1.0)
    volatility = abs(observed_income - reported_income) / reported_income
    dependency = _clamp(activity.peak_hour_dependency_score, 0.0, 1.0)
    return _clamp((volatility * 0.6) + (dependency * 0.4), 0.0, 0.08)


async def generate_policy_recommendations(worker: Worker) -> list[PolicyRecommendation]:
    """Return exactly three recommendations: Basic, Standard, and High."""
    weather = await get_weather(worker.city)
    disruption_risk = _get_city_disruption_frequency(worker.city)
    activity_adjustment = await _get_activity_adjustment(worker)

    rain_risk = _clamp(weather.rainfall_mm / 80.0, 0.0, 1.0)
    aqi_risk = _clamp((weather.aqi - 80.0) / 280.0, 0.0, 1.0)
    heat_risk = _clamp((weather.temperature_c - 30.0) / 14.0, 0.0, 1.0)

    # Normalized risk score in range 0-1 based on historical and live risk signals.
    risk_score = _clamp(
        (rain_risk * 0.33)
        + (aqi_risk * 0.27)
        + (heat_risk * 0.16)
        + (disruption_risk * 0.24)
        + activity_adjustment,
        0.0,
        1.0,
    )

    affordability_multiplier = _income_affordability_multiplier(
        worker.avg_weekly_income_inr
    )

    plan_scores: dict[str, float] = {}
    recommendations: list[PolicyRecommendation] = []

    for plan_type in ("Basic", "Standard", "High"):
        config = PLAN_CONFIGS[plan_type]
        premium = round(
            worker.avg_weekly_income_inr
            * config.premium_rate
            * affordability_multiplier,
            2,
        )
        max_payout = round(
            worker.avg_weekly_income_inr * config.max_payout_ratio,
            2,
        )

        probability_of_trigger = _clamp(
            (risk_score * config.trigger_sensitivity) + (disruption_risk * 0.10),
            0.05,
            0.95,
        )
        avg_payout = max_payout * config.avg_payout_ratio
        expected_payout = round(probability_of_trigger * avg_payout, 2)
        value_score = round(expected_payout / premium, 4)

        suitability_bonus = 0.0
        if risk_score < 0.35:
            suitability_bonus = {"Basic": 0.30, "Standard": 0.18, "High": 0.04}[plan_type]
        elif risk_score < 0.65:
            suitability_bonus = {"Basic": 0.12, "Standard": 0.26, "High": 0.20}[plan_type]
        else:
            suitability_bonus = {"Basic": 0.05, "Standard": 0.18, "High": 0.34}[plan_type]

        plan_scores[plan_type] = value_score + suitability_bonus
        recommendations.append(
            PolicyRecommendation(
                plan_type=plan_type,
                premium=premium,
                max_payout=max_payout,
                why_recommended=_explanation(plan_type=plan_type, risk_score=risk_score),
                expected_payout=expected_payout,
                value_score=value_score,
            )
        )

    # Keep the response order fixed while still using ranked scoring internally.
    _ = max(plan_scores, key=plan_scores.get)
    return recommendations
