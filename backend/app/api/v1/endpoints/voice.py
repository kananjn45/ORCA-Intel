"""
ORCA — Voice Pipeline API Endpoints (Day 1 + Day 2).

FastAPI router exposing:

* POST /voice/transcribe               — ASR speech-to-text
* POST /voice/synthesise & /synthesize — TTS text-to-speech
* GET  /voice/languages                — Supported languages
* POST /voice/translate                — NMT text translation
* POST /voice/tts                      — TTS with audio caching
* POST /voice/pipeline/asr-translate   — ASR → NMT combined
* POST /voice/pipeline/translate-tts   — NMT → TTS combined
* GET  /voice/cache/stats              — TTS cache statistics
* POST /voice/cache/clear              — Clear TTS cache
"""

from __future__ import annotations

import base64
from typing import Optional

from fastapi import APIRouter, File, Form, HTTPException, Request, UploadFile
from pydantic import BaseModel, Field

from app.core.config import get_settings
from app.core.exceptions import (
    AudioValidationError,
    BhashiniError,
    UnsupportedLanguageError,
)
from app.core.logging import get_logger
from app.models.schemas import (
    ASRResult,
    LANGUAGE_NAMES,
    NMTResult,
    ResponsePipelineResult,
    TTSResult,
    VoicePipelineResult,
)
from app.services.bhashini import BhashiniService
from app.services.tts_cache import TTSAudioCache
from app.utils.audio_converter import convert_to_wav

logger = get_logger("orca.api.voice")

router = APIRouter(tags=["Voice Pipeline"])

# Shared service instances (lazy singletons)
_bhashini_service: Optional[BhashiniService] = None
_tts_cache: Optional[TTSAudioCache] = None


def _get_service() -> BhashiniService:
    global _bhashini_service
    if _bhashini_service is None:
        _bhashini_service = BhashiniService()
    return _bhashini_service


def _get_cache() -> TTSAudioCache:
    global _tts_cache
    if _tts_cache is None:
        cfg = get_settings()
        _tts_cache = TTSAudioCache(
            ttl_seconds=cfg.tts_cache_ttl_seconds,
            max_entries=cfg.tts_cache_max_entries,
        )
    return _tts_cache


class TranscribeJsonRequest(BaseModel):
    audio_base64: str = Field(..., description="Base64-encoded audio bytes")
    language: str = Field(default="ta", description="ISO 639-1 language code")
    audio_format: str = Field(default="wav", description="Audio format")


@router.post(
    "/transcribe",
    response_model=ASRResult,
    summary="Transcribe speech audio to text",
    description="Accepts a WAV/PCM audio file and language code; returns recognised transcript.",
)
async def transcribe(
    audio: Optional[UploadFile] = File(None, description="Audio file (WAV preferred)"),
    language: str = Form("ta", description="ISO 639-1 language code"),
    audio_format: str = Form("wav", description="Audio format hint"),
) -> ASRResult:
    """Transcribe uploaded audio file."""
    if audio is None:
        raise HTTPException(status_code=400, detail="Audio file is required")
    try:
        raw_bytes = await audio.read()
        wav_bytes = convert_to_wav(raw_bytes, source_format=audio_format)
        service = _get_service()
        return await service.transcribe_audio(
            audio_data=wav_bytes,
            language_code=language,
            audio_format="wav",
        )
    except AudioValidationError as exc:
        logger.warning("Audio validation failed: %s", exc.message)
        raise HTTPException(status_code=400, detail=exc.message)
    except UnsupportedLanguageError as exc:
        logger.warning("Unsupported language: %s", exc.language)
        raise HTTPException(status_code=400, detail=exc.message)
    except BhashiniError as exc:
        logger.error("Bhashini service error: %s", exc.message)
        raise HTTPException(status_code=502, detail="Voice service temporarily unavailable")


@router.post(
    "/transcribe-json",
    response_model=ASRResult,
    summary="Transcribe speech audio from JSON base64",
)
async def transcribe_json(body: TranscribeJsonRequest) -> ASRResult:
    """Transcribe base64 audio payload."""
    try:
        raw_bytes = base64.b64decode(body.audio_base64)
        wav_bytes = convert_to_wav(raw_bytes, source_format=body.audio_format)
        service = _get_service()
        return await service.transcribe_audio(
            audio_data=wav_bytes,
            language_code=body.language,
            audio_format="wav",
        )
    except AudioValidationError as exc:
        raise HTTPException(status_code=400, detail=exc.message)
    except UnsupportedLanguageError as exc:
        raise HTTPException(status_code=400, detail=exc.message)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.post(
    "/synthesise",
    response_model=TTSResult,
    summary="Synthesise text to speech audio",
    description="Generates spoken audio from text in the specified language.",
)
async def synthesise(
    text: str = Form(..., description="Text to speak"),
    language: str = Form("ta", description="ISO 639-1 language code"),
    gender: str = Form("female", description="Voice gender"),
) -> TTSResult:
    """Synthesise speech from form data."""
    try:
        service = _get_service()
        return await service.synthesise_speech(
            text=text,
            language_code=language,
            gender=gender,
        )
    except AudioValidationError as exc:
        raise HTTPException(status_code=400, detail=exc.message)
    except UnsupportedLanguageError as exc:
        raise HTTPException(status_code=400, detail=exc.message)
    except BhashiniError as exc:
        logger.error("TTS error: %s", exc.message)
        raise HTTPException(status_code=502, detail="Voice service temporarily unavailable")


@router.post(
    "/synthesize",
    response_model=TTSResult,
    summary="Synthesize text to speech audio (JSON / Form compatible alias)",
)
async def synthesize(
    request: Request,
) -> TTSResult:
    """Synthesise speech from either JSON body or Form data."""
    content_type = request.headers.get("content-type", "")
    text: str = ""
    language: str = "ta"
    gender: str = "female"

    if "application/json" in content_type:
        data = await request.json()
        text = data.get("text", "")
        language = data.get("language") or data.get("target_language", "ta")
        gender = data.get("gender", "female")
    else:
        form = await request.form()
        text = str(form.get("text", ""))
        language = str(form.get("language") or form.get("target_language") or "ta")
        gender = str(form.get("gender", "female"))

    if not text:
        raise HTTPException(status_code=400, detail="Field 'text' is required")

    try:
        service = _get_service()
        return await service.synthesise_speech(
            text=text,
            language_code=language,
            gender=gender,
        )
    except AudioValidationError as exc:
        raise HTTPException(status_code=400, detail=exc.message)
    except UnsupportedLanguageError as exc:
        raise HTTPException(status_code=400, detail=exc.message)
    except BhashiniError as exc:
        logger.error("TTS error: %s", exc.message)
        raise HTTPException(status_code=502, detail="Voice service temporarily unavailable")


@router.get(
    "/languages",
    summary="List supported languages",
    description="Returns the languages supported by the voice pipeline.",
)
async def list_languages() -> dict:
    """Return all supported language codes and display names."""
    return {"languages": LANGUAGE_NAMES}


class TranslateRequest(BaseModel):
    """JSON body for the /voice/translate endpoint."""
    text: str = Field(..., description="Text to translate.")
    source_language: str = Field(..., description="Source language code.")
    target_language: str = Field(..., description="Target language code.")


@router.post(
    "/translate",
    response_model=NMTResult,
    summary="Translate text between languages",
)
async def translate(body: TranslateRequest) -> NMTResult:
    """Translate text via Bhashini NMT."""
    try:
        service = _get_service()
        return await service.translate_text(
            text=body.text,
            source_language=body.source_language,
            target_language=body.target_language,
        )
    except AudioValidationError as exc:
        raise HTTPException(status_code=400, detail=exc.message)
    except UnsupportedLanguageError as exc:
        raise HTTPException(status_code=400, detail=exc.message)
    except BhashiniError as exc:
        logger.error("NMT error: %s", exc.message)
        raise HTTPException(status_code=502, detail="Translation service temporarily unavailable")


class TTSCachedRequest(BaseModel):
    """JSON body for the /voice/tts endpoint with caching."""
    text: str = Field(..., description="Text to synthesise.")
    language: str = Field(..., description="Language code.")
    gender: str = Field(default="female", description="Voice gender.")


@router.post(
    "/tts",
    response_model=TTSResult,
    summary="Text-to-speech with audio caching",
)
async def tts_cached(body: TTSCachedRequest) -> TTSResult:
    """TTS with automatic audio caching for repeated safety advisories."""
    try:
        cache = _get_cache()
        cached = cache.get(body.text, body.language, body.gender)
        if cached is not None:
            logger.info("TTS cache hit for lang=%s", body.language)
            return cached

        service = _get_service()
        result = await service.synthesise_speech(
            text=body.text,
            language_code=body.language,
            gender=body.gender,
        )
        cache.put(body.text, body.language, body.gender, result)
        return result
    except AudioValidationError as exc:
        raise HTTPException(status_code=400, detail=exc.message)
    except UnsupportedLanguageError as exc:
        raise HTTPException(status_code=400, detail=exc.message)
    except BhashiniError as exc:
        logger.error("TTS error: %s", exc.message)
        raise HTTPException(status_code=502, detail="Voice service temporarily unavailable")


@router.post(
    "/pipeline/asr-translate",
    response_model=VoicePipelineResult,
    summary="Speech → Transcript → Translation (ASR + NMT)",
)
async def asr_translate_pipeline(
    audio: UploadFile = File(..., description="Audio file (WAV preferred)"),
    language: str = Form("ta", description="Source language code"),
    target_language: str = Form("en", description="Target language code"),
    audio_format: str = Form("wav", description="Audio format hint"),
) -> VoicePipelineResult:
    """Full ASR → NMT pipeline for incoming user speech."""
    try:
        raw_bytes = await audio.read()
        wav_bytes = convert_to_wav(raw_bytes, source_format=audio_format)
        service = _get_service()
        asr_result, nmt_result = await service.asr_then_translate(
            audio_data=wav_bytes,
            source_language=language,
            target_language=target_language,
            audio_format="wav",
        )
        return VoicePipelineResult(
            transcript=asr_result.text,
            translated_text=nmt_result.translated_text,
            source_language=nmt_result.source_language,
            target_language=nmt_result.target_language,
            is_mock=asr_result.is_mock or nmt_result.is_mock,
        )
    except AudioValidationError as exc:
        raise HTTPException(status_code=400, detail=exc.message)
    except UnsupportedLanguageError as exc:
        raise HTTPException(status_code=400, detail=exc.message)
    except BhashiniError as exc:
        logger.error("ASR-translate pipeline error: %s", exc.message)
        raise HTTPException(status_code=502, detail="Voice pipeline temporarily unavailable")


class TranslateTTSRequest(BaseModel):
    """JSON body for the NMT → TTS pipeline endpoint."""
    text: str = Field(..., description="Text to translate and speak.")
    source_language: str = Field(default="en", description="Source language code.")
    target_language: str = Field(..., description="Target language code for speech.")
    gender: str = Field(default="female", description="Voice gender.")


@router.post(
    "/pipeline/translate-tts",
    response_model=ResponsePipelineResult,
    summary="Translation → Speech (NMT + TTS)",
)
async def translate_tts_pipeline(body: TranslateTTSRequest) -> ResponsePipelineResult:
    """Full NMT → TTS pipeline for outgoing responses."""
    try:
        cache = _get_cache()
        service = _get_service()
        nmt_result, tts_result = await service.translate_then_tts(
            text=body.text,
            source_language=body.source_language,
            target_language=body.target_language,
            gender=body.gender,
        )
        cache.put(
            nmt_result.translated_text,
            body.target_language,
            body.gender,
            tts_result,
        )
        return ResponsePipelineResult(
            translated_text=nmt_result.translated_text,
            audio_content=tts_result.audio_content,
            source_language=body.source_language,
            target_language=body.target_language,
            audio_format=tts_result.audio_format,
            is_mock=nmt_result.is_mock or tts_result.is_mock,
        )
    except AudioValidationError as exc:
        raise HTTPException(status_code=400, detail=exc.message)
    except UnsupportedLanguageError as exc:
        raise HTTPException(status_code=400, detail=exc.message)
    except BhashiniError as exc:
        logger.error("Translate-TTS pipeline error: %s", exc.message)
        raise HTTPException(status_code=502, detail="Voice pipeline temporarily unavailable")


@router.get("/cache/stats", summary="TTS cache statistics")
async def cache_stats() -> dict:
    """Return TTS cache statistics."""
    cache = _get_cache()
    return cache.stats


@router.post("/cache/clear", summary="Clear TTS cache")
async def cache_clear() -> dict:
    """Clear the TTS audio cache."""
    cache = _get_cache()
    count = cache.size
    cache.clear()
    return {"cleared": count, "message": f"Cleared {count} cached TTS entries"}