import io
import wave
import sys
import os
import pytest
import numpy as np

# Add server directory to sys.path
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))

from stt_service import wav_bytes_to_float32

def create_wav_bytes(channels=1, sampwidth=2, framerate=16000, data=b''):
    """Helper to create WAV bytes in memory."""
    buf = io.BytesIO()
    with wave.open(buf, 'wb') as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(sampwidth)
        wf.setframerate(framerate)
        wf.writeframes(data)
    return buf.getvalue()

def test_wav_bytes_to_float32_16bit_mono():
    # 16-bit mono silence (0)
    data = b'\x00\x00' * 10
    wav_bytes = create_wav_bytes(channels=1, sampwidth=2, data=data)

    audio, sample_rate = wav_bytes_to_float32(wav_bytes)

    assert sample_rate == 16000
    assert audio.shape == (10,)
    assert audio.dtype == np.float32
    np.testing.assert_allclose(audio, 0.0, atol=1e-7)

def test_wav_bytes_to_float32_16bit_stereo():
    # 16-bit stereo. Left: 10000, Right: 20000 -> Average 15000
    val1 = 10000
    val2 = 20000
    # Create 2 samples (4 bytes per sample frame: 2 bytes left + 2 bytes right)

    frame = val1.to_bytes(2, 'little', signed=True) + val2.to_bytes(2, 'little', signed=True)
    data = frame * 2

    wav_bytes = create_wav_bytes(channels=2, sampwidth=2, data=data)

    audio, sample_rate = wav_bytes_to_float32(wav_bytes)

    assert sample_rate == 16000
    assert audio.shape == (2,) # 2 frames, converted to mono

    expected_val = (val1 + val2) / 2 / 32768.0
    np.testing.assert_allclose(audio, expected_val, atol=1e-5)

def test_wav_bytes_to_float32_32bit_mono():
    # 32-bit mono
    # Max int32: 2147483647
    val = 2147483647
    data = val.to_bytes(4, 'little', signed=True)

    wav_bytes = create_wav_bytes(channels=1, sampwidth=4, data=data)

    audio, sample_rate = wav_bytes_to_float32(wav_bytes)

    assert sample_rate == 16000
    assert audio.shape == (1,)
    expected = val / 2147483648.0
    np.testing.assert_allclose(audio, expected, atol=1e-7)

def test_wav_bytes_to_float32_empty():
    wav_bytes = create_wav_bytes(data=b'')
    audio, sample_rate = wav_bytes_to_float32(wav_bytes)
    assert len(audio) == 0
    assert sample_rate == 16000

def test_wav_bytes_to_float32_unsupported_width():
    # 8-bit (1 byte)
    wav_bytes = create_wav_bytes(sampwidth=1, data=b'\x00')
    with pytest.raises(ValueError, match="Unsupported sample width: 1"):
        wav_bytes_to_float32(wav_bytes)

def test_wav_bytes_to_float32_invalid_wav():
    # Just random bytes
    with pytest.raises(wave.Error):
        wav_bytes_to_float32(b'not a wav file')

def test_wav_bytes_to_float32_malformed_wav():
    # Incomplete header but starts with RIFF
    with pytest.raises(wave.Error):
        wav_bytes_to_float32(b'RIFF....WAVEfmt ')
