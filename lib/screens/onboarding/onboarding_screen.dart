import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/progress_service.dart';
import '../../widgets/confetti_overlay.dart';

// Three tutorial dots at fixed relative positions (fraction of canvas size)
const _tutorialDots = [
  Offset(0.30, 0.40),
  Offset(0.62, 0.35),
  Offset(0.50, 0.65),
];

enum _OnboardingStep {
  handMoving, // Automated: hand taps dot 1
  waitForDot2, // Child must tap dot 2
  waitForDot3, // Child must tap dot 3
  complete,
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  _OnboardingStep _step = _OnboardingStep.handMoving;

  // Which dot indices have been "connected" (as start points)
  final List<int> _connectedDotIndices = [];

  final GlobalKey<ConfettiOverlayState> _confettiKey = GlobalKey();

  // Hand position (relative to canvas) for animated hand
  Offset _handRelPos = _tutorialDots[0];
  bool _handVisible = true;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Run automated first step after a short delay
    Future.delayed(const Duration(milliseconds: 600), _runAutoStep);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _runAutoStep() async {
    if (!mounted) return;
    // Simulate hand tapping dot 1
    setState(() {
      _handRelPos = _tutorialDots[0];
      _connectedDotIndices.add(0);
      _step = _OnboardingStep.waitForDot2;
    });
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _handVisible = false);
  }

  void _handleTap(Offset tapPosition, Size canvasSize) {
    if (_step == _OnboardingStep.handMoving) return;
    if (_step == _OnboardingStep.complete) return;

    final int targetIndex =
        _step == _OnboardingStep.waitForDot2 ? 1 : 2;

    final Offset dotPos = Offset(
      _tutorialDots[targetIndex].dx * canvasSize.width,
      _tutorialDots[targetIndex].dy * canvasSize.height,
    );

    if ((tapPosition - dotPos).distance <= 44.0) {
      _confettiKey.currentState?.triggerBurst(tapPosition);

      setState(() {
        _connectedDotIndices.add(targetIndex);
        if (_step == _OnboardingStep.waitForDot2) {
          _step = _OnboardingStep.waitForDot3;
        } else {
          _step = _OnboardingStep.complete;
          _finishOnboarding();
        }
      });
    }
    // Wrong tap: silent ignore
  }

  void _finishOnboarding() {
    Future.delayed(const Duration(milliseconds: 1500), () async {
      if (!mounted) return;
      await ref.read(progressProvider.notifier).completeOnboarding();
      if (!mounted) return;
      context.go('/stories');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4FF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final canvasSize =
                Size(constraints.maxWidth, constraints.maxHeight);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) =>
                  _handleTap(d.localPosition, canvasSize),
              child: Stack(
                children: [
                  // Painting canvas
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, __) => CustomPaint(
                      size: canvasSize,
                      painter: _OnboardingPainter(
                        connectedDotIndices: _connectedDotIndices,
                        step: _step,
                        pulseValue: _pulseAnim.value,
                      ),
                    ),
                  ),
                  // Animated hand indicator
                  if (_handVisible) _buildHand(canvasSize),
                  // Top instruction banner
                  Positioned(
                    top: 24,
                    left: 24,
                    right: 24,
                    child: _buildInstruction(),
                  ),
                  // Confetti overlay
                  Positioned.fill(
                    child: ConfettiOverlay(key: _confettiKey),
                  ),
                  // Completion overlay
                  if (_step == _OnboardingStep.complete)
                    Positioned.fill(child: _buildCompletion()),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHand(Size canvasSize) {
    final pos = Offset(
      _handRelPos.dx * canvasSize.width - 24,
      _handRelPos.dy * canvasSize.height - 24,
    );
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.orange.withOpacity(0.9),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.5),
              blurRadius: 16,
              spreadRadius: 4,
            ),
          ],
        ),
        child: const Icon(Icons.touch_app, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildInstruction() {
    final String text;
    switch (_step) {
      case _OnboardingStep.handMoving:
        text = 'Watch carefully!';
        break;
      case _OnboardingStep.waitForDot2:
        text = 'Now tap dot 2!';
        break;
      case _OnboardingStep.waitForDot3:
        text = 'Great! Tap dot 3!';
        break;
      case _OnboardingStep.complete:
        text = 'Amazing! You did it!';
        break;
    }
    return Center(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF6B4EFF),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCompletion() {
    return Container(
      color: Colors.black.withOpacity(0.35),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star, color: Colors.yellow, size: 100),
            SizedBox(height: 16),
            Text(
              "You're ready!",
              style: TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------
class _OnboardingPainter extends CustomPainter {
  _OnboardingPainter({
    required this.connectedDotIndices,
    required this.step,
    required this.pulseValue,
  });

  final List<int> connectedDotIndices;
  final _OnboardingStep step;
  final double pulseValue;

  static const _lineColors = [
    Color(0xFFFF6B6B),
    Color(0xFFFFD93D),
    Color(0xFF6BCB77),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final positions = _tutorialDots
        .map((r) => Offset(r.dx * size.width, r.dy * size.height))
        .toList();

    // Draw connecting lines between consecutive connected dots
    final linePaint = Paint()
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < connectedDotIndices.length - 1; i++) {
      linePaint.color = _lineColors[i % _lineColors.length];
      canvas.drawLine(
        positions[connectedDotIndices[i]],
        positions[connectedDotIndices[i + 1]],
        linePaint,
      );
    }

    // Draw each dot
    for (int i = 0; i < 3; i++) {
      final pos = positions[i];
      final isConnected = connectedDotIndices.contains(i);
      final nextIdx = _nextExpectedIndex();
      final isNext = i == nextIdx;

      // Pulse ring for next dot
      if (isNext) {
        final pulsePaint = Paint()
          ..color = const Color(0xFFFFD93D).withOpacity(0.45)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, 28 * pulseValue, pulsePaint);
      }

      // Dot background
      final fillColor = isConnected ? const Color(0xFF6BCB77) : Colors.white;
      canvas.drawCircle(pos, 22, Paint()..color = fillColor);

      // Dot border
      canvas.drawCircle(
        pos,
        22,
        Paint()
          ..color = isConnected
              ? const Color(0xFF4CAF50)
              : const Color(0xFF6B4EFF)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke,
      );

      // Label
      final label = isConnected ? '✓' : '${i + 1}';
      final labelColor =
          isConnected ? Colors.white : const Color(0xFF6B4EFF);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: labelColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  int _nextExpectedIndex() {
    switch (step) {
      case _OnboardingStep.waitForDot2:
        return 1;
      case _OnboardingStep.waitForDot3:
        return 2;
      default:
        return -1;
    }
  }

  @override
  bool shouldRepaint(_OnboardingPainter old) => true;
}
