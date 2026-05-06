import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../services/asset_service.dart';
import '../../services/audio_service.dart';
import '../../services/progress_service.dart';

// Stardust Claymorphism tokens
const _kPrimary = Color(0xFF6C48FF);
const _kCoral = Color(0xFFFF6B6B);
const _kGold = Color(0xFFFFD93D);
const _kNight = Color(0xFF1A0E3F);
const _kCard = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFD4C8FF);
const _kForeground = Color(0xFF1A0A3F);

class TransitionScreen extends ConsumerStatefulWidget {
  const TransitionScreen({
    super.key,
    required this.storyId,
    required this.chapterIndex,
  });

  final String storyId;
  final int chapterIndex;

  @override
  ConsumerState<TransitionScreen> createState() => _TransitionScreenState();
}

class _TransitionScreenState extends ConsumerState<TransitionScreen>
    with TickerProviderStateMixin {
  String? _companionAsset;
  String? _nextDrawingId;
  bool _loading = true;

  List<String> _chunks = [];
  int _chunkIndex = 0;

  late AnimationController _companionCtrl;
  late Animation<double> _companionScale;

  late AnimationController _pageCtrl;
  late Animation<double> _pageFade;

  bool _audioFinished = false;
  StreamSubscription<void>? _audioSub;
  Timer? _fallbackTimer;

  bool get _isLastChunk => _chunkIndex >= _chunks.length - 1;
  bool get _canContinue => _isLastChunk && _audioFinished;

  @override
  void initState() {
    super.initState();

    _companionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _companionScale = CurvedAnimation(
      parent: _companionCtrl,
      curve: Curves.elasticOut,
    );

    _pageCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
    _pageFade = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeInOut);

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
      final chapterIdx =
          widget.chapterIndex.clamp(0, story.chapters.length - 1);
      final chapter = story.chapters[chapterIdx];
      final narration = chapter.getNarration(lang);

      final nextIdx = widget.chapterIndex + 1;
      final nextId = nextIdx < story.drawingIds.length
          ? story.drawingIds[nextIdx]
          : null;

      if (!mounted) return;
      setState(() {
        _companionAsset = story.companionAsset;
        _nextDrawingId = nextId;
        _chunks = _splitIntoChunks(narration);
        _loading = false;
      });

      final audio = ref.read(audioServiceProvider);
      await audio.playChapterNarration(lang, story.id, chapter.chapter);
      _audioSub = audio.voiceoverPlayer.onPlayerComplete.listen((_) {
        _markAudioDone();
      });
      _fallbackTimer = Timer(const Duration(seconds: 4), _markAudioDone);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      _fallbackTimer = Timer(const Duration(seconds: 1), _markAudioDone);
    }
  }

  void _markAudioDone() {
    if (!mounted) return;
    _fallbackTimer?.cancel();
    setState(() => _audioFinished = true);
  }

  List<String> _splitIntoChunks(String text) {
    if (text.trim().isEmpty) return [''];
    final sentences = text.trim().split(RegExp(r'(?<=[.!?])\s+'));
    final chunks = <String>[];
    var current = '';
    for (final sentence in sentences) {
      final candidate = current.isEmpty ? sentence : '$current $sentence';
      if (candidate.length <= 220) {
        current = candidate;
      } else {
        if (current.isNotEmpty) chunks.add(current.trim());
        current = sentence;
      }
    }
    if (current.isNotEmpty) chunks.add(current.trim());
    return chunks.isEmpty ? [text.trim()] : chunks;
  }

  Future<void> _onNext() async {
    if (_isLastChunk) {
      _onContinue();
      return;
    }
    HapticFeedback.lightImpact();
    await _pageCtrl.animateTo(0.0,
        duration: const Duration(milliseconds: 180), curve: Curves.easeIn);
    setState(() => _chunkIndex++);
    await _pageCtrl.animateTo(1.0,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _onPrev() async {
    if (_chunkIndex == 0) return;
    HapticFeedback.lightImpact();
    await _pageCtrl.animateTo(0.0,
        duration: const Duration(milliseconds: 180), curve: Curves.easeIn);
    setState(() => _chunkIndex--);
    await _pageCtrl.animateTo(1.0,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _onContinue() {
    final nextId = _nextDrawingId;
    if (nextId == null) {
      context.go('/stories');
    } else {
      context.go('/drawing/$nextId');
    }
  }

  @override
  void dispose() {
    _companionCtrl.dispose();
    _pageCtrl.dispose();
    _audioSub?.cancel();
    _fallbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kNight,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF9C6FFF)))
          : SafeArea(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const _TwinklingStars(),
                  _buildLayout(),
                ],
              ),
            ),
    );
  }

  Widget _buildLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Big companion zone
                SizedBox(height: h * 0.40, child: _buildCompanion()),
                // Story card + nav row — centered in remaining space
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStoryCard(),
                        const SizedBox(height: 20),
                        _buildNavRow(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Back-to-stories button (top-right)
            Positioned(
              top: 12,
              right: 16,
              child: GestureDetector(
                onTap: () => context.go('/stories'),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(Icons.home_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompanion() {
    final asset = _companionAsset;
    return ScaleTransition(
      scale: _companionScale,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Atmospheric glow behind companion
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _kPrimary.withValues(alpha: 0.5),
                  blurRadius: 50,
                  spreadRadius: 12,
                ),
                BoxShadow(
                  color: _kGold.withValues(alpha: 0.2),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          if (asset != null)
            Opacity(
              opacity: widget.chapterIndex == 0 ? 0.82 : 1.0,
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.auto_stories_rounded,
                  size: 80,
                  color: Colors.white54,
                ),
              ),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildStoryCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: _kBorder, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF3B1FCC),
            blurRadius: 0,
            offset: Offset(6, 6),
          ),
          BoxShadow(
            color: Color(0x556C48FF),
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(29),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gradient chapter header
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6C48FF), Color(0xFF9C6FFF)],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_stories_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.chapter(widget.chapterIndex + 1),
                    style: GoogleFonts.fredoka(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (_chunks.length > 1)
                    Text(
                      '${_chunkIndex + 1} / ${_chunks.length}',
                      style: GoogleFonts.nunito(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),

            // Story text — sized to content
            FadeTransition(
              opacity: _pageFade,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
                child: Text(
                  _chunks.isNotEmpty ? _chunks[_chunkIndex] : '',
                  style: GoogleFonts.nunito(
                    fontSize: 30,
                    height: 1.6,
                    color: _kForeground,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            // Page dot indicators
            if (_chunks.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _PageDots(
                  total: _chunks.length,
                  current: _chunkIndex,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_chunkIndex > 0) ...[
          _StardustButton(
            label: AppLocalizations.of(context)!.backButton,
            color: const Color(0xFF6366F1),
            onTap: _onPrev,
          ),
          const SizedBox(width: 16),
        ],
        if (_isLastChunk)
          _StardustButton(
            label: AppLocalizations.of(context)!.letsDraw,
            color: _canContinue ? _kCoral : const Color(0xFF9CA3AF),
            onTap: _canContinue ? _onContinue : null,
            wide: true,
          )
        else
          _StardustButton(
            label: AppLocalizations.of(context)!.nextButton,
            color: _kCoral,
            onTap: _onNext,
            wide: true,
          ),
      ],
    );
  }
}

// ── Page dots ────────────────────────────────────────────────────────────────

class _PageDots extends StatelessWidget {
  const _PageDots({required this.total, required this.current});

  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: active ? 22 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: active ? _kPrimary : _kBorder,
            borderRadius: BorderRadius.circular(4),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: _kPrimary.withValues(alpha: 0.55),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

// ── Stardust nav button ───────────────────────────────────────────────────────

class _StardustButton extends StatefulWidget {
  const _StardustButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.wide = false,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool wide;

  @override
  State<_StardustButton> createState() => _StardustButtonState();
}

class _StardustButtonState extends State<_StardustButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: (_pressed || !enabled)
            ? Matrix4.translationValues(0, 5, 0)
            : Matrix4.identity(),
        padding: EdgeInsets.symmetric(
          horizontal: widget.wide ? 44 : 28,
          vertical: 18,
        ),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: _pressed || !enabled
              ? []
              : [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.75),
                    blurRadius: 0,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
        ),
        child: Text(
          widget.label,
          style: GoogleFonts.fredoka(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Twinkling star background ────────────────────────────────────────────────

class _TwinklingStars extends StatefulWidget {
  const _TwinklingStars();

  @override
  State<_TwinklingStars> createState() => _TwinklingStarsState();
}

class _TwinklingStarsState extends State<_TwinklingStars>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _StarPainter(twinkle: _ctrl.value),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  const _StarPainter({required this.twinkle});
  final double twinkle;

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(42);
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 90; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final baseR = 0.7 + rand.nextDouble() * 2.2;
      final phase = rand.nextDouble() * math.pi * 2;
      final t = 0.4 + 0.6 * math.sin(twinkle * math.pi * 2 + phase);
      final opacity = (0.2 + rand.nextDouble() * 0.6) * t;
      final warmth = rand.nextDouble();
      paint.color = warmth > 0.7
          ? Color.lerp(Colors.white, const Color(0xFFFFD93D), 0.4)!
              .withValues(alpha: opacity)
          : Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), baseR, paint);
    }

    // Large sparkle stars (gold cross-shape via 4 overlapping circles)
    final sparkPaint = Paint()..style = PaintingStyle.fill;
    final rand2 = math.Random(99);
    for (int i = 0; i < 14; i++) {
      final x = rand2.nextDouble() * size.width;
      final y = rand2.nextDouble() * size.height;
      final phase = rand2.nextDouble() * math.pi * 2;
      final t = 0.3 + 0.7 * math.sin(twinkle * math.pi * 2 + phase);
      sparkPaint.color =
          const Color(0xFFFFD93D).withValues(alpha: t * 0.65);
      canvas.drawCircle(Offset(x, y), 2.8, sparkPaint);
      // Tiny cross arms
      sparkPaint.color =
          const Color(0xFFFFD93D).withValues(alpha: t * 0.35);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 12, height: 2.5),
          sparkPaint);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 2.5, height: 12),
          sparkPaint);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.twinkle != twinkle;
}
