import sys
from unittest.mock import MagicMock, AsyncMock, patch

# Mock heavy dependencies before importing main or any service module
sys.modules["faster_whisper"] = MagicMock()
sys.modules["argostranslate"] = MagicMock()
sys.modules["argostranslate.package"] = MagicMock()
sys.modules["argostranslate.translate"] = MagicMock()
sys.modules["piper"] = MagicMock()

# Mock the service modules themselves to avoid importing their internal logic
# and to easily mock their functions.
sys.modules["stt_service"] = MagicMock()
sys.modules["translate_service"] = MagicMock()
sys.modules["tts_service"] = MagicMock()

import pytest
from server.main import process_audio, Room, User

@pytest.mark.asyncio
async def test_process_audio_flow():
    """
    Test the full flow of process_audio:
    1. STT is called.
    2. Translation is called for different language listeners.
    3. TTS is called for translated text.
    4. Audio is sent to listener.
    """
    # Setup mocks for services
    mock_stt = sys.modules["stt_service"]
    mock_translate = sys.modules["translate_service"]
    mock_tts = sys.modules["tts_service"]

    # Configure STT mock
    mock_stt.transcribe.return_value = {
        "text": "Hello world",
        "language": "en",
        "confidence": 0.99
    }

    # Configure Translate mock
    # translate(text, from_lang, to_lang)
    def translate_side_effect(text, from_lang, to_lang):
        if to_lang == "es":
            return "Hola mundo"
        return text
    mock_translate.translate.side_effect = translate_side_effect

    # Configure TTS mock
    mock_tts.synthesize.return_value = b"fake_audio_bytes"

    # Setup User and Room
    sender = User(id="sender1", name="Alice", language="en", websocket=AsyncMock())
    listener_es = User(id="listener1", name="Bob", language="es", websocket=AsyncMock())
    listener_en = User(id="listener2", name="Charlie", language="en", websocket=AsyncMock())

    room = Room(id="room1", name="Test Room")
    room.users = {
        sender.id: sender,
        listener_es.id: listener_es,
        listener_en.id: listener_en
    }

    audio_bytes = b"raw_audio_input"

    # Run process_audio
    await process_audio(room, sender, audio_bytes)

    # Verify STT called
    # Note: process_audio runs stt in executor, but since we mocked the function, we can check calls.
    # The executor runs `lambda: transcribe(...)`.
    # We can check if `transcribe` was called with correct args.
    mock_stt.transcribe.assert_called_once_with(audio_bytes, "en")

    # Verify sender received transcription
    sender.websocket.send_json.assert_called()
    call_args = sender.websocket.send_json.call_args[0][0]
    assert call_args["type"] == "transcription"
    assert call_args["text"] == "Hello world"

    # Verify Translation called for ES listener
    # translate is also run in executor.
    mock_translate.translate.assert_called_with("Hello world", "en", "es")

    # Verify TTS called for ES listener
    # synthesize is also run in executor.
    mock_tts.synthesize.assert_called_with("Hola mundo", "es")

    # Verify Audio sent to ES listener
    # Listener should receive metadata and then audio
    listener_es.websocket.send_json.assert_called()
    listener_es.websocket.send_bytes.assert_called_with(b"fake_audio_bytes")

    # Verify logic for EN listener (same language)
    # Logic: if target_lang == detected_lang, translate is NOT called (or rather, translation is skipped).
    # But TTS IS called? Let's check the code logic.
    # if target_lang != detected_lang: translate... else: translated = text
    # TTS is called with (translated, target_lang).
    # So for EN listener: translated="Hello world", target_lang="en".
    # TTS should be called with ("Hello world", "en").

    # Check if synthesize was called for 'en'
    # We can inspect all calls to synthesize
    synthesize_calls = mock_tts.synthesize.call_args_list
    # Expected calls: ("Hola mundo", "es") and ("Hello world", "en")

    # Extract args from calls
    args_list = [call[0] for call in synthesize_calls]
    assert ("Hola mundo", "es") in args_list
    assert ("Hello world", "en") in args_list

    # Verify Audio sent to EN listener
    listener_en.websocket.send_bytes.assert_called_with(b"fake_audio_bytes")
