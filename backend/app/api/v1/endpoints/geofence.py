"""
app/api/v1/endpoints/geofence.py
Owner: Dev 1 (Geospatial & Math Engineer)
Real lookahead-vector math lives in app/geospatial/geofence.py.
Computes metric distance to the India-Sri Lanka IMBL boundary polyline
and 15-minute vessel track projection.
"""
import json
import logging
import math
from pathlib import Path
from typing import Optional

from fastapi import APIRouter
from shapely.geometry import MultiLineString, Point, shape
from shapely.ops import nearest_points

from app.geospatial.distance import distance_to_geometry_km, haversine_km
from app.geospatial.geofence import calculate_lookahead
from app.models.schemas import GeofenceStatus, TelemetryPayload

logger = logging.getLogger("orca.geofence")
router = APIRouter()

# Default fallback reference point near Palk Strait IMBL
_DEFAULT_IMBL_REFERENCE = {"lat": 9.35, "lon": 79.42}
_IMBL_GEOMETRY: Optional[MultiLineString] = None


def _get_imbl_geometry() -> Optional[MultiLineString]:
    """Lazy load the Palk Strait / Gulf of Mannar IMBL polyline."""
    global _IMBL_GEOMETRY
    if _IMBL_GEOMETRY is not None:
        return _IMBL_GEOMETRY

    candidates = [
        Path(__file__).resolve().parent.parent.parent.parent / "data" / "boundaries" / "india_imbl.geojson",
        Path("data/boundaries/india_imbl.geojson"),
        Path("backend/data/boundaries/india_imbl.geojson"),
        Path(__file__).resolve().parent.parent.parent.parent / "data" / "boundaries" / "imbl_palk_strait.geojson",
        Path("data/boundaries/imbl_palk_strait.geojson"),
        Path("backend/data/boundaries/imbl_palk_strait.geojson"),
    ]
    for p in candidates:
        if p.exists() and p.stat().st_size > 0:
            try:
                with open(p, "r", encoding="utf-8") as f:
                    data = json.load(f)
                lines = [
                    shape(feat["geometry"])
                    for feat in data.get("features", [])
                    if "geometry" in feat and feat.get("properties", {}).get("boundary_type", "IMBL") == "IMBL"
                ]
                if not lines:
                    lines = [shape(feat["geometry"]) for feat in data.get("features", []) if "geometry" in feat]
                if lines:
                    _IMBL_GEOMETRY = MultiLineString(lines)
                    logger.info("Loaded %d IMBL boundary segments from %s", len(lines), p)
                    return _IMBL_GEOMETRY
            except Exception as e:
                logger.warning("Failed loading IMBL boundary from %s: %s", p, e)
    return None


def _warning_level(distance_km: float) -> str:
    if distance_km < 2.0:
        return "CRITICAL"
    if distance_km < 5.0:
        return "WARNING"
    if distance_km < 10.0:
        return "ADVISORY"
    return "SAFE"


@router.post("/check", response_model=GeofenceStatus, summary="IMBL distance & 15-min lookahead check")
async def check_geofence(telemetry: TelemetryPayload) -> GeofenceStatus:
    imbl = _get_imbl_geometry()

    if imbl is not None and not imbl.is_empty:
        # 1. Exact metric distance in km via local AEQD projection
        distance_km = round(
            distance_to_geometry_km(telemetry.latitude, telemetry.longitude, imbl),
            2,
        )

        # 2. Nearest point on boundary polyline
        vessel_pt = Point(telemetry.longitude, telemetry.latitude)
        _, nearest_pt = nearest_points(vessel_pt, imbl)
        nearest_coords = {"lat": round(nearest_pt.y, 4), "lon": round(nearest_pt.x, 4)}

        # 3. 15-minute speed/heading geodesic lookahead projection
        lookahead = calculate_lookahead(
            lat=telemetry.latitude,
            lon=telemetry.longitude,
            speed_knots=telemetry.speed_knots,
            heading_deg=telemetry.heading_deg,
            boundary_geometry=imbl,
            minutes=15.0,
        )
        lookahead_breach = lookahead.intersects_boundary or (distance_km < 5.0 and telemetry.speed_knots > 5.0)

        # 4. Time to breach (minutes)
        speed_kmh = telemetry.speed_knots * 1.852
        if lookahead_breach and speed_kmh > 0.1:
            time_to_breach = round((distance_km / speed_kmh) * 60.0, 1)
        else:
            time_to_breach = None

        evasive = round((telemetry.heading_deg + 180.0) % 360.0, 1) if (distance_km < 2.0 or lookahead_breach) else None

        return GeofenceStatus(
            distance_to_imbl_km=distance_km,
            nearest_imbl_point=nearest_coords,
            lookahead_breach_projected=lookahead_breach,
            time_to_breach_minutes=time_to_breach,
            warning_level=_warning_level(distance_km),
            evasive_heading_deg=evasive,
        )

    # Safe fallback if geometry file is not found
    distance_km = round(
        haversine_km(
            telemetry.latitude,
            telemetry.longitude,
            _DEFAULT_IMBL_REFERENCE["lat"],
            _DEFAULT_IMBL_REFERENCE["lon"],
        ),
        2,
    )
    lookahead_breach = distance_km < 5.0 and telemetry.speed_knots > 5.0
    time_to_breach = round((distance_km / max(telemetry.speed_knots * 1.852, 0.1)) * 60, 1) if lookahead_breach else None

    return GeofenceStatus(
        distance_to_imbl_km=distance_km,
        nearest_imbl_point=_DEFAULT_IMBL_REFERENCE,
        lookahead_breach_projected=lookahead_breach,
        time_to_breach_minutes=time_to_breach,
        warning_level=_warning_level(distance_km),
        evasive_heading_deg=round((telemetry.heading_deg + 180.0) % 360.0, 1) if distance_km < 2.0 else None,
    )