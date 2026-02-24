"""
Zubia — Real-Time Audio Translation Chat Server
Main FastAPI application with WebSocket-based audio streaming and AI translation pipeline.
"""

import asyncio
import io
import wave
import uuid
import time
import logging
from pathlib import Path
from dataclasses import dataclass, field
from typing import Optional

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Request
from fastapi.responses import FileResponse, JSONResponse, RedirectResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(name)s] %(levelname)s: %(message)s"
)
logger = logging.getLogger("voxbridge")

# ---------------------------------------------------------------------------
# Application
# ---------------------------------------------------------------------------
app = FastAPI(title="Zubia", version="1.0.0")

# Rate Limiter
limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

@app.get("/")
async def serve_root():
    """Redirect root to the APK download endpoint."""
    return RedirectResponse(url="/download")


@app.get("/download")
async def download_apk():
    """Download the Flutter APK directly."""
    apk_path = Path(__file__).parent.parent / "zubia/build/app/outputs/flutter-apk/app-release.apk"
    if apk_path.exists():
        return FileResponse(
            path=str(apk_path),
            filename="Zubia-App.apk",
            media_type="application/vnd.android.package-archive"
        )
    return {"error": "APK not built yet"}


# ---------------------------------------------------------------------------
# Room & User Management
# ---------------------------------------------------------------------------
@dataclass
class User:
    id: str
    name: str
    language: str  # ISO code: 'en', 'es', 'fr', etc.
    websocket: WebSocket
    is_muted: bool = False


@dataclass
class Room:
    id: str
    name: str
    created_at: float = field(default_factory=time.time)
    users: dict[str, User] = field(default_factory=dict)

    @property
    def user_count(self) -> int:
        return len(self.users)


# Global room registry
rooms: dict[str, Room] = {}

# Processing lock per room to prevent overlapping translations
_room_locks: dict[str, asyncio.Lock] = {}


def get_room_lock(room_id: str) -> asyncio.Lock:
    if room_id not in _room_locks:
        _room_locks[room_id] = asyncio.Lock()
    return _room_locks[room_id]


# ---------------------------------------------------------------------------
# REST API Endpoints
# ---------------------------------------------------------------------------
@app.get("/api/languages")
async def get_languages():
    """Return supported languages."""
    from translate_service import get_supported_languages
    return JSONResponse(get_supported_languages())


@app.get("/api/rooms")
async def list_rooms():
    """List all active rooms."""
    return JSONResponse({
        rid: {
            "id": r.id,
            "name": r.name,
            "userCount": r.user_count,
            "createdAt": r.created_at,
        }
        for rid, r in rooms.items()
    })


@app.post("/api/rooms")
@limiter.limit("5/minute")
async def create_room(request: Request, data: dict = {}):
    """Create a new room."""
    room_id = str(uuid.uuid4())[:8]
    room_name = data.get("name", f"Room {room_id}")
    rooms[room_id] = Room(id=room_id, name=room_name)
    logger.info(f"Room created: {room_id} ({room_name})")
    return JSONResponse({"id": room_id, "name": room_name})


# ---------------------------------------------------------------------------
# WebSocket Audio Pipeline
# ---------------------------------------------------------------------------
@app.websocket("/ws/{room_id}")
async def websocket_endpoint(websocket: WebSocket, room_id: str):
    await websocket.accept()

    # Receive join message with user info
    try:
        join_msg = await asyncio.wait_for(websocket.receive_json(), timeout=10)
    except (asyncio.TimeoutError, Exception) as e:
        logger.error(f"Failed to receive join message: {e}")
        await websocket.close(code=4000, reason="Join timeout")
        return

    user_id = str(uuid.uuid4())[:8]
    user_name = join_msg.get("name", f"User-{user_id}")
    user_lang = join_msg.get("language", "en")

    # Create room if it doesn't exist
    if room_id not in rooms:
        rooms[room_id] = Room(id=room_id, name=f"Room {room_id}")

    room = rooms[room_id]
    user = User(id=user_id, name=user_name, language=user_lang, websocket=websocket)
    room.users[user_id] = user

    logger.info(f"User '{user_name}' ({user_lang}) joined room '{room_id}' [{room.user_count} users]")

    # Notify everyone about the new user
    await broadcast_system(room, {
        "type": "user_joined",
        "userId": user_id,
        "userName": user_name,
        "language": user_lang,
        "users": get_user_list(room),
    })

    # Send confirmation to the joining user
    await websocket.send_json({
        "type": "joined",
        "userId": user_id,
        "roomId": room_id,
        "roomName": room.name,
        "users": get_user_list(room),
    })

    try:
        while True:
            # Receive messages (can be JSON control messages or binary audio)
            message = await websocket.receive()

            if "text" in message:
                # JSON control message
                import json
                data = json.loads(message["text"])
                await handle_control_message(room, user, data)

            elif "bytes" in message:
                # Binary audio data
                audio_bytes = message["bytes"]
                if not user.is_muted and len(audio_bytes) > 100:
                    # Process audio in a background task to not block receiving
                    asyncio.create_task(
                        process_audio(room, user, audio_bytes)
                    )

    except WebSocketDisconnect:
        logger.info(f"User '{user_name}' disconnected from room '{room_id}'")
    except Exception as e:
        logger.error(f"WebSocket error for user '{user_name}': {e}")
    finally:
        # Clean up
        room.users.pop(user_id, None)
        await broadcast_system(room, {
            "type": "user_left",
            "userId": user_id,
            "userName": user_name,
            "users": get_user_list(room),
        })

        # Remove empty rooms
        if room.user_count == 0:
            rooms.pop(room_id, None)
            _room_locks.pop(room_id, None)
            logger.info(f"Room '{room_id}' removed (empty)")


async def handle_control_message(room: Room, user: User, data: dict):
    """Handle JSON control messages from clients."""
    msg_type = data.get("type")

    if msg_type == "mute":
        user.is_muted = True
        await broadcast_system(room, {
            "type": "user_muted",
            "userId": user.id,
            "userName": user.name,
        })

    elif msg_type == "unmute":
        user.is_muted = False
        await broadcast_system(room, {
            "type": "user_unmuted",
            "userId": user.id,
            "userName": user.name,
        })

    elif msg_type == "change_language":
        new_lang = data.get("language", user.language)
        user.language = new_lang
        await broadcast_system(room, {
            "type": "user_language_changed",
            "userId": user.id,
            "userName": user.name,
            "language": new_lang,
            "users": get_user_list(room),
        })
        logger.info(f"User '{user.name}' changed language to '{new_lang}'")


async def process_audio(room: Room, sender: User, audio_bytes: bytes):
    """
    Full AI translation pipeline:
    1. STT: audio -> text (in sender's language)
    2. For each listener with different language:
       a. Translate: text -> translated text
       b. TTS: translated text -> audio
       c. Send audio to listener
    """
    start_time = time.time()

    try:
        # Step 1: Speech-to-Text
        from stt_service import transcribe
        result = await asyncio.get_event_loop().run_in_executor(
            None, lambda: transcribe(audio_bytes, sender.language)
        )

        text = result["text"]
        detected_lang = result["language"]

        if not text.strip():
            return  # No speech detected

        logger.info(f"STT [{detected_lang}]: '{text}' (from {sender.name})")

        # Notify the sender about the transcription
        try:
            await sender.websocket.send_json({
                "type": "transcription",
                "text": text,
                "language": detected_lang,
            })
        except Exception:
            pass

        # Step 2: Translate and synthesize for each listener
        from translate_service import translate as translate_text
        from tts_service import synthesize

        # Group listeners by target language to avoid duplicate work
        lang_groups: dict[str, list[User]] = {}
        for uid, listener in room.users.items():
            if uid == sender.id:
                continue
            lang = listener.language
            if lang not in lang_groups:
                lang_groups[lang] = []
            lang_groups[lang].append(listener)

        async def process_group(target_lang, listeners):
            try:
                # Translate
                if target_lang != detected_lang:
                    translated = await asyncio.get_event_loop().run_in_executor(
                        None, lambda tl=target_lang: translate_text(text, detected_lang, tl)
                    )
                else:
                    translated = text

                logger.info(f"Translate [{detected_lang}->{target_lang}]: '{translated}'")

                # TTS
                tts_audio = await asyncio.get_event_loop().run_in_executor(
                    None, lambda tl=target_lang, tx=translated: synthesize(tx, tl)
                )

                # Send to all listeners with this language
                for listener in listeners:
                    try:
                        # Send metadata first
                        await listener.websocket.send_json({
                            "type": "translated_audio_meta",
                            "fromUser": sender.name,
                            "fromLanguage": detected_lang,
                            "toLanguage": target_lang,
                            "originalText": text,
                            "translatedText": translated,
                        })
                        # Then send audio bytes
                        await listener.websocket.send_bytes(tts_audio)
                    except Exception as e:
                        logger.error(f"Failed to send audio to {listener.name}: {e}")

            except Exception as e:
                logger.error(f"Pipeline failed for lang {target_lang}: {e}")

        # Process all language groups in parallel
        await asyncio.gather(*(
            process_group(lang, listeners)
            for lang, listeners in lang_groups.items()
        ))

        elapsed = time.time() - start_time
        logger.info(f"Pipeline completed in {elapsed:.2f}s for {sender.name}")

    except Exception as e:
        logger.error(f"Audio processing error: {e}", exc_info=True)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def get_user_list(room: Room) -> list[dict]:
    """Get list of users in a room for broadcasting."""
    return [
        {
            "id": u.id,
            "name": u.name,
            "language": u.language,
            "isMuted": u.is_muted,
        }
        for u in room.users.values()
    ]


async def broadcast_system(room: Room, message: dict):
    """Broadcast a system message to all users in a room."""
    disconnected = []
    for uid, user in room.users.items():
        try:
            await user.websocket.send_json(message)
        except Exception:
            disconnected.append(uid)

    for uid in disconnected:
        room.users.pop(uid, None)


# ---------------------------------------------------------------------------
# Startup
# ---------------------------------------------------------------------------
@app.on_event("startup")
async def startup_event():
    logger.info("=" * 60)
    logger.info("  Zubia — Real-Time Audio Translation Chat")
    logger.info("=" * 60)
    logger.info("Loading AI models... (this may take a minute on first run)")

    # Pre-load the STT model in background
    async def preload():
        from stt_service import get_model
        await asyncio.get_event_loop().run_in_executor(None, get_model)
        logger.info("STT model loaded.")

    asyncio.create_task(preload())


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
