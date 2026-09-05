import re
from typing import List
from app.agents.state import AgentState

# Multilingual keyword mappings for resilient intent parsing
INTENT_KEYWORD_MAP = {
    "weather": [
        "weather", "wind", "wave", "swell", "sea", "storm", "cyclone", "rain", "squall", "rough",
        "வானிலை", "காற்று", "அலை", "புயல்", "மழை",
        "వాతావరణం", "గాలి", "అలలు", "తుఫాను", "వర్షం",
        "मौसम", "हवा", "लहर", "तूफान", "बारिश"
    ],
    "pfz": [
        "fish", "pfz", "catch", "tuna", "zone", "spot", "chlorophyll", "ocean color", "shoal", "yield",
        "மீன்", "மீன்பிடி", "மண்டலம்",
        "చేపలు", "వేట", "ప్రాంతం",
        "मछली", "पकड़", "क्षेत्र"
    ],
    "boundary": [
        "border", "imbl", "boundary", "sri lanka", "pakistan", "cross", "danger", "distance", "limit",
        "எல்லை", "இலங்கை", "தூரம்",
        "సరిహద్దు", "దూరం",
        "सीमा", "दूरी"
    ],
    "route": [
        "route", "navigate", "path", "course", "waypoint", "direction", "reach", "go to", "steer",
        "பாதை", "வழி", "செல்ல",
        "మార్గం", "దిశ",
        "मार्ग", "रास्ता", "दिशा"
    ]
}

def intent_classifier_node(state: AgentState) -> AgentState:
    """
    Deconstructs user queries (in English or regional dialects) into atomic domain intents.
    Extracts intents and populates state['intents'].
    """
    query_raw = (state.get("raw_query") or "").lower()
    query_trans = (state.get("translated_query") or "").lower()
    combined_text = f"{query_raw} {query_trans}"

    detected_intents: List[str] = []

    for intent_name, keywords in INTENT_KEYWORD_MAP.items():
        if any(kw in combined_text for kw in keywords):
            detected_intents.append(intent_name)

    # If no specific keyword matched, default to a standard composite advisory (weather + pfz + boundary)
    if not detected_intents:
        detected_intents = ["weather", "pfz", "boundary"]

    state["intents"] = detected_intents
    return state
