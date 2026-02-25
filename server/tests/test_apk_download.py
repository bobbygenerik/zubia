import sys
from unittest.mock import MagicMock, patch
import os
from pathlib import Path

# Mock modules to avoid ImportError due to missing heavy dependencies
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

# Add server directory to sys.path
sys.path.append(str(Path(__file__).parent.parent))

from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_download_apk_default():
    """Test the default behavior (likely APK missing)."""
    response = client.get("/download")
    # Should return 200 with error message if APK not found
    assert response.status_code == 200
    assert response.json() == {"error": "APK not built yet"}

def test_download_apk_with_env_var(tmp_path):
    """
    Test that the download endpoint uses the configured APK path.
    """
    # Create a dummy APK
    dummy_apk = tmp_path / "test.apk"
    dummy_apk.write_text("test apk content")

    # We patch the APK_PATH in main module.
    # This assumes APK_PATH is defined in main module as a global variable.
    with patch("main.APK_PATH", dummy_apk):
        response = client.get("/download")
        assert response.status_code == 200
        assert response.content == b"test apk content"
        assert response.headers["content-type"] == "application/vnd.android.package-archive"
