import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/drawing_model.dart';
import '../../models/progress_model.dart';
import '../../models/story_model.dart';
import '../../services/asset_service.dart';
import '../../services/progress_service.dart';

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

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6B4EFF),
        foregroundColor: Colors.white,
        title: const Text(
          'Gallery',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/stories'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _stories.length,
              itemBuilder: (context, i) {
                final story = _stories[i];
                return _buildStorySection(story, progress);
              },
            ),
    );
  }

  Widget _buildStorySection(StoryModel story, ProgressModel progress) {
    final lang = progress.selectedLanguage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
          child: Text(
            story.getTitle(lang),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6B4EFF),
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: story.drawingIds.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, j) {
              final drawingId = story.drawingIds[j];
              final drawing = _drawings[drawingId];
              final image = _coloredImages[drawingId];
              final isCompleted =
                  progress.completedDrawingIds.contains(drawingId);

              if (drawing == null) return const SizedBox(width: 140);

              return GestureDetector(
                onTap: isCompleted && image != null
                    ? () => _showFullScreen(context, drawing, image, lang)
                    : null,
                child: Container(
                  width: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: [
                        Expanded(
                          child: isCompleted && image != null
                              ? CustomPaint(
                                  painter: _ImagePainter(image: image),
                                  size: Size.infinite,
                                )
                              : _buildSilhouette(),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            isCompleted
                                ? drawing.getName(lang)
                                : '???',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isCompleted
                                  ? const Color(0xFF6B4EFF)
                                  : Colors.grey,
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
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSilhouette() {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline,
                size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              '?',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
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
      builder: (_) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            CustomPaint(
              painter: _ImagePainter(image: image),
              child: const AspectRatio(aspectRatio: 1.0),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Text(
                drawing.getName(lang),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
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
