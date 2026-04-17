"""OpenWeatherMap free-tier wrapper (mock-capable).

When ``USE_MOCK_APIS=true`` (default for Phase 1), the wrapper returns
deterministic fake data so the platform can be tested end-to-end without
hitting external services.  In production, real HTTP calls are made via
``httpx``.
"""

from dataclasses import dataclass

import httpx

from app.config import settings


@dataclass
class WeatherData:
    """Weather observation for a given city."""

    city: str
    rainfall_mm: float
    aqi: int
    temperature_c: float
    description: str


# ── Mock data keyed by city (lowercase) ────────────────────────────────────

_MOCK_WEATHER: dict[str, WeatherData] = {
    "mumbai": WeatherData(
        city="Mumbai",
        rainfall_mm=65.0,  # above threshold
        aqi=180,
        temperature_c=30.0,
        description="Heavy rain, monsoon season",
    ),
    "delhi": WeatherData(
        city="Delhi",
        rainfall_mm=12.0,
        aqi=350,  # above threshold
        temperature_c=22.0,
        description="Severe smog",
    ),
    "chennai": WeatherData(
        city="Chennai",
        rainfall_mm=55.0,  # above threshold
        aqi=120,
        temperature_c=32.0,
        description="Cyclone warning, heavy rain",
    ),
    "bangalore": WeatherData(
        city="Bangalore",
        rainfall_mm=20.0,
        aqi=90,
        temperature_c=26.0,
        description="Light drizzle",
    ),
    "kolkata": WeatherData(
        city="Kolkata",
        rainfall_mm=48.0,
        aqi=200,
        temperature_c=28.0,
        description="Overcast, moderate rain",
    ),
}

_DEFAULT_MOCK = WeatherData(
    city="Unknown",
    rainfall_mm=10.0,
    aqi=100,
    temperature_c=28.0,
    description="Clear sky",
)


async def get_weather(city: str) -> WeatherData:
    """Fetch weather data for *city*.

    In mock mode, returns deterministic data from ``_MOCK_WEATHER``.
    In live mode, calls the OpenWeatherMap free-tier API.

    Args:
        city: City name (case-insensitive).

    Returns:
        A ``WeatherData`` instance with current conditions.
    """
    if settings.use_mock_apis:
        return _MOCK_WEATHER.get(city.lower(), _DEFAULT_MOCK)

    # ── Live API call ───────────────────────────────────────────────────
    async with httpx.AsyncClient(timeout=10.0) as client:
        # Current weather
        weather_resp = await client.get(
            "https://api.openweathermap.org/data/2.5/weather",
            params={
                "q": f"{city},IN",
                "appid": settings.openweather_api_key,
                "units": "metric",
            },
        )
        weather_resp.raise_for_status()
        weather_json = weather_resp.json()

        # AQI
        lat = weather_json["coord"]["lat"]
        lon = weather_json["coord"]["lon"]
        aqi_resp = await client.get(
            "https://api.openweathermap.org/data/2.5/air_pollution",
            params={
                "lat": lat,
                "lon": lon,
                "appid": settings.openweather_api_key,
            },
        )
        aqi_resp.raise_for_status()
        aqi_json = aqi_resp.json()

        rainfall_mm = weather_json.get("rain", {}).get("1h", 0.0) * 24  # rough 24 h estimate
        aqi_value = aqi_json["list"][0]["main"]["aqi"] * 75  # scale 1-5 → rough AQI

        return WeatherData(
            city=city,
            rainfall_mm=rainfall_mm,
            aqi=aqi_value,
            temperature_c=weather_json["main"]["temp"],
            description=weather_json["weather"][0]["description"],
        )
