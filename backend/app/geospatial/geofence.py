"""Boundary proximity and 15-minute vessel lookahead calculations."""
from __future__ import annotations

from dataclasses import dataclass, asdict
import math
from typing import Any

from shapely.geometry import LineString, Point
from pyproj import Geod

from .distance import destination_point, distance_to_geometry_km

KNOT_TO_KMH = 1.852
LOOKAHEAD_MINUTES = 15
GEOD = Geod(ellps="WGS84")


@dataclass(frozen=True)
class LookaheadResult:
    start: dict[str, float]
    end: dict[str, float]
    distance_km: float
    bearing_deg: float
    duration_minutes: float
    intersects_boundary: bool

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def _geodesic_line(lat: float, lon: float, bearing_deg: float, distance_km: float, samples: int = 16) -> LineString:
    """Approximate a geodesic with WGS84 points for Shapely intersection tests."""
    if distance_km <= 0:
        return LineString([(lon, lat), (lon, lat)])
    points = [(lon, lat)]
    for i in range(1, samples + 1):
        d = distance_km * i / samples
        p_lat, p_lon = destination_point(lat, lon, d, bearing_deg)
        points.append((p_lon, p_lat))
    return LineString(points)


def lookahead_distance_km(speed_knots: float, minutes: float = LOOKAHEAD_MINUTES) -> float:
    if speed_knots < 0:
        raise ValueError("speed_knots cannot be negative")
    return speed_knots * KNOT_TO_KMH * (minutes / 60.0)


def calculate_lookahead(
    lat: float,
    lon: float,
    speed_knots: float,
    heading_deg: float,
    boundary_geometry=None,
    *,
    minutes: float = LOOKAHEAD_MINUTES,
) -> LookaheadResult:
    """Return the vessel's projected 15-minute track and boundary collision."""
    distance_km = lookahead_distance_km(speed_knots, minutes)
    end_lat, end_lon = destination_point(lat, lon, distance_km, heading_deg)
    track = _geodesic_line(lat, lon, heading_deg, distance_km)
    intersects = bool(boundary_geometry is not None and track.intersects(boundary_geometry))
    return LookaheadResult(
        start={"lat": lat, "lon": lon},
        end={"lat": end_lat, "lon": end_lon},
        distance_km=distance_km,
        bearing_deg=heading_deg % 360.0,
        duration_minutes=minutes,
        intersects_boundary=intersects,
    )


def boundary_proximity_km(lat: float, lon: float, boundary_geometry) -> float:
    """Return metric distance to a boundary/obstacle geometry in km."""
    return distance_to_geometry_km(lat, lon, boundary_geometry)


def point_inside(lat: float, lon: float, polygon_geometry) -> bool:
    """Boundary-inclusive point test (covers, not contains)."""
    return bool(polygon_geometry.covers(Point(lon, lat)))
