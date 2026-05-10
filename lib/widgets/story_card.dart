import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/story_model.dart';

// Toca Boca / Handmade tokens (match app-wide design system)
const _kRed = Color(0xFFE82D2D);
const _kYellow = Color(0xFFF5C800);
const _kGreen = Color(0xFF2DB84B);
const _kBlue = Color(0xFF1FA3E8);
const _kInk = Color(0xFF1A1A2E);
const _kPaper = Color(0xFFFFF8E7);

// Keep legacy names used internally in _ClayCard / _ProgressRow / _StarBadge
const _kPrimary = _kBlue;
const _kPrimaryDark = _kInk;
const _kMint = _kGreen;
const _kBorderColor = _kInk;
const _kForeground = _kInk;
const _kMuted = Color(0xFF7C6FA0);
const _kRadius = 18.0;
const _kBorderWidth = 3.0;

class StoryCard extends StatefulWidget {
  const StoryCard({
    super.key,
    required this.story,
    required this.completedCount,
    required this.onTap,
    required this.language,
    this.completedImagePath,
  });

  final StoryModel story;
  final int completedCount;
  final VoidCallback onTap;
  final String language;
  // If non-null, the story is fully completed — show this colored image.
  final String? completedImagePath;

  @override
  State<StoryCard> createState() => _StoryCardState();
}

class _StoryCardState extends State<StoryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
    _press.forward();
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
    _press.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _press.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.story.drawingIds.length;
    final completed = widget.completedCount;
    final isComplete = completed >= total;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: _ClayCard(
          isPressed: _isPressed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // — Image section —
              Expanded(
                flex: 6,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(_kRadius - _kBorderWidth),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _cardImage(widget.story, widget.completedImagePath),
                      // Rich gradient into info panel
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 70,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.98),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Coming soon overlay for stories without assets
                      if (widget.story.drawingIds.isEmpty)
                        const _ComingSoonOverlay(),
                      // Done star badge
                      if (isComplete)
                        const Positioned(
                          top: 10,
                          right: 10,
                          child: _StarBadge(),
                        ),
                    ],
                  ),
                ),
              ),

              // — Info panel —
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.story.getTitle(widget.language),
                        style: const TextStyle(fontFamily: 'Fredoka',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _kForeground,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      _ProgressRow(completed: completed, total: total),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Clay card shell ──────────────────────────────────────────────────────────

class _ClayCard extends StatelessWidget {
  const _ClayCard({required this.child, required this.isPressed});

  final Widget child;
  final bool isPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      transform: isPressed
          ? Matrix4.translationValues(5, 5, 0)
          : Matrix4.identity(),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(color: _kBorderColor, width: _kBorderWidth),
        boxShadow: isPressed
            ? [
                BoxShadow(
                  color: _kPrimaryDark.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(1, 1),
                ),
              ]
            : [
                // Hard clay shadow
                const BoxShadow(
                  color: _kPrimaryDark,
                  blurRadius: 0,
                  offset: Offset(6, 6),
                ),
                // Soft ambient glow
                BoxShadow(
                  color: _kPrimary.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(2, 10),
                ),
                // Top-left light reflection
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.9),
                  blurRadius: 0,
                  offset: const Offset(-3, -3),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kRadius - _kBorderWidth),
        child: child,
      ),
    );
  }
}

// ── Progress row ─────────────────────────────────────────────────────────────

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (total == 0) {
      return Row(
        children: [
          Text(
            '—',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _kMuted.withValues(alpha: 0.7),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        ...List.generate(total.clamp(0, 8), (i) {
          final done = i < completed;
          return Container(
            width: 13,
            height: 13,
            margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? _kPrimary : _kBorderColor,
              boxShadow: done
                  ? [
                      BoxShadow(
                        color: _kPrimary.withValues(alpha: 0.45),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
          );
        }),
        if (total > 8) ...[
          const SizedBox(width: 2),
          Text(
            '+${total - 8}',
            style: const TextStyle(fontFamily: 'Nunito',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _kMuted,
            ),
          ),
        ],
        const Spacer(),
        Text(
          '$completed/$total',
          style: TextStyle(fontFamily: 'Fredoka',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: completed == total ? _kMint : _kPrimary,
          ),
        ),
      ],
    );
  }
}

// ── Star "Done" badge ────────────────────────────────────────────────────────

class _StarBadge extends StatelessWidget {
  const _StarBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _kMint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: _kMint.withValues(alpha: 0.6),
            blurRadius: 0,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Colors.white, size: 14),
          const SizedBox(width: 3),
          Text(
            AppLocalizations.of(context)!.doneBadge,
            style: const TextStyle(fontFamily: 'Fredoka',
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card image resolver ───────────────────────────────────────────────────────

Widget _cardImage(StoryModel story, String? completedImagePath) {
  // Completed story: show the final colored image
  if (completedImagePath != null) {
    return Image.asset(
      completedImagePath,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _DotGridBackground(index: story.id.hashCode),
    );
  }
  // Story with assets: show ch1 preview image
  if (story.previewAsset.isNotEmpty) {
    return Image.asset(
      story.previewAsset,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _DotGridBackground(index: story.id.hashCode),
    );
  }
  // No assets yet: plain dot-grid background
  return _DotGridBackground(index: story.id.hashCode);
}

// ── Dot-grid background (neutral texture, no lock) ───────────────────────────

class _DotGridBackground extends StatelessWidget {
  const _DotGridBackground({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    const bgColors = [_kRed, _kBlue, _kGreen, _kYellow];
    final bg = bgColors[index.abs() % bgColors.length];
    return Container(
      color: _kPaper,
      child: CustomPaint(painter: _DotGridPainter(color: bg)),
    );
  }
}

// ── Coming-soon overlay (only for stories with no drawings yet) ───────────────

class _ComingSoonOverlay extends StatelessWidget {
  const _ComingSoonOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kInk.withValues(alpha: 0.45),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _kYellow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kInk, width: 2.5),
            boxShadow: const [
              BoxShadow(color: _kInk, blurRadius: 0, offset: Offset(3, 3)),
            ],
          ),
          child: Text(
            'Coming Soon',
            style: TextStyle(
              fontFamily: 'Boogaloo',
              fontSize: 16,
              color: _kInk,
              height: 1.1,
              shadows: [
                for (final d in [-1.5, 0.0, 1.5])
                  for (final e in [-1.5, 0.0, 1.5])
                    if (d != 0 || e != 0)
                      Shadow(
                          color: _kInk.withValues(alpha: 0.0),
                          offset: Offset(d, e),
                          blurRadius: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    for (double y = 16; y < size.height; y += 22) {
      for (double x = 16; x < size.width; x += 22) {
        canvas.drawCircle(Offset(x, y), 2.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}
