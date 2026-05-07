import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dot_story/screens/drawing/zoom_math.dart';

void main() {
  group('zoomMatrixCenteredOn', () {
    test('identity at scale 1.0', () {
      final m = zoomMatrixCenteredOn(1.0, 100, 100);
      expect(m.entry(0, 0), closeTo(1.0, 1e-9));
      expect(m.entry(1, 1), closeTo(1.0, 1e-9));
      expect(m.entry(0, 3), closeTo(0.0, 1e-9));
      expect(m.entry(1, 3), closeTo(0.0, 1e-9));
    });

    test('scale 2 around center (100,100): center maps to itself', () {
      final m = zoomMatrixCenteredOn(2.0, 100, 100);
      expect(m.entry(0, 0), closeTo(2.0, 1e-9));
      expect(m.entry(1, 1), closeTo(2.0, 1e-9));
      // transformed x = 2*100 + tx = 100  →  tx = -100
      expect(m.entry(0, 3), closeTo(-100.0, 1e-9));
      expect(m.entry(1, 3), closeTo(-100.0, 1e-9));
    });

    test('scale 3 around asymmetric center (200,150)', () {
      final m = zoomMatrixCenteredOn(3.0, 200, 150);
      // tx = cx - s*cx = 200 - 600 = -400
      expect(m.entry(0, 3), closeTo(-400.0, 1e-9));
      // ty = cy - s*cy = 150 - 450 = -300
      expect(m.entry(1, 3), closeTo(-300.0, 1e-9));
    });

    test('center point is invariant under the transform', () {
      const cx = 512.0;
      const cy = 384.0;
      const s = 2.5;
      final m = zoomMatrixCenteredOn(s, cx, cy);
      final transformed = MatrixUtils.transformPoint(m, const Offset(cx, cy));
      expect(transformed.dx, closeTo(cx, 1e-6));
      expect(transformed.dy, closeTo(cy, 1e-6));
    });
  });

  group('snapToDotMatrix', () {
    test('dot placed at viewport center', () {
      // scale 2, dot at (50,75), viewport 200×300
      // expected: dot (50,75) maps to (100,150)
      const s = 2.0;
      const dotX = 50.0;
      const dotY = 75.0;
      const W = 200.0;
      const H = 300.0;
      final m = snapToDotMatrix(s, dotX, dotY, W, H);
      final pos = MatrixUtils.transformPoint(m, const Offset(dotX, dotY));
      expect(pos.dx, closeTo(W / 2, 1e-6));
      expect(pos.dy, closeTo(H / 2, 1e-6));
    });

    test('dot at canvas origin maps to top-left at scale 1', () {
      // scale 1, dot at (0,0), viewport 400×600
      // tx = 200-0 = 200, ty = 300-0 = 300
      final m = snapToDotMatrix(1.0, 0, 0, 400, 600);
      expect(m.entry(0, 3), closeTo(200.0, 1e-9));
      expect(m.entry(1, 3), closeTo(300.0, 1e-9));
    });

    test('scale entry is set correctly', () {
      final m = snapToDotMatrix(3.5, 100, 100, 800, 600);
      expect(m.entry(0, 0), closeTo(3.5, 1e-9));
      expect(m.entry(1, 1), closeTo(3.5, 1e-9));
    });
  });

  group('viewportRectFromMatrix', () {
    test('identity transform covers full canvas', () {
      const size = Size(400, 300);
      final rect = viewportRectFromMatrix(Matrix4.identity(), size);
      expect(rect.left, closeTo(0, 1e-6));
      expect(rect.top, closeTo(0, 1e-6));
      expect(rect.right, closeTo(400, 1e-6));
      expect(rect.bottom, closeTo(300, 1e-6));
    });

    test('scale 2 at origin halves the visible area', () {
      final m = Matrix4.identity()..setEntry(0, 0, 2)..setEntry(1, 1, 2);
      const size = Size(200, 100);
      final rect = viewportRectFromMatrix(m, size);
      expect(rect.width, closeTo(100, 1e-6));
      expect(rect.height, closeTo(50, 1e-6));
    });

    test('centered zoom: viewport rect is centered on canvas center', () {
      const s = 2.0;
      const cx = 400.0;
      const cy = 300.0;
      final m = zoomMatrixCenteredOn(s, cx, cy);
      final rect = viewportRectFromMatrix(m, const Size(800, 600));
      expect(rect.left, closeTo(cx / 2, 1e-6));
      expect(rect.top, closeTo(cy / 2, 1e-6));
      expect(rect.right, closeTo(cx + cx / 2, 1e-6));
      expect(rect.bottom, closeTo(cy + cy / 2, 1e-6));
    });
  });
}
