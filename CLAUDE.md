# Shooty McBridgeface: notes for whoever works on this next

- `scripts/core/` is pure logic with headless tests in `tests/`. Keep it that way.
- Any change to game mechanics (gates, panels, zombies, bosses, power-ups,
  perks, scoring, grades, coins, stars, modes, squads) updates the in-game
  HOW TO PLAY page in `scripts/core/help_text.gd` in the same commit, and
  `docs/DESIGN.md` if the design changed. The page is written for a
  teenager: short sections, plain words, numbers taken from the constants.
  `tests/test_run13.gd::test_help_text` fails if a mode, power-up or panel
  colour goes unmentioned; extend that test when you add one.
- Before a push to `main`: `scripts/ci/check.sh <godot>` and
  `scripts/ci/check_export.sh <godot>` from a fresh cache (`rm -rf .godot build`).
- Always push to `main`. Releases are built and tagged by CI from `VERSION`.
