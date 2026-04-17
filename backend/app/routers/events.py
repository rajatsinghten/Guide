"""Events router — parametric trigger ingestion.

Provides the admin/scheduler endpoint that ingests disruption events and
auto-creates claims for eligible workers.  This is the entry point for the
parametric insurance trigger pipeline.
"""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.schemas.claim import (
    EventTrigger,
    EventTriggerResponse,
    MockEventSimulationRequest,
    MockEventSimulationResponse,
)
from app.services.event_engine import process_event
from app.services.mock_event_simulator import run_mock_event_simulation
from app.utils.deps import get_db

router = APIRouter(prefix="/api/v1/events", tags=["Events"])


@router.post(
    "/trigger",
    response_model=EventTriggerResponse,
    summary="Trigger a disruption event (admin / scheduler)",
)
async def trigger_event(
    payload: EventTrigger,
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Ingest a disruption event and auto-create claims for eligible workers.

    This endpoint is called by the admin panel or the scheduled weather
    checker.  It evaluates the event against parametric thresholds and
    creates income-loss claims for every worker in the affected city who
    holds an active policy.

    Phase 1 triggers:
    - ``rainfall``: > 50 mm in 24 h
    - ``aqi``: AQI > 300
    - ``curfew_strike``: Boolean flag
    """
    claim_ids = await process_event(
        db=db,
        event_type=payload.event_type,
        city=payload.city,
        severity=payload.severity,
        timestamp=payload.timestamp,
    )

    return {
        "event_type": payload.event_type,
        "city": payload.city,
        "severity": payload.severity,
        "claims_created": len(claim_ids),
        "claim_ids": claim_ids,
    }


@router.post(
    "/simulate/mock",
    response_model=MockEventSimulationResponse,
    summary="Run random mock events and auto-trigger claims",
)
async def simulate_mock_events(
    payload: MockEventSimulationRequest,
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Run randomized mock event data through the auto-claim pipeline.

    This endpoint is for local/demo environments where real external APIs
    (weather/AQI/municipal alerts) are not connected yet.
    """
    return await run_mock_event_simulation(
        db=db,
        max_events=payload.max_events,
        seed=payload.seed,
    )
