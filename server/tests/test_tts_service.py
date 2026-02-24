import sys
import unittest
from unittest.mock import MagicMock, patch
import logging
import io

# Set up logging to capture output
logging.basicConfig(level=logging.DEBUG)

# Mock piper and numpy before importing tts_service
sys.modules["piper"] = MagicMock()
sys.modules["numpy"] = MagicMock()

# Import the service
from server import tts_service

class TestTTSServiceBroadException(unittest.TestCase):
    def setUp(self):
        # Fix numpy mock to handle zeros().tobytes()
        mock_array = MagicMock()
        mock_array.tobytes.return_value = b'\x00' * 100 # Some bytes
        sys.modules["numpy"].zeros.return_value = mock_array
        sys.modules["numpy"].int16 = "int16" # Just a string or whatever

    @patch("server.tts_service._download_voice")
    def test_synthesize_exception_handling(self, mock_download):
        # Setup mock voice
        mock_voice = MagicMock()
        mock_voice.config.sample_rate = 22050
        # Simulate an exception during synthesis
        mock_voice.synthesize.side_effect = RuntimeError("Synthesis crashed!")

        # Mock PiperVoice.load to return our mock voice
        sys.modules["piper"].PiperVoice.load.return_value = mock_voice

        # Mock download to return valid paths
        mock_download.return_value = (MagicMock(), MagicMock())

        # We need to ensure _synthesizers is clean or we mock it
        with patch("server.tts_service._synthesizers", {}):
            # Capture logs
            with self.assertLogs("voxbridge.tts", level="ERROR") as cm:
                result = tts_service.synthesize("test text", "en")

            # Assert silence is returned (not empty, has some bytes)
            self.assertTrue(len(result) > 0)

            # Verify the log message
            self.assertTrue(any("TTS synthesis failed" in log for log in cm.output))

            # Verify that exc_info was included (traceback available)
            error_record = next(r for r in cm.records if "TTS synthesis failed" in r.getMessage())
            self.assertIsNotNone(error_record.exc_info, "Exception info (traceback) should be logged")
            self.assertIsInstance(error_record.exc_info[1], RuntimeError)

    def test_download_exception_handling(self):
        # Ensure _synthesizers is empty so it tries to download
        with patch("server.tts_service._synthesizers", {}):
            with patch("server.tts_service._download_voice") as mock_download:
                mock_download.side_effect = Exception("Download failed hard!")

                with self.assertLogs("voxbridge.tts", level="ERROR") as cm:
                    result = tts_service.synthesize("test text", "es") # Use non-default lang to trigger logic

                self.assertTrue(len(result) > 0)

                # Check for inner try/except log
                self.assertTrue(any("Could not get voice model for 'es'" in log for log in cm.output))

                error_record = next(r for r in cm.records if "Could not get voice model" in r.getMessage())
                self.assertIsNotNone(error_record.exc_info, "Download exception info should be logged")
                self.assertIn("Download failed hard!", str(error_record.exc_info[1]))

if __name__ == "__main__":
    unittest.main()
