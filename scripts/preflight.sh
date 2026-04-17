#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

log() {
  printf '%s\n' "$1"
}

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
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
[[ -n "$PYTHON_CMD" ]] || fail "Python executable not found. Install Python 3.11+ first."

command -v node >/dev/null 2>&1 || fail "Node.js not found. Install Node 20+ first."
command -v npm >/dev/null 2>&1 || fail "npm not found. Install npm first."

"$PYTHON_CMD" -c "import sys; assert sys.version_info >= (3, 11), 'Python 3.11+ is required'; print(f'Python {sys.version.split()[0]}')"
log "Node $(node -v)"
log "npm $(npm -v)"

[[ -f "$ROOT_DIR/server/requirements.txt" ]] || fail "Missing server/requirements.txt"
[[ -f "$ROOT_DIR/client/package.json" ]] || fail "Missing client/package.json"
[[ -f "$ROOT_DIR/notebooks/xg_bost.pkl" ]] || fail "Missing notebooks/xg_bost.pkl model artifact"
[[ -f "$ROOT_DIR/data/processed/gigshield_training_ready.csv" ]] || fail "Missing data/processed/gigshield_training_ready.csv reference dataset"

if [[ "${SKIP_DOCKER_CHECK:-0}" == "1" ]]; then
  log "Docker preflight skipped (SKIP_DOCKER_CHECK=1)."
else
  if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
      if docker compose version >/dev/null 2>&1; then
        log "Docker daemon and docker compose are available."
      else
        fail "docker compose is not available. Install Docker Compose plugin."
      fi
    else
      log "WARN: Docker is installed but daemon is not running. Optional DB check will be skipped."
    fi
  else
    log "WARN: Docker is not installed. Optional DB check will be skipped."
  fi
fi

log "Preflight checks passed."
