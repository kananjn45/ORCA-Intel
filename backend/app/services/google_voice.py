"""
ORCA — Google Cloud Translation, Speech-to-Text (ASR) & Text-to-Speech (TTS) Service.

Implements the Dev 4 Multilingual Voice & Translation Pipeline using Google Cloud Console APIs:
* Google Cloud Translation API (v2 REST): Indic <-> English bidirectional translation
* Google Cloud Speech-to-Text API (v1 REST): Regional Indic speech recognition
* Google Cloud Text-to-Speech API (v1 REST): Regional Indic speech synthesis
* Localized contextual fallback engine: 100% offline & test compatibility
"""

from __future__ import annotations

import base64
import html
import io
import math
import struct
from typing import Any, Dict, Optional, Tuple

import httpx

from app.core.config import Settings, get_settings
from app.core.exceptions import (
    AudioValidationError,
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

logger = get_logger("orca.google_voice")

# Supported language codes in ORCA
_VALID_LANGUAGE_CODES: set[str] = {lc.value for lc in LanguageCode}
_VALID_AUDIO_FORMATS: set[str] = {"wav", "pcm", "flac", "mp3", "ogg", "webm"}
_MIN_AUDIO_SIZE = 44

# Google Cloud Speech and TTS BCP-47 locale code mappings for Indian coastal languages
GOOGLE_SPEECH_LOCALES: Dict[str, str] = {
    "ta": "ta-IN",
    "te": "te-IN",
    "hi": "hi-IN",
    "bn": "bn-IN",
    "gu": "gu-IN",
    "kn": "kn-IN",
    "ml": "ml-IN",
    "mr": "mr-IN",
    "or": "or-IN",
    "pa": "pa-IN",
    "en": "en-IN",
}

# Deterministic mock transcripts for testing and offline fallback
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
        "Good fishing zone found": "మంచి చేపల వేట ప్రాంతం కనుగొనబడింది",
    },
}


def _validate_language(language_code: str) -> str:
    """Normalise and validate language code."""
    code = language_code.strip().lower()
    if code not in _VALID_LANGUAGE_CODES:
        raise UnsupportedLanguageError(code)
    return code


def _validate_audio_format(fmt: str) -> str:
    """Normalise and validate audio format."""
    fmt = fmt.strip().lower()
    if fmt not in _VALID_AUDIO_FORMATS:
        raise AudioValidationError(f"Unsupported audio format: '{fmt}'")
    return fmt


def _validate_audio_data(data: bytes) -> None:
    """Validate raw audio bytes."""
    if not data:
        raise AudioValidationError("Audio data is empty")
    if len(data) < _MIN_AUDIO_SIZE:
        raise AudioValidationError(
            f"Audio data too small ({len(data)} bytes); minimum is {_MIN_AUDIO_SIZE}"
        )


def _generate_mock_wav(duration_s: float = 0.5, freq: float = 440.0, sample_rate: int = 16000) -> str:
    """Generate in-memory valid PCM WAV audio encoded as Base64."""
    num_samples = int(duration_s * sample_rate)
    data_size = num_samples * 2
    buf = io.BytesIO()

    # RIFF header
    buf.write(b"RIFF")
    buf.write(struct.pack("<I", 36 + data_size))
    buf.write(b"WAVE")

    # fmt subchunk
    buf.write(b"fmt ")
    buf.write(struct.pack("<I", 16))
    buf.write(struct.pack("<H", 1))   # PCM
    buf.write(struct.pack("<H", 1))   # Mono
    buf.write(struct.pack("<I", sample_rate))
    buf.write(struct.pack("<I", sample_rate * 2))
    buf.write(struct.pack("<H", 2))   # Block align
    buf.write(struct.pack("<H", 16))  # Bits per sample

    # data subchunk
    buf.write(b"data")
    buf.write(struct.pack("<I", data_size))

    # Sine wave samples
    for i in range(num_samples):
        sample = int(16000 * math.sin(2 * math.pi * freq * (i / sample_rate)))
        buf.write(struct.pack("<h", sample))

    return base64.b64encode(buf.getvalue()).decode("utf-8")


class GoogleTranslationService:
    """Service client for Google Cloud Translation API v2."""

    def __init__(self, settings: Optional[Settings] = None) -> None:
        self._settings = settings or get_settings()

    @property
    def api_key(self) -> str:
        return self._settings.google_api_key

    @property
    def is_mock(self) -> bool:
        return self._settings.use_google_mock

    async def translate_text(
        self,
        text: str,
        source_language: str,
        target_language: str,
    ) -> NMTResult:
        """Translate text between Indic regional languages and English."""
        src = _validate_language(source_language)
        tgt = _validate_language(target_language)

        clean_text = text.strip()
        if not clean_text:
            return NMTResult(
                translated_text="",
                source_language=src,
                target_language=tgt,
                is_mock=False,
            )

        # Same language: identity return
        if src == tgt:
            return NMTResult(
                translated_text=clean_text,
                source_language=src,
                target_language=tgt,
                is_mock=False,
            )

        # Use mock mode if API key is not configured or in mock setting
        if self.is_mock:
            return self._mock_translation(clean_text, src, tgt)

        endpoint = self._settings.GOOGLE_TRANSLATE_ENDPOINT
        url = f"{endpoint}?key={self.api_key}"
        payload = {
            "q": clean_text,
            "source": src,
            "target": tgt,
            "format": "text",
        }

        try:
            async with httpx.AsyncClient(timeout=self._settings.google_timeout_seconds) as client:
                resp = await client.post(url, json=payload)
                resp.raise_for_status()
                data = resp.json()

            translations = data.get("data", {}).get("translations", [])
            if translations and "translatedText" in translations[0]:
                raw_translation = translations[0]["translatedText"]
                translated_text = html.unescape(raw_translation)
                logger.info(
                    "Google Cloud Translate success: %s -> %s (chars=%d)",
                    src,
                    tgt,
                    len(clean_text),
                )
                return NMTResult(
                    translated_text=translated_text,
                    source_language=src,
                    target_language=tgt,
                    is_mock=False,
                )
            else:
                logger.warning("Empty response from Google Cloud Translate, falling back to mock")
                return self._mock_translation(clean_text, src, tgt)

        except Exception as exc:
            logger.warning(
                "Google Cloud Translate API failed (%s); falling back to mock translation",
                str(exc),
            )
            return self._mock_translation(clean_text, src, tgt)

    def _mock_translation(self, text: str, src: str, tgt: str) -> NMTResult:
        """Deterministic mock translation fallback."""
        translated: Optional[str] = None
        if tgt == "en" and src in _MOCK_NMT_INDIC_TO_EN:
            translated = _MOCK_NMT_INDIC_TO_EN[src].get(text)
        elif src == "en" and tgt in _MOCK_NMT_EN_TO_INDIC:
            translated = _MOCK_NMT_EN_TO_INDIC[tgt].get(text)

        if translated is None:
            translated = f"{_MOCK_NMT_PREFIX}{text}"

        return NMTResult(
            translated_text=translated,
            source_language=src,
            target_language=tgt,
            is_mock=True,
        )


class GoogleSpeechService:
    """Service client for Google Cloud Speech-to-Text and Text-to-Speech APIs."""

    def __init__(self, settings: Optional[Settings] = None) -> None:
        self._settings = settings or get_settings()

    @property
    def api_key(self) -> str:
        return self._settings.google_api_key

    @property
    def is_mock(self) -> bool:
        return self._settings.use_google_mock

    async def transcribe_audio(
        self,
        audio_data: bytes,
        language_code: str = "ta",
        audio_format: str = "wav",
    ) -> ASRResult:
        """Transcribe speech audio bytes using Google Cloud Speech-to-Text v1."""
        lang = _validate_language(language_code)
        _validate_audio_format(audio_format)
        _validate_audio_data(audio_data)

        if self.is_mock:
            return self._mock_transcribe(lang)

        endpoint = self._settings.GOOGLE_SPEECH_ENDPOINT
        url = f"{endpoint}?key={self.api_key}"
        locale = GOOGLE_SPEECH_LOCALES.get(lang, f"{lang}-IN")

        audio_b64 = base64.b64encode(audio_data).decode("utf-8")
        payload = {
            "config": {
                "encoding": "LINEAR16",
                "sampleRateHertz": self._settings.audio_sample_rate,
                "languageCode": locale,
                "enableAutomaticPunctuation": True,
            },
            "audio": {
                "content": audio_b64,
            },
        }

        try:
            async with httpx.AsyncClient(timeout=self._settings.google_timeout_seconds) as client:
                resp = await client.post(url, json=payload)
                resp.raise_for_status()
                data = resp.json()

            results = data.get("results", [])
            if results and "alternatives" in results[0]:
                alt = results[0]["alternatives"][0]
                transcript = alt.get("transcript", "").strip()
                confidence = float(alt.get("confidence", 0.92))
                logger.info("Google Speech-to-Text recognised: '%s' (%s)", transcript, locale)
                return ASRResult(
                    text=transcript or _MOCK_ASR_TRANSCRIPTS.get(lang, "MOCK: Speech recognised"),
                    language=lang,
                    is_mock=False,
                    confidence=confidence,
                )
            else:
                logger.warning("Empty results from Google Speech-to-Text; using mock transcript")
                return self._mock_transcribe(lang)

        except Exception as exc:
            logger.warning("Google Speech-to-Text failed (%s); using mock transcript", str(exc))
            return self._mock_transcribe(lang)

    async def synthesise_speech(
        self,
        text: str,
        language_code: str = "ta",
        gender: str = "female",
    ) -> TTSResult:
        """Synthesise speech audio from text using Google Cloud Text-to-Speech v1."""
        lang = _validate_language(language_code)
        clean_text = text.strip()
        if not clean_text:
            raise AudioValidationError("Text to synthesise cannot be empty")

        if self.is_mock:
            return self._mock_tts(lang)

        endpoint = self._settings.GOOGLE_TTS_ENDPOINT
        url = f"{endpoint}?key={self.api_key}"
        locale = GOOGLE_SPEECH_LOCALES.get(lang, f"{lang}-IN")

        payload = {
            "input": {"text": clean_text},
            "voice": {
                "languageCode": locale,
                "ssmlGender": gender.upper() if gender.upper() in {"MALE", "FEMALE"} else "FEMALE",
            },
            "audioConfig": {
                "audioEncoding": "LINEAR16",
                "sampleRateHertz": self._settings.audio_sample_rate,
            },
        }

        try:
            async with httpx.AsyncClient(timeout=self._settings.google_timeout_seconds) as client:
                resp = await client.post(url, json=payload)
                resp.raise_for_status()
                data = resp.json()

            audio_content = data.get("audioContent")
            if audio_content:
                logger.info("Google TTS synthesised %d bytes of audio for %s", len(audio_content), locale)
                return TTSResult(
                    audio_content=audio_content,
                    language=lang,
                    audio_format="wav",
                    is_mock=False,
                )
            else:
                logger.warning("Empty audioContent from Google TTS; using mock audio")
                return self._mock_tts(lang)

        except Exception as exc:
            logger.warning("Google TTS API failed (%s); using mock audio", str(exc))
            return self._mock_tts(lang)

    def _mock_transcribe(self, lang: str) -> ASRResult:
        return ASRResult(
            text=_MOCK_ASR_TRANSCRIPTS.get(lang, _MOCK_ASR_TRANSCRIPTS["ta"]),
            language=lang,
            is_mock=True,
            confidence=0.95,
        )

    def _mock_tts(self, lang: str) -> TTSResult:
        return TTSResult(
            audio_content=_generate_mock_wav(),
            language=lang,
            audio_format="wav",
            is_mock=True,
        )


class GoogleVoiceService:
    """Unified service combining Google Cloud Translation, ASR and TTS."""

    def __init__(self, settings: Optional[Settings] = None) -> None:
        self._settings = settings or get_settings()
        self._translator = GoogleTranslationService(self._settings)
        self._speech = GoogleSpeechService(self._settings)

    @property
    def settings(self) -> Settings:
        return self._settings

    @property
    def translator(self) -> GoogleTranslationService:
        return self._translator

    @property
    def speech(self) -> GoogleSpeechService:
        return self._speech

    async def transcribe_audio(
        self,
        audio_data: bytes,
        language_code: str = "ta",
        audio_format: str = "wav",
    ) -> ASRResult:
        return await self._speech.transcribe_audio(audio_data, language_code, audio_format)

    async def translate_text(
        self,
        text: str,
        source_language: str,
        target_language: str,
    ) -> NMTResult:
        return await self._translator.translate_text(text, source_language, target_language)

    async def synthesise_speech(
        self,
        text: str,
        language_code: str = "ta",
        gender: str = "female",
    ) -> TTSResult:
        return await self._speech.synthesise_speech(text, language_code, gender)

    async def asr_then_translate(
        self,
        audio_data: bytes,
        source_language: str = "ta",
        target_language: str = "en",
        audio_format: str = "wav",
    ) -> Tuple[ASRResult, NMTResult]:
        """Speech -> Transcript -> Translated text pipeline."""
        asr_result = await self.transcribe_audio(audio_data, source_language, audio_format)
        if source_language == target_language:
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
        gender: str = "female",
    ) -> Tuple[NMTResult, TTSResult]:
        """Translation -> Speech synthesis pipeline."""
        if source_language == target_language:
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
