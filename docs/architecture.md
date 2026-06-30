# Memoring — Architecture (app-architect)

> Phase 2 deliverable. Clean architecture, feature-first, offline-first.
> Dependencies point inward only: presentation → domain ← data.

## Layer map

```
lib/
├── main.dart                       # ProviderScope + app bootstrap
├── app/
│   ├── app.dart                    # MaterialApp.router + theme
│   ├── router/app_router.dart      # go_router (home, compose, detail, settings, alert)
│   └── theme/                      # design tokens → ThemeData (no raw hex anywhere else)
├── core/
│   ├── result.dart                 # typed Result<T> (no raw exceptions to UI)
│   └── widgets/                    # GlassCard, GlassButton, SegmentedToggle (reused)
├── features/
│   ├── scheduler/                  # THE INTELLIGENCE LAYER
│   │   ├── domain/
│   │   │   ├── parsed_reminder.dart        # ParseOutcome (sealed) + ParsedReminder
│   │   │   ├── time_intent_parser.dart     # interface (swap rule-based → LLM in v2)
│   │   │   └── reminder_scheduler.dart      # classify + next-occurrence
│   │   ├── data/
│   │   │   └── rule_based_time_intent_parser.dart  # deterministic parser (the brain)
│   │   └── presentation/scheduler_providers.dart
│   ├── reminders/
│   │   ├── domain/{reminder.dart, recurrence.dart, reminder_repository.dart}
│   │   ├── data/in_memory_reminder_repository.dart  # v1; Drift drops in behind the interface
│   │   └── presentation/{reminders_controller.dart, home_screen.dart, reminder_detail_screen.dart}
│   ├── compose/presentation/compose_screen.dart
│   ├── alert/presentation/full_screen_alert.dart
│   └── settings/presentation/settings_screen.dart
└── shared/services/notification_service.dart   # interface + flutter_local_notifications impl
```

## Key decisions

1. **Parser behind an interface (`TimeIntentParser`).** v1 is rule-based + pure +
   offline. v2 can swap an LLM impl with zero churn to callers. `parse()` takes
   `now` as a parameter → fully deterministic and unit-testable.
2. **Parser returns *local wall-clock* `DateTime`.** Persistence/notification layers
   convert to UTC / tz-aware instants. This keeps the brain pure and free of tz I/O.
3. **`ReminderRepository` interface.** v1 impl is in-memory (compiles with no
   codegen). The Drift (SQLite) impl plugs in behind the same interface — no
   presentation changes. *(Deviation from CLAUDE.md's "Drift now" is purely a
   build-tooling constraint in this environment; the seam is ready.)*
4. **Security is built in, not bolted on** (see §Security below).
5. **No business logic in widgets.** Widgets render; Riverpod notifiers + the
   scheduler decide. Every button calls a controller method.

## Data model (entity → future Drift table)

`Reminder`: `id` (uuid), `text`, `createdAt`, `fireAt` (next occurrence),
`type` (short|long), `recurrence` (none|daily|weekly|monthly|yearly + weekday),
`isActive`, `snoozedUntil?`, `soundEnabled`, `completedAt?`.

## Provider graph

```
parserProvider            → RuleBasedTimeIntentParser (pure)
schedulerProvider         → ReminderScheduler (classify + nextOccurrence)
notificationServiceProvider → LocalNotificationService
reminderRepositoryProvider  → InMemoryReminderRepository
remindersProvider (Stream)  → repo.watchAll()
remindersControllerProvider → add / complete / delete / snooze (wires repo + scheduler + notifications)
```

## Security model (offline + hostile-input-safe)

- **Input validation at the edge:** max 500 chars, trimmed, control chars stripped,
  empty-after-parse rejected. The parser never executes input — pure regex/keyword
  matching, no `eval`, no dynamic code.
- **Past-time guard:** a computed time in the past is rejected with a friendly error,
  never silently scheduled.
- **No network, no accounts, no analytics:** reminders never leave the device
  (privacy by design). Nothing to exfiltrate.
- **Non-guessable ids:** uuid v4, never sequential.
- **Defensive errors:** all async repo ops return `Result<T>`; nothing throws raw to UI.
- **No `any`-style dynamics, no force-unwrap (`!`)** in the engine.
