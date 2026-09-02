from typing import TypedDict, List, Dict, Any, Optional

class AgentState(TypedDict):
    """
    Central shared state object passed across all nodes in the LangGraph multi-agent loop.
    All worker agents read from and mutate specific keys in this dictionary.
    """
    # 1. Session & Multilingual Input Context
    session_id: str
    raw_query: str                  # Original query text (e.g. in Tamil / Telugu / Hindi)
    source_language: str            # 'ta' (Tamil), 'te' (Telugu), 'hi' (Hindi), 'bn', 'gu', 'en'
    translated_query: str           # Standardized English query for downstream agent reasoning
    
    # 2. Real-Time Vessel Telemetry Context
    vessel_lat: float               # Current vessel Latitude (-90.0 to 90.0)
    vessel_lon: float               # Current vessel Longitude (-180.0 to 180.0)
    vessel_speed_knots: float       # Vessel ground speed in knots
    vessel_heading_deg: float       # Vessel magnetic compass heading (0.0 to 360.0 degrees)
    timestamp: str                  # ISO format timestamp of telemetry fix
    
    # 3. Intent Classification & Extracted Slots
    intents: List[str]              # e.g., ["weather", "pfz", "boundary", "route"]
    target_destination: Optional[Dict[str, float]] # Target Lat/Lon if user requested specific spot
    
    # 4. Specialized Worker Agent Outputs
    weather_data: Optional[Dict[str, Any]]         # Sea state, wave height, swell, wind speed
    pfz_features: Optional[List[Dict[str, Any]]]   # High-catch Potential Fishing Zone candidates
    boundary_metrics: Optional[Dict[str, Any]]     # IMBL distance, 15-min lookahead vector breach status
    route_data: Optional[Dict[str, Any]]           # A* computed GeoJSON navigation LineString
    
    # 5. Deterministic Symbolic Guardrail Verification Flags
    guardrail_passed: bool                         # True if all deterministic safety invariants hold
    safety_violations: List[str]                   # Specific safety threshold breach explanations
    emergency_action_required: bool                # Flag triggering urgent alarm & evasive action
    emergency_advisory: Optional[str]              # Deterministic evasive action message
    
    # 6. Response Synthesis & Output Delivery
    english_response: str                          # Standard English synthesized advice
    localized_response: str                        # Translated advice in user's native dialect
    audio_base64: Optional[str]                    # Base64 encoded TTS audio clip
    quick_replies: List[str]                       # Suggested quick-action prompt chips for mobile UI
