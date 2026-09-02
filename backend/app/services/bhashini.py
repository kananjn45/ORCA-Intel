"""
app/services/bhashini.py
Owner: Dev 4 (Voice & Multilingual Specialist)
Scaffold written by: Dev 3 (Data Pipeline & Backend Core Engineer)

Day 1 deliverable — stub / mock Bhashini wrapper so that:
  - The router boots cleanly (voice.py endpoint can import from here)
  - Dev 4 has the exact function signatures to fill with real Bhashini API calls
  - Dev 6 (Flutter) can integrate against the /api/v1/voice/* endpoints NOW

Real Bhashini API (https://bhashini.gov.in/ulca/model/api-integration) requires
auth tokens and a pipeline config call — that integration is Dev 4's Day 1/2 task.
This file is deliberately left as a MOCK so it doesn't block anyone.

Toggle via BHASHINI_USE_MOCK in .env (default: true).
"""
import base64
import hashlib
from typing import Optional

from app.core.config import settings
from app.core.logging import get_logger

logger = get_logger(__name__)

# ---------------------------------------------------------------------------
# Supported language codes (Bhashini BCP-47 tags used in pipeline config)
# ---------------------------------------------------------------------------
SUPPORTED_LANGUAGES = {
    "ta": "Tamil",
    "te": "Telugu",
    "hi": "Hindi",
    "bn": "Bengali",
    "gu": "Gujarati",
    "en": "English",
}


class BhashiniServiceError(Exception):
    """Raised when the upstream Bhashini API cannot be reached or returns an error."""


# ---------------------------------------------------------------------------
# ASR — Automatic Speech Recognition (audio → text)
# ---------------------------------------------------------------------------

async def transcribe_audio(
    audio_base64: str,
    source_language: str = "ta",
) -> str:
    """
    Transcribes spoken audio (base64-encoded WAV/PCM) into text.

    Args:
        audio_base64: Base64-encoded audio bytes.
        source_language: BCP-47 language code of the spoken input.

    Returns:
        Transcribed text string.

    Real implementation (Dev 4):
        POST https://dhruva-api.bhashini.gov.in/services/inference/pipeline
        with a pipeline config referencing the ASR model for source_language.
    """
    if not settings.BHASHINI_USE_MOCK:
        raise BhashiniServiceError(
            "Live Bhashini ASR is not configured. Set BHASHINI_USE_MOCK=true "
            "or implement the real API call in this function (Dev 4 task)."
        )

    # Deterministic mock — decode enough bytes to produce a stable fake transcript
    try:
        raw = base64.b64decode(audio_base64 + "==")[:32]  # first 32 bytes for seed
        seed_hex = hashlib.sha256(raw).hexdigest()[:8]
    except Exception:
        seed_hex = "00000000"

    lang_name = SUPPORTED_LANGUAGES.get(source_language, source_language)
    mock_transcript = f"[MOCK-ASR:{lang_name}:{seed_hex}] நல்ல மீன்பிடி மண்டலம் எங்கே?"
    logger.info(
        "bhashini_asr_mock",
        extra={"extra_fields": {"source_language": source_language, "transcript": mock_transcript}},
    )
    return mock_transcript


# ---------------------------------------------------------------------------
# NMT — Neural Machine Translation (regional language ↔ English)
# ---------------------------------------------------------------------------

async def translate_to_english(text: str, source_language: str = "ta") -> str:
    """
    Translates regional language text to English for LLM reasoning.

    Real implementation (Dev 4):
        POST Bhashini pipeline with NMT model (source_language → en).
    """
    if not settings.BHASHINI_USE_MOCK:
        raise BhashiniServiceError("Live Bhashini NMT not configured.")

    lang_name = SUPPORTED_LANGUAGES.get(source_language, source_language)
    translated = f"[MOCK-NMT from {lang_name}] Where is the best fishing zone nearby?"
    logger.info(
        "bhashini_nmt_to_en_mock",
        extra={"extra_fields": {"source_language": source_language}},
    )
    return translated


async def translate_from_english(text: str, target_language: str = "ta") -> str:
    """
    Translates an English response back into the fisherman's regional language.

    Real implementation (Dev 4):
        POST Bhashini pipeline with NMT model (en → target_language).
    """
    if not settings.BHASHINI_USE_MOCK:
        raise BhashiniServiceError("Live Bhashini NMT not configured.")

    lang_name = SUPPORTED_LANGUAGES.get(target_language, target_language)
    translated = f"[MOCK-NMT to {lang_name}] {text}"
    logger.info(
        "bhashini_nmt_from_en_mock",
        extra={"extra_fields": {"target_language": target_language}},
    )
    return translated


# ---------------------------------------------------------------------------
# TTS — Text-to-Speech (text → audio)
# ---------------------------------------------------------------------------

async def synthesize_speech(
    text: str,
    target_language: str = "ta",
    gender: str = "female",
) -> str:
    """
    Synthesizes spoken audio from text and returns base64-encoded WAV bytes.

    Args:
        text: The advisory text to be spoken.
        target_language: BCP-47 language code for TTS voice.
        gender: Preferred voice gender ("male" / "female").

    Returns:
        Base64-encoded audio string (WAV format in real impl).

    Real implementation (Dev 4):
        POST Bhashini pipeline with TTS model for target_language.
        Decode the returned audio bytes and re-encode as base64 for the
        Flutter `audioplayers` package to stream.
    """
    if not settings.BHASHINI_USE_MOCK:
        raise BhashiniServiceError("Live Bhashini TTS not configured.")

    lang_name = SUPPORTED_LANGUAGES.get(target_language, target_language)
    mock_payload = f"MOCK_AUDIO::{lang_name}::{gender}::{text[:80]}"
    audio_b64 = base64.b64encode(mock_payload.encode("utf-8")).decode("ascii")
    logger.info(
        "bhashini_tts_mock",
        extra={"extra_fields": {"target_language": target_language, "text_length": len(text)}},
    )
    return audio_b64


# ---------------------------------------------------------------------------
# Full pipeline convenience wrapper
# ---------------------------------------------------------------------------

async def process_voice_query(
    audio_base64: str,
    source_language: str = "ta",
    response_text_en: Optional[str] = None,
) -> dict:
    """
    Convenience function that chains ASR → NMT (to EN) → [LLM] → NMT (from EN) → TTS.
    Dev 4 owns the real end-to-end implementation; this mock returns placeholders
    so the chat endpoint has something to call from Day 1.

    Returns a dict with keys:
        transcript         - ASR output (source language text)
        translated_query   - NMT output (English)
        response_localized - NMT output (back to source language)
        audio_base64       - TTS output (base64 WAV)
    """
    transcript = await transcribe_audio(audio_base64, source_language)
    translated_query = await translate_to_english(transcript, source_language)

    # If the caller already has an English response (from the LLM / agents),
    # translate it back and synthesize; otherwise use a placeholder.
    en_response = response_text_en or "Advisory: Conditions are currently safe for fishing."
    response_localized = await translate_from_english(en_response, source_language)
    audio_b64 = await synthesize_speech(response_localized, source_language)

    return {
        "transcript": transcript,
        "translated_query": translated_query,
        "response_localized": response_localized,
        "audio_base64": audio_b64,
    }
