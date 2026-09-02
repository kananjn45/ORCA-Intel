import contextvars
import json
import logging
import sys
from datetime import datetime, timezone
from typing import Any, Dict

from app.core.config import settings

# Holds the current request's correlation id so nested log calls (inside
# services, agents, etc.) automatically get tagged without passing it
# through every function signature.
request_id_ctx_var: contextvars.ContextVar[str] = contextvars.ContextVar(
    "request_id", default="-"
)

class JSONLogFormatter(logging.Formatter):
    """Formats log records as single-line JSON objects."""

    def format(self, record: logging.LogRecord) -> str:
        payload: Dict[str, Any] = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "request_id": request_id_ctx_var.get(),
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno,
        }
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        # Allow callers to pass extra structured fields via `extra={"extra_fields": {...}}`
        extra_fields = getattr(record, "extra_fields", None)
        if extra_fields:
            payload.update(extra_fields)
        return json.dumps(payload, default=str)


def configure_logging() -> None:
    """Configure the root logger to use JSON formatting and the configured log level."""
    root_logger = logging.getLogger()
    root_logger.setLevel(settings.LOG_LEVEL.upper())

    # Avoid adding a second handler on reload (uvicorn --reload re-imports).
    if any(isinstance(h, logging.StreamHandler) for h in root_logger.handlers):
        return

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JSONLogFormatter())
    root_logger.addHandler(handler)

    # Quiet down noisy third-party loggers a little in dev.
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("uvicorn.access").setLevel(logging.INFO)


def get_logger(name: str) -> logging.Logger:
    """Standard accessor used across the codebase: `logger = get_logger(__name__)`."""
    return logging.getLogger(name)