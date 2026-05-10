import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dot_story/screens/drawing/drawing_screen.dart';

void main() {
  group('ZoomControlButton', () {
    testWidgets('touch target is at least 44×44', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ZoomControlButton(
                icon: Icons.add_rounded,
                semanticLabel: 'Zoom in',
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byType(ZoomControlButton));
      expect(size.width, greaterThanOrEqualTo(44.0));
      expect(size.height, greaterThanOrEqualTo(44.0));
    });

    testWidgets('zoom-in button has "Zoom in" semantic label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ZoomControlButton(
                icon: Icons.add_rounded,
                semanticLabel: 'Zoom in',
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Zoom in'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('zoom-out button has "Zoom out" semantic label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ZoomControlButton(
                icon: Icons.remove_rounded,
                semanticLabel: 'Zoom out',
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Zoom out'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('calls onTap when tapped', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ZoomControlButton(
                icon: Icons.add_rounded,
                semanticLabel: 'Zoom in',
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ZoomControlButton));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('DrawingVoiceButton', () {
    testWidgets('idle state has "Play narration" semantic label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DrawingVoiceButton(
                playing: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Play narration'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('playing state has "Stop narration" semantic label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DrawingVoiceButton(
                playing: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Stop narration'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('calls onTap when tapped', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DrawingVoiceButton(
                playing: false,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(DrawingVoiceButton));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('playing:true and playing:false each call their respective onTap', (tester) async {
      // The button is a dumb widget — caller must wire play vs stop callbacks.
      // This test documents the contract: different callbacks must be passed.
      bool stopCalled = false;
      bool playCalled = false;

      // Idle state → onTap should play
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DrawingVoiceButton(playing: false, onTap: () => playCalled = true),
        ),
      ));
      await tester.tap(find.byType(DrawingVoiceButton));
      await tester.pump();
      expect(playCalled, isTrue);

      // Reset and test playing state → onTap should stop
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DrawingVoiceButton(playing: true, onTap: () => stopCalled = true),
        ),
      ));
      await tester.tap(find.byType(DrawingVoiceButton));
      await tester.pump();
      expect(stopCalled, isTrue,
          reason: 'semantic label says Stop narration — caller must pass stop callback when playing');
    });
  });
}
