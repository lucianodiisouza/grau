# Grau

> A free, open-source, native macOS utility for cleaning, inspecting, and managing your Mac's storage.
> CleanMyMac for people who'd rather not pay $40/year.

**Status:** ✅ **v1.0.0** (stable). All five features functional. Self-update via DMG; Sparkle + Homebrew Cask land in v1.1.

![Grau icon](grau/Assets.xcassets/AppIcon.appiconset/icon_1024.png)

## Features

- 🧹 **Junk cleaner** — caches, logs, browser data, dev caches, iOS backups. Five categories with safe defaults; everything moves to `~/.Trash`, never deleted.
- 📦 **App uninstaller** — uninstalls `.app` bundles *and* their residual data (caches, preferences, app support, group containers).
- 🔍 **Disk lens** — visualize your disk as a Top-N list. Drill down to see what's eating space.
- 🪞 **Duplicates finder** — find byte-identical files anywhere. 3-phase pipeline (size → partial hash → full SHA-256). Defaults to keeping the oldest copy.
- 🛠 **Dev mode** — track `node_modules`, 16 package manager caches, Docker, iOS Simulators, Xcode DerivedData, and archives. Hidden behind a Settings toggle.

## First principles

1. **The user owns their data.** Grau never silently deletes anything. Everything goes to `~/.Trash`, with a JSON manifest in `~/.grau/trash-manifests/`.
2. **Be a good citizen.** Reads what it needs, asks for Full Disk Access once, never exfiltrates. No third-party network calls in v1.
3. **Look and feel native.** Sidebar, system materials, SF Symbols, smart dark mode, dynamic type.
4. **Be fast.** Scans in seconds, not minutes. Six Dev-mode inspectors run in parallel.
5. **No surprise writes.** Every destructive action is preceded by a confirmation; every confirmable category is classified `safe` or `userCaution`.

## Install

Download the latest DMG from the [Releases](../../releases) page. Open the DMG, drag `Grau.app` to `/Applications`, and launch. The app requests Full Disk Access on first run; granting it unlocks System Caches and Logs.

> v1.1 will add `brew install --cask grau` and Sparkle self-update.

## Build

Native Swift + SwiftUI. macOS 14+ (Sonoma) and up. Apple Silicon and Intel. **No third-party runtime dependencies in v1** (Sparkle is added in v1.1).

```bash
# Prereqs: Xcode 15+, Swift 5.9+, xcodegen
brew install xcodegen

# Clone
git clone https://github.com/lucianodiisouza/grau
cd grau

# Generate the Xcode project
xcodegen generate

# Run the graucore unit tests (155 tests)
cd graucore && swift test

# Build the macOS app
xcodebuild -project grau.xcodeproj -scheme grau -configuration Debug build
```

## Package a release DMG

```bash
./scripts/make-dmg.sh 1.0.0
# → dist/Grau-1.0.0.dmg

# Optional: notarize for Gatekeeper
./scripts/notarize.sh dist/Grau-1.0.0.dmg \
    --team-id <TEAM_ID> \
    --keychain-profile <KEYCHAIN_PROFILE>
```

## Project layout

```
grau/
├── grau/                       # App target (SwiftUI + AppKit)
│   ├── DesignSystem/           # Colors, spacing, 7 components
│   ├── Features/               # Dashboard, Clean, Uninstaller, DiskLens,
│   │                           # Duplicates, DevMode, Onboarding, Settings
│   ├── grauApp.swift           # @main
│   └── grau.entitlements
├── graucore/                   # Swift Package — pure logic, unit-testable
│   ├── Sources/graucore/       # 41 modules across 9 domains
│   └── Tests/graucoreTests/    # 155 tests
├── docs/                       # The full plan, architecture, design
├── scripts/                    # DMG + notarize helpers
├── .github/workflows/          # CI
├── project.yml                 # XcodeGen config
├── CHANGELOG.md
└── LICENSE                     # MIT
```

## Documentation

- [docs/README.md](./docs/README.md) — start here
- [docs/PLAN.md](./docs/PLAN.md) — what & why (vision, scope, 5-slice plan)
- [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) — how (modules, data model, concurrency)
- [docs/DESIGN.md](./docs/DESIGN.md) — visual language
- [docs/PERMISSIONS.md](./docs/PERMISSIONS.md) — Full Disk Access story
- [docs/DATA-SOURCES.md](./docs/DATA-SOURCES.md) — every path Grau touches
- [docs/HANDOFF.md](./docs/HANDOFF.md) — implementation guide for each task
- [docs/TASKS.md](./docs/TASKS.md) — the project tracker
- [docs/REVIEW.md](./docs/REVIEW.md) — the staff-eng review that corrected the plan
- [docs/MANUAL-TEST.md](./docs/MANUAL-TEST.md) — the pre-release checklist
- [docs/TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md) — known issues + fixes

## Contributing

Issues and PRs welcome. See [CONTRIBUTING.md](./CONTRIBUTING.md).

## License

[MIT](./LICENSE).
