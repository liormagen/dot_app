import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/dot_model.dart';
import '../../models/drawing_model.dart';
import '../../services/asset_service.dart';
import '../../services/audio_service.dart';
import '../../services/progress_service.dart';
import '../../widgets/confetti_overlay.dart';
import 'dot_canvas.dart';
import 'drawing_types.dart';
import 'hint_controller.dart';

// Re-export types so other files can import from drawing_screen.dart if needed
export 'drawing_types.dart';

// ---------------------------------------------------------------------------
// Session Notifier + Provider
// ---------------------------------------------------------------------------
class DrawingSessionNotifier
    extends StateNotifier<DrawingSessionState> {
  DrawingSessionNotifier()
      : super(DrawingSessionState.initial(1));

  void init(int firstDotId) {
    state = DrawingSessionState.initial(firstDotId);
  }

  void addConnection(Connection conn, int nextDotId, bool complete) {
    state = state.copyWith(
      connections: [...state.connections, conn],
      nextExpectedDotId: nextDotId,
      isComplete: complete,
      clearHint: true,
    );
  }

  void setHintingDot(int? dotId) {
    state = state.copyWith(
      hintingDotId: dotId,
      clearHint: dotId == null,
    );
  }
}

final drawingSessionProvider = StateNotifierProvider.autoDispose<
    DrawingSessionNotifier, DrawingSessionState>(
  (_) => DrawingSessionNotifier(),
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
const _kLineColors = [
  Color(0xFFFF6B6B),
  Color(0xFFFFD93D),
  Color(0xFF6BCB77),
  Color(0xFF4D96FF),
  Color(0xFFC77DFF),
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
  ui.Image? _outlineImage;
  bool _loading = true;
  String? _error;

  late AnimationController _lineAnimController;
  late AnimationController _hintPulseController;

  HintController? _hintController;
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

    _loadDrawing();
  }

  Future<void> _loadDrawing() async {
    try {
      final drawing =
          await ref.read(assetServiceProvider).loadDrawing(widget.drawingId);
      final image = await _loadUiImage(drawing.imageOutline);
      if (!mounted) return;
      setState(() {
        _drawing = drawing;
        _outlineImage = image;
        _loading = false;
      });

      // Sort dots and init session from first dot
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
      if (!_hintPulseController.isAnimating) {
        _hintPulseController.forward();
      }
    };
    _hintController!.startHintTimer(targetDotId);
  }

  @override
  void dispose() {
    _lineAnimController.dispose();
    _hintPulseController.dispose();
    _hintController?.dispose();
    super.dispose();
  }

  void _handleTap(Offset tapPosition, Size widgetSize) {
    final drawing = _drawing;
    if (drawing == null) return;

    final session = ref.read(drawingSessionProvider);
    if (session.isComplete) return;

    final so = _computeScaleOffset(drawing, widgetSize);
    final scale = so.$1;
    final off = so.$2;

    // Find the expected target dot
    final targetDot = drawing.dots
        .where((d) => d.id == session.nextExpectedDotId)
        .firstOrNull;
    if (targetDot == null) return;

    final dotScreenPos = Offset(
      targetDot.x * scale + off.dx,
      targetDot.y * scale + off.dy,
    );
    final dist = (tapPosition - dotScreenPos).distance;

    // 44pt minimum touch target = 22pt radius
    if (dist <= 22.0) {
      _onCorrectTap(targetDot, drawing, tapPosition);
    }
    // Wrong tap: silent ignore
  }

  void _onCorrectTap(
      DotModel tappedDot, DrawingModel drawing, Offset tapPos) {
    final session = ref.read(drawingSessionProvider);

    _hintController?.cancel();
    _hintPulseController.stop();
    _hintPulseController.reset();

    // Sort dots to determine order
    final sortedDots = List<DotModel>.from(drawing.dots)
      ..sort((a, b) => a.id.compareTo(b.id));
    final currentIdx =
        sortedDots.indexWhere((d) => d.id == tappedDot.id);
    final isLast = currentIdx == sortedDots.length - 1;
    final nextDotId =
        isLast ? tappedDot.id : sortedDots[currentIdx + 1].id;

    // Determine "from" dot
    final fromDot = session.connections.isNotEmpty
        ? session.connections.last.to
        : (currentIdx > 0 ? sortedDots[currentIdx - 1] : null);

    if (fromDot != null && fromDot.id != tappedDot.id) {
      // Build and animate line
      final colorIdx =
          session.connections.length % _kLineColors.length;
      final newConn = Connection(
        from: fromDot,
        to: tappedDot,
        style: _styleForIndex(session.connections.length),
        color: _kLineColors[colorIdx],
      );

      setState(() => _animatingConnection = newConn);
      _lineAnimController.forward(from: 0).then((_) {
        if (mounted) setState(() => _animatingConnection = null);
      });

      ref.read(drawingSessionProvider.notifier).addConnection(
            newConn,
            nextDotId,
            isLast,
          );
    } else {
      // First dot in the sequence or single dot — advance expected dot
      ref.read(drawingSessionProvider.notifier).init(
            isLast ? tappedDot.id : nextDotId,
          );
    }

    // Audio & effects
    final lang = ref.read(progressProvider).selectedLanguage;
    ref.read(audioServiceProvider).playNumber(lang, tappedDot.id);
    ref.read(audioServiceProvider).playDotConnect();
    _confettiKey.currentState?.triggerBurst(tapPos);

    // Restart hint timer
    if (!isLast && _drawing != null) {
      _hintController?.startHintTimer(nextDotId);
    }

    // Complete
    if (isLast) {
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (!mounted) return;
        await ref
            .read(progressProvider.notifier)
            .markDrawingComplete(widget.drawingId);
        if (!mounted) return;
        context.go('/completion/${widget.drawingId}');
      });
    }
  }

  (double, Offset) _computeScaleOffset(
      DrawingModel drawing, Size widgetSize) {
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
        backgroundColor: const Color(0xFFF0EEF8),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Error: $_error'))
                  : drawing == null
                      ? const Center(child: Text('Drawing not found'))
                      : _buildCanvas(drawing, session),
        ),
      ),
    );
  }

  Widget _buildCanvas(
      DrawingModel drawing, DrawingSessionState session) {
    final total = drawing.dots.length;
    final connected = session.connections.length;

    return Stack(
      children: [
        // Progress bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildProgressBar(connected, total),
        ),
        // Drawing canvas
        Positioned.fill(
          top: 56,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final widgetSize =
                  Size(constraints.maxWidth, constraints.maxHeight);
              final so = _computeScaleOffset(drawing, widgetSize);

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) =>
                    _handleTap(details.localPosition, widgetSize),
                child: CustomPaint(
                  size: widgetSize,
                  painter: DotCanvasPainter(
                    drawing: drawing,
                    session: session,
                    outlineImage: _outlineImage,
                    lineAnimProgress: _lineAnimController.value,
                    hintPulse: _hintPulseController.value,
                    animatingConnection: _animatingConnection,
                    scale: so.$1,
                    offset: so.$2,
                  ),
                ),
              );
            },
          ),
        ),
        // Confetti
        Positioned.fill(
          child: ConfettiOverlay(key: _confettiKey),
        ),
      ],
    );
  }

  Widget _buildProgressBar(int connected, int total) {
    return Container(
      height: 56,
      color: const Color(0xFF6B4EFF),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const Icon(Icons.star, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            '$connected / $total',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LinearProgressIndicator(
              value: total > 0 ? connected / total : 0,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
