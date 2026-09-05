"""
ORCA — Bhashini ASR / NMT / TTS Service Wrapper.

Provides a clean async abstraction around the Bhashini (ULCA / Dhruva)
pipeline API for:

* **ASR** — Automatic Speech Recognition
* **NMT** — Neural Machine Translation
* **TTS** — Text-to-Speech

When Bhashini credentials are absent, unavailable, or returning errors
the service falls back to a deterministic **mock mode** suitable for
local development and automated testing.

Usage::

    from app.services.bhashini import BhashiniService

    svc = BhashiniService()
    result = await svc.transcribe_audio(audio_bytes, "ta")
"""

from __future__ import annotations

import base64
import hashlib
import struct
import io
from typing import Any, Dict, Optional

import httpx

from app.core.config import Settings, get_settings, settings
from app.core.exceptions import (
    AudioValidationError,
    BhashiniAPIError,
    BhashiniConfigurationError,
    BhashiniError,
    BhashiniResponseParseError,
    BhashiniTimeoutError,
    UnsupportedLanguageError,
)
from app.core.logging import get_logger
from app.models.schemas import (
    ASRResult,
    LANGUAGE_NAMES,
    LanguageCode,
    NMTResult,
    TTSResult,
)

logger = get_logger("orca.bhashini")


# ---------------------------------------------------------------------------
# Supported language validation
# ---------------------------------------------------------------------------

_VALID_LANGUAGE_CODES: set[str] = {lc.value for lc in LanguageCode}

# Supported audio formats for ASR input
_VALID_AUDIO_FORMATS: set[str] = {"wav", "pcm", "flac", "mp3", "ogg", "webm"}

# Minimum audio payload size (bytes) — a valid WAV header alone is 44 B
_MIN_AUDIO_SIZE = 44


def _validate_language(language_code: str) -> str:
    """Normalise and validate a language code.

    Returns the lowered code on success.
    Raises :class:`UnsupportedLanguageError` otherwise.
    """
    code = language_code.strip().lower()
    if code not in _VALID_LANGUAGE_CODES:
        raise UnsupportedLanguageError(code)
    return code


def _validate_audio_format(fmt: str) -> str:
    """Normalise and validate an audio format string."""
    fmt = fmt.strip().lower()
    if fmt not in _VALID_AUDIO_FORMATS:
        raise AudioValidationError(f"Unsupported audio format: '{fmt}'")
    return fmt


def _validate_audio_data(data: bytes) -> None:
    """Raise :class:`AudioValidationError` when *data* is empty or too small."""
    if not data:
        raise AudioValidationError("Audio data is empty")
    if len(data) < _MIN_AUDIO_SIZE:
        raise AudioValidationError(
            f"Audio data too small ({len(data)} bytes); minimum is {_MIN_AUDIO_SIZE}"
        )


# ---------------------------------------------------------------------------
# Mock / Fallback deterministic transcripts
# ---------------------------------------------------------------------------

_MOCK_ASR_TRANSCRIPTS: Dict[str, str] = {
    "hi": "MOCK: यह एक परीक्षण हिन्दी प्रतिलेख है",
    "ta": "MOCK: இது ஒரு சோதனை தமிழ் படியெடுப்பு",
    "te": "MOCK: ఇది ఒక పరీక్ష తెలుగు ట్రాన్స్‌క్రిప్షన్",
    "bn": "MOCK: এটি একটি পরীক্ষা বাংলা প্রতিলিপি",
    "gu": "MOCK: આ એક કસોટી ગુજરાતી ટ્રાન્સક્રિપ્શન છે",
    "kn": "MOCK: ಇದು ಒಂದು ಪರೀಕ್ಷಾ ಕನ್ನಡ ಲಿಪ್ಯಂತರ",
    "ml": "MOCK: ഇത് ഒരു ടെസ്റ്റ് മലയാളം ട്രാൻസ്‌ക്രിപ്ഷൻ ആണ്",
    "mr": "MOCK: हे एक चाचणी मराठी प्रतिलेखन आहे",
    "or": "MOCK: ଏହା ଏକ ପରୀକ୍ଷା ଓଡ଼ିଆ ଟ୍ରାନ୍ସକ୍ରିପସନ",
    "pa": "MOCK: ਇਹ ਇੱਕ ਟੈਸਟ ਪੰਜਾਬੀ ਟ੍ਰਾਂਸਕ੍ਰਿਪਸ਼ਨ ਹੈ",
    "en": "MOCK: This is a test English transcription",
}

_MOCK_NMT_PREFIX = "MOCK_TRANSLATED: "

# Deterministic mock translations for Indic → English
_MOCK_NMT_INDIC_TO_EN: Dict[str, Dict[str, str]] = {
    "hi": {
        "मुझे मौसम बताओ": "Tell me the weather",
        "मछली पकड़ने का अच्छा क्षेत्र कहाँ है": "Where is a good fishing area",
        "तूफान की चेतावनी है क्या": "Is there a storm warning",
        "सीमा कितनी दूर है": "How far is the border",
    },
    "ta": {
        "புயல் எச்சரிக்கை உள்ளதா": "Is there a storm warning",
        "நல்ல மீன்பிடி பகுதி எங்கே": "Where is a good fishing area",
        "வானிலை என்ன": "What is the weather",
        "எல்லை எவ்வளவு தொலைவில் உள்ளது": "How far is the border",
    },
    "te": {
        "తుఫాను హెచ్చరిక ఉందా": "Is there a storm warning",
        "మంచి చేపల పట్టే ప్రదేశం ఎక్కడ": "Where is a good fishing area",
        "వాతావరణం ఏమిటి": "What is the weather",
        "సరిహద్దు ఎంత దూరంలో ఉంది": "How far is the border",
    },
}

# English → Indic deterministic mock translations (for response path)
_MOCK_NMT_EN_TO_INDIC: Dict[str, Dict[str, str]] = {
    "hi": {
        "The weather is calm": "मौसम शांत है",
        "Warning: border approaching": "चेतावनी: सीमा नजदीक आ रही है",
        "Good fishing zone found": "अच्छा मछली पकड़ने का क्षेत्र मिला",
    },
    "ta": {
        "The weather is calm": "வானிலை அமைதியாக உள்ளது",
        "Warning: border approaching": "எச்சரிக்கை: எல்லை நெருங்குகிறது",
        "Good fishing zone found": "நல்ல மீன்பிடி மண்டலம் கண்டுபிடிக்கப்பட்டது",
    },
    "te": {
        "The weather is calm": "వాతావరణం ప్రశాంతంగా ఉంది",
        "Warning: border approaching": "హెచ్చరిక: సరిహద్దు సమీపిస్తోంది",
        "Good fishing zone found": "మంచి చేపల పట్టే ప్రదేశం కనుగొనబడింది",
    },
}

_MOCK_TTS_AUDIO_CONTENT = ""  # Populated lazily with a tiny valid WAV


def _generate_mock_tts_audio() -> str:
    """Generate a minimal valid WAV file (silence) encoded as base64.

    This produces a 0.1-second mono 16-bit PCM WAV at 16 kHz.
    """
    sample_rate = 16000
    num_samples = int(sample_rate * 0.1)  # 0.1 s
    num_channels = 1
    sample_width = 2  # 16-bit
    data_size = num_samples * num_channels * sample_width

    buf = io.BytesIO()
    # RIFF header
    buf.write(b"RIFF")
    buf.write(struct.pack("<I", 36 + data_size))
    buf.write(b"WAVE")
    # fmt sub-chunk
    buf.write(b"fmt ")
    buf.write(struct.pack("<I", 16))  # sub-chunk size
    buf.write(struct.pack("<H", 1))   # PCM
    buf.write(struct.pack("<H", num_channels))
    buf.write(struct.pack("<I", sample_rate))
    buf.write(struct.pack("<I", sample_rate * num_channels * sample_width))  # byte rate
    buf.write(struct.pack("<H", num_channels * sample_width))  # block align
    buf.write(struct.pack("<H", sample_width * 8))  # bits per sample
    # data sub-chunk
    buf.write(b"data")
    buf.write(struct.pack("<I", data_size))
    buf.write(b"\x00" * data_size)

    return base64.b64encode(buf.getvalue()).decode("ascii")


# ---------------------------------------------------------------------------
# Bhashini Service
# ---------------------------------------------------------------------------

class BhashiniService:
    """Async wrapper around the Bhashini ULCA / Dhruva pipeline API.

    Automatically falls back to deterministic mock responses when:

    * API credentials are not configured.
    * ``bhashini_mock_mode`` is ``True``.
    * The live API is unreachable or returns an error.

    Args:
        settings: Optional :class:`Settings` override (handy for tests).
    """

    def __init__(self, settings: Optional[Settings] = None) -> None:
        self._settings = settings or get_settings()
        self._client: Optional[httpx.AsyncClient] = None

    # -- lifecycle -----------------------------------------------------------

    async def _get_client(self) -> httpx.AsyncClient:
        """Lazy-initialise and return the shared ``httpx.AsyncClient``."""
        if self._client is None or self._client.is_closed:
            self._client = httpx.AsyncClient(
                timeout=httpx.Timeout(self._settings.bhashini_timeout_seconds),
            )
        return self._client

    async def close(self) -> None:
        """Gracefully close the underlying HTTP client."""
        if self._client and not self._client.is_closed:
            await self._client.aclose()
            self._client = None

    # ======================================================================
    # ASR — Automatic Speech Recognition
    # ======================================================================

    async def transcribe_audio(
        self,
        audio_data: bytes,
        language_code: str,
        audio_format: str = "wav",
        sample_rate: int | None = None,
        *,
        service_id: str | None = None,
    ) -> ASRResult:
        """Transcribe speech audio into text.

        Args:
            audio_data: Raw audio bytes (WAV, PCM, FLAC, …).
            language_code: ISO 639-1 source language (``"ta"``, ``"hi"``, …).
            audio_format: Container format of *audio_data*.
            sample_rate: Sample rate in Hz.  Defaults to settings value.
            service_id: Optional Bhashini ASR model service ID override.

        Returns:
            An :class:`ASRResult` with the transcript.

        Raises:
            AudioValidationError: If audio is empty / malformed.
            UnsupportedLanguageError: If language is not supported.
            BhashiniError: On unrecoverable API failures (only when mock
                fallback itself is disabled or also fails).
        """
        # 1. Validate inputs
        language_code = _validate_language(language_code)
        audio_format = _validate_audio_format(audio_format)
        _validate_audio_data(audio_data)
        sample_rate = sample_rate or self._settings.audio_sample_rate

        # 2. Mock mode — fast path
        if self._settings.use_bhashini_mock:
            logger.info("ASR mock mode — returning deterministic transcript for '%s'", language_code)
            return self._mock_asr(language_code)

        # 3. Live Bhashini call with automatic fallback on failure
        try:
            return await self._live_asr(
                audio_data=audio_data,
                language_code=language_code,
                audio_format=audio_format,
                sample_rate=sample_rate,
                service_id=service_id,
            )
        except (BhashiniAPIError, BhashiniTimeoutError, BhashiniResponseParseError) as exc:
            logger.warning(
                "Bhashini ASR call failed (%s); falling back to mock mode",
                exc.message,
            )
            return self._mock_asr(language_code)
        except httpx.HTTPError as exc:
            logger.warning(
                "Bhashini ASR network error (%s); falling back to mock mode",
                type(exc).__name__,
            )
            return self._mock_asr(language_code)

    # -- ASR internals -------------------------------------------------------

    async def _live_asr(
        self,
        audio_data: bytes,
        language_code: str,
        audio_format: str,
        sample_rate: int,
        service_id: str | None,
    ) -> ASRResult:
        """Execute a real Bhashini ASR pipeline call."""
        audio_b64 = base64.b64encode(audio_data).decode("ascii")

        payload: Dict[str, Any] = {
            "pipelineTasks": [
                {
                    "taskType": "asr",
                    "config": {
                        "language": {"sourceLanguage": language_code},
                        "audioFormat": audio_format,
                        "samplingRate": sample_rate,
                    },
                },
            ],
            "inputData": {
                "audio": [{"audioContent": audio_b64}],
            },
        }

        # Inject serviceId if provided
        if service_id:
            payload["pipelineTasks"][0]["config"]["serviceId"] = service_id

        headers = self._build_headers()
        client = await self._get_client()

        try:
            response = await client.post(
                self._settings.bhashini_inference_endpoint,
                json=payload,
                headers=headers,
            )
        except httpx.TimeoutException:
            raise BhashiniTimeoutError()
        except httpx.HTTPError:
            raise

        if response.status_code != 200:
            raise BhashiniAPIError(
                message="Bhashini ASR returned non-200",
                status_code=response.status_code,
            )

        return self._parse_asr_response(response.json(), language_code)

    @staticmethod
    def _parse_asr_response(data: Dict[str, Any], language_code: str) -> ASRResult:
        """Extract the transcript from a Bhashini pipeline response.

        Expected structure::

            {
              "pipelineResponse": [
                {
                  "taskType": "asr",
                  "output": [{"source": "recognised text"}]
                }
              ]
            }
        """
        try:
            pipeline_resp = data["pipelineResponse"]
            for task in pipeline_resp:
                if task.get("taskType") == "asr":
                    outputs = task.get("output", [])
                    if outputs:
                        text = outputs[0].get("source", "")
                        return ASRResult(
                            text=text,
                            language=language_code,
                            is_mock=False,
                        )
            raise BhashiniResponseParseError("No ASR output found in pipeline response")
        except (KeyError, IndexError, TypeError) as exc:
            raise BhashiniResponseParseError(
                f"Unexpected Bhashini response structure: {type(exc).__name__}"
            )

    @staticmethod
    def _mock_asr(language_code: str) -> ASRResult:
        """Return a deterministic mock ASR result."""
        text = _MOCK_ASR_TRANSCRIPTS.get(
            language_code,
            f"MOCK: Unsupported mock language ({language_code})",
        )
        return ASRResult(text=text, language=language_code, is_mock=True)

    # ======================================================================
    # NMT — Neural Machine Translation
    # ======================================================================

    async def translate_text(
        self,
        text: str,
        source_language: str,
        target_language: str,
        *,
        service_id: str | None = None,
    ) -> NMTResult:
        """Translate text between languages.

        Args:
            text: Source text.
            source_language: Source language code.
            target_language: Target language code.
            service_id: Optional Bhashini NMT model service ID.

        Returns:
            An :class:`NMTResult` with translated text.
        """
        source_language = _validate_language(source_language)
        target_language = _validate_language(target_language)

        if not text or not text.strip():
            raise AudioValidationError("Translation source text is empty")

        if self._settings.use_bhashini_mock:
            logger.info("NMT mock mode — returning mock translation")
            return self._mock_nmt(text, source_language, target_language)

        try:
            return await self._live_nmt(text, source_language, target_language, service_id)
        except (BhashiniAPIError, BhashiniTimeoutError, BhashiniResponseParseError) as exc:
            logger.warning("Bhashini NMT failed (%s); falling back to mock", exc.message)
            return self._mock_nmt(text, source_language, target_language)
        except httpx.HTTPError as exc:
            logger.warning("Bhashini NMT network error (%s); mock fallback", type(exc).__name__)
            return self._mock_nmt(text, source_language, target_language)

    async def _live_nmt(
        self,
        text: str,
        source_language: str,
        target_language: str,
        service_id: str | None,
    ) -> NMTResult:
        """Execute a real Bhashini NMT pipeline call."""
        payload: Dict[str, Any] = {
            "pipelineTasks": [
                {
                    "taskType": "translation",
                    "config": {
                        "language": {
                            "sourceLanguage": source_language,
                            "targetLanguage": target_language,
                        },
                    },
                },
            ],
            "inputData": {
                "input": [{"source": text}],
            },
        }
        if service_id:
            payload["pipelineTasks"][0]["config"]["serviceId"] = service_id

        headers = self._build_headers()
        client = await self._get_client()

        try:
            response = await client.post(
                self._settings.bhashini_inference_endpoint,
                json=payload,
                headers=headers,
            )
        except httpx.TimeoutException:
            raise BhashiniTimeoutError()

        if response.status_code != 200:
            raise BhashiniAPIError(status_code=response.status_code)

        return self._parse_nmt_response(response.json(), source_language, target_language)

    @staticmethod
    def _parse_nmt_response(
        data: Dict[str, Any],
        source_language: str,
        target_language: str,
    ) -> NMTResult:
        """Extract translated text from a Bhashini NMT response."""
        try:
            for task in data["pipelineResponse"]:
                if task.get("taskType") == "translation":
                    outputs = task.get("output", [])
                    if outputs:
                        translated = outputs[0].get("target", "")
                        return NMTResult(
                            translated_text=translated,
                            source_language=source_language,
                            target_language=target_language,
                            is_mock=False,
                        )
            raise BhashiniResponseParseError("No NMT output in response")
        except (KeyError, IndexError, TypeError) as exc:
            raise BhashiniResponseParseError(str(exc))

    @staticmethod
    def _mock_nmt(text: str, source_language: str, target_language: str) -> NMTResult:
        """Return deterministic mock translation.

        Uses a lookup table of known phrases for realistic mock results.
        Falls back to a prefixed copy for unknown phrases.
        """
        translated = None

        # Try Indic → English lookup
        if target_language == "en" and source_language in _MOCK_NMT_INDIC_TO_EN:
            translated = _MOCK_NMT_INDIC_TO_EN[source_language].get(text.strip())

        # Try English → Indic lookup
        if source_language == "en" and target_language in _MOCK_NMT_EN_TO_INDIC:
            translated = _MOCK_NMT_EN_TO_INDIC[target_language].get(text.strip())

        if translated is None:
            translated = f"{_MOCK_NMT_PREFIX}{text}"

        return NMTResult(
            translated_text=translated,
            source_language=source_language,
            target_language=target_language,
            is_mock=True,
        )

    # ======================================================================
    # TTS — Text-to-Speech
    # ======================================================================

    async def synthesise_speech(
        self,
        text: str,
        language_code: str,
        *,
        gender: str = "female",
        audio_format: str = "wav",
        service_id: str | None = None,
    ) -> TTSResult:
        """Synthesise text into spoken audio.

        Args:
            text: Text to speak.
            language_code: Language code.
            gender: ``"male"`` or ``"female"``.
            audio_format: Desired output format.
            service_id: Optional Bhashini TTS service ID.

        Returns:
            A :class:`TTSResult` with base64-encoded audio.
        """
        language_code = _validate_language(language_code)
        if not text or not text.strip():
            raise AudioValidationError("TTS source text is empty")

        if self._settings.use_bhashini_mock:
            logger.info("TTS mock mode — returning silent WAV")
            return self._mock_tts(language_code, audio_format)

        try:
            return await self._live_tts(text, language_code, gender, audio_format, service_id)
        except (BhashiniAPIError, BhashiniTimeoutError, BhashiniResponseParseError) as exc:
            logger.warning("Bhashini TTS failed (%s); mock fallback", exc.message)
            return self._mock_tts(language_code, audio_format)
        except httpx.HTTPError as exc:
            logger.warning("Bhashini TTS network error (%s); mock fallback", type(exc).__name__)
            return self._mock_tts(language_code, audio_format)

    async def _live_tts(
        self,
        text: str,
        language_code: str,
        gender: str,
        audio_format: str,
        service_id: str | None,
    ) -> TTSResult:
        """Execute a real Bhashini TTS pipeline call."""
        payload: Dict[str, Any] = {
            "pipelineTasks": [
                {
                    "taskType": "tts",
                    "config": {
                        "language": {"sourceLanguage": language_code},
                        "gender": gender,
                        "audioFormat": audio_format,
                    },
                },
            ],
            "inputData": {
                "input": [{"source": text}],
            },
        }
        if service_id:
            payload["pipelineTasks"][0]["config"]["serviceId"] = service_id

        headers = self._build_headers()
        client = await self._get_client()

        try:
            response = await client.post(
                self._settings.bhashini_inference_endpoint,
                json=payload,
                headers=headers,
            )
        except httpx.TimeoutException:
            raise BhashiniTimeoutError()

        if response.status_code != 200:
            raise BhashiniAPIError(status_code=response.status_code)

        return self._parse_tts_response(response.json(), language_code, audio_format)

    @staticmethod
    def _parse_tts_response(
        data: Dict[str, Any],
        language_code: str,
        audio_format: str,
    ) -> TTSResult:
        """Extract audio content from a Bhashini TTS response."""
        try:
            for task in data["pipelineResponse"]:
                if task.get("taskType") == "tts":
                    audios = task.get("audio", [])
                    if audios:
                        content = audios[0].get("audioContent", "")
                        return TTSResult(
                            audio_content=content,
                            language=language_code,
                            audio_format=audio_format,
                            is_mock=False,
                        )
            raise BhashiniResponseParseError("No TTS audio in response")
        except (KeyError, IndexError, TypeError) as exc:
            raise BhashiniResponseParseError(str(exc))

    @staticmethod
    def _mock_tts(language_code: str, audio_format: str) -> TTSResult:
        global _MOCK_TTS_AUDIO_CONTENT
        if not _MOCK_TTS_AUDIO_CONTENT:
            _MOCK_TTS_AUDIO_CONTENT = _generate_mock_tts_audio()
        return TTSResult(
            audio_content=_MOCK_TTS_AUDIO_CONTENT,
            language=language_code,
            audio_format=audio_format,
            is_mock=True,
        )

    # ======================================================================
    # Pipeline Orchestration (Day 2)
    # ======================================================================

    async def asr_then_translate(
        self,
        audio_data: bytes,
        source_language: str,
        target_language: str = "en",
        audio_format: str = "wav",
    ) -> tuple[ASRResult, NMTResult]:
        """Full pipeline: speech audio → transcript → translated text.

        Typical use: fisherman speaks Tamil → ASR → Tamil text → NMT → English.

        Args:
            audio_data: Raw audio bytes.
            source_language: Language the user is speaking.
            target_language: Target language (usually ``"en"`` for LLM input).
            audio_format: Audio container format.

        Returns:
            Tuple of ``(ASRResult, NMTResult)``.
        """
        asr_result = await self.transcribe_audio(
            audio_data=audio_data,
            language_code=source_language,
            audio_format=audio_format,
        )

        # Skip translation if source == target
        if source_language.strip().lower() == target_language.strip().lower():
            nmt_result = NMTResult(
                translated_text=asr_result.text,
                source_language=source_language,
                target_language=target_language,
                is_mock=asr_result.is_mock,
            )
        else:
            nmt_result = await self.translate_text(
                text=asr_result.text,
                source_language=source_language,
                target_language=target_language,
            )

        return asr_result, nmt_result

    async def translate_then_tts(
        self,
        text: str,
        source_language: str = "en",
        target_language: str = "ta",
        *,
        gender: str = "female",
    ) -> tuple[NMTResult, TTSResult]:
        """Full pipeline: English text → translation → spoken audio.

        Typical use: ORCA LLM English response → NMT → Tamil → TTS → audio.

        Args:
            text: The text to translate and speak.
            source_language: Source language (usually ``"en"``).
            target_language: Target Indic language for speech output.
            gender: Voice gender preference.

        Returns:
            Tuple of ``(NMTResult, TTSResult)``.
        """
        # Skip translation if source == target
        if source_language.strip().lower() == target_language.strip().lower():
            nmt_result = NMTResult(
                translated_text=text,
                source_language=source_language,
                target_language=target_language,
                is_mock=False,
            )
        else:
            nmt_result = await self.translate_text(
                text=text,
                source_language=source_language,
                target_language=target_language,
            )

        tts_result = await self.synthesise_speech(
            text=nmt_result.translated_text,
            language_code=target_language,
            gender=gender,
        )

        return nmt_result, tts_result

    # ======================================================================
    # Internal helpers
    # ======================================================================

    def _build_headers(self) -> Dict[str, str]:
        """Construct authorization headers for Bhashini API calls.

        Never logs or exposes the actual key values.
        """
        if not self._settings.bhashini_configured:
            raise BhashiniConfigurationError()

        return {
            "Content-Type": "application/json",
            "userID": self._settings.bhashini_user_id,
            "ulcaApiKey": self._settings.bhashini_api_key,
            "Authorization": self._settings.bhashini_api_key,
        }


# =========================================================================
# Backward-Compatible Procedural Wrappers (Dev 3 & 4 Test Suite Bridge)
# =========================================================================

SUPPORTED_LANGUAGES = {
    "ta": "Tamil",
    "te": "Telugu",
    "hi": "Hindi",
    "bn": "Bengali",
    "gu": "Gujarati",
    "en": "English",
}


class BhashiniServiceError(BhashiniError):
    """Raised when the upstream Bhashini API cannot be reached or returns an error."""


async def transcribe_audio(
    audio_base64: str,
    source_language: str = "ta",
) -> str:
    """Procedural wrapper for speech transcription returning text string."""
    lang_name = SUPPORTED_LANGUAGES.get(source_language, LANGUAGE_NAMES.get(source_language, source_language))
    try:
        raw = base64.b64decode(str(audio_base64) + "==")[:32]
        seed_hex = hashlib.sha256(raw).hexdigest()[:8]
    except Exception:
        seed_hex = "00000000"

    mock_transcript = f"[MOCK-ASR:{lang_name}:{seed_hex}] நல்ல மீன்பிடி மண்டலம் எங்கே?"
    logger.info(
        "bhashini_asr_mock",
        extra={"extra_fields": {"source_language": source_language, "transcript": mock_transcript}},
    )
    return mock_transcript


async def translate_to_english(text: str, source_language: str = "ta") -> str:
    """Procedural wrapper translating regional language to English."""
    lang_name = SUPPORTED_LANGUAGES.get(source_language, LANGUAGE_NAMES.get(source_language, source_language))
    translated = f"[MOCK-NMT from {lang_name}] Where is the best fishing zone nearby?"
    logger.info(
        "bhashini_nmt_to_en_mock",
        extra={"extra_fields": {"source_language": source_language}},
    )
    return translated


async def translate_from_english(text: str, target_language: str = "ta") -> str:
    """Procedural wrapper translating English to regional language."""
    lang_name = SUPPORTED_LANGUAGES.get(target_language, LANGUAGE_NAMES.get(target_language, target_language))
    translated = f"[MOCK-NMT to {lang_name}] {text}"
    logger.info(
        "bhashini_nmt_from_en_mock",
        extra={"extra_fields": {"target_language": target_language}},
    )
    return translated


async def synthesize_speech(
    text: str,
    target_language: str = "ta",
    gender: str = "female",
) -> str:
    """Procedural wrapper returning base64-encoded synthesized speech audio."""
    lang_name = SUPPORTED_LANGUAGES.get(target_language, LANGUAGE_NAMES.get(target_language, target_language))
    mock_payload = f"MOCK_AUDIO::{lang_name}::{gender}::{text[:80]}"
    return base64.b64encode(mock_payload.encode("utf-8")).decode("ascii")


async def process_voice_query(
    audio_base64: str,
    source_language: str = "ta",
    response_text_en: Optional[str] = None,
) -> dict:
    """Procedural wrapper chaining ASR -> NMT -> NMT -> TTS."""
    transcript = await transcribe_audio(audio_base64, source_language)
    translated_query = await translate_to_english(transcript, source_language)

    en_response = response_text_en or "Advisory: Conditions are currently safe for fishing."
    response_localized = await translate_from_english(en_response, source_language)
    audio_b64 = await synthesize_speech(response_localized, source_language)

    return {
        "transcript": transcript,
        "translated_query": translated_query,
        "response_localized": response_localized,
        "audio_base64": audio_b64,
    }

