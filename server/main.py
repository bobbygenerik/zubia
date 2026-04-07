"""
Zubia — Real-Time Audio Translation Chat Server
Main FastAPI application with WebSocket-based audio streaming and AI translation pipeline.
"""

import asyncio
import uuid
import time
import logging
import os
from pathlib import Path
from dataclasses import dataclass, field

import json
import uvicorn
from stt_service import transcribe, get_model
from translate_service import translate as translate_text, get_supported_languages
from tts_service import synthesize
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse, RedirectResponse
from pydantic import ValidationError

from schemas import RoomCreate, UserJoin, UserRegister, ThreadCreate

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(name)s] %(levelname)s: %(message)s"
)
logger = logging.getLogger("voxbridge")

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
APK_PATH = Path(
    os.getenv(
        "APK_PATH",
        Path(__file__).parent.parent / "zubia/build/app/outputs/flutter-apk/app-release.apk"
    )
)


# ---------------------------------------------------------------------------
# Application
# ---------------------------------------------------------------------------
app = FastAPI(title="Zubia", version="1.0.0")

# Allow browser clients (Flutter web) to call the API from another origin.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def serve_root():
    """Redirect root to the APK download endpoint."""
    return RedirectResponse(url="/download")


@app.get("/download")
async def download_apk():
    """Download the Flutter APK directly."""
    if APK_PATH.exists():
        return FileResponse(
            path=str(APK_PATH),
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
    _dict: dict = field(init=False, default=None)

    def get_dict(self) -> dict:
        if self._dict is None:
            self._dict = {
                "id": self.id,
                "name": self.name,
                "language": self.language,
                "isMuted": self.is_muted,
            }
        return self._dict

    def clear_cache(self):
        self._dict = None


@dataclass
class Room:
    id: str
    name: str
    created_at: float = field(default_factory=time.time)
    users: dict[str, User] = field(default_factory=dict)

    @property
    def user_count(self) -> int:
        return len(self.users)


# Global registries
rooms: dict[str, Room] = {}
users_db: dict[str, dict] = {}           # userId -> {id, name, language}
users_name_lower: dict[str, str] = {}    # userId -> name.lower()
threads_db: dict[str, dict] = {}         # threadKey -> {id, user1_id, user2_id}
user_threads: dict[str, list[str]] = {}  # userId -> [threadKey, ...]


def _thread_key(user1_id: str, user2_id: str) -> str:
    return '_'.join(sorted([user1_id, user2_id]))



# ---------------------------------------------------------------------------
# REST API Endpoints
# ---------------------------------------------------------------------------
@app.get("/api/languages")
async def get_languages():
    """Return supported languages."""
    return JSONResponse(get_supported_languages())


@app.post("/api/rooms")
async def create_room(data: RoomCreate):
    """Create a new room."""
    room_id = str(uuid.uuid4())[:8]
    room_name = data.name if data.name else f"Room {room_id}"
    rooms[room_id] = Room(id=room_id, name=room_name)
    logger.info(f"Room created: {room_id} ({room_name})")
    return JSONResponse({"id": room_id, "name": room_name})


@app.post("/api/users/register")
async def register_user(data: UserRegister):
    """Register a new user."""
    user_id = str(uuid.uuid4())[:8]
    users_db[user_id] = {"id": user_id, "name": data.name, "language": data.language}
    users_name_lower[user_id] = data.name.lower()
    logger.info(f"User registered: {data.name} ({user_id})")
    return JSONResponse({"id": user_id, "name": data.name, "language": data.language})


@app.get("/api/users/{user_id}")
async def get_user(user_id: str):
    """Get a user by ID."""
    user = users_db.get(user_id)
    if not user:
        return JSONResponse({"error": "User not found"}, status_code=404)
    return JSONResponse(user)


@app.get("/api/users")
async def search_users(name: str = ""):
    """Search users by name (substring match)."""
    name_lower = name.lower().strip()
    if not name_lower:
        results = list(users_db.values())
    else:
        results = [users_db[uid] for uid, uname_lower in users_name_lower.items() if name_lower in uname_lower]
    return JSONResponse(results)


@app.post("/api/threads")
async def create_thread(data: ThreadCreate):
    """Create or retrieve an existing thread between two users."""
    if data.user1_id not in users_db or data.user2_id not in users_db:
        return JSONResponse({"error": "User not found"}, status_code=404)

    key = _thread_key(data.user1_id, data.user2_id)
    if key in threads_db:
        return JSONResponse({"id": threads_db[key]["id"], "existing": True})

    threads_db[key] = {"id": key, "user1_id": data.user1_id, "user2_id": data.user2_id}
    for uid in [data.user1_id, data.user2_id]:
        user_threads.setdefault(uid, []).append(key)

    # Pre-create the room so the WebSocket endpoint finds it
    rooms[key] = Room(id=key, name=key)
    logger.info(f"Thread created: {key}")
    return JSONResponse({"id": key, "existing": False})


@app.get("/api/threads/{user_id}")
async def get_threads(user_id: str):
    """List all threads for a user."""
    if user_id not in users_db:
        return JSONResponse({"error": "User not found"}, status_code=404)

    result = []
    for key in user_threads.get(user_id, []):
        thread = threads_db.get(key)
        if not thread:
            continue
        other_id = thread["user2_id"] if thread["user1_id"] == user_id else thread["user1_id"]
        other = users_db.get(other_id)
        if other:
            result.append({
                "id": thread["id"],
                "otherUserId": other_id,
                "otherUserName": other["name"],
                "otherUserLanguage": other["language"],
            })
    return JSONResponse(result)


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

    try:
        user_data = UserJoin(**join_msg)
        stored = users_db.get(user_data.userId)
        if stored is None:
            await websocket.close(code=4001, reason="Unknown user")
            return
        user_id = user_data.userId
        user_name = stored["name"]
        user_lang = stored["language"]
    except ValidationError as e:
        logger.error(f"Invalid join message: {e}")
        await websocket.close(code=4002, reason="Invalid join data")
        return

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
            logger.info(f"Room '{room_id}' removed (empty)")


async def handle_control_message(room: Room, user: User, data: dict):
    """Handle JSON control messages from clients."""
    msg_type = data.get("type")

    if msg_type == "mute":
        user.is_muted = True
        user.clear_cache()
        await broadcast_system(room, {
            "type": "user_muted",
            "userId": user.id,
            "userName": user.name,
            "users": get_user_list(room),
        })

    elif msg_type == "unmute":
        user.is_muted = False
        user.clear_cache()
        await broadcast_system(room, {
            "type": "user_unmuted",
            "userId": user.id,
            "userName": user.name,
            "users": get_user_list(room),
        })

    elif msg_type == "change_language":
        new_lang = data.get("language", user.language)
        user.language = new_lang
        if user.id in users_db:
            users_db[user.id]["language"] = new_lang
        user.clear_cache()
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
        result = await asyncio.get_event_loop().run_in_executor(
            None, lambda: transcribe(audio_bytes, sender.language)
        )

        text = result["text"]
        detected_lang = result["language"]

        if not text.strip():
            return  # No speech detected

        logger.info(f"STT [{detected_lang}] for {sender.name}")

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

                logger.info(f"Translate [{detected_lang}->{target_lang}]")

                # TTS
                tts_audio = await asyncio.get_event_loop().run_in_executor(
                    None, lambda tl=target_lang, tx=translated: synthesize(tx, tl)
                )

                # Send to all listeners with this language concurrently
                async def send_to_listener(listener):
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

                await asyncio.gather(*(send_to_listener(l) for l in listeners))

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
        u.get_dict()
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
        await asyncio.get_event_loop().run_in_executor(None, get_model)
        logger.info("STT model loaded.")

    asyncio.create_task(preload())


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
