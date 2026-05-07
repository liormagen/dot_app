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
    required this.lineAnimProgress,
    required this.hintPulse,
    required this.animatingConnection,
    required this.scale,
    required this.offset,
    this.revealImage,
    this.revealProgress = 0.0,
    this.spinHintProgress = 0.0,
    this.spinHintActive = false,
    this.visibleDotCount = 0,
  });

  final DrawingModel drawing;
  final DrawingSessionState session;
  final double lineAnimProgress;
  final double hintPulse;
  final Connection? animatingConnection;
  final double scale;
  final Offset offset;

  final ui.Image? revealImage;
  final double revealProgress;

  final double spinHintProgress;
  final bool spinHintActive;
  final int visibleDotCount; // 0 = all visible; >0 = max visible dot id

  Offset _toCanvas(DotModel dot) => Offset(
        dot.x * scale + offset.dx,
        dot.y * scale + offset.dy,
      );

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Warm canvas background (feels like paper)
    canvas.drawRect(
      Rect.fromLTWH(offset.dx, offset.dy, drawing.canvasWidth * scale,
          drawing.canvasHeight * scale),
      Paint()..color = const Color(0xFFFFF9F0),
    );

    // 2. Completed connections
    for (int i = 0; i < session.connections.length; i++) {
      _drawConnection(canvas, session.connections[i], i, 1.0);
    }

    // 3. Animating connection
    if (animatingConnection != null) {
      _drawConnection(canvas, animatingConnection!,
          session.connections.length, lineAnimProgress);
    }

    // 4. Colored image reveal (layered over lines, beneath dots)
    if (revealImage != null && revealProgress > 0) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: revealProgress);
      final src = Rect.fromLTWH(
          0, 0, revealImage!.width.toDouble(), revealImage!.height.toDouble());
      final dst = Rect.fromLTWH(offset.dx, offset.dy,
          drawing.canvasWidth * scale, drawing.canvasHeight * scale);
      canvas.saveLayer(dst, paint);
      canvas.drawImageRect(revealImage!, src, dst, Paint());
      canvas.restore();
    }

    // 5. Dots (always on top) — filtered by visibleDotCount in progressive reveal
    final dotsToRender = visibleDotCount > 0
        ? drawing.dots.where((d) => d.id <= visibleDotCount).toList()
        : drawing.dots;
    for (final dot in dotsToRender) {
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
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    switch (conn.style) {
      case LineStyle.wave:
        final path = Path()..moveTo(from.dx, from.dy);
        final mid = Offset((from.dx + end.dx) / 2, (from.dy + end.dy) / 2);
        final ctrl = Offset(mid.dx + 22, mid.dy - 22);
        path.quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
        canvas.drawPath(path, paint);
        break;
      case LineStyle.glow:
        final glowPaint = Paint()
          ..color = conn.color.withValues(alpha: 0.38)
          ..strokeWidth = 16.0
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
        canvas.drawLine(from, end, glowPaint);
        canvas.drawLine(from, end, paint);
        break;
      case LineStyle.sparkle:
        canvas.drawLine(from, end, paint);
        if (progress > 0.5) {
          _drawStarParticles(canvas, Offset.lerp(from, end, 0.5)!, conn.color);
        }
        break;
    }
  }

  void _drawStarParticles(Canvas canvas, Offset center, Color color) {
    final rand = Random(center.dx.toInt() ^ center.dy.toInt());
    final paint = Paint()
      ..color = color.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 5; i++) {
      final angle = rand.nextDouble() * 2 * pi;
      final dist = 9 + rand.nextDouble() * 9;
      final pos = center + Offset(cos(angle) * dist, sin(angle) * dist);
      canvas.drawCircle(pos, 3.5, paint);
    }
  }

  void _drawDot(Canvas canvas, DotModel dot) {
    final pos = _toCanvas(dot);
    final isConnected = session.connections.any(
      (c) => c.from.id == dot.id || c.to.id == dot.id,
    );
    final isAnimating = animatingConnection?.to.id == dot.id;
    final isNext = dot.id == session.nextExpectedDotId;
    final isHinting = dot.id == session.hintingDotId;

    final radius = 15.0 * scale.clamp(0.5, 1.5);

    // Idle-hint pulse ring (gold)
    if (isHinting) {
      final pulsePaint = Paint()
        ..color = const Color(0xFFFFD93D).withValues(alpha: 0.55 * hintPulse)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
          pos, radius * 2.4 * (0.8 + hintPulse * 0.4), pulsePaint);
    }

    // Wrong-tap spinning comet orbit
    if (isNext && spinHintActive && !isConnected) {
      _drawSpinningComet(canvas, pos, radius);
    }

    // Next dot highlight ring
    if (isNext && !isConnected) {
      // Outer soft glow
      canvas.drawCircle(
        pos,
        radius * 1.85,
        Paint()
          ..color = const Color(0xFF6C48FF).withValues(alpha: 0.18)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      // Inner highlight ring
      canvas.drawCircle(
        pos,
        radius * 1.55,
        Paint()
          ..color = const Color(0xFF6C48FF).withValues(alpha: 0.22)
          ..style = PaintingStyle.fill,
      );
    }

    // Drop shadow for depth
    canvas.drawCircle(
      pos + Offset(0, radius * 0.25),
      radius * 0.9,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Dot fill
    if (isConnected || isAnimating) {
      // Mint gradient fill for connected dots
      const gradient = RadialGradient(
        center: Alignment(-0.3, -0.4),
        radius: 0.9,
        colors: [
          Color(0xFF8DE88B),
          Color(0xFF6BCB77),
        ],
      );
      final rect = Rect.fromCircle(center: pos, radius: radius);
      canvas.drawCircle(
        pos,
        radius,
        Paint()..shader = gradient.createShader(rect),
      );
    } else {
      // White fill with subtle warm tint
      canvas.drawCircle(pos, radius, Paint()..color = Colors.white);
    }

    // Border
    final borderColor = (isConnected || isAnimating)
        ? const Color(0xFF4CAF50)
        : const Color(0xFF6C48FF);
    canvas.drawCircle(
      pos,
      radius,
      Paint()
        ..color = borderColor
        ..strokeWidth = 2.8
        ..style = PaintingStyle.stroke,
    );

    // White highlight on top-left of dot
    canvas.drawCircle(
      pos + Offset(-radius * 0.28, -radius * 0.32),
      radius * 0.28,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );

    // Label
    if (isConnected || isAnimating) {
      _drawText(canvas, '✓', pos, Colors.white, radius * 1.1);
    } else {
      _drawText(
          canvas, '${dot.id}', pos, const Color(0xFF4B35CC), radius * 1.1);
    }
  }

  /// Draws an orange comet arc orbiting the dot — the wrong-tap hint.
  void _drawSpinningComet(Canvas canvas, Offset center, double dotRadius) {
    final orbitRadius = dotRadius * 2.8;
    const arcSweep = pi * 0.75;
    final startAngle = spinHintProgress * 2 * pi;

    const segments = 28;
    for (int i = 0; i < segments; i++) {
      final frac = i / segments;
      final angle = startAngle + frac * arcSweep;
      final x = center.dx + cos(angle) * orbitRadius;
      final y = center.dy + sin(angle) * orbitRadius;
      final alpha = frac * 0.75;
      final strokeWidth = 1.5 + frac * 4.5;
      canvas.drawCircle(
        Offset(x, y),
        strokeWidth / 2,
        Paint()
          ..color = const Color(0xFFEA580C).withValues(alpha: alpha)
          ..style = PaintingStyle.fill,
      );
    }

    // Comet head — bright glowing dot
    final headAngle = startAngle + arcSweep;
    final headX = center.dx + cos(headAngle) * orbitRadius;
    final headY = center.dy + sin(headAngle) * orbitRadius;

    canvas.drawCircle(
      Offset(headX, headY),
      8,
      Paint()
        ..color = const Color(0xFFFFD93D).withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawCircle(
      Offset(headX, headY),
      4.5,
      Paint()..color = const Color(0xFFFFD93D),
    );
  }

  void _drawText(
      Canvas canvas, String text, Offset center, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w700,
          fontFamily: 'Fredoka',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(DotCanvasPainter old) => true;
}
