# Design System Master File — Dot Story

> **LOGIC:** When building a specific page, first check `design-system/dot-story/pages/[page-name].md`.
> If that file exists, its rules **override** this Master file.
> If not, strictly follow the rules below.

---

**Project:** Dot Story
**Style:** Stardust Claymorphism
**Audience:** Children ages 3–7, iPad-first
**Tone:** Magical, warm, celebratory, premium — like a top-tier studio (Toca Boca, Sago Mini quality)
**Tech Stack:** Flutter (Dart), Google Fonts via google_fonts package

---

## 1. Color Palette

| Role | Hex | Flutter Constant | Usage |
|------|-----|-----------------|-------|
| **Purple Primary** | `#6C48FF` | `kColorPrimary` | Buttons, progress, headers |
| **Coral Energy** | `#FF6B6B` | `kColorCoral` | Connections line 1, accents |
| **Golden Star** | `#FFD93D` | `kColorGold` | Stars, rewards, highlights |
| **Mint Success** | `#6BCB77` | `kColorMint` | Connected dots, completion |
| **Sky Blue** | `#4FC3F7` | `kColorSky` | Secondary actions, info |
| **Deep Night** | `#1A0E3F` | `kColorNight` | Story screen background |
| **Warm Canvas** | `#FFF9F0` | `kColorCanvas` | Drawing screen background |
| **Lavender Bg** | `#F0EEFF` | `kColorLavender` | Story selection background |
| **Cream Card** | `#FFFFFF` | `kColorCard` | Card surfaces |
| **Deep Ink** | `#1A0A3F` | `kColorForeground` | Primary text |
| **Soft Purple Border** | `#D4C8FF` | `kColorBorder` | Card borders, dividers |
| **Muted Text** | `#7C6FA0` | `kColorMuted` | Secondary text |
| **Danger Red** | `#FF4757` | `kColorDanger` | Errors only |

### Color Notes
- Never use flat `#FFFFFF` backgrounds at the screen level — always `kColorLavender` or `kColorNight`
- The drawing game canvas uses `kColorCanvas` (warm cream) to make it feel like paper
- Story/narration screens use `kColorNight` + star particle layer for depth
- Celebration/completion screens use full-gradient backgrounds

---

## 2. Typography (Flutter google_fonts)

**Heading Font:** `Fredoka` — rounder, more premium than Baloo 2. Mandatory for all titles and scores.
**Body Font:** `Nunito` — clean, rounded, highly legible for early readers.

```dart
// Headline / Screen title
GoogleFonts.fredoka(
  fontSize: 36,
  fontWeight: FontWeight.w700,
  color: kColorForeground,
  height: 1.1,
)

// Section heading
GoogleFonts.fredoka(
  fontSize: 24,
  fontWeight: FontWeight.w600,
)

// Body / Story narration
GoogleFonts.nunito(
  fontSize: 22,
  fontWeight: FontWeight.w500,
  height: 1.7,
)

// Label / Caption
GoogleFonts.nunito(
  fontSize: 16,
  fontWeight: FontWeight.w600,
)

// Score / Progress number
GoogleFonts.fredoka(
  fontSize: 22,
  fontWeight: FontWeight.w700,
)
```

### Type Scale
| Role | Font | Size | Weight |
|------|------|------|--------|
| Display | Fredoka | 40px | 700 |
| Title | Fredoka | 32px | 700 |
| Heading | Fredoka | 24px | 600 |
| Body | Nunito | 22px | 500 |
| Label | Nunito | 17px | 600 |
| Caption | Nunito | 14px | 400 |

---

## 3. Spacing Scale (4dp base)

| Token | Value | Usage |
|-------|-------|-------|
| `xs` | 4dp | Icon-to-text gaps |
| `sm` | 8dp | Tight padding |
| `md` | 16dp | Standard padding |
| `lg` | 24dp | Section padding |
| `xl` | 32dp | Large section gaps |
| `2xl` | 48dp | Screen-level padding |
| `3xl` | 64dp | Hero padding |

---

## 4. Claymorphism Component Specs

### Clay Button (Primary CTA)

```dart
// Large CTA button — e.g. "Let's Draw!", "Next Story"
Container(
  decoration: BoxDecoration(
    color: kColorPrimary,
    borderRadius: BorderRadius.circular(28),
    border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
    boxShadow: [
      // Hard clay shadow (3D lift)
      BoxShadow(color: Color(0xFF3B1FCC), blurRadius: 0, offset: Offset(0, 6)),
      // Soft ambient glow
      BoxShadow(color: kColorPrimary.withValues(alpha: 0.45), blurRadius: 20, offset: Offset(0, 8)),
    ],
  ),
  padding: EdgeInsets.symmetric(horizontal: 48, vertical: 18),
  child: Text('Label', style: GoogleFonts.fredoka(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
)
```

**Press state:** `Transform.translate(offset: Offset(0, 4))` + remove hard shadow (shadow flattens)

### Clay Card

```dart
Container(
  decoration: BoxDecoration(
    color: kColorCard,
    borderRadius: BorderRadius.circular(28),
    border: Border.all(color: kColorBorder, width: 3),
    boxShadow: [
      BoxShadow(color: Color(0xFF3B2099).withValues(alpha: 0.22), blurRadius: 0, offset: Offset(5, 5)),
      BoxShadow(color: kColorPrimary.withValues(alpha: 0.12), blurRadius: 24, offset: Offset(0, 8)),
      BoxShadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 0, offset: Offset(-3, -3)),
    ],
  ),
)
```

### Progress Bar (Game)

```dart
// Tall, rounded, with star icon
Container(
  height: 64,
  decoration: BoxDecoration(
    gradient: LinearGradient(colors: [Color(0xFF6C48FF), Color(0xFF9C6FFF)]),
    // Hard bottom shadow for depth
    boxShadow: [BoxShadow(color: Color(0xFF3B1FCC), blurRadius: 0, offset: Offset(0, 4))],
  ),
)
// Bar fill: white with 0.9 opacity
// Star ⭐ icon left, Fredoka score text, rounded LinearProgressIndicator
```

---

## 5. Background Treatments

### Story Selection Screen
- Background: `kColorLavender` (#F0EEFF)
- Decorative layer: Soft purple polka dots at 5% opacity (36dp grid)
- Header: Gradient `#6C48FF → #9C6FFF`, border-radius bottom 32, hard shadow `Offset(0,5)`
- Stars / sparkles scattered as decorative elements

### Story Narration Screen (Transition)
- Background: `kColorNight` (#1A0E3F) — mandatory, creates magical atmosphere
- Particle layer: 60 white stars (0.2–0.8 opacity, random sizes 1–3px)
- Card: `kColorCard` with kColorBorder border, triple clay shadow
- Never use a light background on this screen

### Drawing Game Screen
- Background: `kColorCanvas` (#FFF9F0) — warm paper feel
- Progress bar: Gradient purple header
- Canvas itself is pure white (the "paper")

### Completion / Celebration Screen
- Background: Full multi-stop gradient `#1A0E3F → #6C48FF → #C084FC`
- Particle burst: confetti + stars animated
- Never a plain white or lavender background

---

## 6. Animation Standards

| Type | Duration | Easing | Notes |
|------|----------|--------|-------|
| Button press | 100ms | easeOut | Scale 1.0→0.95 + shadow flatten |
| Button release | 200ms | elasticOut | Bounce back with overshoot |
| Card tap | 120ms | easeOut | Scale 0.94 |
| Screen enter | 300ms | easeOut | Slide from bottom 40px + fade |
| Screen exit | 200ms | easeIn | Fade out |
| Dot connect line | 300ms | easeOut | Draw from→to |
| Hint pulse | 800ms | sineInOut | Repeat until tapped |
| Confetti burst | 1200ms | — | Particle physics |
| Story image reveal | 1500ms | easeInOut | Opacity 0→1 |
| Page chunk fade | 180ms out + 250ms in | easeIn/easeOut | Text crossfade |
| Comet orbit | 900ms | linear | Continuous repeat |

### Spring Physics
- Use `Curves.elasticOut` for button releases and card bounces
- Use `Curves.bounceOut` for dot connection completion
- Use `Curves.easeOutCubic` for screen transitions

---

## 7. Screen-Specific Design Tokens

### Drawing Screen Progress Bar
```
height: 64dp
background: LinearGradient(#6C48FF → #9C6FFF)
shadow: BoxShadow(#3B1FCC, offset(0,4), blur 0)
star icon: white, 22px
score text: Fredoka 22px white w700
progress indicator: white 0.3 bg, white fill, height 10, radius 99
```

### Dot Styling
```
radius: 16dp * scale
connected: fill #6BCB77, border #4CAF50
next: fill white, purple border, purple label, outer ring #6C48FF 0.25
hinting: yellow pulse ring #FFD93D
number font: Fredoka (NOT the default system font)
checkmark: white ✓
```

### Story Card (Selection Grid)
```
aspect ratio: 0.72
border radius: 28
border: 3px kColorBorder
shadow: clay triple shadow
image top 62%, info panel bottom 38%
title: Fredoka 18px w700 #1A0A3F
progress dots: 10px circles, filled=kColorPrimary
done badge: kColorMint green
```

---

## 8. Claymorphism Shadow System

Always use the triple-shadow pattern for elevated surfaces:

```dart
// Level 1 (cards, buttons)
boxShadow: [
  BoxShadow(color: Color(0xFF3B2099).withValues(alpha: 0.28), blurRadius: 0, offset: Offset(5, 5)),  // hard clay
  BoxShadow(color: kColorPrimary.withValues(alpha: 0.15), blurRadius: 20, offset: Offset(2, 8)),       // soft glow
  BoxShadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 0, offset: Offset(-3, -3)),        // light reflection
]

// Level 2 (headers, modals)
boxShadow: [
  BoxShadow(color: Color(0xFF3B1FCC), blurRadius: 0, offset: Offset(0, 6)),
  BoxShadow(color: Color(0x556C48FF), blurRadius: 28, offset: Offset(0, 12)),
]
```

---

## 9. Anti-Patterns (NEVER DO)

- ❌ **Flat white (#FFFFFF) screen backgrounds** — always use `kColorLavender`, `kColorNight`, or `kColorCanvas`
- ❌ **Muted/desaturated colors** — this is a kids game, energy must be HIGH
- ❌ **Thin, hairline borders** — minimum 2.5px, always `kColorBorder` or white
- ❌ **System default fonts** — always Fredoka (headings) + Nunito (body)
- ❌ **Single flat shadow** — always use the triple-shadow clay pattern
- ❌ **Linear progress animations** — always use easing curves
- ❌ **No press feedback** — every tappable element must have a press animation
- ❌ **Raw hex colors in code** — use named constants
- ❌ **Emojis as structural icons** — use Flutter Icons or custom painters
- ❌ **Low-contrast text** — 4.5:1 minimum

---

## 10. Pre-Delivery Checklist

- [ ] All text uses Fredoka (heading) or Nunito (body) — no Baloo 2 or Comic Neue
- [ ] All screen backgrounds use design system tokens (no plain white)
- [ ] All cards use triple clay shadow pattern
- [ ] All buttons have press animation (scale + shadow flatten, 100ms)
- [ ] All text contrast ≥ 4.5:1
- [ ] Touch targets ≥ 44×44pt
- [ ] Story/narration screen uses kColorNight background + star layer
- [ ] Drawing canvas uses kColorCanvas warm cream
- [ ] Completion screen uses gradient background + celebration particles
