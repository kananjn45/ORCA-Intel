import json
import sys
import time
import uuid
from contextlib import asynccontextmanager
from pathlib import Path

# Ensure both backend/ and parent directory are on sys.path
_backend_dir = Path(__file__).resolve().parent
_parent_dir = _backend_dir.parent
for _p in (str(_backend_dir), str(_parent_dir)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.logging import configure_logging, get_logger, request_id_ctx_var
from app.db.init_db import init_db
from app.models.schemas import ErrorResponse, HealthCheckResponse

configure_logging()
logger = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan — runs startup tasks before serving requests."""
    logger.info("orca_startup", extra={"extra_fields": {"env": settings.APP_ENV}})
    init_db()  # Create SQLite tables (non-fatal if SQLite unavailable)
    yield
    logger.info("orca_shutdown")


app = FastAPI(
    title=settings.APP_NAME,
    description="ORCA — Marine EcOsystem Reasoning with Collaborative Agents (Backend API)",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# CORS — the Flutter app (and local dev tools like Swagger/Postman) need to
# be able to call this API from a different origin/port.
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Request ID middleware — tags every request with a correlation id that
# shows up in every log line emitted while handling it (see core/logging.py).
@app.middleware("http")
async def request_id_and_timing_middleware(request: Request, call_next):
    request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
    token = request_id_ctx_var.set(request_id)
    start = time.monotonic()
    try:
        response = await call_next(request)
    finally:
        request_id_ctx_var.reset(token)
    duration_ms = round((time.monotonic() - start) * 1000, 2)
    response.headers["X-Request-ID"] = request_id
    response.headers["X-Process-Time-Ms"] = str(duration_ms)
    logger.info(
        "request_completed",
        extra={
            "extra_fields": {
                "path": request.url.path,
                "method": request.method,
                "status_code": response.status_code,
                "duration_ms": duration_ms,
            }
        },
    )
    return response


# Global exception handlers — uniform JSON error envelope for the mobile
# team instead of leaking raw tracebacks / default FastAPI error shapes.
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    # exc.errors() can contain non-JSON-serializable objects (e.g. the raised
    # ValueError instance inside "ctx" for custom @field_validator errors) —
    # round-trip through json.dumps(default=str) to force everything to a
    # plain, serializable representation before it goes into the response.
    safe_errors = json.loads(json.dumps(exc.errors(), default=str))
    logger.warning("validation_error", extra={"extra_fields": {"errors": safe_errors, "path": request.url.path}})
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content=ErrorResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            message="Request validation failed.",
            detail=safe_errors,
            path=str(request.url.path),
        ).model_dump(mode="json"),
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    logger.exception("unhandled_exception", extra={"extra_fields": {"path": request.url.path}})
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=ErrorResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            message="An unexpected error occurred.",
            detail=str(exc) if settings.DEBUG else None,
            path=str(request.url.path),
        ).model_dump(mode="json"),
    )

# Routes
@app.get("/", tags=["Health"], summary="Root ping")
async def root() -> dict:
    return {"message": "ORCA backend is running.", "docs": "/docs"}


@app.get("/health", response_model=HealthCheckResponse, tags=["Health"], summary="Health check")
async def health() -> HealthCheckResponse:
    return HealthCheckResponse(app_name=settings.APP_NAME, app_env=settings.APP_ENV)


app.include_router(api_router, prefix=settings.API_V1_PREFIX)