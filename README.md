# Dot Story

An iPad game for children where numbered dots are connected to reveal drawings — all wrapped in a narrative story experience with voiceover audio, multilingual support, and in-app purchases.

---

## Table of Contents

- [Overview](#overview)
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

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        DotStoryApp                          │
│                    (GoRouter + Riverpod)                    │
├──────────────┬──────────────┬──────────────┬───────────────┤
│   Screens    │   Widgets    │   Services   │    Models     │
│              │              │              │               │
│ Onboarding   │ StoryCard    │ AssetService │ DotModel      │
│ StorySelect  │ ParentalGate │ ProgressSvc  │ DrawingModel  │
│ Drawing      │ ConfettiOver │ AudioService │ StoryModel    │
│ Completion   │              │ PurchaseSvc  │ ProgressModel │
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
│   │   ├── drawing_model.dart             # Full drawing: dots, canvas size, difficulty, i18n names
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
│       ├── app_en.arb                      # English strings (28 keys)
│       ├── app_he.arb                      # Hebrew strings
│       └── app_ar.arb                      # Arabic strings
│
├── assets/
│   ├── drawings/
│   │   ├── knight/                         # story1 knight: dots from real content-tool output
│   │   ├── dragon/                         # Placeholder dot coordinates (needs real content)
│   │   ├── castle/                         # Placeholder dot coordinates (needs real content)
│   │   └── *_s2-5/                         # Story 2–5 variants for each character
│   ├── stories/
│   │   └── stories.json                    # Story metadata + chapter narrations
│   ├── story_cards/                        # Preview images shown in the story grid
│   ├── characters/                         # Character sprites for transition screens
│   └── audio/
│       ├── en/ he/ ar/                     # Voiceover files per language
│       │   └── numbers/                    # Individual number pronunciations
│       ├── encouragement/                  # Random praise clips (6 per language)
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
| `/onboarding` | `OnboardingScreen` | Shown on first launch only |
| `/stories` | `StorySelectionScreen` | Main hub |
| `/drawing/:drawingId` | `DrawingScreen` | `:drawingId` matches drawing JSON filename |
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
  final double x;  // normalized to canvas coordinate space
  final double y;
}
```

### `DrawingModel`
```dart
class DrawingModel {
  final String id;
  final Map<String, String> names;   // { "en": "Knight", "he": "אביר", "ar": "فارس" }
  final String storyId;
  final int chapter;
  final String difficulty;           // "easy" | "medium" | "hard"
  final double canvasWidth;
  final double canvasHeight;
  final String outlineImagePath;
  final String coloredImagePath;
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
  final List<String> drawingIds;
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
- `loadDrawing(id)` → parses `assets/drawings/{id}/{id}.json`
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

Key methods: `playNumber(lang, n)`, `playEncouragement(lang)` (random from 6 clips), `playDotConnect()`, `playDrawingComplete()`, `playChapterNarration(lang, storyId, chapter)`.

### `PurchaseService`
Wraps `in_app_purchase`. Product ID: `com.dotstory.fullaccess`.
- `init()` → subscribes to purchase stream
- `buyFullAccess()` / `restorePurchases()`
- Verified purchases call back into `ProgressService` to set `purchaseUnlocked = true`

---

## Screens

### Onboarding (`/onboarding`)
Interactive tutorial with 3 dots. Walks the child through the tap-to-connect mechanic using an animated hand sprite. Completes by saving `onboardingComplete = true` then navigating to `/stories`.

### Story Selection (`/stories`)
2-column grid of story cards. Each card shows the story preview image, title, and a progress bar (`X of Y drawings complete`). A parental gate (arithmetic dialog) guards access to the Settings sheet. The gallery button is always accessible.

### Drawing (`/drawing/:drawingId`)
Core gameplay screen. `DrawingSessionState` (autoDispose provider) tracks:
- Which dots have been tapped
- The current animating line segment
- Active line style (sparkle/wave/glow — cycles per connection)
- Hint state (pulsing dot)

The `HintController` starts a timer after each correct tap. If the child doesn't tap the next dot within `hintDelaySeconds`, the next expected dot pulses.

`DotCanvasPainter` renders:
1. A plain white background (no image shown during dot-connect)
2. Completed connection lines (with their stored style)
3. The current animating line (lerped end-point)
4. All dots as numbered circles; completed dots show a checkmark

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
Grid item showing: story preview image, localized title, `LinearProgressIndicator` (completed / total drawings), and a lock icon if the story requires a purchase.

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

### Drawing JSON format (`assets/drawings/{id}/{id}.json`)
```json
{
  "id": "knight",
  "names": { "en": "Knight", "he": "אביר", "ar": "فارس" },
  "story_id": "story1",
  "chapter": 1,
  "difficulty": "easy",
  "canvas_width": 1122,
  "canvas_height": 1402,
  "image_colored": "assets/drawings/knight/colored.png",
  "tutorial_steps": [],
  "dots": [
    { "id": 1, "x": 561.0, "y": 112.0 },
    ...
  ]
}
```

### Image file naming convention

Each drawing folder requires **one image file**:

| File | Purpose |
|------|---------|
| `assets/drawings/{id}/colored.png` | Final colored illustration — revealed after all dots are connected |

The `image_outline` field is optional and no longer used in gameplay. You only need to supply `colored.png` per drawing.
```

### Stories JSON format (`assets/stories/stories.json`)
```json
[
  {
    "id": "story1",
    "titles": { "en": "The Knight's Quest", "he": "מסע האביר", "ar": "مسيرة الفارس" },
    "companionAsset": "assets/characters/knight_companion.png",
    "previewAsset": "assets/story_cards/story1_card.png",
    "drawingIds": ["knight", "dragon", "castle"],
    "chapters": [
      {
        "chapterNumber": 1,
        "narrations": {
          "en": "Once upon a time...",
          "he": "היה היה פעם...",
          "ar": "كان يا ما كان..."
        }
      }
    ]
  }
]
```

### Audio file naming conventions
```
assets/audio/{lang}/numbers/{n}.mp3       # e.g. audio/en/numbers/7.mp3
assets/audio/{lang}/encouragement/{n}.mp3 # n = 1..6
assets/audio/{lang}/{storyId}/chapter_{n}.mp3
assets/audio/{lang}/{drawingId}_name.mp3
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
flutter devices                  # list available devices
flutter run -d "iPad (10th generation)"   # or any iPad simulator name
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
| Audio files | Not included — the content creation pipeline produces them. App handles missing files silently. |
| `dragon.json` / `castle.json` dot coordinates | Placeholder values — need real content-tool output. |
| UI strings | Mostly hardcoded English in screen widgets; ARB files exist for proper localization wiring. |
| StoreKit product | `com.dotstory.fullaccess` must be created in App Store Connect before IAP works. |
| Tutorial step images | `tutorialSteps` arrays are empty — no images yet. |
| Confetti position | Offset by ~56px (progress bar height) — minor visual nit. |
| App Store compliance | Privacy manifest, COPPA declaration, and age rating need to be set in App Store Connect. |
| Story 2–5 content | Asset folders (`*_s2-5/`) exist but drawing JSON files have placeholder data. |
