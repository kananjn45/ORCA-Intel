from typing import Dict, Any
from backend.app.agents.state import AgentState

def weather_agent_node(state: AgentState) -> AgentState:
    """
    Evaluates marine weather and sea state conditions at the vessel's current coordinate.
    Populates state['weather_data'].
    """
    vessel_lat = state.get("vessel_lat", 9.28)
    vessel_lon = state.get("vessel_lon", 79.31)

    # Standard marine physics mock fixture (will link to Dev 3's Open-Meteo client on Day 3)
    wave_height_m = 1.3
    wind_speed_knots = 12.5
    swell_wave_height_m = 1.1
    wave_direction_deg = 135.0
    wind_direction_deg = 120.0
    sst_celsius = 28.6
    sea_state_code = 3 # Moderate sea state (Beaufort 3-4)

    is_safe = (wave_height_m <= 2.5 and wind_speed_knots <= 25.0)

    weather_payload: Dict[str, Any] = {
        "location": {"lat": vessel_lat, "lon": vessel_lon},
        "wave_height_m": wave_height_m,
        "swell_wave_height_m": swell_wave_height_m,
        "wave_direction_deg": wave_direction_deg,
        "wind_speed_knots": wind_speed_knots,
        "wind_direction_deg": wind_direction_deg,
        "sea_surface_temp_celsius": sst_celsius,
        "sea_state_code": sea_state_code,
        "is_safe_for_small_craft": is_safe,
        "summary": "Moderate sea conditions. Wave height 1.3m, wind speed 12.5 kts. Safe for artisanal and mechanized crafts."
    }

    state["weather_data"] = weather_payload
    return state
