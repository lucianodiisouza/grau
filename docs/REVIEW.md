# REVIEW — Senior Staff Engineer pass

This document captures the architecture + planning review performed on
the Grau plan before development started. It is **historical record**:
the corrections below are already applied to the other docs
([PLAN.md](./PLAN.md), [ARCHITECTURE.md](./ARCHITECTURE.md),
[DATA-SOURCES.md](./DATA-SOURCES.md), [PERMISSIONS.md](./PERMISSIONS.md),
[DESIGN.md](./DESIGN.md), [HANDOFF.md](./HANDOFF.md)). The
implementing agent does not need to re-apply anything from here — but
it should read this first to understand *why* the other docs look the
way they do.

Reviewer: Mavis (acting as Senior Staff Engineer).
Date: 2026-07-26.
Scope: every doc in this folder (7 docs, ~3,100 lines) + the archived
`macapps` plan.

---

## 1. Verdict

**The 5-feature, 5-beta, 16-week plan is structurally right.** It
needed ~30% timeline correction, 8 correctness fixes in the
data-sources and permissions sections, and a dozen simplifications to
the architecture. None of this was fatal. The bones were good. The
user accepted the 5-feature path; the 3-epic rewrite is documented as
the alternative, not the chosen direction.

---

## 2. Correctness bugs (B1–B8)

### B1. External-volume discovery is wrong for Apple Silicon

**Was:** `VolumeMonitor` walks `/Volumes/*` for external volumes.

**Problem:** True on Intel; wrong on Apple Silicon when the user's
home is on a non-boot APFS volume. Additional volumes are mounted
under `/System/Volumes/Data/`, not `/Volumes/`.

**Fix:** Use
`FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys:options:)`
with keys `[.volumeIsLocalKey, .volumeIsRemovableKey, .volumeNameKey]`
and options `[.skipHiddenVolumes]`.

### B2. Mail attachments path is wrong on modern macOS

**Was:** `~/Library/Mail/V*/MailData/Attachments/`.

**Problem:** On Monterey+ Mail is sandboxed. Real path is
`~/Library/Containers/com.apple.mail/Data/Library/Mail/V*/MailData/Attachments/`.
Even with FDA, the hardcoded path is empty.

**Fix:** **Drop `mailAttachments` from v1 entirely.** Cleaning Mail
attachments is risky (can break local IMAP cache, slow next launch)
and the path-discovery complexity isn't worth the feature.

### B3. `keychainEntries` is unsafe to detect or delete

**Was:** ResidualFinder "detects keychain entries per bundle ID."

**Problem:** Keychain entries have no `bundleID` — they have `svce`
(service name) which is unrelated. Detection requires heuristics
that will both over- and under-match. These are user data (web
passwords, WiFi, certificates) — even *detecting* and showing them
creates a false sense that Grau can manage passwords.

**Fix:** **Drop `keychainEntries` from v1.** If we ever add it, it's
a separate feature with its own consent flow.

### B4. `groupContainers` path pattern is wrong

**Was:** `~/Library/Group Containers/group.<bundleID>/`.

**Problem:** The `group.*` identifier comes from the app's
`com.apple.security.application-groups` entitlement, not from the
bundle ID.

**Fix:** Read group identifiers from the parent app's
`Contents/Info.plist` and look up each group by its actual identifier.

### B5. `~/Library/Caches/com.apple.kext.caches` is stale

**Was:** Listed as a never-delete system exclusion.

**Problem:** Kexts were deprecated in macOS 10.15. The path no longer
exists on macOS 14+. Several other paths in the exclusion list are
similarly stale.

**Fix:** Audit `PathExclusions.standard` against a live macOS 14
machine before Phase 1 (added to Phase 0 task list). Remove paths
that no longer exist. Add Apple Intelligence caches for macOS 15.

### B6. Notification dedupe rule is ambiguous

**Was:** "Once a notification fires, it doesn't fire again until the
condition is reset."

**Problem:** The plan didn't define how "reset" is detected.

**Fix:** Use **state-transition dedupe**: only fire when a threshold
is *crossed upward* (from below to above). Track per-rule last-fired
value in UserDefaults; re-fire only when the new value crosses the
threshold again.

### B7. `NSWorkspace.dispose` is slow and inconsistent

**Was:** `TrashMover` uses `NSWorkspace.dispose(for:)`.

**Problem:** `dispose` is sequential, sometimes goes through Finder,
and is significantly slower than `FileManager.trashItem` for large
operations (30s vs 5min on 10k files).

**Fix:** Use `FileManager.trashItem(at:resultingItemURL:)`. Atomic,
fast, no AppleEvents side effects.

### B8. Browser cache default is dangerous

**Was:** `browserCache` marked as `userCaution`; UI default not
specified.

**Problem:** If the AI defaults to "checked" the user signs out of
every site on click. The plan left this ambiguous.

**Fix:** Default to **OFF** in v1. **Drop `browserCache` from v1
entirely** — path complexity is real, and the cost of a wrong default
is too high. Add back in v1.1 as an opt-in "clear all browser caches"
button with explicit confirmation.

---

## 3. Structural simplifications (S1–S13)

| # | Was | Becomes | Why |
| --- | --- | --- | --- |
| S1 | SwiftData for prefs + cache | UserDefaults + JSON in `~/.grau/` | Two persistence layers for one job; SwiftData adds migration risk |
| S2 | 11 junk categories | 5 user-facing categories (underlying paths still granular) | Cleaner UI, same coverage |
| S3 | Custom SwiftUI Canvas treemap | Top-N folders list view (treemap deferred to v1.1) | 3 weeks → 3 days for 90% of value |
| S4 | Every engine is an `actor` | Default to `struct async`; `actor` only where shared state exists | Ceremony without benefit at this scale |
| S5 | ">80% line coverage" target | 100% public-API tests on 8 critical modules | Tarpit eliminated |
| S6 | No CI in plan | `.github/workflows/ci.yml` added in Phase 0 | First contributor experience |
| S7 | Repo folder `macapps` | Renamed to `grau` | Avoid future confusion |
| S8 | AI designs the app icon | Placeholder only, user provides final | AI icons are mediocre |
| S9 | Dev mode always in sidebar | Settings toggle "Show developer features" (default OFF) | Two audiences, one app |
| S10 | `HardlinkChecker.swift` as separate file | Inlined into `DirectorySizer` | One-method file is noise |
| S11 | Menu bar monogram color spec | Template image, no color (OS tints it) | Moot debate |
| S12 | Phase 6 = 2 weeks for icon+DMG+Sparkle+Cask+notarize+README | Split into Phase 6a (1.5 wk, no Sparkle) + Phase 6b (Sparkle+Cask) | Realistic scope |
| S13 | No Privacy Manifest | `PrivacyInfo.xcprivacy` in Phase 6a | Required for notarization as of May 2024 |

---

## 4. Scope & timeline

The 16-week estimate was 30–40% optimistic. Realistic numbers after
the simplifications:

| Phase | Was | Now | Note |
| --- | --- | --- | --- |
| 0 — Scaffold | 1 wk | 1.5 wk | + CI, + repo rename, + path audit |
| 1 — Junk + tray | 3 wk | 4 wk | + bug-bash week |
| 2 — Uninstaller | 2 wk | 3 wk | + bug-bash week |
| 3 — Disk lens | 3 wk | 2 wk | list view not treemap; + bug-bash week |
| 4 — Duplicates | 2 wk | 2.5 wk | + bug-bash week |
| 5 — Dev mode | 3 wk | 4 wk | + bug-bash week |
| 6a — Polish pt 1 | 2 wk | 1.5 wk | icon+DMG+notarize+Privacy Manifest+README |
| 6b — Polish pt 2 (v1.1) | — | 1.5 wk | Sparkle + Cask |
| **Total v1.0** | **16 wk** | **~19 wk** | **5 months** |
| **+ v1.1** | — | **+1.5 wk** | **~20.5 wk** |

The 3-epic rewrite (junk+tray → uninstall+duplicates → disk+dev,
~13 wk, 3 releases) was proposed and **rejected** by the user. The
5-feature path is locked. This review captures the alternative for
posterity.

---

## 5. What was NOT changed

- **Tech stack** (Swift 5.9, SwiftUI, SwiftData dropped → UserDefaults, etc.) — locked.
- **App shape** (menu bar + window hybrid) — locked.
- **Trash-only destructive ops** — locked.
- **No sandbox, FDA-only, no helper tool** — locked.
- **MIT license, GitHub repo, Homebrew Cask + DMG distribution** — locked.
- **5 user-facing features** — locked.
- **5 betas + 1.0 + v1.1** — locked.

---

## 6. Hidden risks identified (added to PLAN § 7)

| Risk | Note |
| --- | --- |
| Apple Privacy Manifest required for notarization (May 2024+) | Added to Phase 6a. |
| macOS 15 (Sequoia) — Apple Intelligence caches | Tracked in v1.1. |
| App Intents framework — Siri/Shortcuts integration | Tracked in v1.1. |
| `.Trash` symlink to non-boot volume | Resolved in `TrashInfo` via `URL.resolvingSymlinksInPath()`. |
| "Trash full" feature is underwhelming | Lean into size + notification; no Finder button. |
| Per-app "Quit X before cleaning" detection | Generic warning in v1; per-app detection in v1.1. |
| iCloud Documents edge case | Generic footer on confirm sheet in v1. |

---

## 7. Process for future reviews

This review pattern (correctness bugs + structural simplifications +
hidden risks + roadmap adjustment + Epic plan) is the template for
future reviews at end-of-phase. After each beta tag, the staff-eng
review runs again and the docs are amended.
