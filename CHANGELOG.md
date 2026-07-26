# Changelog

All notable changes to Grau are documented here. The format is
based on [Keep a Changelog](https://keepachangelog.com/), and this
project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Planned for Phase 4 (Beta 4)
- Duplicates finder: size → partial-hash → full-SHA256 pipeline
- Safe selection (keep oldest)

## [0.4.0-beta.3] — 2026-07-26

Public beta. The third feature (disk lens) is end-to-end functional.
Grau shows the top 50 folders by size at the current path (starting
at "/"). The user can drill in by double-clicking a row, jump back
to the root via the toolbar, and right-click to reveal in Finder or
move to Trash.

v1 ships a Top-N list view, NOT a full treemap. The treemap
deferred to v1.1 per docs/REVIEW.md S3.

### graucore
- **`Lens/DiskTreeNode`** — struct: id, url, name, size,
  optional children. `isLeaf` and `sortedChildren` helpers.
- **`Lens/DiskTreeBuilder`** — `actor`. `topFolders(at:limit:)`:
  parallel-sized Top-N list. `size(of:)`: single-path size.
  Symlinks excluded by default.

Test count: **86** tests, all green.

### grau
- **`DiskLens/DiskLensView`** — toolbar (Root, Refresh), breadcrumb,
  Top-N list with size column, drill-in on double-click, context
  menu (Reveal in Finder, Move to Trash via `FileManager.trashItem`).

### Build
- `xcodebuild -scheme grau -configuration Debug build` — ✓
- `xcodebuild -scheme grau -configuration Release build` — ✓
- `cd graucore && swift test` — 86/86 ✓

### Known limitations
- No explicit cancel button; v1 scans are fast enough on the
  top 50 to not need one.
- The Move-to-Trash action in the context menu does NOT write
  a Trash manifest (it uses `FileManager.trashItem` directly,
  not `TrashMover`). v1.1 can route this through `TrashMover`
  for consistency.

[Unreleased]: # (HEAD)
[0.1.0-alpha]: https://github.com/lucianodiisouza/grau/releases/tag/v0.1.0-alpha
[0.2.0-beta.1]: https://github.com/lucianodiisouza/grau/releases/tag/v0.2.0-beta.1
[0.3.0-beta.2]: https://github.com/lucianodiisouza/grau/releases/tag/v0.3.0-beta.2
[0.4.0-beta.3]: https://github.com/lucianodiisouza/grau/releases/tag/v0.4.0-beta.3

## [0.3.0-beta.2] — 2026-07-26

Public beta. The second feature (app uninstaller) is end-to-end
functional. Grau scans `/Applications`, `/Applications/Utilities`, and
`~/Applications`, lists every user-installed app, shows its residual
data in `~/Library` (preferences, caches, app support, logs, saved
state, cookies, containers, group containers, launch agents), and
lets the user pick which residuals to clean up alongside the app
bundle itself. System apps (`com.apple.*`) are blocked unless the
user enables Dev Mode in Settings.

### graucore
- **`Uninstaller/InstalledApp`** — struct (no `architecture` field
  per the review). `isAppleSystemComponent` computed.
- **`Uninstaller/BundleMetadata`** / `BundleMetadataLoader` —
  defensive Info.plist parser; reads
  `com.apple.security.application-groups`.
- **`Uninstaller/AppScanner`** — `actor`; walks the standard
  install dirs; skips `/System/Applications`; dedupes by bundle ID.
- **`Uninstaller/ResidualKind`** — 9 kinds (NO `keychainEntries`
  per the review). `mayContainUserData` + `defaultSelected`
  per kind.
- **`Uninstaller/Residual`** — struct.
- **`Uninstaller/ResidualFinder`** — `actor`. Group containers
  looked up via the app's actual `application-groups` entitlement
  (not derived from bundle ID per the review).
- **`Uninstaller/UninstallPlan`** / `Uninstaller` — build plan,
  validate (`systemApp` / `appRunning` errors), execute via
  `TrashMover` with kind `uninstall`.

Test count: **81** tests, all green.

### grau
- **`Uninstaller/UninstallerViewModel`** — `Phase` enum; `scan`,
  `selectApp`, `startUninstall`, `confirmUninstall`, `dismissCompleted`.
- **`Uninstaller/UninstallerView`** — `HSplitView` (app list left,
  detail right). Per-residual row with kind pill. Confirm sheet
  with original path. Success sheet. System apps blocked (unless
  Dev Mode is on).
- **`DesignSystem/Components/DestructiveButton`** — filled
  danger-tone button for destructive actions.

### Documentation
- `docs/MANUAL-TEST.md` updated with the full Phase 2 checklist.
- `CHANGELOG.md` — this entry.

### Build
- `cd graucore && swift test` — 81/81 ✓
- `xcodebuild -scheme grau -configuration Debug build` — ✓
- `xcodebuild -scheme grau -configuration Release build` — ✓

### Known limitations
- Running-app detection uses `NSWorkspace.runningApplications` and
  is best-effort. A malicious app could fork-and-exit fast enough
  to avoid detection; this is acceptable for the use case.
- Containers and group containers default to NOT selected in
  the UI to prevent accidental loss of sandboxed data.

[Unreleased]: # (HEAD)
[0.1.0-alpha]: https://github.com/lucianodiisouza/grau/releases/tag/v0.1.0-alpha
[0.2.0-beta.1]: https://github.com/lucianodiisouza/grau/releases/tag/v0.2.0-beta.1
[0.3.0-beta.2]: https://github.com/lucianodiisouza/grau/releases/tag/v0.3.0-beta.2

## [0.2.0-beta.1] — 2026-07-26

Public beta. The first feature (junk cleaner) is end-to-end functional.
The app reads caches, logs, downloads, and iOS backups; lets the user
select what to clean; moves the items to the Trash with manifests;
and persists a SizeCache for sub-2s subsequent scans.

### graucore (logic)
- **`Primitives/ByteSize`** — Int64-backed size with human-readable
  and compact labels; `+` and `+=` operators; `ExpressibleByIntegerLiteral`.
- **`FS/FileSystemScanner`** — `struct`, AsyncStream walker with
  cancellation, pluggable `PathExclusionsProvider`.
- **`FS/DirectorySizer`** — `struct`, parallel size with hardlink
  dedupe inline (no separate `HardlinkChecker` file).
- **`FS/PathExclusions`** — standard exclusion set (audited
  2026-07-26), apple-component matcher.
- **`FS/TrashMover`** — the only module that performs destructive IO;
  uses `FileManager.trashItem` (not `NSWorkspace.dispose`).
- **`FS/ManifestStore`** — JSON read/write for `~/.grau/state.json`
  and `size-cache.json`.
- **`Permissions/PermissionChecker`** — `actor` with FDA heuristic
  probe of `/Library/Application Support/com.apple.TCC`.
- **`Volume/VolumeInfo`** / **`VolumeMonitor`** — uses
  `FileManager.mountedVolumeURLs(...)` (NOT `/Volumes` walk).
- **`Volume/TrashInfo`** / **`TrashInfoReader`** — symlink-resolving
  cap-10k walk.
- **`Junk/JunkCategory`** — 5 categories per the review.
- **`Junk/JunkDefinition`** / **`JunkDefinitions.standard`** — 5
  definitions, 3 default-on / 2 default-off.
- **`Junk/JunkResult`** / **`JunkItem`** — scan output types.
- **`Junk/SizeCache`** — mtime-keyed cache; sub-2s subsequent scans.
- **`Junk/JunkScanner`** — `actor` with FDA-aware skip + cache
  integration.
- **`Junk/JunkCleaner`** — `struct`, calls `TrashMover` with the
  selected results.

Test count: **70** tests, all green.

### grau (app)
- **`AppViewModel`** — top-level `@MainActor @Observable` with
  `hasOnboarded`, `devModeEnabled`, `downloadsThresholdDays` (all
  in UserDefaults).
- **`grauApp`** — three scenes (MenuBarExtra, main Window,
  Settings Window); on first launch shows Onboarding instead of
  dashboard.
- **Clean tab** (`JunkCleanerView` + `JunkCleanerViewModel`) — 5
  category rows with toggles, confirm sheet, success sheet,
  manual refresh.
- **Onboarding** (`OnboardingView`) — 3-screen first-launch tour.
- **FDA primer** (`PermissionPrimerView` +
  `PermissionCoordinator`) — 3-step primer with polling re-check.
- **Menu bar** (`MenuBarContentView` + `MenuBarState`) — 320pt
  popover with storage, trash, quick actions, version.
- **Settings** (`SettingsView`) — Privacy / Developer / About tabs.
- **Notifications** (`NotificationCoordinator`) — 3 rules
  (`junk.gt1gb`, `disk.full.90`, `trash.full.5gb`) with
  state-transition dedupe per the review.

### Documentation
- `docs/MANUAL-TEST.md` updated with the full Phase 1 checklist.
- `docs/REVIEW.md` corrections applied throughout (see Reviewer's
  list of B1–B8 and S1–S13).
- `docs/PATH-AUDIT-2026-07-26.md` — see audit results.

### Build
- `cd graucore && swift test` — 70/70 ✓
- `xcodebuild -scheme grau -configuration Debug build` — ✓
- `xcodebuild -scheme grau -configuration Release build` — ✓
- App bundle: `LSUIElement = true`, bundle ID `app.grau.mac`,
  min macOS 14.0
- App launches and runs (no Dock icon, menu bar item appears).

### Known limitations
- The menu bar icon is the default `circle.fill` (no custom
  monogram yet — see Phase 6a).
- Notifications require the user to grant authorization on
  first launch; the request is sent but the in-app toggle
  for per-rule enable/disable is deferred to v1.1.
- NotificationCoordinator is instantiated at app level but
  not auto-started; that lands in v1.1 with the 6h background
  tick lifecycle (we don't want to background-tick a menu-bar
  app that hasn't been launched yet).

[Unreleased]: # (HEAD)
[0.1.0-alpha]: https://github.com/lucianodiisouza/grau/releases/tag/v0.1.0-alpha
[0.2.0-beta.1]: https://github.com/lucianodiisouza/grau/releases/tag/v0.2.0-beta.1

## [0.1.0-alpha] — 2026-07-26

The first commit. Grau runs as a menu-bar app, the design system
is in place, the path audit is done, CI is green, and the project
is ready for Phase 1 (Junk cleaner).

### Added
- **Project scaffolding.** Xcode project generated by XcodeGen
  from `project.yml`. App bundle ID `app.grau.mac`. macOS 14
  deployment target. Hardened runtime on, no sandbox.
- **`graucore` Swift Package.** All 41 source files for the
  per-phase engines, plus 21 test files. Every module has a
  TODO(Phase N) pointer and a placeholder namespace; real
  implementation lands per the [TASKS.md](./docs/TASKS.md)
  plan. `swift test` runs 21 placeholder tests, all green.
- **Design system.** 12 color tokens (light + dark variants),
  9-point spacing scale on a 4-pt grid, 4 corner-radius tiers.
  Components: `CardView`, `PrimaryButton`, `SecondaryButton`,
  `Pill`, `EmptyStateView`, `ErrorStateView`, `StorageBar`.
  Every component has a `#Preview`.
- **App skeleton.** Three scenes: `MenuBarExtra` (popover,
  always present), main `Window` (NavigationSplitView with
  sidebar of `AppSection`s and a detail pane), `Settings`
  `Window`. Top-level `@MainActor @Observable` `AppViewModel`
  with `selectedSection`, `hasOnboarded`, `devModeEnabled`
  (UserDefaults-backed).
- **Dashboard skeleton.** Greeting, storage card (with fake
  data, will go live in Phase 1), trash card, last-scan
  card, quick actions row. All cards use `CardView` from
  the design system.
- **9 feature view stubs** (Clean, Uninstaller, Disk Lens,
  Duplicates, Dev Mode, Settings, Onboarding, Permission
  Primer, Notification Coordinator) — each renders an
  `EmptyStateView` pointing to its phase in `TASKS.md`.
- **Dev mode visibility toggle** (per `REVIEW.md` S9): the
  "Dev Mode" sidebar item is hidden unless the user enables
  "Show developer features" in Settings. Default: hidden.
- **Manual test plan** (`docs/MANUAL-TEST.md`) with the full
  Phase 0 checklist filled in and placeholders for each later
  phase.
- **CI workflow** (`.github/workflows/ci.yml`) with three jobs
  on macos-14: graucore tests, app Debug build, app Release
  build. SwiftPM artifacts cached by `Package.swift` hash.
  Runs on push to main, PRs to main, and manual dispatch.
- **macOS path audit** (`docs/PATH-AUDIT-2026-07-26.md`):
  verified every path in `DATA-SOURCES.md` against a real
  macOS 26.5.2 host. Confirmed `com.apple.kext.caches` is
  gone (kexts deprecated since 10.15) and needs to be
  removed from the future `PathExclusions.swift`. Confirmed
  the iCloud daemon cache (`com.apple.bird`) exists and
  must stay excluded. All other paths validated.

### Documentation
- `docs/README.md` — orientation
- `docs/PLAN.md` — vision, scope, decisions, 5-slice plan
- `docs/ARCHITECTURE.md` — components, data model, concurrency
- `docs/DATA-SOURCES.md` — every path Grau touches
- `docs/PERMISSIONS.md` — Full Disk Access story
- `docs/DESIGN.md` — visual language
- `docs/HANDOFF.md` — implementation guide
- `docs/TASKS.md` — project tracker (8 epics, 61 tasks)
- `docs/REVIEW.md` — staff-eng review that corrected the plan
- `docs/archive/macapps-plan/` — the original
  outdated-app-detector plan that seeded this project

### Notes for the next iteration
- The path audit should be re-run on a clean macOS 14.x
  machine before the first beta tag (this audit ran on
  macOS 26.5.2; behavior is forward-compatible but a
  clean-OS check is the standard).
- Apple Intelligence cache paths remain unknown; tracked
  for v1.1 in `PLAN.md` § 11.1.

[Unreleased]: # (HEAD)
[0.1.0-alpha]: https://github.com/lucianodiisouza/grau/releases/tag/v0.1.0-alpha
