# 🗄️ ORCA: Backend Schemas, Data Models & API Contracts
> **Project:** ORCA (Marine EcOsystem Reasoning with Collaborative Agents)  
> **Problem Statement ID:** 26176 | **Document:** Backend Schema & Type Contracts  

---

## 1. 📦 Pydantic Data Models & Request / Response DTOs

```python
from typing import List, Dict, Any, Optional, Literal
from pydantic import BaseModel, Field
from datetime import datetime

# ==========================================
# 1. Telemetry & Navigation Core
# ==========================================

class TelemetryPayload(BaseModel):
    vessel_id: str = Field(default="VESSEL-IND-01", description="Unique craft identifier")
    latitude: float = Field(..., ge=-90.0, le=90.0, example=9.285)
    longitude: float = Field(..., ge=-180.0, le=180.0, example=79.312)
    speed_knots: float = Field(default=0.0, ge=0.0, le=60.0, example=8.5)
    heading_deg: float = Field(default=0.0, ge=0.0, le=360.0, example=85.0)
    timestamp: datetime = Field(default_factory=datetime.utcnow)

class GeofenceStatus(BaseModel):
    distance_to_imbl_km: float = Field(..., example=4.2)
    nearest_imbl_point: Dict[str, float] = Field(..., example={"lat": 9.35, "lon": 79.42})
    lookahead_breach_projected: bool = Field(..., example=False)
    time_to_breach_minutes: Optional[float] = Field(default=None, example=18.5)
    warning_level: Literal["SAFE", "ADVISORY", "WARNING", "CRITICAL"] = Field(...)
    evasive_heading_deg: Optional[float] = Field(default=None, example=270.0)

# ==========================================
# 2. Weather & Oceanographic Models
# ==========================================

class MarineWeatherMetric(BaseModel):
    wave_height_m: float = Field(..., example=1.4)
    wave_direction_deg: float = Field(..., example=140.0)
    wave_period_sec: float = Field(..., example=6.5)
    wind_speed_knots: float = Field(..., example=12.2)
    wind_direction_deg: float = Field(..., example=120.0)
    swell_wave_height_m: float = Field(..., example=1.1)
    sea_surface_temp_celsius: float = Field(..., example=28.4)
    sea_state_code: int = Field(..., ge=0, le=9, example=3)
    is_safe_for_small_craft: bool = Field(...)
    advisory_summary: str = Field(..., example="Moderate breeze, safe for mechanized crafts.")

# ==========================================
# 3. Potential Fishing Zone (PFZ) Models
# ==========================================

class PFZFeature(BaseModel):
    pfz_id: str = Field(..., example="PFZ-TN-20260827-004")
    sector_name: str = Field(..., example="Palk Bay South")
    centroid: Dict[str, float] = Field(..., example={"lat": 9.42, "lon": 79.55})
    distance_km: float = Field(..., example=14.2)
    bearing_deg: float = Field(..., example=65.0)
    chlorophyll_mg_m3: float = Field(..., example=1.25)
    sst_gradient_celsius: float = Field(..., example=0.85)
    depth_m: float = Field(..., example=22.0)
    valid_until: datetime = Field(...)
    geojson_geometry: Dict[str, Any] = Field(..., description="GeoJSON Polygon")

# ==========================================
# 4. Pathfinding & Routing Models
# ==========================================

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

# ==========================================
# 5. Multimodal Conversational Agent Models
# ==========================================

class ChatQueryRequest(BaseModel):
    session_id: str = Field(default="session-001")
    user_query_text: Optional[str] = Field(default=None)
    audio_base64: Optional[str] = Field(default=None)
    source_language: str = Field(default="ta", example="ta")  # ta, te, hi, bn, gu, en
    telemetry: TelemetryPayload

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
```

---

## 2. 📱 Local SQLite Mobile Schema (`sqflite` for Flutter)

```sql
-- 1. Cached IMBL Boundary Points
CREATE TABLE cached_imbl_boundaries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    boundary_name TEXT NOT NULL,
    country_pair TEXT NOT NULL,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    sequence_order INTEGER NOT NULL
);

-- 2. Cached Hourly Marine Weather Grid
CREATE TABLE cached_weather_grid (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    wave_height_m REAL NOT NULL,
    wind_speed_knots REAL NOT NULL,
    forecast_hour TEXT NOT NULL,
    expires_at TEXT NOT NULL
);

-- 3. Cached PFZ Polygons
CREATE TABLE cached_pfz_advisories (
    pfz_id TEXT PRIMARY KEY,
    sector_name TEXT NOT NULL,
    centroid_lat REAL NOT NULL,
    centroid_lon REAL NOT NULL,
    chlorophyll REAL NOT NULL,
    geojson_polygon TEXT NOT NULL,
    valid_until TEXT NOT NULL
);

-- 4. Local Offline Chat & Voice History
CREATE TABLE local_chat_history (
    id TEXT PRIMARY KEY,
    sender TEXT NOT NULL,
    text_localized TEXT NOT NULL,
    text_english TEXT,
    audio_local_path TEXT,
    timestamp TEXT NOT NULL
);
```

---

## 3. 🌐 REST API Endpoints Specifications

| Method | Endpoint | Description | Request Body / Query | Response Model |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/api/v1/chat/message` | Multimodal voice/text query processing | `ChatQueryRequest` | `ChatQueryResponse` |
| `POST` | `/api/v1/navigation/route` | $A^*$ collision-free route generation | `RouteCalculationRequest` | `RouteCalculationResponse` |
| `GET` | `/api/v1/marine/weather` | Live Open-Meteo sea state metrics | `?lat=9.28&lon=79.31` | `MarineWeatherMetric` |
| `GET` | `/api/v1/marine/pfz` | Active INCOIS PFZ advisory polygons | `?lat=9.28&lon=79.31&radius_km=50` | `List[PFZFeature]` |
| `POST` | `/api/v1/geofence/check` | IMBL distance & 15-min lookahead evaluation | `TelemetryPayload` | `GeofenceStatus` |
| `GET` | `/api/v1/marine/offline-pack` | 24-hr bounding box bundle for offline storage | `?min_lat=8.5&min_lon=78.5&max_lat=10.5&max_lon=80.5` | `OfflinePackResponse` |
| `POST` | `/api/v1/voice/transcribe` | Bhashini ASR direct audio transcription | `FormData (audio/wav)` | `{ "transcript": str }` |
| `POST` | `/api/v1/voice/synthesize` | Bhashini TTS direct audio synthesis | `{ "text": str, "target_lang": "ta" }` | `{ "audio_base64": str }` |
