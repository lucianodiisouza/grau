#!/usr/bin/env bash
#
# make-appcast.sh — produce a Sparkle appcast.xml for a release.
#
# Usage:
#   # Single-DMG mode (no deltas). Original v1.1 behavior.
#   ./scripts/make-appcast.sh dist/Grau-1.1.0.dmg [release|beta]
#
#   # Directory mode (deltas auto-generated). New in v1.7.
#   # Drop every release DMG you want to ship into ./dist/dmgs/
#   # and run this — Sparkle's generate_appcast will produce
#   # <enclosure sparkle:deltaFrom="..."> entries for every
#   # consecutive version pair, which the Sparkle framework in
#   # the running app uses to download smaller patch files.
#   ./scripts/make-appcast.sh dist/dmgs/ [release|beta]
#
# Output:
#   dist/appcast.xml         (release channel, default)
#   dist/appcast-beta.xml    (--channel beta)
#
# Channel: release (default) | beta
#
# This script depends on Sparkle's `generate_appcast` tool, which
# is at SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast
# after the first `xcodebuild` resolves the Sparkle package.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if [ $# -lt 1 ]; then
    cat <<EOF >&2
Usage: $0 <dmg-path-or-dmg-dir> [channel]

  channel: release (default) | beta

Examples:
  $0 dist/Grau-1.1.0.dmg
  $0 dist/dmgs/ release
EOF
    exit 1
fi

INPUT="$1"
CHANNEL="${2:-release}"

if [ ! -e "$INPUT" ]; then
    echo "Input not found: $INPUT" >&2
    exit 1
fi

# Find generate_appcast from the resolved Sparkle package
GEN=$(find ~/Library/Developer/Xcode/DerivedData -path "*Sparkle*/bin/generate_appcast" -type f 2>/dev/null | head -1)
if [ -z "$GEN" ]; then
    echo "ERROR: generate_appcast not found. Build the project once with xcodebuild to populate the package cache." >&2
    exit 1
fi

echo "==> Using $GEN"
echo "==> Channel: $CHANNEL"

# Stage the inputs. If the input is a directory we copy it as-is
# (generate_appcast scans recursively). If it's a file we copy
# just that file into a fresh staging dir.
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT

MODE="single"
if [ -d "$INPUT" ]; then
    MODE="directory"
    # Copy every DMG into the staging dir, preserving filenames
    # so generate_appcast can pick them up.
    cp "$INPUT"/*.dmg "$STAGING/" 2>/dev/null || {
        echo "ERROR: no .dmg files found in $INPUT" >&2
        exit 1
    }
    DMG_COUNT=$(ls -1 "$STAGING"/*.dmg | wc -l | tr -d ' ')
    echo "==> Found $DMG_COUNT DMG(s) in $INPUT"
    if [ "$DMG_COUNT" -lt 2 ]; then
        echo "    (Note: delta updates require 2+ DMGs. With 1 DMG, no deltas are generated.)"
    else
        echo "    (Will generate delta updates between consecutive versions.)"
    fi
elif [ -f "$INPUT" ]; then
    cp "$INPUT" "$STAGING/"
else
    echo "ERROR: input must be a .dmg file or a directory of .dmg files" >&2
    exit 1
fi

OUTPUT="$REPO_ROOT/dist/appcast.xml"
if [ "$CHANNEL" = "beta" ]; then
    OUTPUT="$REPO_ROOT/dist/appcast-beta.xml"
fi

cd "$STAGING"
if [ "$CHANNEL" = "beta" ]; then
    "$GEN" --channel beta
else
    "$GEN"
fi

if [ ! -f appcast.xml ]; then
    echo "ERROR: generate_appcast did not produce appcast.xml" >&2
    exit 1
fi

mv appcast.xml "$OUTPUT"
echo "==> Wrote $OUTPUT"

# Report how many delta-from entries we generated, so the
# maintainer can sanity-check before publishing.
DELTA_COUNT=$(grep -c 'sparkle:deltaFrom' "$OUTPUT" 2>/dev/null || echo 0)
ITEM_COUNT=$(grep -c '<item>' "$OUTPUT" 2>/dev/null || echo 0)
echo "==> Items: $ITEM_COUNT, delta updates: $DELTA_COUNT"
