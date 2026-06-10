#!/usr/bin/env bash
set -euo pipefail

# Measure RubyfreeCore line coverage via the TinyTest executable + llvm-cov, and gate
# at a threshold. Command Line Tools has no `swift test`, so we instrument the build,
# run the test executable to emit a raw profile, and report on Sources/RubyfreeCore only.
#
# Threshold defaults to 80% (the M2+ requirement). The M1 skeleton has trivial code;
# set RUBYFREE_COV_MIN=0 to make this informational while scaffolding.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
THRESHOLD="${RUBYFREE_COV_MIN:-80}"

swift build --enable-code-coverage >/dev/null
BIN_PATH="$(swift build --enable-code-coverage --show-bin-path)"
TEST_BIN="$BIN_PATH/RubyfreeCoreTests"

PROFRAW="$ROOT/.build/cov-core.profraw"
PROFDATA="$ROOT/.build/cov-core.profdata"
LLVM_PROFILE_FILE="$PROFRAW" "$TEST_BIN" >/dev/null

xcrun llvm-profdata merge -sparse "$PROFRAW" -o "$PROFDATA"

# Report on product code only: exclude the test executables and the TinyTest harness.
# (RubyfreeCoreTests only links RubyfreeCore + TinyTest, so what remains is Core.)
IGNORE='(/Tests/|/Sources/TinyTest/)'

echo "==> RubyfreeCore coverage"
xcrun llvm-cov report "$TEST_BIN" -instr-profile="$PROFDATA" --ignore-filename-regex="$IGNORE"

PCT="$(xcrun llvm-cov export "$TEST_BIN" -instr-profile="$PROFDATA" -summary-only \
        --ignore-filename-regex="$IGNORE" 2>/dev/null \
      | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["data"][0]["totals"]["lines"]["percent"])')"

printf '==> Core line coverage: %.2f%% (threshold %s%%)\n' "$PCT" "$THRESHOLD"
awk -v p="$PCT" -v t="$THRESHOLD" 'BEGIN { exit !(p+0 >= t+0) }' \
    || { echo "FAIL: coverage below threshold"; exit 1; }
echo "==> coverage OK"
