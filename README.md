# 🌊 ORCA: Marine EcOsystem Reasoning with Collaborative Agents
> **ISRO Problem Statement ID:** 26176 | **Smart India Hackathon**  
> **Client Platform:** Flutter Mobile Application (Android / iOS)  
> **Backend Platform:** Python FastAPI & LangGraph Multi-Agent Architecture  

ORCA is an AI-powered maritime conversational assistant and navigation mobile platform that translates complex satellite Earth Observation (EO) data, oceanographic forecasts, and boundary feeds into actionable, safe advice for coastal fishermen and authorities in regional Indian languages.

---

## 📁 Repository Directory Structure

```text
ORCA-Intel/
├── docs/                                # Core Engineering & Architectural Blueprints
│   ├── PRD.md                           # Product Requirements Document
│   ├── TRD.md                           # Technical Requirements Document
│   ├── UI_UX_DESIGN.md                  # Mobile UI/UX Design System & Wireframes
│   ├── APP_FLOW.md                      # Application & Multi-Agent Flow State Machines
│   ├── BACKEND_SCHEMA.md                # Data Models, SQLite Schemas & API Contracts
│   ├── GEOSPATIAL.md                    # Geospatial Math, Lookahead & A* Pathfinding Blueprint
│   └── IMPLEMENTATION_PLAN.md           # 5-Day Sprint Plan for 6 Team Members
│
├── backend/                             # Python FastAPI & LangGraph Backend
│   ├── app/
│   │   ├── api/
│   │   │   └── v1/
│   │   │       ├── endpoints/
│   │   │       │   ├── chat.py          # Multimodal & voice chat endpoint
│   │   │       │   ├── navigation.py    # A* marine pathfinding endpoint
│   │   │       │   ├── marine_data.py   # Weather, SST & Chlorophyll-a feeds
│   │   │       │   ├── geofence.py      # IMBL distance & lookahead evaluation
│   │   │       │   └── voice.py         # Bhashini ASR/TTS proxy
│   │   │       └── router.py            # API V1 Master Router
│   │   ├── core/                        # System configuration & logging
│   │   │   ├── config.py                # Environment & hyperparameter configs
│   │   │   ├── security.py              # Auth & rate limits
│   │   │   └── logging.py               # Structured logger
│   │   ├── agents/                      # LangGraph Multi-Agent System
│   │   │   ├── state.py                 # AgentState TypedDict definition
│   │   │   ├── graph.py                 # StateGraph builder & compiled runnable
│   │   │   ├── guardrails/              # Deterministic Symbolic Guardrails
│   │   │   │   ├── symbolic_verifier.py # Zero-hallucination verification engine
│   │   │   │   ├── weather_limits.py    # Meteorological invariant checks
│   │   │   │   └── boundary_rules.py    # IMBL proximity validator
│   │   │   └── nodes/                   # Specialized agent worker nodes
│   │   │       ├── intent_classifier.py # Query decomposition & slot extraction
│   │   │       ├── weather_agent.py     # Sea state & swell evaluator
│   │   │       ├── pfz_agent.py         # Potential Fishing Zone locator
│   │   │       ├── boundary_agent.py    # Geodesic distance calculator
│   │   │       ├── routing_agent.py     # Marine pathfinding invocator
│   │   │       └── synthesizer.py       # Constrained LLM response generator
│   │   ├── geospatial/                  # GIS Math & Pathfinding Algorithms
│   │   │   ├── grid.py                  # 2D Water rasterization & obstacle grid
│   │   │   ├── astar.py                 # Marine A* heuristic search engine
│   │   │   ├── geofence.py              # Dynamic speed-drift lookahead vectors
│   │   │   ├── shapefile_loader.py      # IMBL, MPA & Coastline GeoJSON parser
│   │   │   └── distance.py              # Haversine & Geodesic calculators
│   │   ├── services/                    # External API Clients & Caching
│   │   │   ├── open_meteo.py            # Open-Meteo Marine API client
│   │   │   ├── incois_pfz.py            # INCOIS/MOSDAC PFZ feed parser
│   │   │   ├── bhashini.py              # Bhashini ASR/NMT/TTS API client
│   │   │   └── cache.py                 # Redis / SQLite cache layer
│   │   ├── models/                      # Pydantic & GeoJSON Models
│   │   │   ├── schemas.py               # Request/Response DTOs
│   │   │   ├── db_models.py             # Database entity models
│   │   │   └── geojson_models.py        # GeoJSON FeatureCollection schemas
│   │   └── db/                          # Database connection & init
│   │       ├── session.py
│   │       └── init_db.py
│   ├── data/                            # Static GIS Shapefiles & Sample Datasets
│   │   ├── boundaries/                  # GeoJSON boundaries (IMBL, EEZ, MPAs)
│   │   └── samples/                     # Mock INCOIS PFZ advisory data
│   ├── tests/                           # Unit & integration test suites
│   ├── requirements.txt                 # Backend dependencies
│   ├── Dockerfile                       # Container deployment definition
│   └── main.py                          # Application entrypoint
│
└── mobile/                              # Flutter Mobile Application (iOS & Android)
    ├── assets/                          # App icons, audio chimes, static boundaries
    │   ├── icons/
    │   ├── audio/
    │   ├── boundaries/
    │   └── fonts/
    ├── lib/
    │   ├── core/                        # Themes, network clients, geo math
    │   │   ├── constants/               # Colors, endpoints, parameters
    │   │   ├── theme/                   # Tactical Dark & Sunlight Deck themes
    │   │   ├── network/                 # Dio HTTP & WebSocket clients
    │   │   └── utils/                   # Haversine & audio player helpers
    │   ├── data/                        # Local SQLite database & repositories
    │   │   ├── models/                  # Dart DTOs (Telemetry, PFZ, Weather)
    │   │   ├── local/                   # Sqflite database & cache manager
    │   │   └── repositories/            # Marine, Chat, Voice repositories
    │   ├── providers/                   # State Management (Riverpod / Provider)
    │   │   ├── telemetry_provider.dart
    │   │   ├── marine_map_provider.dart
    │   │   ├── voice_chat_provider.dart
    │   │   ├── geofence_alert_provider.dart
    │   │   └── offline_sync_provider.dart
    │   ├── views/                       # UI Screens & Widgets
    │   │   ├── dashboard/               # Main tactical HUD screen
    │   │   ├── map/                     # FlutterMap & vector layer widgets
    │   │   ├── chat/                    # Voice recording sheet & message cards
    │   │   └── offline/                 # Pre-voyage pack downloader screen
    │   └── main.dart                    # Flutter entrypoint
    ├── test/                            # Flutter widget & unit tests
    └── pubspec.yaml                     # Flutter package dependencies
```
