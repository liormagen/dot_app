import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../models/drawing_model.dart';
import '../../models/story_model.dart';
import '../../services/asset_service.dart';
import '../../services/audio_service.dart';
import '../../services/progress_service.dart';

// Stardust Claymorphism tokens
const _kNight = Color(0xFF1A0E3F);
const _kPrimary = Color(0xFF6C48FF);
const _kPrimaryLight = Color(0xFF9C6FFF);
const _kGold = Color(0xFFFFD93D);
const _kCoral = Color(0xFFFF6B6B);
const _kBorder = Color(0xFFD4C8FF);
const _kForeground = Color(0xFF1A0A3F);

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
  List<String> _narrations = [];
  bool _loading = true;

  // Which chapter's narration is currently playing (-1 = none)
  int _playingIndex = -1;
  StreamSubscription<void>? _narrationSub;
  Timer? _narrationDelay;

  late AnimationController _starsCtrl;

  @override
  void initState() {
    super.initState();
    _starsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _loadData();
  }

  @override
  void dispose() {
    _starsCtrl.dispose();
    _narrationSub?.cancel();
    _narrationDelay?.cancel();
    try {
      ref.read(audioServiceProvider).voiceoverPlayer.stop();
    } catch (_) {}
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

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

      final narrations = story.chapters
          .map((c) => c.getNarration(lang))
          .toList();

      if (!mounted) return;
      setState(() {
        _story = story;
        _drawings = drawings;
        _coloredImages = images;
        _narrations = narrations;
        _loading = false;
      });

      // Auto-play all narrations in sequence
      _playNarrationSequence(0);
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

  // ── Audio ─────────────────────────────────────────────────────────────────

  void _playNarrationSequence(int index) {
    if (!mounted) return;
    if (index >= (_story?.chapters.length ?? 0)) {
      setState(() => _playingIndex = -1);
      return;
    }
    _playChapter(index, autoAdvance: true);
  }

  void _playChapter(int index, {bool autoAdvance = false}) {
    if (!mounted) return;
    _narrationSub?.cancel();
    _narrationDelay?.cancel();
    final story = _story;
    if (story == null || index >= story.chapters.length) return;

    final lang = ref.read(progressProvider).selectedLanguage;
    ref.read(audioServiceProvider).playChapterNarration(
        lang, story.id, story.chapters[index].chapter);
    setState(() => _playingIndex = index);

    _narrationSub =
        ref.read(audioServiceProvider).voiceoverPlayer.onPlayerComplete
            .listen((_) {
      if (!mounted) return;
      setState(() => _playingIndex = -1);
      if (autoAdvance) {
        // 1.5-second pause between chapters
        _narrationDelay =
            Timer(const Duration(milliseconds: 1500), () {
          _playNarrationSequence(index + 1);
        });
      }
    });
  }

  void _replayChapter(int index) {
    HapticFeedback.lightImpact();
    _playChapter(index, autoAdvance: false);
  }

  void _replayAll() {
    HapticFeedback.mediumImpact();
    _playNarrationSequence(0);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _kNight,
        body: Center(
          child: CircularProgressIndicator(
            color: _kPrimaryLight,
            strokeWidth: 3,
          ),
        ),
      );
    }

    final story = _story!;
    final lang = ref.read(progressProvider).selectedLanguage;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: _kNight,
      body: Stack(
        children: [
          // Twinkling star background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _starsCtrl,
              builder: (_, __) => CustomPaint(
                painter: _StarFieldPainter(t: _starsCtrl.value),
              ),
            ),
          ),
          // Main content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Header ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _buildHeader(story, lang, l10n),
              ),
              // ── Chapter cards ────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _buildChapterCard(i, story, lang, l10n),
                    childCount:
                        math.min(_drawings.length, story.chapters.length),
                  ),
                ),
              ),
              // ── Bottom actions ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: _buildBottomActions(l10n),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(StoryModel story, String lang, AppLocalizations l10n) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(24, top + 20, 24, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1060), Color(0xFF4B2EA0)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF3B1FCC),
            blurRadius: 0,
            offset: Offset(0, 6),
          ),
          BoxShadow(
            color: Color(0x556C48FF),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          // Quest complete badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: _kGold,
              borderRadius: BorderRadius.circular(99),
              boxShadow: [
                BoxShadow(
                  color: _kGold.withValues(alpha: 0.6),
                  blurRadius: 0,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded,
                    color: _kForeground, size: 20),
                const SizedBox(width: 6),
                Text(
                  l10n.storyComplete,
                  style: GoogleFonts.fredoka(
                    color: _kForeground,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.star_rounded,
                    color: _kForeground, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Story title
          Text(
            story.getTitle(lang),
            style: GoogleFonts.fredoka(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.ourStory,
            style: GoogleFonts.nunito(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          // Play all button
          GestureDetector(
            onTap: _replayAll,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_circle_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    l10n.replay,
                    style: GoogleFonts.fredoka(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
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

  // ── Chapter card ──────────────────────────────────────────────────────────

  Widget _buildChapterCard(
    int i,
    StoryModel story,
    String lang,
    AppLocalizations l10n,
  ) {
    final drawing = _drawings[i];
    final image = i < _coloredImages.length ? _coloredImages[i] : null;
    final narration = i < _narrations.length ? _narrations[i] : '';
    final chapter = story.chapters[i];
    final isPlaying = _playingIndex == i;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _kBorder, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF3B1FCC),
              blurRadius: 0,
              offset: Offset(5, 5),
            ),
            BoxShadow(
              color: Color(0x336C48FF),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Chapter image ──────────────────────────────────────────
              AspectRatio(
                aspectRatio: 4 / 3,
                child: image != null
                    ? CustomPaint(
                        painter: _ImagePainter(image: image),
                        size: Size.infinite,
                      )
                    : Container(
                        color: const Color(0xFFE0D9FF),
                        child: Center(
                          child: Icon(
                            Icons.image_rounded,
                            size: 60,
                            color: _kPrimary.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
              ),
              // ── Chapter header bar ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6C48FF), Color(0xFF9C6FFF)],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_stories_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.chapter(chapter.chapter),
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    // Drawing name badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        drawing.getName(lang),
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Narration text + replay ────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        narration.isNotEmpty ? narration : '…',
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          height: 1.65,
                          color: _kForeground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Replay button
                    _ChapterReplayButton(
                      playing: isPlaying,
                      onTap: () => _replayChapter(i),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom actions ────────────────────────────────────────────────────────

  Widget _buildBottomActions(AppLocalizations l10n) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        MediaQuery.of(context).padding.bottom + 32,
      ),
      child: _StoryButton(
        label: l10n.backToStories,
        icon: Icons.home_rounded,
        onTap: () => context.go('/stories'),
      ),
    );
  }
}

// ── Chapter replay icon button ────────────────────────────────────────────────

class _ChapterReplayButton extends StatefulWidget {
  const _ChapterReplayButton({
    required this.playing,
    required this.onTap,
  });
  final bool playing;
  final VoidCallback onTap;

  @override
  State<_ChapterReplayButton> createState() => _ChapterReplayButtonState();
}

class _ChapterReplayButtonState extends State<_ChapterReplayButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) {
          final scale =
              widget.playing ? (1.0 + _pulse.value * 0.15) : 1.0;
          return Transform.scale(scale: scale, child: child);
        },
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: widget.playing
                ? _kPrimary
                : _kPrimary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: _kPrimary.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: widget.playing
                ? [
                    BoxShadow(
                      color: _kPrimary.withValues(alpha: 0.5),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            widget.playing
                ? Icons.volume_up_rounded
                : Icons.replay_rounded,
            color: widget.playing ? Colors.white : _kPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

// ── Story action button ───────────────────────────────────────────────────────

class _StoryButton extends StatefulWidget {
  const _StoryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_StoryButton> createState() => _StoryButtonState();
}

class _StoryButtonState extends State<_StoryButton> {
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
        duration: const Duration(milliseconds: 100),
        transform: _pressed
            ? Matrix4.translationValues(0, 4, 0)
            : Matrix4.identity(),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: _kCoral,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: _pressed
              ? []
              : [
                  BoxShadow(
                    color: _kCoral.withValues(alpha: 0.75),
                    blurRadius: 0,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: _kCoral.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              widget.label,
              style: GoogleFonts.fredoka(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Painters ──────────────────────────────────────────────────────────────────

class _StarFieldPainter extends CustomPainter {
  const _StarFieldPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(42);
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 80; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final phase = rand.nextDouble() * math.pi * 2;
      final brightness =
          0.3 + 0.7 * math.sin(t * math.pi * 2 + phase);
      paint.color = (rand.nextDouble() > 0.85
              ? const Color(0xFFFFD93D)
              : Colors.white)
          .withValues(alpha: brightness * 0.55);
      canvas.drawCircle(
          Offset(x, y), 0.8 + rand.nextDouble() * 1.6, paint);
    }
  }

  @override
  bool shouldRepaint(_StarFieldPainter old) => old.t != t;
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
