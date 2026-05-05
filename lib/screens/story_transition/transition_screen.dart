import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/asset_service.dart';
import '../../services/audio_service.dart';
import '../../services/progress_service.dart';

class TransitionScreen extends ConsumerStatefulWidget {
  const TransitionScreen({
    super.key,
    required this.storyId,
    required this.chapterIndex,
  });

  final String storyId;
  final int chapterIndex;

  @override
  ConsumerState<TransitionScreen> createState() =>
      _TransitionScreenState();
}

class _TransitionScreenState extends ConsumerState<TransitionScreen>
    with SingleTickerProviderStateMixin {
  bool _continueVisible = false;
  late AnimationController _companionController;
  late Animation<double> _companionScale;
  StreamSubscription<void>? _audioSub;
  String? _narrationText;
  String? _companionAsset;
  String? _nextDrawingId;
  bool _loading = true;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();

    _companionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )
      ..forward();

    _companionScale = CurvedAnimation(
      parent: _companionController,
      curve: Curves.elasticOut,
    );

    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final stories = await ref.read(assetServiceProvider).loadStories();
      final story = stories.firstWhere(
        (s) => s.id == widget.storyId,
        orElse: () => stories.first,
      );

      final lang = ref.read(progressProvider).selectedLanguage;
      final chapterIdx = widget.chapterIndex.clamp(0, story.chapters.length - 1);
      final chapter = story.chapters[chapterIdx];
      final narration = chapter.getNarration(lang);

      // Next drawing
      final nextIdx = widget.chapterIndex + 1;
      final nextId = nextIdx < story.drawingIds.length
          ? story.drawingIds[nextIdx]
          : null;

      if (!mounted) return;
      setState(() {
        _narrationText = narration;
        _companionAsset = story.companionAsset;
        _nextDrawingId = nextId;
        _loading = false;
      });

      // Play narration audio
      final audio = ref.read(audioServiceProvider);
      await audio.playChapterNarration(lang, story.id, chapter.chapter);

      // Listen for completion
      _audioSub = audio.voiceoverPlayer.onPlayerComplete.listen((_) {
        _showContinue();
      });

      // Fallback: show continue after 3 seconds even if audio doesn't fire
      _fallbackTimer = Timer(const Duration(seconds: 3), _showContinue);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      _fallbackTimer = Timer(const Duration(seconds: 1), _showContinue);
    }
  }

  void _showContinue() {
    if (!mounted) return;
    _fallbackTimer?.cancel();
    setState(() => _continueVisible = true);
  }

  void _onContinue() {
    final nextId = _nextDrawingId;
    if (nextId == null) {
      context.go('/stories');
      return;
    }
    context.go('/drawing/$nextId');
  }

  @override
  void dispose() {
    _companionController.dispose();
    _audioSub?.cancel();
    _fallbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1040),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: GestureDetector(
                onTap: _continueVisible ? null : _showContinue,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Stars background
                    const _StarBackground(),
                    // Companion
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 60,
                      bottom: 200,
                      child: _buildCompanion(),
                    ),
                    // Narration text
                    Positioned(
                      left: 32,
                      right: 32,
                      bottom: 120,
                      child: _buildNarrationCard(),
                    ),
                    // Continue button
                    if (_continueVisible)
                      Positioned(
                        bottom: 40,
                        left: 0,
                        right: 0,
                        child: Center(child: _buildContinueButton()),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCompanion() {
    final asset = _companionAsset;
    if (asset == null) return const SizedBox.shrink();

    // chapterIndex=0 shows companion at 70% opacity/scale, 1+ shows full
    final opacity = widget.chapterIndex == 0 ? 0.7 : 1.0;

    return ScaleTransition(
      scale: _companionScale,
      child: Opacity(
        opacity: opacity,
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.person, size: 120, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildNarrationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        _narrationText ?? '',
        style: const TextStyle(
          fontSize: 20,
          height: 1.5,
          color: Color(0xFF1A1040),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildContinueButton() {
    return AnimatedOpacity(
      opacity: _continueVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      child: ElevatedButton.icon(
        onPressed: _onContinue,
        icon: const Icon(Icons.arrow_forward),
        label: const Text(
          'Continue',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF9F43),
          foregroundColor: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }
}

class _StarBackground extends StatelessWidget {
  const _StarBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StarPainter(),
      size: Size.infinite,
    );
  }
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.6);
    // Simple pseudo-random stars
    final positions = [
      const Offset(0.1, 0.05),
      const Offset(0.3, 0.12),
      const Offset(0.7, 0.08),
      const Offset(0.9, 0.15),
      const Offset(0.2, 0.25),
      const Offset(0.5, 0.18),
      const Offset(0.85, 0.3),
      const Offset(0.05, 0.4),
      const Offset(0.95, 0.55),
      const Offset(0.15, 0.7),
      const Offset(0.8, 0.72),
      const Offset(0.4, 0.85),
      const Offset(0.65, 0.92),
    ];
    for (final rel in positions) {
      canvas.drawCircle(
          Offset(rel.dx * size.width, rel.dy * size.height), 2, paint);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => false;
}
