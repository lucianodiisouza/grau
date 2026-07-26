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
- [ ] `cd graucore && swift test` — 21 placeholder tests pass.
- [ ] `xcodebuild -scheme grau -configuration Debug build` —
      succeeds without warnings.
- [ ] `xcodebuild -scheme grau -configuration Release build` —
      succeeds without warnings.
- [ ] CI: GitHub Actions workflow goes green on a dummy commit.

## Phase 1 — Junk cleaner (beta 1)

_(filled in when Phase 1 lands)_

## Phase 2 — Uninstaller (beta 2)

_(filled in when Phase 2 lands)_

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
