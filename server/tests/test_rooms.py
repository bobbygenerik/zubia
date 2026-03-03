import sys
from unittest.mock import MagicMock
import pytest
from fastapi.testclient import TestClient

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

import main

client = TestClient(main.app)

@pytest.fixture(autouse=True)
def clear_rooms():
    """Clear rooms before and after each test to ensure isolation."""
    main.rooms.clear()
    yield
    main.rooms.clear()

def test_create_room():
    """Test creating a room with a valid name."""
    response = client.post("/api/rooms", json={"name": "Test Room"})
    assert response.status_code == 200

    data = response.json()
    assert "id" in data
    assert len(data["id"]) == 8
    assert data["name"] == "Test Room"

    # Verify the room exists in the global state
    room_id = data["id"]
    assert room_id in main.rooms
    assert main.rooms[room_id].name == "Test Room"
    assert main.rooms[room_id].id == room_id

def test_create_room_default_name():
    """Test creating a room without providing a name."""
    response = client.post("/api/rooms", json={})
    assert response.status_code == 200

    data = response.json()
    assert "id" in data
    room_id = data["id"]

    # Ensure it defaults to "Room {id}"
    expected_name = f"Room {room_id}"
    assert data["name"] == expected_name

    # Verify the room exists in the global state
    assert room_id in main.rooms
    assert main.rooms[room_id].name == expected_name

def test_list_rooms():
    """Test listing rooms via the GET /api/rooms endpoint."""
    # Create two rooms
    resp1 = client.post("/api/rooms", json={"name": "Room A"})
    resp2 = client.post("/api/rooms", json={"name": "Room B"})

    room_id_a = resp1.json()["id"]
    room_id_b = resp2.json()["id"]

    # Get the list of rooms
    list_resp = client.get("/api/rooms")
    assert list_resp.status_code == 200

    rooms_data = list_resp.json()
    assert len(rooms_data) == 2

    assert room_id_a in rooms_data
    assert rooms_data[room_id_a]["id"] == room_id_a
    assert rooms_data[room_id_a]["name"] == "Room A"
    assert rooms_data[room_id_a]["userCount"] == 0
    assert "createdAt" in rooms_data[room_id_a]

    assert room_id_b in rooms_data
    assert rooms_data[room_id_b]["id"] == room_id_b
    assert rooms_data[room_id_b]["name"] == "Room B"
    assert rooms_data[room_id_b]["userCount"] == 0
    assert "createdAt" in rooms_data[room_id_b]
