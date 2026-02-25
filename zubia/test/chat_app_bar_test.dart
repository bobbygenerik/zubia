import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zubia/widgets/chat_app_bar.dart';
import 'package:zubia/providers/app_state.dart';

class FakeAppState extends AppState {
  FakeAppState() : super(serverUrl: 'http://dummy.url');

  @override
  String? get otherUserName => 'TestUser';

  @override
  String get connectionStatus => 'connected';

  @override
  void leaveThread() {
    // Do nothing
  }
}

void main() {
  testWidgets('ChatAppBar renders correctly', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final state = FakeAppState();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAppBar(state: state),
        ),
      ),
    );

    expect(find.text('TestUser'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
  });
}
