"""
tests/test_api.py
Owner: Dev 3 (Data Pipeline & Backend Core Engineer)

Automated tests for Dev 3's endpoints. Run with:  pytest -v
Uses FastAPI's TestClient (sync wrapper over httpx) so no real network
calls are made for the endpoints that don't hit Open-Meteo; the weather
tests DO make a real outbound call to the public Open-Meteo API (no key
needed) and gracefully accept the synthetic-fallback response if the
sandbox/CI has no internet access.
"""
import pytest
from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def test_health_check():
    resp = client.get("/health")
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "ok"
    assert "app_name" in body


def test_root():
    resp = client.get("/")
    assert resp.status_code == 200


def test_weather_valid_coords():
    resp = client.get("/api/v1/marine/weather", params={"lat": 9.28, "lon": 79.31})
    assert resp.status_code == 200
    body = resp.json()
    assert "wave_height_m" in body
    assert "wind_speed_knots" in body
    assert 0 <= body["sea_state_code"] <= 9
    assert body["source"] in ("open-meteo", "synthetic-fallback")


def test_weather_invalid_latitude():
    resp = client.get("/api/v1/marine/weather", params={"lat": 200, "lon": 79.31})
    assert resp.status_code == 422


def test_pfz_returns_features():
    resp = client.get("/api/v1/marine/pfz", params={"lat": 9.28, "lon": 79.31, "radius_km": 50})
    assert resp.status_code == 200
    body = resp.json()
    assert isinstance(body, list)
    assert len(body) >= 1
    feature = body[0]
    assert "pfz_id" in feature
    assert "chlorophyll_mg_m3" in feature
    assert feature["geojson_geometry"]["type"] == "Polygon"


def test_pfz_is_deterministic_for_same_query():
    """Same rounded coords + radius => same top zone (demo reproducibility)."""
    r1 = client.get("/api/v1/marine/pfz", params={"lat": 9.28, "lon": 79.31, "radius_km": 50}).json()
    r2 = client.get("/api/v1/marine/pfz", params={"lat": 9.28, "lon": 79.31, "radius_km": 50}).json()
    assert r1[0]["pfz_id"] == r2[0]["pfz_id"]


def test_pfz_invalid_radius():
    resp = client.get("/api/v1/marine/pfz", params={"lat": 9.28, "lon": 79.31, "radius_km": -5})
    assert resp.status_code == 422


def test_offline_pack_valid_bbox():
    resp = client.get(
        "/api/v1/marine/offline-pack",
        params={"min_lat": 8.5, "min_lon": 78.5, "max_lat": 9.0, "max_lon": 79.0, "grid_resolution_deg": 0.5},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["cell_count"] >= 1
    assert body["bounding_box"]["min_lat"] == 8.5
    assert body["imbl_boundary_geojson"]["type"] == "FeatureCollection"


def test_offline_pack_invalid_bbox_order():
    resp = client.get(
        "/api/v1/marine/offline-pack",
        params={"min_lat": 9.0, "min_lon": 78.5, "max_lat": 8.5, "max_lon": 79.0},
    )
    assert resp.status_code == 422


def test_offline_pack_bbox_too_large():
    resp = client.get(
        "/api/v1/marine/offline-pack",
        params={"min_lat": 0, "min_lon": 0, "max_lat": 15, "max_lon": 15},
    )
    assert resp.status_code == 422


def test_cache_stats_endpoint():
    # Warm the cache first.
    client.get("/api/v1/marine/weather", params={"lat": 9.28, "lon": 79.31})
    resp = client.get("/api/v1/marine/cache-stats")
    assert resp.status_code == 200
    body = resp.json()
    assert "weather" in body and "pfz" in body


def test_geofence_check_mock():
    payload = {
        "vessel_id": "TEST-01",
        "latitude": 9.30,
        "longitude": 79.40,
        "speed_knots": 10.0,
        "heading_deg": 90.0,
    }
    resp = client.post("/api/v1/geofence/check", json=payload)
    assert resp.status_code == 200
    body = resp.json()
    assert body["warning_level"] in ("SAFE", "ADVISORY", "WARNING", "CRITICAL")


def test_navigation_route_mock():
    payload = {
        "start_lat": 9.28, "start_lon": 79.31,
        "target_lat": 9.40, "target_lon": 79.55,
    }
    resp = client.post("/api/v1/navigation/route", json=payload)
    assert resp.status_code == 200
    body = resp.json()
    assert body["waypoints_count"] >= 2
    assert body["route_geojson"]["geometry"]["type"] == "LineString"


def test_chat_message_mock():
    payload = {
        "session_id": "test-session",
        "user_query_text": "Where is the best fishing zone?",
        "source_language": "en",
        "telemetry": {
            "vessel_id": "TEST-01",
            "latitude": 9.28,
            "longitude": 79.31,
            "speed_knots": 5,
            "heading_deg": 45,
        },
    }
    resp = client.post("/api/v1/chat/message", json=payload)
    assert resp.status_code == 200
    body = resp.json()
    assert body["session_id"] == "test-session"
    assert "weather_summary" in body


def test_chat_message_invalid_language():
    payload = {
        "session_id": "test-session",
        "user_query_text": "hello",
        "source_language": "xx",
        "telemetry": {"latitude": 9.28, "longitude": 79.31},
    }
    resp = client.post("/api/v1/chat/message", json=payload)
    assert resp.status_code == 422


# ---------------------------------------------------------------------------
# Additional DEV-3 Comprehensive Validation Tests
# ---------------------------------------------------------------------------

def test_weather_missing_parameters():
    # Missing both lat and lon
    resp = client.get("/api/v1/marine/weather")
    assert resp.status_code == 422

    # Missing lon
    resp = client.get("/api/v1/marine/weather", params={"lat": 9.28})
    assert resp.status_code == 422

    # Missing lat
    resp = client.get("/api/v1/marine/weather", params={"lon": 79.31})
    assert resp.status_code == 422


def test_weather_invalid_longitude():
    resp = client.get("/api/v1/marine/weather", params={"lat": 9.28, "lon": 190.0})
    assert resp.status_code == 422

    resp = client.get("/api/v1/marine/weather", params={"lat": 9.28, "lon": -190.0})
    assert resp.status_code == 422


def test_weather_boundary_coordinates():
    # Exactly on boundary: lat 90, lon 180
    resp = client.get("/api/v1/marine/weather", params={"lat": 90.0, "lon": 180.0})
    assert resp.status_code == 200
    assert resp.json()["latitude"] == 90.0

    # Exactly on boundary: lat -90, lon -180
    resp = client.get("/api/v1/marine/weather", params={"lat": -90.0, "lon": -180.0})
    assert resp.status_code == 200
    assert resp.json()["latitude"] == -90.0


def test_pfz_missing_parameters():
    # Missing both
    resp = client.get("/api/v1/marine/pfz")
    assert resp.status_code == 422

    # Missing lat
    resp = client.get("/api/v1/marine/pfz", params={"lon": 79.31})
    assert resp.status_code == 422


def test_pfz_invalid_coordinates():
    resp = client.get("/api/v1/marine/pfz", params={"lat": 100.0, "lon": 79.31})
    assert resp.status_code == 422

    resp = client.get("/api/v1/marine/pfz", params={"lat": 9.28, "lon": 200.0})
    assert resp.status_code == 422


def test_offline_pack_missing_parameters():
    # Missing max_lon
    resp = client.get("/api/v1/marine/offline-pack", params={"min_lat": 8.5, "min_lon": 78.5, "max_lat": 10.5})
    assert resp.status_code == 422


def test_offline_pack_invalid_coordinates():
    resp = client.get("/api/v1/marine/offline-pack", params={"min_lat": -95.0, "min_lon": 78.5, "max_lat": 10.5, "max_lon": 80.5})
    assert resp.status_code == 422


def test_open_meteo_fallback_on_network_error(monkeypatch):
    """When external Open-Meteo service fails, the API should return deterministic fallback without crashing."""
    from app.services import open_meteo
    from app.services.open_meteo import OpenMeteoServiceError

    async def mock_fetch_failure(latitude: float, longitude: float):
        raise OpenMeteoServiceError("Simulated upstream network timeout")

    monkeypatch.setattr(open_meteo, "_fetch_live_weather", mock_fetch_failure)

    # Use unique coords so cache isn't hit
    resp = client.get("/api/v1/marine/weather", params={"lat": 11.44, "lon": 79.88})
    assert resp.status_code == 200
    body = resp.json()
    assert body["source"] == "synthetic-fallback"
    assert "[SYNTHETIC" in body["advisory_summary"]
    assert "wave_height_m" in body
    assert "wind_speed_knots" in body


def test_pydantic_schemas_contract():
    """Verify all Pydantic schemas defined in BACKEND_SCHEMA.md instantiate correctly with expected fields."""
    from datetime import datetime
    from app.models.schemas import (
        TelemetryPayload,
        GeofenceStatus,
        MarineWeatherMetric,
        PFZFeature,
        RouteCalculationRequest,
        RouteCalculationResponse,
        ChatQueryRequest,
        GuardrailValidationReport,
        ChatQueryResponse,
        OfflinePackResponse,
    )

    t = TelemetryPayload(latitude=9.28, longitude=79.31, speed_knots=8.5, heading_deg=85.0)
    assert t.vessel_id == "VESSEL-IND-01"

    g = GeofenceStatus(
        distance_to_imbl_km=4.2,
        nearest_imbl_point={"lat": 9.35, "lon": 79.42},
        lookahead_breach_projected=False,
        time_to_breach_minutes=18.5,
        warning_level="SAFE",
        evasive_heading_deg=270.0,
    )
    assert g.warning_level == "SAFE"

    m = MarineWeatherMetric(
        latitude=9.28,
        longitude=79.31,
        wave_height_m=1.4,
        wave_direction_deg=140.0,
        wave_period_sec=6.5,
        wind_speed_knots=12.2,
        wind_direction_deg=120.0,
        swell_wave_height_m=1.1,
        sea_surface_temp_celsius=28.4,
        sea_state_code=3,
        is_safe_for_small_craft=True,
        advisory_summary="Moderate breeze, safe for mechanized crafts.",
    )
    assert m.sea_state_code == 3

    p = PFZFeature(
        pfz_id="PFZ-TN-20260827-004",
        sector_name="Palk Bay South",
        centroid={"lat": 9.42, "lon": 79.55},
        distance_km=14.2,
        bearing_deg=65.0,
        chlorophyll_mg_m3=1.25,
        sst_gradient_celsius=0.85,
        depth_m=22.0,
        valid_until=datetime.utcnow(),
        geojson_geometry={"type": "Polygon", "coordinates": [[[79.5, 9.4], [79.6, 9.4], [79.6, 9.5], [79.5, 9.4]]]},
    )
    assert p.pfz_id == "PFZ-TN-20260827-004"

    req = RouteCalculationRequest(start_lat=9.28, start_lon=79.31, target_lat=9.42, target_lon=79.55)
    assert req.vessel_draft_m == 1.5

    res = RouteCalculationResponse(
        route_id="ROUTE-001",
        total_distance_km=25.0,
        total_distance_nautical_miles=13.5,
        estimated_duration_hours=2.1,
        waypoints_count=5,
        route_geojson={"type": "Feature", "geometry": {"type": "LineString", "coordinates": [[79.31, 9.28], [79.55, 9.42]]}},
        has_weather_penalties=False,
        min_distance_to_imbl_along_route_km=3.5,
        is_safe=True,
    )
    assert res.is_safe is True

    cq_req = ChatQueryRequest(
        session_id="session-001",
        user_query_text="Where are the fish?",
        source_language="ta",
        telemetry=t,
    )
    assert cq_req.source_language == "ta"

    gr = GuardrailValidationReport(
        passed=True,
        checks_evaluated=["imbl_distance_check", "weather_safety_check"],
        violations=[],
        emergency_action_triggered=False,
    )
    assert gr.passed is True

    cq_res = ChatQueryResponse(
        session_id="session-001",
        translated_query_en="Where are the fish?",
        response_text_en="Active PFZ available 14km east.",
        response_text_localized="14 கிமீ கிழக்கே மீன்பிடி மண்டலம் உள்ளது.",
        guardrail_report=gr,
        geofence_status=g,
    )
    assert cq_res.session_id == "session-001"


def test_offline_pack_contains_imbl_geojson_features():
    resp = client.get(
        "/api/v1/marine/offline-pack",
        params={"min_lat": 8.5, "min_lon": 78.5, "max_lat": 9.0, "max_lon": 79.0, "grid_resolution_deg": 0.5},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["imbl_boundary_geojson"]["type"] == "FeatureCollection"
    assert len(body["imbl_boundary_geojson"].get("features", [])) >= 2


def test_navigation_astar_obstacle_avoidance_endpoint():
    resp = client.post(
        "/api/v1/navigation/route",
        json={
            "start_lat": 9.28,
            "start_lon": 79.31,
            "target_lat": 9.42,
            "target_lon": 79.55,
            "vessel_draft_m": 1.5,
            "avoid_high_waves": True,
            "min_imbl_buffer_km": 2.0,
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["route_id"].startswith("ORCA-ROUTE-")
    assert body["total_distance_km"] > 0
    assert body["waypoints_count"] >= 2
    assert body["route_geojson"]["geometry"]["type"] == "LineString"
    assert body["min_distance_to_imbl_along_route_km"] > 0
    assert isinstance(body["is_safe"], bool)


def test_chat_endpoint_populates_active_route_and_geofence():
    resp = client.post(
        "/api/v1/chat/message",
        json={
            "session_id": "test-dev-bridge",
            "user_query_text": "Find nearest safe fishing zone and plot route",
            "source_language": "en",
            "telemetry": {
                "latitude": 9.28,
                "longitude": 79.31,
                "speed_knots": 8.0,
                "heading_deg": 85.0,
            },
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["geofence_status"]["distance_to_imbl_km"] > 0
    assert body["active_route"] is not None
    assert body["active_route"]["total_distance_km"] > 0
    assert len(body["recommended_pfzs"]) > 0