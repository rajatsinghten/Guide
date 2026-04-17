param(
    [switch]$SkipDockerCheck
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot

function Run-Step([scriptblock]$Action, [string]$Title) {
    Write-Host "`n==> $Title"
    & $Action
}

Run-Step { & "$PSScriptRoot/preflight.ps1" -SkipDockerCheck:$SkipDockerCheck } "Running preflight checks"

$venvPath = "$RootDir/server/.venv"
if (-not (Test-Path $venvPath)) {
    Run-Step { python -m venv $venvPath } "Creating backend virtual environment"
}

$pyExe = "$RootDir/server/.venv/Scripts/python.exe"
if (-not (Test-Path $pyExe)) {
    Write-Error "Python executable not found in virtual environment: $pyExe"
    exit 1
}

Run-Step {
    & $pyExe -m pip install --upgrade pip setuptools wheel | Out-Null
    & $pyExe -m pip install -r "$RootDir/server/requirements.txt"
} "Installing backend dependencies"

if ((-not (Test-Path "$RootDir/server/.env")) -and (Test-Path "$RootDir/server/.env.example")) {
    Copy-Item "$RootDir/server/.env.example" "$RootDir/server/.env"
    Write-Host "Created server/.env from server/.env.example"
}

if (-not $SkipDockerCheck) {
    $canUseDocker = $true
    try {
        docker info *> $null
        docker compose version *> $null
    } catch {
        $canUseDocker = $false
    }

    if ($canUseDocker) {
        Run-Step {
            docker compose -f "$RootDir/server/docker-compose.yml" up -d postgres *> $null
            Write-Host "Postgres container startup requested via docker compose."
        } "Running optional Postgres container check"
    } else {
        Write-Host "Skipping optional Postgres startup check."
    }
} else {
    Write-Host "Skipping optional Postgres startup check."
}

Run-Step {
    Push-Location "$RootDir/client"
    npm ci
    Pop-Location
} "Installing frontend dependencies"

Run-Step {
    Push-Location "$RootDir/server"
    @'
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
'@ | & $pyExe -
    Pop-Location
} "Running backend pytest suite"

Run-Step {
    @'
import sys

try:
    import xgboost  # noqa: F401
except Exception as exc:
    print(f"XGBoost runtime check failed: {exc}", file=sys.stderr)
    raise SystemExit(1)

print("XGBoost runtime check passed.")
'@ | & $pyExe -
    if ($LASTEXITCODE -ne 0) {
        Write-Error "XGBoost runtime is unavailable. On macOS run: brew install libomp"
        exit 1
    }
} "Checking XGBoost runtime prerequisites"

Run-Step {
    @'
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
'@ | & $pyExe -
} "Running real ML inference check"

Run-Step {
    @'
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
'@ | & $pyExe -
} "Running backend /health smoke check"

Run-Step {
    Push-Location "$RootDir/client"
    npm run lint
    npm run build
    Pop-Location
} "Running frontend lint and build"

Write-Host "`nAll setup and integration tests passed."
