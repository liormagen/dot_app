import 'dart:async';

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
const _kPaper    = Color(0xFFFFF8E7);
const _kDisabled = Color(0xFF9CA3AF);

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
  bool _animating = false;
  StreamSubscription<void>? _audioSub;
  Timer? _fallbackTimer;

  bool get _isLastChunk => _chunks.isEmpty || _chunkIndex >= _chunks.length - 1;
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
    if (!mounted || _audioFinished) return;
    _audioSub?.cancel();
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
    if (_animating) return;
    _animating = true;
    HapticFeedback.lightImpact();
    await _pageCtrl.animateTo(0.0,
        duration: const Duration(milliseconds: 180), curve: Curves.easeIn);
    setState(() => _chunkIndex++);
    await _pageCtrl.animateTo(1.0,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    _animating = false;
  }

  Future<void> _onPrev() async {
    if (_chunkIndex == 0 || _animating) return;
    _animating = true;
    HapticFeedback.lightImpact();
    await _pageCtrl.animateTo(0.0,
        duration: const Duration(milliseconds: 180), curve: Curves.easeIn);
    setState(() => _chunkIndex--);
    await _pageCtrl.animateTo(1.0,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    _animating = false;
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
      backgroundColor: _kPaper,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _kBlue))
          : SafeArea(
              child: _buildLayout(),
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
                    color: _kInk.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _kInk.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: const Icon(Icons.home_rounded,
                      color: _kInk, size: 22),
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
                  color: _kYellow.withValues(alpha: 0.4),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
                BoxShadow(
                  color: _kBlue.withValues(alpha: 0.2),
                  blurRadius: 20,
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
            ),
        ],
      ),
    );
  }

  Widget _buildStoryCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: _kInk, width: 3),
        boxShadow: const [
          BoxShadow(
            color: _kInk,
            blurRadius: 0,
            offset: Offset(6, 6),
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
                color: _kBlue,
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_stories_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.chapter(widget.chapterIndex + 1),
                    style: const TextStyle(
                      fontFamily: 'Boogaloo',
                      color: Colors.white,
                      fontSize: 22,
                      height: 1.0,
                    ),
                  ),
                  const Spacer(),
                  if (_chunks.length > 1)
                    Text(
                      '${_chunkIndex + 1} / ${_chunks.length}',
                      style: TextStyle(
                        fontFamily: 'Boogaloo',
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 18,
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
                  style: const TextStyle(
                    fontFamily: 'Boogaloo',
                    fontSize: 30,
                    height: 1.5,
                    color: _kInk,
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
          _HandmadeButton(
            label: AppLocalizations.of(context)!.backButton,
            color: _kBlue,
            onTap: _onPrev,
          ),
          const SizedBox(width: 16),
        ],
        if (_isLastChunk)
          _HandmadeButton(
            label: AppLocalizations.of(context)!.letsDraw,
            color: _canContinue ? _kRed : _kDisabled,
            onTap: _canContinue ? _onContinue : null,
            wide: true,
          )
        else
          _HandmadeButton(
            label: AppLocalizations.of(context)!.nextButton,
            color: _kRed,
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
            color: active ? _kBlue : const Color(0xFFCCCCCC),
            borderRadius: BorderRadius.circular(4),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: _kBlue.withValues(alpha: 0.5),
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

// ── Handmade nav button ──────────────────────────────────────────────────────

class _HandmadeButton extends StatefulWidget {
  const _HandmadeButton({
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
  State<_HandmadeButton> createState() => _HandmadeButtonState();
}

class _HandmadeButtonState extends State<_HandmadeButton> {
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
          border: Border.all(color: _kInk, width: 3),
          boxShadow: _pressed || !enabled
              ? []
              : const [
                  BoxShadow(
                    color: _kInk,
                    blurRadius: 0,
                    offset: Offset(4, 4),
                  ),
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
        ),
      ),
    );
  }
}
