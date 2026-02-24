import sys
import unittest
from unittest.mock import MagicMock
import os
import numpy as np
import wave
import io

# Mock faster_whisper to avoid dependency error
# We must mock it before importing server.stt_service
sys.modules['faster_whisper'] = MagicMock()

# Set python path to include server root
# We assume this script is in server/tests/
# We want to import server.stt_service from server/stt_service.py
# If run from root, 'server' is a package.
# If run from server/tests/, we need to go up two levels.
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))

try:
    from server.stt_service import wav_bytes_to_float32
except ImportError:
    # Fallback if running from a different context
    sys.path.append(os.getcwd())
    from server.stt_service import wav_bytes_to_float32

class TestWavBytesToFloat32(unittest.TestCase):
    def create_wav_bytes(self, data: np.ndarray, sampwidth: int) -> bytes:
        """Helper to create WAV bytes from numpy array."""
        buffer = io.BytesIO()
        with wave.open(buffer, 'wb') as wf:
            wf.setnchannels(1)
            wf.setsampwidth(sampwidth)
            wf.setframerate(16000)
            wf.writeframes(data.tobytes())
        return buffer.getvalue()

    def test_16bit_parsing(self):
        # Max value: 32767 -> expecting ~1.0 (32767/32768 = 0.999969)
        # Min value: -32768 -> expecting -1.0 (-32768/32768 = -1.0)
        data = np.array([32767, -32768, 0], dtype=np.int16)
        wav_bytes = self.create_wav_bytes(data, 2)

        audio, sample_rate = wav_bytes_to_float32(wav_bytes)

        self.assertEqual(sample_rate, 16000)
        expected = data.astype(np.float32) / 32768.0
        np.testing.assert_allclose(audio, expected, atol=1e-6)

    def test_32bit_parsing(self):
        # Max value: 2147483647 -> expecting ~1.0
        # Min value: -2147483648 -> expecting -1.0
        data = np.array([2147483647, -2147483648, 0], dtype=np.int32)
        wav_bytes = self.create_wav_bytes(data, 4)

        audio, sample_rate = wav_bytes_to_float32(wav_bytes)

        self.assertEqual(sample_rate, 16000)
        expected = data.astype(np.float32) / 2147483648.0
        np.testing.assert_allclose(audio, expected, atol=1e-6)

    def test_unsupported_width(self):
        # Test 1-byte (8-bit) which is not supported by current impl
        # 8-bit WAV is usually unsigned 0-255, so logic differs.
        data = np.array([128, 0, 255], dtype=np.uint8)
        wav_bytes = self.create_wav_bytes(data, 1)

        with self.assertRaises(ValueError):
            wav_bytes_to_float32(wav_bytes)

if __name__ == '__main__':
    unittest.main()
