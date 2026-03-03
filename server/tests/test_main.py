import sys
from unittest.mock import MagicMock, patch
import os
from pathlib import Path

# Mock heavy dependencies and internal services to isolate tests and avoid ImportError
mock_modules = [
    "faster_whisper",
    "argostranslate",
    "argostranslate.package",
    "argostranslate.translate",
    "piper",
    "stt_service",
    "translate_service",
    "tts_service",
    "numpy"
]

for module_name in mock_modules:
    sys.modules[module_name] = MagicMock()

sys.path.append(str(Path(__file__).parent.parent))

from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

@patch("main.get_supported_languages")
def test_get_languages(mock_get_supported_languages):
    """
    Test the /api/languages endpoint.
    It should return a 200 OK and the dictionary of supported languages
    provided by get_supported_languages.
    """
    mock_languages = {
        "en": "English",
        "es": "Spanish",
        "fr": "French"
    }
    mock_get_supported_languages.return_value = mock_languages

    response = client.get("/api/languages")

    assert response.status_code == 200
    assert response.json() == mock_languages
    mock_get_supported_languages.assert_called_once()
