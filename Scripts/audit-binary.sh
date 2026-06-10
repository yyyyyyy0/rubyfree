#!/usr/bin/env bash
set -euo pipefail

# Non-communication binary audit (defence-in-depth, heuristic — NOT a proof).
# Fails if the built binary links/references networking, or if dangerous entitlements
# are present. Run against the assembled .app.

APP="${1:-rubyfree.app}"
BIN="$APP/Contents/MacOS/rubyfree"
[ -f "$BIN" ] || { echo "binary not found: $BIN"; exit 1; }

fail=0

echo "==> otool -L (directly linked libraries)"
LINKS="$(otool -L "$BIN")"
echo "$LINKS"
# Only flag networking libs linked DIRECTLY by our binary (AppKit/Foundation may pull
# CFNetwork transitively; that is not a direct dependency of ours).
if echo "$LINKS" | grep -Eiq '/(CFNetwork|libcurl|libssl|libnetwork)'; then
    echo "FAIL: networking library linked directly"; fail=1
fi

echo "==> nm -u (undefined symbols referenced)"
SYMS="$(nm -u "$BIN" 2>/dev/null || true)"
if echo "$SYMS" | grep -Eiq 'URLSession|NWConnection|NWBrowser|CFSocket|getaddrinfo|SCNetworkReachability'; then
    echo "FAIL: networking symbol referenced"; fail=1
fi

echo "==> codesign entitlements"
ENT="$(codesign -d --entitlements - --xml "$APP" 2>/dev/null || true)"
if echo "$ENT" | grep -q 'com.apple.security.network.client'; then
    echo "FAIL: network.client entitlement present"; fail=1
fi
if echo "$ENT" | grep -q 'disable-library-validation'; then
    echo "FAIL: library validation disabled"; fail=1
fi

if [ "$fail" -eq 0 ]; then
    echo "==> audit PASSED"
else
    echo "==> audit FAILED"; exit 1
fi
