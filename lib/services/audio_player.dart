import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// Audio playback service for translated speech.
/// Queues incoming audio and plays sequentially.
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  final _queue = <_AudioItem>[];
  bool _isPlaying = false;
  double _volume = 1.0;

  double get volume => _volume;
  set volume(double v) {
    _volume = v;
    _player.setVolume(v);
  }

  /// Queue WAV audio bytes for playback.
  void enqueue(Uint8List wavBytes, {Map<String, dynamic>? meta}) {
    _queue.add(_AudioItem(wavBytes, meta));
    if (!_isPlaying) _processQueue();
  }

  Future<void> _processQueue() async {
    if (_queue.isEmpty) {
      _isPlaying = false;
      return;
    }

    _isPlaying = true;
    final item = _queue.removeAt(0);

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/zubia_play_${DateTime.now().millisecondsSinceEpoch}.wav');
      await file.writeAsBytes(item.bytes);

      await _player.setVolume(_volume);
      await _player.setFilePath(file.path);
      await _player.play();

      // Wait for playback to complete
      await _player.playerStateStream.firstWhere(
        (s) => s.processingState == ProcessingState.completed,
      );

      await file.delete();
    } catch (_) {}

    _processQueue();
  }

  void dispose() {
    _player.dispose();
    _queue.clear();
  }
}

class _AudioItem {
  final Uint8List bytes;
  final Map<String, dynamic>? meta;
  _AudioItem(this.bytes, this.meta);
}
