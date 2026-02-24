"""
Speech-to-Text service using faster-whisper.
Converts audio bytes (WAV/PCM) to transcribed text with language detection.
"""

import io
import wave
import logging
import numpy as np
from faster_whisper import WhisperModel

logger = logging.getLogger("voxbridge.stt")

# Singleton model instance
_model: WhisperModel | None = None


def get_model() -> WhisperModel:
    """Lazy-load the Whisper model (small, int8 quantized for CPU speed)."""
    global _model
    if _model is None:
        logger.info("Loading faster-whisper 'small' model (int8, CPU)...")
        _model = WhisperModel(
            "small",
            device="cpu",
            compute_type="int8",
            cpu_threads=4,
        )
        logger.info("Whisper model loaded successfully.")
    return _model


def wav_bytes_to_float32(wav_bytes: bytes) -> tuple[np.ndarray, int]:
    """Convert WAV bytes to float32 numpy array and sample rate."""
    with io.BytesIO(wav_bytes) as buf:
        with wave.open(buf, "rb") as wf:
            sample_rate = wf.getframerate()
            n_channels = wf.getnchannels()
            sampwidth = wf.getsampwidth()
            n_frames = wf.getnframes()
            raw = wf.readframes(n_frames)

    # Convert to numpy based on sample width
    sample_width_map = {2: np.int16, 4: np.int32}

    if sampwidth not in sample_width_map:
        raise ValueError(f"Unsupported sample width: {sampwidth}")

    dtype = sample_width_map[sampwidth]
    # Calculate normalization factor based on type range
    # e.g. for int16, min is -32768, so we divide by 32768.0
    max_val = float(abs(np.iinfo(dtype).min))
    audio = np.frombuffer(raw, dtype=dtype).astype(np.float32) / max_val

    # Convert stereo to mono by averaging channels
    if n_channels == 2:
        audio = audio.reshape(-1, 2).mean(axis=1)

    return audio, sample_rate


def transcribe(wav_bytes: bytes, source_lang: str | None = None) -> dict:
    """
    Transcribe WAV audio bytes to text.

    Args:
        wav_bytes: Raw WAV file bytes
        source_lang: Optional ISO language code (e.g., 'en', 'es').
                     If None, language is auto-detected.

    Returns:
        dict with keys:
            - text: transcribed text
            - language: detected/specified language code
            - confidence: language detection probability
    """
    model = get_model()
    audio, sample_rate = wav_bytes_to_float32(wav_bytes)

    # Skip very short or silent audio
    if len(audio) < sample_rate * 0.3:  # Less than 0.3 seconds
        return {"text": "", "language": source_lang or "en", "confidence": 0.0}

    # Check for silence (RMS below threshold)
    rms = np.sqrt(np.mean(audio ** 2))
    if rms < 0.005:
        return {"text": "", "language": source_lang or "en", "confidence": 0.0}

    # Resample to 16kHz if needed (Whisper expects 16kHz)
    if sample_rate != 16000:
        # Simple resampling by interpolation
        duration = len(audio) / sample_rate
        target_len = int(duration * 16000)
        indices = np.linspace(0, len(audio) - 1, target_len)
        audio = np.interp(indices, np.arange(len(audio)), audio)

    try:
        segments, info = model.transcribe(
            audio,
            language=source_lang,
            beam_size=3,
            best_of=2,
            vad_filter=True,
            vad_parameters=dict(
                min_silence_duration_ms=300,
                speech_pad_ms=200,
            ),
        )

        text = " ".join(seg.text.strip() for seg in segments).strip()

        return {
            "text": text,
            "language": info.language,
            "confidence": info.language_probability,
        }
    except Exception as e:
        logger.error(f"Transcription failed: {e}")
        return {"text": "", "language": source_lang or "en", "confidence": 0.0}
