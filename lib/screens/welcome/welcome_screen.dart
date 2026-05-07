import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../services/progress_service.dart';
import '../story_selection/settings_sheet.dart';
import '../../widgets/parental_gate.dart';

// ---------------------------------------------------------------------------
// Direction 1 — Toca Boca / Handmade tokens
// ---------------------------------------------------------------------------
const _kRed = Color(0xFFE82D2D);
const _kYellow = Color(0xFFF5C800);
const _kGreen = Color(0xFF2DB84B);
const _kBlue = Color(0xFF1FA3E8);
const _kInk = Color(0xFF1A1A2E);
const _kPaper = Color(0xFFFFF8E7);

// Simulated cartoon text outline via 8-directional shadows
List<Shadow> _inkOutline(double w) => [
      for (final dx in [-w, 0.0, w])
        for (final dy in [-w, 0.0, w])
          if (dx != 0 || dy != 0)
            Shadow(color: _kInk, offset: Offset(dx, dy), blurRadius: 0),
    ];

// ---------------------------------------------------------------------------
// WelcomeScreen
// ---------------------------------------------------------------------------
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceCtrl;
  late Animation<double> _titleSlide;
  late Animation<double> _titleFade;
  late Animation<double> _dotsScale;
  late Animation<double> _buttonPop;

  late AnimationController _starCtrl;
  late AnimationController _bounceCtrl;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _titleSlide = Tween<double>(begin: -60, end: 0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
      ),
    );
    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );
    _dotsScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.35, 0.70, curve: Curves.elasticOut),
      ),
    );
    _buttonPop = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.60, 1.0, curve: Curves.elasticOut),
      ),
    );

    _starCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _entranceCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _starCtrl.dispose();
    _bounceCtrl.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    final allowed = await ParentalGate.show(context);
    if (!allowed || !mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: _kPaper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: const SettingsSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);
    final completedCount = progress.completedDrawingIds.length;

    return Scaffold(
      backgroundColor: _kPaper,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Hand-drawn doodle background
          const Positioned.fill(child: _DoodleBackground()),

          // Animated wandering blobs
          const Positioned.fill(child: _WanderingBlobsLayer()),

          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _InkButton(
                        icon: Icons.photo_library_rounded,
                        color: _kBlue,
                        onTap: () => context.go('/gallery'),
                      ),
                      const SizedBox(width: 10),
                      _InkButton(
                        icon: Icons.settings_rounded,
                        color: _kGreen,
                        onTap: _openSettings,
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Title block
                AnimatedBuilder(
                  animation: _entranceCtrl,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, _titleSlide.value),
                    child: Opacity(
                      opacity: _titleFade.value,
                      child: Column(
                        children: [
                          // Icon badge
                          Transform.rotate(
                            angle: -0.08,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: _kYellow,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: _kInk, width: 4),
                                boxShadow: const [
                                  BoxShadow(
                                    color: _kInk,
                                    blurRadius: 0,
                                    offset: Offset(6, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.star_rounded,
                                color: _kInk,
                                size: 70,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          // Title with ink outline
                          Text(
                            'Dot Story',
                            style: TextStyle(fontFamily: 'Boogaloo',
                              fontSize: 100,
                              fontWeight: FontWeight.w400,
                              color: _kYellow,
                              height: 1.0,
                              shadows: _inkOutline(4),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Connect the Dots · Reveal the Magic',
                            style: TextStyle(fontFamily: 'Boogaloo',
                              fontSize: 24,
                              color: _kInk,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Bouncing dots row
                AnimatedBuilder(
                  animation: _entranceCtrl,
                  builder: (_, __) => Transform.scale(
                    scale: _dotsScale.value,
                    child: AnimatedBuilder(
                      animation: _bounceCtrl,
                      builder: (_, __) =>
                          _BouncingDots(bounce: _bounceCtrl.value),
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // Play button
                AnimatedBuilder(
                  animation: _entranceCtrl,
                  builder: (_, __) => Transform.scale(
                    scale: _buttonPop.value,
                    child: _PlayButton(
                      label: AppLocalizations.of(context)!.welcomePlay,
                      onTap: () => context.go('/stories'),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                if (completedCount > 0)
                  AnimatedBuilder(
                    animation: _entranceCtrl,
                    builder: (_, __) => Opacity(
                      opacity: _buttonPop.value.clamp(0.0, 1.0),
                      child: _ProgressBadge(completedCount: completedCount),
                    ),
                  ),

                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bouncing dots — colored with ink borders
// ---------------------------------------------------------------------------
class _BouncingDots extends StatelessWidget {
  const _BouncingDots({required this.bounce});
  final double bounce;

  @override
  Widget build(BuildContext context) {
    const colors = [_kRed, _kYellow, _kGreen, _kBlue, _kRed];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(colors.length, (i) {
        final phase = i / colors.length;
        final offset =
            math.sin((bounce + phase) * math.pi * 2) * 16;
        return Transform.translate(
          offset: Offset(0, -offset.clamp(0.0, 16.0)),
          child: Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: colors[i],
              shape: BoxShape.circle,
              border: Border.all(color: _kInk, width: 3.5),
              boxShadow: const [
                BoxShadow(
                  color: _kInk,
                  blurRadius: 0,
                  offset: Offset(4, 4),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Play button
// ---------------------------------------------------------------------------
class _PlayButton extends StatefulWidget {
  const _PlayButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        HapticFeedback.mediumImpact();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: _pressed
            ? Matrix4.translationValues(4, 4, 0)
            : Matrix4.translationValues(0, 0, 0)
          ..rotateZ(-0.035),
        padding:
            const EdgeInsets.symmetric(horizontal: 100, vertical: 28),
        decoration: BoxDecoration(
          color: _kRed,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _kInk, width: 4.5),
          boxShadow: _pressed
              ? []
              : const [
                  BoxShadow(
                    color: _kInk,
                    blurRadius: 0,
                    offset: Offset(6, 6),
                  ),
                  BoxShadow(
                    color: _kYellow,
                    blurRadius: 0,
                    offset: Offset(11, 11),
                  ),
                ],
        ),
        child: Text(
          widget.label,
          style: TextStyle(fontFamily: 'Boogaloo',
            color: Colors.white,
            fontSize: 46,
            shadows: _inkOutline(2.5),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress badge
// ---------------------------------------------------------------------------
class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({required this.completedCount});
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.02,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: _kGreen,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kInk, width: 3),
          boxShadow: const [
            BoxShadow(color: _kInk, blurRadius: 0, offset: Offset(4, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, color: _kYellow, size: 22),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)!
                  .welcomeDrawingsCompleted(completedCount),
              style: TextStyle(fontFamily: 'Boogaloo',
                color: Colors.white,
                fontSize: 20,
                shadows: _inkOutline(1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ink-style icon button (top bar)
// ---------------------------------------------------------------------------
class _InkButton extends StatefulWidget {
  const _InkButton(
      {required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_InkButton> createState() => _InkButtonState();
}

class _InkButtonState extends State<_InkButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: _pressed
            ? Matrix4.translationValues(3, 3, 0)
            : Matrix4.identity(),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kInk, width: 3),
          boxShadow: _pressed
              ? []
              : const [
                  BoxShadow(
                    color: _kInk,
                    blurRadius: 0,
                    offset: Offset(4, 4),
                  ),
                ],
        ),
        child: Icon(widget.icon, color: Colors.white, size: 26),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wandering blobs + elastic lines — interactive (squeeze, drag-to-reconnect)
// ---------------------------------------------------------------------------
class _WanderingBlobsLayer extends StatefulWidget {
  const _WanderingBlobsLayer();

  @override
  State<_WanderingBlobsLayer> createState() => _WanderingBlobsLayerState();
}

class _WanderingBlobsLayerState extends State<_WanderingBlobsLayer>
    with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late AnimationController _squeezeCtrl;
  late Animation<double> _squeezeAnim;

  List<(int, int)> _connections = [(0, 2), (1, 3), (0, 4), (3, 5), (1, 2)];
  Timer? _switchTimer;
  final _rand = math.Random();
  Size _size = Size.zero;

  // Line drag state
  int? _draggingLineIdx;
  bool _draggingFromA = true;
  Offset? _dragPos;
  int? _hoverBlobId;

  // Blob squeeze state — which blob is squeezing
  int? _squeezeBlobId;

  static const _blobRadii = [80.0, 65.0, 72.5, 57.5, 36.0, 30.0];

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _squeezeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          setState(() => _squeezeBlobId = null);
          _squeezeCtrl.reset();
        }
      });
    // Phase 1 (first 20%): fast squish to peak.
    // Phase 2 (remaining 80%): elastic spring-back with overshoot.
    _squeezeAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.32)
            .chain(CurveTween(curve: Curves.easeOutQuart)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.32, end: 0.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 80,
      ),
    ]).animate(_squeezeCtrl);

    _switchTimer = Timer.periodic(const Duration(milliseconds: 2800), (_) {
      if (!mounted || _draggingLineIdx != null) return;
      final next = List<(int, int)>.from(_connections);
      final idx = _rand.nextInt(next.length);
      final (a, b) = next[idx];
      int newEnd;
      do {
        newEnd = _rand.nextInt(6);
      } while (newEnd == a || newEnd == b);
      next[idx] = _rand.nextBool() ? (newEnd, b) : (a, newEnd);
      setState(() => _connections = next);
    });
  }

  @override
  void dispose() {
    _switchTimer?.cancel();
    _ctrl.dispose();
    _squeezeCtrl.dispose();
    super.dispose();
  }

  // Compute blob centers at the current animation tick
  List<Offset> _currentCenters() {
    if (_size == Size.zero) return [];
    final t = _ctrl.value * 2 * math.pi;
    double d(int freq, double phase, double amp) =>
        amp * math.sin(freq * t + phase);
    final s = _size;
    return [
      Offset(40 + d(1, math.pi / 3, 26), 40 + d(1, 0.0, 36)),
      Offset(s.width - 15 - d(1, math.pi * 1.2, 22), 85 + d(1, math.pi * 0.7, 30)),
      Offset(52.5 + d(1, math.pi * 1.5, 20), s.height - 42.5 - d(1, math.pi, 34)),
      Offset(s.width - 17.5 - d(2, 0.5 + math.pi / 2, 18), s.height * 0.94 - 57.5 - d(2, 0.5, 26)),
      Offset(14 + d(1, math.pi * 0.9, 14), s.height * 0.4 + 36 + d(1, math.pi * 0.4, 28)),
      Offset(s.width - 12 - d(2, math.pi * 1.7, 12), s.height * 0.28 + 30 + d(2, math.pi * 1.3, 24)),
    ];
  }

  // Returns the blob index if pos is within its hit area, else null
  int? _blobAt(Offset pos) {
    final centers = _currentCenters();
    for (int i = 0; i < centers.length; i++) {
      if ((pos - centers[i]).distance <= _blobRadii[i] + 22) return i;
    }
    return null;
  }

  // Returns the line index if pos is within 30px of the bezier, else null
  int? _lineAt(Offset pos) {
    final centers = _currentCenters();
    for (int i = 0; i < _connections.length; i++) {
      final (a, b) = _connections[i];
      if (a >= centers.length || b >= centers.length) continue;
      if (_nearBezier(pos, centers[a], centers[b])) return i;
    }
    return null;
  }

  bool _nearBezier(Offset pos, Offset a, Offset b) {
    final dir = b - a;
    final len = dir.distance;
    if (len < 20) return false;
    final norm = Offset(-dir.dy / len, dir.dx / len);
    final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final ctrl = mid + norm * (len * 0.18);
    for (int j = 0; j <= 24; j++) {
      final tt = j / 24.0;
      final mt = 1 - tt;
      final pt = Offset(
        mt * mt * a.dx + 2 * mt * tt * ctrl.dx + tt * tt * b.dx,
        mt * mt * a.dy + 2 * mt * tt * ctrl.dy + tt * tt * b.dy,
      );
      if ((pos - pt).distance < 30) return true;
    }
    return false;
  }

  // onTapDown fires at pointer-down with zero movement — instant blob response
  void _onTapDown(TapDownDetails details) {
    final blobIdx = _blobAt(details.localPosition);
    if (blobIdx == null) return;
    setState(() => _squeezeBlobId = blobIdx);
    _squeezeCtrl.forward(from: 0);
    HapticFeedback.lightImpact();
  }

  void _onPanStart(DragStartDetails details) {
    if (_squeezeBlobId != null) return; // blob tap already handled by onTapDown
    final pos = details.localPosition;

    // Check line
    final lineIdx = _lineAt(pos);
    if (lineIdx != null) {
      final centers = _currentCenters();
      final (a, b) = _connections[lineIdx];
      final fromA = (pos - centers[a]).distance < (pos - centers[b]).distance;
      setState(() {
        _draggingLineIdx = lineIdx;
        _draggingFromA = fromA;
        _dragPos = pos;
        _hoverBlobId = null;
      });
      HapticFeedback.mediumImpact();
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_draggingLineIdx == null) return;
    final pos = details.localPosition;
    final (a, b) = _connections[_draggingLineIdx!];
    final fixedEnd = _draggingFromA ? b : a;
    final blob = _blobAt(pos);
    setState(() {
      _dragPos = pos;
      _hoverBlobId = (blob != null && blob != fixedEnd) ? blob : null;
    });
  }

  void _onPanEnd(DragEndDetails _) {
    if (_draggingLineIdx == null) return;
    final idx = _draggingLineIdx!;
    final (a, b) = _connections[idx];

    if (_hoverBlobId != null) {
      // Reconnect to the new blob
      final next = List<(int, int)>.from(_connections);
      next[idx] = _draggingFromA ? (_hoverBlobId!, b) : (a, _hoverBlobId!);
      setState(() {
        _connections = next;
        _draggingLineIdx = null;
        _dragPos = null;
        _hoverBlobId = null;
      });
      HapticFeedback.lightImpact();
    } else {
      // Snap back — connection unchanged
      setState(() {
        _draggingLineIdx = null;
        _dragPos = null;
        _hoverBlobId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _size = Size(constraints.maxWidth, constraints.maxHeight);
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: _onTapDown,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: AnimatedBuilder(
          animation: Listenable.merge([_ctrl, _squeezeAnim]),
          builder: (_, __) => CustomPaint(
            size: _size,
            painter: _BlobsAndLinesPainter(
              t: _ctrl.value * 2 * math.pi,
              connections: List.unmodifiable(_connections),
              draggingLineIdx: _draggingLineIdx,
              draggingFromA: _draggingFromA,
              dragPos: _dragPos,
              hoverBlobId: _hoverBlobId,
              squeezeBlobId: _squeezeBlobId,
              squeezeAmt: _squeezeAnim.value,
            ),
          ),
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// CustomPainter: lines behind blobs, interactive squeeze + drag dot
// ---------------------------------------------------------------------------
class _BlobsAndLinesPainter extends CustomPainter {
  _BlobsAndLinesPainter({
    required this.t,
    required this.connections,
    this.draggingLineIdx,
    required this.draggingFromA,
    this.dragPos,
    this.hoverBlobId,
    this.squeezeBlobId,
    required this.squeezeAmt,
  });

  final double t;
  final List<(int, int)> connections;
  final int? draggingLineIdx;
  final bool draggingFromA;
  final Offset? dragPos;
  final int? hoverBlobId;
  final int? squeezeBlobId;
  final double squeezeAmt;

  double _d(int freq, double phase, double amp) =>
      amp * math.sin(freq * t + phase);

  List<Offset> _centers(Size s) => [
        Offset(40 + _d(1, math.pi / 3, 26), 40 + _d(1, 0.0, 36)),
        Offset(s.width - 15 - _d(1, math.pi * 1.2, 22), 85 + _d(1, math.pi * 0.7, 30)),
        Offset(52.5 + _d(1, math.pi * 1.5, 20), s.height - 42.5 - _d(1, math.pi, 34)),
        Offset(s.width - 17.5 - _d(2, 0.5 + math.pi / 2, 18), s.height * 0.94 - 57.5 - _d(2, 0.5, 26)),
        Offset(14 + _d(1, math.pi * 0.9, 14), s.height * 0.4 + 36 + _d(1, math.pi * 0.4, 28)),
        Offset(s.width - 12 - _d(2, math.pi * 1.7, 12), s.height * 0.28 + 30 + _d(2, math.pi * 1.3, 24)),
      ];

  static const _blobs = [
    (_kBlue, 80.0),
    (_kGreen, 65.0),
    (_kYellow, 72.5),
    (_kRed, 57.5),
    (_kGreen, 36.0),
    (_kYellow, 30.0),
  ];

  static const _lineColors = [_kRed, _kBlue, _kGreen, _kYellow, _kRed];

  @override
  void paint(Canvas canvas, Size size) {
    final centers = _centers(size);

    // 1. Elastic lines
    for (int i = 0; i < connections.length; i++) {
      final (a, b) = connections[i];
      if (a >= centers.length || b >= centers.length) continue;

      var endA = centers[a];
      var endB = centers[b];
      if (i == draggingLineIdx && dragPos != null) {
        if (draggingFromA) {
          endA = dragPos!;
        } else {
          endB = dragPos!;
        }
      }
      _drawLine(canvas, endA, endB, _lineColors[i % _lineColors.length]);
    }

    // 2. Floating drag dot (visible endpoint being dragged)
    if (draggingLineIdx != null && dragPos != null) {
      _drawDragDot(canvas, dragPos!,
          _lineColors[draggingLineIdx! % _lineColors.length]);
    }

    // 3. Blobs
    for (int i = 0; i < _blobs.length; i++) {
      final (color, radius) = _blobs[i];

      double sx = 1.0, sy = 1.0;
      if (i == squeezeBlobId) {
        sx = 1.0 - squeezeAmt;
        sy = 1.0 + squeezeAmt * 0.55;
      }

      _drawBlob(canvas, centers[i], color, radius, sx, sy,
          highlight: i == hoverBlobId);
    }
  }

  void _drawLine(Canvas canvas, Offset a, Offset b, Color color) {
    final dir = b - a;
    final len = dir.distance;
    if (len < 20) return;
    final norm = Offset(-dir.dy / len, dir.dx / len);
    final ctrl =
        Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2) + norm * (len * 0.18);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy);

    canvas.drawPath(
        path,
        Paint()
          ..color = _kInk.withValues(alpha: 0.22)
          ..strokeWidth = 8
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
    canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.32)
          ..strokeWidth = 5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
  }

  void _drawDragDot(Canvas canvas, Offset pos, Color color) {
    canvas.drawCircle(
        pos + const Offset(3, 3), 14, Paint()..color = _kInk.withValues(alpha: 0.25));
    canvas.drawCircle(pos, 14, Paint()..color = color.withValues(alpha: 0.9));
    canvas.drawCircle(
        pos,
        14,
        Paint()
          ..color = _kInk
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke);
  }

  void _drawBlob(Canvas canvas, Offset c, Color color, double r, double sx,
      double sy, {required bool highlight}) {
    if (highlight) {
      canvas.drawCircle(
          c,
          r + 16,
          Paint()
            ..color = _kYellow.withValues(alpha: 0.50)
            ..strokeWidth = 5
            ..style = PaintingStyle.stroke);
    }

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(sx, sy);

    canvas.drawCircle(const Offset(5, 5), r,
        Paint()..color = _kInk.withValues(alpha: 0.18));
    canvas.drawCircle(Offset.zero, r,
        Paint()..color = color.withValues(alpha: 0.28));
    canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..color = _kInk.withValues(alpha: 0.30)
          ..strokeWidth = 3.5
          ..style = PaintingStyle.stroke);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BlobsAndLinesPainter old) =>
      old.t != t ||
      old.connections != connections ||
      old.draggingLineIdx != draggingLineIdx ||
      old.dragPos != dragPos ||
      old.hoverBlobId != hoverBlobId ||
      old.squeezeBlobId != squeezeBlobId ||
      old.squeezeAmt != squeezeAmt;
}

// ---------------------------------------------------------------------------
// Hand-drawn doodle background
// ---------------------------------------------------------------------------
class _DoodleBackground extends StatelessWidget {
  const _DoodleBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DoodlePainter());
  }
}

class _DoodlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _kPaper,
    );

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;

    // Wavy horizontal lines
    final waveColors = [
      _kBlue.withValues(alpha: 0.18),
      _kGreen.withValues(alpha: 0.15),
      _kRed.withValues(alpha: 0.12),
    ];
    final waveYs = [size.height * 0.22, size.height * 0.55, size.height * 0.78];

    for (int w = 0; w < waveColors.length; w++) {
      linePaint.color = waveColors[w];
      final path = Path();
      path.moveTo(0, waveYs[w]);
      double x = 0;
      int dir = 1;
      while (x < size.width) {
        path.quadraticBezierTo(
            x + 30, waveYs[w] + dir * 14, x + 60, waveYs[w]);
        x += 60;
        dir = -dir;
      }
      canvas.drawPath(path, linePaint);
    }

    // Scattered small circles (doodle dots)
    final dotPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 2;
    final rand = math.Random(42);
    final dotColors = [_kRed, _kYellow, _kGreen, _kBlue];
    for (int i = 0; i < 28; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final r = 4.0 + rand.nextDouble() * 8;
      dotPaint.color =
          dotColors[i % dotColors.length].withValues(alpha: 0.2);
      canvas.drawCircle(Offset(x, y), r, dotPaint);
    }

    // Small X marks scattered around
    final xPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final rand2 = math.Random(99);
    for (int i = 0; i < 16; i++) {
      final cx = rand2.nextDouble() * size.width;
      final cy = rand2.nextDouble() * size.height;
      final s = 6.0 + rand2.nextDouble() * 6;
      xPaint.color =
          dotColors[i % dotColors.length].withValues(alpha: 0.22);
      canvas.drawLine(
          Offset(cx - s, cy - s), Offset(cx + s, cy + s), xPaint);
      canvas.drawLine(
          Offset(cx + s, cy - s), Offset(cx - s, cy + s), xPaint);
    }
  }

  @override
  bool shouldRepaint(_DoodlePainter _) => false;
}
