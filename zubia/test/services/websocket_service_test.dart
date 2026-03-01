import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:zubia/services/websocket_service.dart';

// --- Mocks ---

class FakeWebSocketSink implements WebSocketSink {
  final StreamController controller;
  final Completer doneCompleter = Completer();

  FakeWebSocketSink(this.controller);

  @override
  void add(data) {
    controller.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    controller.addError(error, stackTrace);
  }

  @override
  Future addStream(Stream stream) {
    return controller.addStream(stream);
  }

  @override
  Future close([int? closeCode, String? closeReason]) {
    doneCompleter.complete();
    return controller.close();
  }

  @override
  Future get done => doneCompleter.future;
}

class FakeWebSocketChannel implements WebSocketChannel {
  final StreamController _incomingController = StreamController();
  final StreamController _outgoingController = StreamController.broadcast();

  // Expose these for testing interactions
  StreamSink get incomingSink => _incomingController.sink;
  Stream get outgoingStream => _outgoingController.stream;

  @override
  Stream get stream => _incomingController.stream;

  @override
  WebSocketSink get sink => FakeWebSocketSink(_outgoingController);

  @override
  void pipe(StreamChannel<dynamic> other) {
    throw UnimplementedError();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  Future<void> get ready => Future.value();
}

// --- Tests ---

void main() {
  late WebSocketService service;
  late FakeWebSocketChannel fakeChannel;

  setUp(() {
    fakeChannel = FakeWebSocketChannel();
    service = WebSocketService(
      baseUrl: 'http://test.com',
      connect: (uri) => fakeChannel,
    );
  });

  tearDown(() {
    service.dispose();
  });

  test('connect sends join message with userId', () async {
    final threadId = 'thread-123';
    final userId = 'user-456';

    final futureMsg = fakeChannel.outgoingStream.first;
    service.connect(threadId, userId);

    expect(service.isConnected, isTrue);

    final firstMessage = await futureMsg;
    final decoded = jsonDecode(firstMessage as String);
    expect(decoded['userId'], equals(userId));
  });

  test('handles incoming text message', () async {
    service.connect('thread-1', 'user-1');

    final messageData = {'type': 'chat', 'content': 'Hello'};

    final futureMessage = service.messages.first;

    fakeChannel.incomingSink.add(jsonEncode(messageData));

    final serverMessage = await futureMessage;
    expect(serverMessage.type, equals('chat'));
    expect(serverMessage.data['content'], equals('Hello'));
  });

  test('handles translated_audio_meta and subsequent audio data', () async {
    service.connect('thread-1', 'user-1');

    final metaData = {
      'type': 'translated_audio_meta',
      'id': 'msg-1',
      'language': 'es',
    };

    final futureMeta = service.messages.first;
    fakeChannel.incomingSink.add(jsonEncode(metaData));
    final metaMessage = await futureMeta;

    expect(metaMessage.type, equals('translated_audio_meta'));
    expect(metaMessage.data['id'], equals('msg-1'));

    final audioBytes = [1, 2, 3, 4];
    final futureAudio = service.messages.first;
    fakeChannel.incomingSink.add(audioBytes);

    final audioMessage = await futureAudio;
    expect(audioMessage.type, equals('audio_data'));
    expect(audioMessage.data['id'], equals('msg-1'));
    expect(audioMessage.audioBytes, equals(Uint8List.fromList(audioBytes)));
  });

  test('sendAudio sends bytes to sink', () async {
    final bytes = Uint8List.fromList([10, 20, 30]);

    final expectation = expectLater(
      fakeChannel.outgoingStream,
      emitsInOrder([
        anything, // Join message
        bytes,
      ]),
    );

    service.connect('thread-1', 'user-1');
    service.sendAudio(bytes);

    await expectation;
  });

  test('sendControl sends json to sink', () async {
    final controlMsg = {'type': 'stop_speaking'};

    final expectation = expectLater(
      fakeChannel.outgoingStream,
      emitsInOrder([
        anything, // Join message
        predicate((msg) {
          final decoded = jsonDecode(msg as String);
          return decoded['type'] == 'stop_speaking';
        }),
      ]),
    );

    service.connect('thread-1', 'user-1');
    service.sendControl(controlMsg);

    await expectation;
  });

  test('disconnect closes channel and updates state', () async {
    service.connect('thread-1', 'user-1');
    expect(service.isConnected, isTrue);

    service.disconnect();

    expect(service.isConnected, isFalse);
  });

  test('server disconnection emits disconnected message', () async {
    service.connect('thread-1', 'user-1');

    final futureMsg = service.messages.first;

    // Simulate server closing connection
    await fakeChannel.incomingSink.close();

    final msg = await futureMsg;
    expect(msg.type, equals('disconnected'));
    expect(service.isConnected, isFalse);
  });

  test('server error emits error message', () async {
    service.connect('thread-1', 'user-1');

    final futureMsg = service.messages.first;

    // Simulate server error
    fakeChannel.incomingSink.addError('Connection failed');

    final msg = await futureMsg;
    expect(msg.type, equals('error'));
    expect(msg.data['error'], contains('Connection failed'));
    expect(service.isConnected, isFalse);
  });
}
