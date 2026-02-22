import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/audio_recorder.dart';
import '../services/audio_player.dart';

/// Feed entry for the translation feed.
class FeedEntry {
  final String type; // 'system', 'transcription', 'translation'
  final String? fromUser;
  final String? originalText;
  final String? translatedText;
  final String? fromLanguage;
  final String? toLanguage;
  final String? systemText;
  final DateTime timestamp;

  FeedEntry({
    required this.type,
    this.fromUser,
    this.originalText,
    this.translatedText,
    this.fromLanguage,
    this.toLanguage,
    this.systemText,
  }) : timestamp = DateTime.now();
}

/// User in a room.
class RoomUser {
  final String id;
  final String name;
  final String language;
  final bool isMuted;

  RoomUser({required this.id, required this.name, required this.language, this.isMuted = false});

  factory RoomUser.fromJson(Map<String, dynamic> json) => RoomUser(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        language: json['language'] ?? 'en',
        isMuted: json['isMuted'] ?? false,
      );
}

/// Central app state.
class AppState extends ChangeNotifier {
  // Server config
  String serverUrl;

  // Services
  late ApiService api;
  late WebSocketService ws;
  final AudioRecorderService recorder = AudioRecorderService();
  final AudioPlayerService player = AudioPlayerService();

  // User
  String userName = '';
  String userLanguage = 'en';
  String? userId;

  // Room
  String? roomId;
  String? roomName;
  List<RoomUser> users = [];

  // State
  Map<String, String> languages = {};
  List<Map<String, dynamic>> activeRooms = [];
  String connectionStatus = 'disconnected'; // disconnected, connecting, connected, recording, processing
  bool isRecording = false;
  String mode = 'realtime'; // realtime or walkie
  double volume = 1.0;
  List<FeedEntry> feed = [];

  StreamSubscription? _wsSub;

  AppState({required this.serverUrl}) {
    api = ApiService(baseUrl: serverUrl);
    ws = WebSocketService(baseUrl: serverUrl);
  }

  Future<void> loadLanguages() async {
    languages = await api.getLanguages();
    if (userLanguage.isEmpty && languages.isNotEmpty) {
      userLanguage = languages.keys.first;
    }
    notifyListeners();
  }

  Future<void> loadRooms() async {
    activeRooms = await api.getRooms();
    notifyListeners();
  }

  void setMode(String m) {
    if (isRecording) stopRecording();
    mode = m;
    notifyListeners();
  }

  void setVolume(double v) {
    volume = v;
    player.volume = v;
    notifyListeners();
  }

  // ── Room Management ──────────────────────────────────

  Future<String?> createRoom() async {
    final room = await api.createRoom("$userName's Room");
    if (room != null) return room['id'] as String?;
    return null;
  }

  void joinRoom(String roomCode) {
    roomId = roomCode;
    connectionStatus = 'connecting';
    notifyListeners();

    ws.connect(roomCode, userName, userLanguage);

    _wsSub?.cancel();
    _wsSub = ws.messages.listen(_handleMessage);
  }

  void leaveRoom() {
    stopRecording();
    ws.disconnect();
    _wsSub?.cancel();
    roomId = null;
    roomName = null;
    userId = null;
    users = [];
    feed = [];
    connectionStatus = 'disconnected';
    notifyListeners();
  }

  void changeLanguage(String lang) {
    userLanguage = lang;
    if (ws.isConnected) {
      ws.sendControl({'type': 'change_language', 'language': lang});
    }
    notifyListeners();
  }

  // ── Recording ────────────────────────────────────────

  Future<void> startRealtimeRecording() async {
    final ok = await recorder.startRealtime((wavBytes) async {
      ws.sendAudio(wavBytes);
    });
    if (ok) {
      isRecording = true;
      connectionStatus = 'recording';
      notifyListeners();
    }
  }

  Future<void> startWalkieRecording() async {
    final ok = await recorder.startWalkie();
    if (ok) {
      isRecording = true;
      connectionStatus = 'recording';
      notifyListeners();
    }
  }

  Future<void> stopWalkieAndSend() async {
    final bytes = await recorder.stopWalkie();
    isRecording = false;
    connectionStatus = 'processing';
    notifyListeners();

    if (bytes != null && bytes.isNotEmpty) {
      ws.sendAudio(bytes);
    }

    Future.delayed(const Duration(seconds: 3), () {
      if (connectionStatus == 'processing') {
        connectionStatus = 'connected';
        notifyListeners();
      }
    });
  }

  Future<void> stopRecording() async {
    await recorder.stop();
    isRecording = false;
    connectionStatus = ws.isConnected ? 'connected' : 'disconnected';
    notifyListeners();
  }

  // ── Message Handling ─────────────────────────────────

  void _handleMessage(ServerMessage msg) {
    switch (msg.type) {
      case 'joined':
        userId = msg.data['userId'] as String?;
        roomName = msg.data['roomName'] as String?;
        roomId = msg.data['roomId'] as String?;
        _parseUsers(msg.data['users']);
        connectionStatus = 'connected';
        feed.clear();
        _addSystemFeed('You joined the room. ${mode == 'walkie' ? 'Hold the mic to talk.' : 'Tap the mic to start streaming.'}');
        break;

      case 'user_joined':
        _parseUsers(msg.data['users']);
        _addSystemFeed('${msg.data['userName']} joined (${languages[msg.data['language']] ?? msg.data['language']})');
        break;

      case 'user_left':
        _parseUsers(msg.data['users']);
        _addSystemFeed('${msg.data['userName']} left');
        break;

      case 'user_muted':
      case 'user_unmuted':
        _parseUsers(msg.data['users'] ?? []);
        break;

      case 'user_language_changed':
        _parseUsers(msg.data['users']);
        break;

      case 'transcription':
        feed.add(FeedEntry(
          type: 'transcription',
          fromUser: 'You',
          originalText: msg.data['text'] as String?,
          fromLanguage: msg.data['language'] as String?,
        ));
        break;

      case 'translated_audio_meta':
        feed.add(FeedEntry(
          type: 'translation',
          fromUser: msg.data['fromUser'] as String?,
          originalText: msg.data['originalText'] as String?,
          translatedText: msg.data['translatedText'] as String?,
          fromLanguage: msg.data['fromLanguage'] as String?,
          toLanguage: msg.data['toLanguage'] as String?,
        ));
        break;

      case 'audio_data':
        if (msg.audioBytes != null) {
          player.enqueue(msg.audioBytes!, meta: msg.data);
        }
        break;

      case 'disconnected':
        connectionStatus = 'disconnected';
        break;
    }
    notifyListeners();
  }

  void _parseUsers(dynamic usersList) {
    if (usersList is List) {
      users = usersList
          .map((u) => RoomUser.fromJson(u as Map<String, dynamic>))
          .toList();
    }
  }

  void _addSystemFeed(String text) {
    feed.add(FeedEntry(type: 'system', systemText: text));
  }

  String getFlagEmoji(String langCode) {
    const flags = {
      'en': '🇺🇸', 'es': '🇪🇸', 'fr': '🇫🇷', 'de': '🇩🇪', 'zh': '🇨🇳',
      'ja': '🇯🇵', 'ar': '🇸🇦', 'pt': '🇧🇷', 'ru': '🇷🇺', 'ko': '🇰🇷',
    };
    return flags[langCode] ?? '🌍';
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    ws.dispose();
    recorder.dispose();
    player.dispose();
    super.dispose();
  }
}
