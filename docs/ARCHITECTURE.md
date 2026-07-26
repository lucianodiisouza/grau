# ARCHITECTURE — Grau

## 1. Tech stack

| Layer | Choice | Version target |
| --- | --- | --- |
| Language | Swift | 5.9+ |
| UI | SwiftUI + AppKit interop where SwiftUI is weak | macOS 14+ |
| Persistence | SwiftData | macOS 14+ |
| Concurrency | `actor`, `async/await`, structured concurrency | — |
| Reactive glue | `@Observable` macro | — |
| Hashing | CryptoKit (SHA256) + CommonCrypto (MD5, partial-hash) | — |
| Self-update | Sparkle 2.x | — |
| Packaging | `create-dmg` | — |
| Build (app) | Xcode | 15+ |
| Build (core) | Swift Package Manager | Swift 5.9 toolchain |
| Tests | XCTest | — |
| Min macOS | 14.0 (Sonoma) | — |
| Architectures | Universal (arm64 + x86_64) | — |

No third-party **runtime** dependencies in v1 except Sparkle for
self-update. Everything else is Apple SDKs.

## 2. Top-level layout

The repo is one Xcode app project that depends on a local Swift Package
(`graucore`). All non-UI logic lives in `graucore` and is unit-testable
in isolation.

```
grau/                                     # repo root
├── .github/
│   └── workflows/
│       └── ci.yml                         # CI: graucore tests + app build
├── grau.xcodeproj/                        # Xcode app project
├── grau/                                  # main app target
│   ├── grauApp.swift                      # @main, scene config
│   ├── AppViewModel.swift                 # @MainActor @Observable top-level VM
│   ├── DesignSystem/                      # see DESIGN.md
│   ├── Features/
│   │   ├── Onboarding/
│   │   ├── Dashboard/
│   │   ├── JunkCleaner/
│   │   ├── Uninstaller/
│   │   ├── DiskLens/
│   │   ├── Duplicates/
│   │   ├── DevMode/
│   │   ├── MenuBar/
│   │   ├── Settings/
│   │   ├── Notifications/
│   │   └── Permissions/
│   ├── grau.entitlements
│   ├── Info.plist
│   ├── PrivacyInfo.xcprivacy              # required for notarization (Phase 6a)
│   └── Assets.xcassets/
├── graucore/                              # Swift Package — pure logic
│   ├── Package.swift
│   ├── Sources/graucore/
│   │   └── (see § 4)
│   └── Tests/graucoreTests/
│       └── (see § 5)
├── docs/                                  # this folder
├── scripts/                               # dev tooling
│   ├── make-dmg.sh
│   ├── notarize.sh
│   └── sparkle-feed.sh
├── LICENSE                                # MIT
├── README.md
└── .gitignore
```

## 3. App target configuration

### Info.plist (key entries)
```xml
<key>CFBundleName</key>                <string>Grau</string>
<key>CFBundleDisplayName</key>          <string>Grau</string>
<key>CFBundleIdentifier</key>           <string>app.grau.mac</string>
<key>CFBundleShortVersionString</key>   <string>0.1.0</string>
<key>CFBundleVersion</key>              <string>1</string>
<key>CFBundlePackageType</key>          <string>APPL</string>
<key>LSMinimumSystemVersion</key>       <string>14.0</string>
<key>LSUIElement</key>                  <true/>
<key>NSHumanReadableCopyright</key>     <string>MIT — see LICENSE</string>
<key>NSSupportsAutomaticTermination</key> <true/>
<key>NSSupportsSuddenTermination</key>  <true/>
<key>NSUserNotificationAlertStyle</key> <string>banner</string>
```

`LSUIElement = true` means no Dock icon — Grau is a menu-bar app. The
main window opens on demand from the menu bar popover.

### Entitlements (`grau.entitlements`)
```xml
<key>com.apple.security.app-sandbox</key>     <false/>
<key>com.apple.security.network.client</key>  <true/>
<key>com.apple.security.files.user-selected.read-write</key> <true/>
```

App Sandbox is **off** because:
- We need to read arbitrary paths under `~/Library`, `/Library`, and
  `/private/var/log` (the last two require FDA at the OS level; we are
  not sandboxed but the OS still requires FDA for some paths).
- We need to spawn `docker` as a subprocess.
- We need to write to the user's Trash via `NSWorkspace`.

Hardened runtime **on** for notarization.

### Scenes (declared in `grauApp.swift`)

Three scenes:
1. `MenuBarExtra` (`MenuBarExtraStyle.window` popover) — always present.
2. `Window("Grau", id: "main")` — the dashboard / feature tabs.
3. `Window("Grau Settings", id: "settings")` — opened from menu.

The app activates as `accessory` (no Dock icon), but the main window
opens on first launch so the user sees something.

## 4. `graucore` module structure

Folders are flat. No "Kit" suffix.

```
Sources/graucore/
├── Primitives/                            # shared, used by every feature
│   ├── ByteSize.swift                     # Int64 + ByteCountFormatter-friendly
│   ├── Result+Async.swift
│   └── Logger.swift                       # os.log wrapper, structured
├── FS/                                    # filesystem primitives
│   ├── FileSystemScanner.swift            # struct, AsyncStream-based walker w/ cancel
│   ├── DirectorySizer.swift               # struct, uses scanner + inline hardlink dedupe
│   ├── FileHasher.swift                   # struct, streaming SHA256 + partial-hash
│   ├── TrashMover.swift                   # struct, FileManager.trashItem
│   ├── PathExclusions.swift               # standard exclusions: /System, /private/var/db, ...
│   └── ManifestStore.swift                # JSON read/write of ~/.grau/manifests/
├── Permissions/
│   ├── PermissionKind.swift               # enum: fullDiskAccess, accessibility, automation
│   └── PermissionChecker.swift            # checks current TCC state (FDA heuristic)
├── Volume/
│   ├── VolumeInfo.swift
│   ├── VolumeMonitor.swift                # actor, uses mountedVolumeURLs (not /Volumes)
│   └── TrashInfo.swift                    # ~/.Trash size, file count
├── Junk/
│   ├── JunkCategory.swift                 # 5 categories
│   ├── JunkDefinition.swift               # struct: id, name, paths, safety, defaultSelected
│   ├── JunkScanner.swift                  # actor — walks each definition
│   ├── JunkResult.swift                   # scan result
│   ├── JunkCleaner.swift                  # struct — wraps TrashMover
│   └── SizeCache.swift                    # JSON in ~/.grau/size-cache.json (subsequent scan < 2s)
├── Uninstaller/
│   ├── InstalledApp.swift                 # no architecture field; simple struct
│   ├── BundleMetadata.swift
│   ├── AppScanner.swift                   # actor
│   ├── ResidualKind.swift                 # 8 kinds, NO keychainEntries
│   ├── Residual.swift
│   ├── ResidualFinder.swift               # actor — finds residual data
│   ├── UninstallPlan.swift
│   └── Uninstaller.swift                  # builds uninstall plan + trashes
├── Lens/
│   ├── DiskTreeNode.swift                 # tree structure
│   └── DiskTreeBuilder.swift              # actor — builds tree from scan
├── Duplicates/
│   ├── DuplicateScanner.swift             # actor — size → partial-hash → full-hash
│   ├── DuplicateGroup.swift
│   └── DuplicateSelection.swift           # safe-selection logic (keep oldest)
├── Dev/
│   ├── PackageCacheKind.swift             # enum: npm, yarn, pnpm, ...
│   ├── PackageCacheScanner.swift          # actor
│   ├── NodeModulesFinder.swift            # actor — walks configured roots
│   ├── DockerInspector.swift              # `docker system df -v` parser
│   ├── SimulatorInspector.swift           # iOS Simulators
│   ├── DerivedDataInspector.swift         # Xcode DerivedData
│   ├── DevReport.swift                    # aggregated report
│   └── CLIRunner.swift                    # Process wrapper, timeout, output capture
└── Public API/
    └── graucore.swift                     # re-exports
```

Notes on what was removed and why:
- **`AppUpdatesKit`** — outdated app detection was in the original
  `macapps` plan but doesn't fit Grau. Dropped.
- **`HardlinkChecker.swift`** — single-method file. Inlined into
  `DirectorySizer` (via `URLResourceKey.linkCountKey`).
- **`Notifications/NotificationCenter.swift`** — uses `UNUserNotificationCenter`
  which is app-target territory. The wrapper lives in
  `grau/Features/Notifications/`.
- **`Persistence/ManifestStore.swift`** + **`PreferencesKeys.swift`** —
  consolidated into `FS/ManifestStore.swift`. There is no `Persistence/`
  directory: persistence = UserDefaults for prefs + JSON files in
  `~/.grau/` for state + manifests. No SwiftData. See
  [REVIEW.md S1](./REVIEW.md#3-structural-simplifications-s1s13).

## 5. `graucore` test layout

```
Tests/graucoreTests/
├── ByteSizeTests.swift
├── FileSystemScannerTests.swift           # fixture directory + assert walk
├── DirectorySizerTests.swift              # parallel + cancellation; hardlink dedupe
├── FileHasherTests.swift                  # SHA256 known-answer; partial-hash bounds
├── TrashMoverTests.swift                  # round-trip; manifest shape
├── ManifestStoreTests.swift               # JSON serialize/deserialize
├── PermissionCheckerTests.swift           # mock, returns canned TCC state
├── VolumeMonitorTests.swift               # mock mountedVolumeURLs
├── TrashInfoTests.swift                   # fixture: synthetic ~/.Trash
├── SizeCacheTests.swift                   # mtime check; cache hit/miss
├── JunkScannerTests.swift                 # fixture: 5 categories, assert sizes + paths
├── JunkCleanerTests.swift                 # mock TrashMover; assert manifest
├── AppScannerTests.swift                  # fixture: synthetic .app bundles
├── ResidualFinderTests.swift              # fixture: an app bundle + matching residual dirs
├── UninstallerTests.swift                 # plan shape + trash-by-move (not actually trash in tests)
├── DiskTreeBuilderTests.swift             # fixture tree, assert hierarchy
├── DuplicateScannerTests.swift            # fixture with known duplicates + uniques
├── PackageCacheScannerTests.swift         # fixture: fake ~/.npm, ~/.cargo, etc.
├── DockerInspectorTests.swift             # mock command output, assert parse
├── NodeModulesFinderTests.swift           # fixture: tree with multiple node_modules
└── CLIRunnerTests.swift                   # success/timeout/not-found/non-zero-exit
```

### 5.1 Test coverage target

**100% public-API test coverage on the 8 critical modules:**

1. `TrashMover` (data-loss prevention)
2. `FileSystemScanner` (every feature depends on it)
3. `DirectorySizer` (sizes are user-visible, must be correct)
4. `JunkScanner` (the headline feature)
5. `DuplicateScanner` (correctness critical — false positives lose data)
6. `Uninstaller` (data-loss prevention)
7. `PermissionChecker` (FDA state drives the whole UX)
8. `VolumeMonitor` (drives menu bar + notifications)

The remaining modules get tests as part of writing them, not as a
coverage target. This replaces the old ">80% line coverage" goal — see
[REVIEW.md S5](./REVIEW.md#3-structural-simplifications-s1s13).

## 6. Data model

### 6.1 Core types

```swift
// MARK: - Size

public struct ByteSize: Hashable, Sendable, Codable, Comparable {
    public let bytes: Int64
    public init(bytes: Int64)
    public static let zero = ByteSize(bytes: 0)
}

// MARK: - Junk (5 user-facing categories — see DATA-SOURCES.md)

public enum JunkCategory: String, CaseIterable, Sendable, Codable {
    case userCache         // ~/Library/Caches/*  (excl. com.apple.*)
    case systemCache       // /Library/Caches/* + QuickLook + font cache (FDA)
    case logs              // ~/Library/Logs/* + /private/var/log/*.asl (FDA)
    case oldDownloads      // ~/Downloads/* older than threshold (default OFF)
    case iosBackups        // MobileSync/Backup/* (default OFF, userCaution)
    // Note: `trash` is NOT a junk category. It's displayed separately
    // and never auto-emptied. See DATA-SOURCES.md § 1.11.
}

public struct JunkDefinition: Sendable {
    public let id: JunkCategory
    public let displayName: String
    public let paths: [URL]                  // roots to walk
    public let requiresFDA: Bool
    public let safety: SafetyLevel
    public let defaultSelected: Bool         // initial checkbox state in UI
}

public enum SafetyLevel: String, Sendable, Codable {
    case safe            // caches, logs: deleting is always safe
    case safeWithCare    // downloads older than N: deleting is safe if user understands
    case userCaution     // iOS backups: explicit opt-in required
}

public struct JunkResult: Sendable {
    public let category: JunkCategory
    public let size: ByteSize
    public let items: [JunkItem]              // top N (default 1000) by size
    public let scanDuration: TimeInterval
    public let skipped: Bool                  // true if FDA missing
    public let skipReason: String?
}

public struct JunkItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let path: URL
    public let size: ByteSize
    public let isDirectory: Bool
}

// MARK: - Size cache (for < 2s subsequent scans — see PLAN § 6)

public struct SizeCacheEntry: Codable, Sendable {
    public let path: String
    public let size: Int64
    public let mtime: Date
    public let lastComputed: Date
}

public struct SizeCache: Codable, Sendable {
    public var version: Int = 1
    public var entries: [String: SizeCacheEntry]   // keyed by path
    public var lastFullScan: Date?
}

// MARK: - App + Uninstaller (NO keychain detection, NO architecture field)

public struct InstalledApp: Identifiable, Hashable, Sendable {
    public let id: String                     // bundle ID
    public let name: String
    public let installedVersion: String
    public let bundleURL: URL
    public let iconData: Data?
    public let lastModified: Date?
}

public enum ResidualKind: String, CaseIterable, Sendable, Codable {
    case preferences
    case caches
    case appSupport
    case logs
    case savedState
    case cookies
    case containers                         // default NOT selected
    case groupContainers                     // looked up via app's entitlements
    case launchAgents
    // NOTE: no `keychainEntries`. See REVIEW.md B3.
}

public struct Residual: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let kind: ResidualKind
    public let path: URL
    public let size: ByteSize
    public let note: String?
}

public struct UninstallPlan: Sendable {
    public let app: InstalledApp
    public let residuals: [Residual]
    public let totalSize: ByteSize
    public let hasUninstallHelper: Bool
    public let helperPath: URL?
}

public enum UninstallOutcome: Sendable {
    case trashed(manifestPath: URL)
    case partial(manifestPath: URL, errors: [UninstallError])
    case cancelled
}

// MARK: - Disk Lens

public struct DiskTreeNode: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let size: ByteSize
    public var children: [DiskTreeNode]?     // nil = leaf
}

// MARK: - Duplicates

public struct DuplicateGroup: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let hash: String
    public let size: ByteSize
    public let files: [URL]
    public var wastedBytes: ByteSize { ByteSize(bytes: size.bytes * Int64(files.count - 1)) }
}

// MARK: - Dev caches

public enum PackageCacheKind: String, CaseIterable, Sendable, Codable {
    case npm, yarnClassic, yarnBerry, pnpm, bun
    case cocoapods, carthage, swiftpm
    case maven, gradle, sbt, ivy
    case cargo, gem, pip, poetry
}

public struct PackageCacheInfo: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let kind: PackageCacheKind
    public let path: URL
    public let size: ByteSize
    public let lastUsed: Date?
}

public struct NodeModulesInfo: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let path: URL
    public let projectRoot: URL
    public let size: ByteSize
    public let lastModified: Date?
}

public struct DockerInfo: Sendable {
    public let dockerInstalled: Bool
    public let stoppedContainers: Int
    public let danglingImages: Int
    public let unusedVolumes: Int
    public let buildCacheSize: ByteSize
}

public struct SimulatorInfo: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let deviceID: String
    public let name: String
    public let runtime: String
    public let size: ByteSize
}
```

### 6.2 Persistence — NO SwiftData

**There is no SwiftData in v1.** The previous design used SwiftData
for `CachedApp`, `ScanRecord`, `NotificationRule`. This was removed
(see [REVIEW.md S1](./REVIEW.md#3-structural-simplifications-s1s13))
because:

- We don't need querying — just remember "the last scan" and a few
  booleans.
- SwiftData adds schema migration risk for a single-user local app.
- Two persistence layers (SwiftData + JSON manifests) for one product
  is confusing.

**Persistence is exactly two things:**

1. **`UserDefaults`** for user preferences and notification rule state.
   - Keys: `grau.onboarded: Bool`, `grau.rule.<id>.lastFiredAt: Date`,
     `grau.rule.<id>.lastValue: Double`, `grau.devModeEnabled: Bool`,
     `grau.downloadsThresholdDays: Int`, etc.
2. **JSON files in `~/.grau/`** for state and manifests:
   ```
   ~/.grau/
   ├── state.json                         # last scan summary + menu bar state cache
   ├── size-cache.json                    # SizeCache (mtime-keyed)
   ├── trash-manifests/
   │   ├── 2026-07-26T18-22-14-junk.json
   │   └── ...
   └── logs/
       └── grau.log                       # rolling, capped at 5 MB
   ```

### 6.3 Manifest schema

```swift
public struct TrashManifest: Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let kind: String                  // "junk" | "uninstall" | "duplicates" | ...
    public let totalSize: Int64
    public let items: [TrashManifestItem]
}

public struct TrashManifestItem: Codable, Sendable {
    public let originalPath: String          // path before trashing
    public let trashRelativePath: String     // path inside ~/.Trash
    public let size: Int64
}
```

Manifests are written by `TrashMover` (which uses
`FileManager.trashItem`) for every destructive action. In v1, the UI
does not consume manifests; in v1.1 we add a "Restore from manifest"
flow (see [PLAN.md § 11.1](./PLAN.md#111-v11-post-10-15-weeks)).

## 7. Data flow

### 7.1 Generic feature scan (Junk / Disk Lens / Duplicates / Dev)

```
User clicks "Scan" in FeatureView
        │
        ▼
FeatureViewModel.scan()            [MainActor]
        │
        ├─► showProgress(0)
        │
        ├─► FeatureEngine.scan(progress: onProgress)  [actor]
        │     │
        │     ├─► For each path in FeatureDefinition.paths:
        │     │     FileSystemScanner.walk(
        │     │         root: path,
        │     │         exclusions: PathExclusions.standard,
        │     │         onProgress: { onProgress(...) }
        │     │     )
        │     │
        │     └─► returns FeatureResult
        │
        ├─► persist ScanRecord to SwiftData
        │
        └─► @Observable update → SwiftUI re-renders
```

`FileSystemScanner.walk` is the workhorse — it's the same primitive
used by every feature. It:

1. Walks `root` with `FileManager.enumerator`.
2. Skips paths in `exclusions` (e.g., `/System`, `/private/var/db`,
   `node_modules` unless the feature wants them).
3. Yields files/dirs to a callback as it goes (so the UI can stream
   progress).
4. Honors `Task.isCancelled` between batches.
5. Captures per-file errors (permission denied, etc.) and continues.

### 7.2 Generic destructive action (Clean / Uninstall / Move to Trash)

```
User clicks "Clean" with selection
        │
        ▼
FeatureViewModel.clean(selection)  [MainActor]
        │
        ├─► confirm()                     [in UI: a sheet]
        │
        ├─► TrashMover.trash(items: items, kind: "junk")  [struct]
        │     │
        │     ├─► For each item:
        │     │     FileManager.trashItem(at: item,
        │     │                          resultingItemURL: &url)
        │     │                              // -> ~/.Trash (or .Trashes on volume)
        │     │
        │     └─► writes TrashManifest to ~/.grau/trash-manifests/
        │
        ├─► update state.json
        │
        └─► showSuccess(snapshot: manifest)
```

`TrashMover` is **the only module in the codebase that performs
destructive IO.** Everything funnels through it. It uses
`FileManager.trashItem` (not `NSWorkspace.dispose`) for atomicity and
speed. It also:
- Detects hardlinks via `URLResourceKey.linkCountKey` and preserves
  them (move all hardlinks together, or warn)
- Refuses to trash read-only items
- Records the original path in the manifest so the user can find the
  item in Trash

### 7.3 Menu bar + notifications

```
AppViewModel (top-level)
        │
        ├─► MenuBarState: { freeBytes, totalBytes, trashSize, pendingCount }
        │
        ├─► VolumeMonitor.tick() every 6h     [background task]
        │     └─► updates MenuBarState
        │
        └─► NotificationCenter.evaluate(rules:)
              │
              ├─► rule: "junk > 1 GB"  → check last JunkScanRecord
              ├─► rule: "disk > 90%"   → check VolumeMonitor
              └─► rule: "trash > 5 GB" → check TrashInfo
```

Notifications are deduplicated — once a "trash full" notification
fires, it doesn't fire again until trash is emptied and re-filled.

## 8. Concurrency model

The previous "every engine is an `actor`" rule was relaxed in the
review ([REVIEW.md S4](./REVIEW.md#3-structural-simplifications-s1s13)).
The actual rule:

- **Default: `struct` engines with `async` methods.** Most of our
  engines have no shared mutable state. They take inputs, do work,
  return results.
- **Use `actor` only when there is real shared state** that requires
  serialization. Concretely:
  - `VolumeMonitor` is an `actor` because it holds the running
    background-refresh `Task` and a cancellation flag.
  - `JunkScanner` is an `actor` because it owns the
    parallel-category-scan `TaskGroup` and needs to cancel cleanly.
  - `DuplicateScanner`, `DiskTreeBuilder`, `PackageCacheScanner`,
    `NodeModulesFinder`, `SimulatorInspector`, `DockerInspector`,
    `ResidualFinder`, `AppScanner` are `actor`s for the same reason.
  - `FileSystemScanner`, `DirectorySizer`, `FileHasher`, `TrashMover`,
    `SizeCache`, `ManifestStore`, `PermissionChecker` are `struct`s.
- View models are `@MainActor @Observable`. They own engine
  references and are the only thing SwiftUI binds to.
- Long-running walks use `withTaskGroup(of:)` to fan out in parallel.
- Progress callbacks hop to MainActor before touching any UI state.

### 8.1 Cancellation contract
Every long-running `scan()` accepts `Task.isCancelled` checks at every
batch boundary. The UI shows a "Cancel" button that calls
`viewModel.cancel()` which calls `engine.cancel()` (which sets a flag
the scan checks). Cancellation must be:
- Bounded (cancels within 100ms of user click)
- Idempotent (multiple cancel calls are safe)
- Resource-clean (file handles closed, temp dirs removed)

## 9. Error handling policy

- **Per-file errors** are non-fatal. If a path is unreadable, log it,
  continue. Report the count of skipped items at the end of the scan.
- **Per-category errors** (e.g., `~/Library/Caches` unreadable) are
  surfaced in the UI as a "Could not scan X" state, but other
  categories still render.
- **Permission errors** (FDA missing) surface in the UI as a banner
  with a button to open System Settings.
- **No silent failures.** Every "skipped" state is visible.

## 10. Process model (the `app + package` split)

This is the single most important architecture decision. **All
non-UI logic lives in `graucore`.** The app target is responsible for:

- SwiftUI views
- AppKit interop
- UserDefaults / SwiftData plumbing
- Notification scheduling
- Sparkle integration

`graucore` is responsible for:

- Walking the filesystem
- Parsing `Info.plist`, `.appcast.xml`, `docker system df` output
- Computing sizes
- Hashing
- Moving to Trash
- Permission state queries
- Manifest serialization

If a feature needs UI, it lives in the app target. If a feature
needs logic, it lives in `graucore`. There is no middle ground.
This rule is non-negotiable.

## 11. Testing strategy

- **Unit tests** in `graucore` (XCTest). Every public function on the
  8 critical modules (see § 5.1).
- **Fixture directories** in `Tests/Fixtures/` with real `.app` bundles,
  real `node_modules`, real duplicate files. Tests build the fixtures
  in `setUp` and tear down in `tearDown`.
- **Snapshot tests** for the treemap (deferred to v1.1 — the treemap
  is not in v1).
- **Manual test plan** in [`MANUAL-TEST.md`](./MANUAL-TEST.md) — to be
  authored at end of Phase 0 by the AI.
- **No UI tests in v1.** The UI is mostly SwiftUI bindings to view
  models; unit tests on view models cover the meaningful behavior.
- **Crash-free sessions**: tracked via GitHub Issues during beta.
- **CI**: GitHub Actions runs `swift test` in `graucore/` and
  `xcodebuild -scheme grau build` on every push. See
  `.github/workflows/ci.yml` (added in Phase 0).

## 12. Performance budgets

| Operation | Target (1.0) | How we measure |
| --- | --- | --- |
| First junk scan | < 10 s on 200 GB free, 100 apps | `JunkScanner.scan()` timing |
| Subsequent junk scan (cache-warm) | < 2 s | `SizeCache` mtime check |
| Disk lens (Top-N, top-level dirs) | < 60 s, cancellable | `DiskTreeBuilder.build()` |
| Disk lens drill-down | < 200 ms per level | On-demand |
| Duplicates (`~/`, 100k files) | < 5 min, cancellable | `DuplicateScanner.scan()` |
| Dev caches scan | < 5 s | `PackageCacheScanner.scan()` |
| Idle memory (menu bar only) | < 100 MB | `top` / Activity Monitor |
| Junk clean of 10 GB | < 30 s | `TrashMover.trash(...)` |
| App launch to dashboard | < 1.5 s | Time-to-first-frame |

These are enforced in `MANUAL-TEST.md` and the AI's acceptance check.

## 13. Extensibility points (locked in v1)

The architecture supports (but does not implement in v1):

- **Custom junk definitions.** A `JunkDefinition` is just a struct.
  v1 ships a fixed list. v2 could let power users add their own.
- **Alternative update channels.** Sparkle in v1. v2 could add a
  Homebrew Cask channel.
- **Plugin architectures.** v1 has none. The line is drawn at the
  module boundary in `graucore`; v1 has no plugin loader.
