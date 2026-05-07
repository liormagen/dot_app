import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dot_story/models/dot_model.dart';
import 'package:dot_story/models/drawing_model.dart';
import 'package:dot_story/screens/drawing/drawing_types.dart';
import 'package:dot_story/screens/drawing/minimap_painter.dart';

// ---------------------------------------------------------------------------
// Fixtures (same canvas as dot_canvas tests)
// ---------------------------------------------------------------------------

final _kDots = [
  const DotModel(id: 1, x: 80,  y: 80),
  const DotModel(id: 2, x: 240, y: 80),
  const DotModel(id: 3, x: 320, y: 200),
  const DotModel(id: 4, x: 160, y: 240),
  const DotModel(id: 5, x: 80,  y: 200),
];

final _kDrawing = DrawingModel(
  id: 'minimap-test',
  names: const {'en': 'Minimap Test'},
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

// Fit: canvas fills a 800×600 viewport at scale=1.5, offset=(100,75)
const _kFitScale = 1.5;
const _kFitOffset = Offset(100, 75);
const _kViewportSize = Size(800, 600);

Widget _pump(MinimapPainter painter) {
  return MaterialApp(
    home: RepaintBoundary(
      key: const Key('minimap'),
      child: SizedBox(
        width: MinimapPainter.w,
        height: MinimapPainter.h,
        child: CustomPaint(painter: painter),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MinimapPainter golden', () {
    testWidgets('no connections — all dots unconnected, viewport at identity',
        (tester) async {
      await tester.pumpWidget(_pump(MinimapPainter(
        drawing: _kDrawing,
        session: DrawingSessionState.initial(1),
        fitScale: _kFitScale,
        fitOffset: _kFitOffset,
        zoomMatrix: Matrix4.identity(),
        viewportSize: _kViewportSize,
      )));
      await expectLater(
        find.byKey(const Key('minimap')),
        matchesGoldenFile('goldens/minimap_no_connections.png'),
      );
    });

    testWidgets('partial connections — two lines drawn', (tester) async {
      final connections = [
        Connection(
          from: _kDots[0],
          to: _kDots[1],
          style: LineStyle.sparkle,
          color: const Color(0xFFFF6B6B),
        ),
        Connection(
          from: _kDots[1],
          to: _kDots[2],
          style: LineStyle.wave,
          color: const Color(0xFF6C48FF),
        ),
      ];
      final session = DrawingSessionState(
        nextExpectedDotId: 3,
        connections: connections,
        isComplete: false,
      );
      await tester.pumpWidget(_pump(MinimapPainter(
        drawing: _kDrawing,
        session: session,
        fitScale: _kFitScale,
        fitOffset: _kFitOffset,
        zoomMatrix: Matrix4.identity(),
        viewportSize: _kViewportSize,
      )));
      await expectLater(
        find.byKey(const Key('minimap')),
        matchesGoldenFile('goldens/minimap_partial.png'),
      );
    });

    testWidgets('zoomed in — viewport rect visible inside minimap',
        (tester) async {
      // Zoom 2× centred on canvas centre (200,150 in canvas coords)
      final zoom = Matrix4.identity()
        ..setEntry(0, 0, 2.0)
        ..setEntry(1, 1, 2.0)
        ..setEntry(0, 3, -200.0)
        ..setEntry(1, 3, -150.0);
      await tester.pumpWidget(_pump(MinimapPainter(
        drawing: _kDrawing,
        session: DrawingSessionState.initial(1),
        fitScale: _kFitScale,
        fitOffset: _kFitOffset,
        zoomMatrix: zoom,
        viewportSize: _kViewportSize,
      )));
      await expectLater(
        find.byKey(const Key('minimap')),
        matchesGoldenFile('goldens/minimap_zoomed.png'),
      );
    });
  });
}
