from typing import Any, Dict, List, Tuple

from pydantic import BaseModel, Field

class GeoJSONPoint(BaseModel):
    type: str = "Point"
    coordinates: Tuple[float, float]  # [lon, lat] — GeoJSON is lon,lat order!

class GeoJSONPolygon(BaseModel):
    type: str = "Polygon"
    coordinates: List[List[Tuple[float, float]]]

class GeoJSONLineString(BaseModel):
    type: str = "LineString"
    coordinates: List[Tuple[float, float]]

class GeoJSONFeature(BaseModel):
    type: str = "Feature"
    geometry: Dict[str, Any]
    properties: Dict[str, Any] = Field(default_factory=dict)

class GeoJSONFeatureCollection(BaseModel):
    type: str = "FeatureCollection"
    features: List[GeoJSONFeature] = Field(default_factory=list)

def build_polygon_geometry(center_lat: float, center_lon: float, radius_km: float, num_points: int = 8) -> Dict[str, Any]:
    """
    Builds an approximate circular polygon (in GeoJSON lon/lat order) around
    a centroid. Used by the mock PFZ generator to synthesize realistic-looking
    fishing zone footprints without needing real satellite chlorophyll rasters.
    """
    import math

    earth_radius_km = 6371.0
    coords: List[Tuple[float, float]] = []
    for i in range(num_points + 1):  # +1 to close the ring
        angle_rad = 2 * math.pi * (i % num_points) / num_points
        d_lat = (radius_km / earth_radius_km) * math.cos(angle_rad)
        d_lon = (radius_km / earth_radius_km) * math.sin(angle_rad) / math.cos(math.radians(center_lat))
        lat = center_lat + math.degrees(d_lat)
        lon = center_lon + math.degrees(d_lon)
        coords.append((round(lon, 6), round(lat, 6)))
    return {"type": "Polygon", "coordinates": [coords]}


def empty_feature_collection() -> Dict[str, Any]:
    return {"type": "FeatureCollection", "features": []}