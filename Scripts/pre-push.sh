#!/usr/bin/env bash
set -euo pipefail

# Local full-verification gate (the canonical pre-push command for this repo).
# CI only covers RubyfreeCore; the .app build + binary audit run here.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> swift build"
swift build

echo "==> tests (TinyTest executables)"
swift run RubyfreeCoreTests
swift run RubyfreeSystemTests

echo "==> network source guard"
if grep -REn 'URLSession|import Network|CFSocket|NWConnection|getaddrinfo' Sources/; then
    echo "FAIL: networking API found in Sources/"; exit 1
fi

echo "==> Core coverage gate"
./Scripts/coverage.sh

echo "==> build .app + binary audit"
./Scripts/build-app.sh
./Scripts/audit-binary.sh "$ROOT/rubyfree.app"

echo "==> pre-push OK"
