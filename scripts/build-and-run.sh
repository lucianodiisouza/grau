#!/usr/bin/env bash
#
# build-and-run.sh — build Grau into a stable path and launch it.
#
# Why this exists:
#   Every `xcodebuild` writes the .app to
#   ~/Library/Developer/Xcode/DerivedData/<hash>/.../Grau.app
#   where <hash> changes when project settings change. macOS TCC
#   grants Full Disk Access by *path* (Launch Services identity),
#   so every new build wipes the grant and the user has to
#   re-authorize the app in System Settings.
#
# This script forces the .app into ./build/Grau.app (a fixed path
# in the repo). Run it once, then keep using the same script:
#   - Launch Services always sees the same path
#   - TCC keeps the Full Disk Access grant across rebuilds
#   - The "Permissões não persistem" screen stops showing up
#
# Usage:
#   ./scripts/build-and-run.sh         # build + launch
#   ./scripts/build-and-run.sh --no-run  # just build
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

RUN_AFTER=1
for arg in "$@"; do
    case "$arg" in
        --no-run) RUN_AFTER=0 ;;
        *) echo "Unknown arg: $arg" >&2; exit 1 ;;
    esac
done

STABLE_APP="$REPO_ROOT/build/Grau.app"
CONFIG="Debug"

echo "==> Building grau (Debug) into $STABLE_APP"

# Use -derivedDataPath so DerivedData also lives inside ./build
# (keeps everything in the repo, easier to .gitignore one place).
xcodebuild \
    -project grau.xcodeproj \
    -scheme grau \
    -configuration "$CONFIG" \
    -derivedDataPath "$REPO_ROOT/build/DerivedData" \
    -destination 'platform=macOS' \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build > /tmp/grau-build.log 2>&1 || {
        echo "Build failed. Last 40 lines:" >&2
        tail -40 /tmp/grau-build.log >&2
        exit 1
    }

# xcodebuild's actual output goes into DerivedData/Build/Products/<Config>
DERIVED_APP="$REPO_ROOT/build/DerivedData/Build/Products/$CONFIG/Grau.app"

if [ ! -d "$DERIVED_APP" ]; then
    echo "Build did not produce $DERIVED_APP" >&2
    exit 1
fi

# Make sure the stable path exists, then sync the built .app into it.
mkdir -p "$(dirname "$STABLE_APP")"
rm -rf "$STABLE_APP"
cp -R "$DERIVED_APP" "$STABLE_APP"

# Re-register with Launch Services so the stable path becomes the
# canonical identity. This is what makes TCC stop asking again.
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
if [ -x "$LSREGISTER" ]; then
    "$LSREGISTER" -f "$STABLE_APP" >/dev/null 2>&1 || true
fi

echo "✓ Built: $STABLE_APP"

if [ "$RUN_AFTER" -eq 1 ]; then
    echo "==> Launching"
    open "$STABLE_APP"
fi
