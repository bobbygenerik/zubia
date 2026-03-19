import 'package:flutter_test/flutter_test.dart';
import 'package:zubia/main.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const ZubiaApp());
    expect(find.text('Zubia'), findsWidgets);
  });
}
