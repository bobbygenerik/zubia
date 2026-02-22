/**
 * Zubia — Client Application
 * Handles WebSocket audio streaming, mic capture, playback, and UI state.
 * Supports two modes: Real-time (continuous) and Walkie-talkie (push-to-talk).
 */

// ============================================================
// State
// ============================================================
const state = {
    userId: null,
    userName: '',
    userLanguage: 'en',
    roomId: null,
    roomName: '',
    users: [],
    isRecording: false,
    isMuted: false,
    volume: 0.8,
    ws: null,
    mediaRecorder: null,
    audioContext: null,
    analyserNode: null,
    micStream: null,
    languages: {},
    mode: 'realtime', // 'realtime' or 'walkie'
};

// ============================================================
// DOM Elements
// ============================================================
const $ = (sel) => document.querySelector(sel);
const dom = {
    // Screens
    lobbyScreen: $('#lobby-screen'),
    chatScreen: $('#chat-screen'),
    connectingOverlay: $('#connecting-overlay'),
    connectingText: $('#connecting-text'),

    // Lobby
    userName: $('#user-name'),
    userLanguage: $('#user-language'),
    roomCode: $('#room-code'),
    btnJoin: $('#btn-join-room'),
    btnCreate: $('#btn-create-room'),
    roomList: $('#room-list'),

    // Chat
    roomNameDisplay: $('#room-name-display'),
    roomIdDisplay: $('#room-id-display'),
    languageSwitcher: $('#language-switcher'),
    btnLeave: $('#btn-leave'),
    participantList: $('#participant-list'),
    participantCount: $('#participant-count'),
    translationFeed: $('#translation-feed'),
    btnMic: $('#btn-mic'),
    volumeSlider: $('#volume-slider'),
    statusIndicator: $('#status-indicator'),
    statusText: $('#status-text'),
    audioVisualizer: $('#audio-visualizer'),
    micHint: $('#mic-hint'),

    // Mode toggle
    modeToggle: $('#mode-toggle'),
    modeRealtime: $('#mode-realtime'),
    modeWalkie: $('#mode-walkie'),
};

// ============================================================
// Initialization
// ============================================================
async function init() {
    await loadLanguages();
    setupEventListeners();
    refreshRoomList();
    setInterval(refreshRoomList, 5000);
    initVisualizer();
    updateModeUI();
}

async function loadLanguages() {
    try {
        const res = await fetch('/api/languages');
        state.languages = await res.json();
    } catch {
        state.languages = {
            en: 'English', es: 'Spanish', fr: 'French',
            de: 'German', zh: 'Chinese', ja: 'Japanese',
            ar: 'Arabic', pt: 'Portuguese', ru: 'Russian', ko: 'Korean',
        };
    }

    [dom.userLanguage, dom.languageSwitcher].forEach(select => {
        select.innerHTML = '';
        for (const [code, name] of Object.entries(state.languages)) {
            const opt = document.createElement('option');
            opt.value = code;
            opt.textContent = `${getFlagEmoji(code)} ${name}`;
            select.appendChild(opt);
        }
    });
}

function getFlagEmoji(langCode) {
    const flags = {
        en: '🇺🇸', es: '🇪🇸', fr: '🇫🇷', de: '🇩🇪', zh: '🇨🇳',
        ja: '🇯🇵', ar: '🇸🇦', pt: '🇵🇹', ru: '🇷🇺', ko: '🇰🇷',
    };
    return flags[langCode] || '🌍';
}

function setupEventListeners() {
    // Lobby
    dom.userName.addEventListener('input', validateJoinForm);
    dom.roomCode.addEventListener('input', validateJoinForm);
    dom.btnJoin.addEventListener('click', joinRoom);
    dom.btnCreate.addEventListener('click', createRoom);
    dom.roomCode.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !dom.btnJoin.disabled) joinRoom();
    });

    // Chat
    dom.btnLeave.addEventListener('click', leaveRoom);
    dom.volumeSlider.addEventListener('input', (e) => {
        state.volume = e.target.value / 100;
    });
    dom.languageSwitcher.addEventListener('change', (e) => {
        state.userLanguage = e.target.value;
        if (state.ws && state.ws.readyState === WebSocket.OPEN) {
            state.ws.send(JSON.stringify({
                type: 'change_language',
                language: state.userLanguage,
            }));
        }
    });

    // Mode toggle
    dom.modeRealtime.addEventListener('click', () => setMode('realtime'));
    dom.modeWalkie.addEventListener('click', () => setMode('walkie'));

    // Mic button — different behavior per mode
    dom.btnMic.addEventListener('click', onMicClick);
    dom.btnMic.addEventListener('mousedown', onMicDown);
    dom.btnMic.addEventListener('mouseup', onMicUp);
    dom.btnMic.addEventListener('mouseleave', onMicUp);
    // Touch support for mobile walkie-talkie
    dom.btnMic.addEventListener('touchstart', onMicDown, { passive: true });
    dom.btnMic.addEventListener('touchend', onMicUp);
    dom.btnMic.addEventListener('touchcancel', onMicUp);
}

function validateJoinForm() {
    const nameOk = dom.userName.value.trim().length > 0;
    const codeOk = dom.roomCode.value.trim().length > 0;
    dom.btnJoin.disabled = !(nameOk && codeOk);
}

// ============================================================
// Mode Management
// ============================================================
function setMode(mode) {
    // If currently recording, stop first
    if (state.isRecording) {
        stopRecording();
    }

    state.mode = mode;
    updateModeUI();
}

function updateModeUI() {
    const isWalkie = state.mode === 'walkie';

    // Toggle button active states
    dom.modeRealtime.classList.toggle('active', !isWalkie);
    dom.modeWalkie.classList.toggle('active', isWalkie);
    dom.modeToggle.classList.toggle('walkie', isWalkie);

    // Update mic button appearance
    dom.btnMic.classList.toggle('walkie-mode', isWalkie);

    // Update hint text
    if (isWalkie) {
        dom.micHint.textContent = 'Hold to talk, release to send';
        dom.btnMic.title = 'Hold to talk';
    } else {
        dom.micHint.textContent = state.isRecording ? 'Click to stop streaming' : 'Click to start streaming';
        dom.btnMic.title = state.isRecording ? 'Click to stop' : 'Click to speak';
    }
}

// ============================================================
// Mic Button Handlers (mode-aware)
// ============================================================
let walkieMouseDown = false;

function onMicClick(e) {
    // In real-time mode, toggle recording on click
    if (state.mode === 'realtime') {
        toggleRecording();
    }
    // Walkie-talkie is handled by mousedown/mouseup, not click
}

function onMicDown(e) {
    if (state.mode !== 'walkie') return;
    e.preventDefault();
    walkieMouseDown = true;
    startWalkieRecording();
}

function onMicUp(e) {
    if (state.mode !== 'walkie') return;
    if (!walkieMouseDown) return;
    walkieMouseDown = false;
    stopWalkieRecording();
}

// ============================================================
// Room Management
// ============================================================
async function refreshRoomList() {
    try {
        const res = await fetch('/api/rooms');
        const rooms = await res.json();
        renderRoomList(rooms);
    } catch { /* ignore */ }
}

function renderRoomList(rooms) {
    const entries = Object.values(rooms);
    if (entries.length === 0) {
        dom.roomList.innerHTML = '<div class="room-list-empty">No active rooms. Create one!</div>';
        return;
    }

    dom.roomList.innerHTML = entries.map(r => `
        <div class="room-item" data-room-id="${r.id}" onclick="quickJoin('${r.id}')">
            <div class="room-item-info">
                <span class="room-item-name">${escapeHtml(r.name)}</span>
                <span class="room-item-id">${r.id}</span>
            </div>
            <div class="room-item-users">
                <span class="dot"></span>
                ${r.userCount} user${r.userCount !== 1 ? 's' : ''}
            </div>
        </div>
    `).join('');
}

window.quickJoin = function (roomId) {
    dom.roomCode.value = roomId;
    validateJoinForm();
    if (dom.userName.value.trim()) {
        joinRoom();
    } else {
        dom.userName.focus();
    }
};

async function createRoom() {
    if (!dom.userName.value.trim()) {
        dom.userName.focus();
        return;
    }

    try {
        const res = await fetch('/api/rooms', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name: `${dom.userName.value.trim()}'s Room` }),
        });
        const room = await res.json();
        dom.roomCode.value = room.id;
        joinRoom();
    } catch (err) {
        console.error('Failed to create room:', err);
    }
}

async function joinRoom() {
    state.userName = dom.userName.value.trim();
    state.userLanguage = dom.userLanguage.value;
    state.roomId = dom.roomCode.value.trim();

    if (!state.userName || !state.roomId) return;

    showOverlay('Connecting to room...');
    connectWebSocket();
}

function leaveRoom() {
    stopRecording();
    if (state.ws) {
        state.ws.close();
        state.ws = null;
    }
    if (state.micStream) {
        state.micStream.getTracks().forEach(t => t.stop());
        state.micStream = null;
    }
    switchScreen('lobby');
    refreshRoomList();
}

// ============================================================
// WebSocket Connection
// ============================================================
function connectWebSocket() {
    const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${location.host}/ws/${state.roomId}`;

    state.ws = new WebSocket(wsUrl);
    state.ws.binaryType = 'arraybuffer';

    let pendingAudioMeta = null;

    state.ws.onopen = () => {
        state.ws.send(JSON.stringify({
            name: state.userName,
            language: state.userLanguage,
        }));
    };

    state.ws.onmessage = (event) => {
        if (typeof event.data === 'string') {
            const msg = JSON.parse(event.data);
            handleServerMessage(msg);
            if (msg.type === 'translated_audio_meta') {
                pendingAudioMeta = msg;
            }
        } else {
            playAudio(event.data, pendingAudioMeta);
            pendingAudioMeta = null;
        }
    };

    state.ws.onclose = () => {
        setStatus('disconnected', 'Disconnected');
    };

    state.ws.onerror = (err) => {
        console.error('WebSocket error:', err);
        hideOverlay();
    };
}

function handleServerMessage(msg) {
    switch (msg.type) {
        case 'joined':
            state.userId = msg.userId;
            state.roomName = msg.roomName;
            state.roomId = msg.roomId;
            state.users = msg.users;
            enterChatRoom();
            break;

        case 'user_joined':
            state.users = msg.users;
            updateParticipants();
            addFeedSystem(`${msg.userName} joined (${state.languages[msg.language] || msg.language})`);
            break;

        case 'user_left':
            state.users = msg.users;
            updateParticipants();
            addFeedSystem(`${msg.userName} left`);
            break;

        case 'user_muted':
        case 'user_unmuted':
            state.users = msg.users || state.users;
            updateParticipants();
            break;

        case 'user_language_changed':
            state.users = msg.users;
            updateParticipants();
            break;

        case 'transcription':
            addFeedTranscription('You', msg.text, msg.language);
            break;

        case 'translated_audio_meta':
            addFeedTranslation(msg);
            break;
    }
}

function enterChatRoom() {
    hideOverlay();
    switchScreen('chat');
    dom.roomNameDisplay.textContent = state.roomName;
    dom.roomIdDisplay.textContent = state.roomId;
    dom.languageSwitcher.value = state.userLanguage;
    updateParticipants();
    setStatus('connected', 'Connected');
    clearFeed();

    const modeHint = state.mode === 'walkie'
        ? 'Hold the mic button to talk, release to send.'
        : 'Click the mic button to start streaming.';
    addFeedSystem(`You joined the room. ${modeHint}`);
}

// ============================================================
// Real-time Mode Recording (continuous 4s chunks)
// ============================================================
async function toggleRecording() {
    if (state.isRecording) {
        stopRecording();
    } else {
        await startRealtimeRecording();
    }
}

async function startRealtimeRecording() {
    try {
        state.micStream = await navigator.mediaDevices.getUserMedia({
            audio: {
                echoCancellation: true,
                noiseSuppression: true,
                sampleRate: 16000,
            }
        });

        setupAnalyser();

        const mimeType = getAudioMimeType();
        state.mediaRecorder = new MediaRecorder(state.micStream, {
            mimeType,
            audioBitsPerSecond: 64000,
        });

        let chunks = [];
        state.mediaRecorder.ondataavailable = (e) => {
            if (e.data.size > 0) chunks.push(e.data);
        };

        state.mediaRecorder.onstop = async () => {
            if (chunks.length === 0) return;
            const blob = new Blob(chunks, { type: mimeType });
            chunks = [];
            await sendAudioBlob(blob);
        };

        state.mediaRecorder.start();
        state.isRecording = true;
        dom.btnMic.classList.add('recording');
        setStatus('recording', 'Streaming...');
        updateModeUI();

        // Restart every 4 seconds for chunked sending
        state._recordingInterval = setInterval(() => {
            if (state.mediaRecorder && state.mediaRecorder.state === 'recording') {
                state.mediaRecorder.stop();
                setTimeout(() => {
                    if (state.isRecording && state.mediaRecorder) {
                        chunks = [];
                        state.mediaRecorder.start();
                    }
                }, 50);
            }
        }, 4000);

    } catch (err) {
        console.error('Failed to start recording:', err);
        addFeedSystem('⚠️ Microphone access denied. Please allow microphone access.');
    }
}

// ============================================================
// Walkie-talkie Mode Recording (hold to talk)
// ============================================================
async function startWalkieRecording() {
    try {
        state.micStream = await navigator.mediaDevices.getUserMedia({
            audio: {
                echoCancellation: true,
                noiseSuppression: true,
                sampleRate: 16000,
            }
        });

        setupAnalyser();

        const mimeType = getAudioMimeType();
        state.mediaRecorder = new MediaRecorder(state.micStream, {
            mimeType,
            audioBitsPerSecond: 64000,
        });

        let chunks = [];
        state.mediaRecorder.ondataavailable = (e) => {
            if (e.data.size > 0) chunks.push(e.data);
        };

        state.mediaRecorder.onstop = async () => {
            if (chunks.length === 0) return;
            const blob = new Blob(chunks, { type: mimeType });
            chunks = [];
            setStatus('processing', 'Translating...');
            await sendAudioBlob(blob);
            setTimeout(() => {
                if (!state.isRecording) setStatus('connected', 'Ready');
            }, 5000);
        };

        state.mediaRecorder.start();
        state.isRecording = true;
        dom.btnMic.classList.add('recording');
        setStatus('recording', 'Listening... Release to send');

    } catch (err) {
        console.error('Failed to start walkie recording:', err);
        addFeedSystem('⚠️ Microphone access denied. Please allow microphone access.');
    }
}

function stopWalkieRecording() {
    if (!state.isRecording) return;

    state.isRecording = false;
    dom.btnMic.classList.remove('recording');

    if (state.mediaRecorder && state.mediaRecorder.state !== 'inactive') {
        state.mediaRecorder.stop();
    }

    if (state.micStream) {
        state.micStream.getTracks().forEach(t => t.stop());
        state.micStream = null;
    }

    teardownAnalyser();
}

// ============================================================
// Shared Recording Helpers
// ============================================================
function setupAnalyser() {
    state.audioContext = new (window.AudioContext || window.webkitAudioContext)();
    const source = state.audioContext.createMediaStreamSource(state.micStream);
    state.analyserNode = state.audioContext.createAnalyser();
    state.analyserNode.fftSize = 256;
    source.connect(state.analyserNode);
}

function teardownAnalyser() {
    if (state.audioContext) {
        state.audioContext.close();
        state.audioContext = null;
        state.analyserNode = null;
    }
}

function getAudioMimeType() {
    return MediaRecorder.isTypeSupported('audio/webm;codecs=opus')
        ? 'audio/webm;codecs=opus'
        : 'audio/webm';
}

function stopRecording() {
    state.isRecording = false;
    dom.btnMic.classList.remove('recording');

    if (state._recordingInterval) {
        clearInterval(state._recordingInterval);
        state._recordingInterval = null;
    }

    if (state.mediaRecorder && state.mediaRecorder.state !== 'inactive') {
        state.mediaRecorder.stop();
    }

    if (state.micStream) {
        state.micStream.getTracks().forEach(t => t.stop());
        state.micStream = null;
    }

    teardownAnalyser();
    setStatus('connected', 'Ready');
    updateModeUI();
}

async function sendAudioBlob(blob) {
    const wavBytes = await blobToWav(blob);
    if (wavBytes && state.ws && state.ws.readyState === WebSocket.OPEN) {
        state.ws.send(wavBytes);
    }
}

// ============================================================
// Audio Conversion: WebM/Opus → WAV
// ============================================================
async function blobToWav(blob) {
    try {
        const audioContext = new (window.AudioContext || window.webkitAudioContext)({
            sampleRate: 16000,
        });
        const arrayBuffer = await blob.arrayBuffer();
        const audioBuffer = await audioContext.decodeAudioData(arrayBuffer);

        const pcmData = audioBuffer.getChannelData(0);
        const sampleRate = audioBuffer.sampleRate;

        const int16 = new Int16Array(pcmData.length);
        for (let i = 0; i < pcmData.length; i++) {
            const s = Math.max(-1, Math.min(1, pcmData[i]));
            int16[i] = s < 0 ? s * 0x8000 : s * 0x7FFF;
        }

        const wavHeader = createWavHeader(int16.length, sampleRate, 1, 16);
        const wavBytes = new Uint8Array(wavHeader.byteLength + int16.byteLength);
        wavBytes.set(new Uint8Array(wavHeader), 0);
        wavBytes.set(new Uint8Array(int16.buffer), wavHeader.byteLength);

        audioContext.close();
        return wavBytes.buffer;
    } catch (err) {
        console.error('WAV conversion failed:', err);
        return null;
    }
}

function createWavHeader(numSamples, sampleRate, numChannels, bitsPerSample) {
    const byteRate = sampleRate * numChannels * bitsPerSample / 8;
    const blockAlign = numChannels * bitsPerSample / 8;
    const dataSize = numSamples * numChannels * bitsPerSample / 8;
    const buffer = new ArrayBuffer(44);
    const view = new DataView(buffer);

    writeString(view, 0, 'RIFF');
    view.setUint32(4, 36 + dataSize, true);
    writeString(view, 8, 'WAVE');
    writeString(view, 12, 'fmt ');
    view.setUint32(16, 16, true);
    view.setUint16(20, 1, true);
    view.setUint16(22, numChannels, true);
    view.setUint32(24, sampleRate, true);
    view.setUint32(28, byteRate, true);
    view.setUint16(32, blockAlign, true);
    view.setUint16(34, bitsPerSample, true);
    writeString(view, 36, 'data');
    view.setUint32(40, dataSize, true);

    return buffer;
}

function writeString(view, offset, str) {
    for (let i = 0; i < str.length; i++) {
        view.setUint8(offset + i, str.charCodeAt(i));
    }
}

// ============================================================
// Audio Playback
// ============================================================
const audioQueue = [];
let isPlaying = false;

function playAudio(arrayBuffer, meta) {
    audioQueue.push({ buffer: arrayBuffer, meta });
    if (!isPlaying) processAudioQueue();
}

async function processAudioQueue() {
    if (audioQueue.length === 0) {
        isPlaying = false;
        return;
    }

    isPlaying = true;
    const { buffer } = audioQueue.shift();

    try {
        const audioContext = new (window.AudioContext || window.webkitAudioContext)();
        const audioBuffer = await audioContext.decodeAudioData(buffer.slice(0));

        const source = audioContext.createBufferSource();
        const gainNode = audioContext.createGain();
        gainNode.gain.value = state.volume;

        source.buffer = audioBuffer;
        source.connect(gainNode);
        gainNode.connect(audioContext.destination);

        source.onended = () => {
            audioContext.close();
            processAudioQueue();
        };

        source.start(0);
    } catch (err) {
        console.error('Audio playback error:', err);
        processAudioQueue();
    }
}

// ============================================================
// Audio Visualizer
// ============================================================
let animFrameId = null;

function initVisualizer() {
    const canvas = dom.audioVisualizer;
    const ctx = canvas.getContext('2d');

    function resize() {
        const rect = canvas.parentElement.getBoundingClientRect();
        canvas.width = rect.width;
        canvas.height = 60;
    }
    resize();
    window.addEventListener('resize', resize);

    function draw() {
        animFrameId = requestAnimationFrame(draw);
        const W = canvas.width;
        const H = canvas.height;

        ctx.clearRect(0, 0, W, H);

        if (state.analyserNode) {
            const bufferLength = state.analyserNode.frequencyBinCount;
            const dataArray = new Uint8Array(bufferLength);
            state.analyserNode.getByteFrequencyData(dataArray);

            const barWidth = Math.max(2, (W / bufferLength) * 2);
            const gap = 1;
            let x = 0;

            for (let i = 0; i < bufferLength; i++) {
                const barHeight = (dataArray[i] / 255) * H * 0.9;
                // Walkie mode gets amber/orange bars, real-time gets violet/cyan
                const hue = state.mode === 'walkie'
                    ? 30 + (i / bufferLength) * 20   // Amber range
                    : 290 + (i / bufferLength) * 40;   // Magenta/pink range
                ctx.fillStyle = `hsla(${hue}, 80%, 65%, 0.8)`;
                ctx.fillRect(x, H - barHeight, barWidth - gap, barHeight);
                x += barWidth;
                if (x > W) break;
            }
        } else {
            const time = Date.now() / 1000;
            ctx.beginPath();
            ctx.strokeStyle = 'rgba(255, 0, 255, 0.15)';
            ctx.lineWidth = 2;
            for (let x = 0; x < W; x++) {
                const y = H / 2 + Math.sin(x * 0.02 + time) * 8 + Math.sin(x * 0.01 + time * 0.5) * 4;
                if (x === 0) ctx.moveTo(x, y);
                else ctx.lineTo(x, y);
            }
            ctx.stroke();
        }
    }
    draw();
}

// ============================================================
// UI Updates
// ============================================================
function switchScreen(screen) {
    dom.lobbyScreen.classList.toggle('active', screen === 'lobby');
    dom.chatScreen.classList.toggle('active', screen === 'chat');

    // Hide bottom nav in chat room, show in lobby
    const lobbyNav = document.getElementById('lobby-nav');
    if (lobbyNav) {
        lobbyNav.style.display = screen === 'chat' ? 'none' : 'flex';
    }
}

function showOverlay(text) {
    dom.connectingText.textContent = text;
    dom.connectingOverlay.style.display = 'flex';
}

function hideOverlay() {
    dom.connectingOverlay.style.display = 'none';
}

function setStatus(type, text) {
    dom.statusIndicator.className = `status-indicator ${type}`;
    dom.statusText.textContent = text;
}

function updateParticipants() {
    dom.participantCount.textContent = state.users.length;

    dom.participantList.innerHTML = state.users.map(u => {
        const isYou = u.id === state.userId;
        const initial = u.name.charAt(0).toUpperCase();
        const langName = state.languages[u.language] || u.language;
        const flag = getFlagEmoji(u.language);

        return `
            <li class="participant-item ${isYou ? 'is-you' : ''}">
                <div class="participant-avatar">
                    <div class="avatar-speaking-ring"></div>
                    ${initial}
                </div>
                <div class="participant-info">
                    <div class="participant-name">${escapeHtml(u.name)}${isYou ? ' (you)' : ''}</div>
                    <div class="participant-lang">${flag} ${langName}</div>
                </div>
                ${u.isMuted ? '<svg class="participant-muted-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="1" y1="1" x2="23" y2="23"/><path d="M9 9v3a3 3 0 005.12 2.12"/></svg>' : ''}
            </li>
        `;
    }).join('');
}

// ============================================================
// Translation Feed
// ============================================================
function clearFeed() {
    dom.translationFeed.innerHTML = '';
}

function addFeedSystem(text) {
    const div = document.createElement('div');
    div.className = 'feed-item';
    div.innerHTML = `
        <div class="feed-item-avatar" style="background: var(--bg-tertiary); font-size: 1rem;">⚡</div>
        <div class="feed-item-content">
            <div class="feed-item-translated" style="color: var(--text-secondary); font-size: 0.85rem;">${escapeHtml(text)}</div>
        </div>
    `;
    dom.translationFeed.appendChild(div);
    dom.translationFeed.scrollTop = dom.translationFeed.scrollHeight;
}

function addFeedTranscription(fromName, text, language) {
    const flag = getFlagEmoji(language);
    const div = document.createElement('div');
    div.className = 'feed-item';
    div.innerHTML = `
        <div class="feed-item-avatar">${fromName.charAt(0).toUpperCase()}</div>
        <div class="feed-item-content">
            <div class="feed-item-header">
                <span class="feed-item-name">${escapeHtml(fromName)}</span>
                <span class="feed-item-langs">${flag} ${language.toUpperCase()}</span>
            </div>
            <div class="feed-item-translated">${escapeHtml(text)}</div>
        </div>
    `;
    dom.translationFeed.appendChild(div);
    dom.translationFeed.scrollTop = dom.translationFeed.scrollHeight;
}

function addFeedTranslation(meta) {
    const fromFlag = getFlagEmoji(meta.fromLanguage);
    const toFlag = getFlagEmoji(meta.toLanguage);
    const initial = meta.fromUser.charAt(0).toUpperCase();

    const div = document.createElement('div');
    div.className = 'feed-item';
    div.innerHTML = `
        <div class="feed-item-avatar">${initial}</div>
        <div class="feed-item-content">
            <div class="feed-item-header">
                <span class="feed-item-name">${escapeHtml(meta.fromUser)}</span>
                <span class="feed-item-langs">${fromFlag} ${meta.fromLanguage.toUpperCase()} → ${toFlag} ${meta.toLanguage.toUpperCase()}</span>
            </div>
            <div class="feed-item-original">"${escapeHtml(meta.originalText)}"</div>
            <div class="feed-item-translated">${escapeHtml(meta.translatedText)}</div>
        </div>
    `;
    dom.translationFeed.appendChild(div);
    dom.translationFeed.scrollTop = dom.translationFeed.scrollHeight;
}

// ============================================================
// Utilities
// ============================================================
function escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}

// ============================================================
// Start
// ============================================================
document.addEventListener('DOMContentLoaded', init);
