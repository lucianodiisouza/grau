# PLAN — macapps

## 1. Vision

**macapps** is a native macOS SwiftUI app that, on demand, scans the user's
installed applications and tells them:

- which apps are **outdated**,
- what the **latest** version is,
- **where** to update (Mac App Store, Homebrew, vendor website, Sparkle feed).

It does **not** install updates itself in v1. It is a "what's outdated on my
Mac right now" utility — closer to a status reader than an updater.

The first-run experience is one click on the menu bar icon → a list of apps
with outdated ones visually marked → click an outdated app → "Open in Mac App
Store" / "Run `brew upgrade`" / "Open vendor site" action button.

## 2. Goals & non-goals (v1)

### In scope
- Scan `/Applications`, `~/Applications`, `/Applications/Utilities` (read-only).
- Read `Info.plist` from each `.app` bundle for name, version, bundle ID, and
  update-source hints (`SUFeedURL`, `MASReceipt`).
- Detect installation method (MAS / Homebrew / direct / unknown).
- For each app, determine an `OutdatedStatus`:
  - `.upToDate`
  - `.outdated(latest, source)`
  - `.unknown(reason)`
  - `.checking`
- Hybrid UI: **MenuBarExtra** (always visible, with a count badge) + **main
  window** (full list, filters, preferences).
- Manual refresh button. (Auto-refresh is a v2 feature.)
- Local cache so the second scan is instant.
- Graceful fallback when `mas` and `brew` are not installed — those apps show
  `.unknown` with an install hint, the app does not error.

### Out of scope (v1)
- Auto-installing updates.
- Background polling / launch agents / `launchd` schedules.
- Multi-user support.
- iOS apps, iPad apps on Apple Silicon.
- System apps in `/System/Applications` (filtered out — updated via macOS).
- Cross-machine sync.

## 3. Key decisions (locked)

| Decision | Choice | Why |
| --- | --- | --- |
| Minimum macOS | **macOS 14.0 (Sonoma)** | `MenuBarExtra` polish, SwiftData maturity, `Observable` macro. |
| UI framework | **SwiftUI** | User-requested. Falls back to AppKit interop where needed. |
| Persistence | **SwiftData** | Native, less boilerplate than Core Data, fine for our scale. |
| External CLIs | **Optional, graceful** (`mas`, `brew`) | See § 3.1. |
| App shape | **Menu bar + main window (hybrid)** | User-requested. Menu bar for glance, window for detail. |
| Process model | **Xcode project + Swift Package** | App target in Xcode, all logic in `macappsCore` Swift Package for unit-testability. |
| App Sandbox | **Disabled** | Need full FS read of `/Applications` and child processes (`mas`/`brew`). User runs locally; we are not distributing through MAS. |
| Hardened runtime | **Enabled** | Required for notarization (even if we skip notarization in v1, future-proofs). |
| Update UX | **Status + action button**, never auto-install | User decides. Less liability. Less surprise. |

### 3.1 Why optional `mas` / `brew`

Talking to the Mac App Store and Homebrew Cask directly without their CLIs
means reverse-engineering private frameworks (AppStore) and parsing local
caches that change shape between versions (Homebrew). The CLIs already do
this work and they are widely installed by the audience that would want this
app (power users). If the CLI is missing, the app still works — the affected
apps just show `.unknown`.

## 4. Success criteria

A first build is "done" when **all** of the following hold:

- [ ] App launches, shows a menu bar icon, no Dock icon visible.
- [ ] Clicking the menu bar icon opens a popover with a count of outdated apps
      and a "Show All" button.
- [ ] Main window opens with a list of all installed user apps, name + version
      + icon, sortable.
- [ ] System apps (`/System/Applications`) are filtered out.
- [ ] For at least 3 Sparkle-enabled apps (e.g., Slack, Discord, Sketch) the
      app shows correct `.upToDate` / `.outdated` status.
- [ ] If `brew` is installed, Homebrew Cask apps are correctly classified.
- [ ] If `mas` is installed, Mac App Store apps are correctly classified.
- [ ] If neither CLI is installed, app still works and shows install hints.
- [ ] A `.outdated` app has an action button that opens MAS / vendor URL /
      copies a `brew upgrade` command to clipboard, as appropriate.
- [ ] Cold scan of a 100-app Mac finishes in under 2 seconds.
- [ ] Second scan (cached) finishes in under 200 ms.
- [ ] `macappsCore` unit tests pass (`swift test`).

## 5. Phased plan

Total estimate for a competent engineer/AI agent: **5–7 working days**.

| Phase | Name | Goal | Estimate |
| --- | --- | --- | --- |
| 0 | Scaffold | Xcode project + Swift Package, empty menu bar + window | 0.5 day |
| 1 | Scan & display | List all installed user apps with name, version, icon | 1 day |
| 2 | Sparkle | Outdated detection for Sparkle-enabled apps | 1 day |
| 3 | MAS + Homebrew | Outdated detection for MAS and Homebrew Cask apps | 1.5 days |
| 4 | Polish | Preferences, filters, sort, actions, cache, packaging | 1–2 days |
| 5 (optional) | Ship | Developer ID signing, notarization, DMG | 1 day |

Per-phase acceptance criteria live in [HANDOFF.md § Phases](./HANDOFF.md#phases).

## 6. Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| `mas` and `brew` not installed on target machine | High | Medium | Graceful `.unknown` with install hint. App is still useful for Sparkle + heuristic. |
| `Info.plist` missing/garbled on a hand-rolled app | Medium | Low | Defensive parsing; if a field is missing, label the app `.unknown` and continue. |
| Sparkle feeds in non-XML / JSON / custom formats | Medium | Medium | We parse the common RSS shape. Anything else → `.unknown(reason: "Unsupported feed format")`. |
| Apple introduces app-scanning restrictions | Low | High | Out of our control. App reads only; no IPC injection. App Store distribution would be blocked (we won't ship there anyway). |
| Permission prompts (TCC) when reading other apps' data | Low | Low | We only read `/Applications` and `~/Applications` — no protected user data. No prompts expected. |
| Performance on Macs with 300+ apps | Low | Medium | `actor`-based scanner; parallel checker fan-out; in-memory cache. |

## 7. Future (post-v1)

These are out of scope but worth noting so the v1 architecture doesn't paint
us into a corner:

- Background refresh (LaunchAgent) every N hours.
- Native notifications when new updates appear.
- Sparkle self-update for the app itself.
- Multi-machine sync via iCloud.
- Auto-install for Homebrew casks (`brew upgrade --cask`).
- Homebrew formula apps (CLI tools), not just casks.
- Setapp integration.
- macOS-version-cropped app lists ("which of my apps don't run on macOS 15?").

## 8. Open questions for the user

The following are not blockers — the implementing agent can proceed with the
listed default — but if the user wants to change any of them, do so before
Phase 0:

1. **App name & bundle ID.** Default: `macapps` / `com.targa.macapps`
   (using `targa` to match the user's mobile project family).
2. **App icon.** Default: a neutral SF Symbol (`arrow.up.app` or
   `app.gift`) for v1. Custom icon is Phase 4.
3. **Menu bar icon style.** Default: a small monochrome template image so it
   adapts to light/dark menu bar automatically.
4. **First-run flow.** Default: no onboarding, just open the window and show
   the list. A "How this works" panel can be added if requested.
