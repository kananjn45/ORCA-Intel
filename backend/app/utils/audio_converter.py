"""
ORCA — WAV / PCM Audio Format Converter Utility.

Pure-Python audio conversion utility that makes incoming audio data
compatible with the ORCA voice pipeline and Bhashini ASR.

Target format (configurable via ``app.core.config.Settings``):
    * Container : WAV (RIFF)
    * Encoding  : Linear PCM
    * Bit depth : 16-bit (2 bytes per sample)
    * Channels  : 1 (mono)
    * Rate      : 16 000 Hz

No FFmpeg or heavy native dependencies are required.

Limitations:
    * Only WAV and raw PCM input are supported natively.
    * MP3, OGG, FLAC input would require additional libraries
      (not added in Day 1 to keep the dependency surface minimal).
    * The converter validates WAV RIFF headers and rejects
      malformed data with :class:`AudioValidationError`.
"""

from __future__ import annotations

import io
import struct
from dataclasses import dataclass
from typing import Optional

from app.core.config import Settings, get_settings
from app.core.exceptions import AudioValidationError
from app.core.logging import get_logger

logger = get_logger("orca.audio_converter")

# ---------------------------------------------------------------------------
# WAV constants
# ---------------------------------------------------------------------------

_RIFF_HEADER_SIZE = 44
_RIFF_MAGIC = b"RIFF"
_WAVE_MAGIC = b"WAVE"
_FMT_MAGIC = b"fmt "
_DATA_MAGIC = b"data"
_PCM_FORMAT = 1


@dataclass(frozen=True)
class AudioParams:
    """Immutable descriptor for audio sample parameters."""
    sample_rate: int    # e.g. 16000
    channels: int       # e.g. 1
    sample_width: int   # bytes per sample, e.g. 2 for 16-bit


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


def convert_to_wav(
    audio_data: bytes,
    source_format: str = "wav",
    *,
    target_sample_rate: int | None = None,
    target_channels: int | None = None,
    target_sample_width: int | None = None,
    settings: Settings | None = None,
) -> bytes:
    """Convert audio bytes to a streaming-compatible WAV buffer.

    If *audio_data* is already valid WAV with the desired parameters the
    function returns a potentially re-wrapped copy without resampling
    (resampling requires ``scipy`` or ``librosa`` — not included in Day 1).

    Args:
        audio_data: Input audio bytes.
        source_format: One of ``"wav"`` or ``"pcm"``.
        target_sample_rate: Desired sample rate.  Defaults to settings.
        target_channels: Desired channel count. Defaults to settings.
        target_sample_width: Desired bytes-per-sample.  Defaults to settings.
        settings: Optional settings override.

    Returns:
        A complete WAV byte buffer ready for ASR / streaming.

    Raises:
        AudioValidationError: On empty, malformed, or unsupported input.
    """
    cfg = settings or get_settings()
    rate = target_sample_rate or cfg.audio_sample_rate
    channels = target_channels or cfg.audio_channels
    width = target_sample_width or cfg.audio_sample_width

    target = AudioParams(sample_rate=rate, channels=channels, sample_width=width)

    if not audio_data:
        raise AudioValidationError("Audio data is empty")

    fmt = source_format.strip().lower()

    if fmt == "wav":
        return _convert_wav(audio_data, target)
    elif fmt == "pcm":
        return _wrap_pcm_as_wav(audio_data, target)
    else:
        raise AudioValidationError(
            f"Unsupported source format '{fmt}'. "
            "Only 'wav' and 'pcm' are supported natively. "
            "For mp3/ogg/flac, convert to WAV externally before uploading."
        )


def extract_pcm_from_wav(wav_data: bytes) -> tuple[bytes, AudioParams]:
    """Strip the WAV header and return raw PCM samples + parameters.

    Args:
        wav_data: Complete WAV byte buffer.

    Returns:
        A tuple ``(pcm_bytes, AudioParams)``.

    Raises:
        AudioValidationError: If the WAV header is malformed.
    """
    if len(wav_data) < _RIFF_HEADER_SIZE:
        raise AudioValidationError(
            f"WAV data too small ({len(wav_data)} bytes)"
        )

    params, data_offset, data_size = _parse_wav_header(wav_data)
    pcm = wav_data[data_offset : data_offset + data_size]
    return pcm, params


def validate_wav(audio_data: bytes) -> AudioParams:
    """Validate that *audio_data* is a well-formed WAV file.

    Returns:
        Parsed :class:`AudioParams`.

    Raises:
        AudioValidationError: On any structural issue.
    """
    if len(audio_data) < _RIFF_HEADER_SIZE:
        raise AudioValidationError(
            f"WAV data too small ({len(audio_data)} bytes); "
            f"minimum header size is {_RIFF_HEADER_SIZE}"
        )
    params, _, _ = _parse_wav_header(audio_data)
    return params


def generate_silence_wav(
    duration_seconds: float = 0.1,
    *,
    sample_rate: int | None = None,
    channels: int | None = None,
    sample_width: int | None = None,
    settings: Settings | None = None,
) -> bytes:
    """Generate a silent WAV buffer of the given duration.

    Useful for test fixtures and TTS mock responses.

    Args:
        duration_seconds: Length of silence in seconds.
        sample_rate: Override sample rate.
        channels: Override channels.
        sample_width: Override sample width.
        settings: Optional settings override.

    Returns:
        A complete WAV byte buffer containing silence.
    """
    cfg = settings or get_settings()
    rate = sample_rate or cfg.audio_sample_rate
    ch = channels or cfg.audio_channels
    sw = sample_width or cfg.audio_sample_width

    num_samples = int(rate * duration_seconds)
    pcm = b"\x00" * (num_samples * ch * sw)
    return _wrap_pcm_as_wav(pcm, AudioParams(rate, ch, sw))


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _parse_wav_header(data: bytes) -> tuple[AudioParams, int, int]:
    """Parse the RIFF/WAV header and locate the ``data`` chunk.

    Returns:
        ``(AudioParams, data_offset, data_size)``

    Raises:
        AudioValidationError: On any parsing failure.
    """
    # Validate RIFF container
    if data[:4] != _RIFF_MAGIC:
        raise AudioValidationError(
            "Not a valid WAV file: missing RIFF header"
        )
    if data[8:12] != _WAVE_MAGIC:
        raise AudioValidationError(
            "Not a valid WAV file: missing WAVE identifier"
        )

    # Walk sub-chunks
    offset = 12
    fmt_found = False
    audio_format = 0
    channels = 0
    sample_rate = 0
    sample_width = 0

    while offset < len(data) - 8:
        chunk_id = data[offset : offset + 4]
        chunk_size = struct.unpack_from("<I", data, offset + 4)[0]

        if chunk_id == _FMT_MAGIC:
            if chunk_size < 16:
                raise AudioValidationError("WAV fmt chunk too small")
            audio_format = struct.unpack_from("<H", data, offset + 8)[0]
            channels = struct.unpack_from("<H", data, offset + 10)[0]
            sample_rate = struct.unpack_from("<I", data, offset + 12)[0]
            bits_per_sample = struct.unpack_from("<H", data, offset + 22)[0]
            sample_width = bits_per_sample // 8
            fmt_found = True

        if chunk_id == _DATA_MAGIC:
            if not fmt_found:
                raise AudioValidationError("WAV data chunk before fmt chunk")
            if audio_format != _PCM_FORMAT:
                raise AudioValidationError(
                    f"Unsupported WAV encoding (format={audio_format}); "
                    "only PCM (1) is supported"
                )
            return (
                AudioParams(sample_rate, channels, sample_width),
                offset + 8,
                chunk_size,
            )

        # Advance to next chunk (size is padded to even boundary)
        offset += 8 + chunk_size
        if chunk_size % 2 != 0:
            offset += 1

    raise AudioValidationError("WAV file missing data chunk")


def _convert_wav(wav_data: bytes, target: AudioParams) -> bytes:
    """Validate an existing WAV and re-wrap if parameters differ.

    NOTE: Real sample-rate conversion is not performed in this
    pure-Python implementation.  If the source rate differs from the
    target, the PCM data is re-wrapped with the *target* rate declared
    in the header.  This is acceptable for the Day 1 pipeline because
    the mobile client already records at 16 kHz mono 16-bit.
    """
    source, data_offset, data_size = _parse_wav_header(wav_data)

    # If source already matches target, return as-is
    if (
        source.sample_rate == target.sample_rate
        and source.channels == target.channels
        and source.sample_width == target.sample_width
    ):
        logger.debug("WAV already matches target params; returning as-is")
        return wav_data

    logger.info(
        "Re-wrapping WAV: %s → %s (no resampling)",
        source,
        target,
    )

    # Extract raw PCM and re-wrap with target header
    pcm_bytes = wav_data[data_offset : data_offset + data_size]
    return _wrap_pcm_as_wav(pcm_bytes, target)


def _wrap_pcm_as_wav(pcm_data: bytes, params: AudioParams) -> bytes:
    """Wrap raw PCM samples in a standard WAV (RIFF) header."""
    data_size = len(pcm_data)
    byte_rate = params.sample_rate * params.channels * params.sample_width
    block_align = params.channels * params.sample_width
    bits_per_sample = params.sample_width * 8

    buf = io.BytesIO()
    # RIFF header
    buf.write(_RIFF_MAGIC)
    buf.write(struct.pack("<I", 36 + data_size))
    buf.write(_WAVE_MAGIC)

    # fmt sub-chunk
    buf.write(_FMT_MAGIC)
    buf.write(struct.pack("<I", 16))            # sub-chunk size
    buf.write(struct.pack("<H", _PCM_FORMAT))   # audio format
    buf.write(struct.pack("<H", params.channels))
    buf.write(struct.pack("<I", params.sample_rate))
    buf.write(struct.pack("<I", byte_rate))
    buf.write(struct.pack("<H", block_align))
    buf.write(struct.pack("<H", bits_per_sample))

    # data sub-chunk
    buf.write(_DATA_MAGIC)
    buf.write(struct.pack("<I", data_size))
    buf.write(pcm_data)

    return buf.getvalue()


def _find_data_offset(wav_data: bytes) -> int:
    """Locate the byte offset of the PCM data within a WAV buffer."""
    offset = 12
    while offset < len(wav_data) - 8:
        chunk_id = wav_data[offset : offset + 4]
        chunk_size = struct.unpack_from("<I", wav_data, offset + 4)[0]
        if chunk_id == _DATA_MAGIC:
            return offset + 8
        offset += 8 + chunk_size
        if chunk_size % 2 != 0:
            offset += 1
    raise AudioValidationError("WAV data chunk not found")


def _find_data_size(wav_data: bytes) -> int:
    """Return the declared size of the data chunk."""
    offset = 12
    while offset < len(wav_data) - 8:
        chunk_id = wav_data[offset : offset + 4]
        chunk_size = struct.unpack_from("<I", wav_data, offset + 4)[0]
        if chunk_id == _DATA_MAGIC:
            return chunk_size
        offset += 8 + chunk_size
        if chunk_size % 2 != 0:
            offset += 1
    raise AudioValidationError("WAV data chunk not found")
