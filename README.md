# GigShield — AI-Powered Parametric Insurance for Delivery Workers

GigShield is a revolutionary parametric income-loss insurance platform designed for India's gig economy delivery workers (such as Zomato, Swiggy, Uber, and Ola partners). It offers an automated, objective, and rapid insurance model where external signals (weather, air quality, city shutdowns) trigger claims automatically, eliminating paperwork and speeding up essential payouts.

[**🔴 Live Backend API Documentation (AWS)**](http://43.204.22.185:8000/docs)

---

## 🚀 The GigShield Verification Flow 

To prevent fraud and ensure that claims are only paid to active, legitimate delivery workers on the ground, GigShield employs a **Special Screen Recording Verification Protocol** built natively into the Flutter mobile application (`gigshield_verify`).

### Step-by-Step App Verification Flow

1. **Start Verification Session**: The delivery worker initiates the verification process in the GigShield app. The app securely fetches a session ID, a rotating alphanumeric verification code (nonce), and verifies basic device integrity.
2. **Screen Recording & Active State Tracking**: 
   - A screen-recording session begins natively on the Android device. 
   - A secure floating overlay displays the active tracking session and the rotating nonce so that the recording can later be analyzed manually or algorithmically to prevent replay attacks.
   - The app actively polls for foreground application usage to detect whether the worker is actually using a gig delivery app.
3. **Location & Spoofing Detection**: While recording, the app captures a continuous stream of GPS samples. It analyzes these samples for impossible speed jumps and checks the device for "mock location provider" flags and active Developer Options to deter GPS spoofing.
4. **App Switching & Activity**: The worker switches to their driver app to demonstrate that they are actively online and taking orders while the screen recording captures their session.
5. **Secure Upload & Fraud Validation**: The worker returns to the GigShield app and stops the recording. The encrypted video file, location history, and app usage signals are securely uploaded to the backend server.
6. **Automated Backend Scoring**: The backend analyzes the uploaded payload. It computes a **Fraud Score** and a **Spoofing Score** based on multi-factor signals (recording length, mock provider flags, driver app detection). If the payload passes the validation (`score < 40`), the worker is marked as verified and becomes eligible for parametric claim auto-payouts.

---

## 🏗️ Project Architecture

```
gigshield_verify/          # Flutter Android app with native screen-recording and fraud checks
backend/                   # FastAPI Python server handling parametric logic, algorithms, and models
```

<img width="1006" height="468" alt="GigShield Architecture" src="https://github.com/user-attachments/assets/f4431bf8-edcd-4d3e-9787-5b510f138852" />

### 🌐 Live Deployment
The backend API and Admin infrastructure are built on FastAPI and fully containerized. 
**Access the live AWS Server API Specs here: [http://43.204.22.185:8000/docs](http://43.204.22.185:8000/docs)**

---

## 💰 Pricing & Coverage Model

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

*(Example scenarios and specific details are fully accessible via the backend API documentation).*

---

## ⚡ Parametric Triggers

Our systems monitor third-party datasets and auto-trigger payouts out to the workers. If an event occurs, it parses through valid active worker policies and deposits a percentage of the coverage based on the calculated severity.

| Event Type | Threshold | Auto-Action |
|---|---|---|
| Rainfall | > 50 mm in 24 hours in worker city | Auto-create `income_loss` claim for active workers |
| AQI | > 300 in worker zone | Auto-create `income_loss` claim for active workers |
| Curfew / Strike | Boolean flag = `true` for city | Auto-create `income_loss` claim for active workers |

### Severity-Based Payout Ratios

| Severity | Payout % |
|---|---|
| Low | 25% |
| Medium | 50% |
| High | 75% |
| Critical | 100% |

---

## 🛡️ Verification Module Backend (Fraud Check)

The backend exposes specific endpoints exactly designed to interact with our Flutter Application's mobile verification engine.

### Verification Endpoints

| Method | Path | Description |
|---|---|---|
| POST | `/api/v1/verification/start` | Build a new verification session |
| POST | `/api/v1/verification/upload` | Upload video + structural app metadata |
| POST | `/api/v1/verification/validate` | Return final fraud score + status calculation |

### Fraud Validation Logic Weighting

The system weighs various signals to identify potential fraud accurately natively:

| Signal | Max Penalty Points |
|---|---|
| Recording < 10s | 25 |
| No driver app detected | 30 |
| Spoofing score >= 60 | 35 |
| No location samples | 10 |

`Score < 40 -> verified` | `Score >= 40 -> validation failed`

---

## 🧠 Machine Learning & Server Intelligence

GigShield embeds intelligent real-time disruption prediction directly into the FastAPI backend. Traditional parametric models rely entirely on post-facto ground truths, but GigShield uses an **XGBoost MLOps Pipeline** to anticipate severity before total operational failure.

### Real-Time Severity Prediction
The backend features an advanced ML endpoint (`/api/v1/pricing/predict-severity`) which evaluates 15 distinct live signals representing the worker's current environment. 
- **Features Analyzed:** Distance, current weather conditions, traffic level, vehicle type, granular climate data (temperature, humidity, precipitation), the delivery platform's estimated preparation time, worker demographic data (age, experience, platform rating), and computed macro risk indices (weather risk, traffic risk).
- **Core Engine:** An XGBoost model (`xg_bost.pkl`) dynamically estimates the true severity score of a trip under extreme conditions, predicting the likelihood of an `income_loss` parametric claim being triggered.
- **Processing Pipeline:** Our backend mimics the exact notebook-based data preprocessing pipeline. It merges the real-time payload with synthetic baseline references, conducts feature scaling (`StandardScaler`), performs selective Label / One-Hot Encoding, and immediately outputs a scaled Severity Classification Score back to the client.

### Event Simulation & Automation
The backend isn't just a static API; it is an active disruption monitoring system:
- **Mock Event Simulator:** A deterministic, policy-aware mock event simulator allows stakeholders to simulate various disruptions via API (`/api/v1/events/simulate/mock`). It safely validates threshold-crossing behavior and tests the auto-payout claim generation sequence.
- **Automated APScheduler:** A background native cron engine processes weekly premium burns, manages strict 7-day policy expirations, and actively synchronizes policy statuses seamlessly.

---

## 🛠️ Tech Stack

**Mobile Application (`gigshield_verify/`)**:
- **Engine**: Flutter / Dart
- **Native Integrations**: Android MediaProjection (Screen Recording), UsageStatsManager (App Switching Context)
- **Aesthetics**: High Contrast Minimalist B&W Dynamic Design

**Backend (`backend/`)**:
- **API Server**: FastAPI (Async Python)
- **Database**: PostgreSQL & SQLAlchemy 2.0
- **Migrations**: Alembic
- **Automation / CRON**: APScheduler 
- **Deployment**: Configured and deployed on **AWS Cloud**

---

## 🚦 Future Roadmap Updates

1. **City Nervous System**: Combine weather tracking with broader signals (transit outages, queue anomalies, health infrastructure stress).
2. **AI Rating Sentinel**: Extension to prevent delivery executives from undergoing platform termination during extreme weather anomalies tracking algorithmic damage.
3. Expanded disruption scenario library for targeted protection.

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

## 📄 License
MIT License - Developed for the Guidewire Hackathon.
