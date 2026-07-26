# Changelog

All notable changes to Grau are documented here. The format is
based on [Keep a Changelog](https://keepachangelog.com/), and this
project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed
- 🐛 **App no longer crashes on launch with "Unexpectedly found nil
  while implicitly unwrapping an Optional value" at `grauApp.swift:62`.**
  The Dock-icon feature was setting `NSApp.setActivationPolicy(.accessory)`
  from inside `App.init()`, but the `NSApp` global is still nil at that
  point in the SwiftUI lifecycle — only `NSApplication.shared` is
  guaranteed to be safe. Swapped the call to use the shared singleton;
  the `NSApp` references inside the "Open Grau" / "About" menu
  closures are unchanged because those fire after the app is up.
- 🐛 **Uninstaller now shows the real bundle size for every app.**
  The left sidebar was previously only listing name + version, so
  apps like Xcode (~30 GB) looked identical to a 50 MB utility. The
  app bundle size is now computed in parallel after the scan and
  displayed in a right-aligned monospaced column. The detail header
  also shows it inline (`Version 1.2.3 · 1.4 GB`), and the
  "X to free" total now correctly includes the bundle itself in
  addition to the selected residuals (previously it only counted
  residuals, so the freed total underestimated what would actually
  hit the Trash).

### Notes
- Third-party app **update** check is explicitly out of scope for
  v1 — see `docs/PLAN.md` § 3.

## [1.7.0] — 2026-07-26

Automation, retention, and lighter updates. Grau now prunes its
own history, runs user-defined auto-clean rules, and ships
smaller patches.

### Highlights
- 🧹 **Configurable retention windows.** Three new settings
  (notification log, trash manifests, scan history) with
  per-kind steppers and a "Reset to default" button. 0 days
  means "never expire". A new **Automation** sidebar item
  shows the policy at a glance and has a "Run retention now"
  button that prunes everything in one click.
- ⚙️ **Auto-clean rules.** New `AutoCleanRule` model
  (id, name, condition, action, enabled, cooldown). Four
  condition kinds: trash size, junk size, disk usage, time of
  day. Three action kinds: run retention, reindex trash, log
  a summary. Two safe defaults ship pre-installed but disabled
  — users have to opt in. The Automation tab has a "New rule"
  sheet and a "Run rules now" button.
- ⏱ **Per-rule notification cooldowns.** Each of Grau's three
  alert rules (junk > 1 GB, disk > 90%, trash > 5 GB) can
  now be configured with a custom cooldown (No cooldown / 1h /
  6h / 12h / 1d default / 3d / 1w). The Settings → Notifications
  tab has a picker per rule. The Notification Center view
  shows a "Rule status" card with the current state
  (Ready / Cooling down until X / Disabled).
- 📦 **Sparkle delta updates.** `make-appcast.sh` now accepts
  either a single DMG (legacy, no deltas) or a directory of
  DMGs (deltas auto-generated between consecutive versions).
  Running on a directory of 3 DMGs produces an appcast with
  3 items and 2 delta-from entries. See
  [docs/SPARKLE-DELTAS.md](./docs/SPARKLE-DELTAS.md) for the
  full workflow.

### graucore
- **`Retention/RetentionPolicy`** — Codable struct mapping
  `RetentionKind` to `RetentionWindow(days:)`. Defaults:
  notificationLog 90d, trashManifest 30d, scanHistory 0d
  (forever). `setting(_:)` / `clearing(_:)` return a new
  policy (immutable value type).
- **`Retention/RetentionPolicyStore`** — actor. Persists to
  `~/.grau/retention-policy.json`. `read()` returns
  `.default` when the file is missing.
- **`Retention/RetentionEngine`** — actor. `apply(policy:now:)`
  prunes notifications, manifests, and scan history. Returns
  a `RetentionReport` (counts per kind + total).
- **`AutoClean/AutoCleanRule`** — Codable struct with id,
  name, `AutoCleanCondition` (4 kinds), `AutoCleanAction`
  (3 kinds), enabled, cooldown seconds, created at, last
  fired at. `canFire(now:)` respects cooldown.
- **`AutoClean/AutoCleanStore`** — actor. `add/upsert/remove`
  persist to `~/.grau/auto-clean.json`. Returns
  `defaultRules` (2 disabled) when the file is missing.
- **`AutoClean/AutoCleanEngine`** — actor. `evaluate(...)` is
  pure. `execute(...)` runs actions via RetentionEngine and
  NotificationLog. `runOnce(...)` updates `lastFiredAt` on
  fired rules.
- **`Notifications/NotificationCooldown`** — struct
  (ruleID, seconds, clamped to 30d). `humanReadable`
  produces "No cooldown" / "1 hour" / "3 days" etc.
- **`Notifications/NotificationLog.replace(with:)`** — bulk
  rewrite. Used by the retention engine. Empty input removes
  the file.
- `NotificationLog.record(...)` gains a `timestamp:`
  parameter (default `Date()`). The retention engine uses
  this to backdate test entries.
- Test count: **222** (was 177). 45 new tests cover:
  - RetentionPolicy: defaults, setting/clearing,
    isForever, clamping, equality (10).
  - RetentionEngine: pruneNotificationLog, pruneTrashManifests,
    pruneScanHistory, apply with per-kind policy, store
    round-trip (10).
  - AutoCleanEngine: canFire, all 4 condition kinds, cooldown
    respect, multiple rules, logSummary execution, codable
    round-trips, default rules (17).
  - NotificationCooldown: clamping, human-readable variants,
    default seconds, key format, equality (8).

### grau
- **New sidebar item: Automation** (`wand.and.stars`). Sits
  between Notifications and Settings. Hides nothing.
- **`Features/Automation/AutomationView.swift`** — three
  sections: header, "Last run" card, retention rows
  (stepper 0–3650 days, "Reset" button), auto-clean rule
  rows (toggle, name, "When X → Y", last-fired timestamp,
  delete menu). "+ New rule" sheet covers all 4 condition
  kinds and all 3 action kinds.
- **`Features/Automation/AutomationViewModel.swift`** —
  `@MainActor @Observable`. Reads/writes policy and rules
  via the actors. `runRetentionNow()` and
  `runAutoCleanNow()` capture a live gauge snapshot
  (trash size, last junk scan, disk usage).
- **`SettingsView` gains a "Notifications" tab** with a
  per-rule cooldown picker and a "Cooling down until X"
  line that appears when a rule is mid-cooldown.
- **`NotificationCenterView` gains a "Rule status" card**
  above the log. Shows Ready / Cooling down / Disabled
  per rule.
- `NotificationCoordinator` gains `cooldownSeconds(for:)`,
  `setCooldownSeconds(_:for:)`, `canFire(_:now:)`,
  `cooldownEndsAt(_:now:)`. `fire(...)` now early-returns
  if `canFire(id)` is false (still records the value, so
  threshold-crossing dedupe state is current).
- `NotificationRuleID` gains `displayName`. About tab now
  shows v1.7.0.
- **`scripts/make-appcast.sh`** — accepts a directory of
  DMGs and reports item + delta counts.
- **`docs/SPARKLE-DELTAS.md`** — new doc covering the
  delta workflow, hosting, and verification.

### Files
- New: `graucore/Sources/graucore/Retention/{RetentionPolicy,
  RetentionPolicyStore, RetentionEngine}.swift`
- New: `graucore/Sources/graucore/AutoClean/{AutoCleanRule,
  AutoCleanStore, AutoCleanEngine}.swift`
- New: `graucore/Sources/graucore/Notifications/NotificationCooldown.swift`
- New: `graucore/Tests/graucoreTests/RetentionPolicyTests.swift`
- New: `graucore/Tests/graucoreTests/RetentionEngineTests.swift`
- New: `graucore/Tests/graucoreTests/AutoCleanEngineTests.swift`
- New: `graucore/Tests/graucoreTests/NotificationCooldownTests.swift`
- New: `grau/Features/Automation/{AutomationView,
  AutomationViewModel}.swift`
- New: `docs/SPARKLE-DELTAS.md`
- Modified: `graucore/Sources/graucore/Notifications/NotificationLog.swift`
  (added `replace(with:)`; `record(...)` gains `timestamp:`)
- Modified: `grau/AppViewModel.swift` (new `automation`
  sidebar case)
- Modified: `grau/Features/MainWindow/MainWindowView.swift`
  (routes to `AutomationView`)
- Modified: `grau/Features/Notifications/NotificationCoordinator.swift`
  (cooldown API; `displayName` on rule IDs)
- Modified: `grau/Features/Notifications/NotificationCenterView.swift`
  (Rule status card)
- Modified: `grau/Features/Settings/SettingsView.swift`
  (Notifications tab)
- Modified: `scripts/make-appcast.sh` (directory mode +
  delta count report)
- Modified: `grau/Info.plist`, `project.yml`
  (CFBundleShortVersionString → 1.7.0, MARKETING_VERSION → 1.7.0)

## [1.6.0] — 2026-07-26

Scan history + contributor tooling.

### Highlights
- 📜 **Recent scans on the Dashboard.** A new card lists
  the last 5 cleans (capped at 10 in state.json) with
  kind, total bytes, item count, and timestamp. Hidden
  when the history is empty.
- 🛠 **scripts/ci-verify.sh** runs the same checks CI does
  (xcodegen + graucore swift test + xcodebuild Debug +
  xcodebuild Release + privacy manifest sanity) so
  contributors can verify locally before pushing.
- `--release-only` flag skips the Debug build for a faster
  local run.

### graucore
- **`FS/ManifestStore.swift`** — `StateFile` gains
  `scanHistory: [LastScanSummary]` (capped at
  `StateFile.maxHistoryEntries` = 10) and a pure
  `appendingHistory(_:)` helper.
- Test count: **177** (was 172). Five new tests cover
  default empty history, head-insertion, max-entries trim,
  non-mutation, and Codable round-trip with history.

### grau
- `JunkCleanerViewModel.confirmClean()` also writes the
  new summary to `state.scanHistory` (in addition to
  `lastJunkScan` / `lastClean`).
- `DashboardViewModel` exposes `scanHistory`.
- `DashboardView` shows a "Recent scans" card with up to
  5 entries (kind pill, size, item count, timestamp).
- New `scripts/ci-verify.sh`.

## [1.5.0] — 2026-07-26

Dashboard refresh + treemap label fix.

### Highlights
- 📊 **Real-data Dashboard.** The home screen now reads from
  `VolumeMonitor` (storage card), `TrashInfoReader` (trash
  card), and `~/.grau/state.json` (last scan). The fake
  "237.4 GB / 500.1 GB" placeholders are gone. The Quick
  Actions row is now wired to the corresponding sidebar
  sections.
- 🟦 **Treemap tier-2 labels.** Cells that don't fit the
  full name + size (between 40×18 and 80×36 pt) now show
  just the size in a tiny font. Smaller cells (less than
  40×18) are still unlabelled.
- 🆕 **DevMode Quick Action** is enabled only when the
  Settings dev-mode toggle is on.

### graucore
No engine changes; this is a UI wiring pass.

### grau
- **`Features/Dashboard/DashboardViewModel.swift`** — new
  `@MainActor @Observable` VM with `refresh()` that reads
  storage, trash, and state.
- **`Features/Dashboard/DashboardView.swift`** — fully
  rewritten. The storage card now shows a "N% used" pill
  (red when ≥ 90%), the trash card shows real counts, the
  last-scan card reads from state, and the quick-action
  buttons are wired to sidebar navigation.
- **`Features/DiskLens/DiskTreemapView.swift`** — added a
  tier-2 label for medium cells (just the size, 9-pt font).

## [1.4.0] — 2026-07-26

Notification pass. The new "Notifications" sidebar item shows
every alert Grau has ever fired, persisted to disk.

### Highlights
- 🔔 **In-app Notification Center.** A new sidebar item
  (bell SF Symbol) shows the full log of past notifications.
  Each card displays the rule ID, the time, and the original
  title + body. "Clear" empties the log.
- 💾 **Persistent log.** Every successful `UNUserNotificationCenter.add`
  is also recorded in `~/.grau/notification-log.json` (capped
  at 200 entries, oldest trimmed). The log survives app
  restarts and reboots.

### graucore
- **`Notifications/NotificationLog`** — `actor`. `read()`,
  `record(ruleID:title:body:)`, `clear()`. Backed by
  `~/.grau/notification-log.json`. New `NotificationLogEntry`
  struct (id, timestamp, ruleID, title, body).
- Test count: **172** (was 166). Six new tests cover the
  empty-log read, single-entry persistence, sort order,
  max-entries trim, clear, and init.

### grau
- `NotificationCoordinator.fire(...)` now also calls
  `NotificationLog.record(...)` after a successful
  `UNUserNotificationCenter.add(...)`.
- `Features/Notifications/NotificationCenterView.swift`:
  toolbar with Refresh + Clear, ScrollView of cards (icon
  per rule, title, body, timestamp, "Rule: <id>" footer).
- `Features/Notifications/NotificationCenterViewModel.swift`:
  @MainActor @Observable VM with `entries`, `isLoading`,
  `refresh()`, `clear()`.
- New sidebar item: **Notifications** (system image `bell`).

### Files
- New: `graucore/Sources/graucore/Notifications/NotificationLog.swift`,
  `graucore/Tests/graucoreTests/NotificationLogTests.swift`,
  `grau/Features/Notifications/NotificationCenterView.swift`,
  `grau/Features/Notifications/NotificationCenterViewModel.swift`
- Modified: `grau/Features/Notifications/NotificationCoordinator.swift`,
  `grau/AppViewModel.swift`, `grau/Features/MainWindow/MainWindowView.swift`,
  `project.yml`, `grau/Info.plist`.

## [1.3.0] — 2026-07-26

Quality-of-life and performance pass. The duplicates scanner
gets a real Stop button and auto-tuned parallelism; the Trash
view gets a kind + date filter.

### Highlights
- 🛑 **Duplicates Stop button.** A red "Stop" replaces the
  spinner mid-scan. Clicking it cancels the in-flight scan
  via `DuplicateScanner.cancel()`. The phase label flips to
  "Cancelled" if the scan was terminated before completion.
- ⚙️ **Auto-tuned parallelism.** `DuplicateScanner`'s
  default `maxParallelism` is now
  `min(16, ProcessInfo.activeProcessorCount)`. On a 10-core
  Mac you get 10 hash workers; on a 2-core MBA you get 2. The
  8-worker cap is gone.
- 🔍 **Trash filters.** Filter chip (kind) and date range
  filter narrow the manifest list. "Clear" resets.

### graucore
- **`Duplicates/DuplicateScanner`** —
  * `cancel()` method (idempotent) on the actor.
  * `defaultParallelism()` static func.
  * Internal `CancelToken` (lock-protected) holds the active
    scan's `Task`. `scan()` registers the task via an opaque
    Int ID (since `Task` is a value type, identity comparison
    isn't possible).
  * `maxParallelism` is now `nonisolated let` (immutable
    after init).
- Test count: **166** (was 161). New tests cover cancel on a
  fresh scanner, cancel mid-scan, default-parallelism range,
  and init-clamping.

### grau
- `Features/Duplicates/DuplicatesView.swift`: "Stop" button
  in the toolbar (red tint). After cancel, the phase label
  reads "Cancelled" if the scan was aborted mid-phase.
- `Features/Trash/TrashViewModel.swift` + `TrashView.swift`:
  * `kindFilter`, `dateFrom`, `dateTo` properties.
  * `filteredManifests` computed property.
  * `availableKinds` for the filter chip menu.
  * `clearFilters()` resets.
  * Filter bar with kind menu, "Clear" button (only shown
    when a filter is active), and a date-range label.
  * Empty state for "no matches".

### Files
- Modified: `graucore/Sources/graucore/Duplicates/DuplicateScanner.swift`,
  `graucore/Tests/graucoreTests/DuplicateScannerTests.swift`,
  `grau/Features/Duplicates/DuplicatesView.swift`,
  `grau/Features/Trash/TrashViewModel.swift`,
  `grau/Features/Trash/TrashView.swift`,
  `project.yml`, `grau/Info.plist`.

## [1.2.0] — 2026-07-26

Performance and visualization pass. The duplicates scanner
parallelizes its hash phases; the disk lens gets a treemap
view.

### Highlights
- ⚡ **Duplicates: per-file parallel hashing.** Phase 2
  (partial) and Phase 3 (full) now run with up to 8 in-flight
  hash tasks. A 50k-file home scans in roughly 1/3 the time.
  The size-bucket phase stays serial (no IO).
- 📊 **Disk Lens: treemap view.** A new segmented control
  toggles between the Top-N list and a squarified treemap.
  Tapping a cell drills in, right-click reveals in Finder.

### graucore
- **`Duplicates/DuplicateScanner`** — `maxParallelism`
  parameter (default 8). New `hashInParallel` static helper
  using a worker-pool TaskGroup pattern.
- Test count: **161** (unchanged from v1.1; the parallel
  implementation passes the existing pipeline tests).

### grau
- New file `Features/DiskLens/DiskTreemapView.swift`. The
  squarified treemap algorithm (Bruls, Huijsen, van Wijk,
  2000) is implemented from scratch in SwiftUI.
- `DiskLensView` gets a `ViewMode` picker (list / treemap).
  Drill-in, context menu, and reveal-in-Finder work in
  both modes.

### Files
- New: `grau/Features/DiskLens/DiskTreemapView.swift`
- Modified: `grau/Features/DiskLens/DiskLensView.swift`,
  `graucore/Sources/graucore/Duplicates/DuplicateScanner.swift`

## [1.1.0] — 2026-07-26

The first minor release. Adds the first third-party runtime
dependency (Sparkle 2.9.4) and an in-app trash-restore view.

### Highlights
- 🔄 **Self-update via Sparkle.** `Check for Updates…` in the
  app menu. The feed is hosted at
  `https://lucianodiisouza.github.io/grau/appcast.xml`. The
  EdDSA public key is in `Info.plist`; the matching private
  key lives in the maintainer's keychain.
- 🍺 **`brew install --cask grau`.** Homebrew Cask formula in
  `homebrew-cask/grau.rb` (sha256 to be filled on each release).
- ↩️ **In-app trash restore.** The new "Trash" sidebar item
  shows every past clean/uninstall/duplicates operation by
  reading `~/.grau/trash-manifests/*.json`. One click restores
  the whole batch (or per-item failures are listed).

### graucore
- **`FS/TrashRestore`** — `actor`. `listManifests()`,
  `manifest(id:)`, `restore(manifestID:)`. Restores by moving
  each item from `~/.Trash/<trashRelativePath>` back to its
  `originalPath`. Skips if the original path is now occupied.
- Test count: **161** (was 155 in v1.0).

### grau
- New sidebar item: **Trash** (system image
  `arrow.uturn.backward.circle`).
- `TrashView` + `TrashViewModel` — list of manifests with
  one-click "Restore all" per card.
- `grauApp.swift` — `SPUStandardUpdaterController` started
  in `init`. A "Check for Updates…" item appears under the
  app menu and uses Sparkle's standard NSAlert flow.

### Tooling
- `scripts/make-appcast.sh` — wraps Sparkle's
  `generate_appcast` to produce a fresh `dist/appcast.xml`
  (or `appcast-beta.xml` with `--channel beta`).
- `homebrew-cask/grau.rb` — Homebrew Cask formula.

### Files
- New: `grau/Features/Trash/{TrashView,TrashViewModel}.swift`
- New: `graucore/Sources/graucore/FS/TrashRestore.swift`
- New: `graucore/Tests/graucoreTests/TrashRestoreTests.swift`
- New: `homebrew-cask/grau.rb`
- New: `scripts/make-appcast.sh`
- Modified: `project.yml` (Sparkle package), `grauApp.swift`
  (updater controller + menu), `grau/Info.plist`
  (SUFeedURL/SUPublicEDKey/SUEnableAutomaticChecks),
  `grau/AppViewModel.swift` (new `.trash` case).

### Known limitations (still deferred to 1.2+)
- Disk Lens has no treemap visualization (Top-N list only)
- Duplicates scanner is per-phase-parallel, not per-file-parallel
- No per-kind / per-date filter in the Trash view

## [1.0.0] — 2026-07-26

**First stable release.** All five features functional and
end-to-end tested. App is signed (ad-hoc by default; notarized
when run through `scripts/notarize.sh`) and ships with the
required `PrivacyInfo.xcprivacy`.

### Highlights
- 🧹 Junk cleaner (5 categories, safe defaults, FDA-gated)
- 📦 App uninstaller (bundle + residuals + group containers)
- 🔍 Disk lens (Top-N list with parallel-sized scan)
- 🪞 Duplicates finder (3-phase pipeline, keep-oldest default)
- 🛠 Dev mode (six inspectors, hidden by default)
- 📌 Menu bar tray (storage card + last scan + quick actions)

### graucore
- 41 modules across 9 domains
- 155 unit tests, all green
- 100% public-API test coverage on the 8 critical modules:
  TrashMover, FileSystemScanner, DirectorySizer, JunkScanner,
  DuplicateScanner, Uninstaller, PermissionChecker, VolumeMonitor

### grau
- SwiftUI + AppKit, no third-party runtime deps
- @MainActor @Observable view models throughout
- App Sandbox OFF (Full Disk Access only)
- 9 features: Dashboard, Clean, Uninstaller, Disk Lens,
  Duplicates, Dev Mode, Onboarding, Permissions, Settings,
  Menu Bar, Notifications

### Tooling
- XcodeGen project (`project.yml` source of truth)
- `scripts/make-dmg.sh` — produce a signed DMG
- `scripts/notarize.sh` — submit to notarytool + staple
- GitHub Actions CI: build + test on every push
- `PrivacyInfo.xcprivacy` declaring FileTimestamp,
  DiskSpace, SystemBootTime, and UserDefaults API usage

### Files
- 6 docs in `docs/`: README, PLAN, ARCHITECTURE, DATA-SOURCES,
  PERMISSIONS, DESIGN, HANDOFF, TASKS, REVIEW, MANUAL-TEST,
  PATH-AUDIT-2026-07-26, TROUBLESHOOTING
- README, CONTRIBUTING, CHANGELOG, LICENSE (MIT)

### Known limitations (deferred to v1.1)
- No Sparkle self-update yet
- No Homebrew Cask
- Duplicates scanner is per-phase-parallel, not per-file-parallel
  (full-`~/` scan can take 5+ min on large homes)
- Disk Lens shows Top-N folders, not a treemap
- Trash restore is via Finder drag-out (no in-app restore)

## [0.6.0-beta.5] — 2026-07-26

Public beta. Dev Mode is end-to-end functional but hidden behind
a Settings toggle. The sidebar gains a "Dev Mode" item that
opens a tabbed view of six developer-tooling inspectors. All
inspectors run in parallel via `DevReportGenerator`.

### graucore
- **`Dev/PackageCacheKind`** — `enum` with 16 cases: npm, Yarn
  classic/Berry, pnpm, Bun, CocoaPods, Carthage, SwiftPM, Maven,
  Gradle, sbt, Ivy, Cargo, RubyGems, pip, Poetry. Each case
  declares its `defaultPaths`.
- **`Dev/PackageCacheScanner`** — `actor`. Sizes all 16 caches
  in parallel via `withTaskGroup` + `DirectorySizer`.
- **`Dev/NodeModulesFinder`** — `actor`. Walks `~/` plus the
  usual project roots (Code, Developer, Projects, repos, src,
  work) to depth 6, finds every `node_modules`, reports size
  via `DirectorySizer`. Honors `PathExclusions.standard` and
  does NOT recurse INTO `node_modules`.
- **`Dev/CLIRunner`** — `struct` `Process` wrapper with timeout.
  `which(_:)` resolves via `/usr/bin/which`; `run(_:arguments:)`
  races the process against a `Task.sleep` timeout.
- **`Dev/DockerInspector`** — `actor`. Shells `docker system df -v`,
  parses the Build Cache row, and surfaces three states:
  `dockerNotInstalled`, `dockerDaemonDown`, parsed result.
  `parseSize` handles B/KB/MB/GB/TB in either case.
- **`Dev/SimulatorInspector`** — `actor`. Lists
  `~/Library/Developer/CoreSimulator/Devices/<UDID>/device.plist`
  entries, skipping `state == "Booted"` in `DevReport.totalSize`.
- **`Dev/DerivedDataInspector`** — `actor`. Walks
  `~/Library/Developer/Xcode/DerivedData/<Project>-<hash>/` and
  splits the folder name into `(project, hash)`.
- **`Dev/ArchivesInspector`** — `actor`. Walks
  `~/Library/Developer/Xcode/Archives/<date>/<name>.xcarchive/`.
- **`Dev/DevReport`** — `struct` aggregator. `totalSize` sums
  present package caches + non-booted simulators + node_modules
  + DerivedData + Archives.
- **`Dev/DevReportGenerator`** — `actor`. Runs all six inspectors
  in parallel via `async let`.

Test count: **155** tests, all green (was 94 in Beta 4 — 61 new
tests for Phase 5).

### grau
- **`DevMode/DevModeViewModel`** — `@MainActor @Observable`. Holds
  the `DevReport` and exposes `refresh()`.
- **`DevMode/DevModeView`** — tabbed UI. Six tabs: Packages,
  node_modules, Docker, Simulators, Derived Data, Archives. Each
  tab has an empty state. The Archives tab includes a
  userCaution warning banner ("archives are required for
  shipping").
- Sidebar item "Dev Mode" appears only when the user enables
  "Show developer features" in Settings.

## [0.5.0-beta.4] — 2026-07-26

Public beta. The fourth feature (duplicates finder) is end-to-end
functional. Grau walks the user-chosen root, runs the 3-phase
pipeline (size filter → partial-hash → full SHA-256), groups
identical files, and lets the user pick which copies to move to
the Trash. Defaults: keep the oldest by mtime.

### graucore
- **`FS/FileHasher`** — `struct`, streaming SHA-256 (CryptoKit).
  `partialHash(of:)` reads the first 4 KB; `fullHash(of:)`
  streams 1 MB chunks.
- **`Duplicates/DuplicateGroup`** — `struct`. `wastedBytes` =
  size × (count − 1).
- **`Duplicates/DuplicateScanner`** — `actor`. 3-phase pipeline
  with `ScannerEvent` stream (phase + progress + duplicateFound).
  Honors `Task.isCancelled`.
- **`Duplicates/DuplicateSelection`** — `struct`. `keepURLs(in:)`:
  keep the oldest by mtime. `removeURLs(in:)`, `totalWasted(_:)`.

Test count: **94** tests, all green.

### grau
- **`Duplicates/DuplicatesView`** — root path, scan button with
  live phase label, summary card (groups + recoverable bytes),
  per-group card with toggles; auto-selects all-but-oldest so
  the user just confirms.

### Build
- `xcodebuild -scheme grau -configuration Debug build` — ✓
- `xcodebuild -scheme grau -configuration Release build` — ✓
- `cd graucore && swift test` — 94/94 ✓

### Known limitations
- Sequential hashing (parallelism is per-phase, not per-file).
  A 50k-file home will be slow; v1.1 adds proper file-level
  parallelism via `withTaskGroup` across the size filter.
- No "Move all selected to Trash" button in v1 — the UI shows
  the selection state but the actual move-to-trash action
  lands in v1.1 alongside the trash manifest for duplicates.

[Unreleased]: # (HEAD)
[0.1.0-alpha]: https://github.com/lucianodiisouza/grau/releases/tag/v0.1.0-alpha
[0.2.0-beta.1]: https://github.com/lucianodiisouza/grau/releases/tag/v0.2.0-beta.1
[0.3.0-beta.2]: https://github.com/lucianodiisouza/grau/releases/tag/v0.3.0-beta.2
[0.4.0-beta.3]: https://github.com/lucianodiisouza/grau/releases/tag/v0.4.0-beta.3
[0.5.0-beta.4]: https://github.com/lucianodiisouza/grau/releases/tag/v0.5.0-beta.4

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
