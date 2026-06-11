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

# Terminate any running instance first. `open` would otherwise just re-activate the
# already-running (stale) process instead of launching the freshly built binary, which
# silently hides the changes you just built.
if pgrep -f "rubyfree.app/Contents/MacOS/rubyfree" >/dev/null 2>&1; then
    echo "==> terminating running instance"
    pkill -f "rubyfree.app/Contents/MacOS/rubyfree" || true
    sleep 1
fi

mkdir -p "$INSTALL_DIR"
rm -rf "$APP"
cp -R "$ROOT/rubyfree.app" "$APP"

echo "==> launching $APP"
open -n "$APP"
