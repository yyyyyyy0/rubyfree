#!/usr/bin/env bash
set -euo pipefail

# Build rubyfree.app and install it to a FIXED path, then launch it.
#
# A stable install path + fixed bundle id keeps the TCC subject identity stable across
# rebuilds, so Accessibility / Screen Recording grants are not lost. Do NOT use
# `swift run` for permission-dependent testing: that binary lives at a build-specific
# path and is a different TCC subject, so it would re-prompt every build.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${RUBYFREE_INSTALL_DIR:-$HOME/Applications}"
APP="$INSTALL_DIR/rubyfree.app"

"$ROOT/Scripts/build-app.sh"

mkdir -p "$INSTALL_DIR"
rm -rf "$APP"
cp -R "$ROOT/rubyfree.app" "$APP"

echo "==> launching $APP"
open "$APP"
