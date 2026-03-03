import sys
from unittest.mock import MagicMock
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

]

for module_name in mock_modules:
    sys.modules[module_name] = MagicMock()

# Add server directory to sys.path
sys.path.append(str(Path(__file__).parent.parent))

from fastapi.testclient import TestClient
import main
from main import app

client = TestClient(app)

def test_list_rooms_empty():
    """Test /api/rooms returns an empty dict when there are no active rooms."""
    # Ensure the rooms dictionary is empty
    main.rooms.clear()

    response = client.get("/api/rooms")
    assert response.status_code == 200
    assert response.json() == {}

def test_list_rooms_with_data():
    """Test /api/rooms returns correct room details when rooms exist."""
    # Ensure the rooms dictionary is clean
    main.rooms.clear()

    # Create a test room
    test_room = main.Room(id="room1", name="Test Room")

    # Add a mock user to the room to test userCount
    mock_user = MagicMock(spec=main.User)
    mock_user.id = "user1"
    mock_user.name = "Test User"
    mock_user.language = "en"
    mock_user.is_muted = False

    test_room.users["user1"] = mock_user

    # Add room to the global registry
    main.rooms["room1"] = test_room

    response = client.get("/api/rooms")
    assert response.status_code == 200

    data = response.json()
    assert "room1" in data

    room_data = data["room1"]
    assert room_data["id"] == "room1"
    assert room_data["name"] == "Test Room"
    assert room_data["userCount"] == 1
    assert "createdAt" in room_data
    assert isinstance(room_data["createdAt"], float)
