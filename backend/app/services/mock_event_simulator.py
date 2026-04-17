"""Mock disruption event simulator for local and demo environments.

When real weather/AQI/municipal APIs are unavailable, this module can generate
mock events, randomize their order, and feed them through the same event engine
used in production. This helps verify threshold logic and auto-claim creation.
"""

import random
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.claim import Claim
from app.models.policy import Policy
from app.models.worker import Worker
from app.services.event_engine import process_event
from app.utils.constants import AQI_THRESHOLD, RAINFALL_THRESHOLD_MM

DEFAULT_CITY_POOL = ["Mumbai", "Delhi", "Bangalore", "Chennai"]
_WORKER_RISK_CURSOR: dict[str, int] = {}


@dataclass(frozen=True)
class RiskSignalInput:
    """Human-readable risk signal shown on the dashboard ticker."""

    weather_condition: str
    traffic_level: str
    precipitation_mm: float


@dataclass(frozen=True)
class MockEventInput:
    """Derived event payload generated from a risk signal."""

    event_type: str
    city: str
    severity: str
    weather_condition: str
    traffic_level: str
    precipitation_mm: float
    threshold_crossed: bool
    aqi_value: int | None = None
    curfew_strike: bool | None = None


def _city_at(cities: list[str], index: int) -> str:
    return cities[index % len(cities)]


def _build_risk_signal_pool() -> list[RiskSignalInput]:
    """Create an ordered list of weather/traffic/precipitation signals.

    The list intentionally starts with safe conditions and later includes
    threshold-crossing samples so claim auto-triggering can be observed.
    """
    return [
        RiskSignalInput(weather_condition="Clear", traffic_level="low", precipitation_mm=2.0),
        RiskSignalInput(weather_condition="Cloudy", traffic_level="medium", precipitation_mm=8.0),
        RiskSignalInput(weather_condition="Drizzle", traffic_level="medium", precipitation_mm=16.0),
        RiskSignalInput(weather_condition="Rainy", traffic_level="high", precipitation_mm=31.0),
        RiskSignalInput(weather_condition="Stormy", traffic_level="severe", precipitation_mm=58.0),
        RiskSignalInput(weather_condition="Smog", traffic_level="high", precipitation_mm=6.0),
        RiskSignalInput(weather_condition="Clear", traffic_level="strike", precipitation_mm=0.0),
        RiskSignalInput(weather_condition="Haze", traffic_level="gridlock", precipitation_mm=12.0),
    ]


def _derive_event_from_signal(signal: RiskSignalInput, city: str) -> MockEventInput:
    """Convert risk ticker values into a disruption event payload."""
    weather = signal.weather_condition.lower()
    traffic = signal.traffic_level.lower()
    precipitation = signal.precipitation_mm

    if precipitation > RAINFALL_THRESHOLD_MM:
        severity = "critical" if precipitation >= RAINFALL_THRESHOLD_MM + 20 else "high"
        return MockEventInput(
            event_type="rainfall",
            city=city,
            severity=severity,
            weather_condition=signal.weather_condition,
            traffic_level=signal.traffic_level,
            precipitation_mm=precipitation,
            threshold_crossed=True,
            curfew_strike=False,
        )

    if weather in {"smog", "haze", "dust", "dusty"}:
        aqi_value = AQI_THRESHOLD + (140 if weather == "smog" else 40)
        severity = "critical" if aqi_value >= AQI_THRESHOLD + 120 else "high"
        return MockEventInput(
            event_type="aqi",
            city=city,
            severity=severity,
            weather_condition=signal.weather_condition,
            traffic_level=signal.traffic_level,
            precipitation_mm=precipitation,
            threshold_crossed=True,
            aqi_value=aqi_value,
            curfew_strike=False,
        )

    if traffic in {"severe", "gridlock", "strike", "shutdown"}:
        return MockEventInput(
            event_type="curfew_strike",
            city=city,
            severity="high",
            weather_condition=signal.weather_condition,
            traffic_level=signal.traffic_level,
            precipitation_mm=precipitation,
            threshold_crossed=True,
            curfew_strike=True,
        )

    return MockEventInput(
        event_type="rainfall",
        city=city,
        severity="low",
        weather_condition=signal.weather_condition,
        traffic_level=signal.traffic_level,
        precipitation_mm=precipitation,
        threshold_crossed=False,
        curfew_strike=False,
    )


def _next_signal_for_policy(cursor_key: str) -> tuple[int, RiskSignalInput]:
    """Return the next signal in the per-policy cyclic ticker."""
    signal_pool = _build_risk_signal_pool()
    current_index = _WORKER_RISK_CURSOR.get(cursor_key, 0) + 1
    signal = signal_pool[(current_index - 1) % len(signal_pool)]
    _WORKER_RISK_CURSOR[cursor_key] = current_index
    return current_index, signal


async def _active_policy_cities(db: AsyncSession) -> list[str]:
    """Return distinct worker cities that currently have active policies."""
    now = datetime.now(timezone.utc)
    stmt = (
        select(Worker.city)
        .join(Policy, Policy.worker_id == Worker.id)
        .where(
            Policy.status == "active",
            Policy.start_date <= now,
            or_(Policy.end_date.is_(None), Policy.end_date > now),
        )
        .distinct()
    )
    result = await db.execute(stmt)

    cleaned: list[str] = []
    seen: set[str] = set()
    for city in result.scalars().all():
        normalized = (city or "").strip()
        key = normalized.lower()
        if not normalized or key in seen:
            continue
        cleaned.append(normalized)
        seen.add(key)

    return cleaned


async def run_mock_event_simulation(
    db: AsyncSession,
    max_events: int,
    seed: int | None,
) -> dict:
    """Run randomized mock events through the production event engine."""
    active_cities = await _active_policy_cities(db)
    city_pool = active_cities if active_cities else DEFAULT_CITY_POOL

    signal_pool = _build_risk_signal_pool()
    base_timestamp = datetime.now(timezone.utc)

    mock_data: list[dict] = []
    for offset, signal in enumerate(signal_pool):
        city = _city_at(city_pool, offset)
        event = _derive_event_from_signal(signal, city)
        mock_data.append(
            {
                "sample_index": offset + 1,
                "event_type": event.event_type,
                "city": event.city,
                "severity": event.severity,
                "timestamp": base_timestamp + timedelta(minutes=offset),
                "threshold_crossed": event.threshold_crossed,
                "weather_condition": event.weather_condition,
                "traffic_level": event.traffic_level,
                "precipitation_mm": event.precipitation_mm,
                "aqi_value": event.aqi_value,
                "curfew_strike": event.curfew_strike,
            }
        )

    rng_seed = seed if seed is not None else int(base_timestamp.timestamp())
    rng = random.Random(rng_seed)

    randomized = mock_data.copy()
    rng.shuffle(randomized)

    selected = randomized[: min(max_events, len(randomized))]
    if selected and not any(item["threshold_crossed"] for item in selected):
        crossed_events = [item for item in mock_data if item["threshold_crossed"]]
        selected[-1] = crossed_events[rng.randrange(len(crossed_events))]

    triggered_sequence: list[dict] = []
    total_claims_created = 0
    first_threshold_cross_index: int | None = None
    first_claim_creation_index: int | None = None

    for index, item in enumerate(selected, start=1):
        claim_ids = await process_event(
            db=db,
            event_type=item["event_type"],
            city=item["city"],
            severity=item["severity"],
            timestamp=item["timestamp"],
        )
        claims_created = len(claim_ids)

        if item["threshold_crossed"] and first_threshold_cross_index is None:
            first_threshold_cross_index = index
        if claims_created > 0 and first_claim_creation_index is None:
            first_claim_creation_index = index

        total_claims_created += claims_created

        triggered_sequence.append(
            {
                "sequence_index": index,
                "sample_index": item["sample_index"],
                "event_type": item["event_type"],
                "city": item["city"],
                "severity": item["severity"],
                "timestamp": item["timestamp"],
                "threshold_crossed": item["threshold_crossed"],
                "weather_condition": item["weather_condition"],
                "traffic_level": item["traffic_level"],
                "precipitation_mm": item["precipitation_mm"],
                "aqi_value": item["aqi_value"],
                "curfew_strike": item["curfew_strike"],
                "claims_created": claims_created,
                "claim_ids": claim_ids,
            }
        )

    note = None
    if not active_cities:
        note = (
            "No active-policy workers found in the database. Threshold crossing "
            "still ran, but claim creation depends on active policies."
        )
    elif total_claims_created == 0:
        note = (
            "Threshold was crossed but no claims were created. Check city-policy "
            "matching or duplicate-claim fraud flags."
        )

    return {
        "parameters_used": [
            "event_type",
            "city",
            "severity",
            "timestamp",
            "weather_condition",
            "traffic_level",
            "precipitation_mm",
        ],
        "threshold_rules": {
            "rainfall": f"precipitation_mm > {RAINFALL_THRESHOLD_MM}",
            "aqi": "weather_condition in ['Smog', 'Haze', 'Dusty']",
            "curfew_strike": "traffic_level in ['severe', 'gridlock', 'strike', 'shutdown']",
        },
        "mock_data": mock_data,
        "triggered_sequence": triggered_sequence,
        "first_threshold_cross_index": first_threshold_cross_index,
        "first_claim_creation_index": first_claim_creation_index,
        "total_claims_created": total_claims_created,
        "note": note,
    }


async def next_worker_risk_snapshot(
    db: AsyncSession,
    worker: Worker,
    active_policy: Policy | None,
) -> dict:
    """Return the next rotating risk signal and trigger claims when needed.

    Rules:
    1. Risk signal simulation always rotates.
    2. If no active policy, claim creation is skipped.
    3. If a claim already exists for the current active policy, additional
       auto-claim creation is skipped, but simulation keeps running.
    """
    worker_city = (worker.city or "").strip()
    city = worker_city if worker_city else "Mumbai"

    policy_cursor = str(active_policy.id) if active_policy is not None else "no-policy"
    cursor_key = f"{worker.id}:{policy_cursor}"

    has_existing_claim = False
    if active_policy is not None:
        existing_claim_result = await db.execute(
            select(Claim.id).where(Claim.policy_id == active_policy.id).limit(1)
        )
        has_existing_claim = existing_claim_result.scalar_one_or_none() is not None

    sample_index, signal = _next_signal_for_policy(cursor_key)
    derived_event = _derive_event_from_signal(signal, city)
    timestamp = datetime.now(timezone.utc)

    claim_ids: list[str] = []
    can_auto_claim = (
        derived_event.threshold_crossed
        and active_policy is not None
        and not has_existing_claim
    )
    if can_auto_claim:
        created_claim_ids = await process_event(
            db=db,
            event_type=derived_event.event_type,
            city=city,
            severity=derived_event.severity,
            timestamp=timestamp,
        )
        claim_ids = [str(claim_id) for claim_id in created_claim_ids]

    note = None
    if derived_event.threshold_crossed:
        if active_policy is None:
            note = (
                "Threshold crossed, but no active plan is selected for auto-claim."
            )
        elif has_existing_claim:
            note = (
                "Threshold crossed. Simulation continues, but this plan already has "
                "a claim so no new auto-claim was created."
            )
        elif not claim_ids:
            note = "Threshold crossed, but no eligible active policy matched for auto-claim."

    return {
        "sample_index": sample_index,
        "weather_condition": signal.weather_condition,
        "traffic_level": signal.traffic_level,
        "precipitation_mm": signal.precipitation_mm,
        "event_type": derived_event.event_type,
        "severity": derived_event.severity,
        "threshold_crossed": derived_event.threshold_crossed,
        "claims_created": len(claim_ids),
        "claim_ids": claim_ids,
        "note": note,
    }
