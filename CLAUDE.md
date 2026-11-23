# Shooty McBridgeface: notes for whoever works on this next

- `scripts/core/` is pure logic with headless tests in `tests/`. Keep it that way.
- Any change to game mechanics (gates, panels, zombies, bosses, power-ups,
  perks, scoring, grades, coins, stars, modes, squads) updates the in-game
  HOW TO PLAY page in `scripts/core/help_text.gd` in the same commit, and
  `docs/DESIGN.md` if the design changed. The page is written for a
  teenager: short sections, plain words, numbers taken from the constants.
  `tests/test_run13.gd::test_help_text` fails if a mode, power-up or panel
  colour goes unmentioned; extend that test when you add one.
- The game is kept small on purpose (DESIGN, "The ladder, and the rule of
  few words"). A new mechanic goes on the ladder in
  `scripts/core/progression.gd`: one level, one line for the coach
  (`LEVEL_HINTS`). If it cannot be taught in that line, it does not go in.
- The road is quiet by default. `hud.show_float` and `hud.show_banner`
  take a `Notices` rank and default to CHATTER, which is never shown.
  Lines are short and the tests count the words: eight on the road, six
  on a card or a pit tile, 110 in a HOW TO PLAY section.
- Phones freeze where the bot does not: keep `Diag.set_state` /
  `Diag.mark` breadcrumbs on new states and on long steps, and keep
  `Report` pure. `scripts/ci/soak.sh <godot>` before a release that
  touches the run loop.
- Before a push to `main`: `scripts/ci/check.sh <godot>` and
  `scripts/ci/check_export.sh <godot>` from a fresh cache (`rm -rf .godot build`).
- Always push to `main`. Releases are built and tagged by CI from `VERSION`.
