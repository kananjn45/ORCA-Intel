"""
app/api/v1/endpoints/geofence.py
Owner (per docs/IMPLEMENTATION_PLAN.md): Dev 1 (Geospatial & Math Engineer)
  -> real lookahead-vector math lives in app/geospatial/geofence.py

TEMPORARY MOCK — written by Dev 3 only so the full API surface boots and
is testable end-to-end before Day 3 integration (task instruction #8).
Implements a SIMPLE straight-distance-only check (no real IMBL polygon,
no 15-minute lookahead projection yet) using a hardcoded reference point
that approximates the India-Sri Lanka IMBL near Palk Strait, purely so
the response SHAPE (`GeofenceStatus`) is exercisable by the mobile team.

Real behavior once Dev 1 wires this up: distance to the nearest point on
the actual IMBL polyline (from app/geospatial/shapefile_loader.py) +
15-min speed/heading lookahead intersection test (app/geospatial/geofence.py).
"""
import math

from fastapi import APIRouter

from app.models.schemas import GeofenceStatus, TelemetryPayload

router = APIRouter()

# Rough reference point near the Palk Strait IMBL — NOT the real boundary polyline.
_MOCK_IMBL_REFERENCE = {"lat": 9.35, "lon": 79.42}


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlambda / 2) ** 2
    return 2 * r * math.asin(min(1.0, math.sqrt(a)))


def _warning_level(distance_km: float) -> str:
    if distance_km < 2.0:
        return "CRITICAL"
    if distance_km < 5.0:
        return "WARNING"
    if distance_km < 10.0:
        return "ADVISORY"
    return "SAFE"


@router.post("/check", response_model=GeofenceStatus, summary="[MOCK] IMBL distance check — Dev 1 owns real logic")
async def check_geofence(telemetry: TelemetryPayload) -> GeofenceStatus:
    distance_km = round(
        _haversine_km(
            telemetry.latitude, telemetry.longitude,
            _MOCK_IMBL_REFERENCE["lat"], _MOCK_IMBL_REFERENCE["lon"],
        ),
        2,
    )
    # Extremely simplified "is the vessel heading roughly toward the reference point"
    # placeholder — Dev 1's real 15-min lookahead vector + Shapely intersection
    # test replaces this entirely on Day 2/3.
    lookahead_breach = distance_km < 5.0 and telemetry.speed_knots > 5.0
    time_to_breach = round((distance_km / max(telemetry.speed_knots, 0.1)) * 60, 1) if lookahead_breach else None

    return GeofenceStatus(
        distance_to_imbl_km=distance_km,
        nearest_imbl_point=_MOCK_IMBL_REFERENCE,
        lookahead_breach_projected=lookahead_breach,
        time_to_breach_minutes=time_to_breach,
        warning_level=_warning_level(distance_km),
        evasive_heading_deg=(telemetry.heading_deg + 180) % 360 if distance_km < 2.0 else None,
    )