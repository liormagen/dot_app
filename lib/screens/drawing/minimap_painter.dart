import 'package:flutter/material.dart';

import '../../models/dot_model.dart';
import '../../models/drawing_model.dart';
import 'drawing_types.dart';
import 'zoom_math.dart';

const _kGreen = Color(0xFF2DB84B);
const _kInk   = Color(0xFF1A1A2E);
const _kRed   = Color(0xFFE82D2D);

class MinimapPainter extends CustomPainter {
  const MinimapPainter({
    required this.drawing,
    required this.session,
    required this.fitScale,
    required this.fitOffset,
    required this.zoomMatrix,
    required this.viewportSize,
  });

  final DrawingModel drawing;
  final DrawingSessionState session;
  final double fitScale;
  final Offset fitOffset;
  final Matrix4 zoomMatrix;
  final Size viewportSize;

  static const double w = 160;
  static const double h = 120;

  Offset _toMinimap(Offset p) =>
      Offset(p.dx * (w / viewportSize.width), p.dy * (h / viewportSize.height));

  Offset _dotToWidget(DotModel d) =>
      Offset(d.x * fitScale + fitOffset.dx, d.y * fitScale + fitOffset.dy);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = Colors.white,
    );

    final connPaint = Paint()
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final conn in session.connections) {
      connPaint.color = conn.color;
      canvas.drawLine(
        _toMinimap(_dotToWidget(conn.from)),
        _toMinimap(_dotToWidget(conn.to)),
        connPaint,
      );
    }

    final connectedIds = <int>{
      for (final c in session.connections) ...[c.from.id, c.to.id],
    };
    for (final dot in drawing.dots) {
      canvas.drawCircle(
        _toMinimap(_dotToWidget(dot)),
        2.0,
        Paint()
          ..color = connectedIds.contains(dot.id)
              ? _kGreen
              : _kInk.withValues(alpha: 0.4)
          ..style = PaintingStyle.fill,
      );
    }

    final vpRect = viewportRectFromMatrix(zoomMatrix, viewportSize);
    final rect = Rect.fromPoints(
      _toMinimap(vpRect.topLeft),
      _toMinimap(vpRect.bottomRight),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = _kRed.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = _kRed
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(MinimapPainter old) =>
      old.session != session ||
      old.zoomMatrix != zoomMatrix ||
      old.fitScale != fitScale ||
      old.fitOffset != fitOffset;
}
