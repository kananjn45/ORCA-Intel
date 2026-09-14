import math
from typing import Dict, Any
from app.agents.state import AgentState

# Multilingual localized template dictionary for zero-latency deterministic synthesis
LOCALIZED_TEMPLATES = {
    "ta": {
        "safe": "வானிலை சீராக உள்ளது (அலை: {wave} மீ, காற்று: {wind} நாட்ஸ்). சிறந்த மீன்பிடி மண்டலம் {pfz_id} {dist} கி.மீ தொலைவில் உள்ளது. பாதுகாப்பான பாதை வரைபடத்தில் காட்டப்பட்டுள்ளது.",
        "emergency": "எச்சரிக்கை! நீங்கள் எல்லைக்கு அருகில் உள்ளீர்கள் ({dist} கி.மீ). உடனடியாக {evasive}° திசையில் திரும்பவும்!",
        "weather_danger": "வானிலை எச்சரிக்கை! அலை உயரம் {wave} மீ மற்றும் காற்று {wind} நாட்ஸ். கடலுக்குச் செல்ல வேண்டாம்."
    },
    "te": {
        "safe": "వాతావరణం అనుకూలంగా ఉంది (అలల ఎత్తు: {wave} మీ, గాలి: {wind} నాట్స్). ఉత్తమ చేపల వేట ప్రాంతం {pfz_id} {dist} కి.మీ దూరంలో ఉంది. సురక్షిత మార్గం మ్యాప్‌లో చూపబడింది.",
        "emergency": "హెచ్చరిక! మీరు అంతర్జాతీయ సరిహద్దుకు దగ్గరగా ఉన్నారు ({dist} కి.మీ). వెంటనే {evasive}° దిశలో మళ్లండి!",
        "weather_danger": "తుఫాను హెచ్చరిక! సముద్రంలో అలలు {wave} మీ ఉన్నాయి. వెంటనే సురక్షిత తీరానికి చేరుకోండి."
    },
    "hi": {
        "safe": "मौसम सुरक्षित है (लहर: {wave} मीटर, हवा: {wind} समुद्री मील)। इष्टतम मछली पकड़ने का क्षेत्र {pfz_id} {dist} किमी दूर (दिशा {bearing}°) है। सुरक्षित मार्ग मानचित्र पर लोड किया गया है।",
        "emergency": "सावधान! आप समुद्री सीमा के अत्यंत निकट हैं ({dist} किमी)। तुरंत {evasive}° दिशा में मुड़ें!",
        "weather_danger": "खराब मौसम चेतावनी! लहरें {wave} मीटर और हवा {wind} समुद्री मील है। बंदरगाह पर वापस लौटें।"
    },
    "bn": {
        "safe": "সমুদ্রের আবহাওয়া শান্ত (ঢেউ: {wave} মিটার, বাতাস: {wind} নট)। সেরা মাছ ধরার এলাকা {pfz_id} {dist} কিমি দূরে। নিরাপদ পথ মানচিত্রে দেখানো হয়েছে।",
        "emergency": "সতর্কতা! আপনি আন্তর্জাতিক সীমান্তের কাছে ({dist} কিমি)। অবিলম্বে {evasive}° দিকে ঘুরে যান!",
        "weather_danger": "ঝড়ের সতর্কতা! সমুদ্র উত্তাল। অবিলম্বে তীরে ফিরে আসুন।"
    },
    "gu": {
        "safe": "દરિયાઈ હવામાન અનુકૂળ છે (મોજાં: {wave} મીટર, પવન: {wind} નોટ્સ). શ્રેષ્ઠ માછીમારી ક્ષેત્ર {pfz_id} {dist} કિમી દૂર છે. સલામત માર્ગ નકશા પર દર્શાવેલ છે.",
        "emergency": "ચેતવણી! તમે સરહદની નજીક છો ({dist} કિમી). તરત જ {evasive}° દિશામાં વળો!",
        "weather_danger": "તોફાનની ચેતવણી! મોજાં ઊંચા છે. સલામત બંદરે પાછા ફરો."
    },
    "en": {
        "safe": "Sea state is calm (Wave: {wave}m, Wind: {wind} kts). High-catch Potential Fishing Zone {pfz_id} is located {dist} km away (Bearing {bearing}°). Safe navigation route loaded on map.",
        "emergency": "CRITICAL GEOFENCE ALERT! Vessel is within {dist} km of the IMBL. Turn craft to evasive bearing {evasive}° immediately!",
        "weather_danger": "WEATHER HAZARD! Significant wave height {wave}m and wind {wind} kts exceeds safe operating limits. Return to harbor."
    }
}

MAJOR_INDIAN_PORTS = [
    {"name": "Chennai Kasimedu Fishing Harbor", "state": "Tamil Nadu", "lat": 13.1256, "lon": 80.2974, "type": "Fishing Jetty"},
    {"name": "Chennai Port", "state": "Tamil Nadu", "lat": 13.0850, "lon": 80.2950, "type": "Major Commercial Port"},
    {"name": "Kamarajar Port (Ennore)", "state": "Tamil Nadu", "lat": 13.2600, "lon": 80.3300, "type": "Commercial Deepwater"},
    {"name": "Rameswaram Fishing Harbor", "state": "Tamil Nadu", "lat": 9.2881, "lon": 79.3129, "type": "Fishing Harbor"},
    {"name": "Dhanushkodi Pier", "state": "Tamil Nadu", "lat": 9.1764, "lon": 79.4182, "type": "Coastal Pier"},
    {"name": "Tuticorin (V.O.C.) Port", "state": "Tamil Nadu", "lat": 8.7642, "lon": 78.1348, "type": "Major Port"},
    {"name": "Nagapattinam Harbor", "state": "Tamil Nadu", "lat": 10.7672, "lon": 79.8428, "type": "Intermediate Port"},
    {"name": "Kanyakumari Harbor", "state": "Tamil Nadu", "lat": 8.0883, "lon": 77.5385, "type": "Coastal Harbor"},
    {"name": "Machilipatnam Port", "state": "Andhra Pradesh", "lat": 16.1800, "lon": 81.1500, "type": "Commercial Harbor"},
    {"name": "Krishnapatnam Port", "state": "Andhra Pradesh", "lat": 14.2500, "lon": 80.1200, "type": "Deepwater Port"},
    {"name": "Visakhapatnam Port", "state": "Andhra Pradesh", "lat": 17.6975, "lon": 83.2981, "type": "Major Naval & Cargo Port"},
    {"name": "Paradeep Port", "state": "Odisha", "lat": 20.2644, "lon": 86.6710, "type": "Major Deepwater Port"},
    {"name": "Kochi (Cochin) Harbor", "state": "Kerala", "lat": 9.9312, "lon": 76.2673, "type": "Major Port"},
    {"name": "Mangalore Old Port", "state": "Karnataka", "lat": 12.8617, "lon": 74.8354, "type": "Major Port"},
    {"name": "Mormugao Port (Goa)", "state": "Goa", "lat": 15.4100, "lon": 73.8000, "type": "Major Harbor"},
    {"name": "Mumbai Port & JNPT", "state": "Maharashtra", "lat": 18.9500, "lon": 72.8200, "type": "Major International Port"},
    {"name": "Porbandar Harbor", "state": "Gujarat", "lat": 21.6417, "lon": 69.6293, "type": "All-Weather Harbor"},
]

def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2.0) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2.0) ** 2
    return 2.0 * r * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))

def response_synthesizer_node(state: AgentState) -> AgentState:
    """
    Synthesizes concise, actionable marine advice in English and user's chosen regional language.
    Populates state['english_response'], state['localized_response'], and state['quick_replies'].
    """
    lang = state.get("source_language", "ta")
    if lang not in LOCALIZED_TEMPLATES:
        lang = "en"

    # 1. Emergency Case
    if state.get("emergency_action_required"):
        b_metrics = state.get("boundary_metrics") or {}
        dist = b_metrics.get("distance_to_imbl_km", 1.8)
        evasive = b_metrics.get("evasive_heading_deg", 270.0)

        en_text = f"CRITICAL GEOFENCE ALERT! Vessel is within {dist} km of the IMBL. Turn craft to evasive bearing {evasive}° immediately!"
        loc_text = LOCALIZED_TEMPLATES[lang]["emergency"].format(dist=dist, evasive=evasive)

        state["english_response"] = en_text
        state["localized_response"] = loc_text
        state["quick_replies"] = ["Emergency Return Course", "Nearest Safe Harbor", "Mute Alarm"]
        return state

    # 2. Check Port & Harbor Inquiries
    raw_query = (state.get("raw_query") or "").lower()
    trans_query = (state.get("translated_query") or "").lower()
    combined_q = f"{raw_query} {trans_query}"

    is_port_inquiry = (
        "port" in state.get("intents", [])
        or any(kw in combined_q for kw in ["port", "harbor", "harbour", "jetty", "berth", "dock", "துறைமுகம்", "ஹார்பர்", "बंदरगाह", "రేవు"])
    )

    if is_port_inquiry:
        v_lat = state.get("vessel_lat", 13.08)
        v_lon = state.get("vessel_lon", 80.27)

        if "hyderabad" in combined_q or "హైదరాబాద్" in combined_q or "हैदराबाद" in combined_q:
            en_text = (
                "Hyderabad is an inland hub located in Telangana. The closest commercial seaports to Hyderabad are "
                "Machilipatnam Port (~340 km east) and Krishnapatnam Port (~450 km southeast) in Andhra Pradesh, "
                "followed by Chennai Port (~520 km south) on the Coromandel Coast, and Visakhapatnam Port (~600 km northeast)."
            )
            port_loc_map = {
                "ta": "ஹைதராபாத் தெலங்கானாவில் உள்ள நிலப்பரப்பு நகரம் ஆகும். இதற்கு மிக அருகில் உள்ள கடல் துறைமுகங்கள்: ஆந்திராவில் உள்ள மசூலிப்பட்டினம் துறைமுகம் (~340 கி.மீ), கிருஷ்ணாப்பட்டினம் துறைமுகம் (~450 கி.மீ), மற்றும் சென்னை துறைமுகம் (~520 கி.மீ).",
                "te": "హైదరాబాద్ తెలంగాణలోని అంతర్భాగ నగరం. హైదరాబాద్‌కు అత్యంత సమీపంలో ఉన్న ఓడరేవులు ఆంధ్రప్రదేశ్‌లోని మచిలీపట్నం పోర్ట్ (~340 కి.మీ), కృష్ణపట్నం పోర్ట్ (~450 కి.మీ), మరియు చెన్నై పోర్ట్ (~520 కి.మీ).",
                "hi": "हैदराबाद तेलंगाना का एक अंतर्देशीय शहर है। हैदराबाद के सबसे नजदीकी प्रमुख समुद्री बंदरगाह आंध्र प्रदेश में मछलीपट्टनम बंदरगाह (~340 किमी) और कृष्णापट्टनम बंदरगाह (~450 किमी) हैं, इसके बाद चेन्नई बंदरगाह (~520 किमी) हैं।",
                "en": en_text,
            }
        elif "chennai" in combined_q or "madras" in combined_q or "சென்னை" in combined_q or "चेन्नई" in combined_q:
            en_text = (
                "In the Chennai maritime sector, the primary ports are: 1) Chennai Port (major commercial & container harbor), "
                "2) Kamarajar Port at Ennore (deepwater all-weather port, 20 km north), and 3) Chennai Kasimedu Fishing Harbor (active jetty with ice plants and fuel berths)."
            )
            port_loc_map = {
                "ta": "சென்னை கடல் பகுதியில் உள்ள முக்கிய துறைமுகங்கள்: 1) சென்னை சர்வதேச துறைமுகம், 2) எண்ணூர் காமராஜர் துறைமுகம் (20 கி.மீ வடக்கு), மற்றும் 3) காசிமேடு மீன்பிடி துறைமுகம் ஆகும்.",
                "te": "చెన్నై ప్రాంతంలోని ప్రధాన ఓడరేవులు: 1) చెన్నై కమర్షియల్ పోర్ట్, 2) కామరాజర్ పోర్ట్ (ఎన్నూర్), మరియు 3) కాసిమేడు ఫిషింగ్ హార్బర్.",
                "hi": "चेन्नई क्षेत्र के प्रमुख बंदरगाह: 1) चेन्नई मुख्य कंटेनर बंदरगाह, 2) कामराजार पोर्ट (एन्नोर), और 3) कासिमेडू मत्स्य पालन बंदरगाह हैं।",
                "en": en_text,
            }
        else:
            # Calculate distance to all ports from current vessel position
            scored_ports = []
            for p in MAJOR_INDIAN_PORTS:
                dist = _haversine_km(v_lat, v_lon, p["lat"], p["lon"])
                scored_ports.append((dist, p))
            scored_ports.sort(key=lambda x: x[0])
            nearest_dist, nearest_port = scored_ports[0]

            en_text = (
                f"Nearest harbor to your vessel ({v_lat:.3f}°N, {v_lon:.3f}°E) is {nearest_port['name']} "
                f"({nearest_port['state']}), located {nearest_dist:.1f} km away. Operational facility: {nearest_port['type']}."
            )
            port_loc_map = {
                "ta": f"உங்கள் தற்போதைய படகு இருப்பிடத்திற்கு மிக அருகில் உள்ள துறைமுகம் {nearest_port['name']} ஆகும். இது {nearest_dist:.1f} கி.மீ தொலைவில் உள்ளது ({nearest_port['type']}).",
                "te": f"మీ ప్రస్తుత నౌకకు అత్యంత సమీపంలోని రేవు {nearest_port['name']}, దూరం {nearest_dist:.1f} కి.మీ ({nearest_port['type']}).",
                "hi": f"आपकी नाव की वर्तमान स्थिति से निकटतम बंदरगाह {nearest_port['name']} है, जो {nearest_dist:.1f} किमी की दूरी पर है ({nearest_port['type']})।",
                "en": en_text,
            }

        state["english_response"] = en_text
        state["localized_response"] = port_loc_map.get(lang, en_text)
        state["quick_replies"] = ["Route to Nearest Port", "Weather at Port", "Check Border Distance"]
        return state

    # 3. Weather / Specific Location inquiry vs Composite Advisory
    w_data = state.get("weather_data") or {}
    wave = w_data.get("wave_height_m", 1.3)
    swell = w_data.get("swell_wave_height_m", 1.1)
    wind = w_data.get("wind_speed_knots", 12.5)
    wave_dir = w_data.get("wave_direction_deg", 135.0)
    wind_dir = w_data.get("wind_direction_deg", 120.0)
    temp = w_data.get("sea_surface_temp_celsius", 28.6)
    is_safe = w_data.get("is_safe_for_small_craft", True)
    loc_name = state.get("target_location_name")

    is_weather_specific = (
        not is_port_inquiry
        and (
            any(kw in combined_q for kw in ["weather", "wave", "wind", "swell", "sea", "temp", "storm", "cyclone", "rain", "வானிலை", "அலை", "காற்று", "मौसम", "हवा", "लहर", "వర్షం", "గాలి", "వాతావరణం"])
            or (loc_name is not None and not any(kw in combined_q for kw in ["port", "harbor", "route", "fish", "pfz", "border"]))
        )
    )

    if is_weather_specific:
        area_en = f"{loc_name} Marine Sector" if loc_name else "Current Coastal Sector"
        safety_en = "Sea state calm and safe for small craft operations." if is_safe else "Rough sea advisory! Exercise caution."
        en_text = (
            f"{area_en} Advisory: Significant wave height {wave:.1f}m (Swell: {swell:.1f}m, bearing {wave_dir:.0f}°), "
            f"wind speed {wind:.1f} kts ({wind_dir:.0f}°). Sea temp {temp:.1f}°C. {safety_en}"
        )

        weather_loc_map = {
            "ta": (
                f"{loc_name or 'கடல்'} நேரடி வானிலை: அலை உயரம் {wave:.1f}மீ (சுழல் அலை: {swell:.1f}மீ), "
                f"காற்று {wind:.1f} நாட்ஸ். கடல் வெப்பநிலை {temp:.1f}°C. "
                f"{'கடல் அமைதியாகவும் பாதுகாப்பாகவும் உள்ளது.' if is_safe else 'கடல் கொந்தளிப்பாக உள்ளது, எச்சரிக்கை!'}"
            ),
            "hi": (
                f"{loc_name or 'तटीय क्षेत्र'} समुद्री मौसम: लहरों की ऊंचाई {wave:.1f} मीटर (उछाल: {swell:.1f} मीटर), "
                f"हवा {wind:.1f} समुद्री मील है। समुद्र तापमान {temp:.1f}°C। "
                f"{'समुद्र शांत और नौकाओं के लिए सुरक्षित है।' if is_safe else 'समुद्र अशांत है, सावधानी बरतें।'}"
            ),
            "te": (
                f"{loc_name or 'తీర'} సముద్ర వాతావరణం: అలల ఎత్తు {wave:.1f} మీ (ఉప్పెన {swell:.1f} మీ), "
                f"గాలి {wind:.1f} నాట్స్. సముద్ర ఉష్ణోగ్రత {temp:.1f}°C. "
                f"{'సముద్రం ప్రశాంతంగా ఉంది, సురక్షితం.' if is_safe else 'సముద్రం ఉధృతంగా ఉంది, జాగ్రత్త!'}"
            ),
            "bn": (
                f"{loc_name or 'উপকূলীয়'} আবহাওয়া রিপোর্ট: ঢেউয়ের উচ্চতা {wave:.1f} মিটার, বাতাস {wind:.1f} নট। "
                f"তাপমাত্রা {temp:.1f}°C। {'সমুদ্র শান্ত এবং নিরাপদ।' if is_safe else 'সমুদ্র উত্তাল, সতর্ক থাকুন।'}"
            ),
            "gu": (
                f"{loc_name or 'દરિયાઈ'} હવામાન: મોજાંની ઊંચાઈ {wave:.1f} મીટર, પવન {wind:.1f} નોટ્સ. "
                f"તાપમાન {temp:.1f}°C. {'દરિયો શાંત અને સલામત છે.' if is_safe else 'દરિયો તોફાની છે, સાવધાન રહો.'}"
            ),
            "en": en_text,
        }

        loc_text = weather_loc_map.get(lang, en_text)
        state["english_response"] = en_text
        state["localized_response"] = loc_text
        state["quick_replies"] = ["Hourly Swell Forecast", "Nearest PFZ Zone", "Check Border Distance"]
        return state

    # 4. Composite Safe Case (Default)
    pfz_list = state.get("pfz_features") or []
    if pfz_list:
        top_pfz = pfz_list[0]
        pfz_id = top_pfz["pfz_id"]
        dist = top_pfz["distance_km"]
        bearing = top_pfz["bearing_deg"]
    else:
        pfz_id = "PFZ-01"
        dist = 14.2
        bearing = 82.0

    en_text = f"Sea state is calm (Wave: {wave}m, Wind: {wind} kts). High-catch Potential Fishing Zone {pfz_id} is located {dist} km away (Bearing {bearing}°). Safe navigation route loaded on map."
    loc_text = LOCALIZED_TEMPLATES[lang]["safe"].format(
        wave=wave,
        wind=wind,
        pfz_id=pfz_id,
        dist=dist,
        bearing=bearing
    )

    state["english_response"] = en_text
    state["localized_response"] = loc_text
    state["quick_replies"] = ["Nearest Harbor", "Hourly Swell Forecast", "Check Border Distance"]
    return state
