#!/usr/bin/env bash
# Runs the full local verification: import, unit tests, smoke-play.
# Fails on any GDScript error, because Godot's exit code alone does not.
# Usage: scripts/ci/check.sh [path-to-godot-binary]
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT="${1:-${GODOT:-godot}}"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

fail_on_script_errors() {
  if grep -E "SCRIPT ERROR|^ERROR:|Parse Error|Compile Error" "$LOG" >/dev/null; then
    echo "::error::GDScript errors found in $1 output"
    grep -nE "SCRIPT ERROR|^ERROR:|Parse Error|Compile Error" "$LOG" | head -40
    exit 1
  fi
}

echo "== import"
"$GODOT" --headless --path . --import >"$LOG" 2>&1 || true
fail_on_script_errors import

echo "== unit tests"
"$GODOT" --headless --path . -s tests/run_tests.gd 2>&1 | tee "$LOG"
fail_on_script_errors "unit tests"

echo "== smoke play (900 fixed frames, auto-steer)"
"$GODOT" --headless --path . --fixed-fps 60 ++ --smoke 2>&1 | tee "$LOG"
fail_on_script_errors "smoke play"
grep -q "SMOKE_RESULT" "$LOG" || { echo "::error::smoke run produced no result line"; exit 1; }

echo "== wipe and retry (nightmare, seed 11, a forced wipe at frame 4500: the results screen and the restart)"
"$GODOT" --headless --path . --fixed-fps 60 ++ --smoke --smoke-frames=7000 --smoke-seed=11 --nightmare --smoke-retry --smoke-wipe-at=4500 2>&1 | tee "$LOG"
fail_on_script_errors "wipe and retry"
grep -q "SMOKE_RETRY" "$LOG" || { echo "::error::the bot never reached the results screen and played again"; exit 1; }
echo "== all checks passed"
