import uuid
from typing import Dict, Any
from backend.app.agents.state import AgentState

def routing_agent_node(state: AgentState) -> AgentState:
    """
    Computes a navigable sea route from vessel to target destination/PFZ.
    Populates state['route_data'].
    """
    vessel_lat = state.get("vessel_lat", 9.28)
    vessel_lon = state.get("vessel_lon", 79.31)
    target = state.get("target_destination")

    if not target and state.get("pfz_features"):
        target = state["pfz_features"][0]["centroid"]

    if target:
        t_lat = target["lat"]
        t_lon = target["lon"]

        # 3-segment intermediate waypoint course for Day 1 mock
        # (Will link to Dev 1's A* NetworkX pathfinder on Day 3)
        mid_lat = round((vessel_lat + t_lat) / 2.0, 4)
        mid_lon = round((vessel_lon + t_lon) / 2.0, 4)

        waypoints = [
            [round(vessel_lon, 4), round(vessel_lat, 4)],
            [mid_lon, mid_lat],
            [round(t_lon, 4), round(t_lat, 4)]
        ]

        # Rough distance estimate in km
        total_dist_km = 14.8
        duration_hours = round(total_dist_km / (8.0 * 1.852), 2) # At 8 knots

        state["route_data"] = {
            "route_id": f"route-{uuid.uuid4().hex[:8]}",
            "total_distance_km": total_dist_km,
            "total_distance_nautical_miles": round(total_dist_km * 0.539957, 2),
            "estimated_duration_hours": duration_hours,
            "waypoints_count": len(waypoints),
            "has_weather_penalties": False,
            "min_distance_to_imbl_along_route_km": 6.2,
            "is_safe": True,
            "route_geojson": {
                "type": "Feature",
                "properties": {"name": "Safe Marine Course to PFZ"},
                "geometry": {
                    "type": "LineString",
                    "coordinates": waypoints
                }
            }
        }

    return state
