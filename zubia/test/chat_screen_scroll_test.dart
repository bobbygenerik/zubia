import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zubia/providers/app_state.dart';
import 'package:zubia/screens/chat_screen.dart';

// Create a mock AppState that extends the real one but overrides methods/getters we need.
// Since we can't easily mock the final fields (recorder, player) without more complex mocking or DI,
// we rely on the fact that they aren't used in this specific test scenario (except construction).
class MockAppState extends AppState {
  MockAppState() : super(serverUrl: 'http://mock.local');

  @override
  // ignore: overridden_fields
  List<FeedEntry> feed = [];

  @override
  // ignore: overridden_fields
  double volume = 0.5;

  @override
  void setVolume(double v) {
    volume = v;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock permission handler channel
  const MethodChannel channel = MethodChannel('flutter.baseflow.com/permissions/methods');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'checkPermissionStatus') {
          return 1; // Granted
        } else if (methodCall.method == 'requestPermissions') {
          return {1: 1}; // Microphone: Granted
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  testWidgets('ChatScreen scrolls to bottom on every rebuild (Reproduce Issue)', (WidgetTester tester) async {
    final state = MockAppState();

    // Add many messages to ensure scrolling is possible
    for (int i = 0; i < 50; i++) {
      state.feed.add(FeedEntry(
        type: 'transcription',
        fromUser: i % 2 == 0 ? 'Me' : 'Other',
        originalText: 'Message $i which is long enough to take some space',
      ));
    }

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AppState>.value(
          value: state,
          child: const ChatScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Find the Scrollable
    final scrollableFinder = find.byType(Scrollable);
    expect(scrollableFinder, findsOneWidget);

    final ScrollableState scrollable = tester.state(scrollableFinder);
    final ScrollPosition position = scrollable.position;

    // Verify we are at the bottom initially
    expect(position.pixels, equals(position.maxScrollExtent), reason: "Should start at bottom");

    // Scroll up by 200 pixels
    final double targetScroll = position.maxScrollExtent - 200;
    position.jumpTo(targetScroll);
    await tester.pump();

    expect(position.pixels, equals(targetScroll), reason: "Should be scrolled up");

    // Trigger a rebuild by changing volume (unrelated to feed)
    state.setVolume(0.8);
    await tester.pump(); // Allow Consumer to rebuild

    // Wait for the post frame callback animation to start/complete
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // FIX: It should stay at the same position (targetScroll)
    expect(position.pixels, equals(targetScroll), reason: "Should NOT have scrolled back to bottom");
  });
}
