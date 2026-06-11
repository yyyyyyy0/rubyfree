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
# Signing identity. S0-1 confirmed a stable self-signed cert ("rubyfree-dev") keeps the
# TCC grant across rebuilds, while ad-hoc ("-") resets it every build (cdhash-based DR).
# Prefer the dev cert when present; fall back to ad-hoc (e.g. CI, which builds Core only).
if [ -n "${RUBYFREE_SIGN_IDENTITY:-}" ]; then
    SIGN_IDENTITY="$RUBYFREE_SIGN_IDENTITY"
elif security find-certificate -c rubyfree-dev >/dev/null 2>&1; then
    SIGN_IDENTITY="rubyfree-dev"
else
    SIGN_IDENTITY="-"
fi

echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG"
BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/${APP_NAME}"

echo "==> assembling ${APP_NAME}.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/${APP_NAME}"
cp "$ROOT/Scripts/Info.plist.template" "$APP_DIR/Contents/Info.plist"

# App icon (referenced by CFBundleIconFile=AppIcon). Committed asset; regenerate with
# `swift Scripts/make-icon.swift Scripts/AppIcon.iconset && iconutil -c icns Scripts/AppIcon.iconset -o Scripts/AppIcon.icns`.
if [ -f "$ROOT/Scripts/AppIcon.icns" ]; then
    cp "$ROOT/Scripts/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
else
    echo "warning: Scripts/AppIcon.icns missing — app will have no icon" >&2
fi

# Copy SwiftPM resource bundles (e.g. the bundled reading dictionary) into
# Contents/Resources so Bundle.module resolves them at runtime. Without this the app
# silently falls back to the lower-accuracy tokenizer.
BIN_DIR="$(dirname "$BIN_PATH")"
shopt -s nullglob
for bundle in "$BIN_DIR"/*.bundle; do
    echo "==> bundling resource: $(basename "$bundle")"
    cp -R "$bundle" "$APP_DIR/Contents/Resources/"
done
shopt -u nullglob

echo "==> codesign (identity: ${SIGN_IDENTITY})"
codesign --force --options runtime \
    --entitlements "$ROOT/Scripts/entitlements.plist" \
    --sign "$SIGN_IDENTITY" \
    "$APP_DIR"

codesign --verify --verbose "$APP_DIR"
echo "==> built ${APP_DIR}"
