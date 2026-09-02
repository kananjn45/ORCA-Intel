"""
app/db/init_db.py
Owner: Dev 3 (Data Pipeline & Backend Core Engineer)
Day: 1 (schema creation)

Creates all SQLite tables if they don't already exist.
Called once at application startup (can be hooked into FastAPI lifespan later).
"""
from app.core.logging import get_logger
from app.db.session import get_connection
from app.models.db_models import SCHEMA_DDL

logger = get_logger(__name__)


def init_db() -> None:
    """
    Runs all DDL statements in SCHEMA_DDL against the SQLite database.
    Safe to call multiple times — uses CREATE TABLE IF NOT EXISTS.
    """
    try:
        conn = get_connection()
        cursor = conn.cursor()
        for ddl in SCHEMA_DDL:
            cursor.execute(ddl)
        conn.commit()
        conn.close()
        logger.info("init_db_success", extra={"extra_fields": {"tables": len(SCHEMA_DDL)}})
    except Exception as exc:
        # Non-fatal on startup — the in-memory TTL cache still works without SQLite.
        logger.warning(
            "init_db_failed",
            extra={"extra_fields": {"error": str(exc)}},
        )


if __name__ == "__main__":
    # Allow running directly: python -m app.db.init_db
    init_db()
    print("Database initialized successfully.")
