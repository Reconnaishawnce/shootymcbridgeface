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

echo "== smoke play (1300 fixed frames, auto-steer)"
DUMP="$(mktemp)"
"$GODOT" --headless --path . --fixed-fps 60 ++ --smoke --smoke-dump="$DUMP" 2>&1 | tee "$LOG"
fail_on_script_errors "smoke play"
grep -q "SMOKE_RESULT" "$LOG" || { echo "::error::smoke run produced no result line"; exit 1; }
grep "SMOKE_LB" "$LOG" | grep -q '"closed":true' && grep "SMOKE_LB" "$LOG" | grep -q '"opened":true' || { echo "::error::the leaderboard page did not open and close over the home screen"; exit 1; }
grep "SMOKE_TELEMETRY" "$LOG" | grep -q '"fits":true' && grep "SMOKE_TELEMETRY" "$LOG" | grep -q '"signed":true' || { echo "::error::the crash report did not build, fit and sign"; exit 1; }
grep "SMOKE_FLIGHT" "$LOG" | grep -q '"fits":true' && grep "SMOKE_FLIGHT" "$LOG" | grep -q '"signed":true' && grep "SMOKE_FLIGHT" "$LOG" | grep -q '"gauges":true' && grep "SMOKE_FLIGHT" "$LOG" | grep -q '"rows":[1-9][0-9]' || { echo "::error::the flight recorder did not record a row a second and build a signed chunk"; exit 1; }
grep "SMOKE_FLIGHT" "$LOG" | grep -q '"in_report":[1-9]' || { echo "::error::the report does not carry the flight recorder"; exit 1; }
# The game's own report and log chunk, given to the Worker's own code:
# if signing, sizes or shapes drift apart, it shows here.
if command -v node >/dev/null 2>&1; then
  node leaderboard/accept.mjs "$DUMP" || { echo "::error::the Worker would refuse what the game sends"; exit 1; }
else
  echo "(node not found: skipping the game-to-Worker check)"
fi
rm -f "$DUMP"
# Level 1 is a stroll: a slow road, slow bullets, a few fat rounds.
grep "SMOKE_PACE" "$LOG" | grep -q '"level":1,' && grep "SMOKE_PACE" "$LOG" | grep -q '"bullet":22' && grep "SMOKE_PACE" "$LOG" | grep -q '"max_shots":10' && grep "SMOKE_PACE" "$LOG" | grep -q '"danger":1' || { echo "::error::level 1 is not at the slow starting tempo"; exit 1; }
grep "SMOKE_TELEMETRY" "$LOG" | grep -q '"traced":true' || { echo "::error::the report carries no performance trace with game gauges"; exit 1; }

grep "SMOKE_ABILITY" "$LOG" | grep -q '"id":"volley"' || { echo "::error::the rifle squad never fired its volley"; exit 1; }

echo "== the sinks: every boost armed and a tier of every upgrade enlisted"
"$GODOT" --headless --path . --fixed-fps 60 ++ --smoke --smoke-frames=1300 --smoke-boosts 2>&1 | tee "$LOG"
fail_on_script_errors "boosts smoke"
grep "SMOKE_BOOSTS" "$LOG" | grep -q '"bombs":2' && grep "SMOKE_BOOSTS" "$LOG" | grep -q '"damage":1.25' && grep "SMOKE_BOOSTS" "$LOG" | grep -q '"winds":1' && grep "SMOKE_BOOSTS" "$LOG" | grep -q '"coin_mult":2' && grep "SMOKE_BOOSTS" "$LOG" | grep -q '"left_armed":false' || { echo "::error::the per-run boosts did not reach the run or were not spent"; exit 1; }
grep "SMOKE_BOOSTS" "$LOG" | grep -q '"power":1' || { echo "::error::the enlist tier did not stick"; exit 1; }

echo "== the other squads' moves (shotgun shockwave, medic heal pulse)"
"$GODOT" --headless --path . --fixed-fps 60 ++ --smoke --smoke-frames=1300 --smoke-squad=shotgun 2>&1 | tee "$LOG"
fail_on_script_errors "shotgun smoke"
grep "SMOKE_ABILITY" "$LOG" | grep -q '"id":"shockwave"' || { echo "::error::the shotgun squad never fired its shockwave"; exit 1; }
"$GODOT" --headless --path . --fixed-fps 60 ++ --smoke --smoke-frames=1300 --smoke-squad=medic 2>&1 | tee "$LOG"
fail_on_script_errors "medic smoke"
grep "SMOKE_ABILITY" "$LOG" | grep -q '"id":"heal"' || { echo "::error::the medic squad never sent its heal pulse"; exit 1; }
"$GODOT" --headless --path . --fixed-fps 60 ++ --smoke --smoke-frames=1300 --smoke-squad=sniper 2>&1 | tee "$LOG"
fail_on_script_errors "sniper smoke"
grep "SMOKE_ABILITY" "$LOG" | grep -q '"id":"longshot"' || { echo "::error::the sniper squad never fired its longshot"; exit 1; }

echo "== boss rush (one gate, then the boss) and a saw storm event"
"$GODOT" --headless --path . --fixed-fps 60 ++ --smoke --smoke-frames=3200 --rush --smoke-upgrades 2>&1 | tee "$LOG"
fail_on_script_errors "rush smoke"
grep -q "SMOKE_RUSH" "$LOG" || { echo "::error::the boss rush never killed a boss"; exit 1; }
grep -q "SMOKE_CARD " "$LOG" || { echo "::error::a boss fell and no build card was drafted"; exit 1; }

echo "== rivals: the run passes the names above it, lowest first"
"$GODOT" --headless --path . --fixed-fps 60 ++ --smoke --smoke-frames=1900 --smoke-rivals 2>&1 | tee "$LOG"
fail_on_script_errors "rivals smoke"
grep "SMOKE_RIVALS" "$LOG" | grep -q '"passed":\["BOT B","YOUR BEST","BOT A"\]' || { echo "::error::the rivals were not passed in order"; exit 1; }

echo "== chests: a finished run turns its quest rewards into chests"
"$GODOT" --headless --path . --fixed-fps 60 ++ --smoke --smoke-frames=7000 --smoke-seed=2 --smoke-retry --smoke-wipe-at=4666 2>&1 | tee "$LOG"
fail_on_script_errors "chests smoke"
grep "SMOKE_CHESTS" "$LOG" | grep -q '"n":[1-9]' || { echo "::error::a run that finished quests earned no chests"; exit 1; }

echo "== level themes: a storm level throws lightning, a long run changes places"
"$GODOT" --headless --path . --fixed-fps 60 ++ --smoke --smoke-frames=2100 --smoke-level=11 --smoke-upgrades 2>&1 | tee "$LOG"
fail_on_script_errors "storm smoke"
grep "SMOKE_THEMES" "$LOG" | grep -q '"now":"storm"' || { echo "::error::level 11 is not the storm front"; exit 1; }
grep "SMOKE_THEMES" "$LOG" | grep -q '"strikes":[1-9]' || { echo "::error::the storm front threw no lightning"; exit 1; }
"$GODOT" --headless --path . --fixed-fps 60 ++ --smoke --smoke-frames=6500 2>&1 | tee "$LOG"
fail_on_script_errors "themes smoke"
# By level 3 the run has wound up a notch, and the road has slowed for
# at least one gate that needed reading.
grep "SMOKE_PACE" "$LOG" | grep -Eq '"bullet":(2[4-9]|3[0-9])' || { echo "::error::bullets did not speed up with the levels"; exit 1; }
# The second boss throws things: something was lobbed at the squad.
grep "SMOKE_PACE" "$LOG" | grep -q '"lobs":[1-9]' || { echo "::error::no boss lobbed anything in three levels"; exit 1; }
grep "SMOKE_PACE" "$LOG" | grep -q '"think_zones":[1-9]' || { echo "::error::the road never slowed for a thinking gate"; exit 1; }
grep "SMOKE_THEME " "$LOG" | grep -q '"id":"gold"' && grep "SMOKE_THEME " "$LOG" | grep -q '"id":"night"' || { echo "::error::a run through three levels did not change theme twice"; exit 1; }

echo "== heroes: each one's power reaches the run"
for pair in max:move_soldiers zuri:gate_soldiers luna:ghost kofi:calm rex:shove mei:refill; do
  hero="${pair%%:*}"; fx="${pair##*:}"
  "$GODOT" --headless --path . --fixed-fps 60 ++ --smoke --smoke-frames=1700 --smoke-hero="$hero" 2>&1 | tee "$LOG"
  fail_on_script_errors "$hero smoke"
  grep "SMOKE_HERO" "$LOG" | grep -q "\"$fx\":[1-9]" || { echo "::error::$hero's power ($fx) never fired"; exit 1; }
done

echo "== build cards: every card held, every effect fires"
# From level 6: on the first levels one bullet kills a walker, and a
# zombie has to outlive a hit to be slowed or finished off.
"$GODOT" --headless --path . --fixed-fps 60 ++ --smoke --smoke-frames=2100 --smoke-cards=all --smoke-level=6 2>&1 | tee "$LOG"
fail_on_script_errors "cards smoke"
for fx in ricochet burn slow blast crit execute medic; do
  grep "SMOKE_CARDFX" "$LOG" | grep -q "\"$fx\":[1-9]" || { echo "::error::the $fx card effect never fired"; exit 1; }
done
grep "SMOKE_CARDFX" "$LOG" | grep -q '"firestorm","shatter","wildfire","chain"' || { echo "::error::the combos did not all form"; exit 1; }
grep "SMOKE_CARDFX" "$LOG" | grep -q '"turrets":2' || { echo "::error::the sentry cards put no turrets on the curb"; exit 1; }
"$GODOT" --headless --path . --fixed-fps 60 ++ --smoke --smoke-frames=4200 --smoke-event=saw_storm --smoke-seed=3 --smoke-level=5 2>&1 | tee "$LOG"
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
