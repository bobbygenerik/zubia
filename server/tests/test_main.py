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

@pytest.mark.asyncio
@patch("main.broadcast_system")
async def test_handle_control_message_mute(mock_broadcast):
    room = main.Room(id="room1", name="Test Room")
    user = main.User(id="user1", name="Alice", language="en", websocket=MagicMock())
    room.users[user.id] = user
    user.is_muted = False
    user._dict = {"cached": "data"}

    await main.handle_control_message(room, user, {"type": "mute"})

    assert user.is_muted is True
    # _dict is populated again by get_user_list in broadcast, so we assert the contents reflect the change
    assert user._dict["isMuted"] is True
    mock_broadcast.assert_called_once_with(room, {
        "type": "user_muted",
        "userId": user.id,
        "userName": user.name,
        "users": main.get_user_list(room),
    })

@pytest.mark.asyncio
@patch("main.broadcast_system")
async def test_handle_control_message_unmute(mock_broadcast):
    room = main.Room(id="room1", name="Test Room")
    user = main.User(id="user1", name="Alice", language="en", websocket=MagicMock())
    room.users[user.id] = user
    user.is_muted = True
    user._dict = {"cached": "data"}

    await main.handle_control_message(room, user, {"type": "unmute"})

    assert user.is_muted is False
    assert user._dict["isMuted"] is False
    mock_broadcast.assert_called_once_with(room, {
        "type": "user_unmuted",
        "userId": user.id,
        "userName": user.name,
        "users": main.get_user_list(room),
    })

@pytest.mark.asyncio
@patch("main.broadcast_system")
async def test_handle_control_message_change_language(mock_broadcast):
    room = main.Room(id="room1", name="Test Room")
    user = main.User(id="user1", name="Alice", language="en", websocket=MagicMock())
    room.users[user.id] = user
    main.users_db[user.id] = {"id": user.id, "name": user.name, "language": "en"}
    user._dict = {"cached": "data"}

    await main.handle_control_message(room, user, {"type": "change_language", "language": "es"})

    assert user.language == "es"
    assert main.users_db[user.id]["language"] == "es"
    assert user._dict["language"] == "es"
    mock_broadcast.assert_called_once_with(room, {
        "type": "user_language_changed",
        "userId": user.id,
        "userName": user.name,
        "language": "es",
        "users": main.get_user_list(room),
    })

    # Clean up
    del main.users_db[user.id]


@pytest.mark.asyncio
@patch("main.broadcast_system")
async def test_handle_control_message_unknown(mock_broadcast):
    room = main.Room(id="room1", name="Test Room")
    user = main.User(id="user1", name="Alice", language="en", websocket=MagicMock())
    room.users[user.id] = user
    user.is_muted = False
    user._dict = {"cached": "data"}

    await main.handle_control_message(room, user, {"type": "unknown_type"})

    assert user.is_muted is False
    assert user._dict == {"cached": "data"}
    mock_broadcast.assert_not_called()
