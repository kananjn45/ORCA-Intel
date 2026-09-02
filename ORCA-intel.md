# 🌊 ORCA: Marine EcOsystem Reasoning with Collaborative Agents
> **Problem Statement ID:** 26176 | **Organization:** ISRO | **Smart India Hackathon**

---

## 📌 Executive Summary
**ORCA** is an intelligent, multi-agent marine navigational and advisory platform designed for coastal fishermen, maritime authorities, and marine researchers. Instead of requiring users to manually interpret raw satellite feeds, oceanographic charts, and meteorological bulletins, ORCA coordinates specialized, autonomous AI agents to deliver explainable, safe, and actionable marine intelligence through a regional multilingual interface.

---

## 🏛️ System Architecture

```text
[User Voice / GPS Telemetry]
            │
            ▼
 [Bhashini ASR & NMT Engine]  <── (Speech-to-Text & Translation to English)
            │
            ▼
┌─────────────────────────────────────────────────────────────┐
│               LangGraph Multi-Agent Orchestrator            │
│  - Intent Classification & Task Planning                    │
│  - Shared Agent State Graph Loop                            │
│  - Context & Coordinate Normalization                       │
└──────────────┬───────────────────────────────┬──────────────┘
               │                               │
       ┌───────┴────────┐             ┌────────┴────────┐
       ▼                ▼             ▼                 ▼
[Weather Agent]   [PFZ Agent]   [Boundary Agent]  [Routing Agent]
 (Open-Meteo)    (INCOIS/MOSDAC)  (PostGIS/Shapely)  (NetworkX A*)
       │                │             │                 │
       └───────┬────────┴─────────────┴─────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────┐
│          Deterministic Symbolic Safety Guardrails            │
│  - Non-negotiable boundary distance checks (< 2 km alert)   │
│  - Hard weather limits (Wind > 25 knots / Wave > 2.5m)       │
│  - Zero-Hallucination verification before LLM synthesis     │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
               [Bhashini TTS & Response Generator]
                               │
            ┌──────────────────┴──────────────────┐
            ▼                                     ▼
 [Audio & Text Advice (Voice)]           [Interactive GeoJSON]
 (Tamil / Telugu / Hindi / etc.)         (Routes, PFZs, Hazard Zones)
            │                                     │
            └──────────────────┬──────────────────┘
                               ▼
        [React / Leaflet Web Dashboard & Flutter Client]
```

---

## 🧩 Layer-by-Layer Technical Breakdown (Hard to Easy)

Prioritizing the mathematically and architecturally demanding layers first prevents last-minute integration blockers and ensures safety critical components are rock solid.

```
+-------------------------------------------------------------------------+
| [HARD]    Layer 1: Geospatial Math & A* Pathfinding Engine              |
+-------------------------------------------------------------------------+
| [MED-HD]  Layer 2: Multi-Agent Orchestrator & Symbolic Guardrails       |
+-------------------------------------------------------------------------+
| [MEDIUM]  Layer 3: Marine & Earth Observation Data Pipeline             |
+-------------------------------------------------------------------------+
| [MED-EZ]  Layer 4: Multilingual Voice & Speech Translation (Bhashini)   |
+-------------------------------------------------------------------------+
| [EASY-MD] Layer 5: Frontend Dashboard & Interactive Marine Mapping      |
+-------------------------------------------------------------------------+
| [EASY]    Layer 6: Offline-First Caching & Golden Pitch Scenarios       |
+-------------------------------------------------------------------------+
```

---

### 🔴 Layer 1: Geospatial Math & A* Pathfinding Engine *(Hardest)*
* **Objective:** Ensure mathematically accurate, collision-free sea navigation that strictly avoids restricted zones, land boundaries, and high-hazard weather cells.
* **Key Components:**
  * **Coordinate & Boundary Ingestion:** Load coastline polygons, International Maritime Boundary Lines (IMBL), and Marine Protected Areas (MPAs) into `GeoPandas` and `Shapely`.
  * **Navigable Water Grid Generation:** Construct a 2D coastal graph where land masses, coral reefs, and active storm cells are flagged as unpassable obstacle nodes.
  * **Heuristic Pathfinding:** Implement an $A^*$ search algorithm in `NetworkX` taking `(Start_Lat_Lon, Target_PFZ_Lat_Lon)` and outputting an obstacle-free GeoJSON LineString.
  * **Dynamic Vector Geofencing:** Calculate 15-minute predictive lookahead vectors using vessel speed and drift heading to alert fishermen before an accidental IMBL crossing occurs.

### 🟠 Layer 2: Multi-Agent Orchestration & Symbolic Guardrails *(Hard-Medium)*
* **Objective:** Manage cyclic multi-agent decision logic and enforce absolute zero-hallucination safety policies.
* **Key Components:**
  * **LangGraph State Graph:** Maintain a centralized `AgentState` recording user query, GPS coordinates, retrieved weather metrics, PFZ polygons, and validation flags.
  * **Specialized Agent Nodes:**
    * `IntentClassifier`: Deconstructs complex queries into atomic sub-tasks.
    * `WeatherAgent`: Evaluates local sea state and storm risks.
    * `PFZAgent`: Extracts optimal high-chlorophyll thermal front coordinates.
    * `RoutingAgent`: Requests path generation from Layer 1.
  * **Deterministic Symbolic Guardrail:** An algorithmic barrier that intercepts agent outputs before final LLM synthesis. If raw telemetry exceeds hard safety limits (e.g., wind $> 25	ext{ knots}$, border proximity $< 2	ext{ km}$), safety overrides are enforced regardless of LLM generation.

### 🟡 Layer 3: Marine & Earth Observation Data Pipeline *(Medium)*
* **Objective:** Normalize and cache heterogeneous marine data feeds.
* **Key Components:**
  * **Open-Meteo Marine API Client:** Async ingestion of wave heights, swell period/direction, surface wind speeds, and visibility.
  * **INCOIS / MOSDAC Mock Parser:** Ingests Potential Fishing Zone (PFZ) coordinate polygons, Sea Surface Temperature (SST) gradients, and Chlorophyll-a concentrations.
  * **FastAPI Backend & Caching:** In-memory caching (`Redis` / `SQLite`) to prevent API rate limiting and support low-latency responses during evaluation.

### 🟢 Layer 4: Multilingual Voice & Speech Translation *(Medium-Easy)*
* **Objective:** Provide barrier-free communication for coastal fishermen in their native regional languages.
* **Key Components:**
  * **Bhashini ASR (Speech-to-Text):** Converts spoken Tamil, Telugu, Bengali, Gujarati, or Hindi into text.
  * **Bhashini NMT (Translation):** Translates regional input to standardized English for multi-agent reasoning, and translates synthesized output back into the source language.
  * **Bhashini TTS (Text-to-Speech):** Synthesizes natural spoken voice advisories from translated responses.

### 🔵 Layer 5: Frontend Dashboard & Interactive Marine Mapping *(Easy-Medium)*
* **Objective:** Provide a high-visibility, responsive interface for situational awareness.
* **Key Components:**
  * **Leaflet.js / MapLibre GL Integration:** Displays coastal maps with toggleable layers for IMBL boundaries (Red), PFZ zones (Green), hazard clusters (Orange), and computed $A^*$ routes (Blue).
  * **Conversational Interface:** Voice record/playback controls and a multi-turn chat panel with streaming text support.
  * **Telemetry HUD:** Real-time indicator cards showing vessel speed, nearest boundary distance, current wave height, and wind velocity.

### 🟣 Layer 6: Offline-First Caching & Pitch Scenarios *(Easiest)*
* **Objective:** Ensure uninterrupted operation in zero-connectivity maritime zones and lock in winning demo test cases.
* **Key Components:**
  * **Pre-Voyage Cache Store:** Stores 24-hour weather rasters and boundary vectors locally in browser/app storage before departure.
  * **Golden Pitch Demo Scenarios:**
    1. *Optimal Route Guidance:* Navigation to high-yield PFZ with calm sea state.
    2. *Dynamic Border Warning:* Speed-aware alert preventing an IMBL breach.
    3. *Dynamic Weather Rerouting:* Mid-journey route recalculation avoiding an incoming cyclone cell.

---

## 📅 12-Day Implementation Roadmap

| Day | Focus Layer | Milestones & Deliverables | Primary Tooling |
| :---: | :--- | :--- | :--- |
| **Day 1** | **Layer 1: GIS Foundations** | Load coastline & IMBL shapefiles; implement basic point-in-polygon checks. | `GeoPandas`, `Shapely` |
| **Day 2** | **Layer 1: Navigable Grid** | Build coastal bounding grid; rasterize land & restricted zones as obstacles. | `Shapely`, `NumPy` |
| **Day 3** | **Layer 1: A\* Pathfinding** | Implement $A^*$ route generator; output valid GeoJSON route lines. | `NetworkX`, `GeoJSON` |
| **Day 4** | **Layer 2: Agent Architecture** | Define LangGraph `AgentState` schema, router node, and worker nodes. | `LangGraph`, `FastAPI` |
| **Day 5** | **Layer 2: Symbolic Guardrails** | Implement hard safety override node; eliminate hallucinated coordinates. | Python, `LangGraph` |
| **Day 6** | **Layer 3: Marine Data Client** | Integrate Open-Meteo Marine API client and INCOIS PFZ parser. | `httpx`, `FastAPI` |
| **Day 7** | **Layer 3: Data Integration** | Connect data pipelines to agent state; add SQLite/Redis caching. | `SQLite` / `Redis` |
| **Day 8** | **Layer 4: Voice & Translation** | Integrate Bhashini ASR/NMT/TTS APIs (Voice In $
ightarrow$ Voice Out). | Bhashini API, `requests` |
| **Day 9** | **Layer 5: Map Dashboard** | Build React UI; render map layers (IMBL, PFZ, Storms, $A^*$ Paths). | `React`, `Leaflet.js` |
| **Day 10** | **Layer 5: UI/Backend Integration** | Connect frontend chat & audio recorder to FastAPI SSE/WebSocket stream. | WebSockets, `TailwindCSS` |
| **Day 11** | **Layer 6: Offline Mode & Test Cases** | Implement client-side cache and lock in the 3 Golden Demo scenarios. | LocalStorage / IndexedDB |
| **Day 12** | **Polish & Pitch Rehearsal** | End-to-end dry runs, UI styling polish, and pitch deck finalization. | Presentation Deck |

---

## 🛠️ Complete Technology Stack

* **AI & Agent Orchestration:** LangGraph (Python), Ollama / Groq / Gemini API
* **Geospatial & Pathfinding:** GeoPandas, Shapely, NetworkX, PostGIS
* **Multilingual Localization:** Bhashini API (or Faster-Whisper + IndicTrans2)
* **Backend Services:** FastAPI, Uvicorn, Pydantic, Redis / SQLite
* **Frontend Web Application:** React.js / Next.js, Leaflet.js / MapLibre GL, Tailwind CSS
* **Data Sources & APIs:** Open-Meteo Marine API, INCOIS PFZ Advisories, Marine Regions Boundaries

---

