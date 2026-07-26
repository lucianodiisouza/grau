# MANUAL-TEST — Grau pre-release checklist

This is the manual test plan we run before tagging any beta or 1.0.
Each row is a single check. Each phase adds 3–5 rows as features
land. Run through this end-to-end on a clean machine before tagging
the corresponding release.

## Conventions

- ✓ = pass
- ✗ = fail (file a bug in `docs/BUGS.md` and either fix it or defer
  to v1.1)
- `N/A` = not applicable to this build
- "FDA" = Full Disk Access (System Settings → Privacy & Security →
  Full Disk Access)

## Setup

- [ ] Test machine: a Mac running macOS 14.x or 15.x.
- [ ] Build: `xcodebuild -scheme grau -configuration Release build`
      from the repo root.
- [ ] App launches from the built `.app` bundle.
- [ ] No pre-existing `~/.grau/` directory (or back it up first).

## Phase 0 — Scaffold (alpha)

- [ ] App launches without crash.
- [ ] Menu bar icon appears in the menu bar (no Dock icon).
- [ ] Main window opens, dashboard renders.
- [ ] Greeting shows correct time-of-day (morning/afternoon/evening).
- [ ] Storage card renders with the fake "237.4 GB / 500.1 GB" data.
- [ ] StorageBar visualizes the used/free ratio correctly.
- [ ] Trash card renders with "8 items / 142 MB" placeholder.
- [ ] Last scan card renders with "Never" placeholder.
- [ ] Quick actions row renders with 4 buttons (Scan Junk enabled,
      others visibly disabled).
- [ ] Sidebar lists Dashboard, Clean, Uninstaller, Disk Lens,
      Duplicates, Settings (Dev Mode hidden by default).
- [ ] Sidebar Dev Mode toggle (in Settings) makes the Dev Mode item
      appear/disappear.
- [ ] Sidebar selection switches the detail view.
- [ ] Dark mode: `defaults write -g AppleInterfaceStyle Dark` — colors
      flip correctly. Reset with `Light`.
- [ ] `cd graucore && swift test` — placeholder tests pass.
- [ ] `xcodebuild -scheme grau -configuration Debug build` —
      succeeds without warnings.
- [ ] `xcodebuild -scheme grau -configuration Release build` —
      succeeds without warnings.
- [ ] CI: GitHub Actions workflow goes green on a dummy commit.

## Phase 1 — Junk cleaner (beta 1)

### Onboarding

- [ ] On first launch (no `grau.onboarded` flag in UserDefaults),
      the Onboarding view shows (not the dashboard).
- [ ] Onboarding "Continue" button advances through 3 screens.
- [ ] "Skip" or "Get started" sets `grau.onboarded = true` and
      shows the dashboard on next launch.

### FDA primer (after onboarding or when FDA is needed)

- [ ] Tapping "Open System Settings" opens the Privacy pane.
- [ ] After granting FDA, the primer auto-detects within 10s and
      shows the "All set" state.
- [ ] If the user does not grant, the "Still waiting?" state
      remains visible and the "Open System Settings" button is
      available to retry.

### Clean tab

- [ ] Auto-scans on first appearance of the Clean tab.
- [ ] All 5 categories appear with checkboxes.
- [ ] User Cache, System Cache, and Logs default to selected.
- [ ] Old Downloads and iOS Backups default to NOT selected.
- [ ] System Cache and Logs show "Permission required" pill when
      FDA is not granted, and their rows are disabled.
- [ ] Categories that are userCaution show an "Opt-in" pill
      (yellow).
- [ ] Categories that are safe show a "Safe" pill (green).
- [ ] Each row shows the size in human-readable format.
- [ ] Bottom bar: "X selected, Y GB to free" with a "Clean Selected"
      button.
- [ ] "Clean Selected" is disabled when nothing is selected or
      total size is 0.
- [ ] Clicking "Clean Selected" opens a confirm sheet.
- [ ] Confirm sheet shows "X categories, Y GB" and the userCaution
      warning when applicable.
- [ ] "Move to Trash" on the confirm sheet moves files and
      shows a success sheet.
- [ ] Success sheet shows "Freed X GB, N items moved" with
      "Open Trash" and "Done" buttons.
- [ ] `~/.grau/trash-manifests/<ts>-junk.json` is created.
- [ ] Files are present in `~/.Trash` (verifiable in Finder).

### Menu bar

- [ ] Menu bar icon is present.
- [ ] Clicking the menu bar icon opens a 320pt popover.
- [ ] Popover shows: storage bar, "X free", trash row ("X items,
      Y MB" or "Empty"), "Open Grau" / "Empty Trash" buttons,
      version footer.
- [ ] Live updates every 30s.

### Settings

- [ ] "Privacy" tab shows FDA status and "Open System Settings"
      + "Re-check" buttons.
- [ ] "Developer" tab has "Show developer features" toggle
      (default off) and "Old downloads threshold" stepper.
- [ ] "About" tab shows version and tagline.

### Persistence

- [ ] `~/.grau/state.json` is created after the first scan
      or clean.
- [ ] `~/.grau/size-cache.json` is created during scanning.
- [ ] Quit and relaunch: cached scan state restores, no rescan
      needed.

### Performance

- [ ] First junk scan completes within 10s on a Mac with 200 GB
      free, 100 apps.
- [ ] Subsequent scan (after SizeCache populated) completes in
      under 2s.

## Phase 2 — Uninstaller (beta 2)

### Uninstaller

- [ ] Uninstaller tab shows a list of installed apps on the left.
- [ ] Each app row shows name + version; a lock icon indicates
      system apps (`com.apple.*`).
- [ ] Selecting an app shows its residual data on the right.
- [ ] Residual list shows: kind, path (truncated), size, "May
      contain user data" pill for appSupport/cookies/containers.
- [ ] Default selections: caches/logs/preferences etc. are checked;
      containers and groupContainers are NOT.
- [ ] System apps (e.g. Safari): uninstall button is disabled unless
      Dev Mode is on in Settings.
- [ ] Apps with `Contents/Resources/Uninstall.app` show a
      "Has uninstaller" pill.
- [ ] "Uninstall" opens a confirm sheet showing the original path.
- [ ] "Uninstall" on the confirm sheet moves the app + selected
      residuals to Trash, writes a manifest.
- [ ] Success sheet shows the freed size and "Open Trash" / "Done".
- [ ] `~/.grau/trash-manifests/<ts>-uninstall.json` is created.
- [ ] Re-scan after uninstall removes the app from the list.
- [ ] Running app detection: trying to uninstall a running app
      shows an error alert.

## Phase 3 — Disk lens (beta 3)

- [ ] Disk lens tab shows the root ("/") and its top 50 children
      by size.
- [ ] List is sorted descending by size.
- [ ] Each row shows the folder name + size.
- [ ] Clicking the chevron (or double-clicking the row) drills into
      that folder; the breadcrumb updates to show the new path.
- [ ] "Root" button in the toolbar jumps back to "/".
- [ ] "Refresh" re-runs the scan from the current path.
- [ ] Right-click → "Reveal in Finder" opens Finder with the
      folder selected.
- [ ] Right-click → "Move to Trash" trashes the folder (no
      manifest — single-item, no UI for the cleaner).
- [ ] Performance: scanning the root on a real Mac with ~30 top
      entries completes in < 30s; subdirectories are faster.
- [ ] Cancellation: there's no explicit cancel button in v1;
      scans complete or finish quickly enough to skip it.

## Phase 4 — Duplicates finder (beta 4)

- [ ] Duplicates tab defaults the root to `~/`.
- [ ] "Scan" kicks off the 3-phase pipeline (sizing → partial hash
      → full hash); the live phase label updates.
- [ ] Duplicate groups are listed; each card shows the file size,
      number of copies, and wasted bytes.
- [ ] Each file in a group has a toggle; the oldest-by-mtime file
      is pre-marked "Keep" (its toggle is OFF).
- [ ] Empty state: "No duplicates found" when the scan completes
      with no groups.
- [ ] Cancellation: Phase 4 doesn't yet have a cancel button
      (per docs/HANDOFF § 4.3 — defer to v1.1).
- [ ] Performance: a small `~/` (under 5k files) scans in < 30s.
      A large home (50k+ files) is a v1.1 concern; v1 uses
      sequential hashing (parallelism is per-phrase, not per-file).

## Phase 5 — Dev mode (beta 5)

Dev Mode is hidden by default. Enable it via Settings → Developer
→ "Show developer features", or with
`defaults write app.grau.mac grau.devModeEnabled -bool true`.

- [ ] With Dev Mode enabled, "Dev Mode" appears in the sidebar
      (between Duplicates and Settings).
- [ ] Clicking "Dev Mode" opens the tabbed view with six tabs:
      Packages, node_modules, Docker, Simulators, Derived Data,
      Archives.
- [ ] "Refresh" button starts a full scan. A progress spinner
      replaces the button while scanning.
- [ ] First scan typically takes 2–10s (the six inspectors run
      in parallel).

### Packages tab

- [ ] Lists every installed package manager cache that exists on
      the host. A non-existent cache is hidden (not shown).
- [ ] Each row shows the kind (e.g. "npm", "Yarn (classic)") and
      size. Path is truncated to 2 lines.
- [ ] Empty state: "No package caches found" when none of the 16
      are present (e.g. a fresh dev box without npm).

### node_modules tab

- [ ] Lists every `node_modules` directory found under `~/` plus
      the usual project roots (Code, Developer, Projects, repos,
      src, work), to a max depth of 6.
- [ ] Each row shows the project name (parent dir) and size.
- [ ] The total size in the header matches the sum of all rows.
- [ ] The scanner does NOT recurse INTO a `node_modules` directory
      (so we don't see `node_modules/<pkg>/node_modules/...`).
- [ ] A project at depth > 6 (e.g. `~/a/b/c/d/e/f/g/...`) is
      ignored.

### Docker tab

- [ ] With Docker not installed: "Docker not installed" empty state.
- [ ] With Docker installed but daemon not running: "Docker daemon
      not running" empty state.
- [ ] With Docker daemon running: shows a card with Build Cache
      size and Reclaimable size.

### Simulators tab

- [ ] Lists every simulator under
      `~/Library/Developer/CoreSimulator/Devices/`.
- [ ] Each row shows name, runtime, size.
- [ ] A device whose `device.plist` has `state == "Booted"` shows
      a "Booted" warning pill and is NOT included in the
      `DevReport.totalSize` (i.e. it would be skipped if you ever
      trash en masse).

### Derived Data tab

- [ ] Lists every per-project cache under
      `~/Library/Developer/Xcode/DerivedData/`.
- [ ] Each row shows the project name (folder minus the trailing
      -hash) and the folder name (truncated to middle).
- [ ] Sorted by size descending.

### Archives tab

- [ ] Lists every `.xcarchive` bundle under
      `~/Library/Developer/Xcode/Archives/<date>/`.
- [ ] A warning banner at the top reminds the user that archives
      are required for shipping.
- [ ] Each row shows the archive name, the archive date (mtime),
      and the size.
- [ ] Empty state when no archives exist (rare for a dev machine).

### Performance

- [ ] Full scan (all six inspectors) completes in < 15s on a
      typical dev machine.
- [ ] `cd graucore && swift test` — 155/155 tests pass.

## Phase 6a — Polish pt 1 (1.0)

_(filled in when Phase 6a lands)_

## Phase 10 — Dashboard refresh + treemap tier-2 labels (1.5)

### Dashboard reads real data

- [ ] Open Grau. The "Storage" card shows a real
      "<N>% used" pill in the top right, and the bar
      visualizes actual volume usage.
- [ ] The "Trash" card shows "<N> items" and the real
      size of ~/.Trash/.
- [ ] The "Last junk scan" card shows the real last
      scan summary (or "Never" if you haven't scanned
      yet).
- [ ] The "Quick actions" buttons switch the sidebar
      to the corresponding section.
- [ ] Pull-to-refresh updates everything.

### Treemap tier-2 labels

- [ ] Switch to Disk Lens → treemap view.
- [ ] Big cells (>80×36 pt) show name + size.
- [ ] Medium cells (40×18 to 80×36) show just the size
      in 9-pt.
- [ ] Tiny cells (<40×18) are unlabelled (no overflow).

## Phase 9 — Notification center (1.4)

- [ ] A new "Notifications" sidebar item appears between
      "Trash" and "Settings" (bell SF Symbol).
- [ ] On a fresh install, the Notifications view shows the
      "No notifications yet" empty state.
- [ ] Trigger a junk scan that finds > 1 GB (e.g. on a
      freshly-bootstrapped machine, click the demo junk
      category). After Grau fires the alert, the
      Notifications view shows the entry.
- [ ] Each card displays the original title, body, the time
      stamp, and a "Rule: junk > 1 GB" footer.
- [ ] "Clear" empties the log immediately. The file
      `~/.grau/notification-log.json` is removed.
- [ ] Quit Grau and relaunch — the log is preserved.

## Phase 8 — Cancel + auto-tune + filters (1.3)

### Duplicates Stop button

- [ ] Start a scan of a large `~/` directory. While scanning,
      the spinner is replaced with a red "Stop" button.
- [ ] Click "Stop" within 200ms. The scan ends; the phase
      label reads "Cancelled" (or whatever phase it was on).
- [ ] A scan that completed before the cancel clicked shows
      the normal "Full hash done" completion, NOT "Cancelled".

### Auto-tuned parallelism

- [ ] On a Mac with N performance cores, the scanner spawns
      N (or 16, whichever is smaller) in-flight hash tasks.
      Watch `Activity Monitor` during a scan to verify.
- [ ] `defaultParallelism()` returns a value in `[1, 16]`.

### Trash view filters

- [ ] After running multiple clean operations of different
      kinds, the filter chip menu shows one option per kind
      plus "All kinds".
- [ ] Selecting a kind shows only manifests of that kind.
      Selecting "All kinds" shows everything.
- [ ] The "Clear" button appears only when a filter is active.
- [ ] When no manifests match the filter, an empty state
      reads "No matches".

## Phase 7 — Performance + treemap (1.2)

### Duplicates scanner parallelism

- [ ] The ScannerView shows phase labels updating (Sizing →
      Partial hash → Full hash) as before.
- [ ] A 5k-file `~/Downloads` scan completes in < 30s on a
      recent Mac (vs. ~50s on v1.0).
- [ ] Memory stays under 200 MB during a full-`~/` scan
      (the hash map is the only large allocation).

### Disk Lens treemap

- [ ] A new segmented control in the toolbar (list /
      treemap) switches the view.
- [ ] Treemap cells tile the available area with no gaps;
      the largest folder is in a corner (squarified
      algorithm).
- [ ] Tapping a cell drills in (same as a list row).
- [ ] Right-click → "Reveal in Finder" works.
- [ ] Cells smaller than 80×36pt don't show their label
      (visual cleanup).
- [ ] Drill back out via the breadcrumb, then toggle to list
      view: same Top-N data, no re-scan needed.

## Phase 6b — Polish pt 2 (1.1)

### Self-update (Sparkle)

- [ ] App menu → Grau → "Check for Updates…" is present and
      tappable.
- [ ] With no update available, Sparkle shows the "You're up
      to date" alert.
- [ ] SUFeedURL in `Info.plist` points at
      `https://lucianodiisouza.github.io/grau/appcast.xml`.
- [ ] SUPublicEDKey matches the EdDSA keypair in the dev's
      keychain.
- [ ] Sparkle is listed as a Swift package dep in
      `project.yml` (it was added in Phase 6b — v1.0 had no
      third-party runtime deps).

### Homebrew Cask

- [ ] `homebrew-cask/grau.rb` parses (`brew audit`).
- [ ] After filling in sha256 + version, `brew install
      --cask <local-rb>` installs Grau and it launches.

### Trash restore (in-app)

- [ ] New "Trash" sidebar item appears between "Dev Mode" and
      "Settings".
- [ ] On a fresh install (no past cleans), the Trash tab
      shows the "No trashed items yet" empty state.
- [ ] After running a clean, the Trash tab lists one entry
      per manifest with kind, timestamp, total size, and
      item count.
- [ ] "Restore all" on an item moves every file back to its
      `originalPath`. The card flips to "Restored N item(s)"
      with a green check.
- [ ] If the original path is now occupied, that item is
      reported as a failure (orange warning + path snippet)
      but the rest of the batch still restores.
- [ ] `~/.grau/trash-manifests/<timestamp>-<kind>.json` files
      are still readable after restore (we don't delete the
      manifest on success — that lets the user retry).
