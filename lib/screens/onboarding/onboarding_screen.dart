import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../services/progress_service.dart';
import '../../widgets/confetti_overlay.dart';

// ---------------------------------------------------------------------------
// Design tokens
// ---------------------------------------------------------------------------
const _kPrimary = Color(0xFF6C48FF);
const _kCoral = Color(0xFFFF6B6B);
const _kGold = Color(0xFFFFD93D);
const _kMint = Color(0xFF6BCB77);
const _kNight = Color(0xFF1A0E3F);
const _kCanvas = Color(0xFFFFF9F0);

// ---------------------------------------------------------------------------
// Tutorial dot positions (relative to canvas)
// ---------------------------------------------------------------------------
const _tutorialDots = [
  Offset(0.30, 0.40),
  Offset(0.62, 0.35),
  Offset(0.50, 0.65),
];

enum _OnboardingStep {
  handMoving,  // Automated: hand taps dot 1
  waitForDot2, // Child must tap dot 2
  waitForDot3, // Child must tap dot 3
  complete,
}

// ---------------------------------------------------------------------------
// OnboardingScreen
// ---------------------------------------------------------------------------
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  late AnimationController _handController;
  late Animation<double> _handScale;

  late AnimationController _completionController;
  late Animation<double> _completionFade;
  late Animation<double> _starScale;

  _OnboardingStep _step = _OnboardingStep.handMoving;
  final List<int> _connectedDotIndices = [];
  final GlobalKey<ConfettiOverlayState> _confettiKey = GlobalKey();

  Offset _handRelPos = _tutorialDots[0];
  bool _handVisible = true;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _handController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _handScale = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _handController, curve: Curves.easeInOut),
    );

    _completionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _completionFade = CurvedAnimation(
        parent: _completionController, curve: Curves.easeOut);
    _starScale = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
          parent: _completionController, curve: Curves.elasticOut),
    );

    Future.delayed(const Duration(milliseconds: 600), _runAutoStep);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _handController.dispose();
    _completionController.dispose();
    super.dispose();
  }

  Future<void> _runAutoStep() async {
    if (!mounted) return;
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

    final int targetIndex = _step == _OnboardingStep.waitForDot2 ? 1 : 2;
    final Offset dotPos = Offset(
      _tutorialDots[targetIndex].dx * canvasSize.width,
      _tutorialDots[targetIndex].dy * canvasSize.height,
    );

    if ((tapPosition - dotPos).distance <= 48.0) {
      _confettiKey.currentState?.triggerBurst(tapPosition);

      setState(() {
        _connectedDotIndices.add(targetIndex);
        if (_step == _OnboardingStep.waitForDot2) {
          _step = _OnboardingStep.waitForDot3;
        } else {
          _step = _OnboardingStep.complete;
          _completionController.forward();
          _finishOnboarding();
        }
      });
    }
  }

  void _finishOnboarding() {
    Future.delayed(const Duration(milliseconds: 1800), () async {
      if (!mounted) return;
      await ref.read(progressProvider.notifier).completeOnboarding();
      if (!mounted) return;
      context.go('/welcome');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kCanvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final canvasSize =
                Size(constraints.maxWidth, constraints.maxHeight);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _handleTap(d.localPosition, canvasSize),
              child: Stack(
                children: [
                  // Canvas background texture
                  Positioned.fill(child: _CanvasBackground()),
                  // Dot canvas painter
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
                  // Top instruction clay pill
                  Positioned(
                    top: 24,
                    left: 24,
                    right: 24,
                    child: Center(child: _buildInstructionPill()),
                  ),
                  // Confetti
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
      child: AnimatedBuilder(
        animation: _handScale,
        builder: (_, child) =>
            Transform.scale(scale: _handScale.value, child: child),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kCoral,
            border:
                Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: _kCoral.withValues(alpha: 0.55),
                blurRadius: 20,
                spreadRadius: 4,
              ),
              const BoxShadow(
                color: Color(0x80B03030),
                blurRadius: 0,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.touch_app_rounded,
              color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildInstructionPill() {
    final l10n = AppLocalizations.of(context)!;
    final String text;
    switch (_step) {
      case _OnboardingStep.handMoving:
        text = l10n.watchCarefully;
        break;
      case _OnboardingStep.waitForDot2:
        text = l10n.nowTapDot2;
        break;
      case _OnboardingStep.waitForDot3:
        text = l10n.greatTapDot3;
        break;
      case _OnboardingStep.complete:
        text = l10n.amazingYouDidIt;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: BoxDecoration(
        color: _kPrimary,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.35), width: 2),
        boxShadow: [
          const BoxShadow(
            color: Color(0xFF3B1FCC),
            blurRadius: 0,
            offset: Offset(0, 5),
          ),
          BoxShadow(
            color: _kPrimary.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.25),
            blurRadius: 0,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(fontFamily: 'Fredoka',
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildCompletion() {
    return FadeTransition(
      opacity: _completionFade,
      child: Container(
        color: _kNight.withValues(alpha: 0.82),
        child: Stack(
          children: [
            // Twinkling stars
            Positioned.fill(child: CustomPaint(painter: _StarPainter())),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _starScale,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: _kGold,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          const BoxShadow(
                            color: Color(0xFF8B6914),
                            blurRadius: 0,
                            offset: Offset(0, 6),
                          ),
                          BoxShadow(
                            color: _kGold.withValues(alpha: 0.6),
                            blurRadius: 30,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.star_rounded,
                          color: _kNight, size: 60),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppLocalizations.of(context)!.youreReady,
                    style: TextStyle(fontFamily: 'Fredoka',
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Canvas warm background
// ---------------------------------------------------------------------------
class _CanvasBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CanvasPainter());
  }
}

class _CanvasPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Warm paper fill
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _kCanvas,
    );
    // Subtle grid lines (like a notebook)
    final linePaint = Paint()
      ..color = const Color(0xFFE8E0D0).withValues(alpha: 0.6)
      ..strokeWidth = 0.8;
    const spacing = 48.0;
    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(_CanvasPainter _) => false;
}

// ---------------------------------------------------------------------------
// Star painter for completion overlay
// ---------------------------------------------------------------------------
class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Object().hashCode;
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 60; i++) {
      final x = ((rng * (i + 1) * 9301 + 49297) % 233280) /
          233280.0 *
          size.width;
      final y = ((rng * (i + 1) * 6731 + 31337) % 233280) /
          233280.0 *
          size.height;
      final r = 0.8 + (i % 4) * 0.5;
      final opacity = 0.2 + (i % 5) * 0.12;
      paint.color = Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_StarPainter _) => false;
}

// ---------------------------------------------------------------------------
// Dot canvas painter
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
    Color(0xFFFF6B6B), // coral
    Color(0xFFFFD93D), // gold
    Color(0xFF6BCB77), // mint
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final positions = _tutorialDots
        .map((r) => Offset(r.dx * size.width, r.dy * size.height))
        .toList();

    // Connecting lines
    final linePaint = Paint()
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < connectedDotIndices.length - 1; i++) {
      final color = _lineColors[i % _lineColors.length];
      // Glow pass
      linePaint
        ..color = color.withValues(alpha: 0.3)
        ..strokeWidth = 14;
      canvas.drawLine(
        positions[connectedDotIndices[i]],
        positions[connectedDotIndices[i + 1]],
        linePaint,
      );
      // Solid pass
      linePaint
        ..color = color
        ..strokeWidth = 5;
      canvas.drawLine(
        positions[connectedDotIndices[i]],
        positions[connectedDotIndices[i + 1]],
        linePaint,
      );
    }

    // Dots
    for (int i = 0; i < 3; i++) {
      final pos = positions[i];
      final isConnected = connectedDotIndices.contains(i);
      final nextIdx = _nextExpectedIndex();
      final isNext = i == nextIdx;

      // Outer pulse ring for next dot
      if (isNext) {
        canvas.drawCircle(
          pos,
          32 * pulseValue,
          Paint()
            ..color = _kGold.withValues(alpha: 0.3)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          pos,
          28,
          Paint()
            ..color = _kGold.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }

      // Drop shadow
      canvas.drawCircle(
        pos.translate(0, 4),
        22,
        Paint()
          ..color = const Color(0x303B2099)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      // Fill
      canvas.drawCircle(
        pos,
        22,
        Paint()
          ..color = isConnected ? _kMint : Colors.white
          ..style = PaintingStyle.fill,
      );

      // Border
      canvas.drawCircle(
        pos,
        22,
        Paint()
          ..color = isConnected ? const Color(0xFF4CAF50) : _kPrimary
          ..strokeWidth = 3.5
          ..style = PaintingStyle.stroke,
      );

      // Label / checkmark
      final label = isConnected ? '✓' : '${i + 1}';
      final labelColor = isConnected ? Colors.white : _kPrimary;
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
