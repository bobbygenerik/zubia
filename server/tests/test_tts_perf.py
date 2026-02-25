import sys
import time
import unittest
from unittest.mock import MagicMock, patch
from pathlib import Path

# Mock dependencies before importing the module under test
mock_piper = MagicMock()
mock_numpy = MagicMock()
mock_faster_whisper = MagicMock()
mock_argostranslate = MagicMock()
mock_argostranslate_package = MagicMock()
mock_argostranslate_translate = MagicMock()

sys.modules["piper"] = mock_piper
sys.modules["numpy"] = mock_numpy
sys.modules["faster_whisper"] = mock_faster_whisper
sys.modules["argostranslate"] = mock_argostranslate
sys.modules["argostranslate.package"] = mock_argostranslate_package
sys.modules["argostranslate.translate"] = mock_argostranslate_translate

# Configure numpy mock for _generate_silence
# numpy.zeros(...) returns an array, array.tobytes() returns bytes
mock_numpy.zeros.return_value.tobytes.return_value = b'\x00' * 100
mock_numpy.int16 = "int16"  # Just a dummy value

# Import the service
from server import tts_service

class TestTTSPerformance(unittest.TestCase):
    def setUp(self):
        # Reset synthesizers cache
        tts_service._synthesizers = {}
        # Clear LRU cache if it exists (for when I add it)
        if hasattr(tts_service, "_inner_synthesize"):
             tts_service._inner_synthesize.cache_clear()

        # Reset mocks
        mock_piper.reset_mock()
        mock_numpy.reset_mock()

    @patch("server.tts_service._download_voice")
    def test_synthesize_caching_performance(self, mock_download):
        """
        Verify that repeated calls to synthesize with the same arguments
        are cached and do not re-run the expensive synthesis logic.
        """
        # Setup mocks
        mock_voice = MagicMock()
        mock_voice.config.sample_rate = 22050

        # Make synthesis slow to simulate CPU load
        def slow_synthesize(text, wav_file, length_scale):
            time.sleep(0.1) # Simulate 100ms processing

        mock_voice.synthesize.side_effect = slow_synthesize

        # Mock loading the voice
        mock_piper.PiperVoice.load.return_value = mock_voice

        # Mock download to succeed immediately
        mock_download.return_value = (Path("mock.onnx"), Path("mock.json"))

        # Arguments
        text = "Hello world"
        lang = "en"

        # First call - should be slow
        start_time = time.time()
        result1 = tts_service.synthesize(text, lang)
        duration1 = time.time() - start_time

        # Second call - should be fast (cached)
        start_time = time.time()
        result2 = tts_service.synthesize(text, lang)
        duration2 = time.time() - start_time

        print(f"Call 1 duration: {duration1:.4f}s")
        print(f"Call 2 duration: {duration2:.4f}s")

        # Assertions
        # Expectation:
        # Without cache: Call 2 takes ~0.1s
        # With cache: Call 2 takes ~0.0s

        # This assertion will fail BEFORE optimization
        self.assertLess(duration2, 0.05, f"Second call took {duration2:.4f}s, expected < 0.05s (cache hit)")

        self.assertEqual(result1, result2, "Results should be identical")

        # Verify underlying mock called only once (if cached)
        # Without cache, this assertion will also fail (called twice)
        if hasattr(tts_service, "_inner_synthesize"):
             mock_voice.synthesize.assert_called_once()
        else:
             # Before optimization, it's called twice
             self.assertEqual(mock_voice.synthesize.call_count, 2)

if __name__ == "__main__":
    unittest.main()
