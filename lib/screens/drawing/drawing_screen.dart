import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../models/dot_model.dart';
import '../../models/drawing_model.dart';
import '../../models/progress_model.dart';
import '../../services/asset_service.dart';
import '../../services/audio_service.dart';
import '../../services/progress_service.dart';
import '../../widgets/confetti_overlay.dart';
import 'connection_builder.dart';
import 'dot_canvas.dart';
import 'dot_limiter.dart';
import 'drawing_types.dart';
import 'hint_controller.dart';
import 'zoom_math.dart';

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

  void connectAll(List<Connection> allConnections, int lastDotId) {
    state = state.copyWith(
      connections: allConnections,
      nextExpectedDotId: lastDotId,
      isComplete: true,
      clearHint: true,
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
  Color(0xFFFF6B6B), // coral
  Color(0xFF6C48FF), // electric purple
  Color(0xFFFFD93D), // gold
  Color(0xFF6BCB77), // mint
  Color(0xFF4FC3F7), // sky blue
];

enum _OverlayPhase { none, celebration, narration, timeout }

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

  // Completion overlay
  _OverlayPhase _overlayPhase = _OverlayPhase.none;
  late AnimationController _overlayEnterCtrl;
  late AnimationController _panelCtrl;
  late AnimationController _celebCtrl;

  // Story/narration data
  String _narrationText = '';
  int _chapterNumber = 1;
  String _storyId = '';
  String? _nextDrawingId;
  bool _narrationPlaying = false;
  StreamSubscription<void>? _narrationSub;

  // Difficulty & countdown
  DifficultyMode _difficulty = DifficultyMode.normal;
  int _remainingSeconds = 0;
  int _totalSeconds = 0;
  Timer? _countdownTimer;
  bool _timerStarted = false;

  // Progressive reveal (Hard / Super Hard)
  int _visibleDotCount = 0; // 0 = all visible (Easy/Normal)

  // Zoom / pan (Hard / SuperHard only)
  late TransformationController _transformController;
  double _zoomScale = 1.0;
  Size? _canvasSize;
  bool _showZoomHint = false;

  bool get _isZoomMode =>
      _difficulty == DifficultyMode.hard ||
      _difficulty == DifficultyMode.superHard;

  Connection? _animatingConnection;
  final GlobalKey<ConfettiOverlayState> _confettiKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _transformController = TransformationController();
    _transformController.addListener(() {
      final s = _transformController.value.getMaxScaleOnAxis();
      if (s != _zoomScale) {
        setState(() => _zoomScale = s);
      }
    });

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
          Future.delayed(const Duration(milliseconds: 400), () {
            if (!mounted) return;
            setState(() => _overlayPhase = _OverlayPhase.celebration);
            _overlayEnterCtrl.forward();
            _celebCtrl.repeat();
            Future.delayed(const Duration(milliseconds: 2200), () {
              if (mounted && _overlayPhase == _OverlayPhase.celebration) {
                _showNarration();
              }
            });
          });
        }
      });

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addListener(() {
        if (mounted) setState(() {});
      });

    _overlayEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..addListener(() {
        if (mounted) setState(() {});
      });

    _panelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    )..addListener(() {
        if (mounted) setState(() {});
      });

    _celebCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addListener(() {
        if (mounted) setState(() {});
      });

    _loadDrawing();
  }

  Future<void> _loadDrawing() async {
    try {
      final assetSvc = ref.read(assetServiceProvider);
      final drawing = await assetSvc.loadDrawing(widget.drawingId);
      final colored = await _loadUiImage(drawing.imageColored);

      final stories = await assetSvc.loadStories();
      final story = stories.firstWhere(
        (s) => s.id == drawing.storyId,
        orElse: () => stories.first,
      );
      final chapterIdx = story.drawingIds.indexOf(drawing.id);
      final chapter =
          (chapterIdx >= 0 && chapterIdx < story.chapters.length)
              ? story.chapters[chapterIdx]
              : null;
      final lang = ref.read(progressProvider).selectedLanguage;

      if (!mounted) return;
      final difficulty = ref.read(progressProvider).difficulty;
      final effectiveDots = _applyDotLimit(drawing.dots, difficulty, drawing);
      final effectiveDrawing = drawing.copyWith(dots: effectiveDots);
      final isTimedMode = difficulty == DifficultyMode.hard ||
          difficulty == DifficultyMode.superHard;
      final timerSecs = difficulty == DifficultyMode.hard
          ? effectiveDots.length
          : difficulty == DifficultyMode.superHard
              ? (effectiveDots.length / 2).ceil()
              : 0;

      setState(() {
        _drawing = effectiveDrawing;
        _coloredImage = colored;
        _narrationText = chapter?.getNarration(lang) ?? '';
        _chapterNumber = chapter?.chapter ?? (chapterIdx + 1);
        _storyId = story.id;
        _nextDrawingId = chapterIdx < story.drawingIds.length - 1
            ? story.drawingIds[chapterIdx + 1]
            : null;
        _loading = false;
        _difficulty = difficulty;
        _totalSeconds = timerSecs;
        _remainingSeconds = timerSecs;
        _visibleDotCount =
            isTimedMode ? min(5, effectiveDots.length) : 0;
      });
      // Timer starts on first dot tap (A2) — not here

      // Show zoom hint briefly for Hard/SuperHard
      if (difficulty == DifficultyMode.hard ||
          difficulty == DifficultyMode.superHard) {
        setState(() => _showZoomHint = true);
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _showZoomHint = false);
        });
      }

      final sortedDots = List<DotModel>.from(effectiveDots)
        ..sort((a, b) => a.id.compareTo(b.id));
      final firstId = sortedDots.isNotEmpty ? sortedDots.first.id : 1;
      ref.read(drawingSessionProvider.notifier).init(firstId);
      _setupHintController(effectiveDrawing, firstId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<DotModel> _applyDotLimit(
          List<DotModel> dots, DifficultyMode mode, DrawingModel drawing) =>
      applyDotLimit(dots, mode, drawing.canvasWidth.toDouble(), drawing.canvasHeight.toDouble());

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
    _countdownTimer?.cancel();
    _lineAnimController.dispose();
    _hintPulseController.dispose();
    _revealController.dispose();
    _spinController.dispose();
    _overlayEnterCtrl.dispose();
    _panelCtrl.dispose();
    _celebCtrl.dispose();
    _hintController?.dispose();
    _narrationSub?.cancel();
    _transformController.dispose();
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
      // Progressive reveal: block tap on dots not yet visible
      if (_visibleDotCount > 0 && targetDot.id > _visibleDotCount) return;
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

    // Start timer on first correct tap (A2)
    final isTimedMode = _difficulty == DifficultyMode.hard ||
        _difficulty == DifficultyMode.superHard;
    if (isTimedMode && !_timerStarted && _totalSeconds > 0) {
      _timerStarted = true;
      _startCountdownTimer();
    }

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
      _updateVisibleCount();
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
      final firstDot = sortedDots.first;
      Future.delayed(const Duration(milliseconds: 310), () {
        if (!mounted) return;
        final sess = ref.read(drawingSessionProvider);
        final closingConn = Connection(
          from: tappedDot,
          to: firstDot,
          style: _styleForIndex(sess.connections.length),
          color: _kLineColors[sess.connections.length % _kLineColors.length],
        );
        setState(() => _animatingConnection = closingConn);
        _lineAnimController.forward(from: 0).then((_) {
          if (!mounted) return;
          ref
              .read(drawingSessionProvider.notifier)
              .addConnection(closingConn, tappedDot.id, true);
          setState(() => _animatingConnection = null);
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!mounted) return;
            _countdownTimer?.cancel();
            setState(() => _isRevealing = true);
            _revealController.forward();
          });
        });
      });
    }
  }

  void _updateVisibleCount() {
    final drawing = _drawing;
    if (drawing == null) return;
    if (_difficulty != DifficultyMode.hard &&
        _difficulty != DifficultyMode.superHard) return;
    final session = ref.read(drawingSessionProvider);
    final newVisible =
        min(5 + session.connections.length * 3, drawing.dots.length);
    if (newVisible != _visibleDotCount) {
      setState(() => _visibleDotCount = newVisible);
    }
  }

  void _showNarration() {
    _celebCtrl.stop();
    setState(() => _overlayPhase = _OverlayPhase.narration);
    _panelCtrl.forward();
    if (_narrationText.isNotEmpty) _playNarration();
  }

  void _playNarration() {
    _narrationSub?.cancel();
    final lang = ref.read(progressProvider).selectedLanguage;
    ref.read(audioServiceProvider).playChapterNarration(
        lang, _storyId, _chapterNumber);
    setState(() => _narrationPlaying = true);
    _narrationSub = ref
        .read(audioServiceProvider)
        .voiceoverPlayer
        .onPlayerComplete
        .listen((_) {
      if (mounted) setState(() => _narrationPlaying = false);
    });
  }

  void _stopNarration() {
    _narrationSub?.cancel();
    _narrationSub = null;
    try {
      ref.read(audioServiceProvider).voiceoverPlayer.stop();
    } catch (_) {}
    if (mounted) setState(() => _narrationPlaying = false);
  }

  // QA helper: auto-connect all dots and trigger the normal completion flow.
  void _skipToReveal() {
    final drawing = _drawing;
    if (drawing == null || _isRevealing || _overlayPhase != _OverlayPhase.none) {
      return;
    }

    _countdownTimer?.cancel();
    _hintController?.cancel();
    _hintPulseController.stop();
    _hintPulseController.reset();
    _spinController.stop();
    _spinController.reset();

    if (drawing.dots.isEmpty) return;
    final connections = buildAllConnections(drawing.dots);
    final lastId = (List<DotModel>.from(drawing.dots)
          ..sort((a, b) => a.id.compareTo(b.id)))
        .last
        .id;

    ref
        .read(drawingSessionProvider.notifier)
        .connectAll(connections, lastId);

    _lineAnimController.reset();
    _revealController.reset();
    setState(() {
      _isRevealing = true;
      _animatingConnection = null;
      _spinHintActive = false;
      _firstWrongTapTime = null;
      _visibleDotCount = 0; // show all dots instantly
    });
    _revealController.forward();
  }

  void _finishAndNavigate() {
    _stopNarration();
    _countdownTimer?.cancel();
    if (!mounted) return;
    ref.read(progressProvider.notifier).markDrawingComplete(widget.drawingId);
    final nextId = _nextDrawingId;
    if (nextId != null) {
      context.go('/drawing/$nextId');
    } else if (_storyId.isNotEmpty) {
      context.go('/story-complete/$_storyId');
    } else {
      context.go('/stories');
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _countdownTimer?.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        _countdownTimer?.cancel();
        setState(() => _remainingSeconds = 0);
        _onTimerExpired();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _onTimerExpired() {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    final drawing = _drawing;
    if (drawing == null) return;

    _hintController?.cancel();
    _hintPulseController.stop();
    _hintPulseController.reset();
    _spinController.stop();
    _spinController.reset();

    final sortedDots = List<DotModel>.from(drawing.dots)
      ..sort((a, b) => a.id.compareTo(b.id));
    final firstId = sortedDots.isNotEmpty ? sortedDots.first.id : 1;
    ref.read(drawingSessionProvider.notifier).init(firstId);
    _lineAnimController.reset();

    setState(() {
      _overlayPhase = _OverlayPhase.timeout;
      _isRevealing = false;
      _animatingConnection = null;
      _spinHintActive = false;
      _firstWrongTapTime = null;
      _visibleDotCount = min(5, drawing.dots.length);
    });
  }

  void _resetAfterTimeout() {
    final drawing = _drawing;
    if (drawing == null) return;
    _timerStarted = false;
    final sortedDots = List<DotModel>.from(drawing.dots)
      ..sort((a, b) => a.id.compareTo(b.id));
    final firstId = sortedDots.isNotEmpty ? sortedDots.first.id : 1;
    setState(() {
      _overlayPhase = _OverlayPhase.none;
      _remainingSeconds = _totalSeconds;
    });
    _setupHintController(drawing, firstId);
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

  // ---------------------------------------------------------------------------
  // Zoom helpers
  // ---------------------------------------------------------------------------

  void _applyZoom(double newScale) {
    final size = _canvasSize;
    if (size == null) return;
    _transformController.value =
        zoomMatrixCenteredOn(newScale, size.width / 2, size.height / 2);
  }

  void _zoomIn() {
    final next = (_zoomScale + 0.5).clamp(1.0, 5.0);
    _applyZoom(next);
  }

  void _zoomOut() {
    final next = (_zoomScale - 0.5).clamp(1.0, 5.0);
    _applyZoom(next);
  }

  void _snapToNextDot(DrawingModel drawing, DrawingSessionState session) {
    final size = _canvasSize;
    if (size == null) return;
    final so = _computeScaleOffset(drawing, size);
    final dotEntry = drawing.dots
        .where((d) => d.id == session.nextExpectedDotId)
        .firstOrNull;
    if (dotEntry == null) return;
    final dx = dotEntry.x * so.$1 + so.$2.dx;
    final dy = dotEntry.y * so.$1 + so.$2.dy;
    _transformController.value =
        snapToDotMatrix(_zoomScale, dx, dy, size.width, size.height);
  }

  // ---------------------------------------------------------------------------
  // Minimap widget
  // ---------------------------------------------------------------------------

  Widget _buildMinimap(DrawingModel drawing, DrawingSessionState session) {
    final size = _canvasSize!;
    final so = _computeScaleOffset(drawing, size);
    return Container(
      width: 160,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kInk, width: 2),
        boxShadow: const [
          BoxShadow(color: _kInk, blurRadius: 0, offset: Offset(3, 3)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: _MinimapPainter(
          drawing: drawing,
          session: session,
          fitScale: so.$1,
          fitOffset: so.$2,
          zoomMatrix: _transformController.value,
          viewportSize: size,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Zoom hint widget
  // ---------------------------------------------------------------------------

  Widget _buildZoomHint() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: _kYellow,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: _kInk, width: 3),
          boxShadow: const [
            BoxShadow(color: _kInk, blurRadius: 0, offset: Offset(4, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pinch_rounded, color: _kInk, size: 28),
            const SizedBox(width: 10),
            Text(
              'Pinch to zoom!',
              style: GoogleFonts.boogaloo(
                color: _kInk,
                fontSize: 22,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
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

    final overlayActive = _overlayPhase != _OverlayPhase.none;

    return Stack(
      children: [
        // Progress bar — fades out when overlay is active
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: overlayActive ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 300),
            child: _buildProgressBar(connected, total),
          ),
        ),
        Positioned.fill(
          top: 64,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final widgetSize =
                  Size(constraints.maxWidth, constraints.maxHeight);
              // Store canvas size for zoom controls / minimap
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_canvasSize != widgetSize) {
                  if (mounted) setState(() => _canvasSize = widgetSize);
                }
              });
              final so = _computeScaleOffset(drawing, widgetSize);

              final canvasPainter = CustomPaint(
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
                  visibleDotCount: _visibleDotCount,
                ),
              );

              return InteractiveViewer(
                transformationController: _transformController,
                scaleEnabled: _isZoomMode,
                panEnabled: _isZoomMode,
                minScale: 1.0,
                maxScale: 5.0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (_isRevealing || overlayActive)
                      ? null
                      : (d) => _handleTap(d.localPosition, widgetSize),
                  child: canvasPainter,
                ),
              );
            },
          ),
        ),
        // Minimap (Hard/SuperHard, shown only when zoomed in)
        if (_isZoomMode && _zoomScale > 1.05 && _canvasSize != null)
          Positioned(
            bottom: 80,
            right: 16,
            child: _buildMinimap(drawing, session),
          ),
        // First-time zoom hint
        if (_showZoomHint && _isZoomMode)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _showZoomHint ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              child: _buildZoomHint(),
            ),
          ),
        Positioned.fill(
          child: ConfettiOverlay(key: _confettiKey),
        ),
        // Completion / timeout overlay
        if (overlayActive)
          Positioned.fill(child: _buildCompletionOverlay()),
      ],
    );
  }

  // ── Completion overlay ────────────────────────────────────────────────────

  Widget _buildCompletionOverlay() {
    if (_overlayPhase == _OverlayPhase.narration) return _buildNarrationPanel();
    if (_overlayPhase == _OverlayPhase.timeout) return _buildTimeoutOverlay();
    return _buildCelebrationLayer();
  }

  Widget _buildTimeoutOverlay() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black.withValues(alpha: 0.62),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 22),
                decoration: BoxDecoration(
                  color: _kRed,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: _kInk, width: 4),
                  boxShadow: const [
                    BoxShadow(
                        color: _kInk, blurRadius: 0, offset: Offset(6, 6)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_off_rounded,
                        color: Colors.white, size: 48),
                    const SizedBox(width: 16),
                    Text(
                      "Time's Up!",
                      style: GoogleFonts.boogaloo(
                        color: Colors.white,
                        fontSize: 56,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              _DrawingNextButton(
                label: "Let's Go!  →",
                onTap: _resetAfterTimeout,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCelebrationLayer() {
    final drawing = _drawing!;
    final lang = ref.read(progressProvider).selectedLanguage;
    final t = Curves.elasticOut
        .transform(_overlayEnterCtrl.value.clamp(0.0, 1.0));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showNarration,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _CompletionParticlesPainter(
                progress: _celebCtrl.value),
          ),
          Center(
            child: Transform.scale(
              scale: (0.6 + 0.4 * t).clamp(0.0, 1.15),
              child: Opacity(
                opacity: _overlayEnterCtrl.value.clamp(0.0, 1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.star_rounded, color: _kYellow, size: 40),
                        SizedBox(width: 10),
                        Icon(Icons.star_rounded, color: _kRed, size: 30),
                        SizedBox(width: 10),
                        Icon(Icons.star_rounded, color: _kYellow, size: 40),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 36, vertical: 16),
                      decoration: BoxDecoration(
                        color: _kYellow,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: _kInk, width: 4),
                        boxShadow: const [
                          BoxShadow(
                              color: _kInk,
                              blurRadius: 0,
                              offset: Offset(6, 6)),
                        ],
                      ),
                      child: Text(
                        drawing.getName(lang),
                        style: GoogleFonts.boogaloo(
                          color: _kInk,
                          fontSize: 48,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        color: _kInk,
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: const [
                          BoxShadow(
                              color: _kInk,
                              blurRadius: 0,
                              offset: Offset(3, 3)),
                        ],
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.tapToContinue,
                        style: GoogleFonts.boogaloo(
                          color: Colors.white,
                          fontSize: 20,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrationPanel() {
    final l10n = AppLocalizations.of(context)!;
    final curved =
        Curves.easeOutBack.transform(_panelCtrl.value.clamp(0.0, 1.0));

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(
                alpha: (0.22 * _panelCtrl.value).clamp(0.0, 0.22)),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Transform.scale(
            scale: (0.85 + 0.15 * curved).clamp(0.0, 1.02),
            alignment: Alignment.bottomCenter,
            child: Opacity(
              opacity: _panelCtrl.value.clamp(0.0, 1.0),
              child: FractionallySizedBox(
                heightFactor: 0.46,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _kPaper,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                    border: const Border(
                      top: BorderSide(color: _kInk, width: 4),
                      left: BorderSide(color: _kInk, width: 4),
                      right: BorderSide(color: _kInk, width: 4),
                    ),
                    boxShadow: const [
                      BoxShadow(
                          color: _kInk,
                          blurRadius: 0,
                          offset: Offset(0, -6)),
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 18),
                      _DrawingChapterBadge(
                          chapter: _chapterNumber, l10n: l10n),
                      const SizedBox(height: 14),
                      Expanded(
                        child: SingleChildScrollView(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            _narrationText.isNotEmpty
                                ? _narrationText
                                : '…',
                            style: GoogleFonts.boogaloo(
                              fontSize: 22,
                              height: 1.65,
                              color: _kInk,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _DrawingVoiceButton(
                              playing: _narrationPlaying,
                              onTap: _playNarration,
                            ),
                            const SizedBox(width: 16),
                            _DrawingNextButton(
                              label: _nextDrawingId != null
                                  ? l10n.letsDraw
                                  : l10n.keepGoing,
                              onTap: _finishAndNavigate,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(int connected, int total) {
    final displayed = connected + 1;
    final fraction = total > 0 ? displayed / total : 0.0;

    final Color fillColor = fraction < 0.35
        ? _kRed
        : fraction < 0.68
            ? _kBlue
            : _kGreen;

    final isTimedMode = _difficulty == DifficultyMode.hard ||
        _difficulty == DifficultyMode.superHard;

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
          // Home button
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
              child: const Icon(Icons.home_rounded,
                  color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          // Counter badge
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
          // Timer badge (timed modes only)
          if (isTimedMode) ...[
            _TimerBadge(
              remaining: _remainingSeconds,
              total: _totalSeconds,
            ),
            const SizedBox(width: 12),
          ],
          // Zoom controls (Hard/SuperHard only)
          if (isTimedMode) ...[
            _ZoomControlButton(
              icon: Icons.remove_rounded,
              onTap: _zoomOut,
            ),
            const SizedBox(width: 4),
            if (_zoomScale > 1.05)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '${_zoomScale.toStringAsFixed(1)}×',
                  style: GoogleFonts.boogaloo(
                    color: _kInk,
                    fontSize: 18,
                    height: 1.0,
                  ),
                ),
              ),
            _ZoomControlButton(
              icon: Icons.add_rounded,
              onTap: _zoomIn,
            ),
            const SizedBox(width: 6),
            _FindDotButton(onTap: () {
              final d = _drawing;
              if (d != null) {
                _snapToNextDot(d, ref.read(drawingSessionProvider));
              }
            }),
            const SizedBox(width: 8),
          ],
          // Progress track
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
          const SizedBox(width: 10),
          // ── DEBUG skip button — remove before release ──────────────────
          SkipButton(onTap: _skipToReveal),
          // ── END DEBUG ──────────────────────────────────────────────────
        ],
      ),
    );
  }
}

// ── Completion celebration particles ─────────────────────────────────────────

class _CompletionParticlesPainter extends CustomPainter {
  const _CompletionParticlesPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rand = Random(42);
    final paint = Paint()..style = PaintingStyle.fill;
    const colors = [
      _kYellow, _kRed, _kGreen, _kBlue, Colors.white,
    ];
    for (int i = 0; i < 55; i++) {
      final x = rand.nextDouble() * size.width;
      final baseY = rand.nextDouble() * size.height;
      final speed = 0.35 + rand.nextDouble() * 0.65;
      final y = (baseY - progress * size.height * speed) % size.height;
      final r = 3.5 + rand.nextDouble() * 5.5;
      final phase = rand.nextDouble() * pi * 2;
      final alpha =
          (0.5 + 0.5 * sin(progress * pi * 3 + phase)).clamp(0.0, 1.0);
      paint.color =
          colors[i % colors.length].withValues(alpha: alpha * 0.88);
      canvas.drawCircle(
          Offset(x, y < 0 ? y + size.height : y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_CompletionParticlesPainter old) =>
      old.progress != progress;
}

// ── Chapter badge for narration panel ────────────────────────────────────────

class _DrawingChapterBadge extends StatelessWidget {
  const _DrawingChapterBadge({required this.chapter, required this.l10n});
  final int chapter;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      decoration: BoxDecoration(
        color: _kBlue,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _kInk, width: 3),
        boxShadow: const [
          BoxShadow(color: _kInk, blurRadius: 0, offset: Offset(3, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_stories_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            l10n.chapter(chapter),
            style: GoogleFonts.boogaloo(
              color: Colors.white,
              fontSize: 20,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Voice replay button ───────────────────────────────────────────────────────

class _DrawingVoiceButton extends StatelessWidget {
  const _DrawingVoiceButton({required this.playing, required this.onTap});
  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: playing ? _kBlue : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: _kInk, width: 3),
          boxShadow: const [
            BoxShadow(color: _kInk, blurRadius: 0, offset: Offset(3, 3)),
          ],
        ),
        child: Icon(
          playing ? Icons.volume_up_rounded : Icons.replay_rounded,
          color: playing ? Colors.white : _kInk,
          size: 26,
        ),
      ),
    );
  }
}

// ── Hard-mode countdown badge — bigger + panic pulse on last 5s ───────────────

class _TimerBadge extends StatefulWidget {
  const _TimerBadge({required this.remaining, required this.total});
  final int remaining;
  final int total;

  @override
  State<_TimerBadge> createState() => _TimerBadgeState();
}

class _TimerBadgeState extends State<_TimerBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _panicCtrl;
  late Animation<double> _panicScale;

  @override
  void initState() {
    super.initState();
    _panicCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _panicScale = Tween<double>(begin: 1.0, end: 1.3)
        .chain(CurveTween(curve: Curves.elasticOut))
        .animate(_panicCtrl);
    _maybePanic();
  }

  @override
  void didUpdateWidget(_TimerBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.remaining != widget.remaining) _maybePanic();
  }

  void _maybePanic() {
    if (widget.remaining <= 5 && widget.remaining > 0) {
      _panicCtrl.forward(from: 0).then((_) {
        if (mounted) _panicCtrl.reverse();
      });
    } else if (widget.remaining > 5) {
      _panicCtrl.stop();
      _panicCtrl.reset();
    }
  }

  @override
  void dispose() {
    _panicCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fraction =
        widget.total > 0 ? widget.remaining / widget.total : 0.0;
    final isPanic = widget.remaining <= 5 && widget.remaining > 0;
    final Color badgeColor = isPanic
        ? _kRed
        : fraction > 0.5
            ? _kGreen
            : fraction > 0.25
                ? _kYellow
                : _kRed;

    return AnimatedBuilder(
      animation: _panicCtrl,
      builder: (_, child) =>
          Transform.scale(scale: _panicScale.value, child: child),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: _kInk, width: 3),
          boxShadow: const [
            BoxShadow(color: _kInk, blurRadius: 0, offset: Offset(3, 3)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule_rounded, color: Colors.white, size: 32),
            const SizedBox(width: 8),
            Text(
              '${widget.remaining}',
              style: GoogleFonts.boogaloo(
                color: Colors.white,
                fontSize: 30,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── DEBUG: Skip button ────────────────────────────────────────────────────────

class SkipButton extends StatefulWidget {
  const SkipButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<SkipButton> createState() => SkipButtonState();
}

class SkipButtonState extends State<SkipButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform:
            _pressed ? Matrix4.translationValues(3, 3, 0) : Matrix4.identity(),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: _kRed,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kInk, width: 3),
          boxShadow: _pressed
              ? []
              : const [
                  BoxShadow(
                      color: _kInk, blurRadius: 0, offset: Offset(3, 3)),
                ],
        ),
        child: Text(
          'Skip ▶',
          style: GoogleFonts.boogaloo(
            color: Colors.white,
            fontSize: 18,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

// ── Next / continue button ────────────────────────────────────────────────────

class _DrawingNextButton extends StatefulWidget {
  const _DrawingNextButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_DrawingNextButton> createState() => _DrawingNextButtonState();
}

class _DrawingNextButtonState extends State<_DrawingNextButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: _pressed
            ? Matrix4.translationValues(5, 5, 0)
            : Matrix4.identity(),
        padding:
            const EdgeInsets.symmetric(horizontal: 44, vertical: 18),
        decoration: BoxDecoration(
          color: _kGreen,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _kInk, width: 3),
          boxShadow: _pressed
              ? []
              : const [
                  BoxShadow(
                      color: _kInk, blurRadius: 0, offset: Offset(5, 5)),
                ],
        ),
        child: Text(
          widget.label,
          style: GoogleFonts.boogaloo(
            color: Colors.white,
            fontSize: 26,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

// ── Minimap painter ───────────────────────────────────────────────────────────

class _MinimapPainter extends CustomPainter {
  const _MinimapPainter({
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

  static const double _w = 160;
  static const double _h = 120;

  Offset _toMinimap(Offset p) =>
      Offset(p.dx * (_w / viewportSize.width), p.dy * (_h / viewportSize.height));

  Offset _dotToWidget(DotModel d) =>
      Offset(d.x * fitScale + fitOffset.dx, d.y * fitScale + fitOffset.dy);

  @override
  void paint(Canvas canvas, Size size) {
    // White background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _w, _h),
      Paint()..color = Colors.white,
    );

    // Completed connections
    final connPaint = Paint()
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final conn in session.connections) {
      connPaint.color = conn.color;
      final from = _toMinimap(_dotToWidget(conn.from));
      final to = _toMinimap(_dotToWidget(conn.to));
      canvas.drawLine(from, to, connPaint);
    }

    // All dots
    final connectedIds = <int>{};
    for (final c in session.connections) {
      connectedIds.add(c.from.id);
      connectedIds.add(c.to.id);
    }
    for (final dot in drawing.dots) {
      final pos = _toMinimap(_dotToWidget(dot));
      final isConnected = connectedIds.contains(dot.id);
      canvas.drawCircle(
        pos,
        2.0,
        Paint()
          ..color = isConnected
              ? _kGreen
              : _kInk.withValues(alpha: 0.4)
          ..style = PaintingStyle.fill,
      );
    }

    // Viewport rectangle
    final vpRect = viewportRectFromMatrix(zoomMatrix, viewportSize);
    final rect = Rect.fromPoints(
        _toMinimap(vpRect.topLeft), _toMinimap(vpRect.bottomRight));
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
  bool shouldRepaint(_MinimapPainter old) =>
      old.session != session ||
      old.zoomMatrix != zoomMatrix ||
      old.fitScale != fitScale ||
      old.fitOffset != fitOffset;
}

// ── Zoom control button (+ / −) ───────────────────────────────────────────────

class _ZoomControlButton extends StatefulWidget {
  const _ZoomControlButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_ZoomControlButton> createState() => _ZoomControlButtonState();
}

class _ZoomControlButtonState extends State<_ZoomControlButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: _pressed
            ? Matrix4.translationValues(2, 2, 0)
            : Matrix4.identity(),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _kBlue,
          shape: BoxShape.circle,
          border: Border.all(color: _kInk, width: 2),
          boxShadow: _pressed
              ? []
              : const [
                  BoxShadow(color: _kInk, blurRadius: 0, offset: Offset(2, 2)),
                ],
        ),
        child: Icon(widget.icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ── Find next dot button ──────────────────────────────────────────────────────

class _FindDotButton extends StatefulWidget {
  const _FindDotButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_FindDotButton> createState() => _FindDotButtonState();
}

class _FindDotButtonState extends State<_FindDotButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: _pressed
            ? Matrix4.translationValues(2, 2, 0)
            : Matrix4.identity(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _kGreen,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kInk, width: 2),
          boxShadow: _pressed
              ? []
              : const [
                  BoxShadow(color: _kInk, blurRadius: 0, offset: Offset(2, 2)),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.adjust_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              'Find ●',
              style: GoogleFonts.boogaloo(
                color: Colors.white,
                fontSize: 14,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
