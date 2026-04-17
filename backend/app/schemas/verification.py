"""Verification Pydantic schemas — session models for the fraud-detection API."""
from __future__ import annotations

from datetime import datetime
from typing import Any, Optional
from pydantic import BaseModel, Field


class StartRequest(BaseModel):
    session_id: str
    nonce: str
    timestamp: str
    device_platform: str = "android"


class ValidateRequest(BaseModel):
    session_id: str


class SessionRecord(BaseModel):
    session_id: str
    nonce: str
    started_at: datetime
    device_platform: str
    upload_received: bool = False
    metadata: Optional[dict[str, Any]] = None
    video_path: Optional[str] = None


class StartResponse(BaseModel):
    session_id: str
    server_timestamp: str
    status: str = "started"


class UploadResponse(BaseModel):
    session_id: str
    status: str = "uploaded"
    message: str


class ValidationResponse(BaseModel):
    status: str
    fraud_score: int = Field(ge=0, le=100)
    spoofing_score: int = Field(ge=0, le=100)
    reasons: list[str]
    session_id: str
