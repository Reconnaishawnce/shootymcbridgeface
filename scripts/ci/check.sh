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
grep "SMOKE_LB" "$LOG" | grep -q '"closed":true' && grep "SMOKE_LB" "$LOG" | grep -q '"opened":true' || { echo "::error::the leaderboard page did not open and close over the home screen"; exit 1; }
grep "SMOKE_TELEMETRY" "$LOG" | grep -q '"fits":true' && grep "SMOKE_TELEMETRY" "$LOG" | grep -q '"signed":true' || { echo "::error::the crash report did not build, fit and sign"; exit 1; }
grep "SMOKE_TELEMETRY" "$LOG" | grep -q '"traced":true' || { echo "::error::the report carries no performance trace with game gauges"; exit 1; }

grep "SMOKE_ABILITY" "$LOG" | grep -q '"id":"volley"' || { echo "::error::the rifle squad never fired its volley"; exit 1; }

echo "== the sinks: every boost armed and a tier of every upgrade enlisted"
"$GODOT" --headless --path . --fixed-fps 60 ++ --smoke --smoke-frames=900 --smoke-boosts 2>&1 | tee "$LOG"
fail_on_script_errors "boosts smoke"
grep "SMOKE_BOOSTS" "$LOG" | grep -q '"bombs":2' && grep "SMOKE_BOOSTS" "$LOG" | grep -q '"damage":1.25' && grep "SMOKE_BOOSTS" "$LOG" | grep -q '"winds":1' && grep "SMOKE_BOOSTS" "$LOG" | grep -q '"coin_mult":2' && grep "SMOKE_BOOSTS" "$LOG" | grep -q '"left_armed":false' || { echo "::error::the per-run boosts did not reach the run or were not spent"; exit 1; }
grep "SMOKE_BOOSTS" "$LOG" | grep -q '"power":1' || { echo "::error::the enlist tier did not stick"; exit 1; }

echo "== the other squads' moves (shotgun shockwave, medic heal pulse)"
"$GODOT" --headless --path . --fixed-fps 60 ++ --smoke --smoke-frames=900 --smoke-squad=shotgun 2>&1 | tee "$LOG"
fail_on_script_errors "shotgun smoke"
grep "SMOKE_ABILITY" "$LOG" | grep -q '"id":"shockwave"' || { echo "::error::the shotgun squad never fired its shockwave"; exit 1; }
"$GODOT" --headless --path . --fixed-fps 60 ++ --smoke --smoke-frames=900 --smoke-squad=medic 2>&1 | tee "$LOG"
fail_on_script_errors "medic smoke"
grep "SMOKE_ABILITY" "$LOG" | grep -q '"id":"heal"' || { echo "::error::the medic squad never sent its heal pulse"; exit 1; }
"$GODOT" --headless --path . --fixed-fps 60 ++ --smoke --smoke-frames=900 --smoke-squad=sniper 2>&1 | tee "$LOG"
fail_on_script_errors "sniper smoke"
grep "SMOKE_ABILITY" "$LOG" | grep -q '"id":"longshot"' || { echo "::error::the sniper squad never fired its longshot"; exit 1; }

echo "== boss rush (one gate, then the boss) and a saw storm event"
"$GODOT" --headless --path . --fixed-fps 60 ++ --smoke --smoke-frames=2400 --rush --smoke-upgrades 2>&1 | tee "$LOG"
fail_on_script_errors "rush smoke"
grep -q "SMOKE_RUSH" "$LOG" || { echo "::error::the boss rush never killed a boss"; exit 1; }
grep -q "SMOKE_CARD " "$LOG" || { echo "::error::a boss fell and no build card was drafted"; exit 1; }

echo "== heroes: each one's power reaches the run"
for pair in max:move_soldiers zuri:gate_soldiers luna:ghost kofi:calm rex:shove mei:refill; do
  hero="${pair%%:*}"; fx="${pair##*:}"
  "$GODOT" --headless --path . --fixed-fps 60 ++ --smoke --smoke-frames=1200 --smoke-hero="$hero" 2>&1 | tee "$LOG"
  fail_on_script_errors "$hero smoke"
  grep "SMOKE_HERO" "$LOG" | grep -q "\"$fx\":[1-9]" || { echo "::error::$hero's power ($fx) never fired"; exit 1; }
done

echo "== build cards: every card held, every effect fires"
"$GODOT" --headless --path . --fixed-fps 60 ++ --smoke --smoke-frames=1500 --smoke-cards=all 2>&1 | tee "$LOG"
fail_on_script_errors "cards smoke"
for fx in ricochet burn slow blast crit execute medic; do
  grep "SMOKE_CARDFX" "$LOG" | grep -q "\"$fx\":[1-9]" || { echo "::error::the $fx card effect never fired"; exit 1; }
done
grep "SMOKE_CARDFX" "$LOG" | grep -q '"firestorm","shatter","wildfire","chain"' || { echo "::error::the combos did not all form"; exit 1; }
grep "SMOKE_CARDFX" "$LOG" | grep -q '"turrets":2' || { echo "::error::the sentry cards put no turrets on the curb"; exit 1; }
"$GODOT" --headless --path . --fixed-fps 60 ++ --smoke --smoke-frames=3000 --smoke-event=saw_storm --smoke-seed=3 2>&1 | tee "$LOG"
fail_on_script_errors "saw storm smoke"
grep -q "SMOKE_SAW" "$LOG" || { echo "::error::the saw storm rolled no saw past the squad"; exit 1; }

echo "== wipe and retry (nightmare, seed 11, a forced wipe at frame 4500: the results screen and the restart)"
"$GODOT" --headless --path . --fixed-fps 60 ++ --smoke --smoke-frames=7000 --smoke-seed=11 --nightmare --smoke-retry --smoke-wipe-at=4500 2>&1 | tee "$LOG"
fail_on_script_errors "wipe and retry"
grep -q "SMOKE_RETRY" "$LOG" || { echo "::error::the bot never reached the results screen and played again"; exit 1; }
# The busiest the scene got: a budget on nodes, so a change that doubles
# the bodies on screen (the busy-screen freezes on phones) is caught here.
peak_nodes="$(grep SMOKE_PERF "$LOG" | tail -1 | sed 's/SMOKE_PERF //' | python3 -c 'import sys,json; print(json.load(sys.stdin)["nodes"])')"
echo "peak nodes: $peak_nodes"
[ "$peak_nodes" -le 9000 ] || { echo "::error::the scene peaked at $peak_nodes nodes, over the 9000 budget"; exit 1; }
echo "== all checks passed"
