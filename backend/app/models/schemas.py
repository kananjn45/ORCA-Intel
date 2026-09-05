"""
app/models/schemas.py
Owner: Dev 3 (Data Pipeline & Backend Core Engineer)

Single source of truth for every request/response DTO used across the
ORCA backend. These models are the CONTRACT the whole team codes
against (mirrors docs/BACKEND_SCHEMA.md exactly), so:
  - Dev 1 (geospatial) returns `RouteCalculationResponse` / `GeofenceStatus`
  - Dev 2 (agents) consumes/produces most of these inside AgentState
  - Dev 4 (voice) fills `audio_base64_localized` / voice endpoints
  - Dev 5/6 (mobile) deserialize these exact JSON shapes on the Flutter side

Do not duplicate these models elsewhere — import from here.
"""
from datetime import datetime
from enum import Enum
from typing import Any, Dict, List, Literal, Optional

from pydantic import BaseModel, Field, field_validator


# 0. Shared / Health

class HealthCheckResponse(BaseModel):
    status: Literal["ok", "degraded"] = "ok"
    app_name: str
    app_env: str
    version: str = "1.0.0"
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class ErrorResponse(BaseModel):
    """Uniform error envelope returned by our global exception handlers."""
    error: bool = True
    status_code: int
    message: str
    detail: Optional[Any] = None
    path: Optional[str] = None


# 1. Telemetry & Navigation Core

class TelemetryPayload(BaseModel):
    vessel_id: str = Field(default="VESSEL-IND-01", description="Unique craft identifier")
    latitude: float = Field(..., ge=-90.0, le=90.0, examples=[9.285])
    longitude: float = Field(..., ge=-180.0, le=180.0, examples=[79.312])
    speed_knots: float = Field(default=0.0, ge=0.0, le=60.0, examples=[8.5])
    heading_deg: float = Field(default=0.0, ge=0.0, le=360.0, examples=[85.0])
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class GeofenceStatus(BaseModel):
    distance_to_imbl_km: float = Field(..., examples=[4.2])
    nearest_imbl_point: Dict[str, float] = Field(..., examples=[{"lat": 9.35, "lon": 79.42}])
    lookahead_breach_projected: bool = Field(...)
    time_to_breach_minutes: Optional[float] = Field(default=None, examples=[18.5])
    warning_level: Literal["SAFE", "ADVISORY", "WARNING", "CRITICAL"] = Field(...)
    evasive_heading_deg: Optional[float] = Field(default=None, examples=[270.0])


# 2. Weather & Oceanographic Models

class MarineWeatherMetric(BaseModel):
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)
    wave_height_m: float = Field(..., examples=[1.4])
    wave_direction_deg: float = Field(..., examples=[140.0])
    wave_period_sec: float = Field(..., examples=[6.5])
    wind_speed_knots: float = Field(..., examples=[12.2])
    wind_direction_deg: float = Field(..., examples=[120.0])
    swell_wave_height_m: float = Field(..., examples=[1.1])
    sea_surface_temp_celsius: float = Field(..., examples=[28.4])
    sea_state_code: int = Field(..., ge=0, le=9, examples=[3])
    is_safe_for_small_craft: bool = Field(...)
    advisory_summary: str = Field(..., examples=["Moderate breeze, safe for mechanized crafts."])
    observed_at: datetime = Field(default_factory=datetime.utcnow)
    source: str = Field(default="open-meteo")


# 3. Potential Fishing Zone (PFZ) Models

class PFZFeature(BaseModel):
    pfz_id: str = Field(..., examples=["PFZ-TN-20260827-004"])
    sector_name: str = Field(..., examples=["Palk Bay South"])
    centroid: Dict[str, float] = Field(..., examples=[{"lat": 9.42, "lon": 79.55}])
    distance_km: float = Field(..., examples=[14.2])
    bearing_deg: float = Field(..., examples=[65.0])
    chlorophyll_mg_m3: float = Field(..., examples=[1.25])
    sst_gradient_celsius: float = Field(..., examples=[0.85])
    depth_m: float = Field(..., examples=[22.0])
    valid_until: datetime = Field(...)
    geojson_geometry: Dict[str, Any] = Field(..., description="GeoJSON Polygon")
    source: str = Field(default="incois-mock")

# 4. Pathfinding & Routing Models (owned/produced by Dev 1, contract lives here)


class RouteCalculationRequest(BaseModel):
    start_lat: float = Field(..., ge=-90.0, le=90.0)
    start_lon: float = Field(..., ge=-180.0, le=180.0)
    target_lat: float = Field(..., ge=-90.0, le=90.0)
    target_lon: float = Field(..., ge=-180.0, le=180.0)
    vessel_draft_m: float = Field(default=1.5, ge=0.5, le=10.0)
    avoid_high_waves: bool = Field(default=True)
    min_imbl_buffer_km: float = Field(default=2.0, ge=1.0)


class RouteCalculationResponse(BaseModel):
    route_id: str = Field(...)
    total_distance_km: float = Field(...)
    total_distance_nautical_miles: float = Field(...)
    estimated_duration_hours: float = Field(...)
    waypoints_count: int = Field(...)
    route_geojson: Dict[str, Any] = Field(..., description="GeoJSON Feature (LineString)")
    has_weather_penalties: bool = Field(...)
    min_distance_to_imbl_along_route_km: float = Field(...)
    is_safe: bool = Field(...)

# 5. Multimodal Conversational Agent Models

class ChatQueryRequest(BaseModel):
    session_id: str = Field(default="session-001")
    user_query_text: Optional[str] = Field(default=None)
    audio_base64: Optional[str] = Field(default=None)
    source_language: str = Field(default="ta", examples=["ta"])  # ta, te, hi, bn, gu, en
    telemetry: TelemetryPayload

    @field_validator("source_language")
    @classmethod
    def validate_language(cls, v: str) -> str:
        allowed = {"ta", "te", "hi", "bn", "gu", "en"}
        if v not in allowed:
            raise ValueError(f"source_language must be one of {sorted(allowed)}")
        return v


class GuardrailValidationReport(BaseModel):
    passed: bool = Field(...)
    checks_evaluated: List[str] = Field(...)
    violations: List[str] = Field(default_factory=list)
    emergency_action_triggered: bool = Field(default=False)


class ChatQueryResponse(BaseModel):
    session_id: str = Field(...)
    transcribed_text: Optional[str] = Field(default=None)
    translated_query_en: str = Field(...)
    response_text_en: str = Field(...)
    response_text_localized: str = Field(...)
    audio_base64_localized: Optional[str] = Field(default=None)
    guardrail_report: GuardrailValidationReport
    active_route: Optional[RouteCalculationResponse] = Field(default=None)
    recommended_pfzs: List[PFZFeature] = Field(default_factory=list)
    weather_summary: Optional[MarineWeatherMetric] = Field(default=None)
    geofence_status: GeofenceStatus
    quick_replies: List[str] = Field(default_factory=list)

# 6. Offline Pre-Voyage Pack (Dev 3 / Day 2)

class OfflinePackResponse(BaseModel):
    """
    Bundled 24h payload the Flutter app downloads at the harbor (while
    still online) and hydrates into its local sqflite cache before
    heading out to sea. See docs/TRD.md section 7.
    """
    generated_at: datetime = Field(default_factory=datetime.utcnow)
    expires_at: datetime = Field(...)
    bounding_box: Dict[str, float] = Field(
        ..., examples=[{"min_lat": 8.5, "min_lon": 78.5, "max_lat": 10.5, "max_lon": 80.5}]
    )
    weather_grid: List[MarineWeatherMetric] = Field(default_factory=list)
    pfz_advisories: List[PFZFeature] = Field(default_factory=list)
    imbl_boundary_geojson: Dict[str, Any] = Field(
        default_factory=dict,
        description=(
            "Placeholder pending Dev 1's app/geospatial/shapefile_loader.py output. "
            "Currently returns an empty FeatureCollection so the mobile client's "
            "offline sync flow can be built/tested end-to-end before Day 3 wiring."
        ),
    )
    grid_resolution_deg: float = Field(default=0.1, description="Sampling step for the weather grid")
    cell_count: int = Field(default=0)


# 7. Voice Pipeline Models (Dev 4 — Bhashini ASR / NMT / TTS)

class LanguageCode(str, Enum):
    """ISO 639-1 language codes supported by ORCA's voice pipeline."""
    HINDI = "hi"
    TAMIL = "ta"
    TELUGU = "te"
    BENGALI = "bn"
    GUJARATI = "gu"
    KANNADA = "kn"
    MALAYALAM = "ml"
    MARATHI = "mr"
    ODIA = "or"
    PUNJABI = "pa"
    ENGLISH = "en"


LANGUAGE_NAMES: dict[str, str] = {
    "hi": "Hindi",
    "ta": "Tamil",
    "te": "Telugu",
    "bn": "Bengali",
    "gu": "Gujarati",
    "kn": "Kannada",
    "ml": "Malayalam",
    "mr": "Marathi",
    "or": "Odia",
    "pa": "Punjabi",
    "en": "English",
}


class ASRRequest(BaseModel):
    """Incoming request for speech-to-text transcription."""
    audio_content: str = Field(..., description="Base64-encoded audio bytes.")
    language: str = Field(..., description="ISO 639-1 source language code (e.g. 'ta', 'hi').")
    audio_format: str = Field(default="wav", description="Audio container format: 'wav', 'pcm', 'flac', 'mp3'.")
    sample_rate: int = Field(default=16000, description="Sample rate in Hz.")


class ASRResult(BaseModel):
    """Result of a speech-to-text transcription."""
    text: str = Field(..., description="Recognised transcript text.")
    language: str = Field(..., description="Language code of the recognised speech.")
    is_mock: bool = Field(default=False, description="True when produced by the mock engine.")
    confidence: Optional[float] = Field(default=None, description="Optional confidence score (0.0-1.0).")


class NMTRequest(BaseModel):
    """Incoming request for text translation."""
    text: str = Field(..., description="Source text to translate.")
    source_language: str = Field(..., description="Source language code.")
    target_language: str = Field(..., description="Target language code.")


class NMTResult(BaseModel):
    """Result of a text translation."""
    translated_text: str
    source_language: str
    target_language: str
    is_mock: bool = False


class TTSRequest(BaseModel):
    """Incoming request for speech synthesis."""
    text: str = Field(..., description="Text to synthesise.")
    language: str = Field(..., description="Language code for synthesis.")
    gender: str = Field(default="female", description="Voice gender preference.")
    audio_format: str = Field(default="wav", description="Desired output format.")


class TTSResult(BaseModel):
    """Result of a text-to-speech synthesis."""
    audio_content: str = Field(..., description="Base64-encoded audio bytes.")
    language: str
    audio_format: str = "wav"
    is_mock: bool = False


class VoicePipelineResult(BaseModel):
    """Combined result of the ASR -> NMT pipeline."""
    transcript: str = Field(..., description="Original regional-language transcript.")
    translated_text: str = Field(..., description="Translated text (typically English).")
    source_language: str
    target_language: str
    is_mock: bool = False


class ResponsePipelineResult(BaseModel):
    """Combined result of the NMT -> TTS pipeline."""
    translated_text: str = Field(..., description="Translated regional-language text.")
    audio_content: str = Field(..., description="Base64-encoded WAV audio.")
    source_language: str
    target_language: str
    audio_format: str = "wav"
    is_mock: bool = False