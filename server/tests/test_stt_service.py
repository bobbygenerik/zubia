import sys
from unittest.mock import MagicMock, patch
import numpy as np
import pytest

# Mock faster_whisper to avoid loading the model
# We must mock it before importing stt_service
sys.modules["faster_whisper"] = MagicMock()

# We also need to ensure stt_service can be imported even if it doesn't have scipy yet?
# No, we assume stt_service will have scipy.
# But for now, stt_service.py uses np.interp.

from server.stt_service import transcribe, wav_bytes_to_float32

def test_wav_bytes_to_float32():
    # Create a dummy WAV file in memory
    import io
    import wave

    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(44100)
        # Generate 1 second of silence
        data = np.zeros(44100, dtype=np.int16)
        wf.writeframes(data.tobytes())

    wav_bytes = buf.getvalue()
    audio, sr = wav_bytes_to_float32(wav_bytes)

    assert sr == 44100
    assert len(audio) == 44100
    assert audio.dtype == np.float32

# This test expects the new implementation using scipy.signal.resample_poly
# It will fail on the current implementation.
@patch("server.stt_service.get_model")
def test_transcribe_resampling_logic(mock_get_model):
    # Setup mock model
    mock_model_instance = MagicMock()
    mock_get_model.return_value = mock_model_instance
    mock_model_instance.transcribe.return_value = ([], MagicMock(language="en", language_probability=1.0))

    # Create dummy WAV at 44.1kHz
    import io
    import wave

    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(44100)
        # 1 second of random noise
        data = (np.random.randn(44100) * 1000).astype(np.int16)
        wf.writeframes(data.tobytes())

    wav_bytes = buf.getvalue()

    # We want to verify that resample_poly is used.
    # Since we haven't modified the code yet, we can't easily patch 'server.stt_service.scipy' if it's not imported.
    # So we will patch scipy.signal where it is defined.

    with patch("scipy.signal.resample_poly") as mock_resample:
        # Mock return value
        mock_resample.return_value = np.zeros(16000, dtype=np.float32)

        try:
            transcribe(wav_bytes)
        except NameError:
            # Code hasn't been updated yet
            pytest.fail("scipy not imported or used in stt_service")
        except Exception:
            # Other errors
            pass

        # Verify resample_poly was called
        assert mock_resample.called, "scipy.signal.resample_poly was not called"

        args, _ = mock_resample.call_args
        audio_arg = args[0]
        up_arg = args[1]
        down_arg = args[2]

        assert len(audio_arg) == 44100
        # 16000 / 44100 = 160 / 441
        assert up_arg == 160
        assert down_arg == 441

@patch("server.stt_service.get_model")
def test_transcribe_no_resampling_needed(mock_get_model):
    mock_model_instance = MagicMock()
    mock_get_model.return_value = mock_model_instance
    mock_model_instance.transcribe.return_value = ([], MagicMock(language="en", language_probability=1.0))

    # Create dummy WAV at 16kHz
    import io
    import wave

    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(16000)
        data = np.zeros(16000, dtype=np.int16)
        wf.writeframes(data.tobytes())

    wav_bytes = buf.getvalue()

    # Even with the fix, resample_poly should NOT be called
    with patch("scipy.signal.resample_poly") as mock_resample:
        transcribe(wav_bytes)
        assert not mock_resample.called
