from functools import lru_cache
from typing import List

from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    # ---- App ----
    APP_NAME: str = "ORCA Marine Backend"
    APP_ENV: str = "development"
    DEBUG: bool = True
    LOG_LEVEL: str = "INFO"
    API_V1_PREFIX: str = "/api/v1"

    # ---- CORS ----
    CORS_ORIGINS: str = "*"

    # ---- Open-Meteo ----
    OPEN_METEO_MARINE_BASE_URL: str = "https://marine-api.open-meteo.com/v1/marine"
    OPEN_METEO_FORECAST_BASE_URL: str = "https://api.open-meteo.com/v1/forecast"
    OPEN_METEO_TIMEOUT_SECONDS: float = 8.0

    # ---- INCOIS / PFZ ----
    INCOIS_USE_MOCK: bool = True
    INCOIS_API_BASE_URL: str = ""
    INCOIS_API_KEY: str = ""

    # ---- Caching ----
    CACHE_DEFAULT_TTL_SECONDS: int = 600
    WEATHER_CACHE_TTL_SECONDS: int = 900
    PFZ_CACHE_TTL_SECONDS: int = 1800
    CACHE_MAX_ENTRIES: int = 2000

    # ---- Bhashini ASR / NMT / TTS ----
    BHASHINI_USE_MOCK: bool = True
    BHASHINI_API_KEY: str = ""
    BHASHINI_USER_ID: str = ""
    BHASHINI_PIPELINE_ID: str = ""
    BHASHINI_BASE_URL: str = "https://dhruva-api.bhashini.gov.in/services/inference/pipeline"

    # ---- Security ----
    API_KEY_ENABLED: bool = False
    API_KEY: str = "change-me-orca-2026"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

    @property
    def cors_origins_list(self) -> List[str]:
        """Turn the comma separated CORS_ORIGINS env value into a list."""
        raw = [origin.strip() for origin in self.CORS_ORIGINS.split(",") if origin.strip()]
        return raw or ["*"]


@lru_cache
def get_settings() -> Settings:
    """
    Cached settings accessor. Using lru_cache means the .env file is only
    parsed once per process instead of on every import/request.
    """
    return Settings()


# Convenience singleton used across the codebase: `from app.core.config import settings`
settings = get_settings()