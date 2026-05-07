import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dot_story/models/dot_model.dart';
import 'package:dot_story/models/drawing_model.dart';
import 'package:dot_story/screens/drawing/dot_canvas.dart';
import 'package:dot_story/screens/drawing/drawing_types.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _kDots = [
  const DotModel(id: 1, x: 80,  y: 80),
  const DotModel(id: 2, x: 240, y: 80),
  const DotModel(id: 3, x: 320, y: 200),
  const DotModel(id: 4, x: 160, y: 240),
  const DotModel(id: 5, x: 80,  y: 200),
];

final _kDrawing = DrawingModel(
  id: 'golden-test',
  names: const {'en': 'Golden Test'},
  storyId: 'story1',
  chapter: 1,
  difficulty: 'medium',
  canvasWidth: 400,
  canvasHeight: 300,
  imageOutline: null,
  imageColored: 'assets/dummy.png',
  tutorialSteps: const [],
  dots: _kDots,
);

Connection _conn(int fromIdx, int toIdx, LineStyle style, Color color) =>
    Connection(
      from: _kDots[fromIdx],
      to: _kDots[toIdx],
      style: style,
      color: color,
    );

Widget _pump(DotCanvasPainter painter) {
  return MaterialApp(
    home: RepaintBoundary(
      key: const Key('canvas'),
      child: SizedBox(
        width: 400,
        height: 300,
        child: CustomPaint(painter: painter),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DotCanvasPainter golden', () {
    testWidgets('empty — all dots unconnected, dot 1 is next',
        (tester) async {
      await tester.pumpWidget(_pump(DotCanvasPainter(
        drawing: _kDrawing,
        session: DrawingSessionState.initial(1),
        lineAnimProgress: 0,
        hintPulse: 0,
        animatingConnection: null,
        scale: 1.0,
        offset: Offset.zero,
      )));
      await expectLater(
        find.byKey(const Key('canvas')),
        matchesGoldenFile('goldens/dot_canvas_empty.png'),
      );
    });

    testWidgets('mid-game — two connections drawn, dot 3 is next',
        (tester) async {
      final connections = [
        _conn(0, 1, LineStyle.sparkle, const Color(0xFFFF6B6B)),
        _conn(1, 2, LineStyle.wave,    const Color(0xFF6C48FF)),
      ];
      final session = DrawingSessionState(
        nextExpectedDotId: 3,
        connections: connections,
        isComplete: false,
      );
      await tester.pumpWidget(_pump(DotCanvasPainter(
        drawing: _kDrawing,
        session: session,
        lineAnimProgress: 1.0,
        hintPulse: 0,
        animatingConnection: null,
        scale: 1.0,
        offset: Offset.zero,
      )));
      await expectLater(
        find.byKey(const Key('canvas')),
        matchesGoldenFile('goldens/dot_canvas_mid_game.png'),
      );
    });

    testWidgets('hinting — dot 2 is hinting (pulse visible)',
        (tester) async {
      final session = DrawingSessionState(
        nextExpectedDotId: 2,
        connections: const [],
        isComplete: false,
        hintingDotId: 2,
      );
      await tester.pumpWidget(_pump(DotCanvasPainter(
        drawing: _kDrawing,
        session: session,
        lineAnimProgress: 0,
        hintPulse: 0.8,
        animatingConnection: null,
        scale: 1.0,
        offset: Offset.zero,
      )));
      await expectLater(
        find.byKey(const Key('canvas')),
        matchesGoldenFile('goldens/dot_canvas_hinting.png'),
      );
    });

    testWidgets('complete — all dots connected', (tester) async {
      final connections = [
        _conn(0, 1, LineStyle.sparkle, const Color(0xFFFF6B6B)),
        _conn(1, 2, LineStyle.wave,    const Color(0xFF6C48FF)),
        _conn(2, 3, LineStyle.glow,    const Color(0xFFFFD93D)),
        _conn(3, 4, LineStyle.sparkle, const Color(0xFF6BCB77)),
        _conn(4, 0, LineStyle.wave,    const Color(0xFF4FC3F7)),
      ];
      final session = DrawingSessionState(
        nextExpectedDotId: 6,
        connections: connections,
        isComplete: true,
      );
      await tester.pumpWidget(_pump(DotCanvasPainter(
        drawing: _kDrawing,
        session: session,
        lineAnimProgress: 1.0,
        hintPulse: 0,
        animatingConnection: null,
        scale: 1.0,
        offset: Offset.zero,
      )));
      await expectLater(
        find.byKey(const Key('canvas')),
        matchesGoldenFile('goldens/dot_canvas_complete.png'),
      );
    });

    testWidgets('animating — connection partially drawn (50%)',
        (tester) async {
      final session = DrawingSessionState(
        nextExpectedDotId: 2,
        connections: const [],
        isComplete: false,
      );
      await tester.pumpWidget(_pump(DotCanvasPainter(
        drawing: _kDrawing,
        session: session,
        lineAnimProgress: 0.5,
        hintPulse: 0,
        animatingConnection: _conn(0, 1, LineStyle.glow, const Color(0xFFFF6B6B)),
        scale: 1.0,
        offset: Offset.zero,
      )));
      await expectLater(
        find.byKey(const Key('canvas')),
        matchesGoldenFile('goldens/dot_canvas_animating.png'),
      );
    });
  });
}
