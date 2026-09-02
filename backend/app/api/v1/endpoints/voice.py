"""
app/api/v1/endpoints/voice.py
Owner (per docs/IMPLEMENTATION_PLAN.md): Dev 4 (Voice & Multilingual Specialist)
  -> real Bhashini ASR/TTS logic lives in app/services/bhashini.py

Day 1 (Dev 3 scaffold): Routes are live and call the bhashini mock service.
Day 8 (Dev 4): Replace BHASHINI_USE_MOCK=true with real API credentials.

Endpoints:
  POST /api/v1/voice/transcribe    -> ASR: audio -> text
  POST /api/v1/voice/synthesize    -> TTS: text -> audio
  POST /api/v1/voice/translate     -> NMT: regional text -> English
"""
import base64
from typing import Optional

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field

from app.core.logging import get_logger
from app.services import bhashini

logger = get_logger(__name__)
router = APIRouter()


# ---- Request / Response schemas (voice-specific, not in main schemas.py) ----

class TranscribeRequest(BaseModel):
    audio_base64: str = Field(..., description="Base64-encoded audio bytes (WAV/PCM)")
    source_language: str = Field(default="ta", description="BCP-47 code: ta, te, hi, bn, gu, en")


class TranscribeResponse(BaseModel):
    transcript: str
    source_language: str
    source: str = "bhashini-mock"


class SynthesizeRequest(BaseModel):
    text: str = Field(..., description="Text to synthesize into speech")
    target_language: str = Field(default="ta", description="BCP-47 code")
    gender: str = Field(default="female", description="Voice gender: male / female")


class SynthesizeResponse(BaseModel):
    audio_base64: str
    target_language: str
    source: str = "bhashini-mock"


class TranslateRequest(BaseModel):
    text: str = Field(..., description="Text to translate")
    source_language: str = Field(default="ta")
    target_language: str = Field(default="en")


class TranslateResponse(BaseModel):
    translated_text: str
    source_language: str
    target_language: str
    source: str = "bhashini-mock"


# ---- Endpoints ----

@router.post(
    "/transcribe",
    response_model=TranscribeResponse,
    summary="Bhashini ASR — Convert spoken audio to text",
)
async def transcribe_audio(request: TranscribeRequest) -> TranscribeResponse:
    """
    Accepts base64-encoded audio and returns the transcribed text.
    Currently uses the deterministic mock (BHASHINI_USE_MOCK=true).
    Dev 4 flips the flag and fills in real Bhashini pipeline credentials.
    """
    allowed = bhashini.SUPPORTED_LANGUAGES
    if request.source_language not in allowed:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"source_language must be one of {sorted(allowed.keys())}",
        )
    try:
        transcript = await bhashini.transcribe_audio(
            request.audio_base64, request.source_language
        )
    except bhashini.BhashiniServiceError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc

    return TranscribeResponse(
        transcript=transcript,
        source_language=request.source_language,
        source="bhashini-live" if not bhashini.settings.BHASHINI_USE_MOCK else "bhashini-mock",
    )


@router.post(
    "/synthesize",
    response_model=SynthesizeResponse,
    summary="Bhashini TTS — Convert text to spoken audio",
)
async def synthesize_audio(request: SynthesizeRequest) -> SynthesizeResponse:
    """
    Accepts plain text and returns base64-encoded audio (WAV in real impl).
    """
    allowed = bhashini.SUPPORTED_LANGUAGES
    if request.target_language not in allowed:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"target_language must be one of {sorted(allowed.keys())}",
        )
    try:
        audio_b64 = await bhashini.synthesize_speech(
            request.text, request.target_language, request.gender
        )
    except bhashini.BhashiniServiceError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc

    return SynthesizeResponse(
        audio_base64=audio_b64,
        target_language=request.target_language,
        source="bhashini-live" if not bhashini.settings.BHASHINI_USE_MOCK else "bhashini-mock",
    )


@router.post(
    "/translate",
    response_model=TranslateResponse,
    summary="Bhashini NMT — Translate between regional language and English",
)
async def translate_text(request: TranslateRequest) -> TranslateResponse:
    """
    Translates text either TO English (for LLM reasoning) or FROM English
    (for localised response delivery to the fisherman).
    """
    allowed = bhashini.SUPPORTED_LANGUAGES
    for lang in (request.source_language, request.target_language):
        if lang not in allowed:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Language '{lang}' not supported. Choose from {sorted(allowed.keys())}",
            )
    try:
        if request.target_language == "en":
            translated = await bhashini.translate_to_english(request.text, request.source_language)
        else:
            translated = await bhashini.translate_from_english(request.text, request.target_language)
    except bhashini.BhashiniServiceError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc

    return TranslateResponse(
        translated_text=translated,
        source_language=request.source_language,
        target_language=request.target_language,
        source="bhashini-live" if not bhashini.settings.BHASHINI_USE_MOCK else "bhashini-mock",
    )