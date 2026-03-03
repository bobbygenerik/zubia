import sys
from unittest.mock import MagicMock, patch
import os
from pathlib import Path
import asyncio

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

]

for module_name in mock_modules:
    sys.modules[module_name] = MagicMock()

sys.path.append(str(Path(__file__).parent.parent))

from fastapi.testclient import TestClient
import main
from starlette.websockets import WebSocketDisconnect
import pytest

client = TestClient(main.app)

def test_websocket_join_timeout():
    """Test WebSocket disconnects with code 4000 when join message times out."""
    # We patch asyncio.wait_for in the main module
    with patch("main.asyncio.wait_for", side_effect=asyncio.TimeoutError("timeout")):
        # When TestClient's websocket is closed by the server (e.g. via await websocket.close(code=4000)),
        # it typically raises a WebSocketDisconnect exception with the corresponding code.
        with pytest.raises(WebSocketDisconnect) as exc_info:
            with client.websocket_connect("/ws/test_room") as websocket:
                # Need to read to detect the closure
                websocket.receive_json()

        assert exc_info.value.code == 4000
        assert exc_info.value.reason == "Join timeout"

def test_websocket_join_invalid_data():
    """Test WebSocket disconnects with code 4002 when join message has invalid data."""
    with pytest.raises(WebSocketDisconnect) as exc_info:
        with client.websocket_connect("/ws/test_room") as websocket:
            # Send invalid data (missing required language field or invalid type)
            websocket.send_json({"name": "a" * 100}) # Name is too long and language is missing
            websocket.receive_json()

    assert exc_info.value.code == 4002
    assert exc_info.value.reason == "Invalid join data"
