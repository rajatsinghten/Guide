"""Onboarding router — worker registration, login, and profile.

Handles the first touch-point for delivery workers joining the GigShield
platform.  Registration collects profile data; login uses a phone + OTP
stub that returns a JWT for subsequent authenticated calls.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
import logging

logger = logging.getLogger("gigshield.auth")

from app.models.worker import Worker
from app.schemas.worker import (
    TokenResponse,
    WorkerLogin,
    WorkerRegister,
    WorkerResponse,
)
from app.utils.auth import create_access_token, hash_otp, verify_otp
from app.utils.deps import get_current_worker, get_db

router = APIRouter(prefix="/api/v1/workers", tags=["Onboarding"])


@router.post(
    "/register",
    response_model=WorkerResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new delivery worker",
)
async def register_worker(
    payload: WorkerRegister,
    db: AsyncSession = Depends(get_db),
) -> Worker:
    """Register a gig delivery worker on GigShield.

    Creates a new worker profile with their city, pincode, platform, and
    income data.  A default OTP (``1234``) is set for Phase 1 testing.
    """
    # Check for duplicate phone
    existing = await db.execute(
        select(Worker).where(Worker.phone == payload.phone)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A worker with this phone number already exists",
        )

    worker = Worker(
        name=payload.name,
        phone=payload.phone,
        city=payload.city,
        pincode=payload.pincode,
        platform=payload.platform,
        avg_weekly_income_inr=payload.avg_weekly_income_inr,
        vehicle_type=payload.vehicle_type,
        hashed_otp=hash_otp("1234"),  # Phase 1 default OTP
    )
    db.add(worker)
    await db.flush()
    await db.refresh(worker)
    logger.info(f"REGISTER | Success for phone: {payload.phone} (ID: {worker.id})")
    return worker


@router.post(
    "/login",
    response_model=TokenResponse,
    summary="Login with phone + OTP (returns JWT)",
)
async def login_worker(
    payload: WorkerLogin,
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Authenticate a worker using phone number and OTP.

    Phase 1 stub: any OTP matching the stored hash is accepted.
    The default test OTP is ``1234``.

    Returns a JWT access token on success.
    """
    logger.info(f"LOGIN | Attempt for phone: {payload.phone}")
    result = await db.execute(
        select(Worker).where(Worker.phone == payload.phone)
    )
    worker = result.scalar_one_or_none()

    if worker is None or worker.hashed_otp is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid phone number or OTP",
        )

    if not verify_otp(payload.otp, worker.hashed_otp):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid phone number or OTP",
        )

    access_token = create_access_token(data={"sub": str(worker.id)})
    return {"access_token": access_token, "token_type": "bearer"}


@router.get(
    "/me",
    response_model=WorkerResponse,
    summary="Get authenticated worker's profile",
)
async def get_my_profile(
    current_worker: Worker = Depends(get_current_worker),
) -> Worker:
    """Return the profile of the currently authenticated worker."""
    return current_worker
