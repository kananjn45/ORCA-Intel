"""
ORCA — TTS Audio Cache.

TTL-based in-memory cache for repetitive TTS audio results.

Safety advisories like boundary alerts and storm warnings are spoken
repeatedly.  Caching avoids redundant Bhashini API calls and cuts
latency for the most common responses.

Cache keys are deterministic hashes of ``(text, language, gender)``.

Usage::

    from app.services.tts_cache import TTSAudioCache

    cache = TTSAudioCache(ttl_seconds=3600)
    result = cache.get("alert_text", "ta", "female")
    if result is None:
        result = await bhashini.synthesise_speech(...)
        cache.put(result)
"""

from __future__ import annotations

import hashlib
import time
from dataclasses import dataclass, field
from typing import Dict, Optional

from app.core.logging import get_logger
from app.models.schemas import TTSResult

logger = get_logger("orca.tts_cache")

# Default TTL: 1 hour (3600 s).  Safety advisories rarely change text.
_DEFAULT_TTL_SECONDS = 3600

# Maximum cache entries to prevent unbounded memory growth.
_DEFAULT_MAX_ENTRIES = 256


@dataclass
class _CacheEntry:
    """Single cached TTS result with expiry timestamp."""
    result: TTSResult
    expires_at: float
    hit_count: int = 0


class TTSAudioCache:
    """Thread-safe, TTL-based in-memory cache for TTS audio.

    Args:
        ttl_seconds: Time-to-live for each cache entry.
        max_entries: Maximum number of cached entries (LRU eviction).
    """

    def __init__(
        self,
        ttl_seconds: float = _DEFAULT_TTL_SECONDS,
        max_entries: int = _DEFAULT_MAX_ENTRIES,
    ) -> None:
        self._ttl = ttl_seconds
        self._max_entries = max_entries
        self._store: Dict[str, _CacheEntry] = {}

    # -- public API ----------------------------------------------------------

    def get(
        self,
        text: str,
        language: str,
        gender: str = "female",
    ) -> Optional[TTSResult]:
        """Look up a cached TTS result.

        Args:
            text: The synthesised text.
            language: Language code.
            gender: Voice gender.

        Returns:
            A cached :class:`TTSResult` or ``None`` on miss / expiry.
        """
        key = self._make_key(text, language, gender)
        entry = self._store.get(key)

        if entry is None:
            return None

        # Check expiry
        if time.monotonic() > entry.expires_at:
            logger.debug("TTS cache expired for key=%s", key[:12])
            del self._store[key]
            return None

        entry.hit_count += 1
        logger.debug(
            "TTS cache HIT (key=%s, hits=%d)", key[:12], entry.hit_count
        )
        return entry.result

    def put(
        self,
        text: str,
        language: str,
        gender: str,
        result: TTSResult,
    ) -> None:
        """Store a TTS result in the cache.

        If the cache is full, the oldest entry is evicted.

        Args:
            text: Original text.
            language: Language code.
            gender: Voice gender.
            result: The :class:`TTSResult` to cache.
        """
        key = self._make_key(text, language, gender)

        # Evict oldest if at capacity
        if len(self._store) >= self._max_entries and key not in self._store:
            self._evict_oldest()

        self._store[key] = _CacheEntry(
            result=result,
            expires_at=time.monotonic() + self._ttl,
        )
        logger.debug("TTS cache PUT (key=%s, size=%d)", key[:12], len(self._store))

    def invalidate(
        self,
        text: str,
        language: str,
        gender: str = "female",
    ) -> bool:
        """Remove a specific entry from the cache.

        Returns:
            ``True`` if an entry was removed, ``False`` if not found.
        """
        key = self._make_key(text, language, gender)
        if key in self._store:
            del self._store[key]
            return True
        return False

    def clear(self) -> None:
        """Remove all entries from the cache."""
        count = len(self._store)
        self._store.clear()
        logger.info("TTS cache cleared (%d entries removed)", count)

    @property
    def size(self) -> int:
        """Number of entries currently in the cache."""
        return len(self._store)

    @property
    def stats(self) -> dict:
        """Return cache statistics."""
        total_hits = sum(e.hit_count for e in self._store.values())
        return {
            "entries": len(self._store),
            "max_entries": self._max_entries,
            "ttl_seconds": self._ttl,
            "total_hits": total_hits,
        }

    # -- internals -----------------------------------------------------------

    @staticmethod
    def _make_key(text: str, language: str, gender: str) -> str:
        """Create a deterministic cache key from input parameters."""
        raw = f"{text.strip().lower()}|{language.strip().lower()}|{gender.strip().lower()}"
        return hashlib.sha256(raw.encode("utf-8")).hexdigest()

    def _evict_oldest(self) -> None:
        """Remove the entry with the earliest expiry timestamp."""
        if not self._store:
            return
        oldest_key = min(self._store, key=lambda k: self._store[k].expires_at)
        logger.debug("TTS cache evicting oldest entry (key=%s)", oldest_key[:12])
        del self._store[oldest_key]
