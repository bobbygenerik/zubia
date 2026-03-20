import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// Translation history entry - persisted across sessions.
class TranslationHistory {
  final String originalText;
  final String translatedText;
  final String fromLanguage;
  final String toLanguage;
  final String fromUser;
  final String createdAt;
  final bool isVoice;

  const TranslationHistory({
    required this.originalText,
    required this.translatedText,
    required this.fromLanguage,
    required this.toLanguage,
    required this.fromUser,
    required this.createdAt,
    required this.isVoice,
  });

  Map<String, dynamic> toJson() => {
    'originalText': originalText,
    'translatedText': translatedText,
    'fromLanguage': fromLanguage,
    'toLanguage': toLanguage,
    'fromUser': fromUser,
    'createdAt': createdAt,
    'isVoice': isVoice,
  };

  factory TranslationHistory.fromJson(Map<String, dynamic> json) =>
      TranslationHistory(
        originalText: json['originalText']?.toString() ?? '',
        translatedText: json['translatedText']?.toString() ?? '',
        fromLanguage: json['fromLanguage']?.toString() ?? 'en',
        toLanguage: json['toLanguage']?.toString() ?? 'en',
        fromUser: json['fromUser']?.toString() ?? 'Unknown',
        createdAt:
            json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
        isVoice: json['isVoice'] as bool? ?? false,
      );
}

/// User in a room.
class RoomUser {
  final String id;
  final String name;
  final String language;
  final bool isMuted;

  RoomUser({
    required this.id,
    required this.name,
    required this.language,
    this.isMuted = false,
  });

  factory RoomUser.fromJson(Map<String, dynamic> json) => RoomUser(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    language: json['language'] ?? 'en',
    isMuted: json['isMuted'] ?? false,
  );
}

/// A saved phrase pair captured from translations/history.
class SavedPhrase {
  final String originalText;
  final String translatedText;
  final String fromLanguage;
  final String toLanguage;
  final String createdAt;

  const SavedPhrase({
    required this.originalText,
    required this.translatedText,
    required this.fromLanguage,
    required this.toLanguage,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'originalText': originalText,
    'translatedText': translatedText,
    'fromLanguage': fromLanguage,
    'toLanguage': toLanguage,
    'createdAt': createdAt,
  };

  factory SavedPhrase.fromJson(Map<String, dynamic> json) => SavedPhrase(
    originalText: json['originalText']?.toString() ?? '',
    translatedText: json['translatedText']?.toString() ?? '',
    fromLanguage: json['fromLanguage']?.toString() ?? 'en',
    toLanguage: json['toLanguage']?.toString() ?? 'en',
    createdAt:
        json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
  );
}

/// Central app state.
class AppState extends ChangeNotifier {
  static const String _savedPhrasesKey = 'savedPhrasesV1';
  static const String _translationHistoryKey = 'translationHistoryV1';

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

  // Thread
  String? threadId;
  String? otherUserName;
  List<RoomUser> users = [];

  // State
  Map<String, String> languages = {};
  List<Map<String, dynamic>> threads = [];
  String connectionStatus =
      'disconnected'; // disconnected, connecting, connected, recording, processing
  bool isRecording = false;
  String mode = 'realtime'; // realtime or walkie
  double volume = 1.0;
  List<FeedEntry> feed = [];
  List<SavedPhrase> savedPhrases = [];
  List<TranslationHistory> history = [];

  StreamSubscription? _wsSub;

  AppState({required this.serverUrl}) {
    api = ApiService(baseUrl: serverUrl);
    ws = WebSocketService(baseUrl: serverUrl);
  }

  Future<void> loadIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userId');
    userName = prefs.getString('userName') ?? '';
    userLanguage = prefs.getString('userLanguage') ?? 'en';

    // If we have a stored userId, verify it still exists on the server.
    // The server is in-memory, so it resets on restart — re-register silently.
    if (userId != null && userName.isNotEmpty) {
      final exists = await api.verifyUser(userId!);
      if (!exists) {
        userId = null; // will trigger re-registration in the UI
      }
    }
    await loadSavedPhrases();
    await loadHistory();
    notifyListeners();
  }

  Future<void> loadSavedPhrases() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedPhrasesKey);

    if (raw == null || raw.isEmpty) {
      savedPhrases = [];
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        savedPhrases = decoded
            .whereType<Map>()
            .map((e) => SavedPhrase.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } else {
        savedPhrases = [];
      }
    } catch (_) {
      savedPhrases = [];
    }

    notifyListeners();
  }

  bool isPhraseSaved({
    required String originalText,
    required String translatedText,
    required String fromLanguage,
    required String toLanguage,
  }) {
    return savedPhrases.any((p) {
      return p.originalText == originalText &&
          p.translatedText == translatedText &&
          p.fromLanguage.toLowerCase() == fromLanguage.toLowerCase() &&
          p.toLanguage.toLowerCase() == toLanguage.toLowerCase();
    });
  }

  Future<void> toggleSavedPhrase({
    required String originalText,
    required String translatedText,
    required String fromLanguage,
    required String toLanguage,
  }) async {
    final index = savedPhrases.indexWhere((p) {
      return p.originalText == originalText &&
          p.translatedText == translatedText &&
          p.fromLanguage.toLowerCase() == fromLanguage.toLowerCase() &&
          p.toLanguage.toLowerCase() == toLanguage.toLowerCase();
    });

    if (index >= 0) {
      savedPhrases.removeAt(index);
    } else {
      savedPhrases.insert(
        0,
        SavedPhrase(
          originalText: originalText,
          translatedText: translatedText,
          fromLanguage: fromLanguage.toLowerCase(),
          toLanguage: toLanguage.toLowerCase(),
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
    }

    await _persistSavedPhrases();
    notifyListeners();
  }

  Future<void> removeSavedPhrase(SavedPhrase phrase) async {
    savedPhrases.removeWhere((p) {
      return p.originalText == phrase.originalText &&
          p.translatedText == phrase.translatedText &&
          p.fromLanguage == phrase.fromLanguage &&
          p.toLanguage == phrase.toLanguage;
    });
    await _persistSavedPhrases();
    notifyListeners();
  }

  Future<void> addSavedPhraseEntry(
    SavedPhrase phrase, {
    int atIndex = 0,
  }) async {
    savedPhrases.removeWhere((p) {
      return p.originalText == phrase.originalText &&
          p.translatedText == phrase.translatedText &&
          p.fromLanguage == phrase.fromLanguage &&
          p.toLanguage == phrase.toLanguage;
    });

    final targetIndex = atIndex.clamp(0, savedPhrases.length);
    savedPhrases.insert(targetIndex, phrase);
    await _persistSavedPhrases();
    notifyListeners();
  }

  Future<void> clearSavedPhrases() async {
    if (savedPhrases.isEmpty) return;
    savedPhrases.clear();
    await _persistSavedPhrases();
    notifyListeners();
  }

  Future<void> restoreSavedPhrases(List<SavedPhrase> phrases) async {
    savedPhrases = List<SavedPhrase>.from(phrases);
    await _persistSavedPhrases();
    notifyListeners();
  }

  Future<void> _persistSavedPhrases() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(savedPhrases.map((p) => p.toJson()).toList());
    await prefs.setString(_savedPhrasesKey, raw);
  }

  // ── History Management ──────────────────────────────

  Future<void> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_translationHistoryKey);

    if (raw == null || raw.isEmpty) {
      history = [];
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        history = decoded
            .whereType<Map>()
            .map(
              (e) => TranslationHistory.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList();
      } else {
        history = [];
      }
    } catch (_) {
      history = [];
    }

    notifyListeners();
  }

  Future<void> addToHistory({
    required String originalText,
    required String translatedText,
    required String fromLanguage,
    required String toLanguage,
    String? fromUser,
    bool isVoice = false,
  }) async {
    final entry = TranslationHistory(
      originalText: originalText,
      translatedText: translatedText,
      fromLanguage: fromLanguage.toLowerCase(),
      toLanguage: toLanguage.toLowerCase(),
      fromUser: fromUser ?? userName,
      createdAt: DateTime.now().toIso8601String(),
      isVoice: isVoice,
    );

    history.insert(0, entry); // Most recent first
    await _persistHistory();
    notifyListeners();
  }

  Future<void> _persistHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(history.map((h) => h.toJson()).toList());
    await prefs.setString(_translationHistoryKey, raw);
  }

  Future<void> clearHistory() async {
    if (history.isEmpty) return;
    history.clear();
    await _persistHistory();
    notifyListeners();
  }

  Future<bool> registerAndSaveIdentity(String name, String lang) async {
    final result = await api.registerUser(name, lang);
    if (result != null) {
      userId = result['id'];
      userName = result['name'];
      userLanguage = result['language'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', userId!);
      await prefs.setString('userName', userName);
      await prefs.setString('userLanguage', userLanguage);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> loadLanguages() async {
    languages = await api.getLanguages();
    if (userLanguage.isEmpty && languages.isNotEmpty) {
      userLanguage = languages.keys.first;
    }
    notifyListeners();
  }

  Future<void> loadThreads() async {
    if (userId != null) {
      threads = await api.getThreads(userId!);
      notifyListeners();
    }
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

  // ── Thread Management ──────────────────────────────────

  Future<String?> createThreadWithUser(String otherUserId) async {
    if (userId == null) return null;
    return await api.createThread(userId!, otherUserId);
  }

  void joinThread(String tid, String otherName) {
    if (userId == null) return;
    threadId = tid;
    otherUserName = otherName;
    connectionStatus = 'connecting';
    notifyListeners();

    ws.connect(tid, userId!);

    _wsSub?.cancel();
    _wsSub = ws.messages.listen(_handleMessage);
  }

  void leaveThread() {
    stopRecording();
    ws.disconnect();
    _wsSub?.cancel();
    threadId = null;
    otherUserName = null;
    users = [];
    feed = [];
    connectionStatus = 'disconnected';
    notifyListeners();
  }

  Future<void> changeLanguage(String lang) async {
    userLanguage = lang;
    if (ws.isConnected) {
      ws.sendControl({'type': 'change_language', 'language': lang});
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userLanguage', userLanguage);
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
        threadId = msg.data['roomId'] as String? ?? threadId;
        _parseUsers(msg.data['users']);
        connectionStatus = 'connected';
        feed.clear();
        _addSystemFeed(
          'You joined the chat. ${mode == 'walkie' ? 'Hold the mic to talk.' : 'Tap the mic to start streaming.'}',
        );
        break;

      case 'user_joined':
        _parseUsers(msg.data['users']);
        _addSystemFeed(
          '${msg.data['userName']} joined (${languages[msg.data['language']] ?? msg.data['language']})',
        );
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
        feed.add(
          FeedEntry(
            type: 'transcription',
            fromUser: userName,
            originalText: msg.data['text'] as String?,
            fromLanguage: msg.data['language'] as String?,
          ),
        );
        break;

      case 'translated_audio_meta':
        feed.add(
          FeedEntry(
            type: 'translation',
            fromUser: msg.data['fromUser'] as String?,
            originalText: msg.data['originalText'] as String?,
            translatedText: msg.data['translatedText'] as String?,
            fromLanguage: msg.data['fromLanguage'] as String?,
            toLanguage: msg.data['toLanguage'] as String?,
          ),
        );
        // Add to persistent history (fire and forget)
        if (msg.data['originalText'] != null &&
            msg.data['translatedText'] != null) {
          addToHistory(
            originalText: msg.data['originalText'] as String,
            translatedText: msg.data['translatedText'] as String,
            fromLanguage: msg.data['fromLanguage'] as String? ?? 'en',
            toLanguage: msg.data['toLanguage'] as String? ?? 'en',
            fromUser: msg.data['fromUser'] as String?,
            isVoice: true,
          );
        }
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
      'en': '🇺🇸',
      'es': '🇪🇸',
      'fr': '🇫🇷',
      'de': '🇩🇪',
      'zh': '🇨🇳',
      'ja': '🇯🇵',
      'ar': '🇸🇦',
      'pt': '🇵🇹',
      'ru': '🇷🇺',
      'ko': '🇰🇷',
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
