"""
app/models/db_models.py
Owner: Dev 3 (Data Pipeline & Backend Core Engineer)
Day: 1

SQLite table schemas for the offline pre-voyage cache.
These match the sqflite tables on the Flutter side (docs/BACKEND_SCHEMA.md).

In this hackathon build we use plain dicts + JSON serialization written via
the cache.py TTL store (in-memory). The SQLite persistence layer is wired
in Day 7 (docs/ORCA-intel.md roadmap). These dataclass definitions act as
the schema contract so Dev 6 (Flutter / sqflite) can build the mobile-side
tables against the exact same column names.
"""
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Dict, List, Optional


# ---------------------------------------------------------------------------
# cached_weather_grid
# One row per (lat_rounded, lon_rounded) grid cell stored in the offline pack.
# ---------------------------------------------------------------------------
@dataclass
class CachedWeatherRow:
    """Maps to: CREATE TABLE cached_weather_grid (...)"""
    id: Optional[int] = field(default=None)
    lat_rounded: float = 0.0
    lon_rounded: float = 0.0
    wave_height_m: float = 0.0
    wind_speed_knots: float = 0.0
    wave_direction_deg: float = 0.0
    wave_period_sec: float = 0.0
    swell_wave_height_m: float = 0.0
    sea_surface_temp_celsius: float = 0.0
    sea_state_code: int = 0
    is_safe_for_small_craft: bool = True
    advisory_summary: str = ""
    source: str = "open-meteo"
    observed_at: datetime = field(default_factory=datetime.utcnow)
    expires_at: datetime = field(default_factory=datetime.utcnow)
    pack_id: str = ""   # ties this row to an OfflinePack download batch


# ---------------------------------------------------------------------------
# cached_pfz_advisories
# One row per PFZ feature polygon stored in the offline pack.
# ---------------------------------------------------------------------------
@dataclass
class CachedPFZRow:
    """Maps to: CREATE TABLE cached_pfz_advisories (...)"""
    id: Optional[int] = field(default=None)
    pfz_id: str = ""
    sector_name: str = ""
    centroid_lat: float = 0.0
    centroid_lon: float = 0.0
    distance_km: float = 0.0
    bearing_deg: float = 0.0
    chlorophyll_mg_m3: float = 0.0
    sst_gradient_celsius: float = 0.0
    depth_m: float = 0.0
    geojson_geometry: str = "{}"   # JSON string of the Polygon geometry
    source: str = "incois-mock"
    valid_until: datetime = field(default_factory=datetime.utcnow)
    pack_id: str = ""


# ---------------------------------------------------------------------------
# cached_imbl_boundaries
# Stores the IMBL / EEZ / MPA boundary vectors for offline distance checks.
# Populated from Dev 1's app/geospatial/shapefile_loader.py during Day 3.
# ---------------------------------------------------------------------------
@dataclass
class CachedIMBLRow:
    """Maps to: CREATE TABLE cached_imbl_boundaries (...)"""
    id: Optional[int] = field(default=None)
    boundary_type: str = "IMBL"   # IMBL | EEZ | MPA | COASTLINE
    feature_name: str = ""
    geojson_geometry: str = "{}"  # JSON string of Polygon / LineString
    source: str = "placeholder"
    downloaded_at: datetime = field(default_factory=datetime.utcnow)


# ---------------------------------------------------------------------------
# SQLite DDL strings (used by init_db.py)
# ---------------------------------------------------------------------------
SCHEMA_DDL: List[str] = [
    """
    CREATE TABLE IF NOT EXISTS cached_weather_grid (
        id                      INTEGER PRIMARY KEY AUTOINCREMENT,
        pack_id                 TEXT NOT NULL,
        lat_rounded             REAL NOT NULL,
        lon_rounded             REAL NOT NULL,
        wave_height_m           REAL,
        wind_speed_knots        REAL,
        wave_direction_deg      REAL,
        wave_period_sec         REAL,
        swell_wave_height_m     REAL,
        sea_surface_temp_celsius REAL,
        sea_state_code          INTEGER,
        is_safe_for_small_craft INTEGER,
        advisory_summary        TEXT,
        source                  TEXT,
        observed_at             TEXT,
        expires_at              TEXT
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS cached_pfz_advisories (
        id                      INTEGER PRIMARY KEY AUTOINCREMENT,
        pack_id                 TEXT NOT NULL,
        pfz_id                  TEXT NOT NULL,
        sector_name             TEXT,
        centroid_lat            REAL,
        centroid_lon            REAL,
        distance_km             REAL,
        bearing_deg             REAL,
        chlorophyll_mg_m3       REAL,
        sst_gradient_celsius    REAL,
        depth_m                 REAL,
        geojson_geometry        TEXT,
        source                  TEXT,
        valid_until             TEXT
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS cached_imbl_boundaries (
        id                      INTEGER PRIMARY KEY AUTOINCREMENT,
        boundary_type           TEXT NOT NULL,
        feature_name            TEXT,
        geojson_geometry        TEXT,
        source                  TEXT,
        downloaded_at           TEXT
    )
    """,
]
