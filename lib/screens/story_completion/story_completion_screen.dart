import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../services/asset_service.dart';
import '../../services/audio_service.dart';
import '../../services/progress_service.dart';

// Toca Boca / Handmade tokens
const _kRed    = Color(0xFFE82D2D);
const _kYellow = Color(0xFFF5C800);
const _kGreen  = Color(0xFF2DB84B);
const _kBlue   = Color(0xFF1FA3E8);
const _kInk    = Color(0xFF1A1A2E);
const _kPaper  = Color(0xFFFFF8E7);

class _ChapterEntry {
  const _ChapterEntry({
    required this.chapterNumber,
    required this.narrationText,
    required this.image,
  });
  final int chapterNumber;
  final String narrationText;
  final ui.Image? image;
}

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
  List<_ChapterEntry> _entries = [];
  bool _loading = true;

  // Narration sequencing
  int _activeIndex = -1;
  bool _narrationPlaying = false;
  StreamSubscription<void>? _narrationSub;
  Timer? _fallbackTimer;

  final ScrollController _scrollController = ScrollController();
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
    _stopNarration();
    _celebCtrl.dispose();
    _scrollController.dispose();
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

      final entries = <_ChapterEntry>[];
      for (int i = 0; i < drawings.length; i++) {
        final img = await _loadUiImage(drawings[i].imageColored);
        final chapter = i < story.chapters.length ? story.chapters[i] : null;
        entries.add(_ChapterEntry(
          chapterNumber: chapter?.chapter ?? (i + 1),
          narrationText: chapter?.getNarration(lang) ?? '',
          image: img,
        ));
      }

      if (!mounted) return;
      setState(() {
        _storyTitle = story.getTitle(lang);
        _entries = entries;
        _loading = false;
      });

      // Start sequential narration from chapter 1
      _playChapterAt(0);
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

  void _playChapterAt(int index) {
    if (!mounted || index >= _entries.length) return;

    _narrationSub?.cancel();
    _fallbackTimer?.cancel();

    final entry = _entries[index];
    final lang = ref.read(progressProvider).selectedLanguage;

    setState(() {
      _activeIndex = index;
      _narrationPlaying = true;
    });

    // Auto-scroll to this chapter card (~520px per card including margin)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        index * 520.0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });

    ref.read(audioServiceProvider).playChapterNarration(
        lang, widget.storyId, entry.chapterNumber);

    void advance() {
      if (!mounted) return;
      _narrationSub?.cancel();
      _fallbackTimer?.cancel();
      _narrationSub = null;
      _fallbackTimer = null;
      setState(() => _narrationPlaying = false);
      // Brief pause between chapters before auto-advancing
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _playChapterAt(index + 1);
      });
    }

    _narrationSub = ref
        .read(audioServiceProvider)
        .voiceoverPlayer
        .onPlayerComplete
        .listen((_) => advance());
    // Fallback: if audio file is missing, advance after 4 seconds
    _fallbackTimer = Timer(const Duration(seconds: 4), advance);
  }

  void _stopNarration() {
    _narrationSub?.cancel();
    _narrationSub = null;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    try {
      ref.read(audioServiceProvider).voiceoverPlayer.stop();
    } catch (_) {}
    if (mounted) setState(() => _narrationPlaying = false);
  }

  void _readAgain() {
    HapticFeedback.lightImpact();
    _stopNarration();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) _playChapterAt(0);
    });
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
            // Background confetti
            AnimatedBuilder(
              animation: _celebCtrl,
              builder: (_, __) => CustomPaint(
                painter: _ConfettiPainter(progress: _celebCtrl.value),
              ),
            ),
            Column(
              children: [
                _buildHeader(l10n),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                    itemCount: _entries.length,
                    itemBuilder: (context, i) => _buildChapterCard(i, l10n),
                  ),
                ),
                _buildFooter(l10n),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Back button — left
          Align(
            alignment: Alignment.centerLeft,
            child: _StoryBookButton(
              label: l10n.backToStories,
              color: _kBlue,
              onTap: () {
                _stopNarration();
                context.go('/stories');
              },
            ),
          ),
          // Title — centered
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 28)),
              Text(
                l10n.storyComplete,
                style: const TextStyle(
                  fontFamily: 'Boogaloo',
                  fontSize: 28,
                  color: _kInk,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChapterCard(int i, AppLocalizations l10n) {
    final entry = _entries[i];
    final isActive = i == _activeIndex;
    final img = entry.image;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? _kYellow : _kInk,
          width: isActive ? 5 : 3,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive ? _kYellow : _kInk,
            blurRadius: 0,
            offset: const Offset(5, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Chapter header bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: isActive ? _kYellow : _kBlue,
              child: Row(
                children: [
                  const Icon(Icons.auto_stories_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    l10n.chapter(entry.chapterNumber),
                    style: TextStyle(
                      fontFamily: 'Boogaloo',
                      color: isActive ? _kInk : Colors.white,
                      fontSize: 20,
                      height: 1.0,
                    ),
                  ),
                  const Spacer(),
                  if (isActive && _narrationPlaying) const _PulsingVolumeIcon(),
                ],
              ),
            ),
            // Illustration
            if (img != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: RawImage(
                    image: img,
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
                ),
              )
            else
              Container(
                height: 180,
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                decoration: BoxDecoration(
                  color: _kPaper,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kInk, width: 2),
                ),
              ),
            // Narration text
            if (entry.narrationText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Text(
                  entry.narrationText,
                  style: const TextStyle(
                    fontFamily: 'Boogaloo',
                    fontSize: 20,
                    height: 1.6,
                    color: _kInk,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: _StoryBookButton(
        label: l10n.readAgain,
        color: _kGreen,
        onTap: _readAgain,
        fullWidth: true,
      ),
    );
  }
}

// ── Pulsing volume icon shown next to active chapter ─────────────────────────

class _PulsingVolumeIcon extends StatefulWidget {
  const _PulsingVolumeIcon();

  @override
  State<_PulsingVolumeIcon> createState() => _PulsingVolumeIconState();
}

class _PulsingVolumeIconState extends State<_PulsingVolumeIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Opacity(
        opacity: 0.4 + 0.6 * _pulse.value,
        child: const Icon(Icons.volume_up_rounded,
            color: _kInk, size: 20),
      ),
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

class _StoryBookButton extends StatefulWidget {
  const _StoryBookButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.fullWidth = false,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool fullWidth;

  @override
  State<_StoryBookButton> createState() => _StoryBookButtonState();
}

class _StoryBookButtonState extends State<_StoryBookButton> {
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
        width: widget.fullWidth ? double.infinity : null,
        transform: _pressed
            ? Matrix4.translationValues(0, 4, 0)
            : Matrix4.identity(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
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
