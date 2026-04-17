"""GigShield — Consolidated FastAPI backend.

Combines the insurance platform (workers, policies, pricing, claims,
payouts, events, dashboard) with the verification API (screen recording
fraud detection).
"""

from __future__ import annotations

import json
import os
import logging
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import Any

import aiofiles
import time
from fastapi import FastAPI, File, Form, HTTPException, UploadFile, Request
from fastapi.middleware.cors import CORSMiddleware

from app.database import init_database
from app.routers import claims, dashboard, events, onboarding, payouts, policy, pricing
from app.services.scheduler import start_scheduler, stop_scheduler
from app.schemas.verification import (
    SessionRecord,
    StartRequest,
    StartResponse,
    UploadResponse,
    ValidateRequest,
    ValidationResponse,
)
from app.validator import validate_session

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(name)-25s | %(levelname)-8s | %(message)s",
)
logger = logging.getLogger("gigshield")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan — init DB, start scheduler on boot."""
    from app.config import settings
    logger.info(f"🚀 GigShield starting up (DB: {settings.database_url})…")
    await init_database()
    start_scheduler()
    yield
    stop_scheduler()
    logger.info("🛑 GigShield shutting down…")


app = FastAPI(
    title="GigShield",
    description=(
        "AI-Powered Parametric Income-Loss Insurance for India's Gig Economy "
        "Delivery Workers — with fraud-detection verification."
    ),
    version="0.2.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── REQUEST LOGGING MIDDLEWARE ───────────────────────────────────────────────
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time
    logger.info(
        f"INBOUND | {request.client.host} | {request.method} {request.url.path} | "
        f"STATUS: {response.status_code} | {duration:.3f}s"
    )
    return response

# ── Insurance routers ────────────────────────────────────────────────────────
app.include_router(onboarding.router)
app.include_router(policy.router)
app.include_router(pricing.router)
app.include_router(claims.router)
app.include_router(payouts.router)
app.include_router(events.router)
app.include_router(dashboard.router)

# ── In-memory session store (replace with DB in production) ─────────────────
_sessions: dict[str, SessionRecord] = {}
UPLOAD_DIR = os.path.join(os.path.dirname(__file__), "..", "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)


# ── Health ───────────────────────────────────────────────────────────────────

@app.get("/", tags=["Health"])
async def root() -> dict:
    return {"service": "GigShield", "status": "operational", "version": "0.2.0"}


@app.get("/health", tags=["Health"])
async def health_check() -> dict:
    return {"status": "healthy", "database": "connected", "scheduler": "running"}


# ── Verification endpoints ────────────────────────────────────────────────────

@app.post("/api/v1/verification/start", response_model=StartResponse, status_code=201, tags=["Verification"])
async def start_verification(body: StartRequest) -> StartResponse:
    """Creates a new verification session server-side."""
    if body.session_id in _sessions:
        raise HTTPException(status_code=409, detail="Session already exists")
    _sessions[body.session_id] = SessionRecord(
        session_id=body.session_id,
        nonce=body.nonce,
        started_at=datetime.now(timezone.utc),
        device_platform=body.device_platform,
    )
    return StartResponse(
        session_id=body.session_id,
        server_timestamp=datetime.now(timezone.utc).isoformat(),
    )


@app.post("/api/v1/verification/upload", response_model=UploadResponse, tags=["Verification"])
async def upload_verification(
    session_id: str = Form(...),
    metadata: str = Form(...),
    video: UploadFile | None = File(None),
) -> UploadResponse:
    if session_id not in _sessions:
        raise HTTPException(status_code=404, detail="Session not found")
    session = _sessions[session_id]
    try:
        meta: dict[str, Any] = json.loads(metadata)
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid metadata JSON")
    session.metadata = meta
    if video is not None:
        video_path = os.path.join(UPLOAD_DIR, f"{session_id}.mp4")
        async with aiofiles.open(video_path, "wb") as f:
            await f.write(await video.read())
        session.video_path = video_path
    session.upload_received = True
    return UploadResponse(
        session_id=session_id,
        message=f"Upload received. Video: {'yes' if video else 'no'}",
    )


@app.post("/api/v1/verification/validate", response_model=ValidationResponse, tags=["Verification"])
async def validate_verification(body: ValidateRequest) -> ValidationResponse:
    if body.session_id not in _sessions:
        raise HTTPException(status_code=404, detail="Session not found")
    session = _sessions[body.session_id]
    if not session.upload_received or session.metadata is None:
        raise HTTPException(status_code=422, detail="Upload not received yet.")
    status, fraud_score, spoofing_score, reasons = validate_session(session.metadata)
    return ValidationResponse(
        status=status, fraud_score=fraud_score, spoofing_score=spoofing_score,
        reasons=reasons, session_id=body.session_id,
    )
