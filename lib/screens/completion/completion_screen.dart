import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/drawing_model.dart';
import '../../services/asset_service.dart';
import '../../services/audio_service.dart';
import '../../services/progress_service.dart';
import 'color_fill_canvas.dart';

enum _CompletionPhase {
  colorReveal,
  nameReveal,
  tutorialSteps,
  coloring,
}

class CompletionScreen extends ConsumerStatefulWidget {
  const CompletionScreen({super.key, required this.drawingId});

  final String drawingId;

  @override
  ConsumerState<CompletionScreen> createState() =>
      _CompletionScreenState();
}

class _CompletionScreenState extends ConsumerState<CompletionScreen>
    with SingleTickerProviderStateMixin {
  DrawingModel? _drawing;
  ui.Image? _outlineImage;
  ui.Image? _coloredImage;
  bool _loading = true;

  late AnimationController _revealController;
  late Animation<double> _revealAnim;

  _CompletionPhase _phase = _CompletionPhase.colorReveal;
  int _tutorialStepIndex = 0;

  // Name reveal
  bool _nameVisible = false;

  @override
  void initState() {
    super.initState();

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _nextPhase();
        }
      });

    _revealAnim = CurvedAnimation(
      parent: _revealController,
      curve: Curves.easeInOut,
    );

    _loadDrawing();
  }

  Future<void> _loadDrawing() async {
    try {
      final drawing =
          await ref.read(assetServiceProvider).loadDrawing(widget.drawingId);
      final outline = await _loadUiImage(drawing.imageOutline);
      final colored = await _loadUiImage(drawing.imageColored);

      if (!mounted) return;
      setState(() {
        _drawing = drawing;
        _outlineImage = outline;
        _coloredImage = colored;
        _loading = false;
      });

      // Play SFX and start reveal
      ref.read(audioServiceProvider).playDrawingComplete();
      _revealController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
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

  void _nextPhase() {
    final drawing = _drawing;
    if (drawing == null) return;

    switch (_phase) {
      case _CompletionPhase.colorReveal:
        setState(() => _phase = _CompletionPhase.nameReveal);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _nameVisible = true);
          // Play name voiceover
          final lang = ref.read(progressProvider).selectedLanguage;
          ref
              .read(audioServiceProvider)
              .playDrawingName(lang, drawing.id);
        });
        // Auto-advance to tutorial after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _phase == _CompletionPhase.nameReveal) {
            _nextPhase();
          }
        });
        break;

      case _CompletionPhase.nameReveal:
        setState(() => _phase = _CompletionPhase.tutorialSteps);
        break;

      case _CompletionPhase.tutorialSteps:
        if (drawing.tutorialSteps.isNotEmpty &&
            _tutorialStepIndex < drawing.tutorialSteps.length - 1) {
          setState(() => _tutorialStepIndex++);
        } else {
          setState(() => _phase = _CompletionPhase.coloring);
        }
        break;

      case _CompletionPhase.coloring:
        // Done - handled by callback
        break;
    }
  }

  Future<void> _onColoringDone() async {
    final drawing = _drawing;
    if (drawing == null) return;

    await ref
        .read(progressProvider.notifier)
        .markDrawingComplete(drawing.id);

    // Determine navigation
    final stories = await ref.read(assetServiceProvider).loadStories();
    final story = stories.firstWhere(
      (s) => s.id == drawing.storyId,
      orElse: () => stories.first,
    );

    final chapterIndex = story.drawingIds.indexOf(drawing.id);
    if (!mounted) return;

    if (chapterIndex < story.drawingIds.length - 1) {
      context.go('/transition/${story.id}/$chapterIndex');
    } else {
      context.go('/story-complete/${story.id}');
    }
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _drawing == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4FF),
      body: SafeArea(child: _buildPhase()),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _CompletionPhase.colorReveal:
        return _buildColorReveal();
      case _CompletionPhase.nameReveal:
        return _buildNameReveal();
      case _CompletionPhase.tutorialSteps:
        return _buildTutorialSteps();
      case _CompletionPhase.coloring:
        return _buildColoring();
    }
  }

  Widget _buildColorReveal() {
    final drawing = _drawing!;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Outline image (base layer)
        if (_outlineImage != null)
          CustomPaint(
            painter: _FullImagePainter(image: _outlineImage!),
          ),
        // Colored image swept in from left
        if (_coloredImage != null)
          ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: _revealAnim.value,
              child: SizedBox.expand(
                child: CustomPaint(
                  painter: _FullImagePainter(image: _coloredImage!),
                ),
              ),
            ),
          ),
        // Progress text
        Positioned(
          top: 20,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF6B4EFF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                drawing.getName(
                    ref.read(progressProvider).selectedLanguage),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameReveal() {
    final drawing = _drawing!;
    final lang = ref.read(progressProvider).selectedLanguage;

    return GestureDetector(
      onTap: _nextPhase,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_coloredImage != null)
            CustomPaint(
              painter: _FullImagePainter(image: _coloredImage!),
            ),
          // Dark overlay
          Container(color: Colors.black.withOpacity(0.3)),
          // Name
          Center(
            child: AnimatedOpacity(
              opacity: _nameVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    drawing.getName(lang),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 8),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'You drew it!',
                    style: TextStyle(
                      color: Colors.yellow,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Tap to continue',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialSteps() {
    final drawing = _drawing!;

    if (drawing.tutorialSteps.isEmpty) {
      return GestureDetector(
        onTap: _nextPhase,
        child: Container(
          color: const Color(0xFF6B4EFF),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star, color: Colors.yellow, size: 100),
                SizedBox(height: 24),
                Text(
                  'Great Job!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Tap to color your drawing',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _nextPhase,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            drawing.tutorialSteps[_tutorialStepIndex],
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.white,
              child: const Center(
                child: Icon(Icons.image, size: 80, color: Colors.grey),
              ),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_tutorialStepIndex + 1} / ${drawing.tutorialSteps.length}  •  Tap to continue',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColoring() {
    return ColorFillCanvas(
      drawing: _drawing!,
      onDone: _onColoringDone,
    );
  }
}

class _FullImagePainter extends CustomPainter {
  const _FullImagePainter({required this.image});

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
        0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, src, dst, Paint());
  }

  @override
  bool shouldRepaint(_FullImagePainter old) => old.image != image;
}
