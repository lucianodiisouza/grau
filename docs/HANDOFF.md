# HANDOFF — Build order for the implementing AI

This document is the literal, ordered build plan. The implementing
agent follows it top to bottom, ticking off checkboxes as slices
complete. Each slice ships a usable beta.

**Conventions:**
- File paths are relative to the repo root
  (`/Users/lucianodiisouza/Documents/projects/macapps`).
- "Add a file at X" means create it. The exact content for the first
  several files is provided inline; later files reference the
  architecture doc.
- "Run the tests" means `cd graucore && swift test`.
- "Build the app" means
  `xcodebuild -scheme grau -configuration Debug build`.
- "Tag the beta" means git tag the commit with the slice's beta
  number and push.

---

## Phase 0 — Scaffold (1.5 weeks)

Goal: an Xcode project that builds, runs, shows a menu bar icon,
opens a dashboard window with empty feature placeholders. Design
system is in place. CI is green. Path list is audited. The app is
*recognizable* as Grau.

> Changes from the original Phase 0 (post-review): +0.5 wk for CI,
> repo rename, and the macOS 14 path audit. The rename matters
> because the folder was `macapps` but the project is `Grau` — see
> [REVIEW.md S7](./REVIEW.md#3-structural-simplifications-s1s13).

### 0.1 Repo & legal

- [ ] **Rename folder `macapps` → `grau`** (the project is Grau, not
      macapps — this prevents future contributor confusion).
- [ ] Initialize git: `git init`. Set `.gitignore` for Swift/macOS
      (build/, DerivedData/, .swiftpm/, .DS_Store, `*.swp`).
- [ ] Add `LICENSE` (MIT) at the repo root. Use the standard MIT
      text with `Copyright (c) 2026 <author>` header.
- [ ] Add `README.md` at the repo root: project name, one-line
      description, "this is a work in progress" badge, link to
      `docs/`.
- [ ] Create the GitHub repo (private until beta 1). Push the
      initial commit.

### 0.2 Xcode project

- [ ] Install [XcodeGen](https://github.com/yonaskolb/XcodeGen):
      `brew install xcodegen`.
- [ ] Create `project.yml` at the repo root:
      ```yaml
      name: grau
      options:
        deploymentTarget:
          macOS: "14.0"
        bundleIdPrefix: app.grau
        developmentLanguage: en
      targets:
        grau:
          type: application
          platform: macOS
          sources: [grau]
          info:
            path: grau/Info.plist
            properties:
              CFBundleName: Grau
              CFBundleDisplayName: Grau
              CFBundleShortVersionString: "0.1.0"
              CFBundleVersion: "1"
              CFBundlePackageType: APPL
              LSMinimumSystemVersion: "14.0"
              LSUIElement: true
              NSHumanReadableCopyright: "MIT — see LICENSE"
              NSSupportsAutomaticTermination: true
              NSSupportsSuddenTermination: true
          settings:
            base:
              SWIFT_VERSION: "5.9"
              PRODUCT_BUNDLE_IDENTIFIER: app.grau.mac
              CODE_SIGN_ENTITLEMENTS: grau/grau.entitlements
              ENABLE_HARDENED_RUNTIME: YES
              DEVELOPMENT_TEAM: ""                # fill from Xcode
              CODE_SIGN_STYLE: Automatic
          dependencies:
            - package: graucore
      packages:
        graucore:
          path: graucore
      ```
- [ ] Create `grau/grau.entitlements`:
      ```xml
      <?xml version="1.0" encoding="UTF-8"?>
      <plist version="1.0">
      <dict>
          <key>com.apple.security.app-sandbox</key>
          <false/>
          <key>com.apple.security.network.client</key>
          <true/>
          <key>com.apple.security.files.user-selected.read-write</key>
          <true/>
      </dict>
      </plist>
      ```
- [ ] Run `xcodegen generate`. Verify `grau.xcodeproj` is created
      and opens in Xcode.

### 0.3 Swift Package `graucore`

- [ ] Create the directory `graucore/`.
- [ ] `graucore/Package.swift`:
      ```swift
      // swift-tools-version: 5.9
      import PackageDescription

      let package = Package(
          name: "graucore",
          platforms: [.macOS(.v14)],
          products: [
              .library(name: "graucore", targets: ["graucore"]),
          ],
          targets: [
              .target(name: "graucore"),
              .testTarget(name: "graucoreTests", dependencies: ["graucore"]),
          ]
      )
      ```
- [ ] Create empty files for the modules listed in
      [ARCHITECTURE.md § 4](./ARCHITECTURE.md#4-graucore-module-structure).
      Each file gets a `// TODO: Phase N` comment and an empty
      namespace. This is so the package builds and the test target
      runs (even if empty).

### 0.4 App skeleton

- [ ] `grau/grauApp.swift`:
      ```swift
      import SwiftUI

      @main
      struct grauApp: App {
          @State private var appVM = AppViewModel()

          var body: some Scene {
              MenuBarExtra("Grau", systemImage: "circle.fill") {
                  MenuBarContentView()
                      .environment(appVM)
              }
              .menuBarExtraStyle(.window)

              Window("Grau", id: "main") {
                  MainWindowView()
                      .environment(appVM)
              }
              .windowResizability(.contentSize)
              .defaultSize(width: 900, height: 600)
              .commands {
                  CommandGroup(replacing: .appInfo) {
                      Button("About Grau") { /* TODO */ }
                  }
              }

              Window("Settings", id: "settings") {
                  SettingsView()
                      .environment(appVM)
              }
              .windowResizability(.contentSize)
              .defaultSize(width: 520, height: 360)
          }
      }
      ```
- [ ] `grau/AppViewModel.swift`: empty `@MainActor @Observable` class
      with placeholder `apps: [InstalledApp] = []` and `func refresh() async {}`.
- [ ] Stub views for every feature (Dashboard, Clean, Uninstaller,
      Disk Lens, Duplicates, Dev Mode, Settings, MenuBar, Onboarding).
      Each is a `Text("Feature name — coming soon")` for now.

### 0.5 Design system

- [ ] Create `grau/DesignSystem/Colors/GrauColors.xcassets` with all
      light + dark color tokens from [DESIGN.md § 1.2](./DESIGN.md#12-color-palette).
      Use the Xcode asset catalog format: `Contents.json` + JSON
      color definitions per asset.
- [ ] `grau/DesignSystem/Components/CardView.swift`:
      ```swift
      import SwiftUI

      struct CardView<Content: View>: View {
          @ViewBuilder let content: Content
          var body: some View {
              content
                  .padding(16)
                  .background(.regularMaterial)
                  .clipShape(RoundedRectangle(cornerRadius: 12))
                  .overlay(
                      RoundedRectangle(cornerRadius: 12)
                          .strokeBorder(Color("grau/gray/200"), lineWidth: 0.5)
                  )
          }
      }
      ```
- [ ] `Pill.swift`, `PrimaryButton.swift`, `EmptyStateView.swift`
      from DESIGN.md § 2.5, § 2.6, § 7.
- [ ] `grau/DesignSystem/Spacing/Spacing.swift` with the spacing
      tokens from DESIGN.md § 1.5 as static `CGFloat` constants.

### 0.6 Dashboard skeleton

- [ ] `grau/Features/Dashboard/DashboardView.swift`: a real
      dashboard with **placeholder** content but the real layout:
      - Greeting at the top
      - Storage card (shows fake data, e.g., "237.4 GB used of
        500.1 GB")
      - Trash card (fake "8 items, 142 MB")
      - Last scan card (fake "Last scan: never")
      - Quick actions row with 4 disabled buttons
      - All wrapped in `CardView` instances
- [ ] `MainWindowView.swift` uses `NavigationSplitView` with
      sidebar listing the 5 features + Settings. Each selection
      pushes the (empty) feature view.

### 0.7 Verification

- [ ] `xcodebuild -scheme grau -configuration Debug build` succeeds.
- [ ] Run the app: menu bar icon appears, no Dock icon, main
      window opens with the dashboard, sidebar works (selections
      switch views even if those views are placeholders).
- [ ] Dark mode: `defaults write -g AppleInterfaceStyle Dark` →
      app colors adapt. Undo with `Dark` → `Light`.
- [ ] `cd graucore && swift test` passes (all tests empty for now).

### 0.8 CI

- [ ] Create `.github/workflows/ci.yml`:
      ```yaml
      name: CI
      on:
        push:
          branches: [main]
        pull_request:
      jobs:
        test:
          runs-on: macos-14
          steps:
            - uses: actions/checkout@v4
            - name: Select Xcode
              run: sudo xcode-select -s /Applications/Xcode_15.4.app
            - name: Test graucore
              run: cd graucore && swift test
            - name: Build app
              run: xcodebuild -scheme grau -configuration Debug -destination 'platform=macOS' build
      ```
- [ ] Push the workflow; verify it goes green on a dummy commit.
- [ ] Confirm the badge works in the README.

### 0.9 Path audit (mandatory)

> This task exists because the previous draft had stale paths
> (e.g., `com.apple.kext.caches`, which no longer exists on macOS
> 14+). See [REVIEW.md B5](./REVIEW.md#2-correctness-bugs-b1b8).

- [ ] On a live macOS 14 (or 15) machine, walk every path in
      [DATA-SOURCES.md § 1](./DATA-SOURCES.md#1-junk-cleaner-categories)
      and confirm it exists or doesn't.
- [ ] Remove paths that no longer exist from
      `graucore/Sources/graucore/FS/PathExclusions.swift` and
      `Junk/JunkDefinition.swift`.
- [ ] Add Apple Intelligence cache paths for macOS 15 if discovered
      (mark them as `userCaution`, not selected by default; tracked
      in v1.1 if uncertain).
- [ ] Commit the audit as a single change with a clear
      "audited YYYY-MM-DD" message.

### 0.10 Acceptance (Phase 0)

- [ ] `xcodebuild` succeeds for Debug and Release.
- [ ] App launches, menu bar visible, dashboard visible, sidebar
      functional, design system in place.
- [ ] README on the repo, LICENSE on the repo.
- [ ] All planned doc files committed in `docs/`.

**Tag:** `v0.1.0-alpha`. No public release.

---

## Phase 1 — Junk cleaner + tray (4 weeks) → Beta 1

Goal: Grau scans junk across **5 user-facing categories**, lets the
user select and clean (to Trash), and shows live state in the menu
bar. FDA onboarding works. Manifests are written for every clean.
Beta 1 is shippable.

> Changes from the original Phase 1 (post-review): +1 wk for the
> bug-bash week, +SizeCache, +5-category simplification, -mail
> attachments, -browser cache, -keychain entries. See
> [REVIEW.md § 2](./REVIEW.md#2-correctness-bugs-b1b8) and
> [§ 3 S2](./REVIEW.md#3-structural-simplifications-s1s13).

### 1.1 Shared primitives in `graucore`

- [ ] `FS/ByteSize.swift`:
      ```swift
      public struct ByteSize: Hashable, Sendable, Codable, Comparable {
          public let bytes: Int64
          public init(bytes: Int64) { self.bytes = bytes }
          public static let zero = ByteSize(bytes: 0)
          public static func < (lhs: ByteSize, rhs: ByteSize) -> Bool {
              lhs.bytes < rhs.bytes
          }
          public var humanReadable: String {
              ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
          }
      }
      ```
- [ ] `FS/FileSystemScanner.swift`: `struct` (NOT `actor` — see
      [ARCHITECTURE.md § 8](./ARCHITECTURE.md#8-concurrency-model))
      that walks a root recursively, yields `URL`s via an
      `AsyncStream`, supports cancellation, applies
      `PathExclusions.standard`. The single primitive every feature
      uses.
- [ ] `FS/DirectorySizer.swift`: `struct`. Uses
      `FileSystemScanner` + `URLResourceKey.totalFileAllocatedSizeKey`.
      Returns total bytes + a streaming `AsyncStream<URL>` for live
      progress. **Hardlink dedupe inlined** (via
      `URLResourceKey.linkCountKey` + `Set<ino_t>`).
- [ ] `FS/TrashMover.swift`: `struct` that takes `[URL]`,
      moves each to `~/.Trash` via
      **`FileManager.trashItem(at:resultingItemURL:)`** (NOT
      `NSWorkspace.dispose` — see
      [REVIEW.md B7](./REVIEW.md#2-correctness-bugs-b1b8)),
      writes a `TrashManifest` to `~/.grau/trash-manifests/<ts>.json`.
      The ONLY module in the codebase that performs destructive IO.
- [ ] ~~`FS/HardlinkChecker.swift`~~ — removed; hardlink dedupe is
      inlined in `DirectorySizer` (see [REVIEW.md S10](./REVIEW.md#3-structural-simplifications-s1s13)).
- [ ] `FS/PathExclusions.swift`: the standard exclusion list
      (audited per Phase 0, Task 0.9).
- [ ] `Permissions/PermissionChecker.swift`: see
      [PERMISSIONS.md § 2.4](./PERMISSIONS.md#24-how-grau-checks-fda-status).
      Uses `/Library/Application Support/com.apple.TCC` as the test
      path.
- [ ] `Volume/VolumeMonitor.swift`: `actor`. Uses
      **`FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys:options:)`**
      (NOT walking `/Volumes/*` — see
      [REVIEW.md B1](./REVIEW.md#2-correctness-bugs-b1b8)) with keys
      `[.volumeIsLocalKey, .volumeIsRemovableKey, .volumeNameKey]`
      and options `[.skipHiddenVolumes]`. Returns `[VolumeInfo]`.
      Background tick every 6h.
- [ ] `Volume/TrashInfo.swift`: sizes `~/.Trash` (capped walk).
      Uses `URL.resolvingSymlinksInPath()` to handle the case where
      `~/.Trash` is a symlink to a non-boot volume.
- [ ] Tests for each: see [ARCHITECTURE.md § 5](./ARCHITECTURE.md#5-graucore-test-layout).

### 1.2 Junk module in `graucore`

- [ ] `Junk/JunkCategory.swift`: the **5-category enum** from
      [DATA-SOURCES.md § 1](./DATA-SOURCES.md#1-junk-cleaner-categories)
      (`userCache`, `systemCache`, `logs`, `oldDownloads`,
      `iosBackups`). No `mailAttachments`. No `browserCache`. No
      `trash` (trash is a separate display-only concept).
- [ ] `Junk/JunkDefinition.swift`: struct with id, displayName,
      paths, requiresFDA, safety, **defaultSelected**.
- [ ] `Junk/JunkScanner.swift`: `actor` that, given a list of
      definitions, scans each in parallel and returns
      `[JunkResult]`. Each result is the category, total size, list
      of top-N items (default 1000), scan duration, skipped flag.
- [ ] `Junk/JunkCleaner.swift`: `struct` that takes a selection,
      calls `TrashMover.trash(items:, kind: "junk")`, returns
      `TrashManifest`.
- [ ] `Junk/SizeCache.swift`: `struct` for the
      `~/.grau/size-cache.json` cache. Keyed by path; each entry has
      `size`, `mtime`, `lastComputed`. The scanner consults the cache
      and skips paths whose mtime hasn't changed since the last
      computation. Subsequent scans hit the cache and finish in
      < 2s.
- [ ] `JunkScannerTests.swift` with fixture directories for each
      category. Test: scan returns correct size + correct items;
      FDA-required categories are skipped when FDA missing;
      SizeCache short-circuits on mtime match.
- [ ] `JunkCleanerTests.swift` with a mock `TrashMover` (via
      protocol injection).
- [ ] `SizeCacheTests.swift`.

### 1.3 App target — junk cleaner UI

- [ ] `grau/Features/JunkCleaner/JunkCleanerView.swift`:
      - Toolbar with "Scan" and "Clean Selected" buttons
      - Summary cards at top: total junk found, biggest category,
        FDA-granted status
      - **List of 5 categories** (not 11), each with size, safety
        pill, checkbox. Initial state from
        `JunkDefinition.defaultSelected` — User Cache, System Cache,
        and Logs default ON; Old Downloads and iOS Backups default
        OFF.
      - Bottom action bar: "Clean Selected (X items, Y GB)"
      - Confirm sheet: lists what will be moved to Trash, "Cancel"
        and "Move to Trash" buttons. If any selected category is
        `userCaution`, show a second confirmation step.
      - Success sheet: "Freed X GB. [Done]" 
- [ ] `JunkCleanerViewModel.swift`: `@MainActor @Observable`,
      owns `JunkScanner` + `JunkCleaner`, exposes
      `results: [JunkResult]`, `isScanning`, `selectedCategories:
      Set<JunkCategory>`, `func scan()`, `func clean()`.
- [ ] `grau/Features/Dashboard/StorageCardView.swift`: live from
      `VolumeMonitor`. Polls every 30s when window is open.
- [ ] `grau/Features/Dashboard/LastScanCardView.swift`: reads the
      latest junk scan result from SwiftData.
- [ ] `grau/Features/Permissions/PermissionPrimerView.swift`: the
      3-step FDA primer from PERMISSIONS.md § 5.
- [ ] `grau/Features/Permissions/PermissionCoordinator.swift`:
      wires `PermissionChecker` to the UI; manages the polling
      re-check after the user opens System Settings.

### 1.4 Menu bar

- [ ] `grau/Features/MenuBar/MenuBarContentView.swift`: the 320pt
      popover from DESIGN.md § 3.2.
- [ ] `grau/Features/MenuBar/MenuBarState.swift`: `@MainActor
      @Observable` with `freeBytes`, `totalBytes`, `trashSize`,
      `pendingJunkBytes`. Polled every 6h via background `Task`.
- [ ] Menu bar icon: **template image** (no color), 18×18pt @1x /
      36×36pt @2x, drawn as a simple "G" in template style. The
      user replaces with the real icon in Phase 6a.
- [ ] Red-dot overlay when
      `pendingJunkBytes > 1 GB || trashSize > 5_000_000_000`.
- [ ] Menu bar click → if popover already open, close; if not,
      open it.

### 1.5 Notifications

- [ ] `grau/Features/Notifications/NotificationCoordinator.swift`:
      - On app launch, request `UNUserNotificationCenter`
        authorization.
      - On junk scan completion: if `totalBytes > 1_GB`, fire
        `junk.gt1gb` rule.
      - On `VolumeMonitor` tick: if any volume > 90% used, fire
        `disk.full.90` rule.
      - On `TrashInfo` tick: if > 5 GB, fire `trash.full.5gb` rule.
- [ ] **State-transition dedupe** per
      [PERMISSIONS.md § 3.3.1](./PERMISSIONS.md#331-notification-dedupe--state-transition-rule):
      only fire when value crosses threshold upward. Persist
      per-rule `lastFiredAt` and `lastValue` in UserDefaults.

### 1.6 Persistence (NO SwiftData)

- [ ] Use `UserDefaults.standard` for prefs (key constants in
      `grau/Persistence/PreferencesKeys.swift`):
      - `grau.onboarded: Bool`
      - `grau.devModeEnabled: Bool` (default false, used in Phase 5)
      - `grau.downloadsThresholdDays: Int` (default 90)
      - `grau.rule.<id>.lastFiredAt: Date` per notification rule
      - `grau.rule.<id>.lastValue: Double` per notification rule
- [ ] Use JSON files in `~/.grau/`:
      - `state.json` — last scan summary (kind, totalBytes, itemCount, finishedAt)
      - `size-cache.json` — `SizeCache` struct (mtime-keyed)
      - `trash-manifests/<ISO8601>-<kind>.json` — `TrashManifest`

### 1.7 Onboarding

- [ ] `grau/Features/Onboarding/OnboardingView.swift`: 3-screen
      tour (welcome → FDA primer → ready). Shown only on first
      launch (`!UserDefaults.standard.bool(forKey: "grau.onboarded")`).
      Subsequent launches go straight to the dashboard.
- [ ] "Show me again" toggle in Settings → reset
      `grau.onboarded = false` and re-show.

### 1.8 Settings skeleton

- [ ] `grau/Features/Settings/SettingsView.swift` with a Privacy
      section: FDA status, "Open System Settings" button.
      Other sections land in later phases.

### 1.9 Bug-bash week (mandatory)

> Added in review. AI-assisted solo work eats 25% of every phase to
> bug fixes. Schedule it explicitly or it gets skipped under time
> pressure. See [REVIEW.md § 4](./REVIEW.md#4-scope--timeline).

- [ ] Run through `MANUAL-TEST.md` (authored in Phase 0 Task 0.7).
- [ ] Fix anything red.
- [ ] Re-run all tests; CI must stay green.
- [ ] If a bug would take more than 0.5 day to fix, file it in
      `docs/BUGS.md` and defer to v1.1.

### 1.10 Verification

- [ ] Cold-launch the app, accept FDA in the primer, scan junk:
      results appear within 10s on a 200GB free Mac.
- [ ] Select 3 categories, click "Move to Trash", confirm, observe
      storage card updating.
- [ ] Open `~/.Trash` in Finder: the trashed items are there.
- [ ] Quit Grau. Inspect `~/.grau/trash-manifests/`: a manifest
      JSON file is there.
- [ ] Quit and relaunch: SizeCache should make the second scan
      < 2s.
- [ ] Menu bar icon shows red dot when junk > 1 GB.
- [ ] Notification fires for "disk > 90% full" only when the
      threshold is crossed (state-transition dedupe), not on every
      tick.
- [ ] Without FDA: "limited mode" banner, System Cache and Logs
      show "Permission required", User Cache / Old Downloads /
      iOS Backups still work.
- [ ] All `graucore` unit tests pass.

### 1.11 Acceptance (Beta 1)

- [ ] All 5 junk categories scan correctly.
- [ ] Cleaning moves files to Trash via `FileManager.trashItem`
      (verifiable in Finder).
- [ ] Manifest written for every clean.
- [ ] FDA missing → "limited mode" banner + skipped FDA-required
      categories.
- [ ] Menu bar popover shows real data.
- [ ] Subsequent scan < 2s via SizeCache.
- [ ] All `graucore` tests pass; 100% public-API coverage on the
      6 in-scope critical modules (TrashMover, FileSystemScanner,
      DirectorySizer, JunkScanner, PermissionChecker, VolumeMonitor).
- [ ] Performance: < 10s for first scan on 200GB free.

**Tag:** `v0.2.0-beta.1`. Public beta. README updated with
screenshot. GitHub Release published.

---

## Phase 2 — App uninstaller (3 weeks) → Beta 2

Goal: list installed apps, show residual data, uninstall (trash
everything).

### 2.1 In `graucore`

- [ ] `UninstallerKit/InstalledApp.swift`,
      `BundleMetadata.swift`, `AppScanner.swift` (carried over from
      `macapps` plan, refactored to fit the Grau module naming).
- [ ] `UninstallerKit/ResidualKind.swift`, `Residual.swift`,
      `ResidualFinder.swift`: the 10-kind residual finder from
      [DATA-SOURCES.md § 2.2](./DATA-SOURCES.md#22-residual-detection).
- [ ] `UninstallerKit/Uninstaller.swift`: builds an `UninstallPlan`
      from app + residuals, executes it via `TrashMover`.
- [ ] Tests: `AppScannerTests`, `ResidualFinderTests`,
      `UninstallerTests`.

### 2.2 App target

- [ ] `grau/Features/Uninstaller/UninstallerView.swift`: list of
      installed apps (left), selected app's residual list (right).
      Each residual: kind, path, size, checkbox (default ON
      except containers / keychain).
- [ ] `UninstallerViewModel.swift`: scan, select, build plan,
      confirm, execute.
- [ ] Confirm sheet: "Move X to Trash. Original: /Applications/Foo.app.
      [Cancel] [Move to Trash]". After confirmation, a success sheet
      with "Reveal in Finder" and "Done" buttons.
- [ ] Pre-uninstall helper detection: if app has
      `Contents/Resources/Uninstall.app`, the confirm sheet offers
      "Run the app's uninstaller first."

### 2.3 Verification

- [ ] Install a throwaway app (e.g., a free dev tool from
      Setapp). Run Grau, find it, see residuals.
- [ ] Uninstall: app + residuals land in Trash. Reinstall from
      vendor, run again, all clean.
- [ ] Try to uninstall a system app: blocked with a clear error.
- [ ] Try to uninstall a running app: blocked, "Quit first" hint.

### 2.4 Acceptance (Beta 2)

- [ ] Lists all installed user apps.
- [ ] Shows correct residual kinds + sizes.
- [ ] Uninstall works end-to-end on a real app.
- [ ] System apps blocked.
- [ ] All tests pass.

**Tag:** `v0.3.0-beta.2`.

> Phase 2 changes from review: +1 wk for bug-bash week, dropped
> `keychainEntries` from `ResidualKind`, fixed `groupContainers`
> lookup to use the app's `com.apple.security.application-groups`
> entitlement instead of deriving from bundle ID. See
> [REVIEW.md B3, B4](./REVIEW.md#2-correctness-bugs-b1b8).

Goal: visualize the disk as a treemap, drill down, free space
safely.

### 3.1 In `graucore`

- [ ] `LensKit/DiskTreeNode.swift`, `DiskTreeBuilder.swift`:
      walk `/` (or a user-chosen root), build the tree.
- [ ] `LensKit/TreemapAlgorithm.swift`: implement **squarified
      treemap** (Bruls, Huijing & van Wijk, 2000). The algorithm
      is ~150 lines. No third-party deps.
- [ ] `LensKit/TreemapRect.swift`: output struct.
- [ ] Tests: `DiskTreeBuilderTests`, `TreemapAlgorithmTests` (rects
      don't overlap, sum to parent area, deepest leaves get a rect).

### 3.2 App target

- [ ] `grau/Features/DiskLens/DiskLensView.swift`: top is the
      treemap (`Canvas` rendering), bottom is the file list for the
      selected node.
- [ ] `grau/Features/DiskLens/TopFoldersListView.swift`: a sorted
      list of the top 20 largest folders at the chosen depth,
      with a click-to-drill. Each row shows: folder name, size,
      % of parent. Right-click → context menu with "Reveal in
      Finder" and "Move to Trash".
- [ ] Cancellation: scan progress bar with "Cancel" button.
- [ ] Treemap (v1.1, deferred): squarified algorithm +
      `Canvas` rendering land in v1.1. The current data
      structures (`DiskTreeNode`, drill path) are designed to
      support it without changes.

### 3.3 Verification

- [ ] Open disk lens on `/`. First scan completes in < 60s. Cancel
      mid-scan works.
- [ ] Drill down 3 levels: layout is correct, sizes are correct.
- [ ] Right-click → Reveal in Finder works.
- [ ] Right-click → Move to Trash: item lands in `~/.Trash`.

### 3.4 Acceptance (Beta 3)

- [ ] Top-N folders list renders correctly on a real disk.
- [ ] Drill-down works (click a folder to see its children).
- [ ] Right-click context menu works.
- [ ] Performance target met (< 60s for full scan, cancellable).
- [ ] All tests pass.

**Tag:** `v0.4.0-beta.3`.

---

## Phase 4 — Duplicates finder (2.5 weeks) → Beta 4

Goal: find duplicate files anywhere on disk, group them, let the
user clean.

### 4.1 In `graucore`

- [ ] `DuplicatesKit/DuplicateScanner.swift`: the size → partial
      hash → full hash pipeline. Cancellation between phases.
- [ ] `DuplicatesKit/DuplicateGroup.swift`.
- [ ] `DuplicatesKit/DuplicateSelection.swift`: safe-selection
      logic ("keep oldest").
- [ ] `FS/FileHasher.swift`: streaming SHA256 (CryptoKit) + a
      partial-hash function for the first 4 KB.
- [ ] Tests: `FileHasherTests`, `DuplicateScannerTests`.

### 4.2 App target

- [ ] `grau/Features/Duplicates/DuplicatesView.swift`: pick a root
      (`~/` default), scan, show duplicate groups, multi-select,
      "Move to Trash".
- [ ] `grau/Features/Duplicates/DuplicateGroupView.swift`: per-group
      view: hash, size, file list, "Select all except oldest".
- [ ] Progress: phase indicator (sizing → partial-hash → full-hash),
      byte-count progress, cancel button.

### 4.3 Verification

- [ ] Create a fixture: 3 identical files in different folders +
      1 unique file. Run scan. Find the 1 group, not the unique.
- [ ] On a real `~/Documents` (or test directory), find at least
      one duplicate group.
- [ ] Multi-select + move to Trash works.

### 4.4 Acceptance (Beta 4)

- [ ] Scan completes in < 5 min on `~/` of a 200GB Mac.
- [ ] Never suggests deleting the only copy of a file.
- [ ] All tests pass.

**Tag:** `v0.5.0-beta.4`.

---

## Phase 5 — Dev mode (4 weeks) → Beta 5

Goal: surface dev caches and `node_modules` and let the user clean
them. Docker inspector.

### 5.1 In `graucore`

- [ ] `DevKit/PackageCacheKind.swift`, `PackageCacheScanner.swift`:
      the 16 package manager caches from
      [DATA-SOURCES.md § 5.2](./DATA-SOURCES.md#52-package-manager-caches).
- [ ] `DevKit/NodeModulesFinder.swift`: walks configured roots
      for `node_modules` dirs.
- [ ] `DevKit/DockerInspector.swift`: shells out to
      `docker system df -v`, parses output.
- [ ] `DevKit/SimulatorInspector.swift`, `DerivedDataInspector.swift`,
      `ArchivesInspector.swift`.
- [ ] `DevKit/CLIRunner.swift`: `struct` (carried over from
      macapps plan, refactored) with timeout + JSON-or-text output.
- [ ] Tests: `PackageCacheScannerTests`, `DockerInspectorTests`,
      `NodeModulesFinderTests`.

### 5.2 App target

- [ ] **Dev Mode visibility toggle** (added in review —
      [REVIEW.md S9](./REVIEW.md#3-structural-simplifications-s1s13)):
      - Settings: "Show developer features" toggle (key
        `grau.devModeEnabled`, default `false`).
      - `MainWindowView`'s sidebar conditionally includes the
        Dev Mode item based on this flag.
- [ ] `grau/Features/DevMode/DevModeView.swift`: tabbed view with
      "Packages", "node_modules", "Docker", "Simulators",
      "DerivedData", "Archives".
- [ ] Each tab: list of caches with size + checkbox, summary card,
      "Clean Selected" button.
- [ ] Docker tab: if `docker` not installed, show "Install Docker
      Desktop to enable". If installed but daemon not running,
      show "Docker daemon not running" with a hint.
- [ ] node_modules tab: configuration UI for roots (Settings
      integration).

### 5.3 Verification

- [ ] On a dev machine with node_modules + .npm cache + Docker:
      all visible, sizes match `du -sh`.
- [ ] Clean npm cache: `npm install` works after.
- [ ] Remove a node_modules: project re-installs on `npm install`.
- [ ] Docker: stopped containers, dangling images listed correctly.

### 5.4 Acceptance (Beta 5)

- [ ] All 16 package caches detected.
- [ ] node_modules finder finds at least one match on a dev
      machine.
- [ ] Docker inspector parses real output.
- [ ] All tests pass.

**Tag:** `v0.6.0-beta.5`.

---

## Phase 6a — Polish pt 1 (1.5 weeks) → 1.0

Goal: app icon (placeholder), DMG, notarization, Privacy Manifest,
README, public launch. **1.0 ships without Sparkle or Homebrew Cask**
— those are v1.1 (Phase 6b). The original Phase 6 budget of 2 weeks
for everything was wildly optimistic for a first-time maintainer; see
[REVIEW.md S12](./REVIEW.md#3-structural-simplifications-s1s13).

> Phase 6a changes from review: split out Sparkle + Cask to 6b,
> +Privacy Manifest, +placeholder icon (not AI-designed), +1.5 wk
> realistic estimate.

### 6a.1 App icon (placeholder)

- [ ] Generate a **placeholder** monogram icon: the letter "G" in
      `grau/accent` on a `grau/gray/50` background, 1024×1024 PNG.
      Not AI-designed; not final. The user replaces it before
      the 1.0 announcement.
- [ ] Use `iconutil` to generate `.icns` at all required sizes
      (16, 32, 64, 128, 256, 512, 1024 @1x and @2x where
      applicable).
- [ ] Add to `grau/Assets.xcassets/AppIcon.appiconset/`.
- [ ] Menu bar template image: simple "G" rendered as a
      **template image** (no color, OS tints it).

### 6a.2 DMG packaging

- [ ] `scripts/make-dmg.sh`:
      - Build Release.
      - Create a `Grau-<version>.dmg` with a drag-to-Applications
        background image.
      - Use `create-dmg` (brew formula).
- [ ] Manual test: open DMG, drag to Applications, app launches.

### 6a.3 Notarization

- [ ] `scripts/notarize.sh`:
      - Submit to Apple via `xcrun notarytool submit`.
      - Staple the ticket.
      - Verify with `xcrun stapler validate`.
- [ ] First-time notarization requires a Developer ID. The user
      provides it via the App Store Connect API key.

### 6a.4 Privacy Manifest (REQUIRED for notarization)

- [ ] Create `grau/PrivacyInfo.xcprivacy` with these declared
      "required reason" API accesses (Apple requires this as of
      May 2024):
      - `NSPrivacyAccessedAPICategoryFileTimestamp`: reason
        `"C617.1"` (display to user).
      - `NSPrivacyAccessedAPICategoryDiskSpace`: reason `"E174.1"`
        (display to user).
      - `NSPrivacyAccessedAPICategorySystemBootTime`: reason
        `"35F9.1"` (display to user), if `VolumeMonitor` uses it.
- [ ] Add to Xcode target as a resource.
- [ ] Verify `xcrun notarytool` accepts the bundle.

### 6a.5 Release build verification

- [ ] `xcodebuild -scheme grau -configuration Release` succeeds
      without warnings.
- [ ] All `graucore` tests pass in Release.
- [ ] No SwiftData references anywhere.

### 6a.6 Documentation

- [ ] Repo `README.md`:
      - Logo (placeholder)
      - One-line description
      - "Why Grau?" comparison table (Grau vs CleanMyMac vs App
        Cleaner)
      - Screenshots from each of the 5 features
      - "How to install" — DMG download (Sparkle link added in
        Phase 6b)
      - "How to build" — for contributors
      - "How to contribute"
      - License badge
      - "Roadmap" link to `docs/PLAN.md`
- [ ] `CONTRIBUTING.md`: how to file issues, PR conventions, dev
      setup (the `project.yml` + xcodegen path).
- [ ] `CHANGELOG.md`: per-beta summary, plus a `1.0.0` entry.
- [ ] `docs/MANUAL-TEST.md`: the manual test plan (final pass
      before 1.0). Authored incrementally through the betas;
      fleshed out in 6a.

### 6a.7 Verification

- [ ] All Phase 1–5 success criteria still met.
- [ ] DMG opens, drag-to-Applications works, app launches.
- [ ] Notarization succeeds (Apple accepts).
- [ ] Manual test plan from `docs/MANUAL-TEST.md` passes
      end-to-end.
- [ ] `graucore` test coverage on the 8 critical modules: 100%
      public-API.

### 6a.8 Acceptance (1.0)

- [ ] All 12 success criteria from [PLAN.md § 6](./PLAN.md#6-success-criteria-10)
      are met.
- [ ] README, CHANGELOG, LICENSE, CONTRIBUTING all in place.
- [ ] DMG works.
- [ ] Notarized.
- [ ] No Sparkle yet (acceptable for 1.0; lands in 1.1).

**Tag:** `v1.0.0`. Public launch.

---

## Phase 6b — Polish pt 2 (1.5 weeks) → 1.1

Goal: Sparkle self-update, Homebrew Cask, landing page. Tracked as
v1.1, not v1.0, because the user can install the 1.0 DMG manually
and updating from a 1.0 → 1.1 via Sparkle is the same as
1.0 → 1.0.1 via Sparkle.

### 6b.1 Sparkle self-update

- [ ] Add Sparkle 2.x as a Swift Package dependency.
- [ ] Configure `SUFeedURL` to point at
      `https://grau.app/releases/appcast.xml` (or whatever the
      user owns).
- [ ] Generate signed appcast via
      `scripts/sparkle-feed.sh` (uses Sparkle's `sign_update`).
- [ ] Test: install older build, click "Check for updates",
      update flow runs.

### 6b.2 Sparkle appcast hosting

- [ ] `scripts/sparkle-feed.sh` generates `appcast.xml` on
      `git tag` push (via GitHub Actions).
- [ ] Host the appcast on GitHub Pages
      (or a static bucket; pick what the user owns).
- [ ] First real signed update: cut a v1.0.1 from the
      1.0 branch, publish, verify the existing 1.0 users
      get the update prompt.

### 6b.3 Homebrew Cask

- [ ] Open PR to `homebrew-cask` to add `grau` cask.
      - Source: the GitHub Release DMG URL.
      - SHA256: from the release.
- [ ] Test: `brew install --cask grau` on a fresh machine.
- [ ] Update README to mention the Cask install path.

### 6b.4 Landing page

- [ ] Static HTML, GitHub Pages, simple
      (hero + 3 feature screenshots + install button +
      GitHub link).
- [ ] Update README to link to it.

### 6b.5 Acceptance (1.1)

- [ ] Sparkle self-update works end-to-end.
- [ ] `brew install --cask grau` works.
- [ ] Landing page live.
- [ ] All 12 success criteria from PLAN.md § 6.1 (v1.1) are met.

**Tag:** `v1.1.0`. Public announcement.

---

## Manual test plan (run before every beta tag)

A standalone doc, `docs/MANUAL-TEST.md`, to be authored at the end
of Phase 0 by the AI. The skeleton:

- [ ] App launches without crash. Menu bar icon appears. No Dock icon.
- [ ] Window opens, dashboard renders.
- [ ] Onboarding flow works on a fresh install.
- [ ] FDA grant → app recognizes it within 10s.
- [ ] FDA not granted → "limited mode" banner + skipped categories.
- [ ] For each feature (added per phase): happy path + 1 edge case.
- [ ] Every destructive action moves to Trash, never deletes.
- [ ] Manifest files written for every destructive action.
- [ ] Quit and relaunch: cached state restores, background refresh
      runs.
- [ ] No crash in 10 minutes of normal use.
- [ ] `cd graucore && swift test` passes.
- [ ] `xcodebuild -scheme grau -configuration Debug build` succeeds.
- [ ] `xcodebuild -scheme grau -configuration Release build` succeeds.

---

## Open questions for the implementing AI

If you hit any of these, stop and ask the user:

1. **App name / bundle ID.** Default: `Grau` / `app.grau.mac`. If
   the user wants a different name, change before Phase 0 finishes.
2. **Repo name on GitHub.** Default suggestion: `grau`. User picks.
3. **Bundle identifier prefix.** Default: `app.grau`. If the user
   has a domain, use `com.<domain>.grau` or similar.
4. **Apple Developer team ID.** Required for notarization in Phase 6.
   The user provides it from their Apple Developer account.
5. **App Store distribution.** v1 ships direct (DMG + Cask). If the
   user wants MAS, the architecture needs rework (helper tool etc.).
   Defer.
6. **First-run UI strings.** Defaults are in the design doc. If the
   user wants different copy, document it in `grau/Resources/en.lproj/`
   overrides.
7. **Anything not in this doc.** Use judgment, but the architecture
   and data-sources docs are explicit. Most decisions are made.
