"""
app/services/open_meteo.py
Owner: Dev 3 (Data Pipeline & Backend Core Engineer)
Day: 1 (client) + Day 2 (cache wiring)

Async client for the free, keyless Open-Meteo Marine + Forecast APIs.

Two upstream calls are combined because Open-Meteo splits the data we
need across two products:
  - https://marine-api.open-meteo.com/v1/marine
      -> wave_height, wave_direction, wave_period, swell_wave_height,
         sea_surface_temperature
  - https://api.open-meteo.com/v1/forecast
      -> wind_speed_10m, wind_direction_10m (marine API has no wind
         speed variable, only wind-driven wave height)

Both calls are fired concurrently with asyncio.gather for latency.
"""
import asyncio
from typing import Any, Dict, Optional

import httpx

from app.core.config import settings
from app.core.logging import get_logger
from app.models.schemas import MarineWeatherMetric
from app.services.cache import get_weather_cache, make_grid_key

logger = get_logger(__name__)


class OpenMeteoServiceError(Exception):
    """Raised when the upstream Open-Meteo API cannot be reached or returns an error."""


async def _fetch_json(client: httpx.AsyncClient, url: str, params: Dict[str, Any]) -> Dict[str, Any]:
    try:
        response = await client.get(url, params=params, timeout=settings.OPEN_METEO_TIMEOUT_SECONDS)
        response.raise_for_status()
        return response.json()
    except httpx.TimeoutException as exc:
        raise OpenMeteoServiceError(f"Timed out calling {url}") from exc
    except httpx.HTTPStatusError as exc:
        raise OpenMeteoServiceError(
            f"Open-Meteo returned HTTP {exc.response.status_code} for {url}: {exc.response.text[:200]}"
        ) from exc
    except httpx.RequestError as exc:
        raise OpenMeteoServiceError(f"Network error calling {url}: {exc}") from exc


def _sea_state_code(wave_height_m: float) -> int:
    """WMO-inspired simplified sea state scale (0 = calm glassy, 9 = phenomenal)."""
    if wave_height_m > 14.0:
        return 9
    thresholds = [0.0, 0.1, 0.5, 1.25, 2.5, 4.0, 6.0, 9.0, 14.0]
    code = 0
    for i, t in enumerate(thresholds):
        if wave_height_m >= t:
            code = i
    return min(code, 9)


def _build_advisory(wave_height_m: float, wind_speed_knots: float) -> tuple[bool, str]:
    """
    Mirrors the safety invariants in docs/TRD.md section 4.1 (the FINAL
    hard-stop enforcement lives in Dev 2's SymbolicGuardrailNode — this is
    just an informational summary attached to the raw weather reading).
    """
    if wave_height_m > 2.5 or wind_speed_knots > 25:
        return False, "DANGEROUS: High waves/winds. Do not venture into open sea."
    if wave_height_m > 2.0 or wind_speed_knots > 20:
        return True, "CAUTION: Choppy conditions expected. Small craft advisory in effect."
    if wave_height_m > 1.0 or wind_speed_knots > 12:
        return True, "Moderate breeze, safe for mechanized crafts."
    return True, "Calm seas. Favorable conditions for fishing."


async def _fetch_live_weather(latitude: float, longitude: float) -> MarineWeatherMetric:
    marine_params = {
        "latitude": latitude,
        "longitude": longitude,
        "current": "wave_height,wave_direction,wave_period,swell_wave_height,sea_surface_temperature",
        "timezone": "auto",
    }
    wind_params = {
        "latitude": latitude,
        "longitude": longitude,
        "current": "wind_speed_10m,wind_direction_10m",
        "wind_speed_unit": "kn",
        "timezone": "auto",
    }

    async with httpx.AsyncClient() as client:
        marine_task = _fetch_json(client, settings.OPEN_METEO_MARINE_BASE_URL, marine_params)
        wind_task = _fetch_json(client, settings.OPEN_METEO_FORECAST_BASE_URL, wind_params)
        marine_json, wind_json = await asyncio.gather(marine_task, wind_task)

    marine_current = marine_json.get("current", {})
    wind_current = wind_json.get("current", {})

    wave_height_m = float(marine_current.get("wave_height") or 0.0)
    wave_direction_deg = float(marine_current.get("wave_direction") or 0.0)
    wave_period_sec = float(marine_current.get("wave_period") or 0.0)
    swell_wave_height_m = float(marine_current.get("swell_wave_height") or wave_height_m * 0.8)
    sea_surface_temp_celsius = float(marine_current.get("sea_surface_temperature") or 27.0)

    wind_speed_knots = float(wind_current.get("wind_speed_10m") or 0.0)
    wind_direction_deg = float(wind_current.get("wind_direction_10m") or 0.0)

    is_safe, advisory = _build_advisory(wave_height_m, wind_speed_knots)

    return MarineWeatherMetric(
        latitude=latitude,
        longitude=longitude,
        wave_height_m=round(wave_height_m, 2),
        wave_direction_deg=round(wave_direction_deg, 1),
        wave_period_sec=round(wave_period_sec, 1),
        wind_speed_knots=round(wind_speed_knots, 1),
        wind_direction_deg=round(wind_direction_deg, 1),
        swell_wave_height_m=round(swell_wave_height_m, 2),
        sea_surface_temp_celsius=round(sea_surface_temp_celsius, 1),
        sea_state_code=_sea_state_code(wave_height_m),
        is_safe_for_small_craft=is_safe,
        advisory_summary=advisory,
        source="open-meteo",
    )


def _synthetic_fallback_weather(latitude: float, longitude: float, reason: str) -> MarineWeatherMetric:
    """
    If Open-Meteo is unreachable (offline sandbox, network blocked, rate
    limited) we still want the rest of the team to be able to develop and
    demo against this endpoint. Returns a clearly-labeled synthetic reading
    instead of a hard 500, so the mobile team is never fully blocked.
    """
    import hashlib

    seed = int(hashlib.sha256(f"{round(latitude, 2)}:{round(longitude, 2)}".encode()).hexdigest(), 16)
    wave_height_m = round(0.4 + (seed % 200) / 100, 2)          # ~0.4m - 2.4m
    wind_speed_knots = round(4 + (seed % 1800) / 100, 1)         # ~4kt - 22kt
    is_safe, advisory = _build_advisory(wave_height_m, wind_speed_knots)
    logger.warning("open_meteo_fallback_used", extra={"extra_fields": {"reason": reason}})
    return MarineWeatherMetric(
        latitude=latitude,
        longitude=longitude,
        wave_height_m=wave_height_m,
        wave_direction_deg=float(seed % 360),
        wave_period_sec=round(4 + (seed % 500) / 100, 1),
        wind_speed_knots=wind_speed_knots,
        wind_direction_deg=float((seed // 7) % 360),
        swell_wave_height_m=round(wave_height_m * 0.75, 2),
        sea_surface_temp_celsius=round(26 + (seed % 400) / 100, 1),
        sea_state_code=_sea_state_code(wave_height_m),
        is_safe_for_small_craft=is_safe,
        advisory_summary=f"[SYNTHETIC - upstream unavailable] {advisory}",
        source="synthetic-fallback",
    )


async def get_marine_weather(latitude: float, longitude: float, use_cache: bool = True) -> MarineWeatherMetric:
    """
    Public entrypoint used by the /api/v1/marine/weather endpoint (and by
    the offline-pack builder). Cached with a rounded-coordinate key so a
    vessel drifting a few hundred meters keeps hitting the same cache entry.
    """
    cache = get_weather_cache()
    cache_key = make_grid_key("weather", latitude, longitude, precision=2)

    if use_cache:
        cached = await cache.get(cache_key)
        if cached is not None:
            logger.info("weather_cache_hit", extra={"extra_fields": {"key": cache_key}})
            return cached

    try:
        result = await _fetch_live_weather(latitude, longitude)
    except OpenMeteoServiceError as exc:
        result = _synthetic_fallback_weather(latitude, longitude, reason=str(exc))

    if use_cache:
        await cache.set(cache_key, result, ttl_seconds=settings.WEATHER_CACHE_TTL_SECONDS)

    return result