#!/usr/bin/env bash
set -euo pipefail

# Build a distributable rubyfree.app and package it for a GitHub Release.
#
# Distribution signing is **ad-hoc** ("-"), forced here regardless of any local dev
# certificate: a self-signed cert in this machine's keychain means nothing to a
# downloader, so ad-hoc is the honest, reproducible choice. The app is therefore NOT
# notarized — users verify the published SHA-256 and first-launch via right-click → Open
# (documented in README). The bundle id is fixed, so TCC grants are stable across updates.
#
# This script does NOT publish anything. It produces, under dist/:
#   rubyfree-v<version>-macos-arm64.zip   — the zipped .app
#   rubyfree-v<version>-macos-arm64.zip.sha256  — its checksum
# and prints the exact `gh release create` command to run after manual review.
#
# Usage: ./Scripts/release.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_DIR="$ROOT/rubyfree.app"
DIST_DIR="$ROOT/dist"
ARCH="arm64"   # project targets Apple Silicon / macOS 26 only

# ── 1. Build + sign ad-hoc (override any dev cert) ──────────────────────────
echo "==> building distributable .app (ad-hoc signature)"
RUBYFREE_SIGN_IDENTITY="-" "$ROOT/Scripts/build-app.sh"

# ── 2. Read the version baked into the bundle (single source of truth) ──────
PLIST="$APP_DIR/Contents/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
[ -n "$VERSION" ] || { echo "FAIL: could not read CFBundleShortVersionString"; exit 1; }
echo "==> version: $VERSION"

# ── 3. Non-communication binary audit (release gate) ────────────────────────
echo "==> non-communication audit"
"$ROOT/Scripts/audit-binary.sh" "$APP_DIR"

# ── 4. Confirm the ad-hoc signature actually took ───────────────────────────
echo "==> verifying ad-hoc signature"
if codesign -dvv "$APP_DIR" 2>&1 | grep -q 'Signature=adhoc'; then
    echo "    Signature=adhoc OK"
else
    echo "FAIL: expected an ad-hoc signature on the release build"; exit 1
fi

# ── 5. Package: zip the .app preserving bundle metadata ─────────────────────
BASENAME="rubyfree-v${VERSION}-macos-${ARCH}"
ZIP="$DIST_DIR/${BASENAME}.zip"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
echo "==> packaging $ZIP"
# ditto with --keepParent zips the .app itself (not just its contents) and preserves
# symlinks/extended attributes/codesignature that a plain `zip` would corrupt.
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP"

# ── 6. Checksum ─────────────────────────────────────────────────────────────
SHA_FILE="${ZIP}.sha256"
( cd "$DIST_DIR" && /usr/bin/shasum -a 256 "$(basename "$ZIP")" > "$(basename "$SHA_FILE")" )
SHA="$(awk '{print $1}' "$SHA_FILE")"

# ── 7. Summary + next step (publishing is intentionally manual) ─────────────
echo
echo "==> release artifact ready (NOT published):"
echo "      zip:    $ZIP"
echo "      sha256: $SHA"
echo
echo "    Draft a pre-release (review before publishing) with:"
echo "      gh release create v${VERSION} \"$ZIP\" \\"
echo "        --draft --prerelease --title \"rubyfree v${VERSION}\" --notes-file <notes.md>"
