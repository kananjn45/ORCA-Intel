"""
tests/conftest.py
Pytest configuration and shared test fixtures for ORCA backend.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path
from typing import AsyncGenerator

import pytest
import pytest_asyncio

# Add backend/ to sys.path so `import main` and `from app.xxx import yyy` work
backend_root = Path(__file__).resolve().parent.parent
if str(backend_root) not in sys.path:
    sys.path.insert(0, str(backend_root))

# Force mock mode for Bhashini tests
os.environ["BHASHINI_MOCK_MODE"] = "true"
os.environ["BHASHINI_API_KEY"] = ""
os.environ["BHASHINI_USER_ID"] = ""

from app.core.config import Settings, get_settings  # noqa: E402
from app.services.bhashini import BhashiniService  # noqa: E402
from app.utils.audio_converter import generate_silence_wav  # noqa: E402


@pytest.fixture
def mock_settings() -> Settings:
    """Return a Settings instance with mock mode forced on."""
    return Settings(
        bhashini_mock_mode=True,
        bhashini_api_key="",
        bhashini_user_id="",
    )


@pytest_asyncio.fixture
async def bhashini_service(mock_settings: Settings) -> AsyncGenerator[BhashiniService, None]:
    """Provide a BhashiniService configured in mock mode."""
    svc = BhashiniService(settings=mock_settings)
    yield svc
    await svc.close()


@pytest.fixture
def sample_wav_hindi(mock_settings: Settings) -> bytes:
    """Generate a deterministic WAV fixture for Hindi ASR testing."""
    return generate_silence_wav(duration_seconds=0.5, settings=mock_settings)


@pytest.fixture
def sample_wav_tamil(mock_settings: Settings) -> bytes:
    """Generate a deterministic WAV fixture for Tamil ASR testing."""
    return generate_silence_wav(duration_seconds=0.5, settings=mock_settings)


@pytest.fixture
def sample_wav_telugu(mock_settings: Settings) -> bytes:
    """Generate a deterministic WAV fixture for Telugu ASR testing."""
    return generate_silence_wav(duration_seconds=0.5, settings=mock_settings)
