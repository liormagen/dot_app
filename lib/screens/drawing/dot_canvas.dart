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
    this.dotsOpacity = 1.0,
    this.isEasyMode = false,
    this.squeezedDotId = -1,
    this.squeezeProgress = 0.0,
    this.blinkOpacity = 1.0,
    this.fadingInDotId = -1,
    this.fadingInProgress = 1.0,
    this.fingerPosition,
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
  final double dotsOpacity;

  // Difficulty-driven extras
  final bool isEasyMode;
  final int squeezedDotId;   // dot id currently squishing; -1 = none
  final double squeezeProgress; // 0→1 linear
  final double blinkOpacity; // 1.0 = normal; < 1.0 = blinking (super-hard urgency)
  final int fadingInDotId;      // dot id fading in after reveal; -1 = none
  final double fadingInProgress; // 0→1 while dot fades in
  final Offset? fingerPosition;  // current touch position for proximity wiggle

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
      Paint()..color = const Color(0xFFFFF8E7), // matches _kPaper token
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
    if (dotsOpacity > 0) {
      final dotsToRender = visibleDotCount > 0
          ? drawing.dots.where((d) => d.id <= visibleDotCount).toList()
          : drawing.dots;
      if (dotsOpacity < 1.0) {
        canvas.saveLayer(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..color = Colors.white.withValues(alpha: dotsOpacity),
        );
        for (final dot in dotsToRender) {
          _drawDot(canvas, dot);
        }
        canvas.restore();
      } else {
        for (final dot in dotsToRender) {
          _drawDot(canvas, dot);
        }
      }
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

    // Easy mode dots are 47% larger for small fingers
    // Proximity scale: unconnected dots grow up to 18% when finger is within 80px
    double proxScale = 1.0;
    if (fingerPosition != null && !isConnected && !isAnimating) {
      final dist = (fingerPosition! - pos).distance;
      if (dist < 80.0) {
        proxScale = 1.0 + (1.0 - dist / 80.0) * 0.18;
      }
    }
    final radius = (isEasyMode ? 22.0 : 15.0) * scale.clamp(0.5, 1.5) * proxScale;

    // Fade-in when dot first becomes visible (progressive reveal)
    // Blink urgency for super-hard last 10s — skip during fade-in
    final dotAlpha = (dot.id == fadingInDotId && fadingInProgress < 1.0)
        ? fadingInProgress
        : (!isConnected && !isAnimating && blinkOpacity < 1.0)
            ? blinkOpacity
            : 1.0;

    // ── Halos (drawn outside squeeze transform) ──────────────────────────────

    if (isEasyMode && isNext && !isConnected) {
      // Large warm multi-ring halo — guides very young kids to the next dot
      _drawEasyHalo(canvas, pos, radius, dotAlpha);
    } else if (isHinting) {
      // Normal idle-hint gold pulse
      canvas.drawCircle(
        pos,
        radius * 2.4 * (0.8 + hintPulse * 0.4),
        Paint()
          ..color = const Color(0xFFFFD93D)
              .withValues(alpha: 0.55 * hintPulse * dotAlpha)
          ..style = PaintingStyle.fill,
      );
    }

    // Wrong-tap spinning comet orbit
    if (isNext && spinHintActive && !isConnected) {
      _drawSpinningComet(canvas, pos, radius);
    }

    // Next dot highlight rings (non-easy mode only — easy uses the halo above)
    if (!isEasyMode && isNext && !isConnected) {
      canvas.drawCircle(
        pos,
        radius * 1.85,
        Paint()
          ..color = const Color(0xFF1FA3E8).withValues(alpha: 0.18 * dotAlpha)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(
        pos,
        radius * 1.55,
        Paint()
          ..color = const Color(0xFF1FA3E8).withValues(alpha: 0.22 * dotAlpha)
          ..style = PaintingStyle.fill,
      );
    }

    // ── Squeeze / squish transform (dot core only) ────────────────────────────
    double squishX = 1.0, squishY = 1.0;
    if (squeezedDotId == dot.id && squeezeProgress > 0 && squeezeProgress < 1.0) {
      final t = squeezeProgress;
      if (t < 0.28) {
        // Quick squish inward: x widens, y squashes
        final p = t / 0.28;
        squishX = 1.0 + p * 0.24;
        squishY = 1.0 - p * 0.30;
      } else {
        // Spring back with damped oscillation
        final p = (t - 0.28) / 0.72;
        final damped = exp(-p * 5.5) * cos(p * pi * 3.2);
        squishX = 1.0 + damped * 0.24;
        squishY = 1.0 - damped * 0.30;
      }
    }
    final doTransform = (squishX - 1.0).abs() > 0.001 || (squishY - 1.0).abs() > 0.001;
    if (doTransform) {
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.scale(squishX, squishY);
      canvas.translate(-pos.dx, -pos.dy);
    }

    // Drop shadow for depth
    canvas.drawCircle(
      pos + Offset(0, radius * 0.25),
      radius * 0.9,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12 * dotAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Dot fill
    if (isConnected || isAnimating) {
      const gradient = RadialGradient(
        center: Alignment(-0.3, -0.4),
        radius: 0.9,
        colors: [Color(0xFF8DE88B), Color(0xFF6BCB77)],
      );
      final rect = Rect.fromCircle(center: pos, radius: radius);
      canvas.drawCircle(pos, radius, Paint()..shader = gradient.createShader(rect));
    } else {
      canvas.drawCircle(pos, radius, Paint()..color = Colors.white.withValues(alpha: dotAlpha));
    }

    // Border — on-palette colors: green when done, blue when idle
    final borderColor =
        (isConnected || isAnimating) ? const Color(0xFF2DB84B) : const Color(0xFF1FA3E8);
    canvas.drawCircle(
      pos,
      radius,
      Paint()
        ..color = borderColor.withValues(alpha: dotAlpha)
        ..strokeWidth = 2.8
        ..style = PaintingStyle.stroke,
    );

    // White highlight (top-left glint)
    canvas.drawCircle(
      pos + Offset(-radius * 0.28, -radius * 0.32),
      radius * 0.28,
      Paint()..color = Colors.white.withValues(alpha: 0.7 * dotAlpha),
    );

    // Label
    if (isConnected || isAnimating) {
      _drawText(canvas, '✓', pos, Colors.white, radius * 1.1);
    } else {
      _drawText(canvas, '${dot.id}', pos,
          const Color(0xFF1A1A2E).withValues(alpha: dotAlpha), radius * 1.1);
    }

    if (doTransform) canvas.restore();
  }

  /// Three warm concentric rings that pulse toward the dot — holds young
  /// children's hands and guides their finger to the right spot.
  void _drawEasyHalo(Canvas canvas, Offset pos, double radius, double alpha) {
    // Outer soft glow
    canvas.drawCircle(
      pos,
      radius * 4.5 * (0.85 + hintPulse * 0.15),
      Paint()
        ..color = const Color(0xFFFFB347)
            .withValues(alpha: 0.20 * hintPulse * alpha)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );
    // Mid ring
    canvas.drawCircle(
      pos,
      radius * 3.2 * (0.85 + hintPulse * 0.20),
      Paint()
        ..color = const Color(0xFFFFD93D)
            .withValues(alpha: 0.38 * hintPulse * alpha)
        ..style = PaintingStyle.fill,
    );
    // Inner ring
    canvas.drawCircle(
      pos,
      radius * 2.2 * (0.88 + hintPulse * 0.18),
      Paint()
        ..color = const Color(0xFFFFD93D)
            .withValues(alpha: 0.58 * hintPulse * alpha)
        ..style = PaintingStyle.fill,
    );
    // Crisp stroke ring — gives the halo a clean visible edge
    canvas.drawCircle(
      pos,
      radius * 2.0,
      Paint()
        ..color = const Color(0xFFFFB347)
            .withValues(alpha: 0.75 * hintPulse * alpha)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke,
    );
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
