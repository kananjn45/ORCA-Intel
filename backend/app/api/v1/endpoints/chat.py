"""
app/api/v1/endpoints/chat.py
Owner (per docs/IMPLEMENTATION_PLAN.md): Dev 2 (Multi-Agent & Guardrails)
  with Dev 4 (voice) and Dev 3 (weather/PFZ data) feeding into the graph.
  -> real LangGraph orchestration lives in app/agents/graph.py

TEMPORARY MOCK — written by Dev 3 only so the router boots end-to-end and
Dev 6 (Flutter conversational sheet) can start integrating against the
exact `ChatQueryResponse` contract before the LangGraph pipeline is wired
(Day 3+ per docs/IMPLEMENTATION_PLAN.md).

This mock DOES call Dev 3's own real services (weather + PFZ) so the
"data" half of the response is genuine — only the NLU/guardrail/synthesis
half is a placeholder.
"""
from app.models.schemas import (
    ChatQueryRequest,
    ChatQueryResponse,
    GeofenceStatus,
    GuardrailValidationReport,
)
from app.services import incois_pfz, open_meteo
from fastapi import APIRouter

router = APIRouter()


@router.post("/message", response_model=ChatQueryResponse, summary="[PARTIAL MOCK] Multimodal chat — Dev 2/4 own full logic")
async def post_chat_message(request: ChatQueryRequest) -> ChatQueryResponse:
    lat = request.telemetry.latitude
    lon = request.telemetry.longitude

    weather = await open_meteo.get_marine_weather(lat, lon)
    pfzs = await incois_pfz.get_pfz_features(lat, lon, radius_km=40.0)

    query_text = request.user_query_text or "[voice query - Dev 4 ASR not wired yet]"

    return ChatQueryResponse(
        session_id=request.session_id,
        transcribed_text=request.user_query_text,
        translated_query_en=query_text,
        response_text_en=(
            f"Nearest recommended fishing zone is {pfzs[0].distance_km} km away "
            f"(chlorophyll {pfzs[0].chlorophyll_mg_m3} mg/m3). "
            f"Current wave height is {weather.wave_height_m} m."
        ) if pfzs else f"Current wave height is {weather.wave_height_m} m. No PFZ data available.",
        response_text_localized="[MOCK - Dev 4's NMT/localization pending]",
        audio_base64_localized=None,
        guardrail_report=GuardrailValidationReport(
            passed=True,
            checks_evaluated=["mock_placeholder"],
            violations=[],
            emergency_action_triggered=False,
        ),
        active_route=None,
        recommended_pfzs=pfzs[:3],
        weather_summary=weather,
        geofence_status=GeofenceStatus(
            distance_to_imbl_km=-1.0,
            nearest_imbl_point={"lat": 0.0, "lon": 0.0},
            lookahead_breach_projected=False,
            warning_level="SAFE",
        ),
        quick_replies=["Show me the route", "Is it safe to go further?", "Check weather"],
    )