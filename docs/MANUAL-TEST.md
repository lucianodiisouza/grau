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

_(filled in when Phase 3 lands)_

## Phase 4 — Duplicates finder (beta 4)

_(filled in when Phase 4 lands)_

## Phase 5 — Dev mode (beta 5)

_(filled in when Phase 5 lands)_

## Phase 6a — Polish pt 1 (1.0)

_(filled in when Phase 6a lands)_

## Phase 6b — Polish pt 2 (1.1)

_(filled in when Phase 6b lands)_
