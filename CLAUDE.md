# CLAUDE.md — Memoring

> This file is the single source of truth for the Memoring project. Every agent
> reads this file before doing anything. If a rule lives here, it overrides
> defaults. Keep it current — when architecture or design tokens change, update
> this file in the same commit.

---

## 1. Product

**Memoring** is a mobile reminder app that turns plain text into perfectly-timed,
full-screen alerts. The user types what they want to remember in natural language
and Memoring figures out *when* to fire it.

Two reminder classes:

| Class          | Window            | Examples                                                |
| -------------- | ----------------- | ------------------------------------------------------- |
| **Short-term** | under 1 month     | "remind me in 2 hours", "daily standup", "every Monday" |
| **Long-term**  | months → yearly+  | "renew passport in 8 months", "anniversary every year"  |

When a reminder is due, the app shows a **full-screen takeover** with the reminder
text plus a ringtone/vibration — impossible to ignore, easy to dismiss or snooze.

### Core loop
1. User types text → 2. Intelligence layer parses time intent → 3. Reminder is
slotted into short-term or long-term queue → 4. OS-level scheduled notification →
5. Full-screen alert + sound at the right moment → 6. User dismisses / snoozes / done.

---

## 2. Tech Stack

- **Framework:** Flutter (stable channel)
- **Language:** Dart (null-safe, latest stable SDK)
- **State management:** Riverpod (`flutter_riverpod`)
- **Local DB:** Drift (SQLite) — reminders persist offline, no backend required for v1
- **Notifications:** `flutter_local_notifications` + `awesome_notifications` for full-screen intents
- **Time parsing:** custom Dart parser (see `reminder-engine` agent) — no paid NLP API for v1
- **Navigation:** `go_router`
- **Design source of truth:** Figma → exported tokens → Dart theme

> ⚠️ Do not add a cloud backend, accounts, or analytics in v1. Memoring is
> offline-first and privacy-first. Reminders never leave the device.

---

## 3. Design System (NON-NEGOTIABLE)

The look is **matte black + shiny white**, iPhone-grade, with **liquid glass
morphism**. Clean, minimal, premium. No clutter, no neon, no gradients-for-the-sake-of-it.

### Color tokens
| Token                 | Hex         | Use                                   |
| --------------------- | ----------- | ------------------------------------- |
| `matteBlack`          | `#0A0A0B`   | Primary background                    |
| `surfaceBlack`        | `#141416`   | Cards, sheets                         |
| `glassTint`           | `#FFFFFF14` | Frosted glass overlay (8% white)      |
| `shinyWhite`          | `#FAFAFA`   | Primary text, key icons               |
| `mutedWhite`          | `#A0A0A8`   | Secondary text                        |
| `accent`             | `#E8E8EA`   | Active states, focus ring (soft white)|
| `shortTermAccent`     | `#7DD3FC`   | Subtle cyan tag for short-term        |
| `longTermAccent`      | `#C4B5FD`   | Subtle violet tag for long-term       |
| `dangerRed`           | `#FF453A`   | Delete / overdue                      |

### Glass morphism rules
- Frosted panels use `BackdropFilter` with `ImageFilter.blur(sigmaX: 20, sigmaY: 20)`.
- Glass surfaces: 8–12% white tint, 1px hairline border at 10% white, 24px corner radius.
- Soft, low-opacity shadows only (`Colors.black.withOpacity(0.4)`, blur 30, no harsh edges).
- Always layer glass over the matte-black background — never over pure white.

### Typography
- iPhone-native feel: **SF Pro Display / SF Pro Text**. Bundle `SF-Pro` or use the
  closest free substitute (`Inter` for body, tight tracking) if SF Pro can't be licensed.
- Headings: SF Pro Display, weight 600, tight letter-spacing (`-0.5`).
- Body: 16px, weight 400, 1.4 line-height.
- Never use more than 2 font weights on one screen.

### Motion
- Everything animates: 200–300ms, `Curves.easeOutCubic`.
- Glass sheets slide up with a spring; alerts scale-in from 0.95 → 1.0.
- **Every button must have a pressed state** (scale 0.97 + opacity dip). No dead taps.

### Layout
- 20px screen padding, 16px between cards, generous whitespace.
- One primary action per screen, bottom-anchored and thumb-reachable.

---

## 4. Architecture (Clean Architecture, feature-first)

```
lib/
├── main.dart
├── app/                 # App widget, router, theme, DI bootstrap
│   ├── theme/           # Design tokens → ThemeData (owned by design-architect)
│   └── router/
├── core/                # Shared: errors, extensions, constants, glass widgets
│   └── widgets/         # GlassCard, GlassButton, FullScreenAlert (reusable)
├── features/
│   ├── compose/         # The text-input screen (type a reminder)
│   ├── reminders/       # List, detail, edit (short + long term)
│   ├── scheduler/       # Time-parsing + slotting intelligence
│   └── alert/           # Full-screen takeover + sound
└── shared/
    ├── data/            # Drift DB, repositories
    └── services/        # Notification service, permission service
```

Each feature folder follows: `presentation/` (widgets + Riverpod providers) →
`domain/` (entities + use-cases) → `data/` (repository impl + DB mappers).

Dependencies point **inward only**: presentation → domain ← data.

---

## 5. The Intelligence Layer (how reminders get slotted)

This is the heart of the product. Owned by the **reminder-engine** agent.

1. **Parse** free text for temporal intent ("in 2 hours", "next Friday",
   "every year on June 30", "in 8 months").
2. **Classify**: if the computed delta < 30 days → short-term queue; else → long-term.
3. **Compute** the exact next fire `DateTime` (respect device timezone + DST).
4. **Detect recurrence** ("daily", "every Monday", "yearly") and store a rule.
5. **Schedule** the OS notification. For recurring reminders, re-schedule the next
   occurrence the moment the current one fires.
6. **Fallback**: if text has no parseable time, prompt the user with a quick
   time-picker instead of guessing.

> v1 uses a deterministic rule-based parser (regex + keyword grammar). Keep it
> testable and offline. An LLM upgrade is a v2 concern — design the parser behind
> an interface so it can be swapped later.

---

## 6. Coding Standards

- `dart format` and `flutter analyze` must pass with **zero warnings** before any commit.
- Lint via `flutter_lints` + `very_good_analysis`. No `// ignore` without a reason comment.
- Every public class/function has a doc comment.
- No business logic in widgets. Widgets render; providers/use-cases decide.
- Name files `snake_case.dart`, classes `PascalCase`, providers `camelCaseProvider`.
- One widget per file for anything reusable.
- Write a unit test for every parser rule and every use-case.

### Commit style
`type(scope): summary` — e.g. `feat(scheduler): add yearly recurrence parsing`.
Types: `feat`, `fix`, `design`, `refactor`, `test`, `chore`, `docs`.

---

## 7. How the Agent Team Works

Memoring is built by a team of specialized agents (see `.claude/agents/`). They
operate like a small product company. The default flow:

```
orchestrator (you, the lead — plans & delegates)
   ├─ design-architect      → Figma flow + design tokens + glass components
   ├─ app-architect         → folder structure, DI, routing, DB schema
   ├─ flutter-developer     → builds screens & features in Dart
   ├─ reminder-engine       → the time-parsing + scheduling intelligence
   ├─ qa-engineer           → tests, edge cases, accessibility
   └─ deployment-engineer   → CI, signing, store builds & release
```

**Rule:** never skip the design phase. Figma flow and tokens come first, then
architecture, then features, then QA, then deploy. The orchestrator enforces this
order and hands off with clear, written specs.

---

## 8. Definition of Done (per feature)
- [ ] Matches the Figma frame and uses only design tokens (no hardcoded colors).
- [ ] Glass components reused from `core/widgets/` (no one-off duplicates).
- [ ] Every interactive element has a pressed/loading/disabled state.
- [ ] `flutter analyze` clean, formatted, tests pass.
- [ ] Works offline. Reminder actually fires full-screen with sound on a real device.
- [ ] No reminder data leaves the device.

---

## 9. Commands

```bash
flutter pub get            # install deps
flutter run                # run on device/simulator
flutter analyze            # lint (must be clean)
dart format .              # format
flutter test               # run tests
flutter build apk --release        # Android
flutter build ipa --release        # iOS
```
