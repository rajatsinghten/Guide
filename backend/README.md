# GigShield — AI-Powered Parametric Insurance for Delivery Workers

Parametric income-loss insurance for India's gig economy delivery workers (Zomato and Swiggy partners).

---

## Problem Statement

India's gig economy delivery workers face frequent income disruption from weather, pollution spikes, and city-level operational shutdowns. Traditional insurance models are too slow and too complex for this weekly earning cycle.

GigShield uses a parametric model where objective external signals trigger claims automatically, reducing paperwork and speeding payouts.

---

## Architecture

<img width="1006" height="468" alt="GigShield Architecture" src="https://github.com/user-attachments/assets/f4431bf8-edcd-4d3e-9787-5b510f138852" />

---

## Pricing Model

GigShield uses a transparent three-factor weekly premium calculation:

```text
weekly_premium = base_premium × zone_risk_multiplier × weather_risk_factor
```

| Component | Formula | Range |
|---|---|---|
| Base Premium | `avg_weekly_income × 0.03` (3%) | - |
| Zone Risk Multiplier | City-based historical disruption risk | 1.0 - 1.5 |
| Weather Risk Factor | Season + city combination | 1.0 - 1.3 |
| Coverage Amount | `avg_weekly_income × 0.80` (80% replacement) | - |

### Example: Mumbai Worker Earning INR 8,000/week

| Step | Calculation | Result |
|---|---|---|
| Base Premium | INR 8,000 × 0.03 | INR 240 |
| Zone Risk (Mumbai) | × 1.50 | INR 360 |
| Weather Risk (Monsoon) | × 1.30 | INR 468/week |
| Coverage | INR 8,000 × 0.80 | INR 6,400 |

---

## Parametric Triggers

| Event Type | Threshold | Auto-Action |
|---|---|---|
| Rainfall | > 50 mm in 24 hours in worker city | Auto-create `income_loss` claim for active policies in affected city |
| AQI | > 300 in worker zone | Auto-create `income_loss` claim for active policies in affected city |
| Curfew / Strike | Boolean flag = `true` for city | Auto-create `income_loss` claim for active policies in affected city |

### Severity-Based Payout Ratios

| Severity | Payout (% of coverage) |
|---|---|
| Low | 25% |
| Medium | 50% |
| High | 75% |
| Critical | 100% |

---

## Weekly Policy Window

Current implementation behavior:

- A policy starts immediately when created.
- Coverage duration is fixed to 7 days.
- A worker cannot create a new policy while an `active` policy exists.
- Expiration status updates are applied by the weekly scheduler run.

Future enhancement (recommended): move to an anchored Monday-Sunday purchase window with a configurable lead-time cutoff and explicit renewal guidance in dashboard payloads.

---

## Verification Module (Fraud Check)

This backend also includes verification endpoints used by the mobile verification flow.

### Verification Endpoints

| Method | Path | Description |
|---|---|---|
| POST | `/api/v1/verification/start` | Create verification session |
| POST | `/api/v1/verification/upload` | Upload video + metadata |
| POST | `/api/v1/verification/validate` | Return fraud score + status |

### Fraud Score Weights

| Signal | Max Points |
|---|---|
| Recording < 10s | 25 |
| No driver app detected | 30 |
| Spoofing score >= 60 | 35 |
| No location samples | 10 |

`score < 40 -> verified` and `score >= 40 -> failed`

---

## Environment Variables

| Variable | Description | Default |
|---|---|---|
| `DATABASE_URL` | PostgreSQL async connection string | `postgresql+asyncpg://gigshield:password@localhost:5432/gigshield` |
| `SECRET_KEY` | JWT signing secret | `change-me-in-production` |
| `ALGORITHM` | JWT algorithm | `HS256` |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | JWT token expiry minutes | `60` |
| `USE_MOCK_APIS` | Toggle mock external APIs | `true` |
| `OPENWEATHER_API_KEY` | OpenWeather API key (live mode) | empty |
| `RAZORPAY_KEY_ID` | Razorpay key ID | empty |
| `RAZORPAY_KEY_SECRET` | Razorpay secret | empty |
| `ML_MODEL_PATH` | Model artifact path for severity prediction | empty |
| `ML_REFERENCE_DATA_PATH` | Reference data path for model pipeline | empty |

---

## API Reference

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/` | No | Service status |
| GET | `/health` | No | Health check |
| POST | `/api/v1/workers/register` | No | Register worker |
| POST | `/api/v1/workers/login` | No | Login with phone + OTP -> JWT |
| GET | `/api/v1/workers/me` | Yes | Get worker profile |
| POST | `/api/v1/pricing/calculate` | Yes | Calculate weekly premium |
| POST | `/api/v1/pricing/predict-severity` | Yes | Predict disruption severity score |
| POST | `/api/v1/policies` | Yes | Create new weekly policy |
| GET | `/api/v1/policies/recommendations` | Yes | Get policy plan recommendations |
| GET | `/api/v1/policies/me` | Yes | List worker policies |
| GET | `/api/v1/policies/{policy_id}` | Yes | Get policy detail |
| DELETE | `/api/v1/policies/{policy_id}` | Yes | Delete policy (when eligible) |
| POST | `/api/v1/events/trigger` | No* | Trigger disruption event -> auto-claims |
| POST | `/api/v1/events/simulate/mock` | No* | Run deterministic mock trigger simulation |
| POST | `/api/v1/claims/me/manual` | Yes | Temporary manual claim endpoint |
| GET | `/api/v1/claims/me` | Yes | List worker claims |
| GET | `/api/v1/claims/{claim_id}` | Yes | Get claim detail |
| GET | `/api/v1/payouts/me` | Yes | List payout history |
| POST | `/api/v1/payouts/{claim_id}/process` | Yes | Deprecated (returns gone) |
| GET | `/api/v1/dashboard/worker` | Yes | Worker dashboard summary |
| GET | `/api/v1/dashboard/admin` | No* | Admin dashboard summary |
| POST | `/api/v1/verification/start` | No | Start verification session |
| POST | `/api/v1/verification/upload` | No | Upload verification assets |
| POST | `/api/v1/verification/validate` | No | Validate fraud signals |

*Admin endpoints are open in Phase 1; role-based access control is planned for a later phase.*

---

## Mock Risk Simulation and Live Risk Ticker

GigShield includes a deterministic, policy-aware mock event simulator and a worker-facing live risk ticker.

### Simulator Endpoint

`POST /api/v1/events/simulate/mock`

- Uses synthetic signals and maps them to parametric event types.
- Supports optional `seed` for reproducible demos.
- Ensures threshold-crossing cases are included in simulation flow.
- Runs through the same event engine path as `POST /api/v1/events/trigger`.

Example request:

```json
{
	"max_events": 8,
	"seed": 7
}
```

Response highlights:

- `mock_data`
- `triggered_sequence`
- `first_threshold_cross_index`
- `first_claim_creation_index`
- `total_claims_created`

### Worker Dashboard Live Ticker

`GET /api/v1/dashboard/worker` includes `risk_today` for client polling and policy-aware ticker behavior.

---

## AI and ML Features

### 1. City Nervous System (Roadmap)

Proposed extension to combine weather with broader urban signals (transit outages, queue anomalies, public health spikes, closure notices) and score disruption probability via ML before trigger execution.

### 2. AI Rating Sentinel (Roadmap)

Proposed extension to detect abnormal rating drops and support algorithmic-disruption protection with evidence generation.

### Current ML in Repository

- Severity prediction endpoint: `POST /api/v1/pricing/predict-severity`
- Runtime model path is configurable via `ML_MODEL_PATH`

---

## Current Phase Scope

### Phase 1 - Seed

- FastAPI scaffold with core insurance and verification endpoints
- SQLAlchemy models with Alembic migration support
- Three-factor pricing engine
- Event trigger to auto-claim pipeline
- Mock external APIs (weather/platform/payment)
- JWT auth with OTP stub
- Worker and admin dashboard endpoints
- APScheduler-based weekly premium burn simulation
- Docker Compose with PostgreSQL

---

## Future Additions

1. Fraud avoidance during onboarding.
2. Real location verification for onboarding city/zone.
3. Video verification of active worker status in delivery apps.
4. Standard insurance exclusions framework.
5. Actuarial sustainability and reserve modeling.
6. Expanded disruption scenario library.
7. Accessibility-first worker journeys with vernacular support.

---

## Tech Stack

| Component | Technology |
|---|---|
| Framework | FastAPI (async) |
| ORM | SQLAlchemy 2.0 (async) |
| Database | PostgreSQL |
| Migrations | Alembic |
| Auth | JWT (`python-jose`) + OTP stub (`passlib`) |
| Scheduler | APScheduler |
| HTTP Client | httpx |
| Validation | Pydantic v2 |
| Testing | pytest + httpx AsyncClient |
| Env Config | pydantic-settings |
| Containerization | Docker Compose |

---

## Setup Instructions

### Prerequisites

- Python 3.11+
- Docker and Docker Compose
- pip

### 1. Install Dependencies

```bash
cd backend
python -m venv .venv
# Linux/macOS
source .venv/bin/activate
# Windows PowerShell
# .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### 2. Start PostgreSQL

```bash
docker compose up -d
```

### 3. Configure Environment

Create or edit `backend/.env` and set required values. Defaults in `app/config.py` are suitable for local development.

### 4. Run Migrations

```bash
cd backend
# activate venv first
alembic upgrade head
```

### 5. Start Backend

```bash
cd backend
# activate venv first
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 6. Access

- OpenAPI docs: `http://localhost:8000/docs`
- Health: `http://localhost:8000/health`
- Android emulator backend base URL: `http://10.0.2.2:8000`

---

## Cross-Platform Integration Scripts

Repository-level scripts are available under `scripts/`:

- `scripts/setup-and-test.sh`
- `scripts/setup-and-test.ps1`
- `scripts/preflight.sh`
- `scripts/preflight.ps1`

Use these from repository root when validating end-to-end setup.

---

## License

MIT - Built for the Guidewire Hackathon 2026.
