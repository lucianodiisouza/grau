# Troubleshooting

Common issues and fixes.

## "Grau can't be opened because the developer cannot be verified"

Gatekeeper blocks apps that aren't notarized. Two options:

1. **Right-click → Open** the first time. macOS will offer to open
   it anyway. This setting sticks for subsequent launches.
2. Build from source (the `xcodebuild` flow uses ad-hoc codesigning
   by default).
3. Notarize a release build: `./scripts/notarize.sh dist/Grau-1.0.0.dmg`.

## "Junk scan returned 0 results in System Caches"

Full Disk Access (FDA) is required to read `/Library/Caches`,
`/private/var/log`, etc. Open **System Settings → Privacy &
Security → Full Disk Access** and toggle Grau on. Quit and
relaunch.

## "Simulators tab is empty"

The simulators folder is `~/Library/Developer/CoreSimulator/`,
which Xcode creates the first time you run a simulator. Open
Xcode → Window → Devices and Simulators → download a runtime.

## "Docker tab says daemon not running"

Docker Desktop must be running for `docker system df -v` to
respond. Start Docker Desktop and tap Refresh.

## "Duplicates scan is taking forever"

Sequential hashing of every file in a large `~/` can take 5+
minutes. As of v1, hashing is per-phase (not per-file-parallel);
v1.1 will parallelize. For a faster first run, scan a sub-tree
like `~/Downloads` instead of the whole home.

## "I trashed something by mistake"

`~/.Trash/`. Grau writes a JSON manifest to
`~/.grau/trash-manifests/<timestamp>.json` for every clean.
Open Finder, drag the file back out. The manifest tells you the
original path and what was moved alongside it.

## "Notifications are spamming me"

Grau uses state-transition dedupe (see
`docs/ARCHITECTURE.md` § 7): a notification only fires when a
threshold is crossed *upward*. If you genuinely see duplicates:

1. Open System Settings → Notifications → Grau and ensure
   notification style is set correctly.
2. Reset Grau notifications: `defaults delete app.grau.mac grau.rule.*`
   then relaunch.

## "App uses a lot of RAM after a long session"

Known v1 limitation. The duplicate scanner holds the hash map
in memory. Quit and relaunch to free it. v1.1 will stream-hash
and store the map on disk.

## "Dev Mode is not in the sidebar"

Hidden by default. Enable via **Settings → Developer → Show
developer features**. The setting is stored as
`defaults write app.grau.mac grau.devModeEnabled -bool true`.

## "Build fails with 'No such module graucore'"

The Xcode project is generated. Re-run:

```bash
xcodegen generate
xcodebuild -project grau.xcodeproj -scheme grau -configuration Debug build
```

If that doesn't help, `cd graucore && swift build` first to
warm the package cache.

## "SwiftLint is reporting warnings"

Grau does not use SwiftLint in v1. If you do, the config in
`.swiftlint.yml` (if you added one) should align with the
existing patterns: 4-space indent, trailing commas in
multi-line collections, sorted imports.

## Strict-concurrency warnings in the grau target

The `grau` target compiles with `SWIFT_STRICT_CONCURRENCY=minimal`
(see `project.yml`). The original setting was `complete`, but in
Swift 5 it emits Swift-6-style "main actor-isolated X referenced
from a non-isolated context" as **errors** that the CI macos-14
runner (Xcode 15.4, Swift 5.9) flags but local Xcode 26.x is
lenient about. v1.7.0 surface area grew the noise past the point
where `targeted` was tolerable (still emitted 20+ errors via
"call to main actor-isolated initializer in a synchronous
nonisolated context" for the `@State private var vm = VMType()`
pattern), so we dropped to `minimal` to unblock v1.7.0.

`minimal` keeps only Sendable checks — the actually-dangerous
data-race safety net. Actor-isolation enforcement is restored
either by:

1. **Migrating to Swift 6**, which makes `@State private var vm
   = VMType()` an actual error and forces the proper init pattern.
2. **Manually rewriting every View** to use `_vm = State(...)` in
   a custom `init()` and to mark every `@ViewBuilder` property
   `@MainActor`. This is the v1.7.1 plan; see "The proper fix"
   below.

The pre-existing v1.6.0 view code has the same `@State`-with-`@MainActor`
pattern. CI runs for v1.6.0 were failing for the same reason but
the failures were never investigated. v1.7.0 added more view code
(the Automation sidebar), which made the noise louder and triggered
someone to actually look at CI.

### The proper fix (deferred to v1.7.1)

The mechanical fix is the same everywhere it occurs:

```swift
// BEFORE — non-isolated @State init evaluates @MainActor init().
// Errors under strict-concurrency=complete/targeted.
struct SomeView: View {
    @State private var vm = SomeMainActorViewModel()
}

// AFTER — @State init happens in struct's init, which is
// implicitly @MainActor for a SwiftUI View.
struct SomeView: View {
    @State private var vm: SomeMainActorViewModel
    init() {
        _vm = State(wrappedValue: SomeMainActorViewModel())
    }
}
```

And on every `@ViewBuilder` computed property that touches the
`@MainActor` view model:

```swift
@ViewBuilder
@MainActor
private var someSheet: some View { ... }
```

And on every `Task { ... }` that captures `self` (the non-Sendable
View struct):

```swift
// BEFORE — captures self in a @Sendable closure.
DestructiveButton("Go") {
    Task { await vm.confirm() }
}

// AFTER — capture vm explicitly.
DestructiveButton("Go") {
    let vm = vm
    Task { await vm.confirm() }
}
```

Affected files as of v1.7.0:

- `grau/Features/Automation/AutomationView.swift`
- `grau/Features/Dashboard/DashboardView.swift`
- `grau/Features/DevMode/DevModeView.swift`
- `grau/Features/JunkCleaner/JunkCleanerView.swift`
- `grau/Features/MenuBar/MenuBarContentView.swift`
- `grau/Features/Notifications/NotificationCenterView.swift`
- `grau/Features/Settings/SettingsView.swift`
- `grau/Features/Trash/TrashView.swift`
- `grau/Features/Uninstaller/UninstallerView.swift`

`grau/Features/Uninstaller/UninstallerView.swift` and
`grau/grauApp.swift` already have the proper `@State` pattern
in v1.7.0 (see `fix(ci): resolve strict-concurrency errors in
grauApp + UninstallerView`).
