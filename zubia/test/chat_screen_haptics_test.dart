import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zubia/providers/app_state.dart';
import 'package:zubia/screens/chat_screen.dart';

class MockAppState extends AppState {
  MockAppState() : super(serverUrl: 'http://mock.local');

  // Override methods to avoid real logic but track calls if needed
  @override
  void setMode(String m) {
    mode = m;
    notifyListeners();
  }

  @override
  Future<void> startRealtimeRecording() async {
    isRecording = true;
    notifyListeners();
  }

  @override
  Future<void> stopRecording() async {
    isRecording = false;
    notifyListeners();
  }

  @override
  Future<void> startWalkieRecording() async {
    isRecording = true;
    notifyListeners();
  }

  @override
  Future<void> stopWalkieAndSend() async {
    isRecording = false;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock permission handler channel
  const MethodChannel permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'checkPermissionStatus') {
            return 1; // Granted
          } else if (methodCall.method == 'requestPermissions') {
            return {1: 1}; // Microphone: Granted
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, null);
  });

  testWidgets('ChatScreen controls trigger HapticFeedback', (
    WidgetTester tester,
  ) async {
    final state = MockAppState();
    final List<String> feedbackCalls = [];

    // Mock SystemChannels.platform to intercept HapticFeedback
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'HapticFeedback.vibrate') {
            feedbackCalls.add(methodCall.arguments.toString());
          }
          return null;
        });

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AppState>.value(
          value: state,
          child: const ChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Test Mode Toggle (Real-time -> Walkie-talkie)
    // Find the text 'Walkie-talkie' and tap it
    await tester.tap(find.text('Walkie-talkie'));
    await tester.pump();

    // Expect HapticFeedback.selectionClick (usually mapped to 'HapticFeedbackType.selectionClick')
    // Note: The arguments for HapticFeedback.vibrate are usually a string like 'HapticFeedbackType.selectionClick'
    // Let's check what arguments are sent.

    // 2. Test Walkie-talkie Mic Button (Long Press)
    // Mode is now Walkie-talkie.
    expect(state.mode, 'walkie');

    final micButton = find
        .byType(GestureDetector)
        .last; // The mic button is likely the last GestureDetector or found by icon
    // Better finder:
    final micIcon = find.byIcon(Icons.mic);

    // Long press start
    final gesture = await tester.startGesture(tester.getCenter(micIcon));
    await tester.pump(
      const Duration(milliseconds: 500),
    ); // Ensure long press is recognized

    // Long press end
    await gesture.up();
    await tester.pump(); // Trigger onLongPressEnd

    // 3. Switch back to Real-time
    await tester.tap(find.text('Real-time'));
    await tester.pump();

    // 4. Test Real-time Mic Button (Tap)
    await tester.tap(micIcon);
    await tester.pump();

    // Clean up mock
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);

    // Verify calls
    // Note: Since we haven't implemented the calls yet, this test is expected to fail or have empty list.
    // We will update the test expectations after implementation or rely on manual verification if strings are tricky.
    // For now, let's just print them to see what happens, or assert empty if we want TDD style.

    // HapticFeedback.selectionClick -> 'HapticFeedbackType.selectionClick'
    // HapticFeedback.mediumImpact -> 'HapticFeedbackType.mediumImpact'
    // HapticFeedback.lightImpact -> 'HapticFeedbackType.lightImpact'

    // Check calls
    expect(feedbackCalls.length, 5);
    expect(
      feedbackCalls[0],
      'HapticFeedbackType.selectionClick',
    ); // Switch to Walkie
    expect(feedbackCalls[1], 'HapticFeedbackType.mediumImpact'); // Press Mic
    expect(feedbackCalls[2], 'HapticFeedbackType.lightImpact'); // Release Mic
    expect(
      feedbackCalls[3],
      'HapticFeedbackType.selectionClick',
    ); // Switch to Realtime
    expect(feedbackCalls[4], 'HapticFeedbackType.selectionClick'); // Tap Mic
  });
}
