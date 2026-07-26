# PERMISSIONS — Full Disk Access, TCC, and Grau's onboarding story

This doc is the contract between Grau and the macOS security model. It
is exhaustive. If the AI ever wonders "do I have permission to read X?"
the answer is in this doc.

The TL;DR: **Grau needs Full Disk Access (FDA) to do its job** —
specifically, to read system caches, system logs, and Mail data. The
user grants this once via System Settings, and Grau checks it on every
relevant operation.

---

## 1. Why this doc exists

CleanMyMac-style apps live or die by the permission story. Get it
wrong and the user sees "permission denied" errors with no clear path
forward. Get it right and the user understands the trade-off and
makes an informed decision.

Apple's Transparency, Consent, and Control (TCC) framework controls
which apps can read which data. The mapping is non-obvious:

| Path | FDA needed? | Why |
| --- | --- | --- |
| `~/Library/Caches/*` | no | User's own home |
| `~/Library/Logs/*` | no | User's own home |
| `~/Library/Mail/*` | no (but Mail data is in `~/Library/Containers/com.apple.mail/`) | Depends on the subpath |
| `~/Library/Application Support/MobileSync/Backup/` | no | User's own home |
| `/Library/Caches/*` | **yes** | Shared system location |
| `/private/var/log/*` | **yes** | System log location |
| `/private/var/folders/.../C/` | **yes** | System-managed temp dirs |
| `~/.Trash` | no | User's own home |
| `/Volumes/*` | no (other users' files still need permission) | Volume roots are readable |
| Other apps' sandboxes (e.g., `~/Library/Containers/<other-bundle>/`) | **yes** | Cross-app data |

**The unifying rule:** TCC protects shared system locations
(`/Library`, `/private/var/...`) and cross-app data. Data inside the
user's own `~/Library` is freely readable *except* inside
`Containers/` and `Group Containers/` of other apps' sandboxes.

---

## 2. Full Disk Access (FDA)

### 2.1 What it does

When the user grants Grau Full Disk Access via System Settings →
Privacy & Security → Full Disk Access, Grau can:

- Read any file under `/Library`, `/private/var/`, `/private/etc/`,
  etc. — paths the OS normally hides from non-FDA apps.
- Read the contents of any other app's `~/Library/Containers/<id>/`
  sandboxed data.
- Read Mail data (which lives inside Mail's container).
- Read Safari data (history, downloads, etc.).
- Read system logs.

### 2.2 What it does NOT do

- It does **not** grant write access to `/System`, `/usr`, `/bin`,
  `/sbin`. These are read-only at the OS level (SIP).
- It does **not** grant the ability to elevate with `sudo`.
- It does **not** grant access to other users' files (per-user
  permissions still apply).
- It does **not** grant Accessibility (separate permission).
- It does **not** grant Automation / AppleEvents (separate
  permission).

### 2.3 How the user grants it

The flow is:

1. Grau shows a primer screen explaining "Grau needs Full Disk
   Access to clean system caches. You'll be sent to System Settings."
2. Grau calls `NSWorkspace.shared.open(URL("x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"))`.
3. The user finds Grau in the list, toggles it on, enters
   Touch ID / password.
4. Grau restarts itself (or asks the user to relaunch — actually
   the OS invalidates open file handles but the app doesn't need
   to be relaunched; subsequent reads just work).
5. Grau verifies by attempting a known-FDA-required read
   (e.g., listing `/Library/Caches/`).

This is the only onboarding step that has friction. It is worth the
friction.

### 2.4 How Grau checks FDA status

```swift
public actor PermissionChecker {
    public func hasFullDiskAccess() -> Bool {
        // Heuristic: try to read a known-FDA-protected path.
        // If the listing is empty or throws EACCES, FDA is missing.
        let testPath = URL(fileURLWithPath: "/Library/Application Support/com.apple.TCC")
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: testPath, includingPropertiesForKeys: nil
            )
            return !contents.isEmpty
        } catch {
            return false
        }
    }
}
```

**Caveat:** this is a heuristic. The real "TCC.db" check is more
complex and uses `tccutil`. v1 uses the heuristic; v2 may use the
real check.

### 2.5 The "limited mode"

If the user does not grant FDA, Grau still works in **limited mode**:

- Junk categories with `requiresFDA: true` are shown as
  "Permission required" with a "Grant" button.
- All other features work normally.
- A persistent banner in the dashboard reads: "Grau is in limited
  mode — grant Full Disk Access to clean system caches."

This is the "no FDA = useless app" risk from PLAN § 7, mitigated.

---

## 3. Other permissions

### 3.1 Accessibility (AX)

**Used by:** nothing in v1.

**Why we don't need it:** Grau does not drive other apps' UIs. We
read files and the file system; we don't script Finder or other apps.

**v2 might need AX for:** "click this button in app X to enable
something." Out of scope for v1.

### 3.2 Automation / AppleEvents

**Used by:** nothing in v1.

**Grau does not send AppleEvents.** We use `FileManager.trashItem`,
not `NSWorkspace.dispose`, so no Automation prompt is ever shown.
The previous draft of this doc claimed we "never send arbitrary
AppleEvents" but also implied we did; that was a contradiction. The
correct statement is: **we don't use AppleEvents at all in v1**.

If a future v2 feature needs to script Finder (e.g., "Empty Trash"
button that uses Finder's Empty Trash command), that feature
triggers an Automation prompt and must be added to a "Future" doc
section, not silently introduced.

### 3.3 Notifications

**Used by:** the menu bar notifications.

**How we request it:** on first launch, Grau calls
`UNUserNotificationCenter.current().requestAuthorization(options:)`.
Default: on. User can disable per-rule in Settings.

### 3.3.1 Notification dedupe — state-transition rule

The previous draft of this doc was ambiguous about "when does a
notification re-fire after firing once." The locked-in rule is
**state-transition dedupe**:

A notification for a rule fires **only when the rule's value
transitions from below-threshold to above-threshold**. Once fired,
it does not fire again until:

1. The value has dropped below the threshold (e.g., user emptied
   the trash), AND
2. The value has crossed above the threshold again.

Per-rule state is persisted in `UserDefaults`:
- `grau.rule.<id>.lastFiredAt: Date` — when the rule last fired
- `grau.rule.<id>.lastValue: Double` — the value at last fire (used
  to detect the down-then-up transition)

This is what "fires once per day" really means: at most one
notification per crossing event, regardless of how often we tick
`VolumeMonitor`. See [REVIEW.md B6](./REVIEW.md#2-correctness-bugs-b1b8).

### 3.4 File & folder access (out-of-sandbox)

**Used by:** every feature.

**How it works:** Grau is not sandboxed (`com.apple.security.app-sandbox = false`).
We can read any path the OS user can read. The entitlement
`com.apple.security.files.user-selected.read-write` is for when the
user picks a file via `NSOpenPanel` — we still need it for that.

### 3.5 Network

**Used by:** Docker (`docker system df` is local, but Sparkle and
future features hit the network).

**Entitlement:** `com.apple.security.network.client = true`.

**Specific hosts:**
- Sparkle: `https://api.github.com/repos/<owner>/<repo>/releases/latest`
- v1 only. Documented in `graucore/NetworkAllowlist.swift`.

---

## 4. Permission states and Grau UI

The `PermissionState` is a single observable that the UI binds to:

```swift
public struct PermissionState: Equatable, Sendable {
    public var fullDiskAccess: Bool
    public var notifications: NotificationPermission
    public var appleEventsPromptedForFinder: Bool
}

public enum NotificationPermission: Equatable, Sendable {
    case notRequested
    case denied
    case provisional
    case authorized
}
```

This is checked on app launch, after the FDA primer, and after the
notification authorization request.

### 4.1 Where the UI surfaces permission state

- **Dashboard banner** (if `!fullDiskAccess`): "Grau is in limited
  mode. Grant Full Disk Access to unlock system cleanup."
- **Junk cleaner**: each FDA-required category has a "Permission
  required" badge and a "Grant & scan" button.
- **Settings → Privacy**: a section listing each permission with a
  status + button to open System Settings or re-request.

### 4.2 Where the UI does NOT show permission state

- We do **not** show a permission modal on first launch. The user
  can explore the app first; the primer only appears when they
  try to do something that needs FDA.
- We do **not** nag. The dashboard banner is dismissible per-session.

---

## 5. The FDA primer screen (design)

The primer is a 3-step flow:

1. **Welcome.** "Grau cleans your Mac by reading caches and
   system files. To do that safely, it needs Full Disk Access."
   With a screenshot of the System Settings screen.

2. **What you'll do.** "Click 'Open System Settings' below. Find
   Grau in the list, toggle it on, and enter your password."
   With a screenshot of the toggle.

3. **Done.** "You're all set. Grau is now in full mode." With a
   green checkmark and a "Get started" button.

The primer is **dismissible**. The user can skip it and stay in
limited mode.

---

## 6. The "Grant" button behavior

When the user clicks any "Grant Full Disk Access" button:

```swift
@MainActor
func openFDASettings() {
    let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
    NSWorkspace.shared.open(url)
    // Schedule a re-check in 5s, then every 2s, up to 60s
    Task {
        for delay in [5, 7, 9, 12, 16, 22, 30, 45, 60] {
            try? await Task.sleep(for: .seconds(delay))
            let granted = await permissionChecker.hasFullDiskAccess()
            if granted {
                permissionState.fullDiskAccess = true
                return
            }
        }
        // Timed out — user didn't grant. Show a "still missing"
        // hint and stop polling.
    }
}
```

The polling is graceful: no UI freeze, no aggressive popup.

---

## 7. Code signing, notarization, and permissions

Even though Grau is not sandboxed, **hardened runtime is on**. The
notarization process requires:

- `com.apple.security.cs.allow-jit` = false (we don't use JIT)
- `com.apple.security.cs.allow-unsigned-executable-memory` = false
- `com.apple.security.cs.disable-library-validation` = false
- `com.apple.security.cs.allow-dyld-environment-variables` = false

We use no exceptions. If we later need one (e.g., for a helper
tool), we add it with a comment explaining why.

For the v1 build, the app is **ad-hoc signed locally** for the
developer's own use. The CI / release build uses a personal
Developer ID and notarizes via `xcrun notarytool`.

---

## 8. Sandbox vs. no-sandbox trade-off (locked decision)

We chose **no sandbox** because:

- We need to spawn `docker` and other CLIs as subprocesses. The
  App Sandbox makes subprocess execution painful.
- We need to read arbitrary paths under `~/Library/Containers/<id>/`
  for other apps. Sandbox would block this.
- We need to write to the user's Trash. Sandbox forces a
  security-scoped bookmark per file, which is impractical for
  thousands of files.

The trade-off:
- **Pro:** we can do our job. Less code, more capability.
- **Con:** we cannot ship through the Mac App Store. We ship
  directly via DMG + Homebrew Cask. Acceptable for a free OSS
  utility.

If a future v3 wants MAS distribution, the architecture needs a
significant rework (probably a privileged helper for FDA-equivalent
operations). Not in v1.

---

## 9. Permission tests

`graucore/Tests/graucoreTests/PermissionCheckerTests.swift`:

- Mock the file system. Return canned `contentsOfDirectory` results.
- Test:
  - `hasFullDiskAccess()` returns `true` when the test path is
    non-empty.
  - Returns `false` when the test path is empty.
  - Returns `false` when the test path throws (permission denied).
  - Returns `false` when the test path doesn't exist.

These tests verify the heuristic, not TCC itself. The real TCC
behavior is verified manually on a developer's machine.

---

## 10. What we never do

Grau **never**:

- Calls `tccutil` to manipulate other apps' permissions.
- Sends AppleEvents (we use `FileManager.trashItem` instead of
  `NSWorkspace.dispose`, so no Automation prompt).
- Asks for Accessibility (we don't need it).
- Asks for Full Access to Contacts, Calendars, Photos, Camera,
  Microphone, etc. (we don't need any of them).
- Stores or transmits the user's data anywhere. Grau is local-only.
- Asks for the user's password. Ever. (We don't need elevation.)
- Modifies `/etc/`, `/System/`, `/usr/`. (FDA doesn't even allow this.)

If a feature needs any of these, it does not ship in v1.
