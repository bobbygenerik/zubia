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

@pytest.fixture
def mock_room():
    room = MagicMock(spec=main.Room)
    room.id = "room1"
    room.name = "Test Room"
    room.users = {}
    return room

@pytest.fixture
def mock_user():
    user = MagicMock(spec=main.User)
    user.id = "user1"
    user.name = "Test User"
    user.language = "en"
    user.is_muted = False
    return user

@pytest.mark.asyncio
@patch("main.broadcast_system")
async def test_handle_control_message_mute(mock_broadcast, mock_room, mock_user):
    """Test mute control message."""
    data = {"type": "mute"}

    with patch("main.get_user_list", return_value=[{"id": "user1", "name": "Test User"}]):
        await main.handle_control_message(mock_room, mock_user, data)

    assert mock_user.is_muted is True
    mock_user.clear_cache.assert_called_once()
    mock_broadcast.assert_called_once_with(mock_room, {
        "type": "user_muted",
        "userId": mock_user.id,
        "userName": mock_user.name,
        "users": [{"id": "user1", "name": "Test User"}],
    })

@pytest.mark.asyncio
@patch("main.broadcast_system")
async def test_handle_control_message_unmute(mock_broadcast, mock_room, mock_user):
    """Test unmute control message."""
    mock_user.is_muted = True
    data = {"type": "unmute"}

    with patch("main.get_user_list", return_value=[{"id": "user1", "name": "Test User"}]):
        await main.handle_control_message(mock_room, mock_user, data)

    assert mock_user.is_muted is False
    mock_user.clear_cache.assert_called_once()
    mock_broadcast.assert_called_once_with(mock_room, {
        "type": "user_unmuted",
        "userId": mock_user.id,
        "userName": mock_user.name,
        "users": [{"id": "user1", "name": "Test User"}],
    })

@pytest.mark.asyncio
@patch("main.broadcast_system")
async def test_handle_control_message_change_language(mock_broadcast, mock_room, mock_user):
    """Test change_language control message."""
    data = {"type": "change_language", "language": "es"}
    main.users_db[mock_user.id] = {"name": "Test User", "language": "en"}

    with patch("main.get_user_list", return_value=[{"id": "user1", "name": "Test User"}]):
        await main.handle_control_message(mock_room, mock_user, data)

    assert mock_user.language == "es"
    assert main.users_db[mock_user.id]["language"] == "es"
    mock_user.clear_cache.assert_called_once()
    mock_broadcast.assert_called_once_with(mock_room, {
        "type": "user_language_changed",
        "userId": mock_user.id,
        "userName": mock_user.name,
        "language": "es",
        "users": [{"id": "user1", "name": "Test User"}],
    })

    # Cleanup global state
    del main.users_db[mock_user.id]

@pytest.mark.asyncio
@patch("main.broadcast_system")
async def test_handle_control_message_unknown(mock_broadcast, mock_room, mock_user):
    """Test unknown control message does nothing."""
    data = {"type": "unknown_type"}

    await main.handle_control_message(mock_room, mock_user, data)

    mock_user.clear_cache.assert_not_called()
    mock_broadcast.assert_not_called()
