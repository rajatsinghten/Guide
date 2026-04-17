"""Pricing router — exposes the premium calculation endpoint.

Allows workers (or the frontend) to preview their premium before committing
to a policy.  Delegates entirely to the pricing engine service.
"""

from fastapi import APIRouter, Depends, HTTPException

from app.models.worker import Worker
from app.schemas.policy import (
    PremiumBreakdownResponse,
    SeverityPredictionRequest,
    SeverityPredictionResponse,
)
from app.services.pricing_engine import calculate_premium
from app.services.severity_prediction import predict_severity as predict_severity_from_model
from app.utils.deps import get_current_worker

router = APIRouter(prefix="/api/v1/pricing", tags=["Pricing"])


@router.post(
    "/calculate",
    response_model=PremiumBreakdownResponse,
    summary="Calculate weekly premium for current worker",
)
async def calculate_worker_premium(
    current_worker: Worker = Depends(get_current_worker),
) -> dict:
    """Calculate the weekly insurance premium for the authenticated worker.

    Uses the worker's profile (income, city, pincode) to run the three-factor
    pricing formula and returns a full breakdown of all components.
    """
    breakdown = calculate_premium(
        avg_weekly_income_inr=current_worker.avg_weekly_income_inr,
        city=current_worker.city,
        pincode=current_worker.pincode,
    )
    return {
        "weekly_premium_inr": breakdown.weekly_premium_inr,
        "coverage_amount_inr": breakdown.coverage_amount_inr,
        "risk_score": breakdown.risk_score,
        "risk_factors": [rf.name for rf in breakdown.risk_factors],
        "base_premium": breakdown.base_premium,
        "zone_risk_multiplier": breakdown.zone_risk_multiplier,
        "weather_risk_factor": breakdown.weather_risk_factor,
    }


@router.post(
    "/predict-severity",
    response_model=SeverityPredictionResponse,
    summary="Predict disruption severity from frontend datapoints",
)
async def predict_worker_severity(
    payload: SeverityPredictionRequest,
    current_worker: Worker = Depends(get_current_worker),
) -> dict:
    """Run ML severity prediction using the 15 frontend-provided datapoints."""
    _ = current_worker  # Ensures endpoint remains authenticated.

    try:
        prediction = predict_severity_from_model(payload.model_dump())
    except FileNotFoundError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail="Unable to run severity prediction",
        ) from exc

    return {
        "predicted_severity_score_scaled": prediction.predicted_severity_score_scaled,
        "predicted_severity_score": prediction.predicted_severity_score,
    }
