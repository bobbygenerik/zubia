import sys
import unittest
from unittest.mock import MagicMock, patch
from pathlib import Path
import io

# 1. Mock heavy dependencies BEFORE importing the module under test
# This prevents ImportError and avoids loading actual heavy models during testing
mock_piper = MagicMock()
mock_faster_whisper = MagicMock()
mock_argostranslate = MagicMock()
mock_argostranslate_package = MagicMock()
mock_argostranslate_translate = MagicMock()

sys.modules["piper"] = mock_piper
sys.modules["faster_whisper"] = mock_faster_whisper
sys.modules["argostranslate"] = mock_argostranslate
sys.modules["argostranslate.package"] = mock_argostranslate_package
sys.modules["argostranslate.translate"] = mock_argostranslate_translate

# Do NOT mock numpy globally since scipy needs it in other tests

# Now import the module under test
# We need to make sure server is in path if running from root
from server import tts_service

class TestTTSService(unittest.TestCase):
    def setUp(self):
        # Reset synthesizers cache before each test
        tts_service._synthesizers = {}
        # Reset LRU cache if exists
        if hasattr(tts_service, "_inner_synthesize"):
            tts_service._inner_synthesize.cache_clear()

        # Reset mocks
        mock_piper.reset_mock()

        # Reset specific return values/side effects
        # Clear side effects on the global piper mock to prevent test pollution
        sys.modules["piper"].PiperVoice.load.side_effect = None

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

    @patch("server.tts_service._generate_silence")
    def test_synthesize_empty_text(self, mock_silence):
        """Test that empty text returns silence."""
        # Setup
        mock_silence.return_value = b'silence'

        # Act
        result = tts_service.synthesize("", "en")

        # Assert
        self.assertIsInstance(result, bytes)
        mock_silence.assert_called()

    @patch("server.tts_service._download_voice")
    @patch("server.tts_service._generate_silence")
    def test_synthesize_download_failure(self, mock_silence, mock_download):
        """Test that download failure returns silence."""
        # Setup
        mock_download.side_effect = Exception("Download failed")
        mock_silence.return_value = b'silence'

        # Act
        result = tts_service.synthesize("Hello", "fr")

        # Assert
        self.assertIsInstance(result, bytes)
        mock_silence.assert_called()

    @patch("server.tts_service._inner_synthesize")
    @patch("server.tts_service._generate_silence")
    def test_synthesize_inner_exception(self, mock_silence, mock_inner_synthesize):
        """Test that an exception in _inner_synthesize is caught and returns silence."""
        # Setup
        mock_inner_synthesize.side_effect = Exception("Inner synthesis failed")
        mock_silence.return_value = b'silence'

        # Act
        result = tts_service.synthesize("Hello", "en")

        # Assert
        self.assertEqual(result, b'silence')
        mock_inner_synthesize.assert_called_once_with("Hello", "en", 1.0)
        mock_silence.assert_called_once_with(0.5)

    @patch("server.tts_service._download_voice")
    @patch("server.tts_service._generate_silence")
    def test_synthesize_piper_load_failure(self, mock_silence, mock_download):
        """Test that PiperVoice.load failure returns silence."""
        # Setup
        mock_download.return_value = (Path("a"), Path("b"))
        mock_piper_voice_cls = sys.modules["piper"].PiperVoice
        mock_piper_voice_cls.load.side_effect = Exception("Load failed")
        mock_silence.return_value = b'silence'

        # Act
        result = tts_service.synthesize("Hello", "es")

        # Assert
        self.assertIsInstance(result, bytes)
        mock_silence.assert_called()

    def test_get_voice_path_fallback(self):
        """Test that _get_voice_path falls back to English for unknown languages."""
        # Act
        onnx_path, json_path, model_name, lang_short, lang_region, name, quality = tts_service._get_voice_path("unknown_lang")

        # Assert
        self.assertEqual(model_name, tts_service.VOICE_MODELS["en"])
        self.assertEqual(lang_short, "en")
        self.assertEqual(lang_region, "en_US")
        self.assertEqual(name, "lessac")
        self.assertEqual(quality, "medium")
        self.assertTrue(str(onnx_path).endswith(f"{model_name}.onnx"))
        self.assertTrue(str(json_path).endswith(f"{model_name}.onnx.json"))
