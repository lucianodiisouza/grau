# HANDOFF — Build order for the implementing AI

This document is the literal, ordered build plan. The implementing agent
should follow it top to bottom, ticking off checkboxes as phases complete.
If a step says "stop and ask the user", do that — do not improvise past
ambiguity.

**Conventions:**
- File paths are relative to the repo root (`/Users/lucianodiisouza/Documents/projects/macapps`).
- "Add a file at X" means create it. The exact content for the first
  several files is provided inline below; later files reference the
  architecture doc for their structure.
- "Run the tests" means `cd macappsCore && swift test`.
- "Build the app" means `xcodebuild -scheme macapps -configuration Debug build`.

---

## Phase 0 — Scaffold

Goal: an Xcode project that builds, runs, shows a menu bar icon, and opens
an empty window. Zero logic yet.

- [ ] Confirm with the user the final **app name** and **bundle ID**.
      Defaults: `macapps` / `com.targa.macapps`. If the user has a
      different preference, change these everywhere they appear in this
      doc before continuing.

- [ ] Initialize git:
      ```
      git init
      ```
      and create a `.gitignore` for Swift/macOS:
      ```
      # Xcode
      build/
      DerivedData/
      *.xcodeproj/xcuserdata/
      *.xcworkspace/xcuserdata/
      *.xcuserstate

      # Swift Package Manager
      .build/
      .swiftpm/
      Package.resolved

      # macOS
      .DS_Store
      ```

- [ ] Create the Xcode project. Two options, in order of preference:

      **Option A (recommended — scriptable):** install [XcodeGen](https://github.com/yonaskolb/XcodeGen)
      and write `project.yml` at the repo root:
      ```yaml
      name: macapps
      options:
        deploymentTarget:
          macOS: "14.0"
        bundleIdPrefix: com.targa
        developmentLanguage: en
      targets:
        macapps:
          type: application
          platform: macOS
          sources: [macapps]
          info:
            path: macapps/Info.plist
            properties:
              LSUIElement: YES
              CFBundleShortVersionString: "0.1.0"
              CFBundleVersion: "1"
              LSMinimumSystemVersion: "14.0"
          settings:
            base:
              SWIFT_VERSION: "5.9"
              PRODUCT_BUNDLE_IDENTIFIER: com.targa.macapps
              CODE_SIGN_ENTITLEMENTS: macapps/macapps.entitlements
              ENABLE_HARDENED_RUNTIME: YES
          dependencies:
            - package: macappsCore
      packages:
        macappsCore:
          path: macappsCore
      ```
      Then run `xcodegen generate`. The Xcode project appears.

      **Option B (manual):** open Xcode, File → New → Project, macOS App,
      SwiftUI, name it `macapps`, save into the current directory. Then
      File → New → Package, name it `macappsCore`, save into
      `macappsCore/`. Add the package to the app target (Project → macapps
      → Package Dependencies → + → Add Local).

- [ ] Create `macapps/macapps.entitlements`:
      ```xml
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
          <key>com.apple.security.app-sandbox</key>
          <false/>
          <key>com.apple.security.network.client</key>
          <true/>
      </dict>
      </plist>
      ```

- [ ] Create `macapps/macappsApp.swift`:
      ```swift
      import SwiftUI

      @main
      struct macappsApp: App {
          var body: some Scene {
              MenuBarExtra("macapps", systemImage: "arrow.up.app") {
                  MenuBarContentView()
              }
              .menuBarExtraStyle(.window)

              Window("macapps", id: "main") {
                  MainWindowView()
              }
              .windowResizability(.contentSize)
              .defaultSize(width: 720, height: 480)
          }
      }
      ```

- [ ] Create stub views so the project compiles:
      - `macapps/Views/MenuBar/MenuBarContentView.swift` — a `Text("macapps")` for now.
      - `macapps/Views/MainWindow/MainWindowView.swift` — a `Text("Loading…")` for now.
      - `macapps/Persistence/ModelContainer+Shared.swift` — empty for now.

- [ ] Verify: `xcodebuild -scheme macapps build` succeeds. Run the app:
      `xcodebuild -scheme macapps -configuration Debug -derivedDataPath build` and
      `open build/Build/Products/Debug/macapps.app`. A menu bar icon
      appears, a window opens.

**Acceptance:** menu bar icon visible, window opens, no crashes.

---

## Phase 1 — Scan & display

Goal: the app lists every user-installed `.app` with name, version, and
icon. No outdated detection yet.

- [ ] Create the macappsCore package files. Start with the **simplest
      pure-logic** modules first so tests are easy to write.

- [ ] `macappsCore/Sources/macappsCore/Parsing/Version.swift`:
      ```swift
      public struct Version: Equatable, Hashable, Sendable {
          public let components: [Int]

          public init?(_ string: String) { /* see spec below */ }

          public static func < (lhs: Version, rhs: Version) -> Bool {
              // numeric, NOT lexicographic, per-component
          }
      }
      ```
      Spec:
      - Strip leading `v` and trailing `-beta.1`-style pre-release.
      - Split on `.`, parse each segment as `Int` (drop non-numeric).
      - Reject empty input.
      - Compare component-by-component; longer array wins on tie.

- [ ] `macappsCore/Tests/macappsCoreTests/VersionTests.swift` covering:
      - `Version("1.2.3") < Version("1.2.4")` → true
      - `Version("1.10.0") > Version("1.9.0")` → true  *(regression: lexicographic would fail)*
      - `Version("2.0.0-beta.1") < Version("2.0.0")` → true
      - `Version("1.2") == Version("1.2.0")` → true
      - `Version("1.2.3.4")?.components == [1, 2, 3, 4]`
      - `Version("") == nil`
      - `Version("garbage") == nil`
      - `Version("v3.1")?.components == [3, 1]`

- [ ] `macappsCore/Sources/macappsCore/Models/InstalledApp.swift`,
      `OutdatedStatus.swift`, `InstallMethod.swift`, `UpdateSource.swift`,
      `Architecture.swift` — copy the structs from
      [ARCHITECTURE.md § 6](./ARCHITECTURE.md#6-data-model).

- [ ] `macappsCore/Sources/macappsCore/Parsing/BundleMetadata.swift`:
      ```swift
      public struct BundleMetadata: Sendable {
          public let bundleID: String?
          public let name: String
          public let shortVersion: String
          public let buildVersion: String?
          public let sparkleFeedURL: URL?
          public let minimumSystemVersion: String?
      }

      public enum BundleMetadataLoader {
          public static func load(_ bundleURL: URL) throws -> BundleMetadata
      }
      ```
      Implementation: open `bundleURL/Contents/Info.plist` with
      `NSDictionary(contentsOf:)`, defensively cast each field.

- [ ] `macappsCore/Sources/macappsCore/Sources/InstallSourceDetector.swift`:
      ```swift
      public enum InstallSourceDetector {
          public static func detect(
              bundleURL: URL,
              metadata: BundleMetadata,
              brewPrefixes: [URL] = [
                  URL(fileURLWithPath: "/opt/homebrew/Caskroom"),
                  URL(fileURLWithPath: "/usr/local/Caskroom"),
              ]
          ) -> InstallMethod
      }
      ```
      Logic order:
      1. If `metadata.sparkleFeedURL != nil` → `.sparkle(feedURL)`.
      2. If `bundleURL.appendingPathComponent("Contents/_MASReceipt/receipt")` exists → `.macAppStore`.
      3. If `bundleURL.path` starts with any `brewPrefixes` path → `.homebrew(caskName: token)`.
      4. Else `.direct`.

- [ ] `macappsCore/Sources/macappsCore/Engine/AppScanner.swift`:
      ```swift
      public actor AppScanner {
          public init(
              searchPaths: [URL] = [
                  URL(fileURLWithPath: "/Applications"),
                  URL(fileURLWithPath: "/Applications/Utilities"),
                  FileManager.default.homeDirectoryForCurrentUser
                      .appendingPathComponent("Applications"),
              ]
          )

          public func scan() async throws -> [InstalledApp]
      }
      ```
      Implementation:
      1. For each search path, list `.app` directories (skip hidden, skip
         `Contents/`, skip non-bundle items).
      2. For each `.app`, call `BundleMetadataLoader.load`.
      3. Call `InstallSourceDetector.detect`.
      4. Render icon: `NSWorkspace.shared.icon(forFile:)` then
         `tiffRepresentation` → PNG → `Data`. Downscale to 32×32.
      5. Read `mtime` of the bundle directory.
      6. Read architecture from the binary's `lipo` if `lipo -archs` works;
         else `nil`.
      7. Return `[InstalledApp]`. On per-app error, log + skip.

      **Filter system apps:** the search paths already exclude
      `/System/Applications`, so this is implicit. Add an explicit guard
      that rejects any path starting with `/System/`.

- [ ] `macappsCore/Tests/macappsCoreTests/AppScannerTests.swift` with a
      fixture directory `Tests/Fixtures/Apps/` containing 3 minimal `.app`
      bundles you create in the test setup. Assert the scanner returns
      the expected 3 apps with the right version, name, install method.

- [ ] App target: `AppViewModel.swift`:
      ```swift
      import Foundation
      import Observation
      import macappsCore

      @MainActor
      @Observable
      final class AppViewModel {
          private(set) var apps: [InstalledApp] = []
          private(set) var isLoading = false
          private(set) var lastError: String?

          private let scanner = AppScanner()

          func refresh() async {
              isLoading = true
              defer { isLoading = false }
              do {
                  apps = try await scanner.scan()
                  lastError = nil
              } catch {
                  lastError = error.localizedDescription
              }
          }
      }
      ```

- [ ] App target: `AppViewModel` is owned by `macappsApp` as a
      `@State` and injected via `.environment(viewModel)`.

- [ ] `MainWindowView.swift` calls `viewModel.refresh()` in `.task` and
      renders a `List` of `apps` showing name + version + icon.

- [ ] **Verify** the app lists installed apps with icons. Cross-check
      against Finder: count should match `/Applications` (minus hidden
      ones).

**Acceptance:** scan completes in < 2 s for a 100-app Mac; UI shows
name, version, icon for each; system apps excluded.

---

## Phase 2 — Sparkle outdated detection

Goal: Sparkle-enabled apps show correct `.upToDate` / `.outdated` status.

- [ ] `macappsCore/Sources/macappsCore/Parsing/AppcastParser.swift`:
      Use `XMLParser` with a delegate that captures the
      `sparkle:shortVersionString` and `pubDate` of each `<item>`. The
      output is `[AppcastItem]`, newest first (assume document order is
      newest-first, which is the Sparkle convention).

- [ ] `macappsCore/Sources/macappsCore/Sources/SparkleChecker.swift`:
      ```swift
      public struct SparkleChecker: Sendable {
          public let session: URLSession
          public let timeout: TimeInterval

          public init(session: URLSession = .shared, timeout: TimeInterval = 10) {
              self.session = session
              self.timeout = timeout
          }

          public func check(
              apps: [InstalledApp],
              metadata: [String: BundleMetadata]   // bundleID → metadata
          ) async -> [String: OutdatedStatus]     // bundleID → status
      }
      ```
      Behavior:
      - Filter `apps` to `.sparkle` install method.
      - For each, fetch `metadata.sparkleFeedURL`, parse appcast, compare
      latest with installed.
      - On error, return `.unknown(reason: "<error>")` for that app.
      - Concurrency: 6 in flight.

- [ ] `macappsCore/Tests/macappsCoreTests/AppcastParserTests.swift` with
      fixture XML files in `Tests/Fixtures/Appcasts/`. Cover:
      - Slack-style feed (typical)
      - Discord-style feed (with `<enclosure>` only, no `sparkle:shortVersionString`)
      - Sketch-style feed (with `<sparkle:minimumSystemVersion>`)
      - 1-item feed
      - Garbage XML
      - Empty channel
      - JSON variant (`Tests/Fixtures/Appcasts/sample.appcast.json`)

- [ ] `OutdatednessEngine.swift` (see ARCHITECTURE.md § 4) — fanning out
      SparkleChecker for `.sparkle` apps, returning the others as
      `.upToDate` placeholder for now (Phase 1+2 only).

- [ ] App target: `AppViewModel.refresh()` now calls
      `OutdatednessEngine.evaluate(apps:)` and stores the resulting
      `[bundleID: OutdatedStatus]` alongside `apps`. `AppRowView` reads
      the status and shows the appropriate badge / color.

- [ ] **Verify** by hand: install Slack, wait for a known-outdated
      version, run macapps, see `.outdated`. Then update Slack via Slack's
      own updater, run macapps again, see `.upToDate`.

**Acceptance:** at least 3 real Sparkle apps on the user's machine
classified correctly. All `AppcastParserTests` pass.

---

## Phase 3 — MAS + Homebrew outdated detection

Goal: MAS and Homebrew Cask apps classified correctly when their CLIs are
present; gracefully `.unknown` when not.

- [ ] `macappsCore/Sources/macappsCore/Engine/CLIRunner.swift`:
      ```swift
      public struct CLIRunner: Sendable {
          public let timeout: TimeInterval

          public init(timeout: TimeInterval = 5) { self.timeout = timeout }

          public func run(
              _ executable: URL,
              _ arguments: [String],
              environment: [String: String]? = nil
          ) async throws -> CLIResult

          public func which(_ name: String) -> URL?     // resolves via PATH
      }
      ```
      Implementation: wrap `Process` with `Pipe`s for stdout/stderr,
      `terminationHandler` for async completion, `DispatchSemaphore` (or
      a `withCheckedThrowingContinuation`) to bridge to `async`. Set
      `qualityOfService = .userInitiated`. Enforce timeout via
      `process.terminate()` after `timeout` seconds.

- [ ] `macappsCore/Sources/macappsCore/Sources/MacAppStoreChecker.swift`:
      - On init, `CLIRunner.which("mas")`. If `nil`, all MAS apps return
        `.unknown(reason: "Install mas: brew install mas")`.
      - Otherwise, run `mas outdated`, parse stdout, build
        `[name: (id, installedVersion)]`.
      - For each input MAS app, look up by name (case-insensitive),
        classify.
      - Cross-check: an app **not** in the outdated list is `.upToDate`
        only if the same name appears in `mas list`. Otherwise `.unknown`.

- [ ] `macappsCore/Sources/macappsCore/Sources/HomebrewChecker.swift`:
      - On init, `CLIRunner.which("brew")`. If `nil`, all brew apps
        return `.unknown(reason: "Install Homebrew: https://brew.sh")`.
      - Otherwise, run `brew outdated --cask --json=v2` once. Decode JSON
        into a struct.
      - For each input brew app, look up by cask name (extracted from
        bundle path). Classify.
      - To get the "current version" for up-to-date apps, run
        `brew list --cask --json=v2` and match by token.

- [ ] `macappsCore/Tests/macappsCoreTests/MacAppStoreCheckerTests.swift`
      and `HomebrewCheckerTests.swift` with mock `CLIRunner` returning
      canned stdout. Test all four cases per checker:
      - CLI missing
      - CLI present, app is outdated
      - CLI present, app is up-to-date
      - CLI present, app not in any list (unknown)

- [ ] Update `OutdatednessEngine` to call all four checkers and merge
      results.

- [ ] App target: refresh now invokes the full engine. The UI shows
      `.outdated` / `.upToDate` / `.unknown` for every app.

- [ ] **Verify** on a real machine that has at least one MAS app and
      one brew cask out of date. Confirm correct classification.

**Acceptance:** MAS + Brew apps classified correctly. Without the CLIs,
the app still works and surfaces the install hint. All unit tests pass.

---

## Phase 4 — Polish

Goal: the app is pleasant to use, has preferences, and is packageable.

- [ ] **Menu bar popover:** shows count of outdated apps + a list of the
      top 10 outdated apps + a "Show All" button + a "Refresh" button.
      The icon shows a small numeric badge if there are outdated apps
      (use `MenuBarExtra` with a custom label, or an SF Symbol with a
      `Text("\(count)")` overlay).

- [ ] **Main window filters / sort:**
      - Search bar (filter by name).
      - Sort by: name, install method, status, mtime.
      - Filter chips: All / Outdated / Up-to-date / Unknown.

- [ ] **App detail panel:** clicking a row in the main window opens a
      side panel with: bundle path, install method, full version info,
      "Open in Finder", and a context-aware action button:
      - MAS: "Open in Mac App Store" → `NSWorkspace.open(URL("macappstore://..."))`
      - Brew: "Copy `brew upgrade --cask <name>`" → copies to clipboard,
        or opens Terminal at that command.
      - Sparkle: "Open vendor page" → opens `feedURL`'s host.
      - Direct: "Open vendor page" if a known vendor prefix, else
        "Open in Finder".

- [ ] **Preferences window:** (cmd+,)
      - Refresh interval (manual only in v1, but show "Coming soon" for
        auto).
      - Ignored apps list (bundle IDs the user wants to skip).
      - Reset cache button.

- [ ] **SwiftData cache:** add a `CachedApp` `@Model` (see ARCHITECTURE.md
      § 6) and write to it after each scan. On launch, load the cache
      synchronously (it's tiny — at most a few hundred rows), display
      immediately, then trigger a background refresh.

- [ ] **Empty / error states:**
      - All up-to-date → "🎉 Everything is up to date"
      - No apps found (rare) → "Couldn't find any apps in /Applications"
      - Scan error → banner with retry button

- [ ] **App icon:** a custom `.icns` for the bundle. v1: a simple
      gradient + arrow-up glyph generated with `iconutil` from a single
      1024×1024 PNG. Place in `macapps/Assets.xcassets/AppIcon.appiconset/`.

- [ ] **Code signing:** set up a personal "Developer ID Application"
      certificate (the user does this once; document the steps in
      `docs/SIGNING.md`). For v1, ad-hoc / unsigned is acceptable.

**Acceptance:** every item in the success criteria in PLAN.md § 4 is
checked off. Manual run-through on the user's actual Mac passes.

---

## Phase 5 — Ship (optional in v1, recommended for v2)

- [ ] **DMG packaging:** a `make-dmg.sh` script using `create-dmg` that
      produces a `.dmg` with a drag-to-Applications background.
- [ ] **Notarization:** `xcrun notarytool submit` with App Store Connect
      API key.
- [ ] **Sparkle self-update:** add Sparkle to the app target, point at
      a GitHub Releases feed. (Out of scope for v1; doc this in
      `docs/V2-SELF-UPDATE.md`.)
- [ ] **Homepage / landing page:** a single static page with screenshot
      and a download link. Defer to v2.

---

## Manual test checklist (run before declaring done)

Run these on the user's actual Mac. Tick each one.

- [ ] App launches without crash. Menu bar icon appears. No Dock icon.
- [ ] Window opens. List populates within 2 s.
- [ ] System apps are NOT in the list.
- [ ] Clicking a Sparkle-outdated app shows the right action button.
- [ ] Clicking a brew-outdated app copies the right upgrade command.
- [ ] Clicking a MAS-outdated app opens the App Store.
- [ ] Refresh button works. Pressing it twice in a row is safe (no
      crashes, no double-fire).
- [ ] Quitting the app and relaunching: cached apps appear instantly,
      then a background refresh updates them.
- [ ] Run on a Mac with no `mas` and no `brew`: app still works, MAS
      and Brew apps show `.unknown` with install hints.
- [ ] `cd macappsCore && swift test` passes.
- [ ] `xcodebuild -scheme macapps -configuration Debug build` succeeds.
- [ ] `xcodebuild -scheme macapps -configuration Release build` succeeds.

---

## Open questions for the implementing AI

If you hit any of these, stop and ask the user:

1. **App name / bundle ID** — already asked in Phase 0. If still
   unresolved, default to `macapps` / `com.targa.macapps` and continue.
2. **App icon design** — defer; use a default SF Symbol in v1.
3. **Distribution** — direct download (DMG), Homebrew Cask for
   macapps itself, or both. Defer to v2.
4. **Telemetry** — none in v1. Confirm if the user wants any usage
   analytics.

If you hit anything not on this list, use your judgment — the architecture
and data-source docs are explicit enough that most decisions are made
already.
