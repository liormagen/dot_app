import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dot_story/screens/drawing/drawing_screen.dart';

void main() {
  group('_SkipButton', () {
    testWidgets('renders "Skip ▶" label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SkipButton(onTap: () {}),
          ),
        ),
      );
      expect(find.text('Skip ▶'), findsOneWidget);
    });

    testWidgets('calls onTap exactly once per tap', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SkipButton(onTap: () => taps++),
          ),
        ),
      );
      await tester.tap(find.byType(SkipButton));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('calls onTap again on second tap', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SkipButton(onTap: () => taps++),
          ),
        ),
      );
      await tester.tap(find.byType(SkipButton));
      await tester.pump();
      await tester.tap(find.byType(SkipButton));
      await tester.pump();
      expect(taps, 2);
    });
  });
}
