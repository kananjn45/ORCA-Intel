<div align="center">

# 🌊 ORCA
### Marine EcOsystem Reasoning with Collaborative Agents

**An AI-powered maritime safety & navigation platform for India's coastal fishermen**

[![Python](https://img.shields.io/badge/Python-3.11-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![LangGraph](https://img.shields.io/badge/LangGraph-Multi--Agent-FF6B6B?style=for-the-badge)](https://github.com/langchain-ai/langgraph)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://docker.com)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

---

> 🏆 **Smart India Hackathon 2026** — ISRO Problem Statement **#26176**  
> 🛰️ Translating raw satellite EO data into life-saving voice advisories for fishermen  
> 🌐 Supports Tamil · Telugu · Hindi · Bengali · Gujarati · English

</div>

---

## 📌 What is ORCA?

India has over **4 million coastal fishermen** who venture into the sea daily — often without access to timely weather advisories, maritime boundary information, or navigation tools. Existing systems like INCOIS PFZ advisories require literacy, internet access, and domain expertise most fishermen don't have.

**ORCA solves this** by coordinating a team of specialized AI agents to translate complex satellite ocean data — wave heights, chlorophyll fronts, sea surface temperatures, boundary proximity — into a single, spoken advisory in the fisherman's own language. Through a Flutter mobile app or a web dashboard, a fisherman can simply ask *"நல்ல மீன்பிடி மண்டலம் எங்கே?"* ("Where is a good fishing zone?") and receive a spoken, navigable answer — even offline at sea.

---

## ✨ Core Features

| Feature | Description |
|---|---|
| 🤖 **Multi-Agent AI** | LangGraph DAG with 6 specialized agents — weather, PFZ, boundary, routing, guardrail, synthesizer |
| 🛡️ **Zero-Hallucination Safety** | Symbolic guardrail intercepts LLM before synthesis — hard limits enforced for wave height, wind, and IMBL proximity |
| 🗺️ **A\* Marine Pathfinding** | Custom obstacle-aware A\* over rasterized 0.01° coastal grid — GeoJSON route output |
| 📡 **15-Min Lookahead Geofence** | Speed + heading vector projected 15 minutes forward — alerts before IMBL breach, not after |
| 🗣️ **Multilingual Voice** | Bhashini ASR/NMT/TTS pipeline — voice in → voice out in Tamil, Telugu, Hindi, Bengali, Gujarati |
| 🌊 **Live Marine Data** | Open-Meteo Marine API (wave, swell, SST) + INCOIS PFZ advisories (chlorophyll fronts) |
| 📴 **Offline-First** | Pre-voyage pack downloads 24hr weather grid, PFZ polygons, IMBL boundaries to on-device SQLite |
| ⚡ **Sub-2s Response** | Concurrent async API fetches + TTL in-memory cache (weather: 15min, PFZ: 6hr) |

---

## 🏛️ System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         USER INTERFACE LAYER                            │
│   Flutter Mobile App (Android/iOS)    │   Web Dashboard (Leaflet.js)   │
└───────────────┬─────────────────────────────────────────┬───────────────┘
                │  GPS Telemetry                          │  Chat Query
                │  Voice WAV (16kHz mono)                 │
                ▼                                         ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                     BHASHINI VOICE PIPELINE                             │
│   Regional Speech → ASR → Regional Text → NMT → English Text           │
└─────────────────────────────┬───────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│               FastAPI Backend  :8000  (Python 3.11 + Uvicorn)           │
│                                                                         │
│   POST /api/v1/chat/message     POST /api/v1/navigation/route           │
│   POST /api/v1/geofence/check   GET  /api/v1/marine/weather             │
│   GET  /api/v1/marine/pfz       POST /api/v1/voice/transcribe           │
└─────────────────────────────┬───────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                  LangGraph Multi-Agent Orchestrator                      │
│                                                                         │
│  [IntentClassifier] → [WeatherAgent] → [PFZAgent] → [BoundaryAgent]    │
│                                                          │              │
│                                                   [RoutingAgent]        │
│                                                          │              │
│                                            [SymbolicGuardrail]          │
│                                           ╱                ╲            │
│                              [EmergencyOverride]   [ResponseSynthesizer]│
└──────────────┬──────────────────────────────────────────────────────────┘
               │                    │                      │
               ▼                    ▼                      ▼
    ┌─────────────────┐  ┌────────────────────┐  ┌────────────────────┐
    │  Open-Meteo API  │  │   INCOIS ERDDAP    │  │  GeoJSON Boundary  │
    │  Marine Weather  │  │   PFZ Advisories   │  │  IMBL + Coastline  │
    └─────────────────┘  └────────────────────┘  └────────────────────┘
```

### LangGraph Agent Pipeline

```
START
  ↓
intent_classifier   →  Detects: weather / pfz / boundary / route intent (multilingual keywords)
  ↓
weather_agent       →  Fetches Open-Meteo: wave height, swell, wind speed, SST
  ↓
pfz_agent           →  Fetches INCOIS: PFZ polygons ranked by chlorophyll-a concentration
  ↓
boundary_agent      →  Geodesic IMBL distance + 15-min lookahead vector breach check
  ↓
routing_agent       →  A* pathfinding over rasterized marine grid → GeoJSON LineString
  ↓
symbolic_guardrail  →  HARD RULES: wave>2.5m OR wind>25kt OR IMBL<2km → EMERGENCY
  ↓
  ├─ EMERGENCY ──→ emergency_override_node  →  Deterministic regional alert + evasive bearing
  └─ SAFE      ──→ response_synthesizer     →  Template-filled regional language advisory
```

---

## 🛠️ Technology Stack

### Backend
| Technology | Version | Role |
|---|---|---|
| **Python** | 3.11 | Core runtime |
| **FastAPI** | 0.115.6 | Async REST API framework |
| **Uvicorn** | 0.32.1 | ASGI server |
| **Pydantic v2** | 2.10.3 | Request/response validation & DTOs |
| **LangGraph** | Latest | Multi-agent DAG orchestration |
| **httpx** | 0.28.1 | Async HTTP client (Open-Meteo, INCOIS, Bhashini) |
| **Shapely** | ≥2.0 | GIS geometry operations (IMBL, coastline) |
| **GeoPandas** | ≥1.0 | GeoJSON/shapefile parsing |
| **pyproj** | ≥3.6 | WGS84 geodesic distance calculations |
| **SQLite + aiosqlite** | Built-in | Session storage & local cache |

### AI & Data
| Technology | Role |
|---|---|
| **Groq (Llama3-70B)** | Primary LLM inference (~500 tok/s) |
| **Gemini 1.5 Flash** | Secondary LLM fallback |
| **Ollama (Llama3:8b)** | Offline/local LLM fallback |
| **Bhashini ULCA/Dhruva** | ASR + NMT + TTS for Indian regional languages |
| **Open-Meteo Marine API** | Free wave, swell, wind, SST data |
| **INCOIS ERDDAP/WFS** | PFZ advisory polygons (chlorophyll, SST gradients) |

### Mobile
| Technology | Version | Role |
|---|---|---|
| **Flutter** | 3.x | Cross-platform Android/iOS app |
| **Dart** | ≥3.0 | Application language |
| **flutter_riverpod** | ^2.5.1 | Reactive state management |
| **flutter_map** | ^6.1.0 | Leaflet-equivalent mapping |
| **sqflite** | ^2.3.2 | Offline SQLite cache |
| **geolocator** | ^11.0.0 | Device GPS GNSS stream |
| **record** | ^5.2.1 | Microphone audio capture |
| **audioplayers** | ^6.0.0 | TTS audio playback |
| **dio** | ^5.4.1 | HTTP client with interceptors |

### Web Dashboard
| Technology | Role |
|---|---|
| **HTML5 + Vanilla JS** | Single-page tactical dashboard |
| **Leaflet.js 1.9.4** | Interactive marine map |
| **Manrope + DM Mono** | Typography system |

---

## 📁 Repository Structure

```text
ORCA-Intel/
│
├── docs/                                   # Engineering & Architectural Blueprints
│   ├── PRD.md                              # Product Requirements Document
│   ├── TRD.md                              # Technical Requirements Document
│   ├── UI_UX_DESIGN.md                     # Mobile UI/UX Design System & Wireframes
│   ├── APP_FLOW.md                         # Application & Multi-Agent Flow State Machines
│   ├── BACKEND_SCHEMA.md                   # Data Models, SQLite Schemas & API Contracts
│   ├── GEOSPATIAL.md                       # Geospatial Math, Lookahead & A* Blueprint
│   └── IMPLEMENTATION_PLAN.md              # 12-Day Sprint Plan for 6 Team Members
│
├── backend/                                # Python FastAPI & LangGraph Backend
│   ├── main.py                             # ← App entrypoint, middleware, exception handlers
│   ├── requirements.txt                    # Python dependencies
│   ├── Dockerfile                          # Container definition (python:3.11-slim)
│   ├── .env.example                        # Environment variable template
│   │
│   └── app/
│       ├── api/v1/
│       │   ├── router.py                   # Master V1 router (5 sub-routers)
│       │   └── endpoints/
│       │       ├── chat.py                 # POST /chat/message — LangGraph orchestrator entry
│       │       ├── navigation.py           # POST /navigation/route — A* pathfinding
│       │       ├── geofence.py             # POST /geofence/check — IMBL proximity + lookahead
│       │       ├── marine_data.py          # GET /marine/weather, /pfz, /offline-pack
│       │       └── voice.py               # POST /voice/transcribe, /voice/synthesize
│       │
│       ├── agents/                         # ← LangGraph Multi-Agent System
│       │   ├── state.py                    # AgentState TypedDict (42 keys, 6 sections)
│       │   ├── graph.py                    # build_orca_agent_graph() + StandalonePipeline
│       │   ├── guardrails/
│       │   │   ├── symbolic_verifier.py    # Master neuro-symbolic safety barrier
│       │   │   ├── weather_limits.py       # Wave/wind invariant checks
│       │   │   └── boundary_rules.py       # IMBL proximity validator
│       │   └── nodes/
│       │       ├── intent_classifier.py    # Multilingual keyword-based intent detection
│       │       ├── weather_agent.py        # Open-Meteo sea state evaluator
│       │       ├── pfz_agent.py            # INCOIS chlorophyll-ranked zone locator
│       │       ├── boundary_agent.py       # Geodesic IMBL distance + lookahead
│       │       ├── routing_agent.py        # A* marine pathfinding invocator
│       │       └── synthesizer.py          # Multilingual template-based response generator
│       │
│       ├── geospatial/                     # ← GIS Math & Pathfinding Engine
│       │   ├── astar.py                    # A* with octile heuristic (heapq)
│       │   ├── grid.py                     # MarineGrid — 0.01° rasterized obstacle map
│       │   ├── geofence.py                 # 15-minute WGS84 geodesic lookahead vectors
│       │   ├── distance.py                 # Haversine, geodesic, cross-track, AEQD projection
│       │   └── shapefile_loader.py         # GeoJSON boundary parser
│       │
│       ├── services/                       # ← External APIs & Caching
│       │   ├── open_meteo.py               # Concurrent dual-endpoint weather fetcher
│       │   ├── incois_pfz.py               # PFZ parser (live → cached granules → mock)
│       │   ├── bhashini.py                 # ASR + NMT + TTS (Bhashini / Google / Mock)
│       │   ├── google_voice.py             # Google Cloud Speech/Translate/TTS fallback
│       │   ├── cache.py                    # Async TTL cache (LRU eviction, asyncio.Lock)
│       │   └── tts_cache.py                # TTS audio content cache
│       │
│       ├── models/
│       │   ├── schemas.py                  # All Pydantic DTOs — single source of truth
│       │   ├── db_models.py                # SQLAlchemy ORM entity models
│       │   └── geojson_models.py           # GeoJSON FeatureCollection schemas
│       │
│       ├── core/
│       │   ├── config.py                   # pydantic-settings: all environment config
│       │   ├── logging.py                  # Structured JSON logger + request_id ContextVar
│       │   ├── security.py                 # Auth & rate limit helpers
│       │   └── exceptions.py               # Custom exception hierarchy
│       │
│       ├── db/
│       │   ├── session.py                  # SQLAlchemy engine + async session factory
│       │   └── init_db.py                  # Table creation on startup
│       │
│       ├── data/
│       │   ├── boundaries/                 # GeoJSON: IMBL, EEZ, MPAs, India coastline
│       │   └── samples/                    # Mock INCOIS PFZ granules for offline testing
│       │
│       └── tests/                          # pytest unit & integration suites
│
├── frontend/                               # Web Tactical Dashboard
│   ├── index.html                          # Single-page HTML shell
│   ├── app.js                              # Leaflet map + chat sheet logic (26 lines)
│   └── styles.css                          # Tactical dark theme CSS
│
└── mobile/                                 # Flutter Mobile App (Android/iOS)
    ├── lib/
    │   ├── main.dart                       # App entrypoint, theme switching
    │   ├── core/
    │   │   ├── constants/                  # AppConstants, API endpoints, colors
    │   │   ├── theme/                      # Tactical Dark & Sunlight Deck themes
    │   │   ├── network/                    # Dio HTTP + WebSocket clients
    │   │   └── utils/                      # Haversine math + audio player helpers
    │   ├── data/
    │   │   ├── models/                     # Dart DTOs (Telemetry, PFZ, Weather, Geofence)
    │   │   ├── local/                      # sqflite DB + offline cache manager
    │   │   └── repositories/              # Marine, Chat, Voice data repositories
    │   ├── providers/                      # ChangeNotifier state management
    │   │   ├── telemetry_provider.dart     # Live GPS stream (geolocator)
    │   │   ├── voice_chat_provider.dart    # Recording → ASR → Agent → TTS pipeline
    │   │   ├── geofence_alert_provider.dart # IMBL proximity + emergency alarm
    │   │   ├── marine_map_provider.dart    # Map layer visibility state
    │   │   └── offline_sync_provider.dart  # Pre-voyage pack download progress
    │   └── views/
    │       ├── dashboard/                  # Main tactical HUD screen
    │       ├── map/                        # FlutterMap + vector overlay widgets
    │       ├── chat/                       # Voice recording sheet + message bubbles
    │       └── offline/                    # Pre-voyage pack downloader
    ├── assets/
    │   ├── boundaries/                     # Bundled IMBL GeoJSON for offline
    │   ├── audio/                          # Alert chimes
    │   └── icons/                          # App icons
    ├── pubspec.yaml                        # Flutter dependencies
    └── test/                               # Widget & unit tests
```

---

## 🚀 Getting Started

### Prerequisites

| Tool | Version | Install |
|---|---|---|
| Python | 3.11+ | [python.org](https://python.org) |
| Flutter | 3.x | [flutter.dev](https://flutter.dev) |
| Git | Any | [git-scm.com](https://git-scm.com) |

---

### 1️⃣ Clone the Repository

```bash
git clone https://github.com/kananjn45/ORCA-Intel
cd ORCA-Intel
```

---

### 2️⃣ Backend Setup

```bash
cd backend

# Create virtual environment
python -m venv venv
.\venv\Scripts\activate        # Windows
# source venv/bin/activate     # macOS / Linux

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env and add your API keys (see Environment Variables section)

# Start the server
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The API will be live at `http://localhost:8000`  
Interactive docs: `http://localhost:8000/docs`

---

### 3️⃣ Docker (Alternative)

```bash
cd backend
docker build -t orca-backend .
docker run -p 8000:8000 --env-file .env orca-backend
```

---

### 4️⃣ Flutter Mobile App

```bash
cd mobile

# Get dependencies
flutter pub get

# Run on connected device / emulator
flutter run

# Build release APK
flutter build apk --release
```

---

### 5️⃣ Web Dashboard

Simply open `frontend/index.html` in any modern browser — no build step required.

---

## ⚙️ Environment Variables

Create `backend/.env` from the template:

```env
# ─── Application ───────────────────────────────────────────
APP_ENV=development
DEBUG=true
HOST=0.0.0.0
PORT=8000

# ─── LLM Provider (choose one) ─────────────────────────────
LLM_PROVIDER=groq                     # groq | gemini | ollama
GROQ_API_KEY=your_groq_api_key        # https://console.groq.com
GROQ_MODEL=llama3-70b-8192

GEMINI_API_KEY=your_gemini_key        # https://makersuite.google.com
GEMINI_MODEL=gemini-1.5-flash

OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=llama3:8b

# ─── Bhashini Multilingual Voice ───────────────────────────
BHASHINI_USER_ID=your_user_id         # https://bhashini.gov.in
BHASHINI_API_KEY=your_api_key
BHASHINI_USE_MOCK=true                # Set false when credentials are ready

# ─── Google Cloud APIs (Fallback Voice) ────────────────────
GOOGLE_API_KEY=your_google_key
TRANSLATION_PROVIDER=google           # google | bhashini | mock
VOICE_PROVIDER=google

# ─── Safety Guardrail Limits ───────────────────────────────
MAX_SAFE_WAVE_HEIGHT_METERS=2.0
MAX_SAFE_WIND_SPEED_KNOTS=25.0
IMBL_DANGER_BUFFER_KM=2.0
IMBL_CAUTION_BUFFER_KM=5.0

# ─── Cache TTLs ────────────────────────────────────────────
WEATHER_CACHE_TTL_SECONDS=900         # 15 minutes
PFZ_CACHE_TTL_SECONDS=21600           # 6 hours
```

> **Note:** The system runs in mock/fallback mode without API keys — all three golden demo scenarios work offline.

---

## 🌐 API Reference

### Base URL: `http://localhost:8000/api/v1`

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/chat/message` | 🤖 Full multi-agent advisory (LangGraph + Guardrails) |
| `POST` | `/navigation/route` | 🗺️ A\* collision-free marine route generation |
| `POST` | `/geofence/check` | ⚠️ IMBL distance + 15-min lookahead evaluation |
| `GET`  | `/marine/weather` | 🌊 Live Open-Meteo sea state metrics |
| `GET`  | `/marine/pfz` | 🐟 INCOIS Potential Fishing Zone advisories |
| `GET`  | `/marine/offline-pack` | 📴 24-hour pre-voyage data bundle |
| `POST` | `/voice/transcribe` | 🎙️ Bhashini ASR — regional speech to text |
| `POST` | `/voice/synthesize` | 🔊 Bhashini TTS — text to regional speech |
| `GET`  | `/health` | ✅ Service health check |

### Quick Example — Chat Query

**Request:**
```bash
curl -X POST http://localhost:8000/api/v1/chat/message \
  -H "Content-Type: application/json" \
  -d '{
    "session_id": "session-001",
    "user_query_text": "நல்ல மீன்பிடி மண்டலம் எங்கே?",
    "source_language": "ta",
    "telemetry": {
      "latitude": 9.285,
      "longitude": 79.312,
      "speed_knots": 8.5,
      "heading_deg": 85.0
    }
  }'
```

**Response:**
```json
{
  "response_text_en": "Sea state is calm (Wave: 1.3m, Wind: 12.5 kts). High-catch PFZ-TN-2026-04 is 14.2 km away at bearing 65°. Safe route loaded on map.",
  "response_text_localized": "வானிலை சீராக உள்ளது (அலை: 1.3 மீ, காற்று: 12.5 நாட்ஸ்). சிறந்த மீன்பிடி மண்டலம் PFZ-TN-2026-04 14.2 கி.மீ தொலைவில் உள்ளது.",
  "guardrail_report": {
    "passed": true,
    "violations": [],
    "emergency_action_triggered": false
  },
  "geofence_status": {
    "distance_to_imbl_km": 13.88,
    "warning_level": "SAFE"
  },
  "quick_replies": ["Nearest Harbor", "Hourly Swell Forecast", "Check Border Distance"]
}
```

---

## 🎯 Demo Scenarios

Three pre-configured golden scenarios can be triggered via `TelemetryProvider.setScenario()` in the Flutter app:

### Scenario 1 — Optimal Route Guidance ✅
```
Vessel:  9.28°N, 79.31°E | Speed: 8 kts | Heading: 65°
Result:  A* route to PFZ-TN-2026-04 (14.2 km, bearing 65°)
         Wave: 1.3m ✅ | Wind: 12.5 kts ✅ | IMBL: 13.88 km ✅
         Tamil advisory spoken aloud
```

### Scenario 2 — Dynamic Border Warning 🚨
```
Vessel:  9.37°N, 79.43°E | Speed: 12 kts | Heading: 85° (east)
Result:  IMBL distance: 1.7 km → CRITICAL
         15-min lookahead BREACH in 3.2 minutes
         Emergency Override: "🚨 தீவிர அவசர எச்சரிக்கை! 265° திசையில் திருப்பவும்!"
         Evasive bearing: 265° (180° reversal)
```

### Scenario 3 — Dangerous Weather Rerouting ⛈️
```
Vessel:  Any position
Inject:  Wave height: 3.2m | Wind: 28 knots
Result:  Weather Guardrail fires → LLM bypassed
         "DANGEROUS: High waves/winds. Do not venture into open sea."
         Regional language alert spoken aloud
```

---

## 🧠 Architecture Deep-Dive

### Neuro-Symbolic Safety (Our Core Innovation)

ORCA does **not** use a free-form LLM for safety-critical advice. Instead:

```
Real Data (APIs)  →  Agent Nodes  →  Symbolic Guardrail  →  Template Synthesizer
      ↑                                      ↑                       ↑
  Ground Truth              Hard rules (no LLM override)    Pre-written regional phrases
                                                             filled with verified numbers
```

**Why this matters:** An LLM could hallucinate "conditions are safe" when wave height is 3m. Our symbolic guardrail applies `if wave_height > 2.5m: EMERGENCY` — a pure Python boolean that **cannot hallucinate**. The LLM is never involved in safety threshold decisions.

### A* Marine Pathfinding

```python
# 0.01° grid ≈ 1.1km per cell
grid = MarineGrid(min_lat, max_lat, min_lon, max_lon, resolution_deg=0.01)
grid.rasterize_obstacles(india_coastline_geojson)  # Block land cells

path = astar(grid, start_node, goal_node)          # Octile heuristic: √2×min(Δr,Δc)+|Δr-Δc|
route_geojson = path_to_geojson(grid, path)        # GeoJSON LineString output
```

### 15-Minute Geofence Lookahead

```python
# At 8 knots heading east: vessel travels 3.7 km in 15 minutes
distance_km = speed_knots * 1.852 * (15/60)
end_point = Geod("WGS84").fwd(lon, lat, heading_deg, distance_km * 1000)
track = LineString([start, *16_intermediate_points, end_point])
is_breach = track.intersects(imbl_geometry)        # Alert BEFORE the crossing
```

---

## 🌍 Supported Languages

| Language | Code | ASR | NMT | TTS |
|---|---|---|---|---|
| Tamil | `ta` | ✅ | ✅ | ✅ |
| Telugu | `te` | ✅ | ✅ | ✅ |
| Hindi | `hi` | ✅ | ✅ | ✅ |
| Bengali | `bn` | ✅ | ✅ | ✅ |
| Gujarati | `gu` | ✅ | ✅ | ✅ |
| English | `en` | ✅ | ✅ | ✅ |

Emergency alerts are fully pre-translated into all 6 languages — **zero network latency** in a crisis.

---

## 🛡️ Safety Guardrail Constants

```python
CRITICAL_WAVE_HEIGHT_M    = 2.5   # Capsize danger for <10m fiber crafts (INCOIS standard)
WARNING_WAVE_HEIGHT_M     = 2.0   # Small craft caution threshold
CRITICAL_WIND_SPEED_KNOTS = 25.0  # Squall / gale hazard threshold
WARNING_WIND_SPEED_KNOTS  = 20.0  # Strong breeze caution
CRITICAL_SWELL_HEIGHT_M   = 2.0   # Long-period swell surge danger
IMBL_DANGER_BUFFER_KM     = 2.0   # Hard stop — legal maritime boundary zone
IMBL_CAUTION_BUFFER_KM    = 5.0   # Warning zone
```

---

## 🗄️ Mobile SQLite Schema (Offline Cache)

```sql
CREATE TABLE cached_imbl_boundaries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    latitude REAL, longitude REAL, sequence_order INTEGER
);

CREATE TABLE cached_weather_grid (
    latitude REAL, longitude REAL,
    wave_height_m REAL, wind_speed_knots REAL,
    forecast_hour TEXT, expires_at TEXT
);

CREATE TABLE cached_pfz_advisories (
    pfz_id TEXT PRIMARY KEY, sector_name TEXT,
    centroid_lat REAL, centroid_lon REAL,
    chlorophyll REAL, geojson_polygon TEXT, valid_until TEXT
);

CREATE TABLE local_chat_history (
    id TEXT PRIMARY KEY, sender TEXT,
    text_localized TEXT, text_english TEXT, timestamp TEXT
);
```

---

## 🧪 Running Tests

```bash
# Backend unit tests
cd backend
pytest tests/ -v

# Specific test suites
pytest tests/test_geospatial.py -v    # A*, grid, distance
pytest tests/test_agents.py -v        # Multi-agent pipeline
pytest tests/test_guardrails.py -v    # Safety invariants

# Flutter tests
cd mobile
flutter test
```

---

## 📅 12-Day Implementation Roadmap

| Day | Layer | Milestone |
|---|---|---|
| **Day 1-3** | 🔴 **GIS Engine** | Coastline + IMBL loading · MarineGrid rasterization · A\* pathfinding · GeoJSON output |
| **Day 4-5** | 🟠 **Multi-Agent** | LangGraph StateGraph · 6 agent nodes · Symbolic guardrail · Emergency override |
| **Day 6-7** | 🟡 **Data Pipeline** | Open-Meteo async client · INCOIS PFZ parser · TTL cache layer · SQLite integration |
| **Day 8** | 🟢 **Voice** | Bhashini ASR → NMT → TTS pipeline · Google Cloud fallback |
| **Day 9-10** | 🔵 **Frontend** | Web dashboard · Flutter HUD · Map layers · Chat sheet integration |
| **Day 11** | 🟣 **Offline** | Pre-voyage pack · sqflite cache · Offline geofence evaluation |
| **Day 12** | ⚪ **Polish** | End-to-end demo rehearsal · UI polish · 3 golden scenarios locked |

---

## 👥 Team Responsibilities

| Member | Domain | Key Files |
|---|---|---|
| **Dev 1** | Geospatial & Math | `geospatial/astar.py`, `grid.py`, `distance.py`, `geofence.py` |
| **Dev 2** | Multi-Agent AI | `agents/graph.py`, `agents/nodes/`, `agents/guardrails/` |
| **Dev 3** | Data Pipeline & Backend Core | `services/open_meteo.py`, `incois_pfz.py`, `cache.py`, `schemas.py` |
| **Dev 4** | Voice & Translation | `services/bhashini.py`, `google_voice.py`, `api/v1/endpoints/voice.py` |
| **Dev 5** | Flutter Mobile | `mobile/lib/views/`, `providers/` |
| **Dev 6** | Flutter Mobile | `mobile/lib/data/`, `core/`, `offline/` |

---

## 📜 License

This project is licensed under the **MIT License** — see [LICENSE](LICENSE) for details.

---

<div align="center">

**Built for ISRO · Smart India Hackathon 2026**

*Protecting India's coastal fishermen through intelligent, multilingual maritime AI*

🌊 **ORCA** — Where satellite data meets the fisherman's voice

</div>
