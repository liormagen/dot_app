import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/drawing_model.dart';
import '../../models/story_model.dart';
import '../../services/asset_service.dart';
import '../../services/audio_service.dart';
import '../../services/progress_service.dart';
import '../../widgets/parental_gate.dart';

class StoryCompletionScreen extends ConsumerStatefulWidget {
  const StoryCompletionScreen({super.key, required this.storyId});

  final String storyId;

  @override
  ConsumerState<StoryCompletionScreen> createState() =>
      _StoryCompletionScreenState();
}

class _StoryCompletionScreenState
    extends ConsumerState<StoryCompletionScreen>
    with SingleTickerProviderStateMixin {
  StoryModel? _story;
  List<DrawingModel> _drawings = [];
  List<ui.Image?> _coloredImages = [];
  bool _loading = true;

  late AnimationController _bounceController;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )
      ..repeat(reverse: true);

    _bounceAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
          parent: _bounceController, curve: Curves.easeInOut),
    );

    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final assetService = ref.read(assetServiceProvider);
      final stories = await assetService.loadStories();
      final story = stories.firstWhere(
        (s) => s.id == widget.storyId,
        orElse: () => stories.first,
      );
      final drawings = await assetService.loadStoryDrawings(story);

      final images = <ui.Image?>[];
      for (final d in drawings) {
        images.add(await _loadUiImage(d.imageColored));
      }

      if (!mounted) return;
      setState(() {
        _story = story;
        _drawings = drawings;
        _coloredImages = images;
        _loading = false;
      });

      // Play final narration
      final lang = ref.read(progressProvider).selectedLanguage;
      if (story.chapters.isNotEmpty) {
        ref.read(audioServiceProvider).playChapterNarration(
            lang, story.id, story.chapters.last.chapter);
      }
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
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final story = _story;
    final lang = ref.read(progressProvider).selectedLanguage;

    return Scaffold(
      backgroundColor: const Color(0xFF6B4EFF),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Title
            Text(
              'Quest Complete!',
              style: const TextStyle(
                color: Colors.yellow,
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (story != null)
              Text(
                story.getTitle(lang),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            const SizedBox(height: 20),
            // Companion with bounce
            if (story?.companionAsset != null)
              ScaleTransition(
                scale: _bounceAnim,
                child: SizedBox(
                  height: 160,
                  child: Image.asset(
                    story!.companionAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.star, size: 80, color: Colors.yellow),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            // Drawings row
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: List.generate(_drawings.length, (i) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _buildDrawingCard(i),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Buttons
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/stories'),
                      icon: const Icon(Icons.home),
                      label: const Text('Back to Stories'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF6B4EFF),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final allowed =
                          await ParentalGate.show(context);
                      if (!allowed) return;
                      // Share placeholder - share plugin not included
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Sharing coming soon!')),
                        );
                      }
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9F43),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawingCard(int index) {
    final drawing = _drawings[index];
    final image = _coloredImages.length > index ? _coloredImages[index] : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            Expanded(
              child: image != null
                  ? CustomPaint(
                      painter: _ImagePainter(image: image),
                      size: Size.infinite,
                    )
                  : Center(
                      child: Icon(
                        Icons.image_outlined,
                        color: Colors.white.withOpacity(0.6),
                        size: 48,
                      ),
                    ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                drawing.getName(
                    ref.read(progressProvider).selectedLanguage),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
