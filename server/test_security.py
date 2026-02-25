import pytest
from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect
from main import app

client = TestClient(app)

def test_create_room_long_name():
    long_name = "a" * 51
    response = client.post("/api/rooms", json={"name": long_name})
    assert response.status_code == 422
    # Pydantic returns validation errors
    assert response.json()["detail"][0]["type"] == "string_too_long"

def test_create_room_xss_name():
    xss_name = "<script>alert('xss')</script>"
    # html.escape escapes <, >, &, ", and ' (if quote=True, which is default)
    expected_name = "&lt;script&gt;alert(&#x27;xss&#x27;)&lt;/script&gt;"
    response = client.post("/api/rooms", json={"name": xss_name})
    assert response.status_code == 200
    assert response.json()["name"] == expected_name

def test_create_room_empty_name():
    # If name is missing or empty, it defaults to "Room {id}"
    response = client.post("/api/rooms", json={})
    assert response.status_code == 200
    assert response.json()["name"].startswith("Room ")

    response = client.post("/api/rooms", json={"name": ""})
    assert response.status_code == 200
    assert response.json()["name"].startswith("Room ")

    response = client.post("/api/rooms", json={"name": "   "})
    assert response.status_code == 200
    assert response.json()["name"].startswith("Room ")

def test_create_room_valid_name():
    valid_name = "My Cool Room"
    response = client.post("/api/rooms", json={"name": valid_name})
    assert response.status_code == 200
    assert response.json()["name"] == valid_name

def test_websocket_join_valid():
    with client.websocket_connect("/ws/room123") as websocket:
        websocket.send_json({"name": "User1", "language": "en"})

        # We might receive user_joined (broadcast) and joined (direct)
        data1 = websocket.receive_json()
        data2 = websocket.receive_json()

        types = {data1["type"], data2["type"]}
        assert "joined" in types
        assert "user_joined" in types

        joined_msg = data1 if data1["type"] == "joined" else data2
        assert joined_msg["roomName"] == "Room room123"

def test_websocket_join_xss():
    with client.websocket_connect("/ws/room123") as websocket:
        xss_name = "<script>alert('xss')</script>"
        websocket.send_json({"name": xss_name, "language": "en"})

        data1 = websocket.receive_json()
        data2 = websocket.receive_json()

        types = {data1["type"], data2["type"]}
        assert "joined" in types
        assert "user_joined" in types

        # Check in joined message
        joined_msg = data1 if data1["type"] == "joined" else data2
        users = joined_msg["users"]
        my_user = next(u for u in users if u["id"] == joined_msg["userId"])
        assert my_user["name"] == "&lt;script&gt;alert(&#x27;xss&#x27;)&lt;/script&gt;"

def test_websocket_join_invalid_lang():
    # If invalid language (too long), it should close connection
    with pytest.raises(WebSocketDisconnect) as excinfo:
        with client.websocket_connect("/ws/room123") as websocket:
            websocket.send_json({"name": "User2", "language": "invalid!!!!"})
            websocket.receive_json()
    assert excinfo.value.code == 4002
