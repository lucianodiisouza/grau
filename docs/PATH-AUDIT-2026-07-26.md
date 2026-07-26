# Path Audit — 2026-07-26

This is the macOS 14 path audit required by Task 0.9 before Phase 1
lands. See `docs/DATA-SOURCES.md` § 1 and § 7 for the canonical path
list; this document records what was actually verified on a real
machine, what was found stale, and what was confirmed correct.

## Audit environment

- **Date:** 2026-07-26
- **Host machine:** arm64 Mac
- **macOS version:** 26.5.2 (Build 25F84)
- **Note:** The project's minimum deployment target is macOS 14.0.
  The host here is on macOS 26, which is forward-compatible. A
  full audit should be repeated on a clean macOS 14.x machine
  before each beta tag.

## Method

For every path listed in `docs/DATA-SOURCES.md` § 1 (the 5 user-
facing junk categories) and § 7 (self-exclusion contract), this
audit verifies existence, writability, and known staleness.

## Findings

### Stale paths to remove from docs

| Path | Why stale | Action |
| --- | --- | --- |
| `/Library/Caches/com.apple.kext.caches` | Kexts were deprecated in macOS 10.15. The path no longer exists on macOS 14+ (or 26). | Remove from DATA-SOURCES.md § 1.2 "gotchas" and from the future `PathExclusions.standard`. |

### Confirmed correct

| Path | Behavior on this Mac | Notes |
| --- | --- | --- |
| `~/Library/Caches/` | exists, populated | User Cache scan works |
| `~/Library/Caches/com.apple.Safari` | exists | Normal Safari cache, safe to scan |
| `~/Library/Caches/com.apple.bird` | exists | **iCloud daemon — DO NOT delete.** Hard exclusion. |
| `/Library/Caches/` | exists, populated | System Cache (FDA) |
| `/Library/Caches/com.apple.QuickLook.thumbnailcache` | does NOT exist as a top-level entry | Quick Look cache lives at `~/Library/Caches/com.apple.QuickLook.thumbnailcache` (user) and `/private/var/folders/.../C/com.apple.QuickLook.thumbnailcache` (per-user temp). |
| `/System/Library/Caches` | exists, read-only | Confirmed; skip in scanner |
| `~/Library/Logs/` | exists | User logs |
| `/private/var/log/` | exists (FDA) | System logs |
| `~/Downloads/` | exists | Old Downloads scan |
| `~/Library/Application Support/MobileSync/Backup/` | exists | iOS backups |
| `~/Library/Containers/com.apple.mail/Data/Library/Mail/` | exists (FDA) | Modern sandboxed Mail. **We don't scan it in v1.** |
| `~/Library/Mail/` | exists (legacy) | Pre-Sonoma Mail data. **We don't scan it in v1.** Dropped in review. |
| `~/.Trash/` | exists | Trash display |
| `/System` | exists, read-only | Standard exclusion |
| `/private/var/db` | exists | Standard exclusion |
| `/.Spotlight-V100` | exists at root, owned by `_mds_stores` | Standard exclusion |
| `/.fseventsd` | exists at root, owned by `admin` | Standard exclusion |
| `/.DocumentRevisions-V100` | exists at root, mode `d--x--x--x` | Standard exclusion |

### Unknown / to investigate in v1.1

| Path | Status | Action |
| --- | --- | --- |
| Apple Intelligence caches | Could not locate a canonical path on this host. Likely under `/var/folders/.../C/` per-user temp, or under a private framework. | Defer to v1.1 (already tracked in PLAN.md § 7 and PLAN.md § 11.1). |

## Required changes to DATA-SOURCES.md

1. **§ 1.2 (System Cache) — Gotchas section:** remove the line
   about `com.apple.kext.caches`. (The review already called this
   out; this audit confirms it.)
2. **§ 1.9 (QuickLook cache):** clarify that on modern macOS the
   QuickLook cache is a **user-level** cache at
   `~/Library/Caches/com.apple.QuickLook.thumbnailcache/`, not a
   top-level entry under `/Library/Caches/`. The current doc has
   it under "System Cache" which is correct (it aggregates with
   system caches) but the path string in the doc is a bit
   ambiguous. Keep both locations in the aggregated list.

## Required changes to future `graucore/.../FS/PathExclusions.swift`

(When implemented in Phase 1 Task 1.1.) The standard exclusion
list should NOT include `com.apple.kext.caches` (it doesn't
exist on modern macOS). The list should include:

- `/System`
- `/private/var/db`
- `/.Spotlight-V100`
- `/.fseventsd`
- `/.DocumentRevisions-V100`
- `/.TemporaryItems`
- `/.Trashes`
- `/private/var/folders/.../T/` (system temp, not user temp)
- `~/Library/Caches/com.apple.bird` (iCloud daemon)
- `~/Library/Caches/com.apple.*` (other Apple system caches)

The Apple Intelligence caches go in v1.1 once we know the path.

## Required changes to future `graucore/.../Junk/JunkDefinition.swift`

(When implemented in Phase 1 Task 1.5.) The 5 user-facing
categories map to these underlying paths (with the audit
corrections applied):

| Category | Paths aggregated |
| --- | --- |
| **User Cache** | `~/Library/Caches/*` (excl. `com.apple.*`) |
| **System Cache** | `/Library/Caches/*` (excl. `com.apple.kext.caches` — not present, no-op), `~/Library/Caches/com.apple.QuickLook.thumbnailcache`, `~/Library/Caches/com.apple.CoreServices/CoreFontCache.*`, `/private/var/folders/.../C/com.apple.QuickLook.thumbnailcache`, `/private/var/folders/.../C/com.apple.fontd/` |
| **Logs** | `~/Library/Logs/*`, `/private/var/log/*.asl` (FDA) |
| **Old Downloads** | `~/Downloads/*` shallow (FDA: no) |
| **iOS Backups** | `~/Library/Application Support/MobileSync/Backup/*` |

(Trash is displayed separately, not as a junk category — see
DATA-SOURCES.md § 1.6.)

## Next audit

This audit should be repeated on a clean macOS 14.x machine before
each beta tag. The new machine might have different system caches
present (e.g., a developer who has installed Xcode may have a
`/Library/Caches/com.apple.dt.Xcode` that we should or shouldn't
clean).
