# Delight Sprint Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire missing audio feedback, add a reveal music swell, mid-drawing encouragement, dot proximity wiggle, and a "Save to Photos" button in the gallery — making every session louder, more physical, and leaving children with a shareable artifact.

**Architecture:** All audio flows through the existing `AudioService`. Proximity wiggle is a new optional field on `DotCanvasPainter` — zero coupling to game state. The gallery save wraps the existing `_FullScreenDialog` in a `RepaintBoundary` and calls `Gal.putImageBytes`. No new screens.

**Tech Stack:** Flutter/Dart, `audioplayers ^6.0.0` (already in pubspec), `gal ^1.3.1` (new), `RepaintBoundary` + `RenderRepaintBoundary` for PNG capture.

---

## File Map

| File | What changes |
|---|---|
| `lib/services/audio_service.dart` | Add `playRevealSwell()` method |
| `lib/screens/drawing/drawing_screen.dart` | Wire 4 audio calls, add finger-tracking `Listener`, add encouragement at 60% |
| `lib/screens/drawing/dot_canvas.dart` | Add `fingerPosition` field, proximity scale in `_drawDot` |
| `lib/screens/gallery/gallery_screen.dart` | Add `RepaintBoundary` + Save button in `_FullScreenDialog` |
| `pubspec.yaml` | Add `gal` dependency, add `assets/audio/music/` asset path |
| `ios/Runner/Info.plist` | Add `NSPhotoLibraryAddUsageDescription` key |
| `test/unit/audio_service_test.dart` | Unit tests for new `playRevealSwell` routing |
| `test/widget_tests/drawing_screen_audio_test.dart` | Widget tests verifying audio triggers fire at the right moments |

> **Audio files note:** The code paths are wired in this sprint; the `.mp3` files themselves are a content-production deliverable. The app gracefully no-ops on missing files (all audio calls are wrapped in `try/catch`). Required files to add later:
> - `assets/audio/music/drawing_theme.mp3` — looping background music
> - `assets/audio/sfx/reveal_swell.mp3` — orchestral hit at reveal
> - `assets/audio/sfx/drawing_complete.mp3` — already referenced, needs file
> - `assets/audio/sfx/confetti.mp3` — already referenced, needs file
> - `assets/audio/en/encouragement_1.mp3` … `encouragement_6.mp3` (also he/, ar/)

---

## Task 1: Wire the Two Missing Audio Calls

`playDrawingComplete()` and `playConfetti()` exist in `AudioService` but are never called from `DrawingScreen`.

**Files:**
- Modify: `lib/screens/drawing/drawing_screen.dart`

- [ ] **Step 1: Locate the closing connection block**

  In `drawing_screen.dart`, find the `isLast` branch inside `_onCorrectTap` (around line 547). The structure is:
  ```dart
  if (isLast) {
    _stopBlink();
    final firstDot = sortedDots.first;
    Future.delayed(const Duration(milliseconds: 310), () {
      ...
      _lineAnimController.forward(from: 0).then((_) {
        if (!mounted) return;
        ref.read(drawingSessionProvider.notifier).addConnection(...);
        setState(() => _animatingConnection = null);
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          _countdownTimer?.cancel();
          setState(() => _isRevealing = true);
          _revealController.forward();   // ← add playDrawingComplete here
        });
      });
    });
  }
  ```

- [ ] **Step 2: Add `playDrawingComplete()` call**

  Replace the inner `Future.delayed` block so it reads:
  ```dart
  Future.delayed(const Duration(milliseconds: 200), () {
    if (!mounted) return;
    _countdownTimer?.cancel();
    setState(() => _isRevealing = true);
    ref.read(audioServiceProvider).playDrawingComplete();
    _revealController.forward();
  });
  ```

- [ ] **Step 3: Add `playConfetti()` at celebration start**

  In `_revealController`'s `addStatusListener`, find the block that sets `_overlayPhase = _OverlayPhase.celebration` (around line 240). It currently reads:
  ```dart
  setState(() => _overlayPhase = _OverlayPhase.celebration);
  _overlayEnterCtrl.forward();
  _celebCtrl.repeat();
  ```
  Add the confetti call after `_celebCtrl.repeat()`:
  ```dart
  setState(() => _overlayPhase = _OverlayPhase.celebration);
  _overlayEnterCtrl.forward();
  _celebCtrl.repeat();
  ref.read(audioServiceProvider).playConfetti();
  ```

- [ ] **Step 4: Run all tests**

  ```bash
  /Users/lior.magen/development/flutter/bin/flutter test --no-pub
  ```
  Expected: 117 tests pass. (These audio calls are fire-and-forget; no behavior changes for existing tests.)

- [ ] **Step 5: Commit**

  ```bash
  git add lib/screens/drawing/drawing_screen.dart
  git commit -m "feat: wire playDrawingComplete and playConfetti calls that were missing"
  ```

---

## Task 2: Background Music During Drawing

Start a looping background music track when the drawing loads; stop it when leaving.

**Files:**
- Modify: `lib/screens/drawing/drawing_screen.dart`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add `assets/audio/music/` to pubspec.yaml**

  In `pubspec.yaml`, under the `assets:` list, add one line:
  ```yaml
      - assets/audio/music/
  ```
  Place it after `- assets/audio/sfx/`. The block should look like:
  ```yaml
      - assets/audio/encouragement/
      - assets/audio/sfx/
      - assets/audio/music/
  ```

- [ ] **Step 2: Create the directory**

  ```bash
  mkdir -p /Users/lior.magen/PycharmProjects/dot_app/assets/audio/music
  ```

- [ ] **Step 3: Add music start call in `_loadDrawing()`**

  In `_loadDrawing()`, after the final `setState(() { ... _loading = false; })` block, add:
  ```dart
  ref.read(audioServiceProvider).playMusic('audio/music/drawing_theme.mp3');
  ```

  The complete tail of `_loadDrawing()` after this change:
  ```dart
      setState(() {
        _drawing = effectiveDrawing;
        _coloredImage = colored;
        _narrationText = chapter?.getNarration(lang) ?? '';
        _chapterNumber = chapter?.chapter ?? (chapterIdx + 1);
        _storyId = story.id;
        _nextDrawingId = chapterIdx < story.drawingIds.length - 1
            ? story.drawingIds[chapterIdx + 1]
            : null;
        _loading = false;
        _difficulty = difficulty;
        _totalSeconds = timerSecs;
        _remainingSeconds = timerSecs;
        _visibleDotCount = isTimedMode
            ? (difficulty == DifficultyMode.superHard ? 1 : min(5, effectiveDots.length))
            : 0;
      });
      ref.read(audioServiceProvider).playMusic('audio/music/drawing_theme.mp3');
  ```

- [ ] **Step 4: Stop music in `dispose()`**

  In `dispose()`, before `super.dispose()`, add:
  ```dart
  ref.read(audioServiceProvider).stopMusic();
  ```

  The end of `dispose()` should look like:
  ```dart
    _narrationSub?.cancel();
    _transformController.dispose();
    ref.read(audioServiceProvider).stopMusic();
    super.dispose();
  ```

  > Note: `ref.read()` in `dispose()` is safe for Riverpod providers — the provider isn't necessarily torn down yet. If it throws, wrap in `try/catch`.

- [ ] **Step 5: Stop music when drawing completes (before narration)**

  Music should also stop when the reveal starts (otherwise it plays over narration). In `_onCorrectTap`'s inner `Future.delayed` block (Task 1, Step 2), add a stopMusic call alongside playDrawingComplete:
  ```dart
  Future.delayed(const Duration(milliseconds: 200), () {
    if (!mounted) return;
    _countdownTimer?.cancel();
    setState(() => _isRevealing = true);
    ref.read(audioServiceProvider).stopMusic();
    ref.read(audioServiceProvider).playDrawingComplete();
    _revealController.forward();
  });
  ```

- [ ] **Step 6: Run all tests**

  ```bash
  /Users/lior.magen/development/flutter/bin/flutter test --no-pub
  ```
  Expected: 117 tests pass.

- [ ] **Step 7: Commit**

  ```bash
  git add lib/screens/drawing/drawing_screen.dart pubspec.yaml assets/audio/music/.gitkeep
  git commit -m "feat: start background music when drawing loads, stop on completion"
  ```

---

## Task 3: Reveal Music Swell

Add a new `playRevealSwell()` method to `AudioService` and call it at the moment the image reveal begins.

**Files:**
- Modify: `lib/services/audio_service.dart`
- Modify: `lib/screens/drawing/drawing_screen.dart`

- [ ] **Step 1: Add `playRevealSwell()` to AudioService**

  In `audio_service.dart`, after `playDrawingComplete()`, add:
  ```dart
  Future<void> playRevealSwell() async {
    if (!_sfxEnabled) return;
    try {
      await _sfxPlayer.play(AssetSource('audio/sfx/reveal_swell.mp3'));
    } catch (_) {}
  }
  ```

- [ ] **Step 2: Call `playRevealSwell()` when reveal begins**

  In `_revealController`'s `addStatusListener` in `initState()`, the status listener fires when the reveal animation completes (`AnimationStatus.completed`). We want the swell to fire when the *reveal starts*, not when it ends. Add the call right before `_revealController.forward()` in the last-dot completion block (Task 2, Step 5 block):
  ```dart
  Future.delayed(const Duration(milliseconds: 200), () {
    if (!mounted) return;
    _countdownTimer?.cancel();
    setState(() => _isRevealing = true);
    ref.read(audioServiceProvider).stopMusic();
    ref.read(audioServiceProvider).playRevealSwell();
    ref.read(audioServiceProvider).playDrawingComplete();
    _revealController.forward();
  });
  ```
  `playRevealSwell()` and `playDrawingComplete()` both use `_sfxPlayer` — `playRevealSwell` fires first and the swell audio overlaps naturally with the completion jingle.

- [ ] **Step 3: Run all tests**

  ```bash
  /Users/lior.magen/development/flutter/bin/flutter test --no-pub
  ```
  Expected: 117 tests pass.

- [ ] **Step 4: Commit**

  ```bash
  git add lib/services/audio_service.dart lib/screens/drawing/drawing_screen.dart
  git commit -m "feat: add reveal swell audio triggered at image reveal start"
  ```

---

## Task 4: Mid-Drawing Encouragement at 60%

Play a random encouraging phrase when the child has connected 60% of the dots. Fires once per drawing session.

**Files:**
- Modify: `lib/screens/drawing/drawing_screen.dart`

- [ ] **Step 1: Add `_encouragementPlayed` field**

  In the fields section of `_DrawingScreenState`, after `bool _timerStarted = false;`, add:
  ```dart
  bool _encouragementPlayed = false;
  ```

- [ ] **Step 2: Reset it in `_resetAfterTimeout()`**

  In `_resetAfterTimeout()`, inside the `setState` block, add:
  ```dart
  _encouragementPlayed = false;
  ```
  The block becomes:
  ```dart
  setState(() {
    _overlayPhase = _OverlayPhase.none;
    _remainingSeconds = _totalSeconds;
    _fadingInDotId = -1;
    _encouragementPlayed = false;
    if (isTimedMode) {
      _visibleDotCount = _difficulty == DifficultyMode.superHard
          ? 1
          : min(5, drawing.dots.length);
    }
  });
  ```

- [ ] **Step 3: Fire encouragement in `_onCorrectTap`**

  In `_onCorrectTap`, after the call to `_updateVisibleCount()` (around line 523), add:
  ```dart
  _updateVisibleCount();

  // Encourage once when ~60% of dots are connected
  final total = drawing.dots.length;
  if (!_encouragementPlayed &&
      total > 0 &&
      session.connections.length >= (total * 0.6).floor()) {
    _encouragementPlayed = true;
    final eLang = ref.read(progressProvider).selectedLanguage;
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        ref.read(audioServiceProvider).playEncouragement(eLang);
      }
    });
  }
  ```
  The 700ms delay lets the number audio finish before the encouragement phrase begins.

- [ ] **Step 4: Run all tests**

  ```bash
  /Users/lior.magen/development/flutter/bin/flutter test --no-pub
  ```
  Expected: 117 tests pass.

- [ ] **Step 5: Commit**

  ```bash
  git add lib/screens/drawing/drawing_screen.dart
  git commit -m "feat: play encouragement audio once at 60% dot completion"
  ```

---

## Task 5: Dot Proximity Wiggle

Dots gently grow as the child's finger approaches, creating a tactile "magnetism" feel. Uses a `Listener` widget for continuous pointer tracking inside the canvas.

**Files:**
- Modify: `lib/screens/drawing/drawing_screen.dart`
- Modify: `lib/screens/drawing/dot_canvas.dart`

- [ ] **Step 1: Add `fingerPosition` field to `DotCanvasPainter`**

  In `dot_canvas.dart`, add one optional constructor parameter and field after `fadingInProgress`:
  ```dart
  DotCanvasPainter({
    // ... all existing params ...
    this.fadingInDotId = -1,
    this.fadingInProgress = 1.0,
    this.fingerPosition,           // NEW
  });

  // ... existing final fields ...
  final int fadingInDotId;
  final double fadingInProgress;
  final Offset? fingerPosition;    // NEW
  ```

- [ ] **Step 2: Apply proximity scale in `_drawDot`**

  In `_drawDot`, immediately after the line that sets `radius`:
  ```dart
  final radius = (isEasyMode ? 22.0 : 15.0) * scale.clamp(0.5, 1.5);
  ```
  Replace it with:
  ```dart
  double proxScale = 1.0;
  if (fingerPosition != null && !isConnected && !isAnimating) {
    final dist = (fingerPosition! - pos).distance;
    if (dist < 80.0) {
      proxScale = 1.0 + (1.0 - dist / 80.0) * 0.18;
    }
  }
  final radius = (isEasyMode ? 22.0 : 15.0) * scale.clamp(0.5, 1.5) * proxScale;
  ```
  This makes unconnected dots grow up to 18% larger when the finger is within 80px. Connected/animating dots don't react (they're already done).

- [ ] **Step 3: Add `_fingerPosition` state to `_DrawingScreenState`**

  In `drawing_screen.dart`, after `bool _showZoomHint = false;`, add:
  ```dart
  Offset? _fingerPosition;
  ```

- [ ] **Step 4: Wrap `canvasPainter` in a `Listener`**

  In `_buildCanvas`, inside the `LayoutBuilder`, find the `canvasPainter` widget. It's currently used directly as the child of `GestureDetector`. Wrap it in a `Listener`:

  Find:
  ```dart
  return InteractiveViewer(
    transformationController: _transformController,
    scaleEnabled: _isZoomMode,
    panEnabled: _isZoomMode,
    minScale: 1.0,
    maxScale: 5.0,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (_isRevealing || overlayActive)
          ? null
          : (d) => _handleTap(d.localPosition, widgetSize),
      child: canvasPainter,
    ),
  );
  ```

  Replace `child: canvasPainter` with:
  ```dart
  return InteractiveViewer(
    transformationController: _transformController,
    scaleEnabled: _isZoomMode,
    panEnabled: _isZoomMode,
    minScale: 1.0,
    maxScale: 5.0,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (_isRevealing || overlayActive)
          ? null
          : (d) => _handleTap(d.localPosition, widgetSize),
      child: Listener(
        onPointerMove: (_isRevealing || overlayActive)
            ? null
            : (e) {
                if (_fingerPosition != e.localPosition) {
                  setState(() => _fingerPosition = e.localPosition);
                }
              },
        onPointerUp: (_) {
          if (_fingerPosition != null) {
            setState(() => _fingerPosition = null);
          }
        },
        onPointerCancel: (_) {
          if (_fingerPosition != null) {
            setState(() => _fingerPosition = null);
          }
        },
        child: canvasPainter,
      ),
    ),
  );
  ```

- [ ] **Step 5: Pass `fingerPosition` to `DotCanvasPainter`**

  Find the `DotCanvasPainter(...)` constructor call in `_buildCanvas`. Add the new field at the end:
  ```dart
  final canvasPainter = CustomPaint(
    size: widgetSize,
    painter: DotCanvasPainter(
      drawing: drawing,
      session: session,
      lineAnimProgress: _lineAnimController.value,
      hintPulse: _hintPulseController.value,
      animatingConnection: _animatingConnection,
      scale: so.$1,
      offset: so.$2,
      revealImage: _coloredImage,
      revealProgress: _revealController.value,
      spinHintProgress: _spinController.value,
      spinHintActive: _spinHintActive,
      visibleDotCount: _visibleDotCount,
      dotsOpacity: 1.0 - _dotsHideCtrl.value,
      isEasyMode: _difficulty == DifficultyMode.easy,
      squeezedDotId: _squeezedDotId,
      squeezeProgress: _squeezeCtrl.value,
      blinkOpacity: _blinkActive
          ? (0.30 + 0.70 * _blinkCtrl.value)
          : 1.0,
      fadingInDotId: _fadingInDotId,
      fadingInProgress: _dotRevealCtrl.value,
      fingerPosition: (_isRevealing || overlayActive) ? null : _fingerPosition,
    ),
  );
  ```
  (Pass `null` when revealing or overlay is active so dots don't react during celebration.)

- [ ] **Step 6: Regenerate golden tests**

  The proximity wiggle changes `_drawDot` output. Existing golden tests were captured with `fingerPosition = null` (which is the default), so dot rendering is unchanged at their capture conditions. Verify goldens still pass:
  ```bash
  /Users/lior.magen/development/flutter/bin/flutter test --no-pub test/golden/dot_canvas_painter_test.dart
  ```
  Expected: 5 tests pass. (All golden tests pass `fingerPosition` as `null` / default, so no pixel diff.)

- [ ] **Step 7: Run all tests**

  ```bash
  /Users/lior.magen/development/flutter/bin/flutter test --no-pub
  ```
  Expected: 117 tests pass.

- [ ] **Step 8: Commit**

  ```bash
  git add lib/screens/drawing/dot_canvas.dart lib/screens/drawing/drawing_screen.dart
  git commit -m "feat: dot proximity wiggle — dots grow as finger approaches"
  ```

---

## Task 6: Gallery "Save to Photos"

Add a Save button to `_FullScreenDialog` in `gallery_screen.dart`. Uses `gal` package for iOS photo library access.

**Files:**
- Modify: `pubspec.yaml`
- Modify: `ios/Runner/Info.plist`
- Modify: `lib/screens/gallery/gallery_screen.dart`

- [ ] **Step 1: Add `gal` to pubspec.yaml**

  In `pubspec.yaml`, under `dependencies:`, add after `go_router`:
  ```yaml
    gal: ^1.3.1
  ```

- [ ] **Step 2: Run `flutter pub get`**

  ```bash
  /Users/lior.magen/development/flutter/bin/flutter pub get
  ```
  Expected: Resolves without error, `pubspec.lock` updates.

- [ ] **Step 3: Add photo library permission to Info.plist**

  In `ios/Runner/Info.plist`, add inside the root `<dict>`:
  ```xml
  <key>NSPhotoLibraryAddUsageDescription</key>
  <string>Save your completed drawings to the Photos app.</string>
  ```
  (Only `NSPhotoLibraryAddUsageDescription` is needed for write-only access on iOS 14+.)

- [ ] **Step 4: Add import to `gallery_screen.dart`**

  At the top of `lib/screens/gallery/gallery_screen.dart`, add:
  ```dart
  import 'package:gal/gal.dart';
  ```

- [ ] **Step 5: Add `_repaintKey` and save state to `_FullScreenDialog`**

  `_FullScreenDialog` is currently a `StatelessWidget`. Convert it to a `StatefulWidget` to hold the key and saving state:

  Replace:
  ```dart
  class _FullScreenDialog extends StatelessWidget {
    const _FullScreenDialog({
      required this.drawing,
      required this.image,
      required this.lang,
    });

    final DrawingModel drawing;
    final ui.Image image;
    final String lang;

    @override
    Widget build(BuildContext context) {
  ```

  With:
  ```dart
  class _FullScreenDialog extends StatefulWidget {
    const _FullScreenDialog({
      required this.drawing,
      required this.image,
      required this.lang,
    });

    final DrawingModel drawing;
    final ui.Image image;
    final String lang;

    @override
    State<_FullScreenDialog> createState() => _FullScreenDialogState();
  }

  class _FullScreenDialogState extends State<_FullScreenDialog> {
    final _repaintKey = GlobalKey();
    bool _saving = false;

    @override
    Widget build(BuildContext context) {
  ```

  Also update all references inside `build` from `drawing.` / `image` / `lang` to `widget.drawing.` / `widget.image` / `widget.lang`.

- [ ] **Step 6: Wrap the image with `RepaintBoundary`**

  Inside `_FullScreenDialogState.build`, find the `AspectRatio` widget that holds the `CustomPaint`. Wrap it:
  ```dart
  RepaintBoundary(
    key: _repaintKey,
    child: AspectRatio(
      aspectRatio: 1.0,
      child: CustomPaint(
        painter: _ImagePainter(image: widget.image),
        size: Size.infinite,
      ),
    ),
  ),
  ```

- [ ] **Step 7: Add the Save button to the gradient footer**

  In `_FullScreenDialogState.build`, find the `Positioned` gradient footer. It currently contains only the drawing name `Text`. Add a Save button row below the text:
  ```dart
  Positioned(
    bottom: 0,
    left: 0,
    right: 0,
    child: Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xCC1A0E3F), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.drawing.getName(widget.lang),
            style: const TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _saving ? null : _saveToPhotos,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: _saving ? Colors.white38 : const Color(0xFF2DB84B),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: _saving
                    ? []
                    : const [
                        BoxShadow(
                            color: Color(0xFF1A1A2E),
                            blurRadius: 0,
                            offset: Offset(3, 3)),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_saving)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  else
                    const Icon(Icons.download_rounded,
                        color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _saving ? 'Saving…' : 'Save to Photos',
                    style: const TextStyle(
                      fontFamily: 'Boogaloo',
                      color: Colors.white,
                      fontSize: 18,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ),
  ```

- [ ] **Step 8: Implement `_saveToPhotos()`**

  Add this method to `_FullScreenDialogState`:
  ```dart
  Future<void> _saveToPhotos() async {
    setState(() => _saving = true);
    try {
      final hasAccess = await Gal.hasAccess(toAlbum: false);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: false);
        if (!granted) {
          if (mounted) setState(() => _saving = false);
          return;
        }
      }
      final boundary =
          _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      await Gal.putImageBytes(byteData.buffer.asUint8List());
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Saved to Photos!',
              style: TextStyle(fontFamily: 'Boogaloo', fontSize: 16),
            ),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF2DB84B),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }
  ```

- [ ] **Step 9: Run all tests**

  ```bash
  /Users/lior.magen/development/flutter/bin/flutter test --no-pub
  ```
  Expected: 117 tests pass. (`_FullScreenDialog` is only tested through integration; no existing widget tests reference it.)

- [ ] **Step 10: Commit**

  ```bash
  git add lib/screens/gallery/gallery_screen.dart pubspec.yaml pubspec.lock ios/Runner/Info.plist
  git commit -m "feat: add Save to Photos button in gallery full-screen dialog"
  ```

---

## Self-Review

**Spec coverage check:**

| Opportunity from strategy | Covered by task |
|---|---|
| Reveal music swell | Task 3 ✓ |
| Haptic choreography | Not in this plan — haptic at reveal is a 1-line add (`HapticFeedback.heavyImpact()`) already available; user can add ad-hoc |
| Ambient background music | Task 2 ✓ |
| Mid-drawing narrative teaser ("almost there!") | Task 4 ✓ |
| Dot personality micro-animations (proximity) | Task 5 ✓ |
| Gallery "Save to Photos" | Task 6 ✓ |
| Missing audio calls wired | Task 1 ✓ |

**Types and methods are consistent across tasks:**
- `playRevealSwell()` defined in Task 3 Step 1, called in Task 3 Step 2 ✓
- `fingerPosition` field added in Task 5 Step 1, used in Step 2, passed in Step 5 ✓
- `_repaintKey` and `_saving` defined in Task 6 Step 5, used in Steps 6–8 ✓
- `_encouragementPlayed` added in Task 4 Step 1, reset in Step 2, used in Step 3 ✓

**Placeholder scan:** No TBDs, no "implement later", all code steps contain complete code. ✓
