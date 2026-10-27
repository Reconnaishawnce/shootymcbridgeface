#!/usr/bin/env bash
# Soak: many seeds across every mode and modifier, with the retry path,
# failing on any GDScript error. Longer than check.sh; run it before a
# release that touches the run loop, or when a phone reports a freeze.
# Usage: scripts/ci/soak.sh [path-to-godot-binary] [seeds=6] [frames=7000]
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT="${1:-${GODOT:-godot}}"
SEEDS="${2:-6}"
FRAMES="${3:-7000}"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
fails=0
runs=0
for mode in "" "--endless" "--daily" "--weekly"; do
  for mod in "" "--hard" "--nightmare" "--smoke-upgrades"; do
    for seed in $(seq 1 "$SEEDS"); do
      runs=$((runs + 1))
      # shellcheck disable=SC2086
      if ! "$GODOT" --headless --path . --fixed-fps 60 ++ --smoke --smoke-frames="$FRAMES" --smoke-seed="$seed" --smoke-retry $mode $mod >"$LOG" 2>&1; then
        echo "exit code non-zero: mode=$mode mod=$mod seed=$seed"
      fi
      if grep -E "SCRIPT ERROR|^ERROR:|Parse Error|Compile Error" "$LOG" >/dev/null; then
        fails=$((fails + 1))
        echo "::error::GDScript error: mode=${mode:-levels} mod=${mod:-normal} seed=$seed"
        grep -nE "SCRIPT ERROR|^ERROR:|Parse Error|Compile Error" "$LOG" | head -10
      fi
      result="$(grep SMOKE_RESULT "$LOG" | tail -1 | sed 's/SMOKE_RESULT //')"
      echo "mode=${mode:-levels} mod=${mod:-normal} seed=$seed $(echo "$result" | python3 -c 'import sys,json; d=json.load(sys.stdin); print("level", d["level"], "score", d["score"], "peak", d["peak_squad"], "state", d["state"], "retries", d["retries"])' 2>/dev/null || echo 'no result')"
    done
  done
done
echo "== soak: $runs runs, $fails with errors"
[ "$fails" -eq 0 ]
