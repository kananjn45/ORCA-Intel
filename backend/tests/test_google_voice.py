"""
ORCA — Tests for Dev 4 Google Cloud Translation & Speech Service.

Verifies:
* GoogleTranslationService Indic <-> English translation & mock fallback
* GoogleSpeechService ASR transcription & locale code mapping
* GoogleSpeechService TTS speech synthesis
* Composite pipelines: ASR -> NMT and NMT -> TTS
* FastAPI endpoints in app.api.v1.endpoints.voice
"""

import io
import struct
import httpx
import pytest
from unittest.mock import AsyncMock, patch
from fastapi.testclient import TestClient

from app.core.config import Settings
from main import app
from app.models.schemas import ASRResult, NMTResult, TTSResult
from app.services.google_voice import (
    GOOGLE_SPEECH_LOCALES,
    GoogleSpeechService,
    GoogleTranslationService,
    GoogleVoiceService,
    _generate_mock_wav,
)


def _make_dummy_wav() -> bytes:
    """Generate minimal valid 44-byte WAV header + 160 bytes PCM data."""
    sample_rate = 16000
    data_size = 160
    buf = io.BytesIO()
    buf.write(b"RIFF")
    buf.write(struct.pack("<I", 36 + data_size))
    buf.write(b"WAVE")
    buf.write(b"fmt ")
    buf.write(struct.pack("<I", 16))
    buf.write(struct.pack("<H", 1))   # PCM
    buf.write(struct.pack("<H", 1))   # Mono
    buf.write(struct.pack("<I", sample_rate))
    buf.write(struct.pack("<I", sample_rate * 2))
    buf.write(struct.pack("<H", 2))
    buf.write(struct.pack("<H", 16))
    buf.write(b"data")
    buf.write(struct.pack("<I", data_size))
    buf.write(b"\x00" * data_size)
    return buf.getvalue()


@pytest.fixture
def mock_google_settings() -> Settings:
    return Settings(
        GOOGLE_TRANSLATE_API_KEY="test_google_api_key_12345",
        TRANSLATION_PROVIDER="google",
        VOICE_PROVIDER="google",
        google_mock_mode=True,
    )


@pytest.fixture
def dummy_wav_bytes() -> bytes:
    return _make_dummy_wav()


# ===========================================================================
# 1. GoogleTranslationService Tests
# ===========================================================================

class TestGoogleTranslationService:
    @pytest.mark.asyncio
    async def test_identity_translation_same_language(self, mock_google_settings: Settings):
        svc = GoogleTranslationService(mock_google_settings)
        res = await svc.translate_text("வணக்கம்", "ta", "ta")
        assert res.translated_text == "வணக்கம்"
        assert res.source_language == "ta"
        assert res.target_language == "ta"
        assert res.is_mock is False

    @pytest.mark.asyncio
    async def test_indic_to_english_mock_translation(self, mock_google_settings: Settings):
        svc = GoogleTranslationService(mock_google_settings)
        # Tamil
        res_ta = await svc.translate_text("புயல் எச்சரிக்கை உள்ளதா", "ta", "en")
        assert res_ta.translated_text == "Is there a storm warning"
        assert res_ta.target_language == "en"
        assert res_ta.is_mock is True

        # Telugu
        res_te = await svc.translate_text("సరిహద్దు ఎంత దూరంలో ఉంది", "te", "en")
        assert res_te.translated_text == "How far is the border"

        # Hindi
        res_hi = await svc.translate_text("मुझे मौसम बताओ", "hi", "en")
        assert res_hi.translated_text == "Tell me the weather"

    @pytest.mark.asyncio
    async def test_english_to_indic_mock_translation(self, mock_google_settings: Settings):
        svc = GoogleTranslationService(mock_google_settings)
        res = await svc.translate_text("The weather is calm", "en", "ta")
        assert "வானிலை அமைதியாக உள்ளது" in res.translated_text
        assert res.target_language == "ta"

    @pytest.mark.asyncio
    async def test_live_google_translation_api_call(self):
        live_settings = Settings(
            GOOGLE_TRANSLATE_API_KEY="valid_test_key",
            google_mock_mode=False,
        )
        svc = GoogleTranslationService(live_settings)

        mock_resp = {
            "data": {
                "translations": [
                    {"translatedText": "Where is the fishing zone&#39;s harbor?"}
                ]
            }
        }

        with patch("httpx.AsyncClient.post") as mock_post:
            mock_post.return_value = httpx.Response(
                status_code=200,
                json=mock_resp,
                request=httpx.Request("POST", "https://translation.googleapis.com"),
            )

            result = await svc.translate_text(
                text="மீன்பிடி மண்டல துறைமுகம் எங்கே?",
                source_language="ta",
                target_language="en",
            )

            assert result.is_mock is False
            # Verifies HTML unescaping of &#39; -> '
            assert result.translated_text == "Where is the fishing zone's harbor?"
            assert result.source_language == "ta"
            assert result.target_language == "en"


# ===========================================================================
# 2. GoogleSpeechService Tests
# ===========================================================================

class TestGoogleSpeechService:
    @pytest.mark.asyncio
    async def test_locale_mapping(self):
        assert GOOGLE_SPEECH_LOCALES["ta"] == "ta-IN"
        assert GOOGLE_SPEECH_LOCALES["te"] == "te-IN"
        assert GOOGLE_SPEECH_LOCALES["hi"] == "hi-IN"
        assert GOOGLE_SPEECH_LOCALES["bn"] == "bn-IN"
        assert GOOGLE_SPEECH_LOCALES["gu"] == "gu-IN"
        assert GOOGLE_SPEECH_LOCALES["en"] == "en-IN"

    @pytest.mark.asyncio
    async def test_transcribe_audio_mock(self, mock_google_settings: Settings, dummy_wav_bytes: bytes):
        svc = GoogleSpeechService(mock_google_settings)
        res = await svc.transcribe_audio(dummy_wav_bytes, "ta")
        assert res.language == "ta"
        assert res.is_mock is True
        assert "தமிழ்" in res.text or "MOCK" in res.text

    @pytest.mark.asyncio
    async def test_synthesise_speech_mock(self, mock_google_settings: Settings):
        svc = GoogleSpeechService(mock_google_settings)
        res = await svc.synthesise_speech("வானிலை பாதுகாப்பானது", "ta", "female")
        assert res.language == "ta"
        assert res.is_mock is True
        assert len(res.audio_content) > 100

    @pytest.mark.asyncio
    async def test_live_google_speech_api_call(self, dummy_wav_bytes: bytes):
        live_settings = Settings(
            GOOGLE_SPEECH_API_KEY="valid_speech_key",
            google_mock_mode=False,
        )
        svc = GoogleSpeechService(live_settings)

        mock_resp = {
            "results": [
                {
                    "alternatives": [
                        {"transcript": "வானிலை எச்சரிக்கை", "confidence": 0.96}
                    ]
                }
            ]
        }

        with patch("httpx.AsyncClient.post") as mock_post:
            mock_post.return_value = httpx.Response(
                status_code=200,
                json=mock_resp,
                request=httpx.Request("POST", "https://speech.googleapis.com"),
            )

            result = await svc.transcribe_audio(dummy_wav_bytes, "ta")
            assert result.is_mock is False
            assert result.text == "வானிலை எச்சரிக்கை"
            assert result.confidence == 0.96


# ===========================================================================
# 3. GoogleVoiceService Composite Pipelines Tests
# ===========================================================================

class TestGoogleVoiceService:
    @pytest.mark.asyncio
    async def test_asr_then_translate_pipeline(self, mock_google_settings: Settings, dummy_wav_bytes: bytes):
        svc = GoogleVoiceService(mock_google_settings)
        asr_res, nmt_res = await svc.asr_then_translate(
            audio_data=dummy_wav_bytes,
            source_language="ta",
            target_language="en",
        )
        assert isinstance(asr_res, ASRResult)
        assert isinstance(nmt_res, NMTResult)
        assert asr_res.language == "ta"
        assert nmt_res.source_language == "ta"
        assert nmt_res.target_language == "en"

    @pytest.mark.asyncio
    async def test_translate_then_tts_pipeline(self, mock_google_settings: Settings):
        svc = GoogleVoiceService(mock_google_settings)
        nmt_res, tts_res = await svc.translate_then_tts(
            text="The weather is calm",
            source_language="en",
            target_language="ta",
            gender="female",
        )
        assert isinstance(nmt_res, NMTResult)
        assert isinstance(tts_res, TTSResult)
        assert "வானிலை" in nmt_res.translated_text
        assert len(tts_res.audio_content) > 50


# ===========================================================================
# 4. FastAPI Endpoints Integration Tests
# ===========================================================================

class TestVoiceEndpointsWithGoogle:
    @pytest.fixture
    def client(self):
        return TestClient(app)

    def test_translate_endpoint(self, client: TestClient):
        response = client.post(
            "/api/v1/voice/translate",
            json={
                "text": "புயல் எச்சரிக்கை உள்ளதா",
                "source_language": "ta",
                "target_language": "en",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "translated_text" in data
        assert data["source_language"] == "ta"
        assert data["target_language"] == "en"

    def test_synthesize_endpoint_json(self, client: TestClient):
        response = client.post(
            "/api/v1/voice/synthesize",
            json={
                "text": "கடல் அமைதியாக உள்ளது",
                "language": "ta",
                "gender": "female",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "audio_content" in data
        assert data["language"] == "ta"

    def test_supported_languages_endpoint(self, client: TestClient):
        response = client.get("/api/v1/voice/languages")
        assert response.status_code == 200
        data = response.json()
        assert "ta" in data["languages"]
        assert "hi" in data["languages"]
        assert "te" in data["languages"]
        assert "en" in data["languages"]
