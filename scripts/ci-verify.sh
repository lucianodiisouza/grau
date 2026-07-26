#!/usr/bin/env bash
#
# ci-verify.sh — run the same checks CI runs. Useful for
# contributors running locally before pushing.
#
# Usage:
#   ./scripts/ci-verify.sh
#
# Steps:
#   1. xcodegen generate (regenerate the Xcode project).
#   2. cd graucore && swift build (compile the package).
#   3. cd graucore && swift test   (run all unit tests).
#   4. xcodebuild ... -configuration Debug build.
#   5. xcodebuild ... -configuration Release build.
#   6. Privacy manifest sanity check.
#
# Exits non-zero on the first failure. Use --release-only to
# skip the Debug build for a faster local run.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

RELEASE_ONLY=0
for arg in "$@"; do
    case "$arg" in
        --release-only) RELEASE_ONLY=1 ;;
        *) echo "Unknown arg: $arg" >&2; exit 1 ;;
    esac
done

echo "==> [1/6] xcodegen generate"
xcodegen generate

echo "==> [2/6] cd graucore && swift build"
(cd graucore && swift build)

echo "==> [3/6] cd graucore && swift test"
(cd graucore && swift test)

if [ "$RELEASE_ONLY" -eq 0 ]; then
    echo "==> [4/6] xcodebuild ... -configuration Debug build"
    xcodebuild -project grau.xcodeproj -scheme grau \
        -configuration Debug -destination 'platform=macOS' \
        build > /tmp/grau-debug.log 2>&1 || {
            echo "Debug build failed. Last 30 lines:" >&2
            tail -30 /tmp/grau-debug.log >&2
            exit 1
        }
fi

echo "==> [5/6] xcodebuild ... -configuration Release build"
xcodebuild -project grau.xcodeproj -scheme grau \
    -configuration Release -destination 'platform=macOS' \
    build > /tmp/grau-release.log 2>&1 || {
        echo "Release build failed. Last 30 lines:" >&2
        tail -30 /tmp/grau-release.log >&2
        exit 1
    }

echo "==> [6/6] Privacy manifest sanity check"
PRIVACY="grau/PrivacyInfo.xcprivacy"
if [ ! -f "$PRIVACY" ]; then
    echo "ERROR: $PRIVACY is missing" >&2
    exit 1
fi
for api in FileTimestamp DiskSpace SystemBootTime UserDefaults; do
    if ! /usr/libexec/PlistBuddy -c "Print :NSPrivacyAccessedAPITypes" "$PRIVACY" \
        | grep -q "$api"; then
        echo "ERROR: Privacy manifest is missing $api" >&2
        exit 1
    fi
done

echo ""
echo "✓ All checks passed."
