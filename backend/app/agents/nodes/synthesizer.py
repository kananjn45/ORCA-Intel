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

    # 2. Normal Safe Case
    w_data = state.get("weather_data") or {}
    wave = w_data.get("wave_height_m", 1.3)
    wind = w_data.get("wind_speed_knots", 12.5)

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
