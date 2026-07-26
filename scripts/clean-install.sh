#!/usr/bin/env bash
#
# clean-install.sh — wipe every Grau installation artifact from this Mac.
#
# Why this exists:
#   When iterating on TCC / FDA behavior, leftover artifacts from old
#   builds cause confusing "which binary am I actually launching?" moments:
#     - a Grau.app in /Applications or ~/Applications from a previous install
#     - the .app copy in ./build/ that build-and-run.sh manages
#     - a stale DerivedData build whose path changed (Launch Services
#       still knows it by its old path, but you can't easily open it)
#     - cached preferences, support files, manifests, and the TCC grant
#       itself
#   This script deletes all of them so you can run from a known-clean
#   state.
#
# What it removes:
#   - Running Grau processes (kill, no force)
#   - /Applications/Grau.app, ~/Applications/Grau.app
#   - ./build/Grau.app, ./build/DerivedData
#   - The Xcode DerivedData that the old build-and-run.sh used
#     (~/Library/Developer/Xcode/DerivedData/grau-*)
#   - ~/Library/Application Support/app.grau.mac
#   - ~/Library/Preferences/app.grau.mac.plist
#   - ~/Library/Caches/app.grau.mac
#   - ~/Library/Logs/app.grau.mac
#   - ~/Library/Containers/app.grau.mac
#   - ~/Library/Group Containers/<group ids from Info.plist>
#   - ~/Library/Saved Application State/app.grau.mac.savedState
#   - ~/.grau/  (graucore manifest + size cache + log directory)
#   - Spotlight index entry for the bundle id (mdimport)
#   - Launch Services registration for every Grau.app it can find
#   - TCC grant via `tccutil reset app.grau.mac`
#
# Usage:
#   ./scripts/clean-install.sh            # interactive (asks before deleting)
#   ./scripts/clean-install.sh --yes      # skip the confirm prompt
#   ./scripts/clean-install.sh --dry-run  # print what would happen, do nothing
#
# Re-run build-and-run.sh afterwards to install fresh.
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_ID="app.grau.mac"

DRY_RUN=0
ASSUME_YES=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --yes|-y) ASSUME_YES=1 ;;
        -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
        *) echo "Unknown arg: $arg" >&2; exit 1 ;;
    esac
done

# Each action is either a path to remove (file/dir) or a command to run.
# We collect them and print, then execute (or just print with --dry-run).
# Using arrays keeps this readable; we tag each item so the dry-run
# output is unambiguous.

remove_path() {
    # Returns 0 always. `set -e` would otherwise kill the script
    # every time a path isn't present, which is the *expected*
    # case for most artifacts.
    local label="$1" path="$2"
    if [ -e "$path" ]; then
        printf '  [rm]   %-50s  %s\n' "$label" "$path"
        if [ "$DRY_RUN" -eq 0 ]; then
            rm -rf "$path"
        fi
    else
        printf '  [skip] %-50s  (not present)\n' "$label"
    fi
    return 0
}

run_cmd() {
    local label="$1"; shift
    printf '  [run]  %-50s  %s\n' "$label" "$*"
    if [ "$DRY_RUN" -eq 0 ]; then
        "$@" || true
    fi
}

echo "==> Stopping any running Grau processes"
if pgrep -f "Grau.app/Contents/MacOS/Grau" >/dev/null 2>&1; then
    printf '  [kill] %s\n' "Grau processes"
    if [ "$DRY_RUN" -eq 0 ]; then
        pkill -f "Grau.app/Contents/MacOS/Grau" || true
        sleep 1
    fi
else
    printf '  [skip] %s (no process)\n' "Grau processes"
fi

echo ""
echo "==> Removing built .app copies"
remove_path "stable build"     "$REPO_ROOT/build/Grau.app"
remove_path "build dir"        "$REPO_ROOT/build"
remove_path "/Applications"    "/Applications/Grau.app"
remove_path "~/Applications"   "$HOME/Applications/Grau.app"

# Find every Grau.app registered with Launch Services — there can be
# old ones from previous DerivedData hashes.
echo ""
echo "==> Removing other Grau.app copies (Launch Services search)"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
if [ -x "$LSREGISTER" ] && [ "$DRY_RUN" -eq 0 ]; then
    # lsregister -dump prints one app path per line; filter to Grau.
    # Keep the repo's own build/ path out of the kill list since the
    # previous step already removed it. `|| true` keeps `set -e` happy
    # when the pipeline yields no matches.
    set +e
    OTHER_APPS=$("$LSREGISTER" -dump 2>/dev/null \
        | grep -E '^[[:space:]]*path:' \
        | grep -E '/Grau\.app' \
        | awk -F': ' '{print $2}' \
        | sed 's/[[:space:]]*$//' \
        | sort -u)
    set -e
    for app in $OTHER_APPS; do
        remove_path "lsreg-found" "$app"
    done
    if [ -z "${OTHER_APPS:-}" ]; then
        printf '  [skip] %s\n' "no Grau.app registered with Launch Services"
    fi
else
    echo "  [skip] lsregister not available or dry-run"
fi

# Xcode's classic DerivedData path (where the un-pinned builds go).
echo ""
echo "==> Removing Xcode DerivedData for grau"
# `set +e` around the glob loop: when the glob matches nothing the
# literal pattern string is returned, and `[ -e ]` on that fails the
# `continue` check. We want the loop to just be a no-op in that case.
set +e
for dd in "$HOME/Library/Developer/Xcode/DerivedData"/grau-*; do
    [ -e "$dd" ] || continue
    remove_path "DerivedData" "$dd"
done
set -e
# If nothing matched, print a skip line so the user sees coverage.
if ! ls "$HOME/Library/Developer/Xcode/DerivedData"/grau-* >/dev/null 2>&1; then
    printf '  [skip] %s\n' "no DerivedData/grau-* directory"
fi

echo ""
echo "==> Removing Library/ artifacts (by bundle id $BUNDLE_ID)"
remove_path "Application Support"  "$HOME/Library/Application Support/$BUNDLE_ID"
remove_path "Preferences"          "$HOME/Library/Preferences/$BUNDLE_ID.plist"
remove_path "Caches"               "$HOME/Library/Caches/$BUNDLE_ID"
remove_path "Logs"                 "$HOME/Library/Logs/$BUNDLE_ID"
remove_path "Containers"           "$HOME/Library/Containers/$BUNDLE_ID"
remove_path "Saved State"          "$HOME/Library/Saved Application State/$BUNDLE_ID.savedState"

# Group containers use prefix lookups; the project.yml doesn't pin one,
# but Sparkle + AutoClean may write under a group. Scan for any group
# whose name contains the bundle id.
if [ -d "$HOME/Library/Group Containers" ]; then
    set +e
    for gc in "$HOME/Library/Group Containers/"*"$BUNDLE_ID"*; do
        [ -e "$gc" ] || continue
        remove_path "Group Container" "$gc"
    done
    set -e
fi

echo ""
echo "==> Removing graucore user data (~/.grau)"
remove_path "grau home"  "$HOME/.grau"

echo ""
echo "==> Resetting TCC grant for $BUNDLE_ID"
run_cmd "tccutil reset" tccutil reset "$BUNDLE_ID"

# Drop Spotlight's cached metadata for the bundle so App Switcher /
# Finder don't surface a phantom Grau entry. Cheap, no-op if absent.
echo ""
echo "==> Forgetting Spotlight metadata"
run_cmd "mdimport -r"  mdimport -r "/Applications" 2>/dev/null

echo ""
if [ "$DRY_RUN" -eq 1 ]; then
    echo "Dry run complete. No files were deleted."
    exit 0
fi

echo "✓ Clean. To reinstall, run:"
echo "    ./scripts/build-and-run.sh"
