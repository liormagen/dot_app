import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/drawing_model.dart';
import '../../models/progress_model.dart';
import '../../models/story_model.dart';
import '../../services/asset_service.dart';
import '../../services/progress_service.dart';

// ---------------------------------------------------------------------------
// Design tokens
// ---------------------------------------------------------------------------
const _kPrimary = Color(0xFF6C48FF);
const _kGold = Color(0xFFFFD93D);
const _kNight = Color(0xFF1A0E3F);
const _kBorder = Color(0xFFD4C8FF);
const _kMuted = Color(0xFF7C6FA0);
const _kForeground = Color(0xFF1A0A3F);

const _kTripleShadow = [
  BoxShadow(
    color: Color(0x373B2099),
    blurRadius: 0,
    offset: Offset(5, 5),
  ),
  BoxShadow(
    color: Color(0x1F6C48FF),
    blurRadius: 24,
    offset: Offset(0, 8),
  ),
  BoxShadow(
    color: Color(0xE5FFFFFF),
    blurRadius: 0,
    offset: Offset(-3, -3),
  ),
];

// ---------------------------------------------------------------------------
// Gallery Screen
// ---------------------------------------------------------------------------
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  List<StoryModel> _stories = [];
  Map<String, DrawingModel> _drawings = {};
  Map<String, ui.Image?> _coloredImages = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final assetService = ref.read(assetServiceProvider);
      final stories = await assetService.loadStories();
      final allDrawings = <String, DrawingModel>{};
      final allImages = <String, ui.Image?>{};

      for (final story in stories) {
        for (final id in story.drawingIds) {
          final d = await assetService.loadDrawing(id);
          allDrawings[id] = d;
          allImages[id] = await _loadUiImage(d.imageColored);
        }
      }

      if (!mounted) return;
      setState(() {
        _stories = stories;
        _drawings = allDrawings;
        _coloredImages = allImages;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF0EEFF),
      body: Stack(
        children: [
          // Polka-dot decorative background
          Positioned.fill(child: _PolkaDotBackground()),
          Column(
            children: [
              _buildHeader(context, l10n),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: _kPrimary,
                          strokeWidth: 3,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                        itemCount: _stories.length,
                        itemBuilder: (context, i) {
                          return _buildStorySection(
                              _stories[i], progress, l10n);
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kPrimary, Color(0xFF9C6FFF)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF3B1FCC),
            blurRadius: 0,
            offset: Offset(0, 5),
          ),
          BoxShadow(
            color: Color(0x446C48FF),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Row(
            children: [
              _BackButton(onTap: () => context.go('/stories')),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  l10n.gallery,
                  style: TextStyle(fontFamily: 'Fredoka',
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
              // Stars decoration
              const _StarRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStorySection(
      StoryModel story, ProgressModel progress, AppLocalizations l10n) {
    final lang = progress.selectedLanguage;
    final completedCount = story.drawingIds
        .where((id) => progress.completedDrawingIds.contains(id))
        .length;
    final total = story.drawingIds.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Story title row
          Row(
            children: [
              Expanded(
                child: Text(
                  story.getTitle(lang),
                  style: TextStyle(fontFamily: 'Fredoka',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: _kForeground,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: completedCount == total
                      ? const Color(0xFF6BCB77)
                      : _kPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$completedCount / $total',
                  style: TextStyle(fontFamily: 'Fredoka',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: completedCount == total ? Colors.white : _kPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Drawing cards row
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: story.drawingIds.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, j) {
                final drawingId = story.drawingIds[j];
                final drawing = _drawings[drawingId];
                final image = _coloredImages[drawingId];
                final isCompleted =
                    progress.completedDrawingIds.contains(drawingId);

                if (drawing == null) return const SizedBox(width: 150);

                return _DrawingCard(
                  drawing: drawing,
                  image: image,
                  isCompleted: isCompleted,
                  lang: lang,
                  onTap: isCompleted && image != null
                      ? () => _showFullScreen(context, drawing, image, lang)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreen(
    BuildContext context,
    DrawingModel drawing,
    ui.Image image,
    String lang,
  ) {
    showDialog(
      context: context,
      builder: (_) => _FullScreenDialog(
        drawing: drawing,
        image: image,
        lang: lang,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Drawing card (clay)
// ---------------------------------------------------------------------------
class _DrawingCard extends StatefulWidget {
  const _DrawingCard({
    required this.drawing,
    required this.image,
    required this.isCompleted,
    required this.lang,
    required this.onTap,
  });

  final DrawingModel drawing;
  final ui.Image? image;
  final bool isCompleted;
  final String lang;
  final VoidCallback? onTap;

  @override
  State<_DrawingCard> createState() => _DrawingCardState();
}

class _DrawingCardState extends State<_DrawingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null
          ? (_) => _pressController.forward()
          : null,
      onTapUp: widget.onTap != null
          ? (_) {
              _pressController.reverse();
              widget.onTap!();
            }
          : null,
      onTapCancel: widget.onTap != null
          ? () => _pressController.reverse()
          : null,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) =>
            Transform.scale(scale: _scaleAnim.value, child: child),
        child: Container(
          width: 150,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _kBorder, width: 3),
            boxShadow: _kTripleShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: Column(
              children: [
                Expanded(
                  child: widget.isCompleted && widget.image != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            CustomPaint(
                              painter: _ImagePainter(image: widget.image!),
                              size: Size.infinite,
                            ),
                            // Subtle shine overlay
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 40,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.white.withValues(alpha: 0.25),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : _buildLockedState(),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.isCompleted
                        ? _kPrimary.withValues(alpha: 0.06)
                        : const Color(0xFFF5F5F5),
                    border: Border(
                        top: BorderSide(
                            color: _kBorder.withValues(alpha: 0.6),
                            width: 1.5)),
                  ),
                  child: Text(
                    widget.isCompleted
                        ? widget.drawing.getName(widget.lang)
                        : '???',
                    style: TextStyle(fontFamily: 'Fredoka',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color:
                          widget.isCompleted ? _kForeground : _kMuted,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockedState() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEDE8FF), Color(0xFFD4C8FF)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _kBorder, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: _kPrimary.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_rounded,
                size: 26,
                color: _kMuted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '?',
              style: TextStyle(fontFamily: 'Fredoka',
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: _kMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full-screen dialog
// ---------------------------------------------------------------------------
class _FullScreenDialog extends StatelessWidget {
  const _FullScreenDialog({
    required this.drawing,
    required this.image,
    required this.lang,
  });

  final DrawingModel drawing;
  final ui.Image image;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: _kNight,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: _kBorder, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x663B1FCC),
              blurRadius: 40,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(29),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.0,
                child: CustomPaint(
                  painter: _ImagePainter(image: image),
                  size: Size.infinite,
                ),
              ),
              // Gradient footer
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xCC1A0E3F), Colors.transparent],
                    ),
                  ),
                  child: Text(
                    drawing.getName(lang),
                    style: TextStyle(fontFamily: 'Fredoka',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              // Close button
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _kNight.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1.5),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
              // Gold star badge (completed)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _kGold,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFF8B6914),
                        blurRadius: 0,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 16, color: _kNight),
                      const SizedBox(width: 4),
                      Text(
                        'Done',
                        style: TextStyle(fontFamily: 'Fredoka',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _kNight,
                        ),
                      ),
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

// ---------------------------------------------------------------------------
// Back button
// ---------------------------------------------------------------------------
class _BackButton extends StatefulWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.9).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.4), width: 1.5),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Star row decoration in header
// ---------------------------------------------------------------------------
class _StarRow extends StatelessWidget {
  const _StarRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.star_rounded,
            color: _kGold.withValues(alpha: 0.9), size: 22),
        const SizedBox(width: 2),
        Icon(Icons.star_rounded,
            color: _kGold.withValues(alpha: 0.6), size: 16),
        const SizedBox(width: 2),
        Icon(Icons.star_rounded,
            color: _kGold.withValues(alpha: 0.35), size: 12),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Polka dot background
// ---------------------------------------------------------------------------
class _PolkaDotBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _PolkaPainter());
  }
}

class _PolkaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6C48FF).withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
    const spacing = 36.0;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_PolkaPainter _) => false;
}

// ---------------------------------------------------------------------------
// Image painter (shared)
// ---------------------------------------------------------------------------
class _ImagePainter extends CustomPainter {
  const _ImagePainter({required this.image});
  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
        0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, src, dst, Paint());
  }

  @override
  bool shouldRepaint(_ImagePainter old) => old.image != image;
}
