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

enum _OverlayPhase { none, celebration, narration }

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
  late AnimationController _overlayEnterCtrl;  // celebration badge scale+fade
  late AnimationController _panelCtrl;          // narration panel entrance
  late AnimationController _celebCtrl;          // floating particles loop

  // Story/narration data loaded alongside the drawing
  String _narrationText = '';
  int _chapterNumber = 1;
  String _storyId = '';
  String? _nextDrawingId;
  bool _narrationPlaying = false;
  StreamSubscription<void>? _narrationSub;

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
          // Short pause so the child sees the fully-revealed image, then celebrate
          Future.delayed(const Duration(milliseconds: 400), () {
            if (!mounted) return;
            setState(() => _overlayPhase = _OverlayPhase.celebration);
            _overlayEnterCtrl.forward();
            _celebCtrl.repeat();
            // Auto-advance to narration after 2.2 s (or child taps first)
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

      // Load narration/story context for the completion overlay
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
      setState(() {
        _drawing = drawing;
        _coloredImage = colored;
        _narrationText = chapter?.getNarration(lang) ?? '';
        _chapterNumber = chapter?.chapter ?? (chapterIdx + 1);
        _storyId = story.id;
        _nextDrawingId = chapterIdx < story.drawingIds.length - 1
            ? story.drawingIds[chapterIdx + 1]
            : null;
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
    _overlayEnterCtrl.dispose();
    _panelCtrl.dispose();
    _celebCtrl.dispose();
    _hintController?.dispose();
    _narrationSub?.cancel();
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

  Future<void> _finishAndNavigate() async {
    _stopNarration();
    if (!mounted) return;
    await ref
        .read(progressProvider.notifier)
        .markDrawingComplete(widget.drawingId);
    if (!mounted) return;
    final nextId = _nextDrawingId;
    if (nextId != null) {
      context.go('/drawing/$nextId');
    } else {
      context.go('/story-complete/$_storyId');
    }
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
              final so = _computeScaleOffset(drawing, widgetSize);

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_isRevealing || overlayActive)
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
        // Completion overlay — appears after image is fully revealed
        if (overlayActive)
          Positioned.fill(child: _buildCompletionOverlay()),
        // ── DEBUG SKIP BUTTON — remove before release ──────────────────────
        if (!overlayActive)
          Positioned(
            right: 20,
            bottom: 28,
            child: GestureDetector(
              onTap: _finishAndNavigate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: _kRed,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kInk, width: 3),
                  boxShadow: const [
                    BoxShadow(
                        color: _kInk, blurRadius: 0, offset: Offset(4, 4)),
                  ],
                ),
                child: Text(
                  'Next ▶',
                  style: GoogleFonts.boogaloo(
                    color: Colors.white,
                    fontSize: 22,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        // ── END DEBUG ──────────────────────────────────────────────────────
      ],
    );
  }

  // ── Completion overlay ────────────────────────────────────────────────────

  Widget _buildCompletionOverlay() {
    if (_overlayPhase == _OverlayPhase.narration) return _buildNarrationPanel();
    return _buildCelebrationLayer();
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
          // Floating celebration particles
          CustomPaint(
            painter: _CompletionParticlesPainter(
                progress: _celebCtrl.value),
          ),
          // Name badge + stars — centered, pops in with elastic scale
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
        // Light scrim — absorbs taps, dims the canvas above
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(
                alpha: (0.22 * _panelCtrl.value).clamp(0.0, 0.22)),
          ),
        ),
        // Narration panel — slides/scales up from bottom
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
          (0.5 + 0.5 * sin(progress * pi * 3 + phase))
              .clamp(0.0, 1.0);
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
