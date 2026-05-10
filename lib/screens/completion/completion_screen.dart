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
import '../../services/audio_service.dart';
import '../../models/progress_model.dart';
import '../../services/progress_service.dart';

// Toca Boca / Handmade tokens
const _kRed    = Color(0xFFE82D2D);
const _kYellow = Color(0xFFF5C800);
const _kGreen  = Color(0xFF2DB84B);
const _kBlue   = Color(0xFF1FA3E8);
const _kInk    = Color(0xFF1A1A2E);
const _kPaper  = Color(0xFFFFF8E7);

// Legacy aliases so unchanged sub-widgets compile without edits
const _kGold    = _kYellow;
const _kCoral   = _kRed;
const _kNight   = _kInk;
const _kPrimary = _kBlue;
const _kPrimaryLight = Color(0xFF6BBFFF);
const _kBorder  = _kInk;

enum _CompletionPhase {
  colorReveal,       // Colored image sweeps in
  nameReveal,        // Drawing name + celebration
  chapterNarration,  // Story text on image bg + voice
  tutorialSteps,     // How-to-draw images (if any)
}

class CompletionScreen extends ConsumerStatefulWidget {
  const CompletionScreen({
    super.key,
    required this.drawingId,
    this.skipReveal = false,
    this.elapsedMs,
  });

  final String drawingId;
  // When true the colored image was already revealed on the drawing canvas —
  // skip the sweep animation and go straight to celebration.
  final bool skipReveal;
  // Total elapsed time in milliseconds from when the drawing screen opened
  // until the player finished connecting all dots.
  final int? elapsedMs;

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
  bool _isNewRecord = false;

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
        if (widget.skipReveal) _phase = _CompletionPhase.nameReveal;
        // Personal best detection (Hard/SuperHard only, only when elapsedMs provided)
        final progress = ref.read(progressProvider);
        if (widget.elapsedMs != null &&
            (progress.difficulty == DifficultyMode.hard ||
             progress.difficulty == DifficultyMode.superHard)) {
          final previous = progress.bestTimeMs[widget.drawingId];
          _isNewRecord = previous == null || widget.elapsedMs! < previous;
        }
      });

      if (widget.skipReveal) {
        // Image was already revealed on the canvas — jump to name celebration
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          setState(() => _nameVisible = true);
          ref.read(audioServiceProvider).playDrawingName(lang, drawing.id);
        });
        Future.delayed(const Duration(seconds: 2, milliseconds: 200), () {
          if (mounted && _phase == _CompletionPhase.nameReveal) _nextPhase();
        });
      } else {
        ref.read(audioServiceProvider).playDrawingComplete();
        _revealController.forward();
      }
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

    if (_isNewRecord && widget.elapsedMs != null) {
      await ref
          .read(progressProvider.notifier)
          .saveBestTime(widget.drawingId, widget.elapsedMs!);
    }
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
      return const Scaffold(
        backgroundColor: _kPaper,
        body: Center(
          child: CircularProgressIndicator(
            color: _kBlue,
            strokeWidth: 3,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _kPaper,
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
    return Container(
      color: _kPaper,
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: _RevealImageBox(
                coloredImage: _coloredImage,
                revealProgress: _revealAnim.value,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
            child: _TocaChapterBadge(chapter: _chapterNumber),
          ),
        ],
      ),
    );
  }

  // ── Name reveal ──────────────────────────────────────────────────────────

  Widget _buildNameReveal() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _nextPhase();
      },
      child: Container(
        color: _kPaper,
        child: Column(
          children: [
            // Image — top portion, correct aspect ratio
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _RevealImageBox(
                      coloredImage: _coloredImage,
                      revealProgress: 1.0,
                    ),
                    AnimatedBuilder(
                      animation: _celebController,
                      builder: (_, __) => CustomPaint(
                        painter: _CelebStarsPainter(
                            progress: _celebController.value),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Name + celebration text — bottom portion
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 4, 28, 28),
                child: AnimatedOpacity(
                  opacity: _nameVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 600),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.chapter(_chapterNumber),
                        style: const TextStyle(fontFamily: 'Boogaloo',
                          color: _kInk,
                          fontSize: 52,
                          height: 1.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star_rounded,
                              color: _kYellow, size: 30),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.youDrewIt,
                            style: const TextStyle(fontFamily: 'Boogaloo',
                              color: _kRed,
                              fontSize: 28,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.star_rounded,
                              color: _kYellow, size: 30),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_isNewRecord && widget.elapsedMs != null)
                        _PersonalBestBanner(elapsedMs: widget.elapsedMs!),
                      Text(
                        AppLocalizations.of(context)!.tapToContinue,
                        style: TextStyle(fontFamily: 'Boogaloo',
                          color: _kInk.withValues(alpha: 0.45),
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Chapter narration ────────────────────────────────────────────────────

  Widget _buildChapterNarration() {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      color: _kPaper,
      child: Column(
        children: [
          // Image — top ~40%, correct aspect ratio
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: _RevealImageBox(
                coloredImage: _coloredImage,
                revealProgress: 1.0,
              ),
            ),
          ),
          // Story content — bottom ~60%
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
              child: Column(
                children: [
                  _TocaChapterBadge(chapter: _chapterNumber),
                  const SizedBox(height: 10),
                  // Narration text card
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _kInk, width: 3),
                        boxShadow: const [
                          BoxShadow(
                              color: _kInk,
                              blurRadius: 0,
                              offset: Offset(5, 5)),
                        ],
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                        child: Text(
                          _narrationText.isNotEmpty ? _narrationText : '…',
                          style: const TextStyle(fontFamily: 'Boogaloo',
                            fontSize: 22,
                            height: 1.6,
                            color: _kInk,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Bottom row: voice replay + continue
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _VoiceReplayButton(
                        playing: _narrationPlaying,
                        onTap: _playNarration,
                        tooltip: l10n.playVoice,
                      ),
                      const SizedBox(width: 16),
                      _CelebButton(
                        label: _nextDrawingId != null
                            ? l10n.letsDraw
                            : l10n.keepGoing,
                        onTap: _nextPhase,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
                    style: const TextStyle(fontFamily: 'Fredoka',
                      color: Colors.white,
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.youConnectedAllDots,
                    style: TextStyle(fontFamily: 'Nunito',
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
                  style: const TextStyle(fontFamily: 'Fredoka',
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
            style: const TextStyle(fontFamily: 'Fredoka',
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

// ── Aspect-ratio-correct image box with optional sweep reveal ────────────────

class _RevealImageBox extends StatelessWidget {
  const _RevealImageBox({
    required this.coloredImage,
    required this.revealProgress,
  });

  final ui.Image? coloredImage;
  // 0.0 = fully hidden, 1.0 = fully revealed (left-to-right sweep)
  final double revealProgress;

  @override
  Widget build(BuildContext context) {
    final img = coloredImage;
    if (img == null) {
      return Container(
        decoration: BoxDecoration(
          color: _kPaper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kInk, width: 3),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final imgW = img.width.toDouble();
        final imgH = img.height.toDouble();
        final scale = math.min(
          constraints.maxWidth / imgW,
          constraints.maxHeight / imgH,
        );
        final displayW = imgW * scale;
        final displayH = imgH * scale;

        return Center(
          child: Container(
            width: displayW,
            height: displayH,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kInk, width: 3),
              boxShadow: const [
                BoxShadow(
                    color: _kInk, blurRadius: 0, offset: Offset(6, 6)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RawImage(image: img, fit: BoxFit.fill),
                // Sweep mask: covers right side and shrinks left as progress → 1
                if (revealProgress < 1.0)
                  Align(
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: 1.0 - revealProgress,
                      child: Container(color: _kPaper),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Toca Boca chapter badge ───────────────────────────────────────────────────

class _TocaChapterBadge extends StatelessWidget {
  const _TocaChapterBadge({required this.chapter});
  final int chapter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      decoration: BoxDecoration(
        color: _kBlue,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _kInk, width: 3),
        boxShadow: const [
          BoxShadow(color: _kInk, blurRadius: 0, offset: Offset(3, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_stories_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            l10n.chapter(chapter),
            style: const TextStyle(fontFamily: 'Boogaloo',
              color: Colors.white,
              fontSize: 20,
              height: 1.0,
            ),
          ),
        ],
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

// ── Personal best banner ──────────────────────────────────────────────────────

class _PersonalBestBanner extends StatefulWidget {
  const _PersonalBestBanner({required this.elapsedMs});
  final int elapsedMs;

  @override
  State<_PersonalBestBanner> createState() => _PersonalBestBannerState();
}

class _PersonalBestBannerState extends State<_PersonalBestBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _formatTime(int ms) {
    final seconds = (ms / 1000).toStringAsFixed(1);
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    const kInk = Color(0xFF1A1A2E);
    const kYellow = Color(0xFFF5C800);
    const kRed = Color(0xFFE82D2D);

    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: kYellow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kInk, width: 3),
            boxShadow: const [
              BoxShadow(color: kInk, blurRadius: 0, offset: Offset(4, 4)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'NEW RECORD!',
                    style: TextStyle(
                      fontFamily: 'Boogaloo',
                      fontSize: 22,
                      color: kInk,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: kRed, offset: Offset(2, 2), blurRadius: 0),
                      ],
                    ),
                  ),
                  Text(
                    _formatTime(widget.elapsedMs),
                    style: const TextStyle(
                      fontFamily: 'Boogaloo',
                      fontSize: 16,
                      color: kInk,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
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
          style: const TextStyle(fontFamily: 'Fredoka',
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
