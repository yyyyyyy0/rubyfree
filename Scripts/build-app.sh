#!/usr/bin/env bash
set -euo pipefail

# Assemble rubyfree.app from the SwiftPM executable and ad-hoc codesign it with the
# Hardened Runtime. SwiftPM cannot emit a macOS .app, so the bundle is hand-built.
#
# Signing identity is provisional pending the S0-1 spike: ad-hoc ("-") by default; if
# ad-hoc fails to preserve TCC grants across rebuilds, set RUBYFREE_SIGN_IDENTITY to a
# stable self-signed certificate name.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="rubyfree"
CONFIG="release"
APP_DIR="$ROOT/${APP_NAME}.app"
SIGN_IDENTITY="${RUBYFREE_SIGN_IDENTITY:--}"   # default ad-hoc "-"; override for self-signed cert

echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG"
BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/${APP_NAME}"

echo "==> assembling ${APP_NAME}.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/${APP_NAME}"
cp "$ROOT/Scripts/Info.plist.template" "$APP_DIR/Contents/Info.plist"

echo "==> codesign (identity: ${SIGN_IDENTITY})"
codesign --force --options runtime \
    --entitlements "$ROOT/Scripts/entitlements.plist" \
    --sign "$SIGN_IDENTITY" \
    "$APP_DIR"

codesign --verify --verbose "$APP_DIR"
echo "==> built ${APP_DIR}"
