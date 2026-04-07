import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';
import 'package:zubia/services/audio_recorder.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAudioRecorder extends Mock implements AudioRecorder {}

class MockPathProviderPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => '/tmp';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AudioRecorderService service;
  late MockAudioRecorder mockRecorder;

  setUp(() {
    PathProviderPlatform.instance = MockPathProviderPlatform();
    mockRecorder = MockAudioRecorder();
    service = AudioRecorderService(recorder: mockRecorder);

    registerFallbackValue(const RecordConfig(encoder: AudioEncoder.wav));
  });

  tearDown(() {
    when(() => mockRecorder.dispose()).thenAnswer((_) async {});
    when(() => mockRecorder.isRecording()).thenAnswer((_) async => false);
    service.dispose();
  });

  group('Walkie-talkie mode', () {
    test('startWalkie returns false if no permission', () async {
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => false);

      final result = await service.startWalkie();

      expect(result, isFalse);
      expect(service.isRecording, isFalse);
      verify(() => mockRecorder.hasPermission()).called(1);
      verifyNever(() => mockRecorder.start(any(), path: any(named: 'path')));
    });

    test('startWalkie starts recording if permission granted', () async {
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
      when(() => mockRecorder.start(any(), path: any(named: 'path')))
          .thenAnswer((_) async {});

      final result = await service.startWalkie();

      expect(result, isTrue);
      expect(service.isRecording, isTrue);
      verify(() => mockRecorder.hasPermission()).called(1);
      verify(() => mockRecorder.start(any(), path: any(named: 'path'))).called(1);
    });

    test('stopWalkie stops recording and returns bytes', () async {
      // Create a dummy file in /tmp to simulate the recording output
      final dummyFile = File('/tmp/dummy_rec.wav');
      await dummyFile.writeAsBytes([1, 2, 3]);

      when(() => mockRecorder.isRecording()).thenAnswer((_) async => true);
      when(() => mockRecorder.stop()).thenAnswer((_) async => dummyFile.path);

      final bytes = await service.stopWalkie();

      expect(bytes, isNotNull);
      expect(bytes, equals([1, 2, 3]));
      expect(service.isRecording, isFalse);
      verify(() => mockRecorder.stop()).called(1);
      expect(await dummyFile.exists(), isFalse); // Verify it cleans up
    });

    test('stopWalkie returns null if not recording', () async {
      when(() => mockRecorder.isRecording()).thenAnswer((_) async => false);

      final bytes = await service.stopWalkie();

      expect(bytes, isNull);
      expect(service.isRecording, isFalse);
    });
  });

  group('Real-time mode', () {
    test('startRealtime returns false if no permission', () async {
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => false);

      final result = await service.startRealtime((_) async {});

      expect(result, isFalse);
      expect(service.isRecording, isFalse);
    });

    // Note: Testing the chunk timer fully is tricky due to Future.delayed/Timer in Dart.
    // Testing the initial start behavior is more reliable here without complex FakeAsync setups.
    test('startRealtime starts recording initially', () async {
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
      when(() => mockRecorder.start(any(), path: any(named: 'path')))
          .thenAnswer((_) async {});

      final result = await service.startRealtime((_) async {});

      expect(result, isTrue);
      expect(service.isRecording, isTrue);
      verify(() => mockRecorder.start(any(), path: any(named: 'path'))).called(1);
    });
  });

  group('Stop and dispose', () {
    test('stop cancels recording and cleans up', () async {
      when(() => mockRecorder.isRecording()).thenAnswer((_) async => true);
      when(() => mockRecorder.stop()).thenAnswer((_) async => null);

      await service.stop();

      expect(service.isRecording, isFalse);
      verify(() => mockRecorder.stop()).called(1);
    });

    test('dispose calls stop and dispose on recorder', () {
      when(() => mockRecorder.isRecording()).thenAnswer((_) async => false);
      when(() => mockRecorder.dispose()).thenAnswer((_) async {});

      service.dispose();

      verify(() => mockRecorder.dispose()).called(1);
    });
  });
}
