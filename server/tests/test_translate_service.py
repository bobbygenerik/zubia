import unittest
from unittest.mock import MagicMock, patch
import sys
import os

# Add server directory to sys.path so we can import translate_service
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

# Mock argostranslate before importing translate_service
# We need to mock the modules that translate_service imports
sys.modules["argostranslate"] = MagicMock()
sys.modules["argostranslate.package"] = MagicMock()
sys.modules["argostranslate.translate"] = MagicMock()

import translate_service

class TestTranslateService(unittest.TestCase):
    def setUp(self):
        # Reset mocks before each test
        translate_service.argostranslate.translate.translate.reset_mock()
        translate_service.argostranslate.package.get_installed_languages.reset_mock()
        translate_service.argostranslate.package.get_available_packages.reset_mock()
        # Reset internal state
        translate_service._installed_pairs = set()
        translate_service._initialized = False

    def test_translate_same_language(self):
        """Test translation when source and target languages are the same."""
        text = "Hello"
        result = translate_service.translate(text, "en", "en")
        self.assertEqual(result, text)
        translate_service.argostranslate.translate.translate.assert_not_called()

    def test_translate_empty_text(self):
        """Test translation with empty or whitespace-only text."""
        self.assertEqual(translate_service.translate("", "en", "es"), "")
        self.assertEqual(translate_service.translate("   ", "en", "es"), "")
        translate_service.argostranslate.translate.translate.assert_not_called()

    @patch("translate_service._ensure_package_installed")
    def test_translate_direct_success(self, mock_ensure_installed):
        """Test successful direct translation."""
        translate_service.argostranslate.translate.translate.return_value = "Hola"

        result = translate_service.translate("Hello", "en", "es")

        self.assertEqual(result, "Hola")
        # Should ensure package installed
        mock_ensure_installed.assert_called_with("en", "es")
        # Should call direct translation
        translate_service.argostranslate.translate.translate.assert_called_once_with("Hello", "en", "es")

    @patch("translate_service._ensure_package_installed")
    def test_translate_direct_failure_pivot_success(self, mock_ensure_installed):
        """Test fallback to pivot translation when direct translation fails."""
        # Setup mock to raise exception on first call (direct), succeed on subsequent calls (pivot)
        def side_effect(text, from_lang, to_lang):
            if from_lang == "fr" and to_lang == "es":
                raise Exception("Direct translation failed")
            if from_lang == "fr" and to_lang == "en":
                return "Hello"
            if from_lang == "en" and to_lang == "es":
                return "Hola"
            return ""

        translate_service.argostranslate.translate.translate.side_effect = side_effect

        result = translate_service.translate("Bonjour", "fr", "es")

        self.assertEqual(result, "Hola")
        # Should have tried direct translation
        # Then pivot: fr -> en, then en -> es
        self.assertEqual(translate_service.argostranslate.translate.translate.call_count, 3)

    @patch("translate_service._ensure_package_installed")
    def test_translate_all_failure(self, mock_ensure_installed):
        """Test when both direct and pivot translations fail."""
        translate_service.argostranslate.translate.translate.side_effect = Exception("Translation failed")

        text = "Bonjour"
        result = translate_service.translate(text, "fr", "es")

        self.assertEqual(result, text) # Should return original text
        # Should have tried direct translation
        # Then pivot: fr -> en (failed)
        # Then give up
        self.assertEqual(translate_service.argostranslate.translate.translate.call_count, 2)

    @patch("translate_service._ensure_package_installed")
    def test_translate_pivot_failure_step2(self, mock_ensure_installed):
        """Test when direct fails and pivot second step fails."""
        def side_effect(text, from_lang, to_lang):
            if from_lang == "fr" and to_lang == "es":
                raise Exception("Direct translation failed")
            if from_lang == "fr" and to_lang == "en":
                return "Hello" # First step succeeds
            if from_lang == "en" and to_lang == "es":
                raise Exception("Second step failed")
            return ""

        translate_service.argostranslate.translate.translate.side_effect = side_effect

        text = "Bonjour"
        result = translate_service.translate(text, "fr", "es")

        self.assertEqual(result, text)
        # Direct -> catch -> pivot step 1 (success) -> pivot step 2 (fail) -> catch -> return text
        self.assertEqual(translate_service.argostranslate.translate.translate.call_count, 3)

if __name__ == '__main__':
    unittest.main()
