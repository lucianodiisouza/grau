# TASKS — Grau project plan

This is the **project tracker view** of the Grau plan. Each Phase is
an Epic. Each task has an ID `<phase>.<n>`, sub-tasks that map to
PR-sized work, file paths, and explicit acceptance criteria.

**This is not the implementation guide.** [HANDOFF.md](./HANDOFF.md) is.
When a task says "see HANDOFF § X.Y", go to HANDOFF for the detailed
build steps; this file is for *what* to do, HANDOFF is for *how*.

## Conventions

- **Epic** = one Phase (0–6b). Sums to ~19 wk to 1.0, +1.5 wk to 1.1.
- **Task** = a logically grouped unit of work, typically 0.5–2 days.
  Mapped to one GitHub Issue / Linear ticket.
- **Sub-task** = a single PR. Has a checkbox here for tracking.
- **AC** = acceptance criteria. The task is "done" when all checkboxes
  under AC are true.
- **Critical-modules coverage** = 100% public-API tests on the 8
  in-scope modules (see [ARCHITECTURE.md § 5.1](./ARCHITECTURE.md#51-test-coverage-target)).
  A task is "done" only if its critical-module tests pass.
- **CI** must stay green throughout. Any task that breaks CI is
  reverted immediately.

## Status legend

- [ ] = not started
- [~] = in progress
- [x] = done

## Epics at a glance

| Epic | Weeks | Tag | Public release |
| --- | --- | --- | --- |
| 0 — Scaffold | 1.5 | `v0.1.0-alpha` | No (internal only) |
| 1 — Junk + tray | 4 | `v0.2.0-beta.1` | Yes (public beta) |
| 2 — Uninstaller | 3 | `v0.3.0-beta.2` | Yes (public beta) |
| 3 — Disk lens | 2 | `v0.4.0-beta.3` | Yes (public beta) |
| 4 — Duplicates | 2.5 | `v0.5.0-beta.4` | Yes (public beta) |
| 5 — Dev mode | 4 | `v0.6.0-beta.5` | Yes (public beta) |
| 6a — Polish pt 1 | 1.5 | `v1.0.0` | **Yes (1.0 launch)** |
| 6b — Polish pt 2 | 1.5 | `v1.1.0` | Yes (1.1 launch) |

**Total: ~19 wk to 1.0, +1.5 wk to 1.1 (~20.5 wk overall).**

---

## Epic 0 — Scaffold (1.5 weeks)

> Goal: an Xcode project that builds, runs, shows a menu bar icon,
> opens a dashboard with empty feature placeholders, has the design
> system in place, has CI green, and has a macOS 14 path audit
> committed. The app is *recognizable* as Grau.

### Task 0.1 — Repo setup and rename

- [ ] Rename folder `macapps` → `grau` (the project is Grau, not macapps)
- [ ] `git init` at the new `grau/` root
- [ ] `.gitignore` for Swift/macOS (build/, DerivedData/, .swiftpm/, .DS_Store, `*.swp`)
- [ ] `LICENSE` (MIT) at repo root
- [ ] `README.md` at repo root
- [ ] Push to private GitHub repo

**Files:** `.gitignore`, `LICENSE`, `README.md`
**AC:** `git log` shows the initial commit; remote is set; `LICENSE` is MIT.

### Task 0.2 — Xcode project

- [ ] Install xcodegen via `brew install xcodegen`
- [ ] Write `project.yml` (HANDOFF § 0.2)
- [ ] Write `grau/grau.entitlements` (FDA off, network on, user-selected on)
- [ ] `xcodegen generate`
- [ ] `xcodebuild -scheme grau -configuration Debug build` succeeds
- [ ] `xcodebuild -scheme grau -configuration Release build` succeeds

**Files:** `project.yml`, `grau/grau.entitlements`, `grau.xcodeproj/`
**AC:** Xcode opens the project; both Debug and Release build clean.

### Task 0.3 — `graucore` Swift Package

- [ ] `mkdir graucore/`
- [ ] `graucore/Package.swift` with macOS 14 platform, single target
- [ ] Empty source files for every module listed in
      [ARCHITECTURE.md § 4](./ARCHITECTURE.md#4-graucore-module-structure),
      each with a `// TODO: Phase N` placeholder
- [ ] `cd graucore && swift build` succeeds
- [ ] `cd graucore && swift test` passes (all tests empty)

**Files:** `graucore/Package.swift`, `graucore/Sources/graucore/**/*.swift`,
`graucore/Tests/graucoreTests/**/*.swift`
**AC:** Package builds and tests pass.

### Task 0.4 — Design system

- [ ] `grau/DesignSystem/Colors/GrauColors.xcassets/` with all 12 tokens
      (gray scale 50-900 + accent + accentMuted, light + dark)
- [ ] `grau/DesignSystem/Spacing/Spacing.swift` with 9 spacing tokens
- [ ] `CardView.swift`, `PrimaryButton.swift`, `SecondaryButton.swift`,
      `Pill.swift`, `EmptyStateView.swift`, `ErrorStateView.swift`,
      `StorageBar.swift`
- [ ] Verify dark mode: `defaults write -g AppleInterfaceStyle Dark`
      → app colors flip

**Files:** `grau/DesignSystem/**/*.swift`
**AC:** All components render correctly in light + dark mode.

### Task 0.5 — App skeleton

- [ ] `grau/grauApp.swift` (HANDOFF § 0.4) with MenuBarExtra + 2 Windows
- [ ] `grau/AppViewModel.swift`: empty `@MainActor @Observable`
- [ ] Stub feature views: Dashboard, Clean, Uninstaller, Disk Lens,
      Duplicates, Dev Mode, Settings, MenuBar, Onboarding —
      each a `Text("Coming soon")`
- [ ] `grau/Features/MainWindow/MainWindowView.swift` with
      `NavigationSplitView` and 5-item sidebar (Dev Mode hidden by
      default — see [DESIGN.md](./DESIGN.md))

**Files:** `grau/grauApp.swift`, `grau/AppViewModel.swift`,
`grau/Features/**/*.swift`
**AC:** App launches; menu bar icon visible; window opens; sidebar
selections switch views.

### Task 0.6 — Dashboard skeleton

- [ ] `grau/Features/Dashboard/DashboardView.swift` with placeholder
      cards (greeting, storage, trash, last scan, quick actions)
- [ ] All cards use `CardView` from DesignSystem

**Files:** `grau/Features/Dashboard/DashboardView.swift`
**AC:** Dashboard renders with placeholder content; matches the layout
in DESIGN.md § 2.2.

### Task 0.7 — Manual test plan (skeleton)

- [ ] Create `docs/MANUAL-TEST.md` with a stub:
      - [ ] App launches without crash
      - [ ] Menu bar icon appears
      - [ ] No Dock icon
      - [ ] Window opens, dashboard renders
      - [ ] Dark mode adapts
      - [ ] `swift test` passes
      - [ ] (more rows added per phase)
- [ ] Flesh out per phase as features land

**Files:** `docs/MANUAL-TEST.md`
**AC:** Stub exists; each phase adds 3–5 more test rows.

### Task 0.8 — CI

- [ ] Create `.github/workflows/ci.yml`:
      - macos-14 runner
      - `swift test` in `graucore/`
      - `xcodebuild -scheme grau -configuration Debug build`
- [ ] Push the workflow
- [ ] Verify CI goes green on a dummy commit
- [ ] Add the green-CI badge to README

**Files:** `.github/workflows/ci.yml`
**AC:** PR without the build passing cannot be merged (enforce via
GitHub branch protection on `main`).

### Task 0.9 — Path audit (MANDATORY)

> This task exists because the previous draft had stale paths
> (e.g., `com.apple.kext.caches`, which no longer exists on
> macOS 14+). See [REVIEW.md B5](./REVIEW.md#2-correctness-bugs-b1b8).

- [ ] On a live macOS 14 (or 15) machine, walk every path in
      [DATA-SOURCES.md § 1](./DATA-SOURCES.md#1-junk-cleaner-categories)
- [ ] Remove paths that no longer exist
- [ ] Add Apple Intelligence cache paths for macOS 15 if known
      (mark as `userCaution`, not selected by default)
- [ ] Commit the audit with a clear "audited YYYY-MM-DD" message

**Files:** `graucore/Sources/graucore/FS/PathExclusions.swift`,
`graucore/Sources/graucore/Junk/JunkDefinition.swift`,
`docs/DATA-SOURCES.md`
**AC:** All paths verified against live macOS; commit message includes
the audit date.

### Task 0.10 — Phase 0 acceptance

- [ ] `xcodebuild` succeeds for Debug and Release
- [ ] App launches, menu bar visible, dashboard visible, sidebar
      functional, design system in place
- [ ] README, LICENSE on the repo
- [ ] All planned doc files committed in `docs/`
- [ ] CI green on GitHub Actions
- [ ] Path audit committed (Task 0.9)

**Tag:** `v0.1.0-alpha`. No public release.

---

## Epic 1 — Junk cleaner + tray (4 weeks) → Beta 1

> Goal: Grau scans junk across 5 user-facing categories, lets the
> user select and clean (to Trash), and shows live state in the
> menu bar. FDA onboarding works. Manifests are written for every
> clean. Beta 1 is shippable.

### Task 1.1 — FS primitives

- [ ] `FS/ByteSize.swift` with the public API from
      [ARCHITECTURE.md § 6](./ARCHITECTURE.md#61-core-types)
- [ ] `FS/FileSystemScanner.swift`: `struct`, `AsyncStream<URL>` walker,
      cancellation, exclusions
- [ ] `FS/DirectorySizer.swift`: uses scanner + hardlink dedupe inline
- [ ] `FS/PathExclusions.swift`: standard list
- [ ] Tests: `ByteSizeTests`, `FileSystemScannerTests`,
      `DirectorySizerTests`

**Files:** `graucore/Sources/graucore/FS/ByteSize.swift`,
`graucore/Sources/graucore/FS/FileSystemScanner.swift`,
`graucore/Sources/graucore/FS/DirectorySizer.swift`,
`graucore/Sources/graucore/FS/PathExclusions.swift`
**AC:** 100% public-API coverage on `FileSystemScanner` and
`DirectorySizer`. (These are in the 8 critical modules.)

### Task 1.2 — Trash + manifests

- [ ] `FS/TrashMover.swift`: `FileManager.trashItem`,
      writes `TrashManifest`
- [ ] `FS/ManifestStore.swift`: JSON read/write
- [ ] Tests: `TrashMoverTests`, `ManifestStoreTests`

**Files:** `graucore/Sources/graucore/FS/TrashMover.swift`,
`graucore/Sources/graucore/FS/ManifestStore.swift`
**AC:** 100% public-API coverage on `TrashMover`. (In the 8 critical
modules.) `TrashMover` is the only module that performs destructive IO.

### Task 1.3 — Permissions

- [ ] `Permissions/PermissionKind.swift`
- [ ] `Permissions/PermissionChecker.swift`: FDA heuristic using
      `/Library/Application Support/com.apple.TCC`
- [ ] Tests: `PermissionCheckerTests` with mock TCC state

**Files:** `graucore/Sources/graucore/Permissions/*.swift`
**AC:** 100% public-API coverage on `PermissionChecker`. (In the 8
critical modules.)

### Task 1.4 — Volume + trash info

- [ ] `Volume/VolumeInfo.swift`
- [ ] `Volume/VolumeMonitor.swift`: `actor`, uses
      `FileManager.default.mountedVolumeURLs(...)` (NOT `/Volumes/*`)
- [ ] `Volume/TrashInfo.swift`: resolves `~/.Trash` symlinks, capped walk
- [ ] Tests: `VolumeMonitorTests`, `TrashInfoTests`

**Files:** `graucore/Sources/graucore/Volume/*.swift`
**AC:** 100% public-API coverage on `VolumeMonitor`. (In the 8
critical modules.)

### Task 1.5 — Junk model + SizeCache

- [ ] `Junk/JunkCategory.swift`: 5 categories (no mail/browser/trash)
- [ ] `Junk/JunkDefinition.swift`: includes `defaultSelected`
- [ ] `Junk/JunkResult.swift`, `Junk/JunkItem.swift`
- [ ] `Junk/SizeCache.swift`: JSON-backed, mtime-keyed

**Files:** `graucore/Sources/graucore/Junk/*.swift`
**AC:** Compiles; categories match DATA-SOURCES.md § 1.

### Task 1.6 — Junk scanner + cleaner

- [ ] `Junk/JunkScanner.swift`: `actor`, parallel category scan
- [ ] `Junk/JunkCleaner.swift`: `struct`, calls `TrashMover`
- [ ] Tests: `JunkScannerTests` (5 categories + SizeCache + FDA),
      `JunkCleanerTests`, `SizeCacheTests`

**Files:** `graucore/Sources/graucore/Junk/JunkScanner.swift`,
`graucore/Sources/graucore/Junk/JunkCleaner.swift`
**AC:** 100% public-API coverage on `JunkScanner`. (In the 8
critical modules.)

### Task 1.7 — Junk cleaner UI

- [ ] `grau/Features/JunkCleaner/JunkCleanerView.swift`: 5-category
      list, default-selected checkboxes
- [ ] `grau/Features/JunkCleaner/JunkCleanerViewModel.swift`:
      `@MainActor @Observable`
- [ ] Confirm sheet + Success sheet
- [ ] `grau/Features/Dashboard/StorageCardView.swift`: live from
      `VolumeMonitor`, polls every 30s
- [ ] `grau/Features/Dashboard/LastScanCardView.swift`: reads
      `~/.grau/state.json`
- [ ] `grau/Features/Dashboard/QuickActionsView.swift`

**Files:** `grau/Features/JunkCleaner/*.swift`,
`grau/Features/Dashboard/*.swift`
**AC:** End-to-end junk flow works in the app; manifest written on
clean.

### Task 1.8 — Permission primer + coordinator

- [ ] `grau/Features/Permissions/PermissionPrimerView.swift`
      (3-step primer from PERMISSIONS.md § 5)
- [ ] `grau/Features/Permissions/PermissionCoordinator.swift`:
      open-Settings → poll → verify

**Files:** `grau/Features/Permissions/*.swift`
**AC:** FDA grant is detected within 10s of user toggling it on.

### Task 1.9 — Onboarding

- [ ] `grau/Features/Onboarding/OnboardingView.swift`: 3-screen tour
- [ ] First-launch detection: `!UserDefaults.standard.bool(forKey: "grau.onboarded")`
- [ ] "Show me again" toggle in Settings (sets the key back to false)

**Files:** `grau/Features/Onboarding/OnboardingView.swift`,
`grau/Persistence/PreferencesKeys.swift`
**AC:** Onboarding shown only on first launch; reshows on demand.

### Task 1.10 — Settings skeleton

- [ ] `grau/Features/Settings/SettingsView.swift` with Privacy section
- [ ] FDA status display + "Open System Settings" button

**Files:** `grau/Features/Settings/*.swift`
**AC:** Settings opens from menu; FDA status reflects current state.

### Task 1.11 — Menu bar

- [ ] `grau/Features/MenuBar/MenuBarState.swift`: `@MainActor @Observable`
- [ ] `grau/Features/MenuBar/MenuBarContentView.swift`: 320pt popover
- [ ] Menu bar template icon (no color)
- [ ] Red-dot overlay when junk > 1 GB or trash > 5 GB

**Files:** `grau/Features/MenuBar/*.swift`
**AC:** Menu bar popover shows real data; red dot appears on threshold.

### Task 1.12 — Notifications

- [ ] `grau/Features/Notifications/NotificationCoordinator.swift`
- [ ] State-transition dedupe (per PERMISSIONS.md § 3.3.1)
- [ ] UserDefaults keys for per-rule `lastFiredAt` and `lastValue`
- [ ] Authorization request on first launch

**Files:** `grau/Features/Notifications/*.swift`,
`grau/Persistence/PreferencesKeys.swift`
**AC:** Notifications fire on threshold crossing, not on every tick.

### Task 1.13 — Bug-bash week (mandatory)

- [ ] Run `MANUAL-TEST.md` end-to-end
- [ ] Fix anything red
- [ ] CI must stay green throughout
- [ ] If a bug > 0.5 day, file in `docs/BUGS.md` and defer to v1.1

**Files:** various; `docs/BUGS.md` (new)
**AC:** All beta-1 acceptance criteria pass; CI green.

### Task 1.14 — Beta 1 release

- [ ] Take 3 screenshots: dashboard, junk scan results, menu bar popover
- [ ] Update README with screenshots
- [ ] Write `CHANGELOG.md` with `v0.2.0-beta.1` entry
- [ ] `git tag v0.2.0-beta.1 && git push --tags`
- [ ] Publish GitHub Release with notes

**Files:** `README.md`, `CHANGELOG.md`
**AC:** Beta 1 is public on GitHub.

### Phase 1 acceptance (Beta 1)

- [ ] All 5 junk categories scan correctly
- [ ] Cleaning moves files to Trash via `FileManager.trashItem`
- [ ] Manifest written for every clean
- [ ] FDA missing → "limited mode" banner + skipped FDA categories
- [ ] Menu bar popover shows real data
- [ ] Subsequent scan < 2s via SizeCache
- [ ] 100% public-API coverage on the 6 in-scope critical modules
- [ ] Performance: < 10s for first scan on 200GB free

**Tag:** `v0.2.0-beta.1`. Public beta.

---

## Epic 2 — App uninstaller (3 weeks) → Beta 2

> Goal: list installed apps, show residual data, uninstall (trash
> everything). System apps blocked. Running apps surface a clear
> error. No keychain detection (dropped in review).

### Task 2.1 — App scanner

- [ ] `Uninstaller/InstalledApp.swift` (no `architecture` field)
- [ ] `Uninstaller/BundleMetadata.swift`: load `Info.plist`
- [ ] `Uninstaller/AppScanner.swift`: `actor`, walks
      `/Applications`, `~/Applications`, `/Applications/Utilities`
- [ ] Read `com.apple.security.application-groups` from Info.plist
- [ ] Tests: `AppScannerTests` with fixture bundles

**Files:** `graucore/Sources/graucore/Uninstaller/*.swift`
**AC:** Lists all installed user apps; reads entitlements correctly.

### Task 2.2 — Residual finder

- [ ] `Uninstaller/ResidualKind.swift`: 8 kinds, **no `keychainEntries`**
- [ ] `Uninstaller/Residual.swift`
- [ ] `Uninstaller/ResidualFinder.swift`: `actor`
- [ ] `groupContainers` lookup uses the app's actual group identifiers
- [ ] Tests: `ResidualFinderTests`

**Files:** `graucore/Sources/graucore/Uninstaller/Residual*.swift`
**AC:** Detects 8 kinds; uses entitlements (not bundle ID) for
group containers.

### Task 2.3 — Uninstaller engine

- [ ] `Uninstaller/UninstallPlan.swift`
- [ ] `Uninstaller/Uninstaller.swift`: builds plan, calls `TrashMover`
- [ ] Pre-uninstall helper detection: `Contents/Resources/Uninstall.app`
      and `--uninstall` heuristic
- [ ] System app blocking: `bundleID.starts(with: "com.apple.")` blocked
- [ ] Running app detection: `lsof` on the bundle's executables
- [ ] Tests: `UninstallerTests` with plan + trash-by-move (mocked)

**Files:** `graucore/Sources/graucore/Uninstaller/Uninstaller.swift`
**AC:** 100% public-API coverage on `Uninstaller`. (In the 8
critical modules.) System apps blocked. Running apps surface a
"Quit first" error.

### Task 2.4 — Uninstaller UI

- [ ] `grau/Features/Uninstaller/UninstallerView.swift`: app list
      (left) + residual list (right)
- [ ] `grau/Features/Uninstaller/UninstallerViewModel.swift`
- [ ] Confirm sheet: shows pre-uninstall helper prompt if available
- [ ] Success sheet: "Reveal in Trash" + "Done"

**Files:** `grau/Features/Uninstaller/*.swift`
**AC:** End-to-end uninstall works on a real app.

### Task 2.5 — Bug-bash week

- [ ] Run `MANUAL-TEST.md` uninstaller section
- [ ] Try uninstalling a real throwaway app + reinstall
- [ ] Try uninstalling a system app: blocked with clear error
- [ ] Try uninstalling a running app: blocked with "Quit first"

**AC:** All uninstaller acceptance criteria pass.

### Task 2.6 — Beta 2 release

- [ ] Update README with uninstaller screenshot
- [ ] Update CHANGELOG
- [ ] `git tag v0.3.0-beta.2 && git push --tags`

**Tag:** `v0.3.0-beta.2`. Public beta.

---

## Epic 3 — Disk lens (2 weeks) → Beta 3

> Goal: visualize the disk as a **Top-N folders list**, drill down,
> free space safely. (Custom treemap is deferred to v1.1 — see
> [REVIEW.md S3](./REVIEW.md#3-structural-simplifications-s1s13).)

### Task 3.1 — Disk tree model + builder

- [ ] `Lens/DiskTreeNode.swift`
- [ ] `Lens/DiskTreeBuilder.swift`: `actor`, walks chosen root
- [ ] Hardlink dedupe (inlined like in `DirectorySizer`)
- [ ] Symlink handling: don't follow by default
- [ ] Cancellation
- [ ] Tests: `DiskTreeBuilderTests`

**Files:** `graucore/Sources/graucore/Lens/*.swift`
**AC:** Builds tree from a fixture directory; respects exclusions and
hardlinks; cancels within 100ms.

### Task 3.2 — Top-N folders UI

- [ ] `grau/Features/DiskLens/DiskLensView.swift`: top = Top-N list,
      bottom = drill file list
- [ ] `grau/Features/DiskLens/TopFoldersListView.swift`: sorted list
      of the top 20 largest folders
- [ ] Right-click context menu: "Reveal in Finder", "Move to Trash"
- [ ] Cancellation: progress bar with "Cancel" button

**Files:** `grau/Features/DiskLens/*.swift`
**AC:** Drill works; right-click works; cancel works.

### Task 3.3 — Bug-bash week

- [ ] Run `MANUAL-TEST.md` disk lens section
- [ ] Performance: < 60s for full scan, cancellable
- [ ] Treemap: not in v1 (deferred to v1.1)

**AC:** All disk lens acceptance criteria pass.

### Task 3.4 — Beta 3 release

- [ ] Screenshot
- [ ] CHANGELOG
- [ ] Tag `v0.4.0-beta.3`

**Tag:** `v0.4.0-beta.3`. Public beta.

---

## Epic 4 — Duplicates finder (2.5 weeks) → Beta 4

> Goal: find byte-identical files anywhere on disk, group them, let
> the user clean. Never auto-select the only copy of a file.

### Task 4.1 — File hasher

- [ ] `FS/FileHasher.swift`: streaming SHA256 (CryptoKit) + partial-hash
- [ ] Tests: `FileHasherTests` with known-answer vectors

**Files:** `graucore/Sources/graucore/FS/FileHasher.swift`
**AC:** Hashes 1 GB file in < 5s; partial-hash in < 50ms.

### Task 4.2 — Duplicate scanner

- [ ] `Duplicates/DuplicateScanner.swift`: `actor`, the
      size → partial-hash → full-hash pipeline
- [ ] Cancellation between phases
- [ ] `Duplicates/DuplicateGroup.swift`
- [ ] `Duplicates/DuplicateSelection.swift`: "keep oldest" heuristic
- [ ] Tests: `DuplicateScannerTests` with fixtures of duplicates +
      uniques

**Files:** `graucore/Sources/graucore/Duplicates/*.swift`
**AC:** 100% public-API coverage on `DuplicateScanner`. (In the 8
critical modules.) Never selects the only copy.

### Task 4.3 — Duplicates UI

- [ ] `grau/Features/Duplicates/DuplicatesView.swift`: pick root,
      scan, group list
- [ ] `grau/Features/Duplicates/DuplicateGroupView.swift`
- [ ] Phase indicator (sizing → partial → full)
- [ ] Cancel button
- [ ] Multi-select within a group

**Files:** `grau/Features/Duplicates/*.swift`
**AC:** Scan completes in < 5 min on `~/` of a 200GB Mac.

### Task 4.4 — Bug-bash week

**AC:** All duplicates acceptance criteria pass.

### Task 4.5 — Beta 4 release

- [ ] Screenshot, CHANGELOG, tag `v0.5.0-beta.4`

**Tag:** `v0.5.0-beta.4`. Public beta.

---

## Epic 5 — Dev mode (4 weeks) → Beta 5

> Goal: surface dev caches and `node_modules` and let the user
> clean them. Docker inspector. iOS Simulators. DerivedData.
> Hidden by default behind a Settings toggle.

### Task 5.1 — Dev mode visibility toggle

- [ ] Settings: "Show developer features" toggle
      (key `grau.devModeEnabled`, default `false`)
- [ ] `MainWindowView`'s sidebar conditionally includes Dev Mode
- [ ] `grau/Features/DevMode/DevModeView.swift` (skeleton)

**Files:** `grau/Features/Settings/SettingsView.swift`,
`grau/Features/MainWindow/MainWindowView.swift`
**AC:** Dev Mode item appears in sidebar only when toggle is on.

### Task 5.2 — Node modules finder

- [ ] `Dev/NodeModulesFinder.swift`: `actor`, walks configured roots
- [ ] `Dev/NodeModulesInfo.swift`
- [ ] Tests: `NodeModulesFinderTests` with fixture tree

**Files:** `graucore/Sources/graucore/Dev/NodeModulesFinder.swift`
**AC:** Finds all `node_modules` dirs at depth ≤ 6 from configured
roots.

### Task 5.3 — Package cache scanner

- [ ] `Dev/PackageCacheKind.swift`: 16 kinds
- [ ] `Dev/PackageCacheScanner.swift`: `actor`
- [ ] `Dev/PackageCacheInfo.swift`
- [ ] Tests: `PackageCacheScannerTests` with fixture dirs

**Files:** `graucore/Sources/graucore/Dev/PackageCache*.swift`
**AC:** All 16 package caches detected.

### Task 5.4 — CLIRunner

- [ ] `Dev/CLIRunner.swift`: `Process` wrapper, timeout, output capture
- [ ] Tests: `CLIRunnerTests` (success/timeout/not-found/non-zero)

**Files:** `graucore/Sources/graucore/Dev/CLIRunner.swift`
**AC:** Timeouts within 100ms of configured timeout; output captured.

### Task 5.5 — Docker inspector

- [ ] `Dev/DockerInspector.swift`: parses `docker system df -v`
- [ ] Handles: docker not installed, daemon not running, normal case
- [ ] Tests: `DockerInspectorTests` with canned output

**Files:** `graucore/Sources/graucore/Dev/DockerInspector.swift`
**AC:** All three states (installed+daemon, installed+no-daemon,
not installed) render correctly in UI.

### Task 5.6 — iOS Simulator + DerivedData + Archives inspectors

- [ ] `Dev/SimulatorInspector.swift`
- [ ] `Dev/DerivedDataInspector.swift`
- [ ] `Dev/ArchivesInspector.swift` (default OFF, userCaution)
- [ ] Tests for each

**Files:** `graucore/Sources/graucore/Dev/{Simulator,DerivedData,Archives}*.swift`
**AC:** Each finds the right paths and sizes correctly.

### Task 5.7 — Dev mode UI

- [ ] `grau/Features/DevMode/DevModeView.swift`: tabbed view
      (Packages / node_modules / Docker / Simulators / DerivedData / Archives)
- [ ] Each tab: list + checkbox + summary card + "Clean Selected"
- [ ] Settings: configure `node_modules` roots

**Files:** `grau/Features/DevMode/*.swift`,
`grau/Features/Settings/SettingsView.swift`
**AC:** All 6 tabs functional; root configuration persisted.

### Task 5.8 — Bug-bash week

**AC:** All dev mode acceptance criteria pass.

### Task 5.9 — Beta 5 release

- [ ] Screenshot, CHANGELOG, tag `v0.6.0-beta.5`

**Tag:** `v0.6.0-beta.5`. Public beta.

---

## Epic 6a — Polish pt 1 (1.5 weeks) → 1.0

> Goal: app icon (placeholder), DMG, notarization, Privacy Manifest,
> README, public launch. **1.0 ships without Sparkle or Homebrew
> Cask** — those are v1.1 (Epic 6b). The original Phase 6 budget of
> 2 weeks for everything was wildly optimistic; see
> [REVIEW.md S12](./REVIEW.md#3-structural-simplifications-s1s13).

### Task 6a.1 — App icon (placeholder)

- [ ] Generate placeholder monogram icon (text "G" in `grau/accent`
      on `grau/gray/50`, 1024×1024 PNG)
- [ ] `iconutil` → `.icns` at all required sizes
- [ ] Add to `grau/Assets.xcassets/AppIcon.appiconset/`
- [ ] Menu bar template image

**Files:** `grau/Assets.xcassets/AppIcon.appiconset/`,
`grau/Assets.xcassets/MenuBarIcon.imageset/`
**AC:** Icon visible in Finder; menu bar icon is a template image.

### Task 6a.2 — DMG packaging

- [ ] `scripts/make-dmg.sh`: build Release, create `Grau-<v>.dmg` with
      drag-to-Applications background
- [ ] Use `create-dmg` (brew formula)
- [ ] Manual test: open DMG, drag to Applications, app launches

**Files:** `scripts/make-dmg.sh`
**AC:** DMG is well-formed; install works on a fresh machine.

### Task 6a.3 — Notarization

- [ ] `scripts/notarize.sh`: `xcrun notarytool submit` + staple
- [ ] First-time notarization requires Developer ID + App Store
      Connect API key
- [ ] Verify with `xcrun stapler validate`

**Files:** `scripts/notarize.sh`
**AC:** Notarization succeeds; `stapler validate` passes.

### Task 6a.4 — Privacy Manifest (REQUIRED for notarization)

- [ ] Create `grau/PrivacyInfo.xcprivacy`:
      - `NSPrivacyAccessedAPICategoryFileTimestamp`: `"C617.1"`
      - `NSPrivacyAccessedAPICategoryDiskSpace`: `"E174.1"`
      - `NSPrivacyAccessedAPICategorySystemBootTime`: `"35F9.1"` (if used)
- [ ] Add to Xcode target as a resource
- [ ] Verify `notarytool` accepts the bundle

**Files:** `grau/PrivacyInfo.xcprivacy`
**AC:** Notarization succeeds with the manifest present.

### Task 6a.5 — Release build verification

- [ ] `xcodebuild -scheme grau -configuration Release` succeeds
      without warnings
- [ ] All `graucore` tests pass in Release
- [ ] No SwiftData references anywhere (grep the codebase)

**AC:** Release build is warning-free.

### Task 6a.6 — Documentation

- [ ] Repo `README.md`:
      - Logo (placeholder)
      - One-line description
      - "Why Grau?" comparison table
      - 5 screenshots (one per feature)
      - "How to install" (DMG; Sparkle in 6b)
      - "How to build" (for contributors)
      - "How to contribute"
      - License badge
      - "Roadmap" link
- [ ] `CONTRIBUTING.md`: issues, PR conventions, dev setup
- [ ] `CHANGELOG.md`: per-beta + 1.0.0 entry
- [ ] `docs/TROUBLESHOOTING.md`: known issues + fixes

**Files:** `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md`,
`docs/TROUBLESHOOTING.md`
**AC:** All docs in place; README has screenshots and install
instructions.

### Task 6a.7 — Final manual test pass

- [ ] Run full `docs/MANUAL-TEST.md` end-to-end
- [ ] Verify all 12 success criteria from PLAN.md § 6

**AC:** Every checklist item in MANUAL-TEST.md passes.

### Task 6a.8 — 1.0 release

- [ ] `git tag v1.0.0 && git push --tags`
- [ ] Publish GitHub Release with notes
- [ ] Public announcement (Twitter / Reddit / Hacker News)

**Tag:** `v1.0.0`. Public launch.

### Phase 6a acceptance (1.0)

- [ ] All 12 success criteria from [PLAN.md § 6](./PLAN.md#6-success-criteria-10)
- [ ] README, CHANGELOG, LICENSE, CONTRIBUTING in place
- [ ] DMG works
- [ ] Notarized
- [ ] No Sparkle yet (acceptable for 1.0; lands in 1.1)

---

## Epic 6b — Polish pt 2 (1.5 weeks) → 1.1

> Goal: Sparkle self-update, Homebrew Cask, landing page.

### Task 6b.1 — Sparkle self-update

- [ ] Add Sparkle 2.x as a Swift Package dependency
- [ ] Configure `SUFeedURL`
- [ ] `scripts/sparkle-feed.sh` (uses Sparkle's `sign_update`)
- [ ] Test: install older build, click "Check for updates", update
      flow runs

**Files:** `grau.xcodeproj` (dep), `scripts/sparkle-feed.sh`
**AC:** End-to-end update from 1.0 → 1.1 works.

### Task 6b.2 — Sparkle appcast hosting

- [ ] GitHub Action generates `appcast.xml` on tag push
- [ ] Host on GitHub Pages
- [ ] Cut a v1.0.1 to verify the existing 1.0 users get the prompt

**Files:** `.github/workflows/sparkle-feed.yml`
**AC:** Tag push → appcast updated → existing users notified.

### Task 6b.3 — Homebrew Cask

- [ ] Open PR to `homebrew-cask` to add `grau`
- [ ] Source: GitHub Release DMG URL
- [ ] SHA256: from the release
- [ ] Test: `brew install --cask grau` on a fresh machine

**Files:** PR to `homebrew/homebrew-cask`
**AC:** `brew install --cask grau` installs Grau.

### Task 6b.4 — Landing page

- [ ] Static HTML, GitHub Pages
- [ ] Hero + 3 feature screenshots + install button + GitHub link
- [ ] Update README to link to it

**Files:** `docs/landing/`, GitHub Pages config
**AC:** Landing page live at the user's chosen URL.

### Task 6b.5 — 1.1 release

- [ ] `git tag v1.1.0 && git push --tags`
- [ ] Publish GitHub Release

**Tag:** `v1.1.0`. Public announcement.

### Phase 6b acceptance (1.1)

- [ ] Sparkle self-update works end-to-end
- [ ] `brew install --cask grau` works
- [ ] Landing page live
- [ ] All 12 success criteria from PLAN.md § 6.1 (v1.1) are met

---

## Open questions for the implementing AI

If you hit any of these, stop and ask the user:

1. **App name / bundle ID.** Default: `Grau` / `app.grau.mac`. Change
   before Phase 0 finishes if different.
2. **Repo name on GitHub.** Default suggestion: `grau`. User picks.
3. **Bundle identifier prefix.** Default: `app.grau`. If the user
   has a domain, use `com.<domain>.grau`.
4. **Apple Developer team ID.** Required for notarization in 6a. The
   user provides it from their Apple Developer account.
5. **First-run UI strings.** Defaults are in the design doc. If the
   user wants different copy, override in
   `grau/Resources/en.lproj/`.
6. **Anything not in this doc.** The architecture and data-sources
   docs are explicit. Most decisions are made.
