import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zubia/widgets/empty_chat_view.dart';

void main() {
  testWidgets('EmptyChatView displays correct text and icon', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: EmptyChatView(),
      ),
    ));

    expect(find.text('No chats yet'), findsOneWidget);
    expect(find.text('Start a conversation to connect with others in their language.'), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
  });
}
