#!/usr/bin/env bash
#
# notarize.sh — submit a signed Grau build to Apple's notary service
# and staple the ticket.
#
# Usage:
#   ./scripts/notarize.sh <dmg-or-zip> \
#       --team-id <TEAM_ID> \
#       --apple-id <APPLE_ID_EMAIL> \
#       --keychain-profile <KEYCHAIN_PROFILE_NAME>
#
# Prereqs (one-time setup):
#   1. Enroll in the Apple Developer Program.
#   2. Create a Developer ID Application certificate and import it
#      into your keychain.
#   3. Generate an App Store Connect API key and create a keychain
#      profile:
#         xcrun notarytool store-credentials <KEYCHAIN_PROFILE_NAME> \
#             --apple-id <APPLE_ID_EMAIL> \
#             --team-id <TEAM_ID> \
#             --key <PATH_TO_P8_KEY> \
#             --key-id <KEY_ID> \
#             --issuer <ISSUER_ID>
#
# This script is intentionally non-interactive. The notarization
# step can take 1–10 minutes.

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <dmg-or-zip> --team-id <id> --keychain-profile <name>" >&2
    exit 1
fi

ARTIFACT="$1"
shift

TEAM_ID=""
KEYCHAIN_PROFILE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --team-id) TEAM_ID="$2"; shift 2 ;;
        --keychain-profile) KEYCHAIN_PROFILE="$2"; shift 2 ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

if [ -z "$TEAM_ID" ] || [ -z "$KEYCHAIN_PROFILE" ]; then
    echo "Both --team-id and --keychain-profile are required" >&2
    exit 1
fi

if [ ! -f "$ARTIFACT" ]; then
    echo "Artifact not found: $ARTIFACT" >&2
    exit 1
fi

echo "==> Submitting $ARTIFACT to notarytool"
xcrun notarytool submit "$ARTIFACT" \
    --team-id "$TEAM_ID" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

echo "==> Stapling ticket"
xcrun stapler staple "$ARTIFACT"

echo "==> Verifying"
xcrun stapler validate "$ARTIFACT"

echo "==> Done. Artifact is notarized + stapled:"
echo "    $ARTIFACT"
