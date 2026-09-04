"""
app/api/v1/endpoints/navigation.py
Owner: Dev 1 (Geospatial & Math Engineer)
Real A* pathfinding logic using app/geospatial/astar.py + grid.py.
Computes navigable marine routes avoiding obstacles and buffers.
"""
import json
import logging
from pathlib import Path
from typing import Any, Dict, List, Optional
import uuid

from fastapi import APIRouter
from shapely.geometry import shape

from app.api.v1.endpoints.geofence import _get_imbl_geometry
from app.geospatial.astar import astar, path_to_geojson
from app.geospatial.distance import distance_to_geometry_km, haversine_km
from app.geospatial.grid import MarineGrid
from app.models.schemas import RouteCalculationRequest, RouteCalculationResponse

logger = logging.getLogger("orca.navigation")
router = APIRouter()

_COASTLINE_GEOMS: Optional[List[Any]] = None


def _get_coastline_obstacles() -> List[Any]:
    global _COASTLINE_GEOMS
    if _COASTLINE_GEOMS is not None:
        return _COASTLINE_GEOMS
    candidates = [
        Path(__file__).resolve().parent.parent.parent.parent / "data" / "boundaries" / "india_coastline.geojson",
        Path("data/boundaries/india_coastline.geojson"),
        Path("backend/data/boundaries/india_coastline.geojson"),
    ]
    _COASTLINE_GEOMS = []
    for p in candidates:
        if p.exists() and p.stat().st_size > 0:
            try:
                with open(p, "r", encoding="utf-8") as f:
                    data = json.load(f)
                for feat in data.get("features", []):
                    if "geometry" in feat:
                        geom = shape(feat["geometry"])
                        if geom and not geom.is_empty:
                            _COASTLINE_GEOMS.append(geom)
                if _COASTLINE_GEOMS:
                    return _COASTLINE_GEOMS
            except Exception:
                pass
    return _COASTLINE_GEOMS


def _fallback_straight_line_route(req: RouteCalculationRequest) -> RouteCalculationResponse:
    distance_km = round(
        haversine_km(req.start_lat, req.start_lon, req.target_lat, req.target_lon), 2
    )
    route_geojson: Dict[str, Any] = {
        "type": "Feature",
        "properties": {"fallback": True, "note": "Direct navigational vector"},
        "geometry": {
            "type": "LineString",
            "coordinates": [
                [req.start_lon, req.start_lat],
                [req.target_lon, req.target_lat],
            ],
        },
    }
    return RouteCalculationResponse(
        route_id=f"ORCA-ROUTE-{uuid.uuid4().hex[:8]}",
        total_distance_km=distance_km,
        total_distance_nautical_miles=round(distance_km * 0.539957, 2),
        estimated_duration_hours=round(distance_km / 12.0, 2),  # assumes ~12 km/h cruise
        waypoints_count=2,
        route_geojson=route_geojson,
        has_weather_penalties=False,
        min_distance_to_imbl_along_route_km=-1.0,
        is_safe=False,
    )


@router.post("/route", response_model=RouteCalculationResponse, summary="A* marine pathfinding route")
async def calculate_route(request: RouteCalculationRequest) -> RouteCalculationResponse:
    try:
        # Determine bounding envelope with buffer padding for maneuvering
        lat_pad = max(abs(request.target_lat - request.start_lat) * 0.2, 0.05)
        lon_pad = max(abs(request.target_lon - request.start_lon) * 0.2, 0.05)

        min_lat = min(request.start_lat, request.target_lat) - lat_pad
        max_lat = max(request.start_lat, request.target_lat) + lat_pad
        min_lon = min(request.start_lon, request.target_lon) - lon_pad
        max_lon = max(request.start_lon, request.target_lon) + lon_pad

        # Discretize into marine grid (~0.01 deg ~= 1.1 km cells)
        grid = MarineGrid(min_lat, max_lat, min_lon, max_lon, resolution_deg=0.01)

        # Rasterize coastline landmass obstacles
        for geom in _get_coastline_obstacles():
            grid.rasterize_obstacles(geom)

        start_node = grid.coord_to_node(request.start_lat, request.start_lon)
        goal_node = grid.coord_to_node(request.target_lat, request.target_lon)

        # Ensure start and goal are navigable
        grid.unblock(start_node)
        grid.unblock(goal_node)

        # Run Dev 1's A* pathfinding
        path = astar(grid, start_node, goal_node)
        route_geojson = path_to_geojson(grid, path)

        # Compute accurate distance along the waypoint path
        total_distance_km = 0.0
        min_imbl_dist = float("inf")
        imbl = _get_imbl_geometry()

        for i in range(len(path) - 1):
            lat1, lon1 = grid.node_to_coord(path[i])
            lat2, lon2 = grid.node_to_coord(path[i + 1])
            total_distance_km += haversine_km(lat1, lon1, lat2, lon2)

            if imbl is not None and not imbl.is_empty:
                d = distance_to_geometry_km(lat1, lon1, imbl)
                if d < min_imbl_dist:
                    min_imbl_dist = d

        # Check last waypoint IMBL proximity
        if path and imbl is not None and not imbl.is_empty:
            last_lat, last_lon = grid.node_to_coord(path[-1])
            d_last = distance_to_geometry_km(last_lat, last_lon, imbl)
            if d_last < min_imbl_dist:
                min_imbl_dist = d_last

        total_distance_km = round(total_distance_km, 2)
        duration_hours = round(total_distance_km / 12.0, 2)
        min_imbl_km = round(min_imbl_dist, 2) if min_imbl_dist != float("inf") else request.min_imbl_buffer_km
        is_safe = min_imbl_km >= request.min_imbl_buffer_km

        return RouteCalculationResponse(
            route_id=f"ORCA-ROUTE-{uuid.uuid4().hex[:8]}",
            total_distance_km=total_distance_km,
            total_distance_nautical_miles=round(total_distance_km * 0.539957, 2),
            estimated_duration_hours=duration_hours,
            waypoints_count=len(path),
            route_geojson=route_geojson,
            has_weather_penalties=False,
            min_distance_to_imbl_along_route_km=min_imbl_km,
            is_safe=is_safe,
        )
    except Exception as exc:
        logger.warning("A* routing falling back to direct trajectory: %s", exc)
        return _fallback_straight_line_route(request)