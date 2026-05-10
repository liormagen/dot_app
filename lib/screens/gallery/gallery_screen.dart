import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/drawing_model.dart';
import '../../models/progress_model.dart';
import '../../models/story_model.dart';
import '../../services/asset_service.dart';
import '../../services/progress_service.dart';

// ---------------------------------------------------------------------------
// Toca Boca / Handmade tokens (matches the rest of the app)
// ---------------------------------------------------------------------------
const _kRed    = Color(0xFFE82D2D);
const _kYellow = Color(0xFFF5C800);
const _kGreen  = Color(0xFF2DB84B);
const _kBlue   = Color(0xFF1FA3E8);
const _kInk    = Color(0xFF1A1A2E);
const _kPaper  = Color(0xFFFFF8E7);

List<Shadow> _inkOutline(double w) => [
  for (final dx in [-w, 0.0, w])
    for (final dy in [-w, 0.0, w])
      if (dx != 0 || dy != 0)
        Shadow(color: _kInk, offset: Offset(dx, dy), blurRadius: 0),
];

Future<ui.Image?> _decodeUiImage(String assetPath) async {
  try {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (img) => completer.complete(img));
    return await completer.future.timeout(const Duration(seconds: 10));
  } catch (_) {
    return null;
  }
}

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
      final filtered = stories.where((s) => s.drawingIds.isNotEmpty).toList();

      for (final story in filtered) {
        for (final id in story.drawingIds) {
          allDrawings[id] = await assetService.loadDrawing(id);
        }
      }

      if (!mounted) return;
      setState(() {
        _stories = filtered;
        _drawings = allDrawings;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: _kPaper,
      body: Stack(
        children: [
          // Polka-dot decorative background
          Positioned.fill(child: _PolkaDotBackground()),
          Column(
            children: [
              _buildHeader(context, l10n),
              Expanded(
                child: _loading
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                        children: [
                          _buildSkeletonSection(),
                          _buildSkeletonSection(),
                        ],
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
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kBlue, _kBlue],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          const BoxShadow(
            color: _kBlue,
            blurRadius: 0,
            offset: Offset(0, 5),
          ),
          BoxShadow(
            color: _kBlue.withValues(alpha: 0.267),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
                  style: const TextStyle(fontFamily: 'Boogaloo',
                    fontSize: 32,
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
                  style: const TextStyle(
                    fontFamily: 'Boogaloo',
                    fontSize: 28,
                    color: _kInk,
                    height: 1.1,
                  ),
                ),
              ),
              if (total > 0) _ProgressBadge(completed: completedCount, total: total),
            ],
          ),
          const SizedBox(height: 14),
          // Drawing cards grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              childAspectRatio: 0.82,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: story.drawingIds.length,
            itemBuilder: (context, j) {
              final drawingId = story.drawingIds[j];
              final drawing = _drawings[drawingId];
              final isCompleted =
                  progress.completedDrawingIds.contains(drawingId);
              if (drawing == null) return const SizedBox.shrink();
              return _DrawingCard(
                drawing: drawing,
                isCompleted: isCompleted,
                onImageTap: isCompleted
                    ? (img) => _showFullScreen(context, drawing, img, lang)
                    : null,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 200,
            height: 28,
            decoration: BoxDecoration(
              color: _kInk.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              childAspectRatio: 0.82,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: 4,
            itemBuilder: (_, __) => Container(
              decoration: BoxDecoration(
                color: _kInk.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _kInk.withValues(alpha: 0.10),
                  width: 2,
                ),
              ),
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
// Drawing card — lazy-loads its own image
// ---------------------------------------------------------------------------
class _DrawingCard extends StatefulWidget {
  const _DrawingCard({
    required this.drawing,
    required this.isCompleted,
    required this.onImageTap,
  });

  final DrawingModel drawing;
  final bool isCompleted;
  final void Function(ui.Image)? onImageTap;

  @override
  State<_DrawingCard> createState() => _DrawingCardState();
}

class _DrawingCardState extends State<_DrawingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;
  ui.Image? _image;
  bool _loadFailed = false;

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
    if (widget.isCompleted) _loadImage();
  }

  Future<void> _loadImage() async {
    final img = await _decodeUiImage(widget.drawing.imageColored);
    if (mounted) {
      setState(() {
        _image = img;
        _loadFailed = img == null;
      });
    }
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canTap = widget.isCompleted && _image != null;
    return GestureDetector(
      onTapDown: canTap ? (_) => _pressController.forward() : null,
      onTapUp: canTap
          ? (_) {
              _pressController.reverse();
              widget.onImageTap?.call(_image!);
            }
          : null,
      onTapCancel: canTap ? () => _pressController.reverse() : null,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) =>
            Transform.scale(scale: _scaleAnim.value, child: child),
        child: Container(
          decoration: BoxDecoration(
            color: _kPaper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kInk, width: 2.5),
            boxShadow: const [
              BoxShadow(color: _kInk, blurRadius: 0, offset: Offset(3, 3)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13.5),
            child: Column(
              children: [
                Expanded(child: _buildImageArea()),
                _buildCaption(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageArea() {
    if (widget.isCompleted) {
      if (_image != null) {
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _ImagePainter(image: _image!),
              size: Size.infinite,
            ),
            Positioned(
              top: 0, left: 0, right: 0, height: 36,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(top: 8, right: 8, child: _DoneBadge()),
            Positioned(
              bottom: 8, right: 8,
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: _kInk.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.open_in_full_rounded,
                  color: Colors.white,
                  size: 13,
                ),
              ),
            ),
          ],
        );
      }
      if (_loadFailed) {
        return Container(
          color: _kInk.withValues(alpha: 0.06),
          child: const Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 32),
          ),
        );
      }
      // Still loading
      return Container(color: _kInk.withValues(alpha: 0.08));
    }
    // Locked
    return Container(
      color: _kInk.withValues(alpha: 0.06),
      child: Center(
        child: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: _kYellow,
            shape: BoxShape.circle,
            border: Border.all(color: _kInk, width: 2.5),
            boxShadow: const [
              BoxShadow(color: _kInk, blurRadius: 0, offset: Offset(2, 2)),
            ],
          ),
          child: const Icon(Icons.lock_rounded, color: _kInk, size: 24),
        ),
      ),
    );
  }

  Widget _buildCaption(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isCompleted
            ? _kYellow.withValues(alpha: 0.18)
            : _kInk.withValues(alpha: 0.04),
        border: Border(
          top: BorderSide(color: _kInk.withValues(alpha: 0.20), width: 1.5),
        ),
      ),
      child: Text(
        AppLocalizations.of(context)!.chapter(widget.drawing.chapter),
        style: const TextStyle(
          fontFamily: 'Boogaloo',
          fontSize: 16,
          color: _kInk,
          height: 1.0,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full-screen dialog
// ---------------------------------------------------------------------------
class _FullScreenDialog extends StatefulWidget {
  const _FullScreenDialog({
    required this.drawing,
    required this.image,
    required this.lang,
  });

  final DrawingModel drawing;
  final ui.Image image;
  final String lang;

  @override
  State<_FullScreenDialog> createState() => _FullScreenDialogState();
}

class _FullScreenDialogState extends State<_FullScreenDialog> {
  final _repaintKey = GlobalKey();
  bool _saving = false;

  Future<void> _saveToPhotos() async {
    setState(() => _saving = true);
    try {
      final hasAccess = await Gal.hasAccess(toAlbum: false);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: false);
        if (!granted) {
          if (mounted) setState(() => _saving = false);
          return;
        }
      }
      final boundary =
          _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      final img = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      await Gal.putImageBytes(byteData.buffer.asUint8List());
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Saved to Photos!',
              style: TextStyle(fontFamily: 'Boogaloo', fontSize: 16),
            ),
            duration: Duration(seconds: 2),
            backgroundColor: _kGreen,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: _kInk,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: _kInk.withValues(alpha: 0.25), width: 3),
          boxShadow: [
            BoxShadow(
              color: _kInk.withValues(alpha: 0.40),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(29),
          child: Stack(
            children: [
              RepaintBoundary(
                key: _repaintKey,
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: CustomPaint(
                    painter: _ImagePainter(image: widget.image),
                    size: Size.infinite,
                  ),
                ),
              ),
              // Gradient footer with title + save button
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [_kInk.withValues(alpha: 0.8), Colors.transparent],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.chapter(widget.drawing.chapter),
                        style: const TextStyle(
                          fontFamily: 'Boogaloo',
                          fontSize: 28,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: _saving ? null : _saveToPhotos,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 10),
                          decoration: BoxDecoration(
                            color: _saving
                                ? Colors.white38
                                : _kGreen,
                            borderRadius: BorderRadius.circular(99),
                            border:
                                Border.all(color: Colors.white, width: 2),
                            boxShadow: _saving
                                ? []
                                : [
                                    const BoxShadow(
                                      color: _kInk,
                                      blurRadius: 0,
                                      offset: Offset(3, 3),
                                    ),
                                  ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_saving)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              else
                                const Icon(Icons.download_rounded,
                                    color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                _saving ? 'Saving…' : 'Save to Photos',
                                style: const TextStyle(
                                  fontFamily: 'Boogaloo',
                                  color: Colors.white,
                                  fontSize: 18,
                                  height: 1.0,
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
                      color: _kInk.withValues(alpha: 0.7),
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
              // Gold star badge
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _kYellow,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFF8B6914),
                        blurRadius: 0,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 16, color: _kInk),
                      SizedBox(width: 4),
                      Text(
                        'Done',
                        style: TextStyle(
                          fontFamily: 'Boogaloo',
                          fontSize: 14,
                          color: _kInk,
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
            color: _kYellow.withValues(alpha: 0.9), size: 22),
        const SizedBox(width: 2),
        Icon(Icons.star_rounded,
            color: _kYellow.withValues(alpha: 0.6), size: 16),
        const SizedBox(width: 2),
        Icon(Icons.star_rounded,
            color: _kYellow.withValues(alpha: 0.35), size: 12),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Done badge (overlays completed drawing cards)
// ---------------------------------------------------------------------------
class _DoneBadge extends StatelessWidget {
  const _DoneBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _kYellow,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _kInk, width: 2),
        boxShadow: const [
          BoxShadow(color: _kInk, blurRadius: 0, offset: Offset(2, 2)),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: _kInk, size: 12),
          SizedBox(width: 3),
          Text(
            'Done',
            style: TextStyle(
              fontFamily: 'Boogaloo',
              fontSize: 13,
              color: _kInk,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Story progress badge (e.g. "2 / 4")
// ---------------------------------------------------------------------------
class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final isDone = completed == total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: isDone ? _kGreen : _kBlue,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _kInk, width: 2),
        boxShadow: const [
          BoxShadow(color: _kInk, blurRadius: 0, offset: Offset(2, 2)),
        ],
      ),
      child: Text(
        '$completed / $total',
        style: const TextStyle(
          fontFamily: 'Boogaloo',
          fontSize: 16,
          color: Colors.white,
          height: 1.0,
        ),
      ),
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
      ..color = _kInk.withValues(alpha: 0.04)
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
