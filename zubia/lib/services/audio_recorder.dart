import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

/// Audio recording service with support for real-time chunking and walkie-talkie modes.
class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _chunkTimer;
  bool _isRecording = false;
  String? _currentPath;

  bool get isRecording => _isRecording;

  /// Start recording in real-time mode (4-second chunks).
  /// Calls [onChunk] with WAV bytes every 4 seconds.
  Future<bool> startRealtime(
    Future<void> Function(Uint8List wavBytes) onChunk,
  ) async {
    if (!await _recorder.hasPermission()) return false;

    _isRecording = true;
    await _startRecording();

    _chunkTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!_isRecording) return;
      final bytes = await _stopAndGetBytes();
      if (bytes != null && bytes.isNotEmpty) {
        onChunk(bytes);
      }
      if (_isRecording) {
        await _startRecording();
      }
    });

    return true;
  }

  /// Start recording in walkie-talkie mode (single continuous recording).
  Future<bool> startWalkie() async {
    if (!await _recorder.hasPermission()) return false;
    _isRecording = true;
    await _startRecording();
    return true;
  }

  /// Stop walkie-talkie recording and return the WAV bytes.
  Future<Uint8List?> stopWalkie() async {
    _isRecording = false;
    return await _stopAndGetBytes();
  }

  /// Stop all recording.
  Future<void> stop() async {
    _isRecording = false;
    _chunkTimer?.cancel();
    _chunkTimer = null;
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (_) {}
    _cleanupFile();
  }

  Future<void> _startRecording() async {
    final dir = await getTemporaryDirectory();
    _currentPath =
        '${dir.path}/zubia_rec_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 256000,
      ),
      path: _currentPath!,
    );
  }

  Future<Uint8List?> _stopAndGetBytes() async {
    try {
      if (!await _recorder.isRecording()) return null;
      final path = await _recorder.stop();
      if (path == null) return null;

      final file = File(path);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      await file.delete();
      return bytes;
    } catch (_) {
      return null;
    }
  }

  void _cleanupFile() {
    if (_currentPath != null) {
      try {
        File(_currentPath!).deleteSync();
      } catch (_) {}
      _currentPath = null;
    }
  }

  void dispose() {
    stop();
    _recorder.dispose();
  }
}
