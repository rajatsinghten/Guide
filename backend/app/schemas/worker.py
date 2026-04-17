"""Pydantic schemas for worker registration, login, and profile responses."""

import uuid
from datetime import datetime

from pydantic import BaseModel, Field, field_validator


# ── Requests ────────────────────────────────────────────────────────────────


class WorkerRegister(BaseModel):
    """Payload for POST /workers/register."""

    name: str = Field(..., min_length=2, max_length=120, examples=["Rajesh Kumar"])
    phone: str = Field(..., min_length=10, max_length=15, examples=["9876543210"])
    city: str = Field(..., min_length=2, max_length=60, examples=["Mumbai"])
    pincode: str = Field(..., pattern=r"^\d{6}$", examples=["400001"])
    platform: str = Field(
        ...,
        pattern=r"^(swiggy|zomato|dunzo|ola|uber|rapido)$",
        examples=["zomato"],
    )
    avg_weekly_income_inr: float = Field(..., gt=0, examples=[8000.0])
    vehicle_type: str = Field(
        ..., pattern=r"^(bike|scooter|cycle)$", examples=["bike"]
    )

    @field_validator("name", "phone", "city", "pincode", mode="before")
    @classmethod
    def strip_text_fields(cls, value: str) -> str:
        return value.strip() if isinstance(value, str) else value


class WorkerLogin(BaseModel):
    """Payload for POST /workers/login — OTP-based stub."""

    phone: str = Field(..., min_length=10, max_length=15, examples=["9876543210"])
    otp: str = Field(..., min_length=4, max_length=6, examples=["1234"])


# ── Responses ───────────────────────────────────────────────────────────────


class WorkerResponse(BaseModel):
    """Public worker profile returned by the API."""

    id: uuid.UUID
    name: str
    phone: str
    city: str
    pincode: str
    platform: str
    avg_weekly_income_inr: float
    vehicle_type: str
    created_at: datetime

    model_config = {"from_attributes": True}


class TokenResponse(BaseModel):
    """JWT access token returned on successful login."""

    access_token: str
    token_type: str = "bearer"
