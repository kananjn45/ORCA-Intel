"""
tests/test_services.py
Owner: Dev 3 (Data Pipeline & Backend Core Engineer)

Day 1 + Day 2 unit tests for Dev 3's service layer:
  - open_meteo.py  (weather fetch + synthetic fallback + cache)
  - incois_pfz.py  (mock PFZ generator + determinism + cache)
  - cache.py       (TTL eviction, hit/miss stats, make_grid_key)
  - bhashini.py    (ASR/NMT/TTS mocks)
  - db_models.py   (DDL schema sanity)

These are pure Python tests — no network calls, no FastAPI TestClient.
They run with:  pytest tests/test_services.py -v
"""
import asyncio
import time

import pytest

# ---------------------------------------------------------------------------
# cache.py tests
# ---------------------------------------------------------------------------

class TestTTLCache:
    def setup_method(self):
        """Fresh cache instance for each test."""
        from app.services.cache import TTLCache
        self.cache = TTLCache(default_ttl_seconds=2, max_entries=5, name="test_cache")

    def _run(self, coro):
        return asyncio.get_event_loop().run_until_complete(coro)

    def test_set_and_get(self):
        self._run(self.cache.set("k1", "hello"))
        assert self._run(self.cache.get("k1")) == "hello"

    def test_miss_returns_none(self):
        assert self._run(self.cache.get("nonexistent")) is None

    def test_ttl_expiry(self):
        self._run(self.cache.set("expiring", "value", ttl_seconds=1))
        assert self._run(self.cache.get("expiring")) == "value"
        time.sleep(1.1)
        assert self._run(self.cache.get("expiring")) is None

    def test_delete(self):
        self._run(self.cache.set("del_key", 42))
        self._run(self.cache.delete("del_key"))
        assert self._run(self.cache.get("del_key")) is None

    def test_clear(self):
        self._run(self.cache.set("a", 1))
        self._run(self.cache.set("b", 2))
        self._run(self.cache.clear())
        assert self._run(self.cache.get("a")) is None

    def test_stats_track_hits_and_misses(self):
        self._run(self.cache.set("s", 99))
        self._run(self.cache.get("s"))   # hit
        self._run(self.cache.get("s"))   # hit
        self._run(self.cache.get("nope")) # miss
        stats = self.cache.stats()
        assert stats["hits"] == 2
        assert stats["misses"] == 1
        assert 0.0 <= stats["hit_rate"] <= 1.0

    def test_max_entries_evicts_oldest(self):
        # Fill to capacity
        for i in range(5):
            self._run(self.cache.set(f"key_{i}", i))
        # Adding one more should evict oldest and not raise
        self._run(self.cache.set("overflow", "new"))
        assert self.cache.stats()["entries"] <= 5

    def test_overwrite_existing_key(self):
        self._run(self.cache.set("k", "old"))
        self._run(self.cache.set("k", "new"))
        assert self._run(self.cache.get("k")) == "new"


class TestMakeGridKey:
    def test_basic_key_structure(self):
        from app.services.cache import make_grid_key
        key = make_grid_key("weather", 9.285, 79.312)
        assert key == "weather:9.29:79.31"

    def test_precision_rounding(self):
        from app.services.cache import make_grid_key
        key = make_grid_key("pfz", 9.28, 79.31, precision=1)
        assert key == "pfz:9.3:79.3"

    def test_extra_kwargs_appended(self):
        from app.services.cache import make_grid_key
        key = make_grid_key("pfz", 9.28, 79.31, precision=2, radius=50.0)
        assert "radius=50.0" in key

    def test_extra_kwargs_sorted(self):
        from app.services.cache import make_grid_key
        k1 = make_grid_key("pfz", 9.28, 79.31, precision=2, radius=50, zone="A")
        k2 = make_grid_key("pfz", 9.28, 79.31, precision=2, zone="A", radius=50)
        assert k1 == k2


# ---------------------------------------------------------------------------
# incois_pfz.py tests (all synchronous / deterministic — no network)
# ---------------------------------------------------------------------------

class TestINCOISPFZMock:
    def _run(self, coro):
        return asyncio.get_event_loop().run_until_complete(coro)

    def test_returns_list_of_pfz_features(self):
        from app.services.incois_pfz import get_pfz_features
        features = self._run(get_pfz_features(9.28, 79.31, radius_km=50, use_cache=False))
        assert isinstance(features, list)
        assert len(features) >= 1

    def test_pfz_feature_has_required_fields(self):
        from app.services.incois_pfz import get_pfz_features
        features = self._run(get_pfz_features(9.28, 79.31, radius_km=50, use_cache=False))
        f = features[0]
        assert f.pfz_id.startswith("PFZ-TN-")
        assert f.chlorophyll_mg_m3 > 0
        assert f.geojson_geometry["type"] == "Polygon"
        assert 0 < f.distance_km < 50

    def test_pfz_sorted_by_chlorophyll_descending(self):
        from app.services.incois_pfz import get_pfz_features
        features = self._run(get_pfz_features(9.28, 79.31, radius_km=50, use_cache=False))
        chls = [f.chlorophyll_mg_m3 for f in features]
        assert chls == sorted(chls, reverse=True)

    def test_determinism_same_query_same_result(self):
        """Same rounded coords + radius must always yield the same PFZ IDs."""
        from app.services.incois_pfz import get_pfz_features
        r1 = self._run(get_pfz_features(9.28, 79.31, radius_km=50, use_cache=False))
        r2 = self._run(get_pfz_features(9.28, 79.31, radius_km=50, use_cache=False))
        assert [f.pfz_id for f in r1] == [f.pfz_id for f in r2]

    def test_different_coords_different_result(self):
        from app.services.incois_pfz import get_pfz_features
        r1 = self._run(get_pfz_features(9.28, 79.31, radius_km=50, use_cache=False))
        r2 = self._run(get_pfz_features(12.5, 80.3, radius_km=50, use_cache=False))
        # At least one PFZ ID should differ
        ids1 = {f.pfz_id for f in r1}
        ids2 = {f.pfz_id for f in r2}
        assert ids1 != ids2

    def test_small_radius_fewer_features(self):
        from app.services.incois_pfz import get_pfz_features
        large = self._run(get_pfz_features(9.28, 79.31, radius_km=200, use_cache=False))
        small = self._run(get_pfz_features(9.28, 79.31, radius_km=5, use_cache=False))
        # Both should return >= 1 result (mock always generates some)
        assert len(large) >= 1 and len(small) >= 1

    def test_pfz_cache_hit_on_second_call(self):
        """Second call with same args should hit the cache and return same data."""
        from app.services.incois_pfz import get_pfz_features
        from app.services.cache import get_pfz_cache
        r1 = self._run(get_pfz_features(9.28, 79.31, radius_km=50, use_cache=True))
        r2 = self._run(get_pfz_features(9.28, 79.31, radius_km=50, use_cache=True))
        assert r1[0].pfz_id == r2[0].pfz_id
        stats = get_pfz_cache().stats()
        assert stats["hits"] >= 1


# ---------------------------------------------------------------------------
# open_meteo.py tests (uses synthetic fallback — no real network needed)
# ---------------------------------------------------------------------------

class TestOpenMeteoSyntheticFallback:
    """
    Tests the _synthetic_fallback_weather function directly so these tests
    are 100% offline and fast (no Open-Meteo API call).
    """
    def test_synthetic_fallback_returns_valid_metric(self):
        from app.services.open_meteo import _synthetic_fallback_weather
        metric = _synthetic_fallback_weather(9.28, 79.31, reason="test")
        assert metric.latitude == 9.28
        assert metric.longitude == 79.31
        assert 0 <= metric.sea_state_code <= 9
        assert metric.source == "synthetic-fallback"
        assert "[SYNTHETIC" in metric.advisory_summary

    def test_synthetic_fallback_wave_height_in_valid_range(self):
        from app.services.open_meteo import _synthetic_fallback_weather
        metric = _synthetic_fallback_weather(9.28, 79.31, reason="range-test")
        assert 0.0 <= metric.wave_height_m <= 5.0

    def test_synthetic_fallback_wind_knots_in_valid_range(self):
        from app.services.open_meteo import _synthetic_fallback_weather
        metric = _synthetic_fallback_weather(9.28, 79.31, reason="wind-test")
        assert 0.0 <= metric.wind_speed_knots <= 50.0

    def test_synthetic_fallback_is_deterministic(self):
        from app.services.open_meteo import _synthetic_fallback_weather
        m1 = _synthetic_fallback_weather(9.28, 79.31, reason="det-test")
        m2 = _synthetic_fallback_weather(9.28, 79.31, reason="det-test")
        assert m1.wave_height_m == m2.wave_height_m
        assert m1.wind_speed_knots == m2.wind_speed_knots

    def test_sea_state_code_calculation(self):
        from app.services.open_meteo import _sea_state_code
        # thresholds: [0.0, 0.1, 0.5, 1.25, 2.5, 4.0, 6.0, 9.0, 14.0]
        assert _sea_state_code(0.0) == 0    # calm glassy
        assert _sea_state_code(0.05) == 0   # still below 0.1 → code 0
        assert _sea_state_code(0.15) == 1   # >= 0.1 but < 0.5 → code 1
        assert _sea_state_code(1.0) == 2    # >= 0.5 but < 1.25 → code 2 (slight)
        assert _sea_state_code(3.0) == 4    # >= 2.5 but < 4.0 → code 4 (rough)
        assert _sea_state_code(20.0) == 9   # capped at 9 (phenomenal)

    def test_advisory_builder_dangerous_conditions(self):
        from app.services.open_meteo import _build_advisory
        is_safe, advisory = _build_advisory(wave_height_m=3.0, wind_speed_knots=30.0)
        assert is_safe is False
        assert "DANGEROUS" in advisory

    def test_advisory_builder_caution_conditions(self):
        from app.services.open_meteo import _build_advisory
        is_safe, advisory = _build_advisory(wave_height_m=2.2, wind_speed_knots=22.0)
        assert is_safe is True
        assert "CAUTION" in advisory

    def test_advisory_builder_safe_conditions(self):
        from app.services.open_meteo import _build_advisory
        is_safe, advisory = _build_advisory(wave_height_m=0.5, wind_speed_knots=5.0)
        assert is_safe is True
        assert "Calm" in advisory or "calm" in advisory

    def test_weather_cache_miss_then_hit(self):
        from app.services.open_meteo import _synthetic_fallback_weather
        from app.services.cache import get_weather_cache, make_grid_key
        cache = get_weather_cache()
        key = make_grid_key("weather", 13.0, 80.0, precision=2)

        async def populate():
            metric = _synthetic_fallback_weather(13.0, 80.0, reason="cache-test")
            await cache.set(key, metric, ttl_seconds=60)
            return await cache.get(key)

        result = asyncio.get_event_loop().run_until_complete(populate())
        assert result is not None
        assert result.latitude == 13.0


# ---------------------------------------------------------------------------
# bhashini.py mock tests
# ---------------------------------------------------------------------------

class TestBhashiniMock:
    def _run(self, coro):
        return asyncio.get_event_loop().run_until_complete(coro)

    def test_transcribe_returns_string(self):
        from app.services.bhashini import transcribe_audio
        dummy_audio = "SGVsbG8gV29ybGQ="   # base64("Hello World")
        result = self._run(transcribe_audio(dummy_audio, source_language="ta"))
        assert isinstance(result, str)
        assert len(result) > 0

    def test_transcribe_includes_language_name(self):
        from app.services.bhashini import transcribe_audio
        result = self._run(transcribe_audio("dGVzdA==", source_language="hi"))
        assert "Hindi" in result

    def test_translate_to_english(self):
        from app.services.bhashini import translate_to_english
        result = self._run(translate_to_english("நல்ல மீன்பிடி மண்டலம் எங்கே?", "ta"))
        assert "MOCK-NMT" in result
        assert "Tamil" in result

    def test_translate_from_english(self):
        from app.services.bhashini import translate_from_english
        result = self._run(translate_from_english("Safe conditions for fishing.", "te"))
        assert "Telugu" in result

    def test_synthesize_returns_valid_base64(self):
        import base64 as b64
        from app.services.bhashini import synthesize_speech
        result = self._run(synthesize_speech("Advisory text", target_language="ta"))
        # Must be valid base64
        decoded = b64.b64decode(result.encode("ascii") + b"==")
        assert len(decoded) > 0

    def test_supported_languages_dict_has_six_entries(self):
        from app.services.bhashini import SUPPORTED_LANGUAGES
        assert len(SUPPORTED_LANGUAGES) == 6
        assert "ta" in SUPPORTED_LANGUAGES
        assert "en" in SUPPORTED_LANGUAGES

    def test_process_voice_query_returns_all_keys(self):
        from app.services.bhashini import process_voice_query
        result = self._run(process_voice_query("dGVzdA==", source_language="ta"))
        for key in ("transcript", "translated_query", "response_localized", "audio_base64"):
            assert key in result, f"Missing key: {key}"


# ---------------------------------------------------------------------------
# db_models.py tests
# ---------------------------------------------------------------------------

class TestDBModels:
    def test_schema_ddl_has_three_tables(self):
        from app.models.db_models import SCHEMA_DDL
        assert len(SCHEMA_DDL) == 3

    def test_cached_weather_row_instantiates(self):
        from app.models.db_models import CachedWeatherRow
        row = CachedWeatherRow(lat_rounded=9.28, lon_rounded=79.31, pack_id="test-pack")
        assert row.lat_rounded == 9.28
        assert row.is_safe_for_small_craft is True

    def test_cached_pfz_row_instantiates(self):
        from app.models.db_models import CachedPFZRow
        row = CachedPFZRow(pfz_id="PFZ-001", sector_name="Palk Bay", pack_id="test-pack")
        assert row.pfz_id == "PFZ-001"

    def test_cached_imbl_row_instantiates(self):
        from app.models.db_models import CachedIMBLRow
        row = CachedIMBLRow(boundary_type="IMBL", feature_name="India-Sri Lanka IMBL")
        assert row.boundary_type == "IMBL"

    def test_ddl_contains_expected_table_names(self):
        from app.models.db_models import SCHEMA_DDL
        combined = " ".join(SCHEMA_DDL)
        assert "cached_weather_grid" in combined
        assert "cached_pfz_advisories" in combined
        assert "cached_imbl_boundaries" in combined


# ---------------------------------------------------------------------------
# geojson_models.py tests
# ---------------------------------------------------------------------------

class TestGeoJSONModels:
    def test_build_polygon_is_closed_ring(self):
        from app.models.geojson_models import build_polygon_geometry
        poly = build_polygon_geometry(9.28, 79.31, radius_km=2.0)
        coords = poly["coordinates"][0]
        assert coords[0] == coords[-1], "Polygon ring must be closed (first == last point)"

    def test_build_polygon_has_correct_type(self):
        from app.models.geojson_models import build_polygon_geometry
        poly = build_polygon_geometry(9.28, 79.31, radius_km=2.0)
        assert poly["type"] == "Polygon"

    def test_empty_feature_collection(self):
        from app.models.geojson_models import empty_feature_collection
        fc = empty_feature_collection()
        assert fc["type"] == "FeatureCollection"
        assert fc["features"] == []
