# ARCHITECTURE — macapps

## 1. Tech stack

| Layer | Choice | Version target |
| --- | --- | --- |
| Language | Swift | 5.9+ |
| UI | SwiftUI | macOS 14+ |
| Persistence | SwiftData | macOS 14+ |
| Reactive glue | `@Observable` + `async/await` | — |
| AppKit interop | `NSWorkspace`, `NSStatusItem` fallback | macOS 14+ |
| Build (app) | Xcode | 15+ |
| Build (core) | Swift Package Manager | Swift 5.9 toolchain |
| Tests | XCTest (package) + Swift Testing (where convenient) | — |
| Min macOS | 14.0 (Sonoma) | — |

No third-party dependencies in v1. Everything we need is in the standard
library and Apple SDKs.

## 2. Target layout

The project is **two** build products:

```
macapps/                                  # repository root
├── macapps.xcodeproj/                    # Xcode app project
├── macapps/                              # main app target
│   ├── macappsApp.swift                  # @main, scene config
│   ├── AppViewModel.swift                # @MainActor @Observable
│   ├── Views/
│   │   ├── MenuBar/
│   │   │   ├── MenuBarContentView.swift
│   │   │   └── MenuBarPopoverView.swift
│   │   ├── MainWindow/
│   │   │   ├── MainWindowView.swift
│   │   │   ├── AppListView.swift
│   │   │   ├── AppRowView.swift
│   │   │   └── AppDetailView.swift
│   │   └── Preferences/
│   │       └── PreferencesView.swift
│   ├── Persistence/
│   │   ├── ModelContainer+Shared.swift
│   │   └── CachedApp.swift               # @Model
│   ├── macapps.entitlements
│   ├── Info.plist
│   └── Assets.xcassets/
├── macappsCore/                          # Swift Package — testable
│   ├── Package.swift
│   ├── Sources/macappsCore/
│   │   ├── (see § 4)
│   └── Tests/macappsCoreTests/
│       └── (see § 5)
├── docs/                                 # this folder
└── .gitignore
```

**Why two products:** the core scanning/version logic is pure Swift, has no
UI, and benefits massively from being runnable under `swift test` in CI without
booting the macOS app. The app target depends on `macappsCore` as a local
package.

## 3. App target configuration

### Info.plist
- `LSUIElement = YES` (no Dock icon — the app is menu-bar-first)
- `NSHumanReadableCopyright`
- `LSMinimumSystemVersion = 14.0`

### Entitlements (`macapps.entitlements`)
```xml
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
```

We do **not** enable App Sandbox because we need to:
- read arbitrary `.app` bundles under `/Applications`
- spawn `mas` and `brew` subprocesses
- read user `~/Library` for context

Hardened Runtime is enabled, but the app is not sandboxed. We are not
shipping through the Mac App Store.

### Scenes
Two scenes, both declared in `macappsApp.swift`:

1. `MenuBarExtra` — always present, `MenuBarExtraStyle.window` (popover).
2. `Window` — main detail window, opened on first launch and from the menu
   bar popover's "Show All" button.

The app should activate `accessory` policy so the menu bar item is present
even when no window is open.

## 4. macappsCore module structure

```
Sources/macappsCore/
├── Models/
│   ├── InstalledApp.swift            # struct, Sendable, Identifiable
│   ├── OutdatedStatus.swift          # enum
│   ├── InstallMethod.swift           # enum
│   ├── UpdateSource.swift            # enum
│   ├── Architecture.swift            # enum (arm64, x86_64, universal)
│   └── ScanResult.swift              # struct (apps + errors + duration)
├── Parsing/
│   ├── BundleMetadata.swift          # loads Info.plist, returns struct
│   ├── Version.swift                 # parse "1.2.3", compare, SemVer-ish
│   └── AppcastParser.swift           # XMLParser delegate for Sparkle feeds
├── Sources/
│   ├── InstallSourceDetector.swift   # MAS / Brew / Sparkle / direct
│   ├── MacAppStoreChecker.swift      # via `mas` shell
│   ├── HomebrewChecker.swift         # via `brew` shell
│   ├── SparkleChecker.swift          # HTTP + AppcastParser
│   └── HeuristicChecker.swift        # file mtime fallback
├── Engine/
│   ├── AppScanner.swift              # actor — walks dirs, produces [InstalledApp]
│   ├── OutdatednessEngine.swift      # actor — fans out checkers, combines results
│   └── CLIRunner.swift               # process spawn, timeout, JSON parse
├── Errors/
│   └── macappsError.swift
└── Public API/
    └── macappsCore.swift             # re-exports
```

### Public API surface (entry points the app calls)

```swift
public actor AppScanner {
    public init(searchPaths: [URL] = .default)
    public func scan() async throws -> [InstalledApp]
}

public actor OutdatednessEngine {
    public init(
        masChecker: MacAppStoreChecker = .live,
        brewChecker: HomebrewChecker = .live,
        sparkleChecker: SparkleChecker = .live,
        heuristicChecker: HeuristicChecker = .live
    )
    public func evaluate(apps: [InstalledApp]) async -> [UUID: OutdatedStatus]
    // UUID here is a stable hash of bundle ID — see § 6
}

public struct CLIRunner: Sendable {
    public init(timeout: TimeInterval = 5)
    public func run(_ executable: String, _ args: [String]) async throws -> CLIResult
}

public struct CLIResult: Sendable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32
}
```

## 5. macappsCore tests

```
Tests/macappsCoreTests/
├── VersionTests.swift
│   // - "1.2.3" < "1.2.4"
│   // - "1.10.0" > "1.9.0"  (NOT lexicographic)
│   // - "2.0.0-beta.1" < "2.0.0"
│   // - "1.2" == "1.2.0"
│   // - "1.2.3.4" parses
│   // - "" / "garbage" returns nil
├── AppcastParserTests.swift
│   // - parses a real Slack feed snapshot
│   // - parses a real Discord feed snapshot
│   // - parses a real Sketch feed snapshot
│   // - returns latest version
│   // - handles missing <pubDate>
│   // - handles enclosure-only items
├── MacAppStoreCheckerTests.swift
│   // - mock CLIRunner, returns outdated list, parses correctly
│   // - mas missing → returns .unknown for MAS apps
│   // - empty list → all .upToDate
├── HomebrewCheckerTests.swift
│   // - mock CLIRunner with sample brew outdated --cask --json=v2
│   // - maps cask "name" → app "bundle ID"
│   // - brew missing → .unknown
├── AppScannerTests.swift
│   // - fixture: a directory with 3 fake .app bundles
│   // - assert exact list, exact version, exact install method
│   // - skips .DS_Store and non-bundle dirs
├── InstallSourceDetectorTests.swift
│   // - bundle with _MASReceipt → .macAppStore
│   // - bundle with SUFeedURL → .sparkle
│   // - bundle in /opt/homebrew/Caskroom → .homebrew
│   // - everything else → .direct
└── CLIRunnerTests.swift
    // - successful run
    // - non-zero exit
    // - timeout
    // - executable not found
```

## 6. Data model

```swift
public struct InstalledApp: Identifiable, Hashable, Sendable {
    public let id: String                    // CFBundleIdentifier, or sha256(bundleURL) if missing
    public let name: String                  // CFBundleDisplayName ?? CFBundleName
    public let installedVersion: String      // CFBundleShortVersionString
    public let installedBuild: String?       // CFBundleVersion
    public let bundleURL: URL
    public let installMethod: InstallMethod
    public let lastModified: Date?           // bundle dir mod time
    public let architecture: Architecture?
    public let minimumSystemVersion: String?
    public let iconData: Data?               // rendered AppIcon, small (32x32 PNG)
}

public enum InstallMethod: Hashable, Sendable {
    case macAppStore
    case homebrew(caskName: String?)
    case sparkle(feedURL: URL)
    case direct
    case unknown
}

public enum OutdatedStatus: Hashable, Sendable {
    case upToDate
    case outdated(latest: String, source: UpdateSource)
    case unknown(reason: String)
    case checking
}

public enum UpdateSource: Hashable, Sendable {
    case macAppStore(appStoreID: Int?)
    case homebrew(caskName: String)
    case sparkle(feedURL: URL, latestVersion: String)
    case vendorWebsite(URL)
}

public enum Architecture: String, Sendable, Codable {
    case arm64
    case x86_64
    case universal
    case unknown
}
```

### Cached model (SwiftData, in the app target)

```swift
@Model
final class CachedApp {
    @Attribute(.unique) var bundleID: String
    var name: String
    var installedVersion: String
    var installedBuild: String?
    var bundlePath: String
    var installMethodRaw: String
    var lastModified: Date?
    var architecture: String?
    var lastSeen: Date
    var lastOutdatedStatusRaw: String?     // serialized OutdatedStatus
    var lastOutdatedLatest: String?        // the "latest version" if outdated
    var lastOutdatedSourceRaw: String?     // serialized UpdateSource
    var lastOutdatedCheckedAt: Date?
}
```

The cache is **best-effort** and **non-authoritative** — the source of truth
is always the live scan. The cache exists only to make the second scan
instant.

## 7. Data flow

### Cold path (first scan)

```
MenuBarExtra click
    │
    ▼
AppViewModel.refresh()        [MainActor]
    │
    ├─► showLoadingState()
    │
    ├─► AppScanner.scan()      [actor]
    │       └─ walks /Applications, ~/Applications
    │       └─ filters /System/Applications
    │       └─ loads Info.plist for each .app
    │       └─ returns [InstalledApp]
    │
    ├─► OutdatednessEngine.evaluate(apps:)  [actor]
    │       └─ fans out:
    │            SparkleChecker.check(for: apps.where(.sparkle))    ──► HTTP GET appcast.xml
    │            MacAppStoreChecker.check()                         ──► `mas outdated` (once)
    │            HomebrewChecker.check()                            ──► `brew outdated --cask` (once)
    │            HeuristicChecker.check(for: apps.where(.direct))
    │       └─ returns [bundleID: OutdatedStatus]
    │
    ├─► merge apps + statuses → ScanResult
    │
    ├─► write to SwiftData CachedApp
    │
    └─► @Observable update → SwiftUI re-renders
```

### Warm path (subsequent scans)

If the cache is fresh (e.g., < 1 hour old), the app shows the cached list
immediately, then runs the cold path in the background and updates the UI
when it completes. This is the "second scan finishes in < 200 ms" guarantee
in the success criteria.

## 8. Concurrency model

- **`AppScanner`** is an `actor`. It owns a `FileManager`, mutates internal
  progress state, and exposes `func scan() async throws -> [InstalledApp]`.
- **`OutdatednessEngine`** is an `actor`. It holds the four checkers and a
  reference to the current evaluation task, so the UI can cancel mid-scan.
- **Checkers** are structs (or actors if they own mutable state). They are
  `Sendable`.
- **`AppViewModel`** is `@MainActor @Observable`. It owns the `AppScanner`
  and `OutdatednessEngine` references and is the only thing SwiftUI binds to.
- **`CLIRunner`** is a struct. It uses `Process` internally and is
  fully `async`.

The view never touches the checkers directly. It calls
`AppViewModel.refresh()` and observes the resulting `ScanResult`.

## 9. Error handling policy

- **Per-app errors** are non-fatal. If one `.app` fails to parse, the scanner
  records an error, skips it, and continues. The user sees the rest of the
  list.
- **Whole-scan errors** (e.g., `/Applications` is unreadable) are surfaced in
  the UI as a banner.
- **Checker errors** (e.g., `brew` crashes) are demoted: that checker's apps
  fall back to `.unknown` for the rest of the scan.
- **No silent failures.** Every `.unknown` carries a `reason` string the UI
  can show in a tooltip.

## 10. UI/UX rules

- **App Sandbox**: off (see § 3). The app is local-only.
- **First-launch window**: opens automatically (the menu bar popover alone is
  too easy to miss).
- **Refresh button**: in the toolbar of the main window and in the menu bar
  popover.
- **Status colors**: outdated = orange, up-to-date = secondary color, unknown
  = tertiary color. No red — we don't want to alarm the user.
- **Outdated app click**: opens the update action sheet (Open in MAS / Open
  vendor site / Copy `brew upgrade` command / Open Sparkle feed URL).
- **Empty state**: a friendly "All your apps are up to date" with a refresh
  button.
- **Error state**: a banner with the specific error + a "Retry" button.
