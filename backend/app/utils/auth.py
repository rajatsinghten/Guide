"""JWT token creation and verification.

Provides helper functions used by the auth dependency (`deps.py`) and the
onboarding router for login/registration flows.
"""

import hashlib
import hmac
from datetime import datetime, timedelta, timezone

from jose import JWTError, jwt

from app.config import settings


def hash_otp(otp: str) -> str:
    """Hash an OTP string for secure storage.

    Uses SHA-256 with the app secret key as salt.  This is a Phase 1 stub —
    in production, OTP verification would happen via SMS gateway (Twilio/MSG91).
    """
    return hashlib.sha256(
        f"{settings.secret_key}:{otp}".encode()
    ).hexdigest()


def verify_otp(plain_otp: str, hashed_otp: str) -> bool:
    """Verify a plain OTP against its stored hash."""
    expected = hash_otp(plain_otp)
    return hmac.compare_digest(expected, hashed_otp)


def create_access_token(
    data: dict,
    expires_delta: timedelta | None = None,
) -> str:
    """Create a signed JWT access token.

    Args:
        data: Claims to embed (must include ``sub`` with the worker ID).
        expires_delta: Optional custom expiry. Defaults to config value.

    Returns:
        Encoded JWT string.
    """
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (
        expires_delta
        if expires_delta
        else timedelta(minutes=settings.access_token_expire_minutes)
    )
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.secret_key, algorithm=settings.algorithm)


def decode_access_token(token: str) -> dict | None:
    """Decode and verify a JWT access token.

    Returns:
        The token payload dict, or ``None`` if verification fails.
    """
    try:
        payload = jwt.decode(
            token, settings.secret_key, algorithms=[settings.algorithm]
        )
        return payload
    except JWTError:
        return None
