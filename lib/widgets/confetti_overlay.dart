import 'dart:math';

import 'package:flutter/material.dart';

class _Particle {
  _Particle({
    required this.origin,
    required this.angle,
    required this.speed,
    required this.color,
    required this.size,
    required this.shape, // 0 = rect, 1 = circle
  })  : position = origin,
        opacity = 1.0;

  final Offset origin;
  final double angle;
  final double speed;
  final Color color;
  final double size;
  final int shape;

  Offset position;
  double opacity;

  void update(double dt) {
    const gravity = 400.0;
    final vx = cos(angle) * speed;
    final vy = sin(angle) * speed;
    position = Offset(
      origin.dx + vx * dt,
      origin.dy + vy * dt + 0.5 * gravity * dt * dt,
    );
    opacity = (1.0 - dt / 1.5).clamp(0.0, 1.0);
  }
}

class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key});

  @override
  State<ConfettiOverlay> createState() => ConfettiOverlayState();
}

class ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final Random _rand = Random();

  static const _colors = [
    Color(0xFFFF6B6B),
    Color(0xFFFFD93D),
    Color(0xFF6BCB77),
    Color(0xFF4D96FF),
    Color(0xFFC77DFF),
    Color(0xFFFF9F43),
    Color(0xFFFF6FA8),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addListener(() {
        if (mounted) setState(() {});
      });
  }

  void triggerBurst(Offset position) {
    _particles.clear();
    for (int i = 0; i < 40; i++) {
      final angle = _rand.nextDouble() * 2 * pi;
      final speed = 80 + _rand.nextDouble() * 220;
      _particles.add(
        _Particle(
          origin: position,
          angle: angle,
          speed: speed,
          color: _colors[_rand.nextInt(_colors.length)],
          size: 4 + _rand.nextDouble() * 8,
          shape: _rand.nextInt(2),
        ),
      );
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ConfettiPainter(
          particles: _particles,
          progress: _controller.value,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.particles, required this.progress});

  final List<_Particle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (particles.isEmpty) return;

    final paint = Paint()..isAntiAlias = true;

    for (final p in particles) {
      p.update(progress * 1.5);
      if (p.opacity <= 0) continue;

      paint.color = p.color.withValues(alpha: p.opacity);

      if (p.shape == 0) {
        canvas.save();
        canvas.translate(p.position.dx, p.position.dy);
        canvas.rotate(progress * pi * 2);
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          paint,
        );
        canvas.restore();
      } else {
        canvas.drawCircle(p.position, p.size * 0.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => true;
}
