import sys
import unittest
from unittest.mock import MagicMock, patch
from pathlib import Path
import io
import importlib

# We'll create mock objects but avoid mutating sys.modules at import time to
# prevent cross-test pollution. The tests will inject mocks in `setUp` while
# importing `server.tts_service` dynamically.
mock_piper = MagicMock()
mock_numpy = MagicMock()
mock_faster_whisper = MagicMock()
mock_argostranslate = MagicMock()
mock_argostranslate_package = MagicMock()
mock_argostranslate_translate = MagicMock()

# Configure numpy mock for _generate_silence convenience (can be reset in setUp)
mock_numpy.zeros.return_value.tobytes.return_value = b'\x00' * 100
mock_numpy.int16 = "int16"  # Dummy sentinel

# Will be assigned in setUp
tts_service = None

class TestTTSService(unittest.TestCase):
    def setUp(self):
        # Inject mocks into sys.modules and import the tts_service module so it
        # picks up the mocked heavy dependencies. We restore sys.modules after
        # importing to avoid polluting other tests.
        real_mods = {}
        for name, mock in (
            ("piper", mock_piper),
            ("numpy", mock_numpy),
            ("faster_whisper", mock_faster_whisper),
            ("argostranslate", mock_argostranslate),
            ("argostranslate.package", mock_argostranslate_package),
            ("argostranslate.translate", mock_argostranslate_translate),
        ):
            real_mods[name] = sys.modules.get(name)
            sys.modules[name] = mock

        # Import (or reload) the module under test so it captures mocked deps
        global tts_service
        if "server.tts_service" in sys.modules:
            importlib.reload(sys.modules["server.tts_service"])
            tts_service = sys.modules["server.tts_service"]
        else:
            from server import tts_service as _mod
            tts_service = _mod

        # Restore original sys.modules entries
        for name, prev in real_mods.items():
            if prev is None:
                del sys.modules[name]
            else:
                sys.modules[name] = prev

        # Reset synthesizers cache before each test
        tts_service._synthesizers = {}

        # Reset mocks
        mock_piper.reset_mock()
        mock_numpy.reset_mock()

        # Reset specific return values/side effects we rely on
        mock_numpy.zeros.return_value.tobytes.return_value = b'\x00' * 100

        # Clear side effects on the global piper mock to prevent test pollution
        mock_piper.PiperVoice.load.side_effect = None

    @patch("server.tts_service._download_voice")
    def test_synthesize_cache_miss_success(self, mock_download):
        """Test synthesis when voice is not in cache (downloads and loads it)."""
        # Setup
        lang = "en"
        mock_onnx = Path("/tmp/mock_model.onnx")
        mock_json = Path("/tmp/mock_model.onnx.json")
        mock_download.return_value = (mock_onnx, mock_json)

        # Mock PiperVoice.load to return a mock voice instance
        mock_piper_voice_cls = sys.modules["piper"].PiperVoice
        mock_voice_instance = MagicMock()
        mock_piper_voice_cls.load.return_value = mock_voice_instance
        mock_voice_instance.config.sample_rate = 22050

        # Act
        result = tts_service.synthesize("Hello world", lang)

        # Assert
        mock_download.assert_called_once_with(lang)
        mock_piper_voice_cls.load.assert_called_once_with(str(mock_onnx), str(mock_json))
        mock_voice_instance.synthesize.assert_called_once()

        # Check that result is bytes (from our in-memory synthesis)
        self.assertIsInstance(result, bytes)

        # Verify cache update
        cache_key = str(mock_onnx)
        self.assertIn(cache_key, tts_service._synthesizers)
        self.assertEqual(tts_service._synthesizers[cache_key], mock_voice_instance)

    @patch("server.tts_service._download_voice")
    def test_synthesize_cache_hit(self, mock_download):
        """Test synthesis when voice is already in cache."""
        # Setup
        lang = "en"
        # We need to know the cache key the service will generate
        onnx_path, _, _, _, _, _, _ = tts_service._get_voice_path(lang)
        cache_key = str(onnx_path)

        mock_voice = MagicMock()
        mock_voice.config.sample_rate = 22050
        # Pre-populate cache
        tts_service._synthesizers[cache_key] = mock_voice

        # Act
        result = tts_service.synthesize("Hello world", lang)

        # Assert
        mock_download.assert_not_called()
        mock_voice.synthesize.assert_called_once()
        self.assertIsInstance(result, bytes)

    def test_synthesize_empty_text(self):
        """Test that empty text returns silence."""
        # Act
        result = tts_service.synthesize("", "en")

        # Assert
        self.assertIsInstance(result, bytes)
        # Should return non-empty silence bytes
        self.assertGreater(len(result), 0)

    @patch("server.tts_service._download_voice")
    def test_synthesize_download_failure(self, mock_download):
        """Test that download failure returns silence."""
        # Setup
        mock_download.side_effect = Exception("Download failed")

        # Act
        result = tts_service.synthesize("Hello", "fr")

        # Assert
        self.assertIsInstance(result, bytes)
        # Should return silence bytes
        self.assertGreater(len(result), 0)

    @patch("server.tts_service._download_voice")
    def test_synthesize_piper_load_failure(self, mock_download):
        """Test that PiperVoice.load failure returns silence."""
        # Setup
        mock_download.return_value = (Path("a"), Path("b"))
        mock_piper_voice_cls = sys.modules["piper"].PiperVoice
        mock_piper_voice_cls.load.side_effect = Exception("Load failed")

        # Act
        result = tts_service.synthesize("Hello", "es")

        # Assert
        self.assertIsInstance(result, bytes)
        # Should return silence bytes on load failure
        self.assertGreater(len(result), 0)
