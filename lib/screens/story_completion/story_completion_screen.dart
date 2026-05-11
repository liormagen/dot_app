import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/drawing_model.dart';
import '../../services/asset_service.dart';
import '../../services/progress_service.dart';

// Toca Boca / Handmade tokens
const _kRed    = Color(0xFFE82D2D);
const _kYellow = Color(0xFFF5C800);
const _kGreen  = Color(0xFF2DB84B);
const _kBlue   = Color(0xFF1FA3E8);
const _kInk    = Color(0xFF1A1A2E);
const _kPaper  = Color(0xFFFFF8E7);

class StoryCompletionScreen extends ConsumerStatefulWidget {
  const StoryCompletionScreen({super.key, required this.storyId});
  final String storyId;

  @override
  ConsumerState<StoryCompletionScreen> createState() =>
      _StoryCompletionScreenState();
}

class _StoryCompletionScreenState extends ConsumerState<StoryCompletionScreen>
    with SingleTickerProviderStateMixin {
  String _storyTitle = '';
  List<DrawingModel> _drawings = [];
  List<ui.Image?> _coloredImages = [];
  bool _loading = true;

  late AnimationController _celebCtrl;

  @override
  void initState() {
    super.initState();
    _celebCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _loadData();
  }

  @override
  void dispose() {
    _celebCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final lang = ref.read(progressProvider).selectedLanguage;
      final assetSvc = ref.read(assetServiceProvider);
      final stories = await assetSvc.loadStories();
      final story = stories.firstWhere(
        (s) => s.id == widget.storyId,
        orElse: () => stories.first,
      );
      final drawings = await assetSvc.loadStoryDrawings(story);

      final images = <ui.Image?>[];
      for (final d in drawings) {
        images.add(await _loadUiImage(d.imageColored));
      }

      if (!mounted) return;
      setState(() {
        _storyTitle = story.getTitle(lang);
        _drawings = drawings;
        _coloredImages = images;
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
    if (_loading) {
      return const Scaffold(
        backgroundColor: _kPaper,
        body: Center(
          child: CircularProgressIndicator(color: _kBlue, strokeWidth: 3),
        ),
      );
    }

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: _kPaper,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _celebCtrl,
              builder: (_, __) => CustomPaint(
                painter: _ConfettiPainter(progress: _celebCtrl.value),
              ),
            ),
            Column(
              children: [
                // ── Header ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                  child: Column(
                    children: [
                      const Text('🎉', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 8),
                      Text(
                        l10n.storyComplete,
                        style: const TextStyle(
                          fontFamily: 'Boogaloo',
                          fontSize: 48,
                          color: _kInk,
                          height: 1.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 6),
                        decoration: BoxDecoration(
                          color: _kYellow,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: _kInk, width: 2),
                          boxShadow: const [
                            BoxShadow(
                                color: _kInk,
                                blurRadius: 0,
                                offset: Offset(3, 3)),
                          ],
                        ),
                        child: Text(
                          _storyTitle,
                          style: const TextStyle(
                            fontFamily: 'Boogaloo',
                            fontSize: 22,
                            color: _kInk,
                            height: 1.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // ── Chapter thumbnails ─────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildThumbnailGrid(),
                  ),
                ),
                // ── Action buttons ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TocaButton(
                          label: l10n.playAgain,
                          color: _kGreen,
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            context.go('/transition/${widget.storyId}/0');
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _TocaButton(
                          label: l10n.backToStories,
                          color: _kBlue,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.go('/stories');
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailGrid() {
    if (_coloredImages.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = _coloredImages.length;
        final crossCount = count <= 3 ? count : (count <= 6 ? 3 : 4);
        const spacing = 14.0;
        final itemSize =
            (constraints.maxWidth - spacing * (crossCount - 1)) / crossCount;
        final cappedSize = itemSize.clamp(0.0, constraints.maxHeight);

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          alignment: WrapAlignment.center,
          children: [
            for (int i = 0; i < _coloredImages.length; i++)
              _buildThumbnail(i, cappedSize),
          ],
        );
      },
    );
  }

  Widget _buildThumbnail(int i, double size) {
    final img = i < _coloredImages.length ? _coloredImages[i] : null;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kInk, width: 3),
        boxShadow: const [
          BoxShadow(color: _kInk, blurRadius: 0, offset: Offset(4, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: img != null
          ? RawImage(image: img, fit: BoxFit.cover)
          : Container(color: _kPaper),
    );
  }
}

// ── Confetti painter ──────────────────────────────────────────────────────────

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(12);
    final paint = Paint()..style = PaintingStyle.fill;
    const colors = [_kYellow, _kRed, _kGreen, _kBlue, Colors.white];

    for (int i = 0; i < 40; i++) {
      final x = rand.nextDouble() * size.width;
      final baseY = rand.nextDouble() * size.height;
      final speed = 0.3 + rand.nextDouble() * 0.7;
      final y = (baseY - progress * size.height * speed) % size.height;
      final r = 1.5 + rand.nextDouble() * 3.5;
      final phase = rand.nextDouble() * math.pi * 2;
      final t = 0.4 + 0.6 * math.sin(progress * math.pi * 4 + phase);
      paint.color = colors[i % colors.length].withValues(alpha: t * 0.6);
      canvas.drawCircle(Offset(x, y < 0 ? y + size.height : y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

// ── Toca Boca button ──────────────────────────────────────────────────────────

class _TocaButton extends StatefulWidget {
  const _TocaButton({
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_TocaButton> createState() => _TocaButtonState();
}

class _TocaButtonState extends State<_TocaButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: _pressed
            ? Matrix4.translationValues(0, 4, 0)
            : Matrix4.identity(),
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _kInk, width: 3),
          boxShadow: _pressed
              ? []
              : const [
                  BoxShadow(
                      color: _kInk,
                      blurRadius: 0,
                      offset: Offset(4, 4)),
                ],
        ),
        child: Text(
          widget.label,
          style: const TextStyle(
            fontFamily: 'Boogaloo',
            color: Colors.white,
            fontSize: 22,
            height: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
