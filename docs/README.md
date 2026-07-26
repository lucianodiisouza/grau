# Grau — Planning Docs

This folder holds the planning + handoff documentation for **Grau**, a free
and open-source native macOS utility for cleaning, inspecting, and managing
your Mac's storage.

Grau is built in Swift + SwiftUI for **macOS 14 (Sonoma)+**, targets
**Apple Silicon and Intel**, and is licensed under **MIT**.

The docs are written for two audiences:

1. **A human** deciding whether to green-light the project and at what scope.
2. **An AI agent (or another engineer) executing the build** — these docs
   are intentionally self-contained. The implementing agent should not need
   to re-derive any decision; everything is locked in here.

## Doc index

| File | Purpose | Read it for… |
| --- | --- | --- |
| [PLAN.md](./PLAN.md) | Vision, scope, decisions, 5-slice phased plan, success criteria | The "what" and "why" |
| [ARCHITECTURE.md](./ARCHITECTURE.md) | Components, modules, data model, shared primitives | The "how" — system shape |
| [DATA-SOURCES.md](./DATA-SOURCES.md) | What counts as junk, dev caches, system paths | The hard part of every feature |
| [PERMISSIONS.md](./PERMISSIONS.md) | Full Disk Access, TCC, the onboarding story | Why we need what we need |
| [DESIGN.md](./DESIGN.md) | Visual language, components, interaction patterns | The "modern native feel" promise |
| [HANDOFF.md](./HANDOFF.md) | Step-by-step build order, file paths, code stubs | The actual build instructions |
| [TASKS.md](./TASKS.md) | Epic + task breakdown per phase, with file paths | The project plan, ready for tracking |
| [REVIEW.md](./REVIEW.md) | Staff-eng review: bugs found, simplifications, why the other docs look the way they do | Historical record; read first if you're an AI implementing |

**Suggested reading order:** README (this) → PLAN → ARCHITECTURE → DESIGN →
PERMISSIONS → DATA-SOURCES → HANDOFF → TASKS → REVIEW (last, for context).

## What Grau is (TL;DR)

A native macOS app that helps the user reclaim, understand, and manage
their Mac's storage. Five feature areas:

1. **Junk cleaner** — caches, logs, trash, browser data, dev caches.
2. **App uninstaller** — uninstall `.app` bundles *and* their residual
   data in `~/Library`.
3. **Disk lens** — visualize the whole disk, drill down, free space
   safely.
4. **Duplicates finder** — find byte-identical files anywhere on disk.
5. **Dev mode** — `node_modules`, package caches (npm/yarn/pnpm/cocoapods/
   cargo/gem/gradle/maven/swiftpm), Docker, iOS Simulators.

Plus a **menu bar tray** that surfaces storage state and notifications.

Grau **never** permanently deletes anything without an explicit user
action. Destructive operations move things to the user's Trash and let
them empty it on their own schedule. This is a trust commitment and is
non-negotiable.

## Project status

- [x] Planning docs (this folder)
- [x] Staff-eng review applied ([REVIEW.md](./REVIEW.md))
- [ ] Phase 0 — Scaffold (Xcode project, design system, CI, path audit, onboarding shell)
- [ ] Phase 1 — Junk cleaner + menu bar (beta 1, ~4 wk)
- [ ] Phase 2 — App uninstaller (beta 2, ~3 wk)
- [ ] Phase 3 — Disk lens (beta 3, ~2 wk) — Top-N list view, treemap deferred to v1.1
- [ ] Phase 4 — Duplicates finder (beta 4, ~2.5 wk)
- [ ] Phase 5 — Dev mode (beta 5, ~4 wk)
- [ ] Phase 6a — Polish pt 1 (1.0, ~1.5 wk) — icon+DMG+notarize+Privacy Manifest
- [ ] Phase 6b — Polish pt 2 (1.1, ~1.5 wk) — Sparkle + Homebrew Cask

**Total: ~19 wk to 1.0, +1.5 wk to 1.1.**

## Conventions used throughout the docs

- **File paths** are relative to the repo root.
- **Code identifiers** are English. User-facing strings (UI text) start in
  English and are structured for future localization.
- **"FDA"** = Full Disk Access (macOS Privacy & Security permission).
- **"TCC"** = Transparency, Consent, and Control — Apple's permission
  framework.
- **"The user"** = the end user of Grau, not the developer building it.
- **"Always"** / **"never"** in the docs are strong claims. Read them as
  "unless a higher-priority doc says otherwise."
- **"v1"** = the first public release. v1.0 = the polished version after
  all 5 betas.

## Archived plans

[`archive/macapps-plan/`](./archive/macapps-plan/) contains the original
outdated-app-detector plan that was the seed for this project. Parts of
the architecture (the App Scanner module structure) were carried over
into the Grau Uninstaller feature. The rest is historical.

## License

Grau is MIT-licensed. See [`LICENSE`](../LICENSE) at the repo root.
