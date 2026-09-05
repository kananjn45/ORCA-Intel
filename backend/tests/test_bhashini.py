"""
ORCA — Bhashini ASR / NMT / TTS Service Tests.

Automated test suite for Day 1 Dev 4 deliverables:

1. Hindi ASR transcription
2. Tamil ASR transcription
3. Telugu ASR transcription
4. Fallback / mock mode behaviour
5. API failure → automatic fallback
6. Invalid language rejection
7. Empty audio rejection
8. Bhashini response parsing
9. NMT mock mode
10. TTS mock mode

All tests run WITHOUT a live Bhashini API connection.
"""

from __future__ import annotations

import base64
import struct
import io
from unittest.mock import AsyncMock, patch

import httpx
import pytest

from app.core.config import Settings
from app.core.exceptions import (
    AudioValidationError,
    BhashiniAPIError,
    BhashiniTimeoutError,
    UnsupportedLanguageError,
)
from app.services.bhashini import BhashiniService
from app.utils.audio_converter import (
    AudioParams,
    convert_to_wav,
    extract_pcm_from_wav,
    generate_silence_wav,
    validate_wav,
)


# =====================================================================
# ASR — Hindi
# =====================================================================


class TestASRHindi:
    """ASR transcription tests for Hindi (hi)."""

    async def test_hindi_mock_transcription(
        self, bhashini_service: BhashiniService, sample_wav_hindi: bytes
    ):
        """Mock ASR returns deterministic Hindi transcript."""
        result = await bhashini_service.transcribe_audio(sample_wav_hindi, "hi")
        assert result.language == "hi"
        assert result.is_mock is True
        assert "MOCK" in result.text
        assert "हिन्दी" in result.text or "Hindi" in result.text.lower() or "hindi" in result.text.lower()

    async def test_hindi_correct_language_sent(
        self, bhashini_service: BhashiniService, sample_wav_hindi: bytes
    ):
        """Language code is normalised to lowercase 'hi'."""
        result = await bhashini_service.transcribe_audio(sample_wav_hindi, "HI")
        assert result.language == "hi"

    async def test_hindi_returns_asr_result(
        self, bhashini_service: BhashiniService, sample_wav_hindi: bytes
    ):
        """Result type is ASRResult with all expected fields."""
        result = await bhashini_service.transcribe_audio(sample_wav_hindi, "hi")
        assert hasattr(result, "text")
        assert hasattr(result, "language")
        assert hasattr(result, "is_mock")


# =====================================================================
# ASR — Tamil
# =====================================================================


class TestASRTamil:
    """ASR transcription tests for Tamil (ta)."""

    async def test_tamil_mock_transcription(
        self, bhashini_service: BhashiniService, sample_wav_tamil: bytes
    ):
        """Mock ASR returns deterministic Tamil transcript."""
        result = await bhashini_service.transcribe_audio(sample_wav_tamil, "ta")
        assert result.language == "ta"
        assert result.is_mock is True
        assert "MOCK" in result.text
        assert "தமிழ்" in result.text or "Tamil" in result.text.lower()

    async def test_tamil_correct_language_sent(
        self, bhashini_service: BhashiniService, sample_wav_tamil: bytes
    ):
        result = await bhashini_service.transcribe_audio(sample_wav_tamil, " ta ")
        assert result.language == "ta"


# =====================================================================
# ASR — Telugu
# =====================================================================


class TestASRTelugu:
    """ASR transcription tests for Telugu (te)."""

    async def test_telugu_mock_transcription(
        self, bhashini_service: BhashiniService, sample_wav_telugu: bytes
    ):
        """Mock ASR returns deterministic Telugu transcript."""
        result = await bhashini_service.transcribe_audio(sample_wav_telugu, "te")
        assert result.language == "te"
        assert result.is_mock is True
        assert "MOCK" in result.text
        assert "తెలుగు" in result.text or "Telugu" in result.text.lower()

    async def test_telugu_correct_language_sent(
        self, bhashini_service: BhashiniService, sample_wav_telugu: bytes
    ):
        result = await bhashini_service.transcribe_audio(sample_wav_telugu, "TE")
        assert result.language == "te"


# =====================================================================
# Fallback / Mock Mode
# =====================================================================


class TestFallbackMode:
    """Verify fallback behaviour when Bhashini is unavailable."""

    async def test_mock_mode_returns_mock_flag(
        self, bhashini_service: BhashiniService, sample_wav_hindi: bytes
    ):
        """is_mock is True when service runs in mock mode."""
        result = await bhashini_service.transcribe_audio(sample_wav_hindi, "hi")
        assert result.is_mock is True

    async def test_mock_mode_deterministic(
        self, bhashini_service: BhashiniService, sample_wav_hindi: bytes
    ):
        """Two calls with same language produce identical results."""
        r1 = await bhashini_service.transcribe_audio(sample_wav_hindi, "hi")
        r2 = await bhashini_service.transcribe_audio(sample_wav_hindi, "hi")
        assert r1.text == r2.text

    async def test_fallback_on_api_error(self, sample_wav_hindi: bytes):
        """Service falls back to mock when live API returns HTTP 500."""
        settings = Settings(
            bhashini_mock_mode=False,
            bhashini_api_key="test-key",
            bhashini_user_id="test-user",
        )
        svc = BhashiniService(settings=settings)

        mock_response = httpx.Response(
            status_code=500,
            request=httpx.Request("POST", "https://example.com"),
        )

        with patch.object(svc, "_get_client") as mock_client_factory:
            mock_client = AsyncMock()
            mock_client.post = AsyncMock(return_value=mock_response)
            mock_client.is_closed = False
            mock_client_factory.return_value = mock_client

            result = await svc.transcribe_audio(sample_wav_hindi, "hi")
            assert result.is_mock is True
            assert "MOCK" in result.text

        await svc.close()

    async def test_fallback_on_timeout(self, sample_wav_hindi: bytes):
        """Service falls back to mock when API times out."""
        settings = Settings(
            bhashini_mock_mode=False,
            bhashini_api_key="test-key",
            bhashini_user_id="test-user",
        )
        svc = BhashiniService(settings=settings)

        with patch.object(svc, "_get_client") as mock_client_factory:
            mock_client = AsyncMock()
            mock_client.post = AsyncMock(side_effect=httpx.TimeoutException("timeout"))
            mock_client.is_closed = False
            mock_client_factory.return_value = mock_client

            result = await svc.transcribe_audio(sample_wav_hindi, "hi")
            assert result.is_mock is True

        await svc.close()

    async def test_fallback_on_connection_error(self, sample_wav_hindi: bytes):
        """Service falls back to mock on network connection error."""
        settings = Settings(
            bhashini_mock_mode=False,
            bhashini_api_key="test-key",
            bhashini_user_id="test-user",
        )
        svc = BhashiniService(settings=settings)

        with patch.object(svc, "_get_client") as mock_client_factory:
            mock_client = AsyncMock()
            mock_client.post = AsyncMock(
                side_effect=httpx.ConnectError("Connection refused")
            )
            mock_client.is_closed = False
            mock_client_factory.return_value = mock_client

            result = await svc.transcribe_audio(sample_wav_hindi, "hi")
            assert result.is_mock is True

        await svc.close()


# =====================================================================
# Bhashini Response Parsing
# =====================================================================


class TestResponseParsing:
    """Test correct extraction of transcripts from Bhashini API responses."""

    def test_parse_valid_asr_response(self):
        """Standard Bhashini ASR response is parsed correctly."""
        response_data = {
            "pipelineResponse": [
                {
                    "taskType": "asr",
                    "output": [{"source": "நல்ல மீன்பிடி பகுதி எங்கே"}],
                }
            ]
        }
        result = BhashiniService._parse_asr_response(response_data, "ta")
        assert result.text == "நல்ல மீன்பிடி பகுதி எங்கே"
        assert result.language == "ta"
        assert result.is_mock is False

    def test_parse_empty_output(self):
        """Empty output array raises parse error."""
        response_data = {
            "pipelineResponse": [
                {"taskType": "asr", "output": []}
            ]
        }
        from app.core.exceptions import BhashiniResponseParseError

        with pytest.raises(BhashiniResponseParseError):
            BhashiniService._parse_asr_response(response_data, "ta")

    def test_parse_missing_pipeline_response(self):
        """Missing pipelineResponse key raises parse error."""
        from app.core.exceptions import BhashiniResponseParseError

        with pytest.raises(BhashiniResponseParseError):
            BhashiniService._parse_asr_response({}, "ta")

    def test_parse_wrong_task_type(self):
        """Response with non-ASR task type raises parse error."""
        response_data = {
            "pipelineResponse": [
                {"taskType": "translation", "output": [{"source": "text"}]}
            ]
        }
        from app.core.exceptions import BhashiniResponseParseError

        with pytest.raises(BhashiniResponseParseError):
            BhashiniService._parse_asr_response(response_data, "ta")

    def test_parse_nmt_response(self):
        """Standard NMT response is parsed correctly."""
        response_data = {
            "pipelineResponse": [
                {
                    "taskType": "translation",
                    "output": [
                        {"source": "மீன்பிடி", "target": "Fishing"}
                    ],
                }
            ]
        }
        result = BhashiniService._parse_nmt_response(response_data, "ta", "en")
        assert result.translated_text == "Fishing"
        assert result.source_language == "ta"
        assert result.target_language == "en"
        assert result.is_mock is False

    def test_parse_tts_response(self):
        """Standard TTS response returns audio content."""
        fake_audio = base64.b64encode(b"fake_audio").decode()
        response_data = {
            "pipelineResponse": [
                {
                    "taskType": "tts",
                    "audio": [{"audioContent": fake_audio}],
                }
            ]
        }
        result = BhashiniService._parse_tts_response(response_data, "ta", "wav")
        assert result.audio_content == fake_audio
        assert result.is_mock is False


# =====================================================================
# Input Validation
# =====================================================================


class TestInputValidation:
    """Verify that invalid inputs are rejected with proper exceptions."""

    async def test_invalid_language_rejected(
        self, bhashini_service: BhashiniService, sample_wav_hindi: bytes
    ):
        """Unsupported language code raises UnsupportedLanguageError."""
        with pytest.raises(UnsupportedLanguageError):
            await bhashini_service.transcribe_audio(sample_wav_hindi, "zz")

    async def test_empty_audio_rejected(
        self, bhashini_service: BhashiniService
    ):
        """Empty bytes raises AudioValidationError."""
        with pytest.raises(AudioValidationError):
            await bhashini_service.transcribe_audio(b"", "hi")

    async def test_tiny_audio_rejected(
        self, bhashini_service: BhashiniService
    ):
        """Audio smaller than minimum header size is rejected."""
        with pytest.raises(AudioValidationError):
            await bhashini_service.transcribe_audio(b"\x00" * 10, "hi")

    async def test_invalid_audio_format_rejected(
        self, bhashini_service: BhashiniService, sample_wav_hindi: bytes
    ):
        """Unsupported audio format string is rejected."""
        with pytest.raises(AudioValidationError):
            await bhashini_service.transcribe_audio(
                sample_wav_hindi, "hi", audio_format="xyz"
            )


# =====================================================================
# NMT Mock Mode
# =====================================================================


class TestNMTMockMode:
    """Test NMT translation in mock mode."""

    async def test_nmt_mock_translation(
        self, bhashini_service: BhashiniService
    ):
        """Mock NMT returns prefixed text."""
        result = await bhashini_service.translate_text(
            text="மீன்பிடி",
            source_language="ta",
            target_language="en",
        )
        assert result.is_mock is True
        assert "MOCK_TRANSLATED" in result.translated_text
        assert result.source_language == "ta"
        assert result.target_language == "en"

    async def test_nmt_empty_text_rejected(
        self, bhashini_service: BhashiniService
    ):
        """Empty text raises validation error."""
        with pytest.raises(AudioValidationError):
            await bhashini_service.translate_text("", "hi", "en")


# =====================================================================
# TTS Mock Mode
# =====================================================================


class TestTTSMockMode:
    """Test TTS synthesis in mock mode."""

    async def test_tts_mock_returns_audio(
        self, bhashini_service: BhashiniService
    ):
        """Mock TTS returns base64-encoded silent WAV."""
        result = await bhashini_service.synthesise_speech(
            text="Test speech", language_code="ta"
        )
        assert result.is_mock is True
        assert result.language == "ta"
        # Verify it's valid base64
        audio_bytes = base64.b64decode(result.audio_content)
        assert audio_bytes[:4] == b"RIFF"

    async def test_tts_empty_text_rejected(
        self, bhashini_service: BhashiniService
    ):
        """Empty text raises validation error."""
        with pytest.raises(AudioValidationError):
            await bhashini_service.synthesise_speech("", "ta")


# =====================================================================
# Audio Converter
# =====================================================================


class TestAudioConverter:
    """Test the WAV/PCM audio converter utility."""

    def test_generate_silence_wav(self, mock_settings: Settings):
        """Generated silence WAV is valid."""
        wav = generate_silence_wav(0.5, settings=mock_settings)
        assert wav[:4] == b"RIFF"
        assert wav[8:12] == b"WAVE"

    def test_validate_valid_wav(self, mock_settings: Settings):
        """validate_wav succeeds on properly generated WAV."""
        wav = generate_silence_wav(0.1, settings=mock_settings)
        params = validate_wav(wav)
        assert params.sample_rate == 16000
        assert params.channels == 1
        assert params.sample_width == 2

    def test_extract_pcm_from_wav(self, mock_settings: Settings):
        """extract_pcm_from_wav returns raw samples."""
        wav = generate_silence_wav(0.1, settings=mock_settings)
        pcm, params = extract_pcm_from_wav(wav)
        expected_size = int(16000 * 0.1) * 1 * 2  # rate * dur * channels * width
        assert len(pcm) == expected_size
        assert params.sample_rate == 16000

    def test_convert_pcm_to_wav(self, mock_settings: Settings):
        """Raw PCM data is properly wrapped in WAV container."""
        pcm = b"\x00" * (16000 * 1 * 2)  # 1 second silence
        wav = convert_to_wav(pcm, source_format="pcm", settings=mock_settings)
        assert wav[:4] == b"RIFF"
        params = validate_wav(wav)
        assert params.sample_rate == 16000

    def test_convert_wav_passthrough(self, mock_settings: Settings):
        """WAV input with matching params passes through."""
        original = generate_silence_wav(0.1, settings=mock_settings)
        result = convert_to_wav(original, source_format="wav", settings=mock_settings)
        assert result[:4] == b"RIFF"

    def test_empty_audio_rejected(self, mock_settings: Settings):
        """Empty audio data raises AudioValidationError."""
        with pytest.raises(AudioValidationError):
            convert_to_wav(b"", source_format="wav", settings=mock_settings)

    def test_unsupported_format_rejected(self, mock_settings: Settings):
        """Unsupported format raises AudioValidationError."""
        with pytest.raises(AudioValidationError):
            convert_to_wav(b"data", source_format="mp3", settings=mock_settings)

    def test_malformed_wav_rejected(self, mock_settings: Settings):
        """Non-WAV data labelled as WAV is rejected."""
        with pytest.raises(AudioValidationError):
            convert_to_wav(b"not a wav file at all!!" * 5, source_format="wav", settings=mock_settings)

    def test_validate_too_small(self):
        """WAV data smaller than header is rejected."""
        with pytest.raises(AudioValidationError):
            validate_wav(b"\x00" * 10)


# =====================================================================
# Live API Simulation (mocked HTTP)
# =====================================================================


class TestLiveAPISimulation:
    """Simulate real Bhashini API calls with mocked httpx responses."""

    async def test_successful_live_asr(self, sample_wav_tamil: bytes):
        """Simulated successful Bhashini ASR returns parsed transcript."""
        settings = Settings(
            bhashini_mock_mode=False,
            bhashini_api_key="test-key",
            bhashini_user_id="test-user",
        )
        svc = BhashiniService(settings=settings)

        bhashini_response = {
            "pipelineResponse": [
                {
                    "taskType": "asr",
                    "output": [
                        {"source": "புயல் எச்சரிக்கை உள்ளதா"}
                    ],
                }
            ]
        }

        mock_http_response = httpx.Response(
            status_code=200,
            json=bhashini_response,
            request=httpx.Request("POST", "https://example.com"),
        )

        with patch.object(svc, "_get_client") as mock_client_factory:
            mock_client = AsyncMock()
            mock_client.post = AsyncMock(return_value=mock_http_response)
            mock_client.is_closed = False
            mock_client_factory.return_value = mock_client

            result = await svc.transcribe_audio(sample_wav_tamil, "ta")
            assert result.text == "புயல் எச்சரிக்கை உள்ளதா"
            assert result.language == "ta"
            assert result.is_mock is False

        await svc.close()

    async def test_live_asr_sends_correct_payload(self, sample_wav_hindi: bytes):
        """Verify the payload sent to Bhashini contains correct language and audio."""
        settings = Settings(
            bhashini_mock_mode=False,
            bhashini_api_key="test-key",
            bhashini_user_id="test-user",
        )
        svc = BhashiniService(settings=settings)

        bhashini_response = {
            "pipelineResponse": [
                {
                    "taskType": "asr",
                    "output": [{"source": "टेस्ट"}],
                }
            ]
        }

        mock_http_response = httpx.Response(
            status_code=200,
            json=bhashini_response,
            request=httpx.Request("POST", "https://example.com"),
        )

        with patch.object(svc, "_get_client") as mock_client_factory:
            mock_client = AsyncMock()
            mock_client.post = AsyncMock(return_value=mock_http_response)
            mock_client.is_closed = False
            mock_client_factory.return_value = mock_client

            await svc.transcribe_audio(sample_wav_hindi, "hi")

            # Inspect the call
            call_args = mock_client.post.call_args
            payload = call_args.kwargs.get("json") or call_args[1].get("json")
            assert payload is not None

            # Verify language in payload
            task_config = payload["pipelineTasks"][0]["config"]
            assert task_config["language"]["sourceLanguage"] == "hi"

            # Verify audio content is base64
            audio_b64 = payload["inputData"]["audio"][0]["audioContent"]
            decoded = base64.b64decode(audio_b64)
            assert decoded == sample_wav_hindi

            # Verify auth headers
            headers = call_args.kwargs.get("headers") or call_args[1].get("headers")
            assert headers["userID"] == "test-user"
            assert headers["ulcaApiKey"] == "test-key"

        await svc.close()
