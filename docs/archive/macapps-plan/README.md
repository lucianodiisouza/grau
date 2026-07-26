# macapps — Planning Docs

This folder holds the planning + handoff documentation for **macapps**, a native
macOS SwiftUI app that scans installed applications and surfaces which ones have
updates available.

The docs are written for two audiences:

1. **A human** deciding whether to green-light the project and to which level of
   detail.
2. **An AI agent (or another engineer) executing the build** — these docs are
   intentionally self-contained. The implementing agent should not need to
   re-derive any decision; everything is locked in here.

## Doc index

| File | Purpose | Read it for… |
| --- | --- | --- |
| [PLAN.md](./PLAN.md) | Vision, scope, decisions, phases, success criteria | The "what" and "why" |
| [ARCHITECTURE.md](./ARCHITECTURE.md) | Components, data model, data flow, tech stack | The "how" — system shape |
| [DATA-SOURCES.md](./DATA-SOURCES.md) | Per-source mechanics for detecting "outdated" | The hard part of the app |
| [HANDOFF.md](./HANDOFF.md) | Step-by-step build order, file paths, code stubs | The actual build instructions |

**Suggested reading order:** README (this) → PLAN → ARCHITECTURE → DATA-SOURCES
→ HANDOFF.

## TL;DR

A menu-bar + window hybrid SwiftUI app for macOS 14+ that walks
`/Applications` and `~/Applications`, classifies each app's update source (Mac
App Store, Homebrew Cask, Sparkle, direct), and surfaces outdated ones with a
"how to update" action. External CLIs (`mas`, `brew`) are optional and used
gracefully when present.

## Project status

- [x] Planning docs (this folder)
- [ ] Project scaffold (Xcode + Swift Package)
- [ ] Phase 1 — Scan & display
- [ ] Phase 2 — Sparkle outdated detection
- [ ] Phase 3 — MAS + Homebrew outdated detection
- [ ] Phase 4 — Polish, preferences, packaging

(Outdated checkboxes are intentional — the implementing agent should tick
them off in `HANDOFF.md` as phases complete.)
