"""Geospatial distance and bearing utilities used by the ORCA navigation engine."""
from __future__ import annotations

import math
from typing import Iterable, Sequence, Tuple

from pyproj import Geod, Transformer
from shapely.geometry.base import BaseGeometry
from shapely.ops import transform

EARTH_RADIUS_KM = 6371.0088
GEOD = Geod(ellps="WGS84")


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance between two WGS84 coordinates in kilometres."""
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlambda / 2) ** 2
    return 2 * EARTH_RADIUS_KM * math.asin(math.sqrt(min(1.0, a)))


def initial_bearing_deg(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Initial true bearing from point 1 to point 2, clockwise from north."""
    azimuth, _, _ = GEOD.inv(lon1, lat1, lon2, lat2)
    return azimuth % 360.0


def destination_point(lat: float, lon: float, distance_km: float, bearing_deg: float) -> Tuple[float, float]:
    """Move from a WGS84 point along a geodesic and return (lat, lon)."""
    lon2, lat2, _ = GEOD.fwd(lon, lat, bearing_deg, distance_km * 1000.0)
    return lat2, lon2


def cross_track_distance_km(
    point: Sequence[float],
    start: Sequence[float],
    end: Sequence[float],
) -> float:
    """Approximate cross-track distance from a point to a great-circle segment.

    Inputs are (lat, lon). The result is unsigned and is useful for proximity
    checks; it is not intended to replace a full geodesic line-intersection
    calculation for legal boundary adjudication.
    """
    lat1, lon1 = start
    lat2, lon2 = end
    lat3, lon3 = point
    d13 = haversine_km(lat1, lon1, lat3, lon3) / EARTH_RADIUS_KM
    theta13 = math.radians(initial_bearing_deg(lat1, lon1, lat3, lon3))
    theta12 = math.radians(initial_bearing_deg(lat1, lon1, lat2, lon2))
    value = math.sin(d13) * math.sin(theta13 - theta12)
    return abs(math.asin(max(-1.0, min(1.0, value))) * EARTH_RADIUS_KM)


def _local_metric_transformers(lat: float, lon: float):
    """Create a local azimuthal-equidistant projection centred on a point."""
    crs = f"+proj=aeqd +lat_0={lat} +lon_0={lon} +datum=WGS84 +units=m +no_defs"
    forward = Transformer.from_crs("EPSG:4326", crs, always_xy=True)
    inverse = Transformer.from_crs(crs, "EPSG:4326", always_xy=True)
    return forward, inverse


def distance_to_geometry_km(lat: float, lon: float, geometry: BaseGeometry) -> float:
    """Shortest metric distance from a WGS84 point to a geometry, in km.

    The geometry is expected to use EPSG:4326 coordinates. A local metric
    projection is used so callers never accidentally interpret degrees as km.
    """
    if geometry is None or geometry.is_empty:
        return math.inf
    forward, _ = _local_metric_transformers(lat, lon)
    point_xy = forward.transform(lon, lat)
    metric_geometry = transform(forward.transform, geometry)
    from shapely.geometry import Point
    return Point(*point_xy).distance(metric_geometry) / 1000.0
