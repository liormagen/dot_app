import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/drawing_model.dart';
import '../../models/dot_model.dart';
import 'drawing_types.dart';

class DotCanvasPainter extends CustomPainter {
  DotCanvasPainter({
    required this.drawing,
    required this.session,
    required this.outlineImage,
    required this.lineAnimProgress,
    required this.hintPulse,
    required this.animatingConnection,
    required this.scale,
    required this.offset,
  });

  final DrawingModel drawing;
  final DrawingSessionState session;
  final ui.Image? outlineImage;
  final double lineAnimProgress; // 0..1 for current animating line
  final double hintPulse; // 0..1 pulse for hint dot
  final Connection? animatingConnection;
  final double scale;
  final Offset offset;

  /// Convert drawing coordinates → canvas coordinates
  Offset _toCanvas(DotModel dot) {
    return Offset(
      dot.x * scale + offset.dx,
      dot.y * scale + offset.dy,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Background / outline image
    if (outlineImage != null) {
      final src = Rect.fromLTWH(0, 0, outlineImage!.width.toDouble(),
          outlineImage!.height.toDouble());
      final dst = Rect.fromLTWH(
          offset.dx, offset.dy, drawing.canvasWidth * scale,
          drawing.canvasHeight * scale);
      canvas.drawImageRect(outlineImage!, src, dst, Paint());
    } else {
      canvas.drawRect(
        Rect.fromLTWH(offset.dx, offset.dy, drawing.canvasWidth * scale,
            drawing.canvasHeight * scale),
        Paint()..color = Colors.grey.shade200,
      );
    }

    // 2. Draw completed connections
    for (int i = 0; i < session.connections.length; i++) {
      final conn = session.connections[i];
      _drawConnection(canvas, conn, i, 1.0);
    }

    // 3. Draw animating connection
    if (animatingConnection != null) {
      _drawConnection(canvas, animatingConnection!,
          session.connections.length, lineAnimProgress);
    }

    // 4. Draw dots
    for (final dot in drawing.dots) {
      _drawDot(canvas, dot);
    }
  }

  void _drawConnection(
      Canvas canvas, Connection conn, int index, double progress) {
    final from = _toCanvas(conn.from);
    final to = _toCanvas(conn.to);
    final end = Offset.lerp(from, to, progress)!;

    final paint = Paint()
      ..color = conn.color
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    switch (conn.style) {
      case LineStyle.wave:
        final path = Path()..moveTo(from.dx, from.dy);
        final mid = Offset((from.dx + end.dx) / 2, (from.dy + end.dy) / 2);
        final ctrl = Offset(mid.dx + 20, mid.dy - 20);
        path.quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
        canvas.drawPath(path, paint);
        break;
      case LineStyle.glow:
        // Glow: blurred + sharp
        final glowPaint = Paint()
          ..color = conn.color.withOpacity(0.4)
          ..strokeWidth = 14.0
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawLine(from, end, glowPaint);
        canvas.drawLine(from, end, paint);
        break;
      case LineStyle.sparkle:
        canvas.drawLine(from, end, paint);
        // Star particles at the midpoint
        if (progress > 0.5) {
          _drawStarParticles(canvas, Offset.lerp(from, end, 0.5)!, conn.color);
        }
        break;
    }
  }

  void _drawStarParticles(Canvas canvas, Offset center, Color color) {
    final rand = Random(center.dx.toInt() ^ center.dy.toInt());
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 4; i++) {
      final angle = rand.nextDouble() * 2 * pi;
      final dist = 8 + rand.nextDouble() * 8;
      final pos = center + Offset(cos(angle) * dist, sin(angle) * dist);
      canvas.drawCircle(pos, 3, paint);
    }
  }

  void _drawDot(Canvas canvas, DotModel dot) {
    final pos = _toCanvas(dot);
    final isConnected = session.connections.any(
      (c) => c.from.id == dot.id || c.to.id == dot.id,
    );
    // Also consider animating connection
    final isAnimating = animatingConnection?.to.id == dot.id;
    final isNext = dot.id == session.nextExpectedDotId;
    final isHinting = dot.id == session.hintingDotId;

    final radius = 14.0 * scale.clamp(0.5, 1.5);

    // Hint pulse ring
    if (isHinting) {
      final pulsePaint = Paint()
        ..color = const Color(0xFFFFD93D).withOpacity(0.5 * hintPulse)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, radius * 2.2 * (0.8 + hintPulse * 0.4),
          pulsePaint);
    }

    // Next dot highlight ring
    if (isNext && !isConnected) {
      final nextPaint = Paint()
        ..color = const Color(0xFF6B4EFF).withOpacity(0.25)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, radius * 1.6, nextPaint);
    }

    // Dot fill
    Color fillColor;
    if (isConnected || isAnimating) {
      fillColor = const Color(0xFF6BCB77);
    } else if (isNext) {
      fillColor = Colors.white;
    } else {
      fillColor = Colors.white;
    }

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, radius, fillPaint);

    // Border
    final borderColor =
        (isConnected || isAnimating) ? const Color(0xFF4CAF50) : const Color(0xFF6B4EFF);
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(pos, radius, borderPaint);

    // Label
    if (isConnected || isAnimating) {
      _drawText(canvas, '✓', pos, Colors.white, radius * 1.1);
    } else {
      _drawText(canvas, '${dot.id}', pos, const Color(0xFF6B4EFF),
          radius * 1.1);
    }
  }

  void _drawText(
      Canvas canvas, String text, Offset center, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(DotCanvasPainter old) => true;
}
