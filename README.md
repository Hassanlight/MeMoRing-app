# Memoring — Claude Code Project Scaffold

This is the planning + agent scaffold for **Memoring**, a Flutter reminder app.
It does not contain the app code yet — it contains the *team* and the *rules* that
Claude Code will use to build the app for you.

## What's inside

```
memoring/
├── CLAUDE.md                       # Project brain — read by every agent
├── README.md                       # This file
├── .claude/
│   └── agents/
│       ├── orchestrator.md         # Lead — plans & delegates (start here)
│       ├── design-architect.md     # Figma flow + tokens + glass components
│       ├── app-architect.md        # Structure, DI, routing, Drift DB
│       ├── flutter-developer.md    # Builds the screens in Dart
│       ├── reminder-engine.md      # Time parsing + scheduling intelligence
│       ├── qa-engineer.md          # Tests & sign-off
│       └── deployment-engineer.md  # CI, signing, store release
└── docs/                           # Agents fill these as they work
```

## How to use it

1. Put this `memoring/` folder at the root of your project (or run
   `flutter create memoring` first, then copy `CLAUDE.md` and `.claude/` into it).
2. Open the folder in **Claude Code**.
3. Verify the agents are picked up:
   ```
   /agents
   ```
   You should see all 7 agents listed.
4. Kick off the build by talking to the lead, e.g.:
   > "Use the orchestrator to plan and build Memoring v1, starting with the
   >  full design flow."

The orchestrator will run the pipeline:
**design → architecture → build → QA → deploy**, delegating to each specialist.

## The pipeline at a glance

```
orchestrator
   ├─ design-architect      → Figma flow + matte-black/glass tokens   (FIRST)
   ├─ app-architect         → folders, DI, go_router, Drift schema
   ├─ flutter-developer     → screens & glass widgets in Dart
   ├─ reminder-engine       → "remind me in 2 hours" → scheduled alert
   ├─ qa-engineer           → tests + sign-off
   └─ deployment-engineer   → APK/IPA + store release   (LAST)
```

## The product in one line
Type a reminder in plain text → Memoring figures out *when* → fires a full-screen
alert with sound at the right moment. Short-term (under a month) and long-term
(months/yearly) reminders, offline and private, in a premium matte-black + shiny-white
liquid-glass iPhone design.

## Tips
- Edit `CLAUDE.md` whenever you want to change the design tokens, stack, or rules —
  every agent will follow the update automatically.
- The model on each agent (`opus` / `sonnet`) is a suggestion; tune to your plan.
- If you have a Figma MCP connector, the design-architect can create real frames;
  otherwise it produces a build-ready written spec.
