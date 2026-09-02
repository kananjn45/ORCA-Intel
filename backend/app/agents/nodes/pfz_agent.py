import math
from datetime import datetime, timedelta
from typing import List, Dict, Any
from backend.app.agents.state import AgentState

def _calculate_haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Computes great-circle distance in kilometers."""
    r = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2.0)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2.0)**2
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return r * c

def _calculate_bearing(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Computes initial compass bearing in degrees."""
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dlambda = math.radians(lon2 - lon1)
    y = math.sin(dlambda) * math.cos(phi2)
    x = math.cos(phi1) * math.sin(phi2) - math.sin(phi1) * math.cos(phi2) * math.cos(dlambda)
    return (math.degrees(math.atan2(y, x)) + 360.0) % 360.0

def pfz_agent_node(state: AgentState) -> AgentState:
    """
    Extracts high-yield Potential Fishing Zones (PFZs) based on chlorophyll and SST fronts.
    Populates state['pfz_features'] and sets state['target_destination'].
    """
    vessel_lat = state.get("vessel_lat", 9.28)
    vessel_lon = state.get("vessel_lon", 79.31)

    # Mock high-density PFZ zones (will connect to Dev 3's INCOIS parser on Day 3)
    candidate_pfzs: List[Dict[str, Any]] = [
        {
            "pfz_id": "PFZ-TN-2026-04",
            "sector_name": "Palk Bay East Front",
            "centroid": {"lat": 9.42, "lon": 79.52},
            "chlorophyll_mg_m3": 1.45,
            "sst_gradient_celsius": 0.85,
            "depth_m": 22.0,
            "valid_until": (datetime.utcnow() + timedelta(hours=18)).isoformat(),
            "geojson_geometry": {
                "type": "Polygon",
                "coordinates": [[[79.48, 9.38], [79.56, 9.38], [79.56, 9.46], [79.48, 9.46], [79.48, 9.38]]]
            }
        },
        {
            "pfz_id": "PFZ-TN-2026-07",
            "sector_name": "Rameswaram South Shelf",
            "centroid": {"lat": 9.18, "lon": 79.35},
            "chlorophyll_mg_m3": 1.15,
            "sst_gradient_celsius": 0.65,
            "depth_m": 18.0,
            "valid_until": (datetime.utcnow() + timedelta(hours=12)).isoformat(),
            "geojson_geometry": {
                "type": "Polygon",
                "coordinates": [[[79.30, 9.12], [79.40, 9.12], [79.40, 9.24], [79.30, 9.24], [79.30, 9.12]]]
            }
        }
    ]

    # Calculate distance and bearing relative to current vessel position
    for pfz in candidate_pfzs:
        c_lat = pfz["centroid"]["lat"]
        c_lon = pfz["centroid"]["lon"]
        pfz["distance_km"] = round(_calculate_haversine_distance(vessel_lat, vessel_lon, c_lat, c_lon), 1)
        pfz["bearing_deg"] = round(_calculate_bearing(vessel_lat, vessel_lon, c_lat, c_lon), 0)

    # Sort by nearest distance
    candidate_pfzs.sort(key=lambda x: x["distance_km"])
    state["pfz_features"] = candidate_pfzs

    # If no target destination was explicitly provided by user, lock nearest PFZ
    if not state.get("target_destination") and candidate_pfzs:
        state["target_destination"] = candidate_pfzs[0]["centroid"]

    return state
