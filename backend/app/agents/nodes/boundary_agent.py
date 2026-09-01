import math
from typing import Dict, Any
from backend.app.agents.state import AgentState

def boundary_agent_node(state: AgentState) -> AgentState:
    """
    Evaluates vessel proximity to the International Maritime Boundary Line (IMBL).
    Populates state['boundary_metrics'].
    """
    vessel_lat = state.get("vessel_lat", 9.28)
    vessel_lon = state.get("vessel_lon", 79.31)
    speed_knots = state.get("vessel_speed_knots", 8.0)
    heading_deg = state.get("vessel_heading_deg", 85.0)

    # Simplified IMBL reference line point in Palk Strait for standalone Day 1 testing
    # (Will link to Dev 1's Shapely geofence engine on Day 3)
    imbl_ref_lat = 9.35
    imbl_ref_lon = 79.45

    # Haversine distance approximation
    dlat = (imbl_ref_lat - vessel_lat) * 111.0
    dlon = (imbl_ref_lon - vessel_lon) * 111.0 * math.cos(math.radians(vessel_lat))
    dist_km = math.sqrt(dlat**2 + dlon**2)

    # 15-minute lookahead vector distance in km
    speed_kmh = speed_knots * 1.852
    travel_15min_km = speed_kmh * 0.25

    # Check if vessel heading is directly pointing towards boundary (between 45° and 135°)
    is_heading_towards_imbl = (45.0 <= heading_deg <= 135.0)
    breach_projected = is_heading_towards_imbl and (travel_15min_km >= (dist_km - 1.0))
    time_to_breach = round((dist_km / speed_kmh) * 60.0, 1) if (speed_kmh > 0.1 and is_heading_towards_imbl) else None

    # Calculate safe 180° evasive heading
    evasive_heading = round((heading_deg + 180.0) % 360.0, 1)

    if dist_km < 2.0 or (breach_projected and time_to_breach and time_to_breach <= 5.0):
        warning_level = "CRITICAL"
    elif dist_km < 5.0 or breach_projected:
        warning_level = "WARNING"
    elif dist_km < 10.0:
        warning_level = "ADVISORY"
    else:
        warning_level = "SAFE"

    state["boundary_metrics"] = {
        "distance_to_imbl_km": round(dist_km, 2),
        "nearest_imbl_point": {"lat": imbl_ref_lat, "lon": imbl_ref_lon},
        "lookahead_breach_projected": breach_projected,
        "time_to_breach_minutes": time_to_breach,
        "warning_level": warning_level,
        "evasive_heading_deg": evasive_heading
    }

    return state
