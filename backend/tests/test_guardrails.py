try:
    import pytest
except ImportError:
    pass

from backend.app.agents.state import AgentState
from backend.app.agents.guardrails.weather_limits import weather_guardrail
from backend.app.agents.guardrails.boundary_rules import boundary_guardrail
from backend.app.agents.guardrails.symbolic_verifier import symbolic_verifier
from backend.app.agents.graph import orca_graph

def test_weather_guardrail_safe():
    weather_data = {
        "wave_height_m": 1.2,
        "swell_wave_height_m": 0.8,
        "wind_speed_knots": 14.0
    }
    is_valid, violations, is_emergency, msg = weather_guardrail.evaluate(weather_data)
    assert is_valid is True
    assert len(violations) == 0
    assert is_emergency is False

def test_weather_guardrail_critical_wave_height():
    weather_data = {
        "wave_height_m": 2.9, # Exceeds 2.5m ceiling
        "swell_wave_height_m": 1.5,
        "wind_speed_knots": 16.0
    }
    is_valid, violations, is_emergency, msg = weather_guardrail.evaluate(weather_data)
    assert is_valid is False
    assert is_emergency is True
    assert "CRITICAL SEA STATE" in violations[0]
    assert "2.9m" in msg

def test_weather_guardrail_critical_squall_wind():
    weather_data = {
        "wave_height_m": 1.5,
        "swell_wave_height_m": 1.0,
        "wind_speed_knots": 29.0 # Exceeds 25 kts ceiling
    }
    is_valid, violations, is_emergency, msg = weather_guardrail.evaluate(weather_data)
    assert is_valid is False
    assert is_emergency is True
    assert "CRITICAL SQUALL" in violations[0]

def test_boundary_guardrail_safe():
    boundary_metrics = {
        "distance_to_imbl_km": 12.4,
        "lookahead_breach_projected": False,
        "time_to_breach_minutes": None,
        "evasive_heading_deg": 270.0
    }
    is_valid, violations, is_emergency, msg, evasive = boundary_guardrail.evaluate(boundary_metrics)
    assert is_valid is True
    assert len(violations) == 0
    assert is_emergency is False

def test_boundary_guardrail_critical_proximity():
    boundary_metrics = {
        "distance_to_imbl_km": 1.35, # Violates 2.0 km critical threshold
        "lookahead_breach_projected": True,
        "time_to_breach_minutes": 4.2,
        "evasive_heading_deg": 265.0
    }
    is_valid, violations, is_emergency, msg, evasive = boundary_guardrail.evaluate(boundary_metrics)
    assert is_valid is False
    assert is_emergency is True
    assert "CRITICAL IMBL PROXIMITY" in violations[0]
    assert evasive == 265.0

def test_symbolic_verifier_end_to_end_emergency_trip():
    state: AgentState = {
        "session_id": "test-emergency-01",
        "raw_query": "அருகிலுள்ள மீன்பிடி மண்டலம் எங்கே?",
        "source_language": "ta",
        "translated_query": "Where is the nearest fishing zone?",
        "vessel_lat": 9.35,
        "vessel_lon": 79.44, # Dangerously close to IMBL
        "vessel_speed_knots": 12.0,
        "vessel_heading_deg": 90.0, # Heading directly East towards border
        "timestamp": "2026-09-01T10:00:00Z",
        "intents": ["pfz"],
        "target_destination": None,
        "weather_data": {"wave_height_m": 1.2, "wind_speed_knots": 10.0},
        "pfz_features": [],
        "boundary_metrics": {
            "distance_to_imbl_km": 1.2,
            "lookahead_breach_projected": True,
            "time_to_breach_minutes": 3.0,
            "warning_level": "CRITICAL",
            "evasive_heading_deg": 270.0
        },
        "route_data": {"is_safe": True, "min_distance_to_imbl_along_route_km": 1.2},
        "guardrail_passed": True,
        "safety_violations": [],
        "emergency_action_required": False,
        "emergency_advisory": None,
        "english_response": "",
        "localized_response": "",
        "audio_base64": None,
        "quick_replies": []
    }

    verified_state = symbolic_verifier.verify(state)
    assert verified_state["guardrail_passed"] is False
    assert verified_state["emergency_action_required"] is True
    assert len(verified_state["safety_violations"]) >= 1

def test_orca_graph_routes_to_emergency_override():
    # Simulate a scenario where vessel is within 1.5 km of IMBL
    state: AgentState = {
        "session_id": "sim-emergency-trip",
        "raw_query": "Go to PFZ",
        "source_language": "ta",
        "translated_query": "Go to PFZ",
        "vessel_lat": 9.35,
        "vessel_lon": 79.44,
        "vessel_speed_knots": 14.0,
        "vessel_heading_deg": 90.0,
        "timestamp": "2026-09-01T10:00:00Z",
        "intents": ["route"],
        "target_destination": None,
        "weather_data": None,
        "pfz_features": None,
        "boundary_metrics": None,
        "route_data": None,
        "guardrail_passed": True,
        "safety_violations": [],
        "emergency_action_required": False,
        "emergency_advisory": None,
        "english_response": "",
        "localized_response": "",
        "audio_base64": None,
        "quick_replies": []
    }

    result = orca_graph.invoke(state)

    # In the boundary agent, dist_km for (9.35, 79.44) relative to (9.35, 79.45) is ~1.1 km
    # This trips the critical proximity rule (< 2.0 km)
    assert result["guardrail_passed"] is False
    assert result["emergency_action_required"] is True
    assert "CRITICAL SAFETY OVERRIDE" in result["english_response"]
    assert "அவசர எச்சரிக்கை" in result["localized_response"] # Tamil Emergency keyword
    assert "Steer Bearing" in result["quick_replies"][0]


if __name__ == "__main__":
    print("=" * 60)
    print("Running Dev 2 Guardrails Tests (backend/tests/test_guardrails.py)")
    print("=" * 60)
    test_weather_guardrail_safe()
    print("  [PASS] test_weather_guardrail_safe")
    test_weather_guardrail_critical_wave_height()
    print("  [PASS] test_weather_guardrail_critical_wave_height")
    test_weather_guardrail_critical_squall_wind()
    print("  [PASS] test_weather_guardrail_critical_squall_wind")
    test_boundary_guardrail_safe()
    print("  [PASS] test_boundary_guardrail_safe")
    test_boundary_guardrail_critical_proximity()
    print("  [PASS] test_boundary_guardrail_critical_proximity")
    test_symbolic_verifier_end_to_end_emergency_trip()
    print("  [PASS] test_symbolic_verifier_end_to_end_emergency_trip")
    test_orca_graph_routes_to_emergency_override()
    print("  [PASS] test_orca_graph_routes_to_emergency_override")
    print("=" * 60)
    print("All Guardrail Tests Passed!")
    print("=" * 60)

