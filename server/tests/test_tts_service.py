<<<<<<< HEAD
import pytest
from pathlib import Path
from server.tts_service import _get_voice_path, VOICES_DIR, VOICE_MODELS

def test_get_voice_path_structure():
    """Test that _get_voice_path returns the expected 7-element tuple."""
    result = _get_voice_path("en")
    assert isinstance(result, tuple)
    assert len(result) == 7

    onnx_path, json_path, model_name, lang_short, lang_region, name, quality = result
    assert isinstance(onnx_path, Path)
    assert isinstance(json_path, Path)
    assert isinstance(model_name, str)
    assert isinstance(lang_short, str)
    assert isinstance(lang_region, str)
    assert isinstance(name, str)
    assert isinstance(quality, str)

@pytest.mark.parametrize("lang", ["en", "es", "fr"])
def test_get_voice_path_valid_languages(lang):
    """Test _get_voice_path with valid language codes."""
    expected_model = VOICE_MODELS[lang]
    onnx_path, json_path, model_name, lang_short, lang_region, name, quality = _get_voice_path(lang)

    assert model_name == expected_model
    assert onnx_path == VOICES_DIR / f"{expected_model}.onnx"
    assert json_path == VOICES_DIR / f"{expected_model}.onnx.json"

    # Verify components derived from model_name
    parts = expected_model.split("-")
    assert lang_region == parts[0]
    assert name == parts[1]
    assert quality == parts[2]
    assert lang_short == parts[0][:2]

def test_get_voice_path_invalid_language_fallback():
    """Test that _get_voice_path falls back to English for unknown languages."""
    # "xx" is not in VOICE_MODELS
    en_model = VOICE_MODELS["en"]
    onnx_path, json_path, model_name, lang_short, lang_region, name, quality = _get_voice_path("xx")

    assert model_name == en_model
    assert lang_short == "en"
    assert lang_region == "en_US"
=======
import sys
import unittest
from unittest.mock import MagicMock, patch
from pathlib import Path
import io

# 1. Mock heavy dependencies BEFORE importing the module under test
# This prevents ImportError and avoids loading actual heavy models during testing
mock_piper = MagicMock()
mock_numpy = MagicMock()
mock_faster_whisper = MagicMock()
mock_argostranslate = MagicMock()
mock_argostranslate_package = MagicMock()
mock_argostranslate_translate = MagicMock()

import sys
import pytest
import unittest
from unittest.mock import MagicMock, patch
from pathlib import Path
import io
import json

# Keep lightweight pytest-style checks and more extensive unittest-based tests
# in the same file. pytest can discover and run unittest.TestCase subclasses.

# Pytest-style tests (quick sanity checks)
from server.tts_service import _get_voice_path, VOICES_DIR, VOICE_MODELS

def test_get_voice_path_structure():
    """Test that _get_voice_path returns the expected 7-element tuple."""
    result = _get_voice_path("en")
    assert isinstance(result, tuple)
    assert len(result) == 7

    onnx_path, json_path, model_name, lang_short, lang_region, name, quality = result
    assert isinstance(onnx_path, Path)
    assert isinstance(json_path, Path)
    assert isinstance(model_name, str)
    assert isinstance(lang_short, str)
    assert isinstance(lang_region, str)
    assert isinstance(name, str)
    assert isinstance(quality, str)


@pytest.mark.parametrize("lang", ["en", "es", "fr"])
def test_get_voice_path_valid_languages(lang):
    """Test _get_voice_path with valid language codes."""
    expected_model = VOICE_MODELS[lang]
    onnx_path, json_path, model_name, lang_short, lang_region, name, quality = _get_voice_path(lang)
    assert model_name == expected_model
    assert onnx_path == VOICES_DIR / f"{expected_model}.onnx"
    assert json_path == VOICES_DIR / f"{expected_model}.onnx.json"

    # Verify components derived from model_name
    parts = expected_model.split("-")
    assert lang_region == parts[0]
    assert name == parts[1]
    assert quality == parts[2]
    assert lang_short == parts[0][:2]


def test_get_voice_path_invalid_language_fallback():
    """Test that _get_voice_path falls back to English for unknown languages."""
    en_model = VOICE_MODELS["en"]
    onnx_path, json_path, model_name, lang_short, lang_region, name, quality = _get_voice_path("xx")
    assert model_name == en_model
    assert lang_short == "en"
    assert lang_region == "en_US"


# Unittest-style tests with mocks for heavier behavior
# Mock heavy dependencies BEFORE importing the module under test
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
mock_numpy.zeros.return_value.tobytes.return_value = b'\x00' * 100
mock_numpy.int16 = "int16"

from server import tts_service


class TestTTSService(unittest.TestCase):
    def setUp(self):
        tts_service._synthesizers = {}
        mock_piper.reset_mock()
        mock_numpy.reset_mock()
        mock_numpy.zeros.return_value.tobytes.return_value = b'\x00' * 100
        sys.modules["piper"].PiperVoice.load.side_effect = None

    @patch("server.tts_service._download_voice")
    def test_synthesize_cache_miss_success(self, mock_download):
        lang = "en"
        mock_onnx = Path("/tmp/mock_model.onnx")
        mock_json = Path("/tmp/mock_model.onnx.json")
        mock_download.return_value = (mock_onnx, mock_json)

        mock_piper_voice_cls = sys.modules["piper"].PiperVoice
        mock_voice_instance = MagicMock()
        mock_piper_voice_cls.load.return_value = mock_voice_instance
        mock_voice_instance.config.sample_rate = 22050

        result = tts_service.synthesize("Hello world", lang)

        mock_download.assert_called_once_with(lang)
        mock_piper_voice_cls.load.assert_called_once()
        mock_voice_instance.synthesize.assert_called_once()
        self.assertIsInstance(result, bytes)

        cache_key = str(mock_onnx)
        self.assertIn(cache_key, tts_service._synthesizers)
        self.assertEqual(tts_service._synthesizers[cache_key], mock_voice_instance)

    @patch("server.tts_service._download_voice")
    def test_synthesize_cache_hit(self, mock_download):
        lang = "en"
        onnx_path, _, _, _, _, _, _ = tts_service._get_voice_path(lang)
        cache_key = str(onnx_path)

        mock_voice = MagicMock()
        mock_voice.config.sample_rate = 22050
        tts_service._synthesizers[cache_key] = mock_voice

        result = tts_service.synthesize("Hello world", lang)

        mock_download.assert_not_called()
        mock_voice.synthesize.assert_called_once()
        self.assertIsInstance(result, bytes)

    def test_synthesize_empty_text(self):
        result = tts_service.synthesize("", "en")
        self.assertIsInstance(result, bytes)
        mock_numpy.zeros.assert_called()

    @patch("server.tts_service._download_voice")
    def test_synthesize_download_failure(self, mock_download):
        mock_download.side_effect = Exception("Download failed")
        result = tts_service.synthesize("Hello", "fr")
        self.assertIsInstance(result, bytes)
        mock_numpy.zeros.assert_called()

    @patch("server.tts_service._download_voice")
    def test_synthesize_piper_load_failure(self, mock_download):
        mock_download.return_value = (Path("a"), Path("b"))
        mock_piper_voice_cls = sys.modules["piper"].PiperVoice
        mock_piper_voice_cls.load.side_effect = Exception("Load failed")
        result = tts_service.synthesize("Hello", "es")
        self.assertIsInstance(result, bytes)
        mock_numpy.zeros.assert_called()
