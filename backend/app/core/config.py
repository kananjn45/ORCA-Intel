from typing import List, Union
from pydantic import AnyHttpUrl, validator
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    # Server & Application
    APP_ENV: str = "development"
    DEBUG: bool = True
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    API_V1_STR: str = "/api/v1"
    API_V1_PREFIX: str = "/api/v1"
    PROJECT_NAME: str = "ORCA Marine AI Gateway"
    APP_NAME: str = "ORCA Marine AI Gateway"
    CORS_ORIGINS: str = "*"
    LOG_LEVEL: str = "INFO"

    # API Security
    API_KEY_ENABLED: bool = False
    API_KEY: str = "orca_secret_key"

    # LLM Inference
    LLM_PROVIDER: str = "groq"  # 'groq' | 'gemini' | 'ollama'
    GROQ_API_KEY: str = ""
    GROQ_MODEL: str = "llama3-70b-8192"
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-1.5-flash"
    OLLAMA_BASE_URL: str = "http://localhost:11434"
    OLLAMA_MODEL: str = "llama3:8b"

    # Bhashini Multilingual Speech API
    BHASHINI_USER_ID: str = ""
    BHASHINI_API_KEY: str = ""
    BHASHINI_PIPELINE_ENDPOINT: str = "https://dhruva-api.bhashini.gov.in/services/inference/pipeline"
    BHASHINI_USE_MOCK: bool = True

    # Database
    DATABASE_URL: str = "sqlite+aiosqlite:///./orca_local.db"
    POSTGRES_SERVER: str = "localhost"
    POSTGRES_PORT: int = 5432
    POSTGRES_USER: str = "orca_user"
    POSTGRES_PASSWORD: str = "orca_password"
    POSTGRES_DB: str = "orca_marine"

    # External APIs (Open-Meteo & INCOIS)
    OPEN_METEO_BASE_URL: str = "https://marine-api.open-meteo.com/v1/marine"
    OPEN_METEO_MARINE_BASE_URL: str = "https://marine-api.open-meteo.com/v1/marine"
    OPEN_METEO_FORECAST_BASE_URL: str = "https://api.open-meteo.com/v1/forecast"
    OPEN_METEO_TIMEOUT_SECONDS: float = 10.0
    INCOIS_PFZ_API_URL: str = "https://incois.gov.in/portal/datainfo/pfz.jsp"
    INCOIS_USE_MOCK: bool = True

    # In-Memory / Redis Caching
    WEATHER_CACHE_TTL_SECONDS: int = 900       # 15 minutes
    PFZ_CACHE_TTL_SECONDS: int = 21600         # 6 hours
    CACHE_MAX_ENTRIES: int = 1000

    # Safety Guardrail Limits
    MAX_SAFE_WAVE_HEIGHT_METERS: float = 2.0
    MAX_SAFE_WIND_SPEED_KNOTS: float = 25.0
    IMBL_DANGER_BUFFER_KM: float = 2.0
    IMBL_CAUTION_BUFFER_KM: float = 5.0

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @property
    def cors_origins_list(self) -> List[str]:
        if self.CORS_ORIGINS == "*":
            return ["*"]
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",") if origin.strip()]

settings = Settings()
