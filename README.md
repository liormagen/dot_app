# Dot Story

An iPad game for children (ages 3–7) where numbered dots are connected to reveal drawings — all wrapped in a narrative story experience with voiceover audio, multilingual support, and in-app purchases. Built with Flutter, targeting iPad.

---

## Table of Contents

- [Overview](#overview)
- [Design System](#design-system)
- [Features](#features)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [State Management](#state-management)
- [Navigation](#navigation)
- [Data Models](#data-models)
- [Services](#services)
- [Screens](#screens)
- [Widgets](#widgets)
- [Localization](#localization)
- [Assets](#assets)
- [Getting Started](#getting-started)
- [Known Gaps / TODO](#known-gaps--todo)

---

## Overview

Dot Story is a Flutter-based iPad app designed for young children. Each "story" consists of multiple chapters. In each chapter the child:

1. **Connects numbered dots** on a clean canvas to reveal a hidden drawing (knight, dragon, castle, etc.)
2. **Sees the colored image revealed** with an animated sweep after all dots are connected
3. **Advances through story narration** between chapters

The app ships with voiceover audio (per language), encouragement sounds, and a gallery to revisit completed drawings.

---

## Design System

The app uses a **Toca Boca / Handmade** visual language throughout all screens. The goal is a bold, playful aesthetic that feels crafted — not digital.

### Color Tokens

```dart
const _kRed    = Color(0xFFE82D2D);  // Primary action, danger, accents
const _kYellow = Color(0xFFF5C800);  // Headers, highlights, stars
const _kGreen  = Color(0xFF2DB84B);  // Success, positive feedback
const _kBlue   = Color(0xFF1FA3E8);  // Secondary actions, progress
const _kInk    = Color(0xFF1A1A2E);  // All outlines, borders, text
const _kPaper  = Color(0xFFFFF8E7);  // App background, canvas surface
```

### Typography

**`GoogleFonts.boogaloo`** is used for all text — headings, labels, counters, and buttons. No other font family is used anywhere in the app.

### Visual Rules

| Rule | Value |
|------|-------|
| Container borders | `Border.all(color: _kInk, width: 3–4)` |
| Drop shadows | `BoxShadow(color: _kInk, offset: Offset(x, y), blurRadius: 0)` — hard/flat, no blur |
| Gradients | **None** — flat solid colors only |
| Border radius | Chunky rounded corners (12–22px depending on element) |
| Text outlines | 8-directional `TextStyle.shadows` via `_inkOutline(w)` helper |
| Animations | Spring physics: `Curves.elasticOut` for bounce-backs; `Curves.easeOutQuart` for initial press |

---

## Features

| Feature | Description |
|---|---|
| Dot-to-dot drawing | Tap numbered dots in sequence; animated lines connect them |
| 3 line animation styles | Sparkle, Wave, Glow — cycle with each connection |
| Colored image reveal | Animated left-to-right sweep reveals the colored drawing after all dots connected |
| Story narration | Chapter transitions with character animations and voiceover |
| Hint system | Timer-based pulsing of the next expected dot (configurable per difficulty) |
| Parental gate | Arithmetic dialog locks the Settings sheet |
| Multilingual | English, Hebrew (RTL), Arabic (RTL) with dynamic switching |
| In-app purchase | One-time "Full Access" unlock (`com.dotstory.fullaccess`) |
| Gallery | Displays all completed colored drawings |
| Onboarding | Interactive 3-dot tutorial with animated hand guide |
| Confetti | Particle celebration overlay on drawing/story completion |
| Interactive welcome | Wandering blobs with tap-squeeze + elastic line drag-to-reconnect |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        DotStoryApp                          │
│                    (GoRouter + Riverpod)                    │
├──────────────┬──────────────┬──────────────┬───────────────┤
│   Screens    │   Widgets    │   Services   │    Models     │
│              │              │              │               │
│ Welcome      │ StoryCard    │ AssetService │ DotModel      │
│ Onboarding   │ ParentalGate │ ProgressSvc  │ DrawingModel  │
│ StorySelect  │ ConfettiOver │ AudioService │ StoryModel    │
│ Drawing      │              │ PurchaseSvc  │ ProgressModel │
│ Completion   │              │              │               │
│ Transition   │              │              │               │
│ StoryComplete│              │              │               │
│ Gallery      │              │              │               │
└──────────────┴──────────────┴──────────────┴───────────────┘
                         │
              SharedPreferences (local)
              JSON assets (bundled)
              AudioPlayers (3 instances)
              StoreKit / Google Play IAP
```

**Key principles:**

- **Services are initialized in `main()` and injected via `ProviderScope.overrides`** — screens never instantiate services directly.
- **`autoDispose` providers** are used for per-session drawing state so it resets cleanly when the user leaves a drawing screen.
- **All audio calls are wrapped in try/catch** — audio files may not exist during development; the app degrades silently.
- **Flood-fill runs in a `compute()` isolate** — prevents frame drops on large canvases.
- **Localization is dynamic** — changing language in Settings immediately re-renders the entire app without restart.

---

## Project Structure

```
dot_app/
├── lib/
│   ├── main.dart                          # Bootstrap: services init, ProviderScope
│   ├── app.dart                           # DotStoryApp widget + GoRouter config
│   │
│   ├── models/
│   │   ├── dot_model.dart                 # Single dot: id, x, y (JSON-serializable)
│   │   ├── drawing_model.dart             # Full drawing: dots, canvas size, difficulty, audioPath
│   │   ├── story_model.dart               # Story + chapters with localized narrations
│   │   └── progress_model.dart            # Immutable user state (completed drawings, settings)
│   │
│   ├── services/
│   │   ├── asset_service.dart             # Loads + caches JSON assets (stories, drawings)
│   │   ├── progress_service.dart          # SharedPreferences read/write + ProgressNotifier
│   │   ├── audio_service.dart             # Three AudioPlayer instances (voiceover/sfx/music)
│   │   └── purchase_service.dart          # In-app purchase: buy + restore
│   │
│   ├── screens/
│   │   ├── welcome/
│   │   │   └── welcome_screen.dart        # Animated welcome with interactive blobs + elastic lines
│   │   ├── onboarding/
│   │   │   └── onboarding_screen.dart     # 3-dot tutorial with animated hand
│   │   ├── story_selection/
│   │   │   ├── story_selection_screen.dart # Story grid with per-story progress
│   │   │   └── settings_sheet.dart         # Language / audio / purchase settings
│   │   ├── drawing/
│   │   │   ├── drawing_screen.dart         # Core gameplay: dot tapping + session state
│   │   │   ├── dot_canvas.dart             # CustomPainter: outline image, dots, animated lines
│   │   │   ├── drawing_types.dart          # LineStyle enum, Connection model, DrawingSessionState
│   │   │   └── hint_controller.dart        # Timer → pulse animation on next expected dot
│   │   ├── completion/
│   │   │   ├── completion_screen.dart      # Post-drawing: reveal colored image + coloring phases
│   │   │   └── color_fill_canvas.dart      # Flood-fill painter (compute isolate on RGBA pixels)
│   │   ├── story_transition/
│   │   │   └── transition_screen.dart      # Chapter narration + character animation
│   │   ├── story_completion/
│   │   │   └── story_completion_screen.dart # Final story gallery + share
│   │   └── gallery/
│   │       └── gallery_screen.dart         # All completed drawings across stories
│   │
│   ├── widgets/
│   │   ├── story_card.dart                 # Grid card: preview image + progress bar
│   │   ├── parental_gate.dart              # Arithmetic dialog (60-second unlock window)
│   │   └── confetti_overlay.dart           # Particle animation overlay
│   │
│   └── l10n/
│       ├── app_en.arb                      # English strings
│       ├── app_he.arb                      # Hebrew strings
│       └── app_ar.arb                      # Arabic strings
│
├── assets/
│   ├── stories/
│   │   ├── stories.json                    # Story metadata + chapter narrations + drawing_ids
│   │   ├── story1/
│   │   │   ├── ch1/
│   │   │   │   ├── ch1.json               # Dot coordinates, canvas size, difficulty
│   │   │   │   ├── ch1_outline.png        # Black-and-white outline shown during gameplay
│   │   │   │   ├── ch1_colored.png        # Full-color image revealed on completion
│   │   │   │   └── ch1_audio.mp3          # Narration voiceover for this chapter
│   │   │   ├── ch2/  (same structure)
│   │   │   └── ch3/  (same structure)
│   │   ├── story2/ … story5/              # Same structure; image files reference story1/
│   │   │                                  # (placeholder audio: replace with real recordings)
│   ├── story_cards/                        # Preview images shown in the story grid
│   ├── characters/                         # Character sprites for transition screens
│   └── audio/
│       ├── en/ he/ ar/                     # Voiceover files per language
│       │   └── numbers/                    # Individual number pronunciations (1.mp3 … N.mp3)
│       ├── encouragement/                  # Random praise clips
│       └── sfx/                            # dot_connect.mp3, confetti.mp3, complete.mp3, etc.
│
├── pubspec.yaml
├── l10n.yaml                               # ARB dir + output file config
└── analysis_options.yaml
```

---

## State Management

The app uses **Flutter Riverpod** throughout.

| Provider | Type | Purpose |
|---|---|---|
| `assetServiceProvider` | `Provider` | Singleton `AssetService` (no override needed) |
| `storiesProvider` | `FutureProvider` | Loads stories.json once, cached |
| `progressServiceProvider` | `Provider` | Injected via `ProviderScope.overrides` in `main()` |
| `progressProvider` | `StateNotifierProvider` | Reactive user progress; exposes `ProgressNotifier` |
| `audioServiceProvider` | `Provider` | Injected via `ProviderScope.overrides` in `main()` |
| `purchaseServiceProvider` | `Provider` | Injected via `ProviderScope.overrides` in `main()` |
| `drawingSessionProvider` | `StateNotifierProvider.autoDispose` | Per-screen drawing session; resets on exit |

Services that require async initialization (`ProgressService`, `AudioService`, `PurchaseService`) are initialized in `main()` before `runApp()`, then passed into `ProviderScope.overrides` — this avoids late-initialization errors and keeps services testable.

---

## Navigation

Navigation uses **GoRouter** with path parameters:

| Route | Screen | Notes |
|---|---|---|
| `/` | Splash / redirect | Checks onboarding flag → `/onboarding` or `/stories` |
| `/welcome` | `WelcomeScreen` | Animated entry with interactive blob layer |
| `/onboarding` | `OnboardingScreen` | Shown on first launch only |
| `/stories` | `StorySelectionScreen` | Main hub |
| `/drawing/:drawingId` | `DrawingScreen` | `:drawingId` = `story{N}_ch{N}` format |
| `/completion/:drawingId` | `CompletionScreen` | Coloring phase after drawing complete |
| `/transition/:storyId/:chapterIndex` | `TransitionScreen` | Narration between chapters |
| `/story-complete/:storyId` | `StoryCompletionScreen` | End-of-story celebration |
| `/gallery` | `GalleryScreen` | All completed drawings |

---

## Data Models

### `DotModel`
```dart
class DotModel {
  final int id;
  final double x;  // canvas coordinate space
  final double y;
}
```

### `DrawingModel`
```dart
class DrawingModel {
  final String id;                    // e.g. "story1_ch1"
  final Map<String, String> names;    // { "en": "The Knight", "he": "הפרש", "ar": "الفارس" }
  final String storyId;               // e.g. "story1"
  final int chapter;
  final String difficulty;            // "easy" | "medium" | "hard"
  final int canvasWidth;
  final int canvasHeight;
  final String? imageOutline;         // path to black-and-white outline PNG
  final String imageColored;          // path to full-color PNG
  final String? audioPath;            // path to chapter narration MP3
  final List<String> tutorialSteps;
  final List<DotModel> dots;

  int get hintDelaySeconds => difficulty == "easy" ? 2 : difficulty == "medium" ? 3 : 5;
}
```

### `StoryModel` / `StoryChapter`
```dart
class StoryModel {
  final String id;
  final Map<String, String> titles;
  final String companionAsset;
  final String previewAsset;
  final List<String> drawingIds;      // e.g. ["story1_ch1", "story1_ch2", "story1_ch3"]
  final List<StoryChapter> chapters;
}

class StoryChapter {
  final int chapterNumber;
  final Map<String, String> narrations;  // localized text
}
```

### `ProgressModel`
```dart
class ProgressModel {
  final Set<String> completedDrawingIds;
  final String selectedLanguage;     // "en" | "he" | "ar"
  final bool onboardingComplete;
  final bool musicEnabled;
  final bool sfxEnabled;
  final bool purchaseUnlocked;
}
```
Immutable — updated via `copyWith()`. Persisted to `SharedPreferences` by `ProgressService`.

---

## Services

### `AssetService`
Loads bundled JSON files and caches results in memory.
- `loadStories()` → parses `assets/stories/stories.json`
- `loadDrawing(id)` → splits `"story1_ch1"` into `storyId="story1"`, `chId="ch1"`, then loads `assets/stories/story1/ch1/ch1.json`
- `loadStoryDrawings(story)` → batch loads all drawings for a story

### `ProgressService`
Wraps `SharedPreferences`. All keys are string constants defined in the class.
- `init()` → must be called before `runApp()`
- `load()` / `save(model)` — full model read/write
- Individual setters for granular updates (e.g. `markDrawingComplete(id)`)
- Exposes `ProgressNotifier extends StateNotifier<ProgressModel>` for Riverpod integration

### `AudioService`
Manages **three separate `AudioPlayer` instances**:
- `_voiceoverPlayer` — narrations and drawing name pronunciations (does not loop)
- `_sfxPlayer` — dot connect, confetti, completion sounds
- `_musicPlayer` — background music (loops)

Key methods: `playNumber(lang, n)`, `playEncouragement(lang)` (random from available clips), `playDotConnect()`, `playDrawingComplete()`, `playChapterNarration(lang, storyId, chapter)`.

### `PurchaseService`
Wraps `in_app_purchase`. Product ID: `com.dotstory.fullaccess`.
- `init()` → subscribes to purchase stream
- `buyFullAccess()` / `restorePurchases()`
- Verified purchases call back into `ProgressService` to set `purchaseUnlocked = true`

---

## Screens

### Welcome (`/welcome`)
Full-screen Toca Boca-styled entry screen. Features:
- **Wandering blobs** — 6 soft colored circles that drift slowly using sine-wave paths; transparent, playful
- **Elastic lines** — bezier curves connecting the blobs; rotate endpoints on a timer
- **Interactive blobs** — tap a blob to trigger a jelly squeeze animation (`TweenSequence`: fast `easeOutQuart` squish + `elasticOut` spring-back over 420ms)
- **Line dragging** — touch a line to disconnect one endpoint and drag it to a new blob; snaps on release or reverts if dropped in empty space
- **"Dot Story" title** — Boogaloo 100px, `_kYellow` fill with 8-directional `_kInk` outline
- **Play button** — round `_kRed` badge with hard drop shadow

### Onboarding (`/onboarding`)
Interactive tutorial with 3 dots. Walks the child through the tap-to-connect mechanic using an animated hand sprite. Completes by saving `onboardingComplete = true` then navigating to `/stories`.

### Story Selection (`/stories`)
2-column grid of story cards. Design features:
- **Floating sticker header** — yellow `_kYellow` badge rotated slightly, with double drop shadow (`_kInk` + `_kRed`), displaying "Dot Story" in Boogaloo with flanking stars
- **Story cards** — press animation: fast 90ms `easeOut` scale-down + 550ms `elasticOut` spring-back; thick black border + hard offset shadow
- **Wandering blobs** — same as welcome screen (no lines), providing ambient background motion
- **Parental gate** guards the Settings sheet

### Drawing (`/drawing/:drawingId`)
Core gameplay screen. `DrawingSessionState` (autoDispose provider) tracks:
- Which dots have been tapped
- The current animating line segment
- Active line style (sparkle/wave/glow — cycles per connection)
- Hint state (pulsing dot)

**Progress bar** (Toca Boca design):
- `_kYellow` bar, 72px tall, 4px black bottom border + hard `BoxShadow(offset: Offset(0,5), blurRadius: 0)`
- Round `_kRed` home button with hard shadow; navigates to `/stories`
- `_kInk` counter badge showing `★ N / total` in Boogaloo white
- Chunky white progress track with `TweenAnimationBuilder` smooth fill; fill color cycles: `_kRed` (0–35%) → `_kBlue` (35–68%) → `_kGreen` (68–100%)
- Counter starts at **1** (not 0) and ends at total, showing current progress intuitively

The `HintController` starts a timer after each correct tap. If the child doesn't tap the next dot within `hintDelaySeconds`, the next expected dot pulses.

On final dot connected → navigate to `/completion/:drawingId`.

### Completion (`/completion/:drawingId`)
Multi-phase screen:
1. **Reveal** — colored image sweeps in from left over a white background
2. **Name reveal** — displays and pronounces the drawing's name
3. **Tutorial steps** — shows any guide images (if present); then navigates to next chapter

### Transition (`/transition/:storyId/:chapterIndex`)
Displays localized chapter narration text, plays the voiceover, and shows the companion character with an elastic scale animation. A "Continue" button appears after audio finishes (3-second fallback timer if audio fails).

### Story Completion (`/story-complete/:storyId`)
Shows all drawings in the completed story as a gallery row, plays the final narration, and offers a share option.

### Gallery (`/gallery`)
Displays all completed drawings across every story. Stories are tab-filtered. Shows the saved colored image thumbnail. Tapping a drawing does not re-open it (read-only showcase).

---

## Widgets

### `StoryCard`
Grid item showing: story preview image, localized title, progress bar (completed / total drawings), and a lock icon if the story requires a purchase. Uses Toca Boca press animation.

### `ParentalGate`
Modal dialog with a randomly generated arithmetic question (e.g. "7 + 4 = ?"). On correct answer, unlocks a 60-second window so the parent doesn't need to re-solve it for quick follow-up taps.

### `ConfettiOverlay`
Canvas-based particle system. Particles spawn from the top, fall with slight horizontal drift, and fade out. Used on drawing completion and story completion screens.

---

## Localization

The app supports **English**, **Hebrew**, and **Arabic**. Hebrew and Arabic are RTL; Flutter handles text direction automatically once the locale is set.

Configuration is in `l10n.yaml`:
```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
```

After adding or changing ARB keys, regenerate with:
```bash
flutter gen-l10n
```

Language is stored in `ProgressModel.selectedLanguage` and applied by rebuilding the `MaterialApp` locale.

---

## Assets

### Asset folder structure

```
assets/stories/
├── stories.json
├── story1/
│   ├── ch1/
│   │   ├── ch1.json          ← dot data, canvas size, difficulty, image & audio paths
│   │   ├── ch1_outline.png   ← black-and-white outline (shown during gameplay)
│   │   ├── ch1_colored.png   ← full-color illustration (revealed on completion)
│   │   └── ch1_audio.mp3     ← chapter narration voiceover  ← PLACEHOLDER — replace with recording
│   ├── ch2/  (same structure)
│   └── ch3/  (same structure)
├── story2/ … story5/
│   └── ch1-3/
│       ├── ch{N}.json        ← dot data (different difficulty/dot count per story)
│       └── ch{N}_audio.mp3   ← PLACEHOLDER — replace with recording
│       (images reference story1/ — update json fields when new art is ready)
```

Stories 2–5 currently reuse story1's images (`image_outline` / `image_colored` fields in their JSON files point to `assets/stories/story1/chN/`). Update those fields in each chapter's JSON once new artwork is created.

### Chapter JSON format (`assets/stories/story{N}/ch{N}/ch{N}.json`)

```json
{
  "id": "story1_ch1",
  "names": { "en": "The Knight", "he": "הפרש", "ar": "الفارس" },
  "story_id": "story1",
  "chapter": 1,
  "difficulty": "medium",
  "canvas_width": 1122,
  "canvas_height": 1402,
  "image_outline": "assets/stories/story1/ch1/ch1_outline.png",
  "image_colored": "assets/stories/story1/ch1/ch1_colored.png",
  "audio_path": "assets/stories/story1/ch1/ch1_audio.mp3",
  "tutorial_steps": [],
  "dots": [
    { "id": 1, "x": 272, "y": 491 },
    ...
  ]
}
```

**Difficulty levels** control the hint timer:

| Difficulty | Hint delay |
|------------|-----------|
| `"easy"` | 2 seconds |
| `"medium"` | 3 seconds |
| `"hard"` | 5 seconds |

### Stories JSON format (`assets/stories/stories.json`)

```json
{
  "stories": [
    {
      "id": "story1",
      "titles": { "en": "The Knight's Quest", "he": "מסע הפרש", "ar": "رحلة الفارس" },
      "companion_asset": "assets/characters/the_knight.png",
      "preview_asset": "assets/story_cards/story1.png",
      "drawing_ids": ["story1_ch1", "story1_ch2", "story1_ch3"],
      "chapters": [
        {
          "chapter": 1,
          "narrations": {
            "en": "Once upon a time...",
            "he": "פעם היה פרש אמיץ...",
            "ar": "كان يا ما كان..."
          }
        }
      ]
    }
  ]
}
```

### Audio file conventions

```
assets/stories/story{N}/ch{N}/ch{N}_audio.mp3   ← chapter narration (one per chapter)

assets/audio/{lang}/numbers/{n}.mp3              ← number pronunciation  e.g. audio/en/numbers/7.mp3
assets/audio/encouragement/{n}.mp3              ← random praise clips
assets/audio/sfx/dot_connect.mp3
assets/audio/sfx/confetti.mp3
assets/audio/sfx/drawing_complete.mp3
```

---

## Getting Started

### Prerequisites
- Flutter SDK 3.16 or later (`flutter --version`)
- Xcode 15+ with an iOS Simulator or physical iPad
- CocoaPods (`sudo gem install cocoapods`)

### Setup

```bash
# 1. Clone
git clone https://github.com/liormagen/dot_app.git
cd dot_app

# 2. Generate native iOS/Android scaffolding (safe to run on existing project)
flutter create .

# 3. Install dependencies
flutter pub get

# 4. Generate localization files
flutter gen-l10n

# 5. Install iOS pods
cd ios && pod install && cd ..

# 6. Run on a simulator
flutter devices                           # list available devices
flutter run -d "iPad Air 13-inch (M4)"   # or any iPad simulator name
```

### Building for a physical iPad
Open `ios/Runner.xcworkspace` in Xcode, set your Bundle Identifier and signing team, then run from Xcode or:
```bash
flutter run -d <device-udid>
```

---

## Known Gaps / TODO

| Area | Status |
|---|---|
| Audio files | All 15 chapter audio files are empty placeholders. Replace `assets/stories/story{N}/ch{N}/ch{N}_audio.mp3` with real narration recordings. |
| Artwork for stories 2–5 | Chapter JSON files for stories 2–5 currently reference story1 images. Create new art per story and update the `image_outline` / `image_colored` fields in each chapter JSON. |
| Dot coordinates for stories 2–5 | Placeholder coordinates copied from story1. Each story's chapters need their own dot placements. |
| StoreKit product | `com.dotstory.fullaccess` must be created in App Store Connect before IAP works. |
| Tutorial step images | `tutorial_steps` arrays are empty — no guide images yet. |
| App Store compliance | Privacy manifest, COPPA declaration, and age rating need to be set in App Store Connect. |
| Number audio files | `assets/audio/{lang}/numbers/` needs one MP3 per dot number, per language. |
| Encouragement audio | `assets/audio/encouragement/` needs random praise clips. |
| SFX files | `assets/audio/sfx/` needs `dot_connect.mp3`, `confetti.mp3`, `drawing_complete.mp3`. |
