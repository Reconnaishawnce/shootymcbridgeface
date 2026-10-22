#!/usr/bin/env bash
# Exports a Linux build with the same script export settings as the Android
# APK (compressed binary tokens, release template) and smoke-plays it.
# The editor binary is more forgiving than the release template: a script
# that parses in the editor can fail to load in the exported game, which
# on a phone looks like a gray screen after the splash. This catches that.
# Usage: scripts/ci/check_export.sh [path-to-godot-binary]
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT="${1:-${GODOT:-godot}}"
OUT="build/export-check/shootymcbridgeface.x86_64"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
mkdir -p "$(dirname "$OUT")"

echo "== export Linux (release, binary tokens)"
"$GODOT" --headless --path . --export-release Linux "$OUT" >"$LOG" 2>&1 || true
if grep -qiE "^ERROR|failed" "$LOG"; then
  echo "::error::Linux export reported a problem"; grep -iE "^ERROR|failed" "$LOG" | head -20; exit 1
fi
test -x "$OUT" || { echo "::error::no Linux binary was produced"; exit 1; }

echo "== smoke-play the exported build"
"$OUT" --headless --fixed-fps 60 ++ --smoke 2>&1 | tee "$LOG"
if grep -qE "SCRIPT ERROR|^ERROR:|Parse Error|Compile Error" "$LOG"; then
  echo "::error::the exported build has script errors"; exit 1
fi
grep -q "SMOKE_RESULT" "$LOG" || { echo "::error::the exported build produced no smoke result"; exit 1; }
echo "== exported build passed"
