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
import '../../services/asset_service.dart';
import '../../services/audio_service.dart';
import '../../services/progress_service.dart';

// Stardust Claymorphism tokens
const _kGold = Color(0xFFFFD93D);
const _kCoral = Color(0xFFFF6B6B);
const _kNight = Color(0xFF1A0E3F);
const _kPrimary = Color(0xFF6C48FF);
const _kPrimaryLight = Color(0xFF9C6FFF);
const _kBorder = Color(0xFFD4C8FF);

enum _CompletionPhase {
  colorReveal,       // Colored image sweeps in
  nameReveal,        // Drawing name + celebration
  chapterNarration,  // Story text on image bg + voice
  tutorialSteps,     // How-to-draw images (if any)
}

class CompletionScreen extends ConsumerStatefulWidget {
  const CompletionScreen({super.key, required this.drawingId});

  final String drawingId;

  @override
  ConsumerState<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends ConsumerState<CompletionScreen>
    with TickerProviderStateMixin {
  DrawingModel? _drawing;
  ui.Image? _coloredImage;
  bool _loading = true;

  // Reveal animation
  late AnimationController _revealController;
  late Animation<double> _revealAnim;

  // Celebration particles
  late AnimationController _celebController;

  _CompletionPhase _phase = _CompletionPhase.colorReveal;
  int _tutorialStepIndex = 0;
  bool _nameVisible = false;

  // Chapter narration data (loaded alongside drawing)
  String _narrationText = '';
  int _chapterNumber = 1;
  String _storyId = '';
  String? _nextDrawingId;

  // Narration audio state
  bool _narrationPlaying = false;
  StreamSubscription<void>? _narrationSub;

  @override
  void initState() {
    super.initState();

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _nextPhase();
      });

    _revealAnim = CurvedAnimation(
      parent: _revealController,
      curve: Curves.easeInOut,
    );

    _celebController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _loadDrawing();
  }

  Future<void> _loadDrawing() async {
    try {
      final lang = ref.read(progressProvider).selectedLanguage;
      final assetSvc = ref.read(assetServiceProvider);

      final drawing = await assetSvc.loadDrawing(widget.drawingId);
      final colored = await _loadUiImage(drawing.imageColored);

      // Load story context for chapter narration
      final stories = await assetSvc.loadStories();
      final story = stories.firstWhere(
        (s) => s.id == drawing.storyId,
        orElse: () => stories.first,
      );
      final chapterIdx = story.drawingIds.indexOf(drawing.id);
      final chapter =
          (chapterIdx >= 0 && chapterIdx < story.chapters.length)
              ? story.chapters[chapterIdx]
              : null;

      if (!mounted) return;
      setState(() {
        _drawing = drawing;
        _coloredImage = colored;
        _narrationText = chapter?.getNarration(lang) ?? '';
        _chapterNumber = chapter?.chapter ?? (chapterIdx + 1);
        _storyId = story.id;
        _nextDrawingId = chapterIdx < story.drawingIds.length - 1
            ? story.drawingIds[chapterIdx + 1]
            : null;
        _loading = false;
      });

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

  // ── Phase transitions ────────────────────────────────────────────────────

  void _nextPhase() {
    final drawing = _drawing;
    if (drawing == null) return;

    switch (_phase) {
      case _CompletionPhase.colorReveal:
        setState(() {
          _phase = _CompletionPhase.nameReveal;
          _nameVisible = false;
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _nameVisible = true);
          final lang = ref.read(progressProvider).selectedLanguage;
          ref.read(audioServiceProvider).playDrawingName(lang, drawing.id);
        });
        // Auto-advance to narration phase
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _phase == _CompletionPhase.nameReveal) _nextPhase();
        });
        break;

      case _CompletionPhase.nameReveal:
        setState(() => _phase = _CompletionPhase.chapterNarration);
        if (_narrationText.isNotEmpty) _playNarration();
        break;

      case _CompletionPhase.chapterNarration:
        _stopNarration();
        if (drawing.tutorialSteps.isNotEmpty) {
          setState(() {
            _phase = _CompletionPhase.tutorialSteps;
            _tutorialStepIndex = 0;
          });
        } else {
          _navigateNext();
        }
        break;

      case _CompletionPhase.tutorialSteps:
        if (_tutorialStepIndex < drawing.tutorialSteps.length - 1) {
          setState(() => _tutorialStepIndex++);
        } else {
          _navigateNext();
        }
        break;
    }
  }

  // ── Narration audio ──────────────────────────────────────────────────────

  void _playNarration() {
    _narrationSub?.cancel();
    final lang = ref.read(progressProvider).selectedLanguage;
    ref.read(audioServiceProvider)
        .playChapterNarration(lang, _storyId, _chapterNumber);
    setState(() => _narrationPlaying = true);
    _narrationSub = ref
        .read(audioServiceProvider)
        .voiceoverPlayer
        .onPlayerComplete
        .listen((_) {
      if (mounted) setState(() => _narrationPlaying = false);
    });
  }

  void _stopNarration() {
    _narrationSub?.cancel();
    _narrationSub = null;
    try {
      ref.read(audioServiceProvider).voiceoverPlayer.stop();
    } catch (_) {}
    if (mounted) setState(() => _narrationPlaying = false);
  }

  Future<void> _navigateNext() async {
    final drawing = _drawing;
    if (drawing == null) return;

    await ref
        .read(progressProvider.notifier)
        .markDrawingComplete(drawing.id);
    if (!mounted) return;

    final nextId = _nextDrawingId;
    if (nextId != null) {
      context.go('/drawing/$nextId');
    } else {
      context.go('/story-complete/$_storyId');
    }
  }

  @override
  void dispose() {
    _revealController.dispose();
    _celebController.dispose();
    _narrationSub?.cancel();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading || _drawing == null) {
      return Scaffold(
        backgroundColor: _kNight,
        body: const Center(
          child: CircularProgressIndicator(
            color: _kPrimaryLight,
            strokeWidth: 3,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _kNight,
      body: SafeArea(child: _buildPhase()),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _CompletionPhase.colorReveal:
        return _buildColorReveal();
      case _CompletionPhase.nameReveal:
        return _buildNameReveal();
      case _CompletionPhase.chapterNarration:
        return _buildChapterNarration();
      case _CompletionPhase.tutorialSteps:
        return _buildTutorialSteps();
    }
  }

  // ── Color reveal ─────────────────────────────────────────────────────────

  Widget _buildColorReveal() {
    final drawing = _drawing!;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: const Color(0xFFFFF9F0)),
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
        // Name badge
        Positioned(
          top: 20,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C48FF), Color(0xFF9C6FFF)],
                ),
                borderRadius: BorderRadius.circular(99),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xFF3B1FCC),
                    blurRadius: 0,
                    offset: Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Color(0x446C48FF),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Text(
                drawing.getName(
                    ref.read(progressProvider).selectedLanguage),
                style: GoogleFonts.fredoka(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Name reveal ──────────────────────────────────────────────────────────

  Widget _buildNameReveal() {
    final drawing = _drawing!;
    final lang = ref.read(progressProvider).selectedLanguage;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _nextPhase();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_coloredImage != null)
            CustomPaint(
              painter: _FullImagePainter(image: _coloredImage!),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0xCC1A0E3F)],
                stops: [0.4, 1.0],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _celebController,
            builder: (_, __) => CustomPaint(
              painter:
                  _CelebStarsPainter(progress: _celebController.value),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 24,
            right: 24,
            child: AnimatedOpacity(
              opacity: _nameVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    drawing.getName(lang),
                    style: GoogleFonts.fredoka(
                      color: Colors.white,
                      fontSize: 58,
                      fontWeight: FontWeight.w700,
                      shadows: const [
                        Shadow(
                            color: Color(0xFF1A0E3F),
                            blurRadius: 12,
                            offset: Offset(0, 4)),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context)!.youDrewIt,
                    style: GoogleFonts.fredoka(
                      color: _kGold,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      shadows: const [
                        Shadow(color: Color(0xFF1A0E3F), blurRadius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    AppLocalizations.of(context)!.tapToContinue,
                    style: GoogleFonts.nunito(
                      color: Colors.white.withValues(alpha: 0.7),
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

  // ── Chapter narration ────────────────────────────────────────────────────

  Widget _buildChapterNarration() {
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Colored image as atmospheric background
        if (_coloredImage != null)
          CustomPaint(painter: _FullImagePainter(image: _coloredImage!)),
        // Deep gradient overlay
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xBB1A0E3F),
                Color(0xF01A0E3F),
              ],
              stops: [0.0, 0.6],
            ),
          ),
        ),
        // Twinkling stars
        AnimatedBuilder(
          animation: _celebController,
          builder: (_, __) =>
              CustomPaint(painter: _StarsPainter(t: _celebController.value)),
        ),
        // Content
        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Chapter badge
              _ChapterBadge(chapterLabel: l10n.chapter(_chapterNumber)),
              const SizedBox(height: 24),
              // Narration clay card (scrollable if long)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 700),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.97),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: _kBorder, width: 3),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFF3B1FCC),
                            blurRadius: 0,
                            offset: Offset(5, 5),
                          ),
                          BoxShadow(
                            color: Color(0x556C48FF),
                            blurRadius: 30,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                        child: Text(
                          _narrationText.isNotEmpty
                              ? _narrationText
                              : '…',
                          style: GoogleFonts.nunito(
                            fontSize: 22,
                            height: 1.65,
                            color: const Color(0xFF1A0A3F),
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Replay voice button
              _VoiceReplayButton(
                playing: _narrationPlaying,
                onTap: _playNarration,
                tooltip: l10n.playVoice,
              ),
              const SizedBox(height: 24),
              // Continue button
              Padding(
                padding: const EdgeInsets.only(bottom: 36),
                child: _CelebButton(
                  label: _nextDrawingId != null
                      ? l10n.letsDraw
                      : l10n.keepGoing,
                  onTap: _nextPhase,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Tutorial steps ───────────────────────────────────────────────────────

  Widget _buildTutorialSteps() {
    final drawing = _drawing!;
    final l10n = AppLocalizations.of(context)!;

    if (drawing.tutorialSteps.isEmpty) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _nextPhase();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1A0E3F),
                    Color(0xFF6C48FF),
                    Color(0xFF9C3FFF),
                  ],
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _celebController,
              builder: (_, __) => CustomPaint(
                painter:
                    _CelebStarsPainter(progress: _celebController.value),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: _kGold,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _kGold.withValues(alpha: 0.6),
                          blurRadius: 0,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: _kGold.withValues(alpha: 0.4),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.star_rounded,
                        color: Color(0xFF1A0E3F), size: 72),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    l10n.amazing,
                    style: GoogleFonts.fredoka(
                      color: Colors.white,
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.youConnectedAllDots,
                    style: GoogleFonts.nunito(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  _CelebButton(
                    label: l10n.keepGoing,
                    onTap: _nextPhase,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _nextPhase();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),
          Image.asset(
            drawing.tutorialSteps[_tutorialStepIndex],
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFFFFF9F0),
              child: const Center(
                child: Icon(Icons.image, size: 80, color: Colors.grey),
              ),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C48FF), Color(0xFF9C6FFF)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFF3B1FCC),
                      blurRadius: 0,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  '${_tutorialStepIndex + 1} / ${drawing.tutorialSteps.length}  ·  ${l10n.tapToContinue}',
                  style: GoogleFonts.fredoka(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chapter badge ─────────────────────────────────────────────────────────────

class _ChapterBadge extends StatelessWidget {
  const _ChapterBadge({required this.chapterLabel});
  final String chapterLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C48FF), Color(0xFF9C6FFF)],
        ),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF3B1FCC),
            blurRadius: 0,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x446C48FF),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_stories_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            chapterLabel,
            style: GoogleFonts.fredoka(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Voice replay button ───────────────────────────────────────────────────────

class _VoiceReplayButton extends StatefulWidget {
  const _VoiceReplayButton({
    required this.playing,
    required this.onTap,
    required this.tooltip,
  });
  final bool playing;
  final VoidCallback onTap;
  final String tooltip;

  @override
  State<_VoiceReplayButton> createState() => _VoiceReplayButtonState();
}

class _VoiceReplayButtonState extends State<_VoiceReplayButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (_, child) {
            final scale =
                widget.playing ? (1.0 + _pulse.value * 0.12) : 1.0;
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: widget.playing
                  ? _kPrimary.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 2.5,
              ),
              boxShadow: widget.playing
                  ? [
                      BoxShadow(
                        color: _kPrimary.withValues(alpha: 0.6),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              widget.playing
                  ? Icons.volume_up_rounded
                  : Icons.replay_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Full-image painter ────────────────────────────────────────────────────────

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

// ── Celebration particles ─────────────────────────────────────────────────────

class _CelebStarsPainter extends CustomPainter {
  const _CelebStarsPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(12);
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 40; i++) {
      final x = rand.nextDouble() * size.width;
      final baseY = rand.nextDouble() * size.height;
      final speed = 0.3 + rand.nextDouble() * 0.7;
      final y = (baseY - progress * size.height * speed) % size.height;
      final r = 1.5 + rand.nextDouble() * 3.5;
      final phase = rand.nextDouble() * math.pi * 2;
      final t = 0.4 + 0.6 * math.sin(progress * math.pi * 4 + phase);

      const starColors = [
        Color(0xFFFFD93D),
        Color(0xFFFF6B6B),
        Color(0xFF6BCB77),
        Color(0xFF4FC3F7),
        Color(0xFFFFFFFF),
      ];
      paint.color =
          starColors[i % starColors.length].withValues(alpha: t * 0.85);
      canvas.drawCircle(
          Offset(x, y < 0 ? y + size.height : y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_CelebStarsPainter old) => old.progress != progress;
}

// ── Static twinkling stars (for narration bg) ─────────────────────────────────

class _StarsPainter extends CustomPainter {
  const _StarsPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(77);
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 60; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final phase = rand.nextDouble() * math.pi * 2;
      final brightness = 0.3 + 0.7 * math.sin(t * math.pi * 2 + phase);
      paint.color = Colors.white.withValues(alpha: brightness * 0.6);
      canvas.drawCircle(Offset(x, y), 1.0 + rand.nextDouble() * 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) => old.t != t;
}

// ── Celebration CTA button ────────────────────────────────────────────────────

class _CelebButton extends StatefulWidget {
  const _CelebButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_CelebButton> createState() => _CelebButtonState();
}

class _CelebButtonState extends State<_CelebButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: _pressed
            ? Matrix4.translationValues(0, 5, 0)
            : Matrix4.identity(),
        padding:
            const EdgeInsets.symmetric(horizontal: 52, vertical: 20),
        decoration: BoxDecoration(
          color: _kCoral,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.3), width: 2),
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
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ],
        ),
        child: Text(
          widget.label,
          style: GoogleFonts.fredoka(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
