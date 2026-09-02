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
    PROJECT_NAME: str = "ORCA Marine AI Gateway"
    CORS_ORIGINS: str = "*"

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

    # Database
    DATABASE_URL: str = "sqlite+aiosqlite:///./orca_local.db"
    POSTGRES_SERVER: str = "localhost"
    POSTGRES_PORT: int = 5432
    POSTGRES_USER: str = "orca_user"
    POSTGRES_PASSWORD: str = "orca_password"
    POSTGRES_DB: str = "orca_marine"

    # External APIs
    OPEN_METEO_BASE_URL: str = "https://marine-api.open-meteo.com/v1/marine"
    INCOIS_PFZ_API_URL: str = "https://incois.gov.in/portal/datainfo/pfz.jsp"

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
