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

The `grau` target compiles with `SWIFT_STRICT_CONCURRENCY=complete`
(see `project.yml`). This emits Swift-6-style "main actor-isolated
X referenced from a non-isolated context" errors as **warnings** in
Swift 5.

The local build (Xcode 26.x, Swift 6) and the CI build (Xcode 15.4,
Swift 5.9) disagree on how to surface these:
- The local build often emits the warning but it's not blocking.
- The CI build with `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` would treat
  them as build failures.

To keep CI green without losing visibility, the v1.7.0 release sets
`SWIFT_TREAT_WARNINGS_AS_ERRORS=NO`. The strict-concurrency checks
still run; their output is visible in the build log; they just
don't fail the build.

### Why does this affect v1.7.0 specifically?

The pre-existing v1.6.0 view code has the same warnings (every
`@State private var vm = VMType()` where `VMType` is `@MainActor`,
and every `@ViewBuilder` computed property that touches the
`@MainActor` view model). v1.6.0 CI runs were also failing for the
same reason — they were just never investigated. v1.7.0 added more
view code, which made the noise louder.

### The proper fix (deferred to v1.7.1)

The mechanical fix is the same everywhere it occurs:

```swift
// BEFORE — non-isolated @State init evaluates @MainActor init().
// Errors under strict-concurrency.
struct SomeView: View {
    @State private var vm = SomeMainActorViewModel()
}

// AFTER — @State init happens in struct's init, which is
// implicitly @MainActor for an @main App or for any @MainActor
// struct.
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
- `grau/Features/Notifications/NotificationCenterView.swift`
- `grau/Features/Trash/TrashView.swift`

`grau/Features/Uninstaller/UninstallerView.swift` and
`grau/grauApp.swift` are already fixed in v1.7.0 (see
`fix(ci): resolve strict-concurrency errors in grauApp +
UninstallerView`).
