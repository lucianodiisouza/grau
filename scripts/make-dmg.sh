#!/usr/bin/env bash
#
# make-dmg.sh — package a Release build of Grau into a DMG.
#
# Usage:
#   ./scripts/make-dmg.sh [version]
#
# Default version is read from MARKETING_VERSION in the project file.
# Output: dist/Grau-<version>.dmg
#
# Requirements:
#   - macOS (uses hdiutil, codesign, /usr/libexec/PlistBuddy)
#   - create-dmg (brew install create-dmg) — optional, falls back to
#     hdiutil if missing.
#
# This script is intentionally non-interactive and avoids
# notarization. Run scripts/notarize.sh after this for notarization.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' grau/Info.plist 2>/dev/null || echo "0.0.0")}"
DMG_NAME="Grau-${VERSION}.dmg"
DIST_DIR="$REPO_ROOT/dist"
APP_PATH="$REPO_ROOT/build/Build/Products/Release/grau.app"

echo "==> Building Release configuration"
xcodebuild \
    -project grau.xcodeproj \
    -scheme grau \
    -configuration Release \
    -derivedDataPath build \
    build > /tmp/grau-build.log 2>&1

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: build/Release/grau.app not found" >&2
    echo "Check /tmp/grau-build.log" >&2
    exit 1
fi

echo "==> Codesigning (ad-hoc) for local testing"
codesign --force --sign - --deep "$APP_PATH"

echo "==> Creating $DIST_DIR"
mkdir -p "$DIST_DIR"

STAGING_DIR=$(mktemp -d)
trap 'rm -rf "$STAGING_DIR"' EXIT
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

if command -v create-dmg >/dev/null 2>&1; then
    echo "==> create-dmg available, using it"
    create-dmg \
        --volname "Grau $VERSION" \
        --volicon "$APP_PATH/Contents/Resources/Assets.car" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "grau.app" 175 190 \
        --hide-extension "grau.app" \
        --app-drop-link 425 190 \
        --no-internet-enable \
        "$DIST_DIR/$DMG_NAME" \
        "$STAGING_DIR" || true
fi

if [ ! -f "$DIST_DIR/$DMG_NAME" ]; then
    echo "==> Falling back to hdiutil"
    hdiutil create \
        -volname "Grau $VERSION" \
        -srcfolder "$STAGING_DIR" \
        -ov \
        -format UDZO \
        "$DIST_DIR/$DMG_NAME"
fi

echo "==> Done: $DIST_DIR/$DMG_NAME"
ls -la "$DIST_DIR/$DMG_NAME"
