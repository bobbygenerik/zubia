# Zubia — Real-Time Audio Translation Chat

> Speak your language. Hear theirs.

Zubia is a self-hosted, real-time audio translation chat app. Users speak in their own language and hear other participants in their chosen language — powered entirely by open-source AI models running locally on your server.

![Python](https://img.shields.io/badge/Python-3.10+-blue?logo=python)
![FastAPI](https://img.shields.io/badge/FastAPI-WebSocket-009688?logo=fastapi)
![License](https://img.shields.io/badge/License-MIT-green)

## ✨ Features

- **🎙️ Real-time Mode** — Continuous audio streaming with live translation
- **📻 Walkie-talkie Mode** — Push-to-talk for cleaner, full-message translations
- **🌍 10 Languages** — English, Spanish, French, German, Chinese, Japanese, Arabic, Portuguese, Russian, Korean
- **🔒 Fully Self-Hosted** — No external APIs. All AI runs on your server
- **💻 CPU-Only** — No GPU required (optimized for CPU inference)
- **🎨 Premium UI** — Dark glassmorphism design with animated visualizers

## 🏗️ Architecture

```
Browser (mic) → WebSocket → FastAPI Server
                              ├── faster-whisper (STT)
                              ├── Argos Translate (Translation)
                              └── Piper TTS (Speech Synthesis)
                            → WebSocket → Browser (speaker)
```

## 🚀 Quick Start

### Prerequisites
- Python 3.10+
- ~4GB disk for AI models (auto-downloaded on first use)

### Setup

```bash
# Clone the repo
git clone https://github.com/bobbygenerik/zubia.git
cd zubia

# Create virtual environment
python3 -m venv server/venv
source server/venv/bin/activate

# Install dependencies
pip install -r server/requirements.txt

# Run the server
cd server
uvicorn main:app --host 0.0.0.0 --port 8000
```

Open `http://localhost:8000` in your browser.

### Usage

1. Enter your name and select your language
2. Create a room or join with a room code
3. Toggle between **Real-time** or **Walkie-talkie** mode
4. Click (or hold) the mic button and speak!

## 🧠 AI Stack

| Component | Model | Size |
|-----------|-------|------|
| Speech-to-Text | [faster-whisper](https://github.com/SYSTRAN/faster-whisper) (small, int8) | ~500MB |
| Translation | [Argos Translate](https://github.com/argosopentech/argos-translate) | ~50MB/pair |
| Text-to-Speech | [Piper TTS](https://github.com/rhasspy/piper) | ~60MB/voice |

## ⚡ Performance

- **Latency**: ~2-3s per translation cycle on CPU
- **Concurrent streams**: 2-4 on an 8-core CPU
- **First use**: ~30s extra while models download

## 📄 License

MIT
