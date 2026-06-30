# Memoring — Design Spec v1 (design-architect)

> Phase 1 deliverable. Build-ready, screen-by-screen. Matte black + shiny white,
> liquid-glass, iPhone-grade. Every value below maps to a token in CLAUDE.md §3 —
> no raw hex in code. This is the contract the flutter-developer builds against.

---

## 0. Design principles

1. **Calm & premium.** Matte-black canvas, frosted glass floating above it, one
   bright focal action per screen. Nothing competes for attention.
2. **Type-first.** The product is "type a thought, forget it." The compose field is
   the hero of the whole app.
3. **Always show the time it understood.** The parser's guess is shown live and big,
   so the user trusts it before saving.
4. **No dead taps.** Every interactive element has pressed / disabled / loading states.
5. **Thumb-first.** Primary action bottom-anchored within the bottom 1/3 of the screen.
6. **Responsive** (see §9): one layout that scales gracefully from a 360px phone to a
   tablet, respecting safe areas and Dynamic Type.

---

## 1. Token quick-reference (source of truth = CLAUDE.md §3)

| Group   | Token              | Value        |
| ------- | ------------------ | ------------ |
| BG      | matteBlack         | #0A0A0B      |
| Surface | surfaceBlack       | #141416      |
| Glass   | glassTint          | #FFFFFF14 (8% white) |
| Text    | shinyWhite         | #FAFAFA      |
| Text    | mutedWhite         | #A0A0A8      |
| State   | accent             | #E8E8EA      |
| Tag     | shortTermAccent    | #7DD3FC (cyan)  |
| Tag     | longTermAccent     | #C4B5FD (violet)|
| Danger  | dangerRed          | #FF453A      |

Glass recipe: `BackdropFilter blur(20,20)` · 8–12% white tint · 1px hairline border
@10% white · 24px radius · soft shadow `black @40%, blur 30`.
Spacing scale: 4 / 8 / 12 / 16 / 20 / 24 / 32. Screen padding 20. Card gap 16.
Type: SF Pro Display (headings, w600, tracking -0.5) · SF Pro Text / Inter (body,
16/1.4, w400). Max 2 weights per screen.
Motion: 200–300ms `easeOutCubic`. Sheets spring up. Alert scales 0.95→1.0. Buttons
press to scale 0.97 + opacity dip.

---

## 2. Navigation / flow map

```
[Splash]
   └─> first launch? ──yes──> [Onboarding 1: value] ─> [Onboarding 2: permission] ─┐
                     └──no───────────────────────────────────────────────────────┐│
                                                                                   ▼▼
                                                                              [Home / List]
   Home ── (+) FAB ───────────────────> [Compose] ──save──> back to Home (new card animates in)
   Home ── tap a card ────────────────> [Reminder Detail / Edit] ──save/delete──> Home
   Home ── gear icon ─────────────────> [Settings]
   (OS notification fires) ───────────> [Full-Screen Alert] ──dismiss/snooze/done──> Home or lock
```

Tab/segment inside Home: **Short-term** ⇄ **Long-term** (segmented glass toggle, no
page nav — content swaps with a 250ms cross-fade + slide).

---

## 3. Onboarding (2 screens)

**Screen A — Value.** Centered. Big headline "Type it. Forget it. We'll remind you."
in shinyWhite (SF Pro Display 32/w600/-0.5), one-line subhead in mutedWhite. A glass
card mock of a reminder floats mid-screen. Bottom: primary GlassButton "Get started".
**Screen B — Permission.** Explains *why* notifications matter ("Memoring needs to
show full-screen alerts so you never miss a reminder."). Primary "Enable notifications"
triggers the OS prompt; secondary text-button "Maybe later" (mutedWhite). On grant →
Home. On deny → Home with a persistent inline banner offering to enable later.

States: loading (button spinner while OS prompt resolves), denied (banner).
Motion: cards drift in 300ms; page-to-page slide with parallax on the glass mock.

---

## 4. Home / Reminders list  ← primary screen

```
┌───────────────────────────────┐  20px padding
│  Memoring            ⚙         │  title row (SF Pro Display 28/w600)
│                               │
│  ┌─────────────────────────┐  │  segmented glass toggle (full width, 44px)
│  │  Short-term │ Long-term  │  │  active pill = glass @12% + accent text
│  └─────────────────────────┘  │
│                               │  16px gap
│  ┌─────────────────────────┐  │  GlassCard (radius 24)
│  │ ● cyan  in 2 hours       │  │  tag dot + relative time (shortTermAccent)
│  │ Call mom                 │  │  text (shinyWhite 17/w500)
│  │ today · 4:30 PM          │  │  meta (mutedWhite 13)
│  └─────────────────────────┘  │
│  ┌─────────────────────────┐  │  swipe L = complete (green), swipe R = delete (red)
│  │ ● cyan  tomorrow 9:00    │  │
│  │ Daily standup  ↻         │  │  ↻ recurrence glyph
│  └─────────────────────────┘  │
│                               │
│                         (＋)  │  FAB bottom-right, glass, 56px, accent glow
└───────────────────────────────┘
```

- **Card anatomy:** left tag dot (cyan=short, violet=long), relative time as the
  emphasis line, reminder text below, absolute date/time meta, optional ↻ recurrence
  glyph, optional snooze badge. Overdue → time turns dangerRed.
- **Sort:** soonest fire time first.
- **Swipe actions** sit on a colored bed revealed behind the glass card.
- **FAB** opens Compose with a spring + shared-element morph into the text field.

**States**
- *Empty:* centered glass illustration + "Nothing scheduled. Tap ＋ to add your first
  reminder." Primary FAB still present.
- *Loading:* 3 shimmer skeleton cards (glass placeholders).
- *Error:* glass card "Couldn't load reminders" + "Retry" button.

---

## 5. Compose  ← the hero

```
┌───────────────────────────────┐
│  ✕                       Save  │  Save disabled until text + valid time
│                               │
│  Remind me to…                │  giant text field, autofocus, SF Pro Display 24
│  │ call mom in 2 hours        │  caret; placeholder mutedWhite
│                               │
│  ┌─────────────────────────┐  │  LIVE PARSE PREVIEW (glass pill), updates as you type
│  │ → fires in 2 hours       │  │  shinyWhite, with classified tag dot (cyan/violet)
│  │   today, 4:30 PM · short │  │  meta row
│  └─────────────────────────┘  │
│                               │
│  Suggestions:                 │  optional quick chips (glass): "tonight", "tomorrow
│  [tonight][tomorrow 9am][↻]   │  9am", "every Monday" — tap to insert
└───────────────────────────────┘
          [   Save reminder   ]    bottom-anchored primary GlassButton
```

- **Live preview** is driven by `TimeIntentParser`. Three preview states:
  1. *Parsed:* "→ fires in 2 hours · today 4:30 PM · short-term" + tag dot.
  2. *No time found* (`needsManualTime`): preview becomes a tappable "Pick a time"
     row that opens a glass time-picker bottom sheet. Never guess.
  3. *Past time:* preview turns dangerRed "That time has already passed" and Save
     stays disabled.
- The parsed time-phrase is **stripped** from the saved text ("call mom in 2 hours"
  → stored text "call mom"); show the cleaned text faintly under the preview.
- Save button: disabled (40% opacity) until valid; loading spinner on tap.

**States:** empty (placeholder), typing (live parse), needs-time, past-time error,
saving (spinner), saved (sheet closes, Home card animates in).

---

## 6. Reminder detail / edit

Glass sheet (or full screen on small devices). Editable: text, fire time (time-picker
sheet), recurrence (segmented: none / daily / weekly / monthly / yearly / custom),
sound toggle, snooze default. Footer: "Save changes" (primary) + "Delete" (dangerRed
text button → confirm dialog). Shows next-fire preview live, same component as Compose.

States: view, editing (dirty → Save enabled), saving, delete-confirm, deleted.

---

## 7. Full-screen Alert  ← the takeover

```
┌───────────────────────────────┐  matteBlack, NO chrome, edge-to-edge
│                               │
│            ● cyan             │  tag dot, centered
│                               │
│         Call mom              │  HUGE — SF Pro Display 40/w600, centered
│                               │
│        today · 4:30 PM        │  mutedWhite meta
│                               │
│                               │
│   ┌─────────┐   ┌─────────┐   │  two big glass buttons, thumb row
│   │ Snooze  │   │  Done   │   │  Snooze (accent) · Done (filled shinyWhite)
│   └─────────┘   └─────────┘   │
│        Dismiss (text)         │  tertiary
└───────────────────────────────┘
```

- Scales in 0.95→1.0 + fade, subtle glass shimmer. Ringtone + vibration play until
  the user acts. Snooze opens a quick "+5 / +15 / +60 min / custom" glass row.
- **Platform note (from reminder-engine):** Android = true full-screen-intent on a
  high-importance channel. iOS = time-sensitive/critical notification that launches
  this in-app screen on tap (iOS limits true OS takeovers — documented, not a bug).
- Recurrence-safe: Done/Snooze must not lose the recurrence rule.

---

## 8. Settings

Grouped glass list: **Sound** (default ringtone picker, vibration toggle), **Snooze**
(default duration stepper), **Appearance** (theme — locked to dark for v1, shown as
"Matte black"), **Permissions** (re-request notifications / exact-alarm shortcut with
status chip), **About / Privacy** ("Your reminders never leave this device.").
Each row: label (shinyWhite) + control; section headers in mutedWhite caps.

---

## 9. Responsive behavior (user asked for this explicitly)

One adaptive layout, not separate designs:

| Width band         | Behavior                                                        |
| ------------------ | -------------------------------------------------------------- |
| ≤ 360px (small)    | 16px screen padding, type scale −1 step, detail opens full-screen instead of sheet |
| 361–430px (phones) | Baseline spec above (20px padding)                            |
| 431–600px (large)  | Cards max-width 520px, centered; FAB stays bottom-right        |
| ≥ 600px (tablet)   | Two-column reminder grid; Compose preview sits beside the field; content column capped at 640px, centered on matteBlack |

- Use `MediaQuery` + `LayoutBuilder`; never hardcode pixel positions.
- Respect safe-area insets (notch, home indicator) on every screen.
- **Dynamic Type:** all text scales with the OS font-size setting; cards grow in
  height, never clip. Test at the largest accessibility size.
- Orientation: portrait-primary; landscape allowed on tablets only.

---

## 10. Glass component specs (build these in core/widgets/)

| Component        | Spec                                                                                  |
| ---------------- | ------------------------------------------------------------------------------------- |
| `GlassCard`      | blur 20 · tint 8% · border 1px @10% · radius 24 · padding 16 · shadow black@40 blur30 |
| `GlassButton`    | same glass · height 52 · radius 16 · pressed scale .97 + opacity .85 · disabled 40% · loading spinner replaces label |
| `GlassBottomSheet`| blur 24 · tint 12% · top radius 28 · grab handle · springs up 300ms                  |
| `SegmentedToggle`| glass track · active pill glass@12% + accent text · 250ms slide between segments       |
| `FullScreenAlert`| edge-to-edge matteBlack · scale-in 0.95→1.0 · two GlassButtons + dismiss              |
| `TagDot`         | 8px dot · cyan(short)/violet(long) · used on cards, compose preview, alert            |

All components ship with: pressed + disabled + loading states, 44pt min touch target,
AA contrast verified on glass.

---

## 11. Accessibility checklist (verify per screen)

- [ ] Min 44pt touch targets everywhere.
- [ ] AA contrast: shinyWhite on matteBlack passes; mutedWhite only for non-essential
      meta; never convey state by color alone (tag dot is paired with a text label).
- [ ] Every control has a semantic label / screen-reader name.
- [ ] Respect `prefers-reduced-motion` → swap spring/scale for a simple fade.
- [ ] Layout survives largest Dynamic Type without clipping.
- [ ] Focus order is logical; full-screen alert announces itself.

---

## 12. Handoff

→ **app-architect**: confirm routes (onboarding, home, compose, detail, alert,
settings) and that the alert route is launchable from a background notification tap.
Confirm the `TimeIntentParser` interface so Compose's live preview binds to it.
→ **flutter-developer** (after architecture): build glass primitives first, then
Home → Compose → Detail → Alert → Settings → Onboarding, each verified against §10–11.
