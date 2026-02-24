import sys
from unittest.mock import MagicMock

# Mock heavy dependencies before importing server.main
def mock_dependencies():
    modules = [
        "faster_whisper",
        "argostranslate",
        "argostranslate.package",
        "argostranslate.translate",
        "piper",
        "numpy"  # Mock numpy as well if needed, though usually available
    ]
    for module in modules:
        sys.modules[module] = MagicMock()

mock_dependencies()

from fastapi.testclient import TestClient
# We need to set pythonpath to include server directory if running from root
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from main import app

client = TestClient(app)

def test_create_room_dos():
    """
    Test that rapid room creation is rate limited.
    """
    # Number of requests to send
    # Adjust this number based on the rate limit we plan to implement (e.g., 5/minute)
    # We send 20 requests. If rate limited (5/min), we expect 5 successes and 15 failures.

    responses = []
    for i in range(20):
        response = client.post("/api/rooms", json={"name": f"Room {i}"})
        responses.append(response.status_code)

    # Check results
    success_count = responses.count(200)
    failure_count = responses.count(429)

    print(f"Success: {success_count}, Rate Limited: {failure_count}")

    # Assertions
    # We expect exactly 5 successes because the limit is 5/minute
    assert success_count == 5, f"Expected 5 successes, got {success_count}"
    assert failure_count == 15, f"Expected 15 failures, got {failure_count}"

    print("Test Passed: Rate limiting is active.")
    return success_count, failure_count

if __name__ == "__main__":
    test_create_room_dos()
