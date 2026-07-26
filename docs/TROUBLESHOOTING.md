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
