#!/usr/bin/env bash
set -euo pipefail

# Builds Gmail.app from the SPM executable and substitutes the Google OAuth
# client ID into Info.plist. Requires Swift 6.0+ and macOS 14+.
#
# Usage:
#   OAUTH_CLIENT_ID="123-abc.apps.googleusercontent.com" ./scripts/build.sh
#
# After building, move Gmail.app to /Applications and launch via Spotlight or
# `open Gmail.app`.

CLIENT_ID="${OAUTH_CLIENT_ID:-}"
CLIENT_SECRET="${OAUTH_CLIENT_SECRET:-}"
if [[ -z "$CLIENT_ID" || -z "$CLIENT_SECRET" ]]; then
    echo "ERROR: Set OAUTH_CLIENT_ID and OAUTH_CLIENT_SECRET before building."
    echo
    echo "How to get them:"
    echo "  1. Visit https://console.cloud.google.com/apis/credentials"
    echo "  2. Create OAuth 2.0 Client ID, type = Desktop app"
    echo "  3. Copy both the Client ID and Client Secret"
    echo
    echo "Then re-run:"
    echo "  OAUTH_CLIENT_ID=\"<id>.apps.googleusercontent.com\" \\"
    echo "  OAUTH_CLIENT_SECRET=\"GOCSPX-...\" \\"
    echo "  ./scripts/build.sh"
    echo
    echo "Note: Google treats Desktop app secrets as non-confidential, but you"
    echo "      should still keep them out of public repos. The secret lands in"
    echo "      Gmail.app/Contents/Info.plist (the bundle is gitignored)."
    exit 1
fi

if [[ "$CLIENT_ID" != *.apps.googleusercontent.com ]]; then
    echo "ERROR: OAUTH_CLIENT_ID must end with .apps.googleusercontent.com"
    exit 1
fi

REVERSED="${CLIENT_ID%.apps.googleusercontent.com}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "Building release binary..."
swift build -c release

APP="$REPO_ROOT/Gmail.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$REPO_ROOT/.build/release/Gmail" "$APP/Contents/MacOS/Gmail"

sed \
    -e "s|__OAUTH_CLIENT_ID__|${CLIENT_ID}|g" \
    -e "s|__OAUTH_CLIENT_SECRET__|${CLIENT_SECRET}|g" \
    -e "s|__OAUTH_REVERSED_ID__|${REVERSED}|g" \
    "$REPO_ROOT/scripts/Info.plist.template" > "$APP/Contents/Info.plist"

echo
echo "Built: $APP"
echo "Launch with: open \"$APP\""
echo
echo "Note: macOS Gatekeeper will prompt on first launch (unsigned binary)."
echo "Right-click → Open the first time, or run:"
echo "  xattr -d com.apple.quarantine \"$APP\""
