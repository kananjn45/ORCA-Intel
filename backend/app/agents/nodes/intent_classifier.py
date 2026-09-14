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
    ],
    "port": [
        "port", "harbor", "harbour", "jetty", "berth", "dock", "haven", "pier", "landing",
        "துறைமுகம்", "ஹார்பர்", "படகுகுழாம்", "தளவாடம்",
        "పోర్టు", "రేవు", "హార్బర్", "తీరప్రాంతం",
        "बंदरगाह", "गोदी", "पत्तन", "हार्बर"
    ]
}

COASTAL_LOCATIONS = {
    "hyderabad": {"name": "Hyderabad", "lat": 17.3850, "lon": 78.4867, "is_inland": True},
    "ஹைதராபாத்": {"name": "Hyderabad", "lat": 17.3850, "lon": 78.4867, "is_inland": True},
    "హైదరాబాద్": {"name": "Hyderabad", "lat": 17.3850, "lon": 78.4867, "is_inland": True},
    "हैदराबाद": {"name": "Hyderabad", "lat": 17.3850, "lon": 78.4867, "is_inland": True},

    "mumbai": {"name": "Mumbai", "lat": 18.95, "lon": 72.82},
    "bombay": {"name": "Mumbai", "lat": 18.95, "lon": 72.82},
    "மும்பை": {"name": "Mumbai", "lat": 18.95, "lon": 72.82},
    "मुंबई": {"name": "Mumbai", "lat": 18.95, "lon": 72.82},

    "chennai": {"name": "Chennai", "lat": 13.08, "lon": 80.27},
    "madras": {"name": "Chennai", "lat": 13.08, "lon": 80.27},
    "சென்னை": {"name": "Chennai", "lat": 13.08, "lon": 80.27},
    "चेन्नई": {"name": "Chennai", "lat": 13.08, "lon": 80.27},

    "machilipatnam": {"name": "Machilipatnam", "lat": 16.18, "lon": 81.15},
    "krishnapatnam": {"name": "Krishnapatnam", "lat": 14.25, "lon": 80.12},
    "kasimedu": {"name": "Chennai Kasimedu", "lat": 13.12, "lon": 80.29},
    "ennore": {"name": "Kamarajar Port Ennore", "lat": 13.26, "lon": 80.33},

    "rameswaram": {"name": "Rameswaram", "lat": 9.28, "lon": 79.31},
    "palk": {"name": "Palk Bay", "lat": 9.28, "lon": 79.31},
    "ராமேஸ்வரம்": {"name": "Rameswaram", "lat": 9.28, "lon": 79.31},
    "रामेश्वरम": {"name": "Rameswaram", "lat": 9.28, "lon": 79.31},

    "kochi": {"name": "Kochi", "lat": 9.96, "lon": 76.24},
    "cochin": {"name": "Kochi", "lat": 9.96, "lon": 76.24},
    "கொச்சி": {"name": "Kochi", "lat": 9.96, "lon": 76.24},
    "कोच्चि": {"name": "Kochi", "lat": 9.96, "lon": 76.24},

    "goa": {"name": "Goa", "lat": 15.40, "lon": 73.80},
    "mormugao": {"name": "Goa", "lat": 15.40, "lon": 73.80},
    "கோவா": {"name": "Goa", "lat": 15.40, "lon": 73.80},
    "गोवा": {"name": "Goa", "lat": 15.40, "lon": 73.80},

    "visakhapatnam": {"name": "Visakhapatnam", "lat": 17.68, "lon": 83.21},
    "vizag": {"name": "Visakhapatnam", "lat": 17.68, "lon": 83.21},
    "விசாகப்பட்டினம்": {"name": "Visakhapatnam", "lat": 17.68, "lon": 83.21},
    "विशाखापत्तनम": {"name": "Visakhapatnam", "lat": 17.68, "lon": 83.21},

    "porbandar": {"name": "Porbandar", "lat": 21.64, "lon": 69.60},
    "gujarat": {"name": "Gujarat Coast", "lat": 21.64, "lon": 69.60},
    "போர்பந்தர்": {"name": "Porbandar", "lat": 21.64, "lon": 69.60},
    "पोरबंदर": {"name": "Porbandar", "lat": 21.64, "lon": 69.60},

    "kanyakumari": {"name": "Kanyakumari", "lat": 8.08, "lon": 77.55},
    "கன்னியாகுமரி": {"name": "Kanyakumari", "lat": 8.08, "lon": 77.55},
    "कन्याकुमारी": {"name": "Kanyakumari", "lat": 8.08, "lon": 77.55},

    "tuticorin": {"name": "Tuticorin", "lat": 8.76, "lon": 78.13},
    "தூத்துக்குடி": {"name": "Tuticorin", "lat": 8.76, "lon": 78.13},

    "mangalore": {"name": "Mangalore", "lat": 12.87, "lon": 74.84},
    "மங்களூரு": {"name": "Mangalore", "lat": 12.87, "lon": 74.84},
    "मंगलुरु": {"name": "Mangalore", "lat": 12.87, "lon": 74.84},

    "kolkata": {"name": "Kolkata", "lat": 22.06, "lon": 88.06},
    "haldia": {"name": "Haldia", "lat": 22.06, "lon": 88.06},
    "கொல்கத்தா": {"name": "Kolkata", "lat": 22.06, "lon": 88.06},
    "कोलकाता": {"name": "Kolkata", "lat": 22.06, "lon": 88.06},

    "paradip": {"name": "Paradip", "lat": 20.31, "lon": 86.61},
    "odisha": {"name": "Odisha Coast", "lat": 20.31, "lon": 86.61},
}

def intent_classifier_node(state: AgentState) -> AgentState:
    """
    Deconstructs user queries (in English or regional dialects) into atomic domain intents.
    Extracts intents, named coastal location, and target coordinates.
    """
    query_raw = (state.get("raw_query") or "").lower()
    query_trans = (state.get("translated_query") or "").lower()
    combined_text = f"{query_raw} {query_trans}"

    # 1. Location Detection
    for loc_key, loc_info in COASTAL_LOCATIONS.items():
        if loc_key in combined_text:
            state["target_location_name"] = loc_info["name"]
            if not state.get("target_destination"):
                state["target_destination"] = {"lat": loc_info["lat"], "lon": loc_info["lon"]}
            break

    # 2. Intent Classification
    detected_intents: List[str] = []

    for intent_name, keywords in INTENT_KEYWORD_MAP.items():
        if any(kw in combined_text for kw in keywords):
            detected_intents.append(intent_name)

    # If no specific keyword matched, default to a standard composite advisory (weather + pfz + boundary)
    if not detected_intents:
        detected_intents = ["weather", "pfz", "boundary"]

    state["intents"] = detected_intents
    return state
