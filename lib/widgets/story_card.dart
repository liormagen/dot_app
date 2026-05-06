import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../models/story_model.dart';

// Stardust Claymorphism tokens
const _kPrimary = Color(0xFF6C48FF);
const _kPrimaryDark = Color(0xFF3B2099);
const _kMint = Color(0xFF6BCB77);
const _kBorderColor = Color(0xFFD4C8FF);
const _kForeground = Color(0xFF1A0A3F);
const _kMuted = Color(0xFF7C6FA0);
const _kRadius = 28.0;
const _kBorderWidth = 3.0;

class StoryCard extends StatefulWidget {
  const StoryCard({
    super.key,
    required this.story,
    required this.completedCount,
    required this.onTap,
    required this.language,
  });

  final StoryModel story;
  final int completedCount;
  final VoidCallback onTap;
  final String language;

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
                      Image.asset(
                        widget.story.previewAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _PlaceholderImage(
                          index: widget.story.id.hashCode,
                        ),
                      ),
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
                        style: GoogleFonts.fredoka(
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
            style: GoogleFonts.nunito(
              fontSize: 11,
              color: _kMuted,
            ),
          ),
        ],
        const Spacer(),
        Text(
          '$completed/$total',
          style: GoogleFonts.fredoka(
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
            style: GoogleFonts.fredoka(
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

// ── Placeholder image ────────────────────────────────────────────────────────

class _PlaceholderImage extends StatelessWidget {
  const _PlaceholderImage({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    const gradients = [
      [Color(0xFFE0E7FF), Color(0xFFC7D2FE)],
      [Color(0xFFFFE4E6), Color(0xFFFECACA)],
      [Color(0xFFD1FAE5), Color(0xFFA7F3D0)],
      [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
      [Color(0xFFF3E8FF), Color(0xFFE9D5FF)],
    ];
    const symbols = ['✦', '◆', '★', '●', '▲'];
    final g = gradients[index.abs() % gradients.length];
    final sym = symbols[index.abs() % symbols.length];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: g,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          sym,
          style: TextStyle(
            fontSize: 52,
            color: _kPrimary.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}
