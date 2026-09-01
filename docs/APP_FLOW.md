# 🔄 ORCA: Mobile Application & Multi-Agent Flow State Machines
> **Project:** ORCA (Marine EcOsystem Reasoning with Collaborative Agents)  
> **Problem Statement ID:** 26176 | **Document:** Flutter Mobile App & Multi-Agent State Flows  

---

## 1. 🌊 Core Mobile User Journeys

### Journey 1: Voice-First PFZ Discovery & Route Guidance
```text
[Fisherman on Boat]
       │
       ▼ (Holds Native Mobile Mic Button)
"புயல் எச்சரிக்கை உள்ளதா? நல்ல மீன்பிடி பகுதி எங்கே?"
       │
       ▼
[Flutter Audio Recording Stream] ──> Encodes WAV Audio
       │
       ▼
[POST /api/v1/chat/message] (FastAPI Gateway)
       │
       ▼
[Bhashini ASR & NMT Pipeline] ──> Standardized English: "Any storm alert? Where is good PFZ?"
       │
       ▼
[LangGraph Intent Classifier] ──> Inferred: [weather, pfz, routing]
       │
       ├───────────────────────────────┬───────────────────────────────┐
       ▼                               ▼                               ▼
[Weather Agent]                [PFZ Agent]                    [Boundary Agent]
- Wave: 1.3m (Calm)            - Extracts PFZ-04 (14km East)  - IMBL Dist: 8.5km (Safe)
       │                               │                               │
       └───────────────────────────────┼───────────────────────────────┘
                                       │
                                       ▼
                              [Routing Agent (A*)]
                              - Generates collision-free GeoJSON LineString
                                       │
                                       ▼
                       [Deterministic Symbolic Guardrail]
                       - Invariant Checks: Wave < 2.5m, Dist > 5km -> PASS
                                       │
                                       ▼
                         [Response Synthesizer & Bhashini TTS]
                         - Synthesizes Tamil Audio + Advisory text
                                       │
                                       ▼
                         [Flutter Mobile Presentation]
                         - Auto-plays Tamil Voice Advice via AudioPlayer
                         - Renders Cyan Route Line on FlutterMap
                         - Highlights Emerald PFZ-04 Polygon
```

---

### Journey 2: Dynamic IMBL Drift Warning & Evasive Action
```text
[Mobile Phone GPS Telemetry: 9.32°N, 79.45°E | Speed: 14 kts | Heading: 120°]
       │
       ▼ (Mobile Background Stream every 3 seconds)
[Dynamic Geofence Engine / Local Dart GeoMath]
       │
       ├─> Calculates 15-min lookahead vector: Δd = 14 * 1.852 * 0.25 = 6.48 km
       ├─> Detects intersection with IMBL LineString
       └─> Projected boundary breach in 6.8 minutes!
       │
       ▼
[Deterministic Emergency Override]
       │
       ├─> Triggers Heavy Mobile Haptic Vibration (`HapticFeedback.heavyImpact`)
       ├─> Sounds High-Priority Emergency Siren
       ├─> Calculates Immediate Evasive Heading: Bearing (Heading - 120°) = 000° (North)
       └─> Plays Localized Urgent TTS Audio: "எச்சரிக்கை! எல்லை நெருங்குகிறது. உடனே வடக்கு நோக்கி திரும்பவும்!"
       │
       ▼
[Flutter Map Tactical View]
       ├─> Flashes Pulsating Red Warning Cone on Vessel Heading Vector
       └─> Immediately Draws Cyan Escape Course towards Coastal Safety Corridor
```

---

## 2. 📱 Flutter Mobile App State Machine

```mermaid
stateDiagram-v2
    [*] --> AppInit: Launch Flutter App
    
    state AppInit {
        [*] --> CheckPermissions: Request GPS & Mic Permissions
        CheckPermissions --> LoadLocalCache: Hydrate SQLite / Hive Database
        LoadLocalCache --> EstablishConnection: Connect REST / WebSocket
    }
    
    AppInit --> TacticalDashboardActive
    
    state TacticalDashboardActive {
        [*] --> IdleListening
        
        IdleListening --> RecordingAudio: User Presses & Holds Hero Mic Button
        RecordingAudio --> UploadingAudio: Mic Button Released
        UploadingAudio --> ProcessingAgentGraph: Audio Sent to FastAPI
        
        ProcessingAgentGraph --> RenderTacticalUpdates: GeoJSON & TTS Received
        RenderTacticalUpdates --> PlayingSpeechAdvisory: Auto-play Audio
        PlayingSpeechAdvisory --> IdleListening: Audio Playback Complete
        
        --
        
        [*] --> LocationStreamTick: GPS Stream Interval (3s)
        LocationStreamTick --> EvaluateGeofenceProximity
        EvaluateGeofenceProximity --> TriggerEmergencyAlarm: Distance < 2km or Imminent Drift
        TriggerEmergencyAlarm --> LocationStreamTick: Threat Averted
    }
```

---

## 3. 💾 Offline Pre-Voyage Storage State Machine

```mermaid
stateDiagram-v2
    [*] --> PreVoyageScreen: User Opens Offline Pack Manager
    
    PreVoyageScreen --> FetchBoundingBox: User Selects Coastal Sector
    FetchBoundingBox --> DownloadingDataPack: Calls /api/v1/marine/offline-pack
    
    state DownloadingDataPack {
        [*] --> SaveBoundaries: Write IMBL & Coastline GeoJSON to SQLite
        SaveBoundaries --> SaveWeatherMatrix: Write 24hr Wave & Wind Grids
        SaveWeatherMatrix --> SavePFZs: Write Active PFZ Polygons
        SavePFZs --> PrecacheAudio: Store Emergency Offline Audio Clips
    }
    
    DownloadingDataPack --> OfflineReady: Status Validated for 24h
    
    OfflineReady --> DeepSeaDisconnectedMode: Vessel Leaves Cellular Range
    
    state DeepSeaDisconnectedMode {
        [*] --> LocalGPSTracking: Native Device Location
        LocalGPSTracking --> LocalHaversineCheck: Dart Math vs SQLite IMBL
        LocalHaversineCheck --> LocalAudioAlarm: Play Pre-cached Audio if Danger
    }
```
