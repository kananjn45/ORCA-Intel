try:
    import pytest
except ImportError:
    pass

from backend.app.agents.state import AgentState
from backend.app.agents.nodes.intent_classifier import intent_classifier_node
from backend.app.agents.nodes.weather_agent import weather_agent_node
from backend.app.agents.nodes.pfz_agent import pfz_agent_node
from backend.app.agents.nodes.boundary_agent import boundary_agent_node
from backend.app.agents.nodes.routing_agent import routing_agent_node
from backend.app.agents.nodes.synthesizer import response_synthesizer_node
from backend.app.agents.graph import orca_graph

def test_intent_classifier_english():
    state: AgentState = {
        "session_id": "s-1",
        "raw_query": "Is there any storm warning? Find good fish catch zone.",
        "source_language": "en",
        "translated_query": "Is there any storm warning? Find good fish catch zone.",
        "vessel_lat": 9.28,
        "vessel_lon": 79.31,
        "vessel_speed_knots": 8.0,
        "vessel_heading_deg": 85.0,
        "timestamp": "2026-08-28T00:00:00Z",
        "intents": [],
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
    updated = intent_classifier_node(state)
    assert "weather" in updated["intents"]
    assert "pfz" in updated["intents"]

def test_intent_classifier_tamil():
    state: AgentState = {
        "session_id": "s-2",
        "raw_query": "புயல் எச்சரிக்கை உள்ளதா? மீன்பிடி மண்டலம் எங்கே?",
        "source_language": "ta",
        "translated_query": "",
        "vessel_lat": 9.28,
        "vessel_lon": 79.31,
        "vessel_speed_knots": 8.0,
        "vessel_heading_deg": 85.0,
        "timestamp": "2026-08-28T00:00:00Z",
        "intents": [],
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
    updated = intent_classifier_node(state)
    assert "weather" in updated["intents"]
    assert "pfz" in updated["intents"]

def test_full_orca_graph_execution():
    initial_state: AgentState = {
        "session_id": "test-session-001",
        "raw_query": "வானிலை எப்படி உள்ளது? சிறந்த PFZ எங்கே?",
        "source_language": "ta",
        "translated_query": "How is weather? Where is best PFZ?",
        "vessel_lat": 9.285,
        "vessel_lon": 79.312,
        "vessel_speed_knots": 8.4,
        "vessel_heading_deg": 82.0,
        "timestamp": "2026-08-28T00:00:00Z",
        "intents": [],
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

    final_state = orca_graph.invoke(initial_state)

    # Validate state mutations across all nodes
    assert final_state["weather_data"] is not None
    assert final_state["weather_data"]["wave_height_m"] == 1.3
    assert len(final_state["pfz_features"]) > 0
    assert final_state["boundary_metrics"] is not None
    assert final_state["route_data"] is not None
    assert final_state["english_response"] != ""
    assert final_state["localized_response"] != ""
    assert len(final_state["quick_replies"]) > 0
