from __future__ import annotations

from typing import Any

DRIVER_PACKAGES = {
    "com.zomato.delivery",
    "in.swiggy.deliveryapp",
    "com.ubercab.driver",
    "com.ola.driver",
}


def validate_session(
    metadata: dict[str, Any],
) -> tuple[str, int, int, list[str]]:
    """
    Core validation logic.

    Returns:
        (status, fraud_score, spoofing_score, reasons)
        status: "verified" | "failed"
        fraud_score: 0–100
        spoofing_score: 0–100
    """
    reasons: list[str] = []
    fraud_score: int = 0

    # ── 1. Recording duration ─────────────────────────────────────────────────
    duration: int = metadata.get("duration_seconds", 0)
    if duration < 10:
        reasons.append(f"Recording too short: {duration}s (min 10s)")
        fraud_score += 25
    elif duration < 20:
        reasons.append(f"Recording short: {duration}s (recommended ≥20s)")
        fraud_score += 10

    # ── 2. Driver app usage ───────────────────────────────────────────────────
    driver_opened: bool = metadata.get("driver_app_opened", False)
    if not driver_opened:
        reasons.append("No driver app foreground event detected")
        fraud_score += 30
    else:
        # Verify via app_usage_log
        usage_log: list[dict] = metadata.get("app_usage_log", [])
        driver_events = [
            e for e in usage_log
            if e.get("package_name") in DRIVER_PACKAGES
            and e.get("event_type") == "foreground"
        ]
        if not driver_events:
            reasons.append("driver_app_opened flag set but no log entries found")
            fraud_score += 15

    # ── 3. Spoofing score ─────────────────────────────────────────────────────
    spoofing_data: dict = metadata.get("spoofing", {})
    spoofing_score: int = int(spoofing_data.get("spoofing_score", 0))
    spoofing_flags: list[str] = spoofing_data.get("flags", [])

    if spoofing_score >= 60:
        reasons.append(f"High location spoofing score: {spoofing_score}")
        fraud_score += 35
    elif spoofing_score >= 30:
        reasons.append(f"Moderate location spoofing indicators ({spoofing_score})")
        fraud_score += 15

    for flag in spoofing_flags:
        if "mock_provider" in flag:
            reasons.append(f"Mock provider flag: {flag}")
        elif "developer_options" in flag:
            reasons.append("Developer options enabled")

    # ── 4. Location sample count ──────────────────────────────────────────────
    location_samples: list = metadata.get("location_samples", [])
    if len(location_samples) == 0:
        reasons.append("No location samples collected")
        fraud_score += 10
    elif len(location_samples) < 3:
        reasons.append(f"Very few location samples: {len(location_samples)}")
        fraud_score += 5

    # ── 5. Session consistency ────────────────────────────────────────────────
    # (In prod: compare nonce in video frame with session nonce via OCR)
    # Prototype: just verify session_id present
    if not metadata.get("session_id"):
        reasons.append("Missing session ID in metadata")
        fraud_score += 10

    # ── 6. Clamp and decide ───────────────────────────────────────────────────
    fraud_score = min(fraud_score, 100)
    status = "verified" if fraud_score < 40 else "failed"

    return status, fraud_score, spoofing_score, reasons
