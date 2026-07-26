#!/usr/bin/env bash
#
# make-appcast.sh — produce a Sparkle appcast.xml for a release.
#
# Usage:
#   ./scripts/make-appcast.sh <version> <dmg-path> [channel]
#
# Example:
#   ./scripts/make-appcast.sh 1.1.0 dist/Grau-1.1.0.dmg release
#
# Output: dist/appcast.xml (one <item> per call). Append to the
# live appcast hosted at https://lucianodiisouza.github.io/grau/
# appcast.xml on every release.
#
# This script depends on Sparkle's `generate_appcast` tool, which
# is at SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast
# after the first `xcodebuild` resolves the Sparkle package.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if [ $# -lt 2 ]; then
    echo "Usage: $0 <version> <dmg-path> [channel]" >&2
    echo "  channel: release (default) | beta" >&2
    exit 1
fi

VERSION="$1"
DMG_PATH="$2"
CHANNEL="${3:-release}"

if [ ! -f "$DMG_PATH" ]; then
    echo "DMG not found: $DMG_PATH" >&2
    exit 1
fi

# Find generate_appcast from the resolved Sparkle package
GEN=$(find ~/Library/Developer/Xcode/DerivedData -path "*Sparkle*/bin/generate_appcast" -type f 2>/dev/null | head -1)
if [ -z "$GEN" ]; then
    echo "ERROR: generate_appcast not found. Build the project once with xcodebuild to populate the package cache." >&2
    exit 1
fi

echo "==> Using $GEN"

# Sparkle's generate_appcast scans a directory of DMGs and writes
# appcast.xml. We stage the DMG in a temp dir and re-run from there.
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
cp "$DMG_PATH" "$STAGING/"
if [ "$CHANNEL" = "beta" ]; then
    cd "$STAGING"
    "$GEN" --channel beta
    mv appcast.xml "$REPO_ROOT/dist/appcast-beta.xml"
    echo "==> Wrote dist/appcast-beta.xml (channel: beta)"
else
    cd "$STAGING"
    "$GEN"
    mv appcast.xml "$REPO_ROOT/dist/appcast.xml"
    echo "==> Wrote dist/appcast.xml (channel: release)"
fi
