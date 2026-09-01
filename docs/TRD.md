# ⚙️ ORCA: Technical Requirements Document (TRD)
> **Project:** ORCA (Marine EcOsystem Reasoning with Collaborative Agents)  
> **Problem Statement ID:** 26176 | **Target Audience:** Engineering & Dev Team  
> **Client Platform:** Flutter 3.x (Dart) Mobile App (Android / iOS)  
> **Backend Platform:** Python 3.11+, FastAPI, LangGraph, Uvicorn, GeoPandas, NetworkX  
> **Version:** 1.0.0  

---

## 1. 🏗️ High-Level Technical Architecture

ORCA employs a **Neuro-Symbolic, Multi-Agent Hybrid Architecture** coupled with an **Offline-First Flutter Mobile Client**.

```text
                                  ┌────────────────────────┐
                                  │   Flutter Mobile App   │
                                  │ (Android / iOS / PWA)  │
                                  │ - Flutter Map / Native │
                                  │ - Riverpod / Provider  │
                                  │ - SQLite / Hive Cache  │
                                  │ - Audio Stream / Mic   │
                                  └───────────┬────────────┘
                                              │
                       ┌──────────────────────┴──────────────────────┐
                       │ REST / WebSockets / SSE (FastAPI Gateway)   │
                       └──────────────────────┬──────────────────────┘
                                              │
         ┌────────────────────────────────────┼────────────────────────────────────┐
         │                                    │                                    │
         ▼                                    ▼                                    ▼
┌──────────────────┐               ┌──────────────────────┐               ┌──────────────────┐
│  Bhashini Audio  │               │   Multi-Agent Graph  │               │  Geospatial GIS  │
│  Proxy Engine    │               │  (LangGraph Engine)  │               │  Math Engine     │
│ - ASR (Speech)   │               │ - Intent Classifier  │               │ - Shapely/GeoPan │
│ - NMT (Translate)│               │ - Weather Agent      │               │ - NetworkX A*    │
│ - TTS (Voice)    │               │ - PFZ Agent          │               │ - Lookahead Vec  │
└──────────────────┘               │ - Boundary Agent     │               └──────────────────┘
                                   │ - Routing Agent      │
                                   └──────────┬───────────┘
                                              │
                                              ▼
                                   ┌──────────────────────┐
                                   │ Deterministic Safety │
                                   │ Symbolic Guardrail   │
                                   │ (Hard Code Overrides)│
                                   └──────────┬───────────┘
                                              │
                                              ▼
                                   ┌──────────────────────┐
                                   │ Response Synthesizer │
                                   │ (Bounded Generator)  │
                                   └──────────────────────┘
```

---

## 2. 📱 Flutter Mobile Client Architecture

### 2.1 Mobile Technology Stack
- **Framework:** Flutter 3.x (Dart 3.x)
- **State Management:** `flutter_riverpod` or `provider`
- **Mapping Engine:** `flutter_map` (Leaflet port for Flutter) or `maplibre_gl`
- **Local Persistence & Offline:** `sqflite` (relational offline cache) and `hive` / `shared_preferences` (fast key-value cache)
- **Audio Capture & Playback:** `record` (WAV/PCM streaming) and `audioplayers` / `just_audio`
- **GPS Telemetry:** `geolocator` and `flutter_compass` (real-time bearing and speed tracking)
- **HTTP / WebSockets:** `dio` and `web_socket_channel`

### 2.2 Mobile Clean Architecture Layers
```text
mobile/lib/
├── core/             # Design constants, theme tokens, network clients, geo math helpers
├── data/             # Models (DTOs), local SQLite database helpers, repositories
├── providers/        # Riverpod/Provider state controllers (Telemetry, Map, Chat, Alerts)
└── views/            # UI Screens (Dashboard, Tactical Map, Voice Chat Sheet, Offline Sync)
```

---

## 3. 🤖 LangGraph Multi-Agent State Machine

### 3.1 State Graph Topology
```text
                [START]
                   │
                   ▼
         [IntentClassifierNode]
                   │
         ┌─────────┼─────────┬─────────┐
         ▼         ▼         ▼         ▼
     [Weather]   [PFZ]   [Boundary] [Routing]
     [ Agent ]  [Agent]  [ Agent  ] [ Agent ]
         │         │         │         │
         └─────────┼─────────┴─────────┘
                   │
                   ▼
       [SymbolicGuardrailNode]  <── (Hard Deterministic GIS/Weather Rules)
                   │
                   ├────────────────────────┐
        (Passes Guardrails)         (Hard Safety Trip: e.g., Wave > 2.5m, IMBL < 2km)
                   │                        │
                   ▼                        ▼
         [ResponseSynthesizer]      [EmergencyOverrideNode]
                   │                        │
                   └──────────┬─────────────┘
                              │
                              ▼
                            [END]
```

### 3.2 Shared `AgentState` Definition
```python
from typing import TypedDict, List, Dict, Any, Optional

class AgentState(TypedDict):
    # User Input & Session Context
    session_id: str
    raw_query: str
    source_language: str  # 'ta', 'te', 'hi', 'bn', 'gu', 'en'
    translated_query: str  # Standardized English for agents
    
    # Telemetry
    vessel_lat: float
    vessel_lon: float
    vessel_speed_knots: float
    vessel_heading_deg: float
    timestamp: str
    
    # Inferred Intent Slots
    intents: List[str]  # e.g., ["find_pfz", "check_weather", "route_to_target"]
    target_destination: Optional[Dict[str, float]]  # {"lat": float, "lon": float}
    
    # Sub-Agent Outputs
    weather_data: Optional[Dict[str, Any]]
    pfz_features: Optional[List[Dict[str, Any]]]
    boundary_metrics: Optional[Dict[str, Any]]
    route_geojson: Optional[Dict[str, Any]]
    
    # Symbolic Guardrail Flags
    guardrail_passed: bool
    safety_violations: List[str]
    emergency_action_required: bool
    emergency_advisory: Optional[str]
    
    # Final Synthesized Outputs
    english_response: str
    localized_response: str
    audio_base64: Optional[str]
    suggested_actions: List[str]
```

---

## 4. 🛡️ Deterministic Neuro-Symbolic Safety Guardrails

### 4.1 Invariant Rules Matrix
| Invariant Parameter | Safe Threshold | Critical Danger Threshold | Symbolic Action |
| :--- | :--- | :--- | :--- |
| **Distance to IMBL ($d_{\text{IMBL}}$)** | $\ge 5.0\text{ km}$ | $< 2.0\text{ km}$ | **HALT**: Immediate Emergency Alarm, generate 180° retreat vector. |
| **Lookahead Vector Collision ($t_{15}$)** | No intersection | Intersects IMBL in $\le 15\text{ min}$ | **ALERT**: Warning chime, generate evasive bearing adjustment. |
| **Significant Wave Height ($H_s$)** | $\le 2.0\text{ m}$ | $> 2.5\text{ m}$ | **PROHIBIT**: Block open sea route, recommend return to nearest harbor. |
| **Surface Wind Speed ($v_{\text{wind}}$)** | $\le 20\text{ knots}$ | $> 25\text{ knots}$ | **WARNING**: Issue squall alert, disable distant PFZ suggestions. |
| **Marine Protected Area (MPA)** | Outside buffer | Inside MPA Polygon | **REJECT**: Route invalid, reroute around MPA perimeter. |

---

## 5. 📐 Geospatial Mathematics & Pathfinding

### 5.1 Dynamic Speed-Drift Lookahead Vector
Given mobile GPS speed $v$ (in knots, converted to $\text{km/h}$ by $1.852$), heading $\theta$ (degrees), and lookahead time $\Delta t = 0.25\text{ hours}$ (15 minutes):
$$\Delta d = v \times 1.852 \times \Delta t \quad (\text{km})$$
$$\phi_{\text{lookahead}} = \phi_1 + \left(\frac{\Delta d}{R}\right) \cos(\theta)$$
$$\lambda_{\text{lookahead}} = \lambda_1 + \left(\frac{\Delta d}{R \cos(\phi_1)}\right) \sin(\theta)$$

Intersection testing is performed in Python with `Shapely.intersects()` and replicated natively in Dart for offline client execution.

### 5.2 Marine $A^*$ Pathfinding Formulation
- **Grid Representation:** Discretized bounding box $G = (V, E)$ over coastal waters with step resolution $\Delta = 0.01^\circ \approx 1.11\text{ km}$.
- **Obstacle Rasterization:**
  $$\text{NodeCost}(u) = \begin{cases} \infty & \text{if } u \in \text{Land} \lor u \in \text{MPA} \lor H_s(u) > 2.5\text{ m} \\ 1.0 + \alpha \cdot H_s(u) + \beta \cdot e^{-d_{\text{IMBL}}(u)} & \text{otherwise} \end{cases}$$
- **$A^*$ Evaluation Function:**
  $$f(n) = g(n) + h(n)$$

---

## 6. 🌐 External API Integrations & Data Feeds

1. **Open-Meteo Marine API:** Hourly significant wave height ($H_s$), wave direction, swell period, wind speed, and sea temperature.
2. **INCOIS / MOSDAC PFZ Ingestion:** Chlorophyll-a front boundaries ($0.2 - 2.0\text{ mg/m}^3$), SST gradient thermal fronts ($\ge 0.75^\circ\text{C}$), depth contours.
3. **Bhashini Voice Services:** ULCA ASR, NMT (Indic $\leftrightarrow$ English), and TTS endpoints across Tamil, Telugu, Hindi, Bengali, Gujarati.

---

## 7. 💾 Mobile Offline Storage & Synchronization Lifecycle

```text
[Online Mode at Harbor]
  │
  └─> User taps "Download 24h Pre-Voyage Pack"
        └─> Mobile Client calls GET /api/v1/marine/offline-pack
              └─> Stores boundaries.geojson, 24h weather matrix, and PFZs in SQLite
                    └─> Pre-renders emergency offline audio alerts

[Offline Mode on High Seas]
  │
  ├─> Flutter geolocator stream receives raw GPS coordinates
  ├─> Local Dart geo_math evaluates Haversine distance to cached IMBL lines
  ├─> Local Dart evaluator inspects wave heights from cached hourly forecast
  └─> If distance < 2km, Flutter plays local emergency audio siren
```
