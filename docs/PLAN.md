# PLAN — Grau

## 1. Vision

**Grau** is a free, open-source, native macOS utility that helps users
**reclaim, understand, and manage** their Mac's storage. It is the
CleanMyMac for people who don't want to pay $40/year and don't want to
hand over a privileged system to closed-source binary blobs.

Grau's first principles:

1. **The user owns their data.** Grau never silently deletes anything.
   Every destructive operation moves files to the user's Trash and
   records what it did. The user can always undo by emptying the Trash
   the other way (restoring the files).
2. **Be a good citizen.** Grau reads what's needed, asks for permissions
   up front, and respects macOS sandboxing norms. It does not exfiltrate.
3. **Look and feel native.** Not "designed on macOS, ported from iOS."
   Sidebar, inspector, native menus, system materials, SF Symbols,
   keyboard shortcuts that match the platform.
4. **Be fast.** No scan should take more than a few seconds for a sane
   subset; the full disk lens is allowed to take a minute and shows
   progress.

## 2. Feature scope (v1)

### 2.1 Junk cleaner
- User caches: `~/Library/Caches/*`
- System caches: `/Library/Caches/*` *(requires FDA)*
- System logs: `/private/var/log/*` *(requires FDA)*
- User logs: `~/Library/Logs/*`
- Trash: `~/.Trash/` and `/Volumes/*/.Trashes/` *(volume-dependent)*
- Browser caches: Safari, Chrome, Firefox, Edge, Brave
- Mail attachments cache
- iOS device backups in `~/Library/Application Support/MobileSync/Backup/`
- Old Downloads: `~/Downloads/*` older than N days (configurable)
- Quick Look cache, font caches, kernel cache metadata

### 2.2 App uninstaller
- List installed `.app` bundles (carries over from the macapps plan)
- Per-app residual finder: prefs, caches, app support, logs, containers,
  saved state, cookies, keychain entries (read-only detection — never
  delete keychain)
- Per-app pre-uninstall hooks: if the app has `--uninstall` or
  `Contents/Resources/Uninstall.app`, offer to run it
- Move app + residuals to Trash (never `rm -rf`)

### 2.3 Disk lens
- Tree-map visualization of the entire disk
- Drill-down by directory
- Right-click → reveal in Finder, move to Trash
- Per-volume view (Macintosh HD, external drives)
- Excludes: `/System`, `/private/var/db`, `/Volumes` (other than root)
- Cancellation: scan can be paused or aborted

### 2.4 Duplicates finder
- User picks a root folder (defaults to `~/`)
- Pipeline: size filter → partial-hash (first 4 KB) → full SHA256
- Group by hash, list each group
- Multi-select within a group, bulk move to Trash
- Safe defaults: never delete the only copy of anything

### 2.5 Dev mode
A "developer tools" sub-section of the app that surfaces caches and
artifacts specific to dev workflows:

- **`node_modules` finder** — walks the user's home (or configured
  project roots) for `node_modules` directories, lists them with size
- **Package manager caches**:
  - npm: `~/.npm/`
  - yarn (classic): `~/Library/Caches/yarn/`
  - yarn (berry/pnp): `~/.yarn/`
  - pnpm: `~/Library/pnpm/`
  - bun: `~/.bun/`
  - CocoaPods: `~/Library/Caches/CocoaPods/`
  - Carthage: `~/Library/Caches/org.carthage.Carthage/`
  - SwiftPM: `~/Library/Caches/org.swift.swiftpm/` and
    `~/Library/org.swift.swiftpm/`
  - Maven: `~/.m2/`
  - Gradle: `~/.gradle/`
  - sbt: `~/.sbt/`, `~/.ivy2/`
  - Cargo: `~/.cargo/registry/`
  - RubyGems: `~/.gem/`
  - pip: `~/Library/Caches/pip/`
  - poetry: `~/Library/Caches/pypoetry/`
- **Docker**: shells out to `docker system df -v` (if `docker` is
  installed), shows stopped containers, dangling images, unused volumes,
  build cache
- **iOS Simulators**: `~/Library/Developer/CoreSimulator/Devices/`,
  `~/Library/Developer/CoreSimulator/Caches/`, derived data
- **Xcode DerivedData**: `~/Library/Developer/Xcode/DerivedData/`
- **Archives**: `~/Library/Developer/Xcode/Archives/`

### 2.6 Menu bar + notifications
- Menu bar icon with a small numeric badge for "X items to review"
- Popover: storage bar, trash status, quick actions (scan, empty trash,
  open app)
- Notifications (user-configurable, defaults: on):
  - "12.4 GB of junk available" — after a junk scan, if > 1 GB
  - "Your disk is 95% full" — daily check
  - "Trash has 8.2 GB" — daily check
  - "Grau update available" — when Grau itself has a new version
- Background: every 6h, scan trash + storage. Full junk scan only on
  user request or menu bar click.

## 3. Out of scope (v1)

- **No privileged helper tool.** No `SMJobBless`, no admin elevation.
  Everything runs in user space with FDA.
- **No real-time protection.** No launchd daemons, no file system
  monitoring, no automatic cleanup.
- **No antivirus / malware scanning.** Not the product.
- **No iOS / iPadOS app.** macOS only.
- **No multi-user support.** Single user per Mac.
- **No cloud sync.** Everything is local. No accounts.
- **No "secure file shredder".** `rm -P` is not on the menu; we don't
  pretend to do it either.
- **No RAM / CPU / battery tools.** That's a different product
  (e.g., iStat Menus). We are scoped to storage.

## 4. Key decisions (locked)

| Decision | Choice | Why |
| --- | --- | --- |
| Name | **Grau** | User-chosen. Portuguese for "gray" — warm, neutral, available. |
| Min macOS | **14.0 (Sonoma)** | SwiftData, modern `MenuBarExtra`, `Observable`. |
| UI framework | **SwiftUI** + AppKit interop | Native feel. AppKit for things SwiftUI does poorly (NSStatusItem quirks, treemap Canvas). |
| Permissions | **FDA only, user-space** | User-chosen. CleanMyMac-lite. OSS-friendly. |
| Destructive ops | **Trash, never `rm`** | Trust + recovery. |
| App Sandbox | **Off** | Need FS read of arbitrary paths. Hardened runtime on. |
| Distribution | **Direct download (DMG) + Homebrew Cask for Grau itself** | MIT-licensed OSS. No MAS (review would reject this kind of app). |
| Update channel | **Sparkle self-update** from GitHub Releases | Standard for OSS Mac apps. |
| Architecture | **Xcode app + `graucore` Swift Package** | App + UI in Xcode. All engines in a testable package. |
| Persistence | **SwiftData** for prefs + cache; JSON manifests in `~/.grau/` | Standard. |
| Dependency policy | **No third-party runtime deps in v1** | Treemap algorithm, file hashing all in-house. CryptoKit for SHA256. |
| Languages | **Swift 5.9+**, **English** UI in v1, structure ready for i18n | v1 ships in EN. PT-BR and others in v2. |
| License | **MIT** | User-chosen. |
| Repo | **GitHub** | De facto for OSS Mac apps. |

## 5. The 5-slice phased plan

This is a **5-month project** (realistic, post-review estimate: ~19
weeks to 1.0, +1.5 weeks for v1.1 with Sparkle). Scoped into **5
vertical slices that each ship a usable beta**, plus a final polish
phase that is itself split in two. The betas accumulate; the user
always has a working app from week 5 onward.

| Slice | Weeks | What ships | Cumulative value |
| --- | --- | --- | --- |
| 0 — Scaffold | 1.5 | Xcode project, design system, CI, onboarding shell, path audit, dashboard skeleton | Empty app that runs, builds in CI, and looks right |
| 1 — Junk cleaner | 4 | 5-category junk scan + clean, FDA onboarding, menu bar, basic notifications | **Public beta 1**: a useful cleaner |
| 2 — Uninstaller | 3 | App list, residual detection, uninstall flow | **Public beta 2**: cleaner + uninstaller |
| 3 — Disk lens | 2 | Top-N folders list, drill, context menu, cancel | **Public beta 3**: visual disk exploration |
| 4 — Duplicates | 2.5 | Size → partial-hash → full-SHA256 pipeline, group, multi-select clean | **Public beta 4**: full storage toolkit |
| 5 — Dev mode | 4 | node_modules, 16 package caches, Docker, Simulators, DerivedData | **Public beta 5**: dev-friendly |
| 6a — Polish pt 1 | 1.5 | App icon (placeholder), DMG, notarization, Privacy Manifest, README | **1.0** |
| 6b — Polish pt 2 | 1.5 | Sparkle self-update, Homebrew Cask, website | **1.1** |

**Total: ~19 weeks to 1.0; +1.5 wk to 1.1 (~20.5 wk overall).**

The 16-week estimate was ~30% optimistic. Reality: AI-assisted solo
execution eats 30% to bug fixes, test writing, and macOS quirks. See
[REVIEW.md § 4](./REVIEW.md#4-scope--timeline) for the detailed
breakdown.

> **Alternative considered (and rejected):** a 3-epic rewrite
> (junk+tray → uninstall+duplicates → disk+dev, ~13 weeks, 3
> releases). The user chose the 5-feature path. The 3-epic rewrite
> is captured in [REVIEW.md](./REVIEW.md) for posterity.

The betas are tagged on GitHub. Each beta gets a brief release post on
the repo's Discussions / a `CHANGELOG.md` entry. This builds a public
record of progress and lets early users file issues per feature.

### 5.1 Per-slice acceptance criteria

Each slice has explicit, testable criteria in
[HANDOFF.md § Acceptance](./HANDOFF.md#per-slice-acceptance-criteria)
and the corresponding Epic in [TASKS.md](./TASKS.md). The
implementing AI agent checks them off before declaring the slice
done.

## 6. Success criteria (1.0)

Grau 1.0 is "done" when **all** of the following hold:

- [ ] All 5 features functional on a clean install.
- [ ] Onboarding walks the user through FDA, with screenshots.
- [ ] On a 200 GB free, 100-app Mac, first junk scan completes in
      < 10 s, disk lens scan in < 60 s, duplicates scan in < 5 min.
- [ ] No data loss reported by any user in 30 days of beta.
- [ ] No crash in normal use for 30 days.
- [ ] App uses < 100 MB RAM at idle (menu bar only).
- [ ] All destructive operations land in Trash; a manifest is written
      for every clean.
- [ ] Menu bar popover updates in real time.
- [ ] All notifications are user-toggleable, with state-transition
      dedupe (no spam).
- [ ] App icon, DMG, GitHub README all in place.
- [ ] **Privacy Manifest (`PrivacyInfo.xcprivacy`) shipped.** Required
      for notarization as of May 2024.
- [ ] **100% public-API test coverage on the 8 critical modules:**
      `TrashMover`, `FileSystemScanner`, `DirectorySizer`,
      `JunkScanner`, `DuplicateScanner`, `Uninstaller`,
      `PermissionChecker`, `VolumeMonitor`. The rest of the modules
      get tests as part of writing them — not as a target. (This
      replaces the old "80% line coverage" goal — see
      [REVIEW.md § S5](./REVIEW.md#3-structural-simplifications-s1s13).)
- [ ] Verified on both Apple Silicon and Intel.
- [ ] Verified on macOS 14.0, 14.x latest, 15.x latest.
- [ ] Notarized and signed (even on free Apple Developer ID).
- [ ] CI green on GitHub Actions (`.github/workflows/ci.yml`).

### 6.1 Success criteria for v1.1 (Phase 6b)

- [ ] Sparkle self-update works end-to-end from a prior beta build.
- [ ] `brew install --cask grau` installs the latest signed release.
- [ ] A landing page exists (static HTML, GitHub Pages).

## 7. Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| **Data loss** from a buggy cleaner / uninstaller | Medium | Catastrophic | Trash-only via `FileManager.trashItem`; manifest for undo; aggressive pre-flight size/path checks; no `rm -rf`; canary test in CI |
| User never grants FDA — the app is useless | High | High | Strong onboarding with screenshots; "limited mode" that still works on user space only; FDA not required for User Cache / Trash / Dev Mode |
| `~/Library` layout changes between macOS versions | Medium | High | Per-category path lists; defensive `exists` checks; graceful "category skipped" state; path audit in Phase 0 against live macOS 14 |
| Hashing 1 TB of files is slow | High | Medium | Partial-hash first (first 4 KB), then full SHA256 only on collision candidates; user picks scope; cancellable |
| Docker API changes / Docker Desktop licensing | Low | Low | `docker system df -v` text output is stable across recent versions; fall back to "not available" |
| Apple adds new system protections (e.g., per-app library containers) | Medium | Medium | Defensive coding; track macOS release notes; document which paths require which permission; Phase 0 path audit catches staleness |
| Apple Privacy Manifest required for notarization | High | High | `PrivacyInfo.xcprivacy` shipped in Phase 6a (covers file timestamps, system boot time, disk space APIs) |
| **macOS 15 (Sequoia) Apple Intelligence caches** | Medium | Medium | Tracked in v1.1; v1 must skip unknown paths gracefully without erroring |
| Project scope creep | High | High | 5-slice plan with hard cutoffs; new feature ideas go in `docs/V2-IDEAS.md`; the 3-epic alternative is documented as a fallback if 1.0 runs long |
| Solo maintainer burnout | High | High | Betas are timeboxed; each phase has a dedicated bug-bash week; if a phase is at 150% effort, cut the lowest-value item, do not extend |
| Trademark / name collision | Low | Low | Search before 1.0; document in `docs/TRADEMARKS.md` |
| App Intents (Siri/Shortcuts) — users will expect it | Low | Low | Tracked for v1.1; v1 ships without |
| `.Trash` symlink to non-boot volume (Apple Silicon multi-volume) | Medium | Low | `TrashInfo` resolves symlinks via `URL.resolvingSymlinksInPath()` before sizing |

## 8. What "modern native feel" means

This is enough of a commitment that it gets its own doc. See
[DESIGN.md](./DESIGN.md). TL;DR: macOS-native sidebar, system materials,
SF Symbols, native menu bar, keyboard-first interactions, dark mode that
isn't a hack.

## 9. What "FDA-only" means

This is enough of a commitment that it gets its own doc. See
[PERMISSIONS.md](./PERMISSIONS.md). TL;DR: Grau is a TCC citizen; the user
grants Full Disk Access once, Grau is on the honor system from there.

## 10. Open questions for the user

These are not blockers — the implementing agent proceeds with the
listed default unless told otherwise:

1. **App icon.** Default: a custom-drawn "G" mark in the Grau palette,
   generated as a 1024×1024 PNG → `.icns`. Final design lands in Phase 6.
2. **First-run onboarding flow.** Default: a 3-screen tour (welcome →
   FDA primer → ready), each dismissible, with a "Show me again" in
   Settings.
3. **Notifications default.** Default: enabled for "junk > 1 GB found"
   and "disk > 90% full"; disabled for everything else.
4. **Trash full threshold.** Default: 5 GB or 1000 items, whichever
   first. Configurable in Settings.
5. **Dev mode default root.** Default: `~/` for `node_modules` walk.
   Configurable in Settings (common additions: `~/Code`, `~/Developer`).
6. **Localization.** Default: EN only in v1. PT-BR for v2 (since the
   user is PT-BR-speaking and likely wants this).
7. **Repo name on GitHub.** Default suggestion: `grau`. The user picks.

## 11. Future (post-v1)

Out of scope, but the architecture should not paint us into a corner:

### 11.1 v1.1 (post-1.0, ~1.5 weeks)

- **Sparkle self-update** + signed appcast hosted on GitHub Pages.
- **Homebrew Cask** for `brew install --cask grau`.
- **Landing page** (static HTML, GitHub Pages).
- Browser cache cleaning (dropped from v1, see [REVIEW.md B8](./REVIEW.md#2-correctness-bugs-b1b8)).
- Apple Intelligence cache detection (macOS 15).
- App Intents / Siri / Shortcuts integration.
- Per-app "Quit X before cleaning" detection (currently a generic warning).
- Real treemap visualization (v1 ships a Top-N folders list; treemap
  was deferred to v1.1, see [REVIEW.md S3](./REVIEW.md#3-structural-simplifications-s1s13)).
- Restore-from-manifest UI (manifests are written in v1; UI is in v1.1).

### 11.2 v2+

- **Privileged helper tool** (SMJobBless) for system-root cleanup
  (`/private/var/log`, `System` volume).
- **Real-time protection** (launchd daemon that watches Downloads and
  Trash).
- **iOS / iPadOS** companion.
- **Localization** (PT-BR, ES, DE, FR, JA, ZH). PT-BR is the natural
  v2 locale given the user is bilingual EN/PT-BR.
- **Localization for community contributors** via Crowdin.

### 11.3 Out of scope forever

- **Multi-machine sync** via iCloud. Contradicts "always free" — would
  require Grau Pro.
- **Battery / RAM / CPU tools**. Different product, different audience.
- **Plugin architecture** for custom junk categories. Risk of becoming
  a malware loader.
