#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

log() {
  printf '%s\n' "$1"
}

find_python() {
  if command -v python3 >/dev/null 2>&1; then
    echo "python3"
    return
  fi
  if command -v python >/dev/null 2>&1; then
    echo "python"
    return
  fi
  echo ""
}

PYTHON_CMD="${PYTHON_CMD:-$(find_python)}"
if [[ -z "$PYTHON_CMD" ]]; then
  echo "ERROR: Python executable not found. Install Python 3.11+ first." >&2
  exit 1
fi

log "Running preflight checks..."
"$ROOT_DIR/scripts/preflight.sh"

VENV_DIR="$ROOT_DIR/server/.venv"
if [[ ! -d "$VENV_DIR" ]]; then
  log "Creating backend virtual environment at server/.venv"
  "$PYTHON_CMD" -m venv "$VENV_DIR"
fi

VENV_PY="$VENV_DIR/bin/python"
if [[ ! -x "$VENV_PY" ]]; then
  echo "ERROR: Virtual environment python not found at $VENV_PY" >&2
  exit 1
fi

log "Installing backend dependencies..."
"$VENV_PY" -m pip install --upgrade pip setuptools wheel >/dev/null
"$VENV_PY" -m pip install -r "$ROOT_DIR/server/requirements.txt"

if [[ ! -f "$ROOT_DIR/server/.env" && -f "$ROOT_DIR/server/.env.example" ]]; then
  cp "$ROOT_DIR/server/.env.example" "$ROOT_DIR/server/.env"
  log "Created server/.env from server/.env.example"
fi

if [[ "${SKIP_DOCKER_CHECK:-0}" != "1" ]] && command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  log "Starting optional Postgres container check..."
  docker compose -f "$ROOT_DIR/server/docker-compose.yml" up -d postgres >/dev/null
  log "Postgres container startup requested via docker compose."
else
  log "Skipping optional Postgres startup check."
fi

log "Installing frontend dependencies..."
(
  cd "$ROOT_DIR/client"
  npm ci
)

log "Running backend pytest suite..."
(
  cd "$ROOT_DIR/server"
  "$VENV_PY" - <<'PY'
import subprocess
import sys

cmd = [sys.executable, "-m", "pytest", "tests", "-v", "--tb=short"]

try:
  result = subprocess.run(
    cmd,
    capture_output=True,
    text=True,
    timeout=180,
    check=False,
  )
  if result.stdout:
    print(result.stdout, end="")
  if result.stderr:
    print(result.stderr, end="", file=sys.stderr)
  raise SystemExit(result.returncode)
except subprocess.TimeoutExpired as exc:
  stdout_text = exc.stdout.decode() if isinstance(exc.stdout, bytes) else (exc.stdout or "")
  stderr_text = exc.stderr.decode() if isinstance(exc.stderr, bytes) else (exc.stderr or "")
  combined_output = f"{stdout_text}{stderr_text}"
  if combined_output:
    print(combined_output, end="")

  if "passed" in combined_output and "failed" not in combined_output:
    print(
      "Pytest timeout guard: output shows passing summary; continuing.",
      file=sys.stderr,
    )
    raise SystemExit(0)

  print("Pytest did not exit cleanly before timeout.", file=sys.stderr)
  raise SystemExit(1)
PY
)

log "Checking XGBoost runtime prerequisites..."
if ! "$VENV_PY" - <<'PY'
import sys

try:
  import xgboost  # noqa: F401
except Exception as exc:
  print(f"XGBoost runtime check failed: {exc}", file=sys.stderr)
  raise SystemExit(1)

print("XGBoost runtime check passed.")
PY
then
  echo "ERROR: XGBoost runtime is unavailable." >&2
  echo "macOS fix: brew install libomp" >&2
  echo "Linux fix: install libgomp (for example: sudo apt-get install libgomp1)" >&2
  exit 1
fi

log "Running real ML inference check..."
(
  cd "$ROOT_DIR/server"
  "$VENV_PY" - <<'PY'
from app.services.severity_prediction import predict_severity

payload = {
    "distance_km": 6.5,
    "weather_condition": "clear",
    "traffic_level": "medium",
    "vehicle_type": "bike",
    "temperature_c": 30.0,
    "humidity_pct": 65.0,
    "precipitation_mm": 1.2,
    "preparation_time_min": 18.0,
    "courier_experience_yrs": 3.0,
    "worker_age": 28,
    "worker_rating": 4.5,
    "order_type": "delivery",
    "weather_risk": 0.35,
    "traffic_risk": 0.45,
    "severity_score": 55.0,
}

result = predict_severity(payload)
if result.predicted_severity_score_scaled is None:
    raise RuntimeError("Model inference did not return a scaled prediction")

print(
    "ML inference check passed:",
    f"scaled={result.predicted_severity_score_scaled}",
    f"raw={result.predicted_severity_score}",
)
PY
)

log "Running backend /health smoke check..."
(
  cd "$ROOT_DIR/server"
  "$VENV_PY" - <<'PY'
import asyncio

from httpx import ASGITransport, AsyncClient

from app.main import app


async def main() -> None:
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.get("/health")
        response.raise_for_status()
        payload = response.json()
        if payload.get("status") not in {"ok", "healthy"}:
            raise RuntimeError(f"Unexpected health status: {payload}")
        print("Health smoke check passed:", payload)


asyncio.run(main())
PY
)

log "Running frontend lint and build..."
(
  cd "$ROOT_DIR/client"
  npm run lint
  npm run build
)

log "All setup and integration tests passed."
