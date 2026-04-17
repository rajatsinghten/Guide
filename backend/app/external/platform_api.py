"""Mock Zomato / Swiggy delivery platform data API.

Simulates fetching delivery partner activity data (earnings, trips, zones)
from the gig platform.  Always runs in mock mode for Phase 1 — the interface
is designed so a real integration can be swapped in later.
"""

from dataclasses import dataclass

from app.config import settings


@dataclass
class DeliveryActivity:
    """Summary of a worker's recent delivery activity on their platform."""

    worker_phone: str
    platform: str
    trips_last_7_days: int
    earnings_last_7_days_inr: float
    peak_hour_dependency_score: float  # 0.0 – 1.0 (higher = more peak-dependent)
    primary_zone: str
    active: bool


# ── Mock data ───────────────────────────────────────────────────────────────

_MOCK_ACTIVITY: dict[str, DeliveryActivity] = {
    "+919876543210": DeliveryActivity(
        worker_phone="+919876543210",
        platform="zomato",
        trips_last_7_days=85,
        earnings_last_7_days_inr=7800.0,
        peak_hour_dependency_score=0.72,
        primary_zone="Andheri West",
        active=True,
    ),
    "+919876543211": DeliveryActivity(
        worker_phone="+919876543211",
        platform="swiggy",
        trips_last_7_days=60,
        earnings_last_7_days_inr=5500.0,
        peak_hour_dependency_score=0.45,
        primary_zone="Koramangala",
        active=True,
    ),
}

_DEFAULT_MOCK = DeliveryActivity(
    worker_phone="unknown",
    platform="zomato",
    trips_last_7_days=50,
    earnings_last_7_days_inr=5000.0,
    peak_hour_dependency_score=0.50,
    primary_zone="Central Zone",
    active=True,
)


async def get_delivery_activity(phone: str) -> DeliveryActivity:
    """Fetch recent delivery activity for a worker.

    In mock mode (Phase 1 default), returns deterministic fake data.
    In live mode, would call the Zomato/Swiggy partner API.

    Args:
        phone: Worker's registered phone number.

    Returns:
        A ``DeliveryActivity`` summary.
    """
    if settings.use_mock_apis:
        return _MOCK_ACTIVITY.get(phone, _DEFAULT_MOCK)

    # Live implementation placeholder — swap in real API calls here
    raise NotImplementedError(
        "Live Zomato/Swiggy API integration is not available in Phase 1."
    )


async def get_curfew_strike_status(city: str) -> bool:
    """Check if a curfew or strike is active in *city*.

    In mock mode, returns ``True`` for Delhi (simulating a strike scenario)
    and ``False`` for all other cities.

    Args:
        city: City name (case-insensitive).

    Returns:
        ``True`` if a curfew / strike is in effect.
    """
    if settings.use_mock_apis:
        return city.lower() == "delhi"

    raise NotImplementedError(
        "Live curfew/strike API integration is not available in Phase 1."
    )
