import math
from typing import Dict, Any, Optional

try:
    from app.agents.state import AgentState
    from app.geospatial.distance import distance_to_geometry_km, haversine_km
    from app.geospatial.geofence import calculate_lookahead
    from app.api.v1.endpoints.geofence import _get_imbl_geometry
except ImportError:
    from app.agents.state import AgentState
    from app.geospatial.distance import distance_to_geometry_km, haversine_km
    from app.geospatial.geofence import calculate_lookahead
    from app.api.v1.endpoints.geofence import _get_imbl_geometry


def boundary_agent_node(state: AgentState) -> AgentState:
    """
    Evaluates vessel proximity to the International Maritime Boundary Line (IMBL).
    Powered by Dev 1's geodesic distance calculations and 15-minute lookahead vector engine.
    Populates state['boundary_metrics'].
    """
    vessel_lat = state.get("vessel_lat", 9.28)
    vessel_lon = state.get("vessel_lon", 79.31)
    speed_knots = state.get("vessel_speed_knots", 8.0)
    heading_deg = state.get("vessel_heading_deg", 85.0)

    imbl = _get_imbl_geometry()

    if imbl is not None and not imbl.is_empty:
        # 1. High-precision metric distance to real IMBL polyline
        real_dist = distance_to_geometry_km(vessel_lat, vessel_lon, imbl)
        # Check proximity to critical Palk Strait reference crossing (9.35, 79.45)
        corridor_dist = haversine_km(vessel_lat, vessel_lon, 9.35, 79.45)
        dist_km = round(min(real_dist, corridor_dist), 2)

        # 2. 15-minute geodesic speed/drift lookahead vector projection
        lookahead = calculate_lookahead(vessel_lat, vessel_lon, speed_knots, heading_deg, imbl)
        speed_kmh = speed_knots * 1.852
        travel_15min_km = speed_kmh * 0.25
        is_heading_towards_imbl = (45.0 <= heading_deg <= 135.0)
        breach_projected = lookahead.intersects_boundary or (is_heading_towards_imbl and travel_15min_km >= max(0.1, dist_km - 1.0))
        time_to_breach = round((dist_km / speed_kmh) * 60.0, 1) if (speed_kmh > 0.1 and breach_projected) else None

        # Nearest reference coordinate
        from shapely.geometry import Point
        from shapely.ops import nearest_points
        v_pt = Point(vessel_lon, vessel_lat)
        n_pt, _ = nearest_points(imbl, v_pt)
        nearest_coord = {"lat": round(n_pt.y, 4), "lon": round(n_pt.x, 4)}
    else:
        # Fallback approximation near Palk Strait
        imbl_ref_lat = 9.35
        imbl_ref_lon = 79.45
        dist_km = round(haversine_km(vessel_lat, vessel_lon, imbl_ref_lat, imbl_ref_lon), 2)
        speed_kmh = speed_knots * 1.852
        travel_15min_km = speed_kmh * 0.25
        is_heading_towards_imbl = (45.0 <= heading_deg <= 135.0)
        breach_projected = is_heading_towards_imbl and (travel_15min_km >= (dist_km - 1.0))
        time_to_breach = round((dist_km / speed_kmh) * 60.0, 1) if (speed_kmh > 0.1 and is_heading_towards_imbl) else None
        nearest_coord = {"lat": imbl_ref_lat, "lon": imbl_ref_lon}

    # Safe 180° return vector course
    evasive_heading = round((heading_deg + 180.0) % 360.0, 1)

    # Classify non-negotiable warning levels
    if dist_km < 2.0 or (breach_projected and time_to_breach and time_to_breach <= 5.0):
        warning_level = "CRITICAL"
        state["emergency_advisory"] = (
            f"IMBL BREACH IMMINENT! Distance to border is {dist_km:.1f} km. "
            f"15-min trajectory intersects foreign maritime territory."
        )
    elif dist_km < 5.0 or breach_projected:
        warning_level = "WARNING"
    elif dist_km < 10.0:
        warning_level = "ADVISORY"
    else:
        warning_level = "SAFE"

    state["boundary_metrics"] = {
        "distance_to_imbl_km": dist_km,
        "nearest_imbl_point": nearest_coord,
        "lookahead_breach_projected": breach_projected,
        "time_to_breach_minutes": time_to_breach,
        "warning_level": warning_level,
        "evasive_heading_deg": evasive_heading
    }

    return state
