"""
app/services/incois_pfz.py
Owner: Dev 3 (Data Pipeline & Backend Core Engineer)
Day: 1 (mock generator) + Day 2 (cache wiring + endpoint hookup)

ASSUMPTION (stated explicitly per task instructions): INCOIS / MOSDAC do
not publish a documented, public, key-less REST API that can be reliably
integrated in a 5-day hackathon. This module therefore ships a
deterministic MOCK PFZ generator that produces realistic-looking
Potential Fishing Zone polygons (chlorophyll-a fronts, SST gradients,
depth) around any queried coordinate.

The function signature/shape is exactly what a real integration would
return, so swapping this out later only touches `_generate_mock_pfz_features`
-> `_fetch_live_pfz_features` — nothing downstream (endpoints, agents,
mobile client) needs to change. Toggle via INCOIS_USE_MOCK in .env.
"""
import hashlib
import random
from datetime import datetime, timedelta, timezone
from typing import List

from app.core.config import settings
from app.core.logging import get_logger
from app.models.geojson_models import build_polygon_geometry
from app.models.schemas import PFZFeature
from app.services.cache import get_pfz_cache, make_grid_key

logger = get_logger(__name__)

_SECTOR_NAMES = [
    "Palk Bay South", "Palk Bay North", "Gulf of Mannar East", "Gulf of Mannar West",
    "Coromandel Coast Offshore", "Cauvery Delta Shelf", "Tuticorin Approach",
    "Rameswaram Channel", "Nagapattinam Bank", "Pamban Strait Outer",
]


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    import math

    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlambda / 2) ** 2
    return 2 * r * math.asin(min(1.0, math.sqrt(a)))


def _bearing_deg(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    import math

    p1, p2 = math.radians(lat1), math.radians(lat2)
    dlambda = math.radians(lon2 - lon1)
    x = math.sin(dlambda) * math.cos(p2)
    y = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dlambda)
    return (math.degrees(math.atan2(x, y)) + 360) % 360


def _generate_mock_pfz_features(
    latitude: float, longitude: float, radius_km: float, max_results: int = 6
) -> List[PFZFeature]:
    """
    Deterministically seeded so the SAME query (rounded coords + radius)
    always returns the SAME zones within a cache window — this matters for
    demo reproducibility (judges re-asking the same question should not
    get a different answer each time).
    """
    seed_str = f"{round(latitude, 2)}:{round(longitude, 2)}:{round(radius_km, 1)}"
    seed = int(hashlib.sha256(seed_str.encode()).hexdigest(), 16) % (2**32)
    rng = random.Random(seed)

    now = datetime.now(timezone.utc)
    count = rng.randint(3, max_results)
    features: List[PFZFeature] = []

    for i in range(count):
        # Scatter candidate zones within the requested radius using polar offsets.
        distance_km = round(rng.uniform(radius_km * 0.15, radius_km * 0.95), 1)
        bearing = rng.uniform(0, 360)

        import math

        d_lat = (distance_km / 6371.0) * math.cos(math.radians(bearing))
        d_lon = (distance_km / 6371.0) * math.sin(math.radians(bearing)) / math.cos(math.radians(latitude))
        centroid_lat = round(latitude + math.degrees(d_lat), 5)
        centroid_lon = round(longitude + math.degrees(d_lon), 5)

        chlorophyll = round(rng.uniform(0.2, 2.0), 2)      # mg/m3, per TRD 6.2 realistic band
        sst_gradient = round(rng.uniform(0.3, 1.5), 2)      # deg C
        depth_m = round(rng.uniform(8.0, 60.0), 1)
        zone_radius_km = round(rng.uniform(1.5, 4.5), 2)

        actual_distance = round(_haversine_km(latitude, longitude, centroid_lat, centroid_lon), 2)
        actual_bearing = round(_bearing_deg(latitude, longitude, centroid_lat, centroid_lon), 1)

        pfz_id = f"PFZ-TN-{now.strftime('%Y%m%d')}-{i + 1:03d}"
        features.append(
            PFZFeature(
                pfz_id=pfz_id,
                sector_name=rng.choice(_SECTOR_NAMES),
                centroid={"lat": centroid_lat, "lon": centroid_lon},
                distance_km=actual_distance,
                bearing_deg=actual_bearing,
                chlorophyll_mg_m3=chlorophyll,
                sst_gradient_celsius=sst_gradient,
                depth_m=depth_m,
                valid_until=now + timedelta(hours=24),
                geojson_geometry=build_polygon_geometry(centroid_lat, centroid_lon, zone_radius_km),
                source="incois-mock",
            )
        )

    # Best zones (highest chlorophyll) first — that's what a fisherman cares about.
    features.sort(key=lambda f: f.chlorophyll_mg_m3, reverse=True)
    return features


async def _fetch_live_pfz_features(latitude: float, longitude: float, radius_km: float) -> List[PFZFeature]:
    """
    Placeholder for a real INCOIS/MOSDAC integration. Not implemented in
    this hackathon build (see module docstring). Left here so wiring in a
    real feed later is a one-function swap — raises so misconfiguration is
    loud instead of silently returning nothing.
    """
    raise NotImplementedError(
        "Live INCOIS/MOSDAC PFZ feed is not configured for this build. "
        "Set INCOIS_USE_MOCK=true (default) to use the deterministic mock generator."
    )


async def get_pfz_features(
    latitude: float, longitude: float, radius_km: float = 50.0, use_cache: bool = True
) -> List[PFZFeature]:
    """Public entrypoint used by the /api/v1/marine/pfz endpoint."""
    cache = get_pfz_cache()
    cache_key = make_grid_key("pfz", latitude, longitude, precision=2, radius=radius_km)

    if use_cache:
        cached = await cache.get(cache_key)
        if cached is not None:
            logger.info("pfz_cache_hit", extra={"extra_fields": {"key": cache_key}})
            return cached

    if settings.INCOIS_USE_MOCK:
        result = _generate_mock_pfz_features(latitude, longitude, radius_km)
    else:
        result = await _fetch_live_pfz_features(latitude, longitude, radius_km)

    if use_cache:
        await cache.set(cache_key, result, ttl_seconds=settings.PFZ_CACHE_TTL_SECONDS)

    return result