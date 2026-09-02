"""
app/api/v1/endpoints/navigation.py
Owner (per docs/IMPLEMENTATION_PLAN.md): Dev 1 (Geospatial & Math Engineer)
  -> real A* pathfinding logic lives in app/geospatial/astar.py + grid.py

TEMPORARY MOCK — written by Dev 3 ONLY so that:
  1) main.py boots cleanly and the full router surface is testable on Day 1/2
     (per task instruction #8: "provide a temporary mock so that Developer 3's
     work can still be tested independently").
  2) The mobile team (Dev 5/6) and Dev 2's ResponseSynthesizer can start
     coding against the exact `RouteCalculationResponse` shape immediately.

Expected real behavior once Dev 1 wires this up (Day 3, per
IMPLEMENTATION_PLAN.md "Dev 1 + Dev 5" / "Dev 1 + Dev 2" integration):
  input  -> RouteCalculationRequest (start/target lat-lon, draft, buffers)
  output -> RouteCalculationResponse with a REAL A*-searched GeoJSON
            LineString that avoids land, MPAs, and the IMBL buffer.

DO NOT treat the route returned here as navigationally safe. It is a
straight-line placeholder for wiring/testing only.
"""
import math
import uuid
from typing import Any, Dict

from fastapi import APIRouter

from app.models.schemas import RouteCalculationRequest, RouteCalculationResponse

router = APIRouter()


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Local copy of the haversine formula for this mock only. The canonical,
    production version belongs to Dev 1 in app/geospatial/distance.py and
    should be imported from there once available (Day 3 wiring).
    """
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlambda / 2) ** 2
    return 2 * r * math.asin(min(1.0, math.sqrt(a)))


def _mock_straight_line_route(req: RouteCalculationRequest) -> RouteCalculationResponse:
    distance_km = round(
        _haversine_km(req.start_lat, req.start_lon, req.target_lat, req.target_lon), 2
    )
    route_geojson: Dict[str, Any] = {
        "type": "Feature",
        "properties": {"mock": True, "note": "Dev 1's A* engine will replace this straight line."},
        "geometry": {
            "type": "LineString",
            "coordinates": [
                [req.start_lon, req.start_lat],
                [req.target_lon, req.target_lat],
            ],
        },
    }
    return RouteCalculationResponse(
        route_id=f"MOCK-ROUTE-{uuid.uuid4().hex[:8]}",
        total_distance_km=distance_km,
        total_distance_nautical_miles=round(distance_km * 0.539957, 2),
        estimated_duration_hours=round(distance_km / 12.0, 2),  # assumes ~12 km/h cruise
        waypoints_count=2,
        route_geojson=route_geojson,
        has_weather_penalties=False,
        min_distance_to_imbl_along_route_km=-1.0,  # -1 signals "not yet computed by Dev 1's engine"
        is_safe=False,  # conservatively False until the real A* + guardrails vet it
    )


@router.post("/route", response_model=RouteCalculationResponse, summary="[MOCK] A* route — Dev 1 owns real logic")
async def calculate_route(request: RouteCalculationRequest) -> RouteCalculationResponse:
    return _mock_straight_line_route(request)