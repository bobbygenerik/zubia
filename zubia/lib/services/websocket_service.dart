import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Message types from the server.
class ServerMessage {
  final String type;
  final Map<String, dynamic> data;
  final Uint8List? audioBytes;

  ServerMessage({required this.type, this.data = const {}, this.audioBytes});
}

/// WebSocket service for real-time communication with the Zubia backend.
typedef WebSocketConnect = WebSocketChannel Function(Uri uri);

class WebSocketService {
  final String baseUrl;
  final WebSocketConnect _connect;
  WebSocketChannel? _channel;
  final _messageController = StreamController<ServerMessage>.broadcast();
  Map<String, dynamic>? _pendingAudioMeta;
  bool _connected = false;

  WebSocketService({required this.baseUrl, WebSocketConnect? connect})
    : _connect = connect ?? ((uri) => WebSocketChannel.connect(uri));

  Stream<ServerMessage> get messages => _messageController.stream;
  bool get isConnected => _connected;

  void connect(String threadId, String userId) {
    final wsUrl = baseUrl.replaceFirst('http', 'ws');
    _channel = _connect(Uri.parse('$wsUrl/ws/thread/$threadId'));

    // Send join message
    _channel!.sink.add(jsonEncode({'userId': userId}));

    _channel!.stream.listen(
      (data) {
        if (data is String) {
          final msg = jsonDecode(data) as Map<String, dynamic>;
          final type = msg['type'] as String? ?? '';

          if (type == 'translated_audio_meta') {
            _pendingAudioMeta = msg;
          }

          _messageController.add(ServerMessage(type: type, data: msg));
        } else if (data is List<int>) {
          // Binary audio data
          final bytes = Uint8List.fromList(data);
          _messageController.add(
            ServerMessage(
              type: 'audio_data',
              data: _pendingAudioMeta ?? {},
              audioBytes: bytes,
            ),
          );
          _pendingAudioMeta = null;
        }
      },
      onDone: () {
        _connected = false;
        _messageController.add(ServerMessage(type: 'disconnected'));
      },
      onError: (err) {
        _connected = false;
        _messageController.add(
          ServerMessage(type: 'error', data: {'error': err.toString()}),
        );
      },
    );

    _connected = true;
  }

  void sendAudio(Uint8List wavBytes) {
    if (_channel != null && _connected) {
      _channel!.sink.add(wavBytes);
    }
  }

  void sendControl(Map<String, dynamic> message) {
    if (_channel != null && _connected) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  void disconnect() {
    _connected = false;
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
