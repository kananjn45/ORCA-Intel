import asyncio
import time
from dataclasses import dataclass, field
from typing import Any, Dict, Optional

from app.core.config import settings
from app.core.logging import get_logger

logger = get_logger(__name__)


@dataclass
class _CacheEntry:
    value: Any
    expires_at: float
    created_at: float = field(default_factory=time.monotonic)


class TTLCache:
    """A minimal thread/async-safe TTL cache with an LRU-ish size cap."""

    def __init__(self, default_ttl_seconds: int = 600, max_entries: int = 2000, name: str = "cache"):
        self._store: Dict[str, _CacheEntry] = {}
        self._lock = asyncio.Lock()
        self._default_ttl = default_ttl_seconds
        self._max_entries = max_entries
        self._name = name
        self._hits = 0
        self._misses = 0

    async def get(self, key: str) -> Optional[Any]:
        async with self._lock:
            entry = self._store.get(key)
            if entry is None:
                self._misses += 1
                return None
            if entry.expires_at < time.monotonic():
                # Expired — evict lazily.
                del self._store[key]
                self._misses += 1
                return None
            self._hits += 1
            return entry.value

    async def set(self, key: str, value: Any, ttl_seconds: Optional[int] = None) -> None:
        ttl = ttl_seconds if ttl_seconds is not None else self._default_ttl
        async with self._lock:
            if len(self._store) >= self._max_entries and key not in self._store:
                self._evict_oldest()
            self._store[key] = _CacheEntry(value=value, expires_at=time.monotonic() + ttl)

    async def delete(self, key: str) -> None:
        async with self._lock:
            self._store.pop(key, None)

    async def clear(self) -> None:
        async with self._lock:
            self._store.clear()

    def _evict_oldest(self) -> None:
        """Called while holding the lock. Drops the single oldest entry (simple LRU-ish policy)."""
        if not self._store:
            return
        oldest_key = min(self._store, key=lambda k: self._store[k].created_at)
        del self._store[oldest_key]

    def stats(self) -> Dict[str, Any]:
        total = self._hits + self._misses
        hit_rate = round(self._hits / total, 3) if total else 0.0
        return {
            "cache_name": self._name,
            "entries": len(self._store),
            "max_entries": self._max_entries,
            "hits": self._hits,
            "misses": self._misses,
            "hit_rate": hit_rate,
        }


# Process-wide singletons. Import these, don't instantiate TTLCache directly,
# so every part of the app shares the same cache instance/stats.
_weather_cache = TTLCache(
    default_ttl_seconds=settings.WEATHER_CACHE_TTL_SECONDS,
    max_entries=settings.CACHE_MAX_ENTRIES,
    name="weather_cache",
)
_pfz_cache = TTLCache(
    default_ttl_seconds=settings.PFZ_CACHE_TTL_SECONDS,
    max_entries=settings.CACHE_MAX_ENTRIES,
    name="pfz_cache",
)


def get_weather_cache() -> TTLCache:
    return _weather_cache


def get_pfz_cache() -> TTLCache:
    return _pfz_cache


def make_grid_key(prefix: str, lat: float, lon: float, precision: int = 2, **extra: Any) -> str:

    rounded_lat = round(lat, precision)
    rounded_lon = round(lon, precision)
    extra_part = "&".join(f"{k}={v}" for k, v in sorted(extra.items()))
    key = f"{prefix}:{rounded_lat}:{rounded_lon}"
    if extra_part:
        key += f":{extra_part}"
    return key


def get_all_cache_stats() -> Dict[str, Any]:
    return {
        "weather": _weather_cache.stats(),
        "pfz": _pfz_cache.stats(),
    }