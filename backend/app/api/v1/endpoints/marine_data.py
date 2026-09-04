"""
app/api/v1/endpoints/marine_data.py
Owner: Dev 3 (Data Pipeline & Backend Core Engineer)
Day: 1 (route scaffolding) + Day 2 (full implementation)

Implements:
  GET /api/v1/marine/weather       -> MarineWeatherMetric
  GET /api/v1/marine/pfz           -> List[PFZFeature]
  GET /api/v1/marine/offline-pack  -> OfflinePackResponse
  GET /api/v1/marine/cache-stats   -> debug endpoint (not in the official
                                       contract, but very handy for
                                       demonstrating the caching layer to
                                       judges / teammates)
"""
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, List

from fastapi import APIRouter, HTTPException, Query, status

from app.core.logging import get_logger
from app.models.geojson_models import empty_feature_collection
from app.models.schemas import MarineWeatherMetric, OfflinePackResponse, PFZFeature
from app.services import incois_pfz, open_meteo
from app.services.cache import get_all_cache_stats

logger = get_logger(__name__)
router = APIRouter()

_IMBL_GEOJSON: Dict[str, Any] | None = None


def _get_imbl_geojson() -> Dict[str, Any]:
    global _IMBL_GEOJSON
    if _IMBL_GEOJSON is not None:
        return _IMBL_GEOJSON
    candidates = [
        Path(__file__).resolve().parent.parent.parent.parent / "data" / "boundaries" / "india_imbl.geojson",
        Path("data/boundaries/india_imbl.geojson"),
        Path("backend/data/boundaries/india_imbl.geojson"),
    ]
    for p in candidates:
        if p.exists() and p.stat().st_size > 0:
            try:
                with open(p, "r", encoding="utf-8") as f:
                    _IMBL_GEOJSON = json.load(f)
                    return _IMBL_GEOJSON
            except Exception:
                pass
    return empty_feature_collection()


def _validate_lat(lat: float) -> None:
    if not (-90.0 <= lat <= 90.0):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="latitude must be between -90 and 90")


def _validate_lon(lon: float) -> None:
    if not (-180.0 <= lon <= 180.0):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="longitude must be between -180 and 180")


@router.get("/weather", response_model=MarineWeatherMetric, summary="Live Open-Meteo sea state metrics")
async def get_weather(
    lat: float = Query(..., description="Vessel/query latitude", examples=[9.28]),
    lon: float = Query(..., description="Vessel/query longitude", examples=[79.31]),
) -> MarineWeatherMetric:
    _validate_lat(lat)
    _validate_lon(lon)
    try:
        return await open_meteo.get_marine_weather(lat, lon)
    except Exception as exc:  # pragma: no cover - defensive net, service already has its own fallback
        logger.exception("weather_endpoint_failed")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Unable to retrieve marine weather: {exc}",
        ) from exc


@router.get("/pfz", response_model=List[PFZFeature], summary="Active INCOIS PFZ advisory polygons")
async def get_pfz(
    lat: float = Query(..., description="Query center latitude", examples=[9.28]),
    lon: float = Query(..., description="Query center longitude", examples=[79.31]),
    radius_km: float = Query(50.0, gt=0, le=500, description="Search radius in kilometers"),
) -> List[PFZFeature]:
    _validate_lat(lat)
    _validate_lon(lon)
    try:
        return await incois_pfz.get_pfz_features(lat, lon, radius_km)
    except Exception as exc:  # pragma: no cover
        logger.exception("pfz_endpoint_failed")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Unable to retrieve PFZ advisories: {exc}",
        ) from exc


@router.get("/offline-pack", response_model=OfflinePackResponse, summary="24-hr bounding box bundle for offline storage")
async def get_offline_pack(
    min_lat: float = Query(..., examples=[8.5]),
    min_lon: float = Query(..., examples=[78.5]),
    max_lat: float = Query(..., examples=[10.5]),
    max_lon: float = Query(..., examples=[80.5]),
    grid_resolution_deg: float = Query(0.5, gt=0.05, le=2.0, description="Weather sample spacing in degrees"),
) -> OfflinePackResponse:
    """
    Bundles a weather grid + PFZ advisories for the requested bounding box
    so the Flutter app can hydrate its sqflite cache before losing signal.

    NOTE (assumption): `imbl_boundary_geojson` is returned as an empty
    FeatureCollection here. Real IMBL/coastline polygons are owned by
    Dev 1 (`app/geospatial/shapefile_loader.py`) and are wired in during
    Day 3 integration per docs/IMPLEMENTATION_PLAN.md. This keeps the
    offline-pack contract testable end-to-end today without blocking on
    Dev 1's GIS parsing work.
    """
    for lat in (min_lat, max_lat):
        _validate_lat(lat)
    for lon in (min_lon, max_lon):
        _validate_lon(lon)
    if min_lat >= max_lat or min_lon >= max_lon:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="min_lat/min_lon must be strictly less than max_lat/max_lon",
        )
    # Guard against an absurdly large bbox blowing up the grid sample count.
    if (max_lat - min_lat) > 10 or (max_lon - min_lon) > 10:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Bounding box too large for an offline pack (max 10 degrees per side)",
        )

    # Build a coarse sampling grid across the bounding box.
    lat_steps = max(1, int((max_lat - min_lat) / grid_resolution_deg) + 1)
    lon_steps = max(1, int((max_lon - min_lon) / grid_resolution_deg) + 1)
    lat_steps = min(lat_steps, 12)  # hard cap so a demo laptop doesn't fan out 500 requests
    lon_steps = min(lon_steps, 12)

    sample_points = []
    for i in range(lat_steps):
        for j in range(lon_steps):
            sample_lat = round(min_lat + i * (max_lat - min_lat) / max(1, lat_steps - 1), 4) if lat_steps > 1 else min_lat
            sample_lon = round(min_lon + j * (max_lon - min_lon) / max(1, lon_steps - 1), 4) if lon_steps > 1 else min_lon
            sample_points.append((sample_lat, sample_lon))

    weather_grid: List[MarineWeatherMetric] = []
    for sample_lat, sample_lon in sample_points:
        try:
            reading = await open_meteo.get_marine_weather(sample_lat, sample_lon)
            weather_grid.append(reading)
        except Exception:  # pragma: no cover - individual cell failures shouldn't fail the whole pack
            logger.warning(
                "offline_pack_weather_cell_failed",
                extra={"extra_fields": {"lat": sample_lat, "lon": sample_lon}},
            )

    center_lat = (min_lat + max_lat) / 2
    center_lon = (min_lon + max_lon) / 2
    approx_radius_km = max(
        1.0,
        ((max_lat - min_lat) * 111.0 + (max_lon - min_lon) * 111.0) / 2,
    )
    try:
        pfz_advisories = await incois_pfz.get_pfz_features(center_lat, center_lon, approx_radius_km)
    except Exception:  # pragma: no cover
        logger.warning("offline_pack_pfz_failed")
        pfz_advisories = []

    now = datetime.now(timezone.utc)
    return OfflinePackResponse(
        generated_at=now,
        expires_at=now + timedelta(hours=24),
        bounding_box={"min_lat": min_lat, "min_lon": min_lon, "max_lat": max_lat, "max_lon": max_lon},
        weather_grid=weather_grid,
        pfz_advisories=pfz_advisories,
        imbl_boundary_geojson=_get_imbl_geojson(),
        grid_resolution_deg=grid_resolution_deg,
        cell_count=len(weather_grid),
    )


@router.get("/cache-stats", summary="[Debug] Inspect the TTL cache hit/miss stats")
async def get_cache_stats() -> dict:
    return get_all_cache_stats()