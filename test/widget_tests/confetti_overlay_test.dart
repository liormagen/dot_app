import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dot_story/widgets/confetti_overlay.dart';

void main() {
  group('ConfettiOverlay', () {
    testWidgets('renders without error before any burst', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: ConfettiOverlay()),
      ));
      expect(find.byType(ConfettiOverlay), findsOneWidget);
    });

    testWidgets('is wrapped in IgnorePointer — touches pass through',
        (tester) async {
      int taps = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              // Button sitting behind the overlay
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => taps++,
                  child: const ColoredBox(color: Colors.white),
                ),
              ),
              // Overlay on top — should NOT swallow the tap
              const ConfettiOverlay(),
            ],
          ),
        ),
      ));

      await tester.tapAt(const Offset(100, 100));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('triggerBurst does not crash', (tester) async {
      final key = GlobalKey<ConfettiOverlayState>();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ConfettiOverlay(key: key)),
      ));

      key.currentState!.triggerBurst(const Offset(200, 150));
      // Pump partway through the animation
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('animation completes without error', (tester) async {
      final key = GlobalKey<ConfettiOverlayState>();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ConfettiOverlay(key: key)),
      ));

      key.currentState!.triggerBurst(const Offset(200, 150));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
