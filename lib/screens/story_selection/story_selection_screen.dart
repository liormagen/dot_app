import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../services/asset_service.dart';
import '../../services/progress_service.dart';
import '../../widgets/parental_gate.dart';
import '../../widgets/story_card.dart';
import 'settings_sheet.dart';

// ---------------------------------------------------------------------------
// Toca Boca / Handmade tokens
// ---------------------------------------------------------------------------
const _kRed = Color(0xFFE82D2D);
const _kYellow = Color(0xFFF5C800);
const _kGreen = Color(0xFF2DB84B);
const _kBlue = Color(0xFF1FA3E8);
const _kInk = Color(0xFF1A1A2E);
const _kPaper = Color(0xFFFFF8E7);

List<Shadow> _inkOutline(double w) => [
      for (final dx in [-w, 0.0, w])
        for (final dy in [-w, 0.0, w])
          if (dx != 0 || dy != 0)
            Shadow(color: _kInk, offset: Offset(dx, dy), blurRadius: 0),
    ];

// ---------------------------------------------------------------------------
// StorySelectionScreen
// ---------------------------------------------------------------------------
class StorySelectionScreen extends ConsumerWidget {
  const StorySelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(storiesProvider);
    final progress = ref.watch(progressProvider);

    return Scaffold(
      backgroundColor: _kPaper,
      body: Stack(
        children: [
          // Static doodle texture
          const Positioned.fill(child: _DoodleBackground()),
          // Animated wandering blobs
          const Positioned.fill(child: _WanderingBlobsLayer()),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _BoldHeader(
                  onGalleryTap: () => context.go('/gallery'),
                  onSettingsTap: () => _openSettings(context),
                ),
              ),
              storiesAsync.when(
                loading: () => const SliverFillRemaining(
                  child: Center(child: _InkLoader()),
                ),
                error: (e, _) => SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'Oops! $e',
                      style:
                          GoogleFonts.boogaloo(color: _kInk, fontSize: 22),
                    ),
                  ),
                ),
                data: (stories) {
                  if (stories.isEmpty) {
                    return const SliverFillRemaining(
                      child: Center(child: _EmptyState()),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 22,
                        mainAxisSpacing: 28,
                        childAspectRatio: 0.75,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final story = stories[index];
                          final completedCount = story.drawingIds
                              .where((id) =>
                                  progress.completedDrawingIds.contains(id))
                              .length;
                          const cardColors = [_kRed, _kBlue, _kGreen];
                          return _TocaStoryCard(
                            baseTilt: index.isEven ? 0.026 : -0.026,
                            accentColor:
                                cardColors[index % cardColors.length],
                            onTap: () => _onStoryTap(
                              context,
                              story.drawingIds,
                              progress.completedDrawingIds,
                            ),
                            child: AbsorbPointer(
                              child: StoryCard(
                                story: story,
                                completedCount: completedCount,
                                language: progress.selectedLanguage,
                                onTap: () {},
                              ),
                            ),
                          );
                        },
                        childCount: stories.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onStoryTap(
    BuildContext context,
    List<String> drawingIds,
    Set<String> completed,
  ) {
    String? target;
    for (final id in drawingIds) {
      if (!completed.contains(id)) {
        target = id;
        break;
      }
    }
    target ??= drawingIds.first;
    context.go('/drawing/$target');
  }

  Future<void> _openSettings(BuildContext context) async {
    final allowed = await ParentalGate.show(context);
    if (!allowed || !context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: _kPaper,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: _kInk, width: 3),
        ),
        child: const SettingsSheet(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Toca story card — impressive spring press animation
// ---------------------------------------------------------------------------
class _TocaStoryCard extends StatefulWidget {
  const _TocaStoryCard({
    required this.baseTilt,
    required this.accentColor,
    required this.onTap,
    required this.child,
  });

  final double baseTilt;
  final Color accentColor;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_TocaStoryCard> createState() => _TocaStoryCardState();
}

class _TocaStoryCardState extends State<_TocaStoryCard>
    with TickerProviderStateMixin {
  // Press-down controller: scale 1.0 → 0.88
  late AnimationController _pressCtrl;
  late Animation<double> _pressScale;

  // Spring-back controller: elastic overshoot from pressed to natural
  late AnimationController _springCtrl;
  late Animation<double> _springScale;

  bool _pressed = false;
  bool _springing = false;

  @override
  void initState() {
    super.initState();

    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    )..addListener(() => setState(() {}));

    _pressScale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );

    _springCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..addListener(() => setState(() {}))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          setState(() => _springing = false);
          _springCtrl.reset();
        }
      });

    _springScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _springCtrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    _springCtrl.dispose();
    super.dispose();
  }

  double get _scale =>
      _springing ? _springScale.value : _pressScale.value;

  double get _currentTilt =>
      _pressed ? widget.baseTilt + 0.06 : widget.baseTilt;

  bool get _isShadowActive => !_pressed && !_springing;

  void _onTapDown(TapDownDetails _) {
    _springCtrl.stop();
    setState(() {
      _pressed = true;
      _springing = false;
    });
    _pressCtrl.forward(from: 0);
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails _) {
    _pressCtrl.stop();
    setState(() {
      _pressed = false;
      _springing = true;
    });
    _springCtrl.forward(from: 0);
    HapticFeedback.mediumImpact();
    widget.onTap();
  }

  void _onTapCancel() {
    _pressCtrl.stop();
    setState(() {
      _pressed = false;
      _springing = true;
    });
    _springCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: Transform.rotate(
        angle: _currentTilt,
        child: Transform.scale(
          scale: _scale,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _pressed ? _kYellow : _kInk,
                width: _pressed ? 4.5 : 4,
              ),
              boxShadow: _isShadowActive
                  ? [
                      BoxShadow(
                        color: _kInk,
                        blurRadius: 0,
                        offset: Offset(
                          widget.baseTilt > 0 ? 6 : -2,
                          6,
                        ),
                      ),
                      BoxShadow(
                        color: widget.accentColor.withValues(alpha: 0.5),
                        blurRadius: 0,
                        offset: Offset(
                          widget.baseTilt > 0 ? 11 : -7,
                          11,
                        ),
                      ),
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Game-style sticker header — floating badge, no rectangular banner
// ---------------------------------------------------------------------------
class _BoldHeader extends StatelessWidget {
  const _BoldHeader({
    required this.onGalleryTap,
    required this.onSettingsTap,
  });

  final VoidCallback onGalleryTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: top + 148,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Floating action buttons — top right
          Positioned(
            top: top + 14,
            right: 20,
            child: Row(
              children: [
                _InkIconButton(
                  icon: Icons.photo_library_rounded,
                  color: _kBlue,
                  onTap: onGalleryTap,
                ),
                const SizedBox(width: 10),
                _InkIconButton(
                  icon: Icons.settings_rounded,
                  color: _kGreen,
                  onTap: onSettingsTap,
                ),
              ],
            ),
          ),

          // Centered sticker badge
          Positioned(
            top: top + 8,
            left: 0,
            right: 0,
            child: Center(
              child: Transform.rotate(
                angle: -0.03,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 10),
                  decoration: BoxDecoration(
                    color: _kYellow,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: _kInk, width: 4),
                    boxShadow: const [
                      BoxShadow(
                          color: _kInk,
                          blurRadius: 0,
                          offset: Offset(6, 6)),
                      BoxShadow(
                          color: _kRed,
                          blurRadius: 0,
                          offset: Offset(11, 11)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Star left
                      Transform.rotate(
                        angle: -0.3,
                        child: const Icon(Icons.star_rounded,
                            color: _kInk, size: 30),
                      ),
                      const SizedBox(width: 8),
                      // "Dot Story" — same style as welcome screen
                      Text(
                        'Dot Story',
                        style: GoogleFonts.boogaloo(
                          fontSize: 58,
                          color: _kYellow,
                          height: 1.0,
                          shadows: _inkOutline(3.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Star right
                      Transform.rotate(
                        angle: 0.4,
                        child: const Icon(Icons.star_rounded,
                            color: _kInk, size: 30),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Subtitle pill — centered below sticker
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Transform.rotate(
                angle: 0.015,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 5),
                  decoration: BoxDecoration(
                    color: _kGreen,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: _kInk, width: 3),
                    boxShadow: const [
                      BoxShadow(
                          color: _kInk,
                          blurRadius: 0,
                          offset: Offset(3, 3)),
                    ],
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.pickAStory,
                    style: GoogleFonts.boogaloo(
                      fontSize: 20,
                      color: Colors.white,
                      height: 1.1,
                      shadows: _inkOutline(1.5),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Decorative scattered stars around header
          Positioned(
            top: top + 18,
            left: 22,
            child: Transform.rotate(
              angle: 0.5,
              child: Icon(Icons.star_rounded,
                  color: _kRed.withValues(alpha: 0.8), size: 26),
            ),
          ),
          Positioned(
            top: top + 52,
            left: 54,
            child: Transform.rotate(
              angle: -0.8,
              child: Icon(Icons.star_rounded,
                  color: _kGreen.withValues(alpha: 0.7), size: 18),
            ),
          ),
          Positioned(
            top: top + 24,
            left: 110,
            child: Transform.rotate(
              angle: 0.2,
              child: Icon(Icons.star_rounded,
                  color: _kBlue.withValues(alpha: 0.5), size: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ink-style icon button
// ---------------------------------------------------------------------------
class _InkIconButton extends StatefulWidget {
  const _InkIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_InkIconButton> createState() => _InkIconButtonState();
}

class _InkIconButtonState extends State<_InkIconButton> {
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
            ? Matrix4.translationValues(4, 4, 0)
            : Matrix4.identity(),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kInk, width: 3.5),
          boxShadow: _pressed
              ? []
              : const [
                  BoxShadow(
                      color: _kInk, blurRadius: 0, offset: Offset(4, 4)),
                ],
        ),
        child: Icon(widget.icon, color: Colors.white, size: 26),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wandering colored blobs — slow sine-wave drift
// ---------------------------------------------------------------------------
class _WanderingBlobsLayer extends StatefulWidget {
  const _WanderingBlobsLayer();

  @override
  State<_WanderingBlobsLayer> createState() =>
      _WanderingBlobsLayerState();
}

class _WanderingBlobsLayerState extends State<_WanderingBlobsLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value * 2 * math.pi;
        double d(int freq, double phase, double amp) =>
            amp * math.sin(freq * t + phase);

        return Stack(
          children: [
            // Top-left red blob
            Positioned(
              top: -50 + d(1, 0.0, 38),
              left: -50 + d(1, math.pi / 3, 28),
              child: const _WanderingBlob(color: _kRed, size: 180),
            ),
            // Top-right blue blob
            Positioned(
              top: 30 + d(1, math.pi * 0.7, 32),
              right: -60 + d(1, math.pi * 1.2, 24),
              child: const _WanderingBlob(color: _kBlue, size: 150),
            ),
            // Bottom-left green blob
            Positioned(
              bottom: -40 + d(1, math.pi, 36),
              left: -30 + d(1, math.pi * 1.5, 22),
              child: const _WanderingBlob(color: _kGreen, size: 160),
            ),
            // Bottom-right yellow blob
            Positioned(
              bottom: size.height * 0.08 + d(2, 0.5, 28),
              right: -45 + d(2, 0.5 + math.pi / 2, 20),
              child: const _WanderingBlob(color: _kYellow, size: 130),
            ),
            // Mid-left small red
            Positioned(
              top: size.height * 0.38 + d(1, math.pi * 0.4, 30),
              left: -30 + d(1, math.pi * 0.9, 16),
              child: const _WanderingBlob(color: _kRed, size: 90),
            ),
            // Mid-right small blue
            Positioned(
              top: size.height * 0.55 + d(2, math.pi * 1.3, 26),
              right: -20 + d(2, math.pi * 1.7, 14),
              child: const _WanderingBlob(color: _kBlue, size: 80),
            ),
          ],
        );
      },
    );
  }
}

class _WanderingBlob extends StatelessWidget {
  const _WanderingBlob({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.55),
        shape: BoxShape.circle,
        border: Border.all(color: _kInk, width: 3.5),
        boxShadow: const [
          BoxShadow(color: _kInk, blurRadius: 0, offset: Offset(5, 5)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Doodle background (static texture layer)
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

    // Grid of small ink dots
    final dotPaint = Paint()
      ..color = _kInk.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;
    for (double y = 40; y < size.height; y += 40) {
      for (double x = 40; x < size.width; x += 40) {
        canvas.drawCircle(Offset(x, y), 2.5, dotPaint);
      }
    }

    // Wavy doodle lines
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;

    final lineData = [
      (_kRed, 0.25),
      (_kGreen, 0.58),
      (_kBlue, 0.82),
    ];

    for (final (color, yFrac) in lineData) {
      linePaint.color = color.withValues(alpha: 0.15);
      final y = size.height * yFrac;
      final path = Path()..moveTo(0, y);
      double x = 0;
      int dir = 1;
      while (x < size.width) {
        path.quadraticBezierTo(x + 30, y + dir * 13, x + 60, y);
        x += 60;
        dir = -dir;
      }
      canvas.drawPath(path, linePaint);
    }

    // Scattered X marks
    final xPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final rand = math.Random(55);
    final xColors = [_kRed, _kYellow, _kGreen, _kBlue];
    for (int i = 0; i < 20; i++) {
      final cx = rand.nextDouble() * size.width;
      final cy = rand.nextDouble() * size.height;
      final s = 5.0 + rand.nextDouble() * 7;
      xPaint.color = xColors[i % 4].withValues(alpha: 0.18);
      canvas.drawLine(Offset(cx - s, cy - s), Offset(cx + s, cy + s), xPaint);
      canvas.drawLine(Offset(cx + s, cy - s), Offset(cx - s, cy + s), xPaint);
    }
  }

  @override
  bool shouldRepaint(_DoodlePainter _) => false;
}

// ---------------------------------------------------------------------------
// Ink loader — bouncing colored dots with black outlines
// ---------------------------------------------------------------------------
class _InkLoader extends StatefulWidget {
  const _InkLoader();

  @override
  State<_InkLoader> createState() => _InkLoaderState();
}

class _InkLoaderState extends State<_InkLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const dotColors = [_kRed, _kYellow, _kGreen, _kBlue];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(4, (i) {
              final offset =
                  math.sin((_ctrl.value * math.pi * 2) - (i * 0.8)) * 12;
              return Transform.translate(
                offset: Offset(0, -offset.clamp(-12.0, 12.0)),
                child: Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColors[i],
                    border: Border.all(color: _kInk, width: 2.5),
                    boxShadow: const [
                      BoxShadow(
                          color: _kInk,
                          blurRadius: 0,
                          offset: Offset(2, 2)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          AppLocalizations.of(context)!.loadingStories,
          style: GoogleFonts.boogaloo(
            color: _kInk,
            fontSize: 24,
            shadows: _inkOutline(1.5),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Transform.rotate(
          angle: -0.05,
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: _kYellow,
              shape: BoxShape.circle,
              border: Border.all(color: _kInk, width: 4),
              boxShadow: const [
                BoxShadow(
                    color: _kInk, blurRadius: 0, offset: Offset(6, 6)),
              ],
            ),
            child: const Icon(Icons.auto_stories_rounded,
                size: 52, color: _kInk),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          AppLocalizations.of(context)!.noStoriesYet,
          style: GoogleFonts.boogaloo(
            fontSize: 32,
            color: _kInk,
            shadows: _inkOutline(2),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context)!.addStoriesToStart,
          style: GoogleFonts.boogaloo(
              fontSize: 18, color: _kInk.withValues(alpha: 0.6)),
        ),
      ],
    );
  }
}
