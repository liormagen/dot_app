import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/dot_model.dart';
import '../../models/drawing_model.dart';
import '../../services/asset_service.dart';
import '../../services/audio_service.dart';
import '../../services/progress_service.dart';
import '../../widgets/confetti_overlay.dart';
import 'dot_canvas.dart';
import 'drawing_types.dart';
import 'hint_controller.dart';

export 'drawing_types.dart';

// ---------------------------------------------------------------------------
// Toca Boca / Handmade design tokens
// ---------------------------------------------------------------------------
const _kRed = Color(0xFFE82D2D);
const _kYellow = Color(0xFFF5C800);
const _kGreen = Color(0xFF2DB84B);
const _kBlue = Color(0xFF1FA3E8);
const _kInk = Color(0xFF1A1A2E);
const _kPaper = Color(0xFFFFF8E7);

// ---------------------------------------------------------------------------
// Session state
// ---------------------------------------------------------------------------

class DrawingSessionNotifier extends StateNotifier<DrawingSessionState> {
  DrawingSessionNotifier() : super(DrawingSessionState.initial(1));

  void init(int firstDotId) => state = DrawingSessionState.initial(firstDotId);

  void addConnection(Connection conn, int nextDotId, bool complete) {
    state = state.copyWith(
      connections: [...state.connections, conn],
      nextExpectedDotId: nextDotId,
      isComplete: complete,
      clearHint: true,
    );
  }

  void setHintingDot(int? dotId) =>
      state = state.copyWith(hintingDotId: dotId, clearHint: dotId == null);
}

final drawingSessionProvider = StateNotifierProvider.autoDispose<
    DrawingSessionNotifier, DrawingSessionState>(
  (_) => DrawingSessionNotifier(),
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _kLineColors = [
  Color(0xFFFF6B6B), // coral
  Color(0xFF6C48FF), // electric purple
  Color(0xFFFFD93D), // gold
  Color(0xFF6BCB77), // mint
  Color(0xFF4FC3F7), // sky blue
];

LineStyle _styleForIndex(int i) {
  switch (i % 3) {
    case 0:
      return LineStyle.sparkle;
    case 1:
      return LineStyle.wave;
    default:
      return LineStyle.glow;
  }
}

// ---------------------------------------------------------------------------
// DrawingScreen
// ---------------------------------------------------------------------------

class DrawingScreen extends ConsumerStatefulWidget {
  const DrawingScreen({super.key, required this.drawingId});

  final String drawingId;

  @override
  ConsumerState<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends ConsumerState<DrawingScreen>
    with TickerProviderStateMixin {
  DrawingModel? _drawing;
  ui.Image? _coloredImage;
  bool _loading = true;
  String? _error;

  // Line animation
  late AnimationController _lineAnimController;

  // Idle-hint pulse
  late AnimationController _hintPulseController;
  HintController? _hintController;

  // In-place reveal after last dot
  late AnimationController _revealController;
  bool _isRevealing = false;

  // Wrong-tap spinning hint
  late AnimationController _spinController;
  DateTime? _firstWrongTapTime;
  bool _spinHintActive = false;

  Connection? _animatingConnection;
  final GlobalKey<ConfettiOverlayState> _confettiKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _lineAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
        if (mounted) setState(() {});
      });

    _hintPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addStatusListener((status) {
        if (!mounted) return;
        if (status == AnimationStatus.completed) {
          _hintPulseController.reverse();
        } else if (status == AnimationStatus.dismissed &&
            ref.read(drawingSessionProvider).hintingDotId != null) {
          _hintPulseController.forward();
        }
      });

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )
      ..addListener(() {
        if (mounted) setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _navigateToCompletion();
        }
      });

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addListener(() {
        if (mounted) setState(() {});
      });

    _loadDrawing();
  }

  Future<void> _loadDrawing() async {
    try {
      final drawing =
          await ref.read(assetServiceProvider).loadDrawing(widget.drawingId);
      final colored = await _loadUiImage(drawing.imageColored);

      if (!mounted) return;
      setState(() {
        _drawing = drawing;
        _coloredImage = colored;
        _loading = false;
      });

      final sortedDots = List<DotModel>.from(drawing.dots)
        ..sort((a, b) => a.id.compareTo(b.id));
      final firstId = sortedDots.isNotEmpty ? sortedDots.first.id : 1;
      ref.read(drawingSessionProvider.notifier).init(firstId);
      _setupHintController(drawing, firstId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<ui.Image?> _loadUiImage(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, (img) => completer.complete(img));
      return completer.future;
    } catch (_) {
      return null;
    }
  }

  void _setupHintController(DrawingModel drawing, int targetDotId) {
    _hintController?.dispose();
    _hintController = HintController(delaySeconds: drawing.hintDelaySeconds);
    _hintController!.onHintActivate = (dotId) {
      if (!mounted) return;
      ref.read(drawingSessionProvider.notifier).setHintingDot(dotId);
      if (!_hintPulseController.isAnimating) _hintPulseController.forward();
    };
    _hintController!.startHintTimer(targetDotId);
  }

  @override
  void dispose() {
    _lineAnimController.dispose();
    _hintPulseController.dispose();
    _revealController.dispose();
    _spinController.dispose();
    _hintController?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Tap handling
  // ---------------------------------------------------------------------------

  void _handleTap(Offset tapPosition, Size widgetSize) {
    final drawing = _drawing;
    if (drawing == null || _isRevealing) return;

    final session = ref.read(drawingSessionProvider);
    if (session.isComplete) return;

    final so = _computeScaleOffset(drawing, widgetSize);
    final scale = so.$1;
    final off = so.$2;

    final targetDot = drawing.dots
        .where((d) => d.id == session.nextExpectedDotId)
        .firstOrNull;
    if (targetDot == null) return;

    final dotScreenPos = Offset(
      targetDot.x * scale + off.dx,
      targetDot.y * scale + off.dy,
    );

    if ((tapPosition - dotScreenPos).distance <= 22.0) {
      _onCorrectTap(targetDot, drawing, tapPosition);
    } else {
      _onWrongTap();
    }
  }

  void _onWrongTap() {
    final now = DateTime.now();
    _firstWrongTapTime ??= now;

    final elapsed = now.difference(_firstWrongTapTime!);
    if (elapsed.inMilliseconds >= 2000 && !_spinHintActive) {
      setState(() => _spinHintActive = true);
      _spinController.repeat();
      HapticFeedback.mediumImpact();
    }
  }

  void _onCorrectTap(
      DotModel tappedDot, DrawingModel drawing, Offset tapPos) {
    final session = ref.read(drawingSessionProvider);

    _firstWrongTapTime = null;
    if (_spinHintActive) {
      _spinController.stop();
      _spinController.reset();
      setState(() => _spinHintActive = false);
    }

    _hintController?.cancel();
    _hintPulseController.stop();
    _hintPulseController.reset();

    final sortedDots = List<DotModel>.from(drawing.dots)
      ..sort((a, b) => a.id.compareTo(b.id));
    final currentIdx = sortedDots.indexWhere((d) => d.id == tappedDot.id);
    final isLast = currentIdx == sortedDots.length - 1;
    final nextDotId =
        isLast ? tappedDot.id : sortedDots[currentIdx + 1].id;

    final fromDot = session.connections.isNotEmpty
        ? session.connections.last.to
        : (currentIdx > 0 ? sortedDots[currentIdx - 1] : null);

    if (fromDot != null && fromDot.id != tappedDot.id) {
      final newConn = Connection(
        from: fromDot,
        to: tappedDot,
        style: _styleForIndex(session.connections.length),
        color: _kLineColors[session.connections.length % _kLineColors.length],
      );
      setState(() => _animatingConnection = newConn);
      _lineAnimController.forward(from: 0).then((_) {
        if (mounted) setState(() => _animatingConnection = null);
      });
      ref
          .read(drawingSessionProvider.notifier)
          .addConnection(newConn, nextDotId, isLast);
    } else {
      ref.read(drawingSessionProvider.notifier).init(
            isLast ? tappedDot.id : nextDotId,
          );
    }

    final lang = ref.read(progressProvider).selectedLanguage;
    ref.read(audioServiceProvider).playNumber(lang, tappedDot.id);
    ref.read(audioServiceProvider).playDotConnect();
    _confettiKey.currentState?.triggerBurst(tapPos);
    HapticFeedback.lightImpact();

    if (!isLast) {
      _hintController?.startHintTimer(nextDotId);
    }

    if (isLast) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        setState(() => _isRevealing = true);
        _revealController.forward();
      });
    }
  }

  Future<void> _navigateToCompletion() async {
    if (!mounted) return;
    await ref
        .read(progressProvider.notifier)
        .markDrawingComplete(widget.drawingId);
    if (!mounted) return;
    context.go('/completion/${widget.drawingId}');
  }

  // ---------------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------------

  (double, Offset) _computeScaleOffset(DrawingModel drawing, Size widgetSize) {
    final scaleX = widgetSize.width / drawing.canvasWidth;
    final scaleY = widgetSize.height / drawing.canvasHeight;
    final scale = min(scaleX, scaleY);
    final dx = (widgetSize.width - drawing.canvasWidth * scale) / 2;
    final dy = (widgetSize.height - drawing.canvasHeight * scale) / 2;
    return (scale, Offset(dx, dy));
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(drawingSessionProvider);
    final drawing = _drawing;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _kPaper,
        body: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF6C48FF),
                    strokeWidth: 3,
                  ),
                )
              : _error != null
                  ? Center(
                      child: Text(
                        'Error: $_error',
                        style: GoogleFonts.nunito(
                          color: const Color(0xFF7C6FA0),
                          fontSize: 16,
                        ),
                      ),
                    )
                  : drawing == null
                      ? Center(
                          child: Text(
                            'Drawing not found',
                            style: GoogleFonts.nunito(
                              color: const Color(0xFF7C6FA0),
                              fontSize: 16,
                            ),
                          ),
                        )
                      : _buildCanvas(drawing, session),
        ),
      ),
    );
  }

  Widget _buildCanvas(DrawingModel drawing, DrawingSessionState session) {
    final total = drawing.dots.length;
    final connected = session.connections.length;

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildProgressBar(connected, total),
        ),
        Positioned.fill(
          top: 64,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final widgetSize =
                  Size(constraints.maxWidth, constraints.maxHeight);
              final so = _computeScaleOffset(drawing, widgetSize);

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: _isRevealing
                    ? null
                    : (d) => _handleTap(d.localPosition, widgetSize),
                child: CustomPaint(
                  size: widgetSize,
                  painter: DotCanvasPainter(
                    drawing: drawing,
                    session: session,
                    lineAnimProgress: _lineAnimController.value,
                    hintPulse: _hintPulseController.value,
                    animatingConnection: _animatingConnection,
                    scale: so.$1,
                    offset: so.$2,
                    revealImage: _coloredImage,
                    revealProgress: _revealController.value,
                    spinHintProgress: _spinController.value,
                    spinHintActive: _spinHintActive,
                  ),
                ),
              );
            },
          ),
        ),
        Positioned.fill(
          child: ConfettiOverlay(key: _confettiKey),
        ),
      ],
    );
  }

  Widget _buildProgressBar(int connected, int total) {
    // Fix: show "1/N" at start (which dot you're connecting TO), not "0/N"
    final displayed = connected + 1;
    final fraction = total > 0 ? displayed / total : 0.0;

    // Fill color shifts from red → blue → green as progress grows
    final Color fillColor = fraction < 0.35
        ? _kRed
        : fraction < 0.68
            ? _kBlue
            : _kGreen;

    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: _kYellow,
        border: Border(
          bottom: BorderSide(color: _kInk, width: 4),
        ),
        boxShadow: [
          BoxShadow(color: _kInk, blurRadius: 0, offset: Offset(0, 5)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Home button — round red with hard shadow
          GestureDetector(
            onTap: () => context.go('/stories'),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _kRed,
                shape: BoxShape.circle,
                border: Border.all(color: _kInk, width: 3),
                boxShadow: const [
                  BoxShadow(color: _kInk, blurRadius: 0, offset: Offset(3, 3)),
                ],
              ),
              child: const Icon(Icons.home_rounded, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          // Counter badge — ink pill with star + "X / Y"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: _kInk,
              borderRadius: BorderRadius.circular(99),
              boxShadow: const [
                BoxShadow(color: _kInk, blurRadius: 0, offset: Offset(3, 3)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: _kYellow, size: 20),
                const SizedBox(width: 6),
                Text(
                  '$displayed / $total',
                  style: GoogleFonts.boogaloo(
                    color: Colors.white,
                    fontSize: 22,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Progress track — chunky Toca Boca bar
          Expanded(
            child: Container(
              height: 26,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: _kInk, width: 3),
                boxShadow: const [
                  BoxShadow(color: _kInk, blurRadius: 0, offset: Offset(3, 3)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: fraction.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                builder: (_, val, __) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: val,
                  child: Container(color: fillColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
