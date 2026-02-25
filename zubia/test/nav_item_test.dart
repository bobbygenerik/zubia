import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zubia/widgets/nav_item.dart';
import 'package:zubia/theme.dart';

void main() {
  testWidgets('ZubiaNavItem renders correctly and is accessible', (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ZubiaNavItem(
              icon: Icons.home,
              label: 'Home',
              active: true,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      ),
    );

    // Verify visual elements
    expect(find.text('Home'), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);

    // Verify Semantics
    final semanticsNode = tester.getSemantics(find.bySemanticsLabel('Home'));
    final data = semanticsNode.getSemanticsData();

    expect(data.label, 'Home');
    expect(data.hasFlag(SemanticsFlag.isButton), true, reason: 'Should be a button');
    expect(data.hasFlag(SemanticsFlag.isSelected), true, reason: 'Should be selected');
    expect(data.hasAction(SemanticsAction.tap), true, reason: 'Should be tappable');
    expect(data.hasFlag(SemanticsFlag.isFocusable), true, reason: 'Should be focusable');

    // Verify interaction
    await tester.tap(find.bySemanticsLabel('Home'));
    await tester.pumpAndSettle();
    expect(tapped, true);
  });

  testWidgets('ZubiaNavItem reflects inactive state', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ZubiaNavItem(
              icon: Icons.settings,
              label: 'Settings',
              active: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    // Verify Semantics
    final semanticsNode = tester.getSemantics(find.bySemanticsLabel('Settings'));
    final data = semanticsNode.getSemanticsData();

    expect(data.label, 'Settings');
    expect(data.hasFlag(SemanticsFlag.isButton), true);
    expect(data.hasFlag(SemanticsFlag.isSelected), false, reason: 'Should NOT be selected');
    expect(data.hasAction(SemanticsAction.tap), true);

    // Check color (Inactive should be muted)
    final textWidget = tester.widget<Text>(find.text('Settings'));
    expect(textWidget.style?.color, ZubiaColors.textMuted);
  });
}
