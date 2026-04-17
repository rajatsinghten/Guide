# GigShield Verify — FastAPI Backend

## Run

```bash
cd backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Android emulator connects via `http://10.0.2.2:8000`.

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | /verification/start | Create session |
| POST | /verification/upload | Upload video + metadata |
| POST | /verification/validate | Get fraud score |

## Fraud Score Weights

| Signal | Max Points |
|--------|-----------|
| Recording < 10s | 25 |
| No driver app detected | 30 |
| Spoofing score ≥ 60 | 35 |
| No location samples | 10 |

Score < 40 → **verified** | Score ≥ 40 → **failed**
