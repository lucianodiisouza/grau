# DATA-SOURCES — What Grau scans, where, and why

Every feature in Grau reads from the filesystem. This doc enumerates
**every** path, file, and CLI that Grau touches, the safety level, and
the gotchas. The implementing AI must not invent a path; if it's not
listed here, it doesn't get scanned.

Conventions:
- `~` = the user's home directory (`$HOME`).
- All paths are subject to the standard exclusions in
  `PathExclusions.standard` (see [ARCHITECTURE.md § 4](./ARCHITECTURE.md#4-graucore-module-structure)).
- "FDA" = requires Full Disk Access. Without FDA, the path returns
  "permission denied" or empty result depending on the OS.

---

## 1. Junk cleaner categories

**Five user-facing categories** in v1. Each maps to one or more
underlying `JunkDefinition`s in
`graucore/Sources/graucore/Junk/JunkDefinition.swift`. The UI groups
them; the underlying scanner knows the granular paths.

> **Why 5 not 11:** The previous design had 11 categories (caches,
> logs, browser cache, mail attachments, iOS backups, old downloads,
> quicklook, font cache, etc). The user thinks "caches, logs, old
> downloads, iOS backups" — 4 buckets. We collapse to 5 user-facing
> categories for clarity, keeping the underlying path granularity
> where it matters (e.g. font cache is a sub-path of System Cache,
> not its own category). See [REVIEW.md S2](./REVIEW.md#3-structural-simplifications-s1s13).
>
> **Why no browser cache in v1:** clearing browser cache signs the
> user out of every site on click. Path complexity is real
> (Firefox profiles, Chromium forks). Deferred to v1.1 as an explicit
> "Clear all browser caches" opt-in. See [REVIEW.md B8](./REVIEW.md#2-correctness-bugs-b1b8).
>
> **Why no mail attachments in v1:** Mail is sandboxed on modern
> macOS (different path), and cleaning Mail attachments can break
> local IMAP cache. High cost, low benefit. Deferred indefinitely.
> See [REVIEW.md B2](./REVIEW.md#2-correctness-bugs-b1b8).

### 1.1 User Cache — `userCache`

**User-visible label:** "User Cache"
**Default selected:** YES
**Safety:** `safe`
**FDA required:** no

**Internal paths aggregated:**
- `~/Library/Caches/*` (top level, no recursion)
- Excluded: `~/Library/Caches/com.apple.*` (Apple system components
  manage these; deleting breaks things)
- Excluded: `~/Library/Caches/com.apple.bird` (iCloud's local cache)

**Sub-rules:**
- We use `URLResourceKey.totalFileAllocatedSizeKey` for the top-level
  cache entries. We do not recurse into them (recursion = slow, and
  most apps keep their cache flat).
- The size shown is the sum of all top-level cache entries.

**Gotchas:**
- Some apps write a `lock` file inside their cache dir. Trashing
  the parent dir while the app is running can corrupt the cache. The
  UI shows a generic "Quit apps before cleaning" warning; per-app
  detection is in v1.1.
- iCloud's local cache lives at
  `~/Library/Caches/com.apple.bird`. We exclude it explicitly.

### 1.2 System Cache — `systemCache`

**User-visible label:** "System Cache"
**Default selected:** YES (when FDA granted)
**Safety:** `safe`
**FDA required:** **yes**

**Internal paths aggregated:**
- `/Library/Caches/*` (top level)
- `/Library/Caches/com.apple.QuickLook.thumbnailcache/`
- `/Library/Caches/com.apple.CoreServices/CoreFontCache.*`
- `/private/var/folders/*/C/com.apple.QuickLook.thumbnailcache/`
- `/private/var/folders/*/C/com.apple.fontd/`

**Sub-rules:**
- Skip `/System/Library/Caches` (read-only at the OS level; FDA
  doesn't help).
- Show the per-top-level breakdown so the user can target
  ("QuickLook: 1.2 GB", "Dyld: 800 MB", etc).
- Font cache deletion triggers font re-indexing on next login. Show
  a "This will trigger font re-index" warning in the confirm sheet.

**Gotchas:**
- `/Library/Caches/com.apple.kext.caches` was a never-delete path on
  older macOS but **does not exist on macOS 14+**. The path audit
  (Phase 0, Task 0.8) confirms and removes from the exclusion list.
- The `/private/var/folders/.../C/` path is the per-user temp dir;
  resolve via `FileManager.default.temporaryDirectory`.

### 1.3 Logs — `logs`

**User-visible label:** "Logs"
**Default selected:** YES (when FDA granted)
**Safety:** `safe` (for `.asl` archives); `userCaution` for diagnostic
reports
**FDA required:** **yes** (for system log paths only; user logs are
in `~/Library/Logs` which doesn't need FDA)

**Internal paths aggregated:**
- `~/Library/Logs/*` (user logs; no FDA needed)
- `/private/var/log/*.asl` (Apple System Log archives)
- `/private/var/log/com.apple.*.crash` (system crash reports)
- `~/Library/Logs/DiagnosticReports/*` (user crash reports, `userCaution`)

**Sub-rules:**
- Diagnostic reports (`.crash`, `.diag`, `.ips`) are NOT selected by
  default — they're useful for debugging. User must opt in.
- `.asl` archives > 30 days old are included; newer ones are
  skipped (the system is still using them).

**Gotchas:**
- The `asl` daemon may be reading these. We can still delete — the
  daemon will just stop reading and start a new archive.

### 1.4 Old Downloads — `oldDownloads`

**User-visible label:** "Old Downloads"
**Default selected:** **NO** (opt-in only)
**Safety:** `userCaution`
**FDA required:** no

**Path:** `~/Downloads/*` (shallow, no recursion into subdirs)

**Sub-rules:**
- Default threshold: 90 days old. Configurable in Settings (key
  `grau.downloadsThresholdDays`, default 90).
- Default: **not selected**. User must explicitly check the box to
  include this category.
- Confirm sheet shows the count + size: "Move 47 files (3.2 GB)
  older than 90 days to Trash".

**Gotchas:**
- `~/Downloads` can have thousands of files. We use shallow
  `URLResourceKey.fileSizeKey` enumeration, **no recursion** into
  `~/Downloads/foo/bar.zip` — that path is not "old download", that's
  "user data inside a downloaded file."
- The user may symlink `~/Downloads` to iCloud. Detect the symlink
  and warn: "Your Downloads folder is in iCloud. Trashing files
  inside may only remove the local copy."

### 1.5 iOS Backups — `iosBackups`

**User-visible label:** "iOS Backups"
**Default selected:** **NO** (opt-in only)
**Safety:** `userCaution` (these are *backups* — deletion is data loss)
**FDA required:** no

**Path:** `~/Library/Application Support/MobileSync/Backup/*/`

**Sub-rules:**
- Default: **not selected**. User must explicitly check the box AND
  the confirm sheet lists each backup by device name.
- The UI shows: "X iOS backups, Y GB. Deletion is permanent and
  cannot be undone."
- The size is cached in `SizeCache` because this directory can be
  50+ GB and re-walking on every scan is wasteful. The cache is
  invalidated when the user adds/removes a backup (detected by mtime
  of the parent dir).

**Gotchas:**
- Each backup is a folder named with a hex hash. Display the device
  name by reading `Info.plist` inside (`<key>Display Name</key>`).
- iOS 17+ may also write backups via iCloud Drive to a different
  location. Out of scope for v1.

---

## 1.6 Trash (read-only display, NOT a junk category)

**This is NOT a `JunkCategory`.** It's a separate concept. The Trash
is shown in the dashboard and menu bar but Grau does not (and will
not) auto-empty it.

**Path:** `~/.Trash/` (resolved via `URL.resolvingSymlinksInPath()`
because on Apple Silicon with multi-volume setups, `~/.Trash` is a
symlink to the volume where the user's home lives).

**Other volumes:** walk `/Volumes/*/.Trashes/` and sum.

**What Grau shows:**
- Total size of `~/.Trash`
- File count (capped walk at 10,000 items; show "(at least N items)"
  if we cap)

**What Grau does NOT do:**
- Empty the trash.
- Show a "Open in Finder" button — the user already knows where Trash
  is. (The previous plan had this button. We removed it because the
  user value of the button is zero; the actual value is the size +
  notification. See [REVIEW.md H5](./REVIEW.md#6-hidden-risks-identified-added-to-plan-7).)

**What Grau does do:**
- Notification: "Trash has 8.2 GB waiting" when trash > 5 GB
  (state-transition dedupe).

## 2. App uninstaller

### 2.1 App detection (carried over from macapps plan)

Walk `/Applications`, `~/Applications`, `/Applications/Utilities` for
`.app` bundles. Skip `/System/Applications`.

For each bundle, parse `Contents/Info.plist` for:
- `CFBundleIdentifier`
- `CFBundleName`, `CFBundleDisplayName`
- `CFBundleShortVersionString`
- `CFBundleExecutable`

### 2.2 Residual detection

For each installed app, look for these companion paths. Every match
is a `Residual` with a `kind`.

| Kind | Path pattern | Notes |
| --- | --- | --- |
| `.preferences` | `~/Library/Preferences/<bundleID>.plist` | Always present, safe to trash |
| `.caches` | `~/Library/Caches/<bundleID>/` | Per-user app cache |
| `.appSupport` | `~/Library/Application Support/<bundleID>/` | May contain user data — `userCaution` if non-empty |
| `.logs` | `~/Library/Logs/<bundleID>/` | Safe to trash |
| `.savedState` | `~/Library/Saved Application State/<bundleID>.savedState/` | Safe to trash |
| `.cookies` | `~/Library/Cookies/<bundleID>.binarycookies` | Rare, browser-style apps |
| `.containers` | `~/Library/Containers/<bundleID>/` | Sandboxed app data — **show only, default to NOT selected** |
| `.groupContainers` | `~/Library/Group Containers/<groupID>/` where `groupID` is read from the app's `com.apple.security.application-groups` entitlement. **NOT** derived from bundle ID. | Same as containers |
| `.launchAgents` | `~/Library/LaunchAgents/<bundleID>.plist` | Active launchd job — warn before removing |

**Note: no `keychainEntries` kind.** Detecting keychain entries
safely is not possible (entries have no bundle ID), and even
*detecting* them creates a false sense that Grau can manage
passwords. Dropped. See [REVIEW.md B3](./REVIEW.md#2-correctness-bugs-b1b8).

### 2.3 Pre-uninstall helpers

Some apps ship an uninstaller:
- `<bundle>/Contents/Resources/Uninstall.app`
- `<bundle>/Contents/MacOS/<executable> --uninstall` (heuristic)

If found, the UI offers: "Run the app's built-in uninstaller first,
then I'll clean up the residual." This is a per-app choice.

### 2.4 Uninstaller gotchas

- **Bundle ID collisions**: two apps with the same bundle ID (rare
  but real) → confirm which is being uninstalled.
- **App is running**: refuse to trash, surface a "Quit X first" hint.
- **System components**: skip any bundle with `CFBundleIdentifier`
  starting with `com.apple.` unless the user explicitly opts in.
- **App store apps**: detect via `_MASReceipt` and surface "you may
  want to use the App Store to reinstall later" hint.

## 3. Disk lens

### 3.1 Roots

By default: `/` (skipping `/System`, `/private/var/db`, `/Volumes`
except `/Volumes/Macintosh HD`).

User can change roots in Settings (e.g., to scan a specific external
drive or `~/` only).

### 3.2 Standard exclusions

```swift
public enum PathExclusions {
    public static let standard: Set<String> = [
        "/System",
        "/private/var/db",
        "/.Spotlight-V100",
        "/.fseventsd",
        "/.DocumentRevisions-V100",
        "/.TemporaryItems",
        "/.Trashes",
        "/private/var/folders",   // per-user temp, scan separately if needed
    ]
}
```

### 3.3 Traversal

- One pass to compute sizes (parallel across top-level dirs).
- Build a `DiskTreeNode` tree.
- Compute treemap layout (squarified algorithm).
- Stream to the renderer.

### 3.4 Gotchas

- **Hardlinks**: a single inode can appear in many places. The
  `st_nlink` field tells us. Sum inode sizes only once.
- **Symlinks**: follow only if explicitly enabled. Default: don't.
- **Permissions**: stop at the first unreadable dir, don't try to
  elevate.
- **Time Machine backups**: `/Volumes/Backups of <machine>/` is huge
  and irrelevant. Exclude by default; user can override.

## 4. Duplicates finder

### 4.1 Pipeline

1. **Size filter.** Group files by size. Files with unique sizes are
   not duplicates.
2. **Partial-hash.** For each size group with > 1 file, hash the
   first 4 KB (using SHA256). Group by partial-hash.
3. **Full-hash.** For each partial-hash group with > 1 file, hash the
   whole file. Group by full-hash. These are the duplicate groups.
4. **Report.** Each group has all paths + the size.

### 4.2 Scope

User picks a root folder. Default: `~/`. Common additions:
`~/Documents`, `~/Pictures`, `~/Downloads`.

### 4.3 Exclusions

- Hidden files (`.` prefix)
- Files < 1 KB (too small to be worth the IO)
- Files inside any path in `PathExclusions.standard`
- `node_modules`, `.git`, `build/`, `DerivedData/`, `.venv/` —
  duplicates here are not user data

### 4.4 Selection safety

Grau enforces: **never auto-select the only copy of a file.** If a
group has only 2 files and they're in different places, default
selection is "keep the older one" (heuristic: most user-trashable
duplicates are downloads + photos, where the original is older).

The user can override per-file.

### 4.5 Gotchas

- **Symlinks**: skip. Hashing through a symlink is meaningless.
- **Resource forks / xattrs**: not hashed. v1 ignores. v2 could
  surface a warning if two files have same SHA but different xattrs.
- **Sparse files**: SHA256 reads actual content, so sparse files are
  handled correctly.
- **Network files**: skip by default (`URLResourceKey.isUbiquitousItem`).

## 5. Dev mode

### 5.1 `node_modules` finder

**Roots (configurable in Settings):**
- `~/`
- `~/Developer`, `~/Code`, `~/Projects`, `~/repos` (if they exist)
- Any path the user adds

**Detection:** any directory named `node_modules` at depth ≤ 6 from
a configured root.

**Output:** `NodeModulesInfo` per match: path, project root (parent
of `node_modules`), size, last modified.

**Safety:** `safe`. `npm install` rebuilds it.

**Gotchas:**
- A repo may have multiple `node_modules` (monorepos with workspaces).
  Group by parent project.
- `pnpm` uses content-addressable storage; the `node_modules` is
  mostly symlinks. Hashing shows the same files, but size is
  real (the symlinks point to `~/.pnpm-store` which is also scanned
  separately).

### 5.2 Package manager caches

| Kind | Path | Safety | Notes |
| --- | --- | --- | --- |
| `npm` | `~/.npm/` | safe | npm rebuilds on demand |
| `yarnClassic` | `~/Library/Caches/yarn/` | safe | yarn 1.x |
| `yarnBerry` | `~/.yarn/cache/` | safe | yarn 2+ berry |
| `pnpm` | `~/Library/pnpm/` | safe | pnpm store |
| `bun` | `~/.bun/` | safe | bun cache |
| `cocoapods` | `~/Library/Caches/CocoaPods/` | safe | pods cache |
| `carthage` | `~/Library/Caches/org.carthage.Carthage/` | safe | carthage builds |
| `swiftpm` | `~/Library/Caches/org.swift.swiftpm/`, `~/Library/org.swift.swiftpm/` | safe | SPM cache |
| `maven` | `~/.m2/` | safe | local repo + cache |
| `gradle` | `~/.gradle/` | safe | caches + wrapper dists |
| `sbt` | `~/.sbt/`, `~/.ivy2/` | safe | sbt + ivy |
| `cargo` | `~/.cargo/registry/` | safe | rust registry |
| `gem` | `~/.gem/` | safe | ruby gems |
| `pip` | `~/Library/Caches/pip/` | safe | pip cache |
| `poetry` | `~/Library/Caches/pypoetry/` | safe | poetry cache |

**FDA required:** no for any of these.

**Detection:** existence check + `FileManager.enumerator(at:)`
for size. Skip if path doesn't exist.

### 5.3 Docker inspector

**Source:** shells out to `docker system df -v`.

**Sample output:**
```
REPOSITORY                   TAG       IMAGE ID       CREATED         SIZE
myapp                        latest    abc123         2 weeks ago     1.2GB
<none>                       <none>    def456         3 weeks ago     800MB  (dangling)

CONTAINER ID   IMAGE    COMMAND   CREATED         STATUS                     NAMES
...

LOCAL VOLUMES:
VOLUME NAME    LINKS     SIZE
...

BUILD CACHE:
TYPE          TOTAL     SIZE
...

Reclaimable space: 4.2GB
```

**Parsed into `DockerInfo`:**
- `stoppedContainers: Int`
- `danglingImages: Int`
- `unusedVolumes: Int`
- `buildCacheSize: ByteSize`
- `reclaimable: ByteSize`

**Cleanup command (offered, never auto-run):** `docker system prune`.
We display the command and let the user paste it into Terminal.

**Gotchas:**
- `docker` may not be on `$PATH`. Check `which docker` first.
- Docker Desktop may not be running. The CLI will return a daemon
  error. We show "Docker daemon not running" with a hint.
- `docker system df -v` output format has been stable since Docker
  17, but parse defensively.

### 5.4 iOS Simulators

**Paths:**
- `~/Library/Developer/CoreSimulator/Devices/`
- `~/Library/Developer/CoreSimulator/Caches/`
- `~/Library/Developer/CoreSimulator/Devices/<deviceID>/data/`

**Output:** `SimulatorInfo[]`.

**Detection:** walk `Devices/*/device.plist`, parse for name +
runtime.

**Safety:** `safe` to delete the cache and the device data; v1 does
not delete the device entry itself (would require `xcrun simctl
delete`).

**Gotchas:**
- A simulator may be currently booted. Skip in the UI; offer
  "Shutdown and clean" instead.
- Sim caches can be 20+ GB. The walk is slow; show progress.

### 5.5 Xcode DerivedData

**Path:** `~/Library/Developer/Xcode/DerivedData/`

**Safety:** `safe`. Xcode rebuilds on next build.

**Gotchas:**
- May have 50+ project entries. UI shows per-project size.

### 5.6 Xcode Archives

**Path:** `~/Library/Developer/Xcode/Archives/`

**Safety:** `userCaution`. Archives are submission-ready builds;
deleting is destructive.

**Default:** shown, not selected.

---

## 6. Menu bar + notifications data sources

### 6.1 Storage state

`FileManager.default.attributesOfFileSystem(forPath: "/")` gives:
- `.systemFreeSize` (Int64)
- `.systemSize` (Int64)
- `.systemNodes` (Int64, not used)

For external volumes: walk `/Volumes` and gather the same for each
mounted `.Volume`.

### 6.2 Trash size

`FileManager.enumerator(at: ~/.Trash, includingPropertiesForKeys: [.fileSizeKey])`.
Cap at first 10,000 items to avoid runaway scans; show "(at least
N items)" if we cap.

### 6.3 Notification rules (initial set)

| Rule ID | Default | Trigger |
| --- | --- | --- |
| `junk.gt1gb` | on | After junk scan, if total > 1 GB and not yet notified today |
| `disk.full.90` | on | Volume > 90% used |
| `trash.full.5gb` | on | Trash > 5 GB |
| `grau.update` | on | Sparkle feed has a newer version |

All rules user-toggleable in Settings.

---

## 7. Self-exclusion contract

Grau does **not** touch:
- `/System` and any path under it
- `/private/var/db` (system databases)
- `.Spotlight-V100`, `.fseventsd`, `.DocumentRevisions-V100` (Apple
  metadata stores)
- Anything in `/private/var/root` (other user's home, even if sudo
  were available — we're not sandboxed but we never use elevation)
- Any file Grau itself wrote (under `~/.grau/`)
- `/System/Library/Caches` (read-only at the OS level; FDA doesn't help)
- `/private/var/folders/.../T/` (system temp, not user temp)
- Apple Intelligence caches on macOS 15+ (until we know what they
  are; tracked in v1.1)

This list is enforced in `PathExclusions.standard` and tested in
`PathExclusionsTests`.

### 7.1 The macOS 14 path audit (Phase 0, Task 0.8)

Before Phase 1 starts, the AI implementation agent **must** audit
the path list against a live macOS 14 machine. Specifically:

1. For every path in this doc, verify it exists on macOS 14.
2. Remove paths that no longer exist (e.g., the now-defunct
   `com.apple.kext.caches`).
3. Add paths that did not exist in earlier docs (e.g., Apple
   Intelligence caches on macOS 15, if developing on 15).
4. The audit is committed as a `git` change to `DATA-SOURCES.md` and
   `graucore/Sources/graucore/FS/PathExclusions.swift` with a clear
   "audited YYYY-MM-DD" note.

---

## 8. Path list (canonical, for the AI)

The complete enumeration, for copy-paste into the implementation:

```swift
public extension JunkCategory {
    var defaultDefinitions: [JunkDefinition] { ... }   // see source
}
```

The actual list lives in `graucore/Sources/graucore/Junk/JunkDefinition.swift`
and is the single source of truth. This doc describes the *intent*;
the code is the contract.

If the AI needs to add a new path, it must:
1. Add it to the source.
2. Update this doc.
3. Add a test case in `JunkScannerTests`.
4. Note the FDA requirement in the `JunkDefinition.requiresFDA` flag.
5. Set the appropriate `SafetyLevel` and `defaultSelected`.
