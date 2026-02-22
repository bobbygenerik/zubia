"""
Text-to-Speech service using Piper TTS.
Generates natural-sounding speech audio from text, per language.
"""

import io
import wave
import logging
import subprocess
import json
from pathlib import Path
from typing import Optional

logger = logging.getLogger("voxbridge.tts")

# Directory for storing downloaded voice models
VOICES_DIR = Path(__file__).parent / "piper_voices"
VOICES_DIR.mkdir(exist_ok=True)

# Piper voice models per language (using medium quality for balance of speed/quality)
# Format: lang_code -> (model_name, download_url_base)
VOICE_MODELS = {
    "en": "en_US-lessac-medium",
    "es": "es_ES-sharvard-medium",
    "fr": "fr_FR-siwis-medium",
    "de": "de_DE-thorsten-medium",
    "zh": "zh_CN-huayan-medium",
    "ja": "ja_JP-takumi-medium",  # Note: may fall back
    "ar": "ar_JO-kareem-medium",
    "pt": "pt_PT-tugão-medium",
    "ru": "ru_RU-denis-medium",
    "ko": "ko_KR-kss-medium",  # Note: may fall back
}

PIPER_DOWNLOAD_BASE = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0"

# Cache for loaded voice synthesizers
_synthesizers: dict[str, object] = {}


def _get_voice_path(lang: str) -> tuple[Optional[Path], Optional[Path]]:
    """Get paths to .onnx and .onnx.json for a language's voice model."""
    model_name = VOICE_MODELS.get(lang)
    if not model_name:
        # Fall back to English
        model_name = VOICE_MODELS["en"]

    # Parse model name: lang_REGION-name-quality
    parts = model_name.split("-")
    lang_region = parts[0]  # e.g., en_US
    name = parts[1]          # e.g., lessac
    quality = parts[2]       # e.g., medium

    lang_short = lang_region[:2]  # e.g., en

    onnx_path = VOICES_DIR / f"{model_name}.onnx"
    json_path = VOICES_DIR / f"{model_name}.onnx.json"

    return onnx_path, json_path, model_name, lang_short, lang_region, name, quality


def _download_voice(lang: str) -> tuple[Path, Path]:
    """Download the Piper voice model for a language if not already present."""
    onnx_path, json_path, model_name, lang_short, lang_region, name, quality = _get_voice_path(lang)

    if onnx_path.exists() and json_path.exists():
        logger.info(f"Voice model for '{lang}' already downloaded: {model_name}")
        return onnx_path, json_path

    # Construct download URLs
    # URL pattern: {base}/{lang_short}/{lang_REGION}/{name}/{quality}/{model_name}.onnx
    url_base = f"{PIPER_DOWNLOAD_BASE}/{lang_short}/{lang_region}/{name}/{quality}"
    onnx_url = f"{url_base}/{model_name}.onnx"
    json_url = f"{url_base}/{model_name}.onnx.json"

    logger.info(f"Downloading Piper voice model: {model_name}...")

    try:
        # Download ONNX model
        subprocess.run(
            ["wget", "-q", "-O", str(onnx_path), onnx_url],
            check=True, timeout=120
        )
        # Download config JSON
        subprocess.run(
            ["wget", "-q", "-O", str(json_path), json_url],
            check=True, timeout=30
        )
        logger.info(f"Voice model '{model_name}' downloaded successfully.")
    except subprocess.CalledProcessError as e:
        logger.error(f"Failed to download voice model '{model_name}': {e}")
        # Clean up partial downloads
        onnx_path.unlink(missing_ok=True)
        json_path.unlink(missing_ok=True)
        # Fall back to English if not already trying English
        if lang != "en":
            logger.info("Falling back to English voice model.")
            return _download_voice("en")
        raise

    return onnx_path, json_path


def synthesize(text: str, lang: str, speed: float = 1.0) -> bytes:
    """
    Synthesize speech from text using Piper TTS.

    Args:
        text: The text to convert to speech
        lang: Target language code (e.g., 'en', 'es')
        speed: Speech speed multiplier (1.0 = normal)

    Returns:
        WAV audio bytes
    """
    if not text or not text.strip():
        return _generate_silence(0.5)

    try:
        onnx_path, json_path = _download_voice(lang)
    except Exception as e:
        logger.error(f"Could not get voice model for '{lang}': {e}")
        return _generate_silence(0.5)

    try:
        # Use piper-tts via its Python API
        from piper import PiperVoice

        # Cache the synthesizer
        cache_key = str(onnx_path)
        if cache_key not in _synthesizers:
            logger.info(f"Loading Piper voice: {onnx_path.name}")
            _synthesizers[cache_key] = PiperVoice.load(str(onnx_path), str(json_path))

        voice = _synthesizers[cache_key]

        # Synthesize to WAV in memory
        wav_buffer = io.BytesIO()
        with wave.open(wav_buffer, "wb") as wav_file:
            wav_file.setnchannels(1)
            wav_file.setsampwidth(2)
            wav_file.setframerate(voice.config.sample_rate)
            voice.synthesize(text, wav_file, length_scale=1.0 / speed)

        wav_bytes = wav_buffer.getvalue()
        logger.debug(f"Synthesized {len(wav_bytes)} bytes for lang={lang}: '{text[:50]}...'")
        return wav_bytes

    except Exception as e:
        logger.error(f"TTS synthesis failed: {e}")
        return _generate_silence(0.5)


def _generate_silence(duration_seconds: float, sample_rate: int = 22050) -> bytes:
    """Generate silent WAV audio of the specified duration."""
    import numpy as np
    n_samples = int(duration_seconds * sample_rate)
    silence = np.zeros(n_samples, dtype=np.int16)

    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(silence.tobytes())

    return buf.getvalue()


def preload_voices(languages: list[str] | None = None):
    """Pre-download voice models for specified languages."""
    if languages is None:
        languages = ["en", "es"]  # Default to just English and Spanish

    for lang in languages:
        try:
            _download_voice(lang)
        except Exception as e:
            logger.warning(f"Failed to preload voice for '{lang}': {e}")
