"""
app/db/session.py
Owner: Dev 3 (Data Pipeline & Backend Core Engineer)
Day: 1 (stub) — full SQLite wiring in Day 7 per docs/ORCA-intel.md roadmap.

Provides a minimal SQLite connection factory. The in-memory TTL cache
(app/services/cache.py) handles Day 1-2 caching needs; this session module
is the placeholder that Day 7 will expand into a proper aiosqlite pool.
"""
import sqlite3
from pathlib import Path

from app.core.config import settings
from app.core.logging import get_logger

logger = get_logger(__name__)

# Database file lives next to the backend/ directory in a data/ subfolder.
_DB_PATH = Path(__file__).resolve().parent.parent.parent / "data" / "orca_cache.db"


def get_db_path() -> Path:
    return _DB_PATH


def get_connection() -> sqlite3.Connection:
    """
    Returns a synchronous sqlite3 connection.
    Day 7 will replace this with an async aiosqlite connection pool.
    """
    _DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(_DB_PATH), check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn
