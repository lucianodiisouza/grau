# Grau

> A free, open-source, native macOS utility for cleaning, inspecting, and managing your Mac's storage.
> CleanMyMac for people who'd rather not pay $40/year.

**Status:** 🚧 Active development. Currently at **v0.1.0-alpha** (Phase 0: Scaffold complete). Next: Phase 1 (Junk cleaner + tray) → Beta 1.

## What it will do (v1.0)

- 🧹 **Junk cleaner** — caches, logs, browser data, dev caches
- 📦 **App uninstaller** — uninstalls `.app` bundles *and* their residual data
- 🔍 **Disk lens** — visualize your whole disk, drill down, free space safely
- 🪞 **Duplicates finder** — find byte-identical files anywhere
- 🛠 **Dev mode** — `node_modules`, package manager caches, Docker, iOS Simulators
- 📌 **Menu bar tray** — live storage state, smart notifications

## First principles

1. **The user owns their data.** Grau never silently deletes anything. Everything goes to `~/.Trash`.
2. **Be a good citizen.** Reads what it needs, asks for permissions once, never exfiltrates.
3. **Look and feel native.** Not "designed on iOS." Sidebar, system materials, SF Symbols, smart dark mode.
4. **Be fast.** Scans in seconds, not minutes.

## Build

Native Swift + SwiftUI, macOS 14+ (Sonoma) and up. Apple Silicon and Intel. No third-party runtime dependencies in v1 except Sparkle for self-update.

```bash
# Generate the Xcode project
brew install xcodegen
xcodegen generate

# Build the Swift package (logic + tests)
cd graucore && swift test

# Build the macOS app
xcodebuild -project grau.xcodeproj -scheme grau -configuration Debug build
```

## Project layout

```
grau/
├── grau/                 # App target (SwiftUI + AppKit)
│   ├── DesignSystem/     # Colors, spacing, components
│   ├── Features/         # Dashboard, Clean, Uninstaller, DiskLens, Duplicates, DevMode, ...
│   ├── grauApp.swift     # @main
│   └── grau.entitlements
├── graucore/             # Swift Package — pure logic, unit-testable
│   ├── Sources/graucore/ # Primitives, FS, Permissions, Volume, Junk, Uninstaller, ...
│   └── Tests/graucoreTests/
├── docs/                 # The full plan: PLAN, ARCHITECTURE, DATA-SOURCES, DESIGN, HANDOFF, TASKS, REVIEW
├── .github/workflows/    # CI
├── project.yml           # XcodeGen config (source of truth for the Xcode project)
├── CHANGELOG.md
└── LICENSE               # MIT
```

## Documentation

- [docs/README.md](./docs/README.md) — start here
- [docs/PLAN.md](./docs/PLAN.md) — what & why (vision, scope, 5-slice plan)
- [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) — how (modules, data model, concurrency)
- [docs/DESIGN.md](./docs/DESIGN.md) — visual language
- [docs/PERMISSIONS.md](./docs/PERMISSIONS.md) — Full Disk Access story
- [docs/DATA-SOURCES.md](./docs/DATA-SOURCES.md) — every path Grau touches
- [docs/HANDOFF.md](./docs/HANDOFF.md) — implementation guide for each task
- [docs/TASKS.md](./docs/TASKS.md) — the project tracker (8 epics, 61 tasks)
- [docs/REVIEW.md](./docs/REVIEW.md) — the staff-eng review that corrected the plan

## License

[MIT](./LICENSE).
