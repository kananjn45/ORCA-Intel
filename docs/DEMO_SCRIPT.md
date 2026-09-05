# 🎬 ORCA Prototype: 3 Golden Pitch Scenarios & Jury Demonstration Guide
> **ISRO Problem Statement ID:** 26176 | **Project:** ORCA (Marine Ecosystem Reasoning with Collaborative Agents)  
> **Evaluation Focus:** Multilingual Voice Intelligence, Offline-First Maritime Resilience, Deterministic Zero-Hallucination Guardrails.

---

## 🚀 Quick Launch

1. **Start Backend & Web Dashboard:**
   ```powershell
   ./run_prototype.ps1
   ```
   *FastAPI boots on `http://localhost:8000`, API Docs at `http://localhost:8000/docs`, and the Leaflet dashboard opens.*

2. **Start Flutter Mobile App:**
   ```bash
   cd mobile
   flutter run
   ```

---

## 🌟 Scenario 1: High-Yield PFZ Discovery & Calm Routing (Multilingual Voice)

### Context
A Tamil fisherman in Palk Bay taps the push-to-talk mic and asks for the best fishing zone.

### Actions
1. In the Mobile App (or Web Dashboard), tap the **Microphone** or select quick prompt: **"Nearest PFZ"** (or in Tamil: *"அருகிலுள்ள நல்ல மீன்பிடி மண்டலம் எங்கே?"*).
2. The request routes through:
   - **Dev 4 (Bhashini ASR):** Spoken audio transcribed into Tamil text.
   - **Dev 4 (Bhashini NMT):** Translates to English for multi-agent reasoning.
   - **Dev 2 (LangGraph Multi-Agent):** `IntentClassifier` dispatches to `PFZAgentNode` and `WeatherAgentNode`.
   - **Dev 3 (INCOIS & Open-Meteo):** Identifies PFZ Sector 04 ($14.2\text{ km}$ offshore, chlorophyll $1.25\text{ mg/m}^3$), checks sea state ($1.1\text{ m}$ swell, safe).
   - **Dev 1 (A* Pathfinding):** Calculates obstacle-avoiding maritime route avoiding shallow shoals and IMBL buffer.
   - **Dev 2 (Symbolic Guardrails):** Enforces $d_{\text{IMBL}} > 2\text{ km}$ and wave height $< 2.0\text{ m}$ verification.
   - **Dev 4 (Bhashini TTS):** Synthesizes localized Tamil spoken audio advisory.

### Expected Visual & Audio Output
- **Map:** Animated cyan dashed line from vessel to PFZ polygon with green chlorophyll gradient.
- **HUD:** "PFZ Active · 14.2 km Bearing 65°".
- **Audio:** Localized voice advice plays through phone speaker: *"அருகிலுள்ள மீன்பிடி மண்டலம் 14 கிமீ தொலைவில் உள்ளது..."*

---

## ⚠️ Scenario 2: Dynamic IMBL Drift Emergency Warning & 180° Evasion

### Context
Vessel is drifting or trawling at 11.2 knots heading directly towards the Sri Lankan maritime boundary.

### Actions
1. On the Mobile HUD, tap the **"TEST SCENARIO SIMULATOR"** button.
2. Select **Scenario 3: Border Breach Danger (1.4 km to border!)**.
3. Telemetry updates:
   - Coordinates: `9.345° N, 79.412° E`, Heading: `90°`, Speed: `11.2 kts`.
   - Dev 1's 15-minute speed/drift lookahead vector projects an imminent international maritime boundary breach within 8 minutes.

### Expected Visual & Audio Output
- **HUD Bar:** Flashes **CRITICAL RED** (`WARNING_LEVEL: CRITICAL`).
- **Lookahead Vector:** Red projected velocity ribbon crossing the IMBL buffer.
- **Haptic & Buzzer:** Emergency vibration pattern triggered.
- **Safety Preemption:** `EmergencyOverrideNode` kicks in, bypassing normal conversational chit-chat to display:
  > **"CRITICAL BORDER BREACH ALERT! Steer 270° (Due West) immediately to remain in Indian sovereign waters."**
- **Course Line:** Magenta evasive course drawn returning the boat to safety.

---

## 📴 Scenario 3: Mid-Sea Cyclone Rerouting & High-Seas Disconnected Mode

### Context
The boat is miles offshore with **zero mobile data / cellular connectivity**. A sudden weather front develops.

### Actions
1. **Pre-Voyage:** In the harbor, crew opened the **"Pre-Voyage Sync"** sheet and downloaded the **24-Hour Offline Marine Pack** (stored in local SQLite `sqflite` database).
2. **At Sea:** Turn phone to **Airplane Mode** (or disconnect Wi-Fi/LTE).
3. On the HUD Simulator, tap **"Scenario 4: High Seas Cyclone & Shelter Harbor"**.
4. The mobile app automatically switches to **Zero-Internet Local Failover Mode**:
   - `OfflineCacheManager` evaluates boat position against local SQLite-stored IMBL line segments using local pure-Dart Haversine formulas.
   - Weather raster grid cached locally alerts crew to a $2.8\text{ m}$ wave cell.
   - App computes bearing to nearest sheltered harbor (Rameswaram).

### Expected Visual & Audio Output
- Offline indicator banner: **"OFFLINE MODE: Using Onboard Satellite/SQLite Engine"**.
- Map renders offline cached IMBL vector boundary lines and safe return course to harbor.
- Pre-cached local emergency sirens and advisories trigger without network latency.

---

## 🏆 Key Architectural Talking Points for Judges

1. **Deterministic Guardrails Over Raw LLMs:**
   Safety-critical maritime decisions never rely on probabilistic hallucination. Symbolic verifiers enforce non-negotiable maritime boundaries.
2. **Decoupled 6-Developer Architecture:**
   Geospatial algorithms (Dev 1), LangGraph AI (Dev 2), Data ingestion (Dev 3), Bhashini speech (Dev 4), Web GIS (Dev 5), and Flutter UX (Dev 6) communicate strictly through typed Pydantic/Dart contracts.
3. **100% Automated Test Coverage:**
   - 125 backend pytest tests (geospatial, multi-agent, Bhashini speech, API endpoints).
   - 13 mobile Flutter unit and widget tests.
