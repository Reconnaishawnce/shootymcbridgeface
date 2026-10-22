# Roadmap

Work happens in numbered runs. Each run ships a playable build to `main`,
passes the full verification, and leaves the game better than it found it.
A run's scope is fixed when it starts; new ideas go into the backlog in
`DESIGN.md`, not into the current run.

Definition of done for every run:

- `scripts/ci/check.sh` passes locally and in CI.
- The release APK builds, installs over the previous version, and the
  change is visible on a phone.
- `CHANGELOG.md` has an entry. `DESIGN.md` reflects any mechanic change.
- No known crash. No gameplay bug the auto-player can reproduce.

## Run 1: skeleton and pipeline (done)

- Godot 4.4 project, whole scene built in code, portrait, touch and
  keyboard input.
- Core loop: scrolling lane, gate pairs, shootable and hidden panels,
  zombie waves with brutes, squad formation, auto-fire, score, local best.
- Pure logic in `scripts/core/` with 20 unit tests, a headless auto-player
  smoke test, and a check script CI runs verbatim.
- GitHub Actions: test, export signed APK, publish a release for Obtainium.
- Launcher icon, README, design doc, this roadmap.

## Run 2: levels, bosses, feel

- Levels of about eight gates ending in a boss whose health sets the bar.
  Squad resets at level start. Endless mode becomes an unlock.
- Boss with a shootable weak point.
- Juice: hit flashes, gate-pass pulse, soldier spawn pop, death confetti,
  camera kick on brute bite, a tiny screen flash on a new best.
- Sound: generated or CC0 one-shots for fire, hit, gate, bite, wipe.
- Pause button and a settings toggle for sound.
- Re-tune difficulty against the auto-player with levels in place.

## Run 3: perks and meta

- Mid-run perk picks every three gates: three cards, pick one.
- Coins earned per run. Meta shop with about eight upgrades.
- Peak squad, best level and total kills on the title card.
- Unlock the first alternate squad type (shotgunners).

## Run 4: shareable and daily

- Daily seeded run with a shareable score code and a local leaderboard.
- Share sheet from the game-over card.
- Branching lanes with a minimap.
- Zombie types that interact with gates (thief, tank).

## Run 5: polish and the weird one

- Real models for soldiers and zombies if available, same classes.
- Play-as-the-horde mode prototype.
- Pass-and-play.
- Performance pass on low-end phones, battery check, 30 fps option.

## Always

- Keep `scripts/core/` pure and tested.
- Any balance change is checked against the auto-player at 900, 3600 and
  7200 frames before it ships.
- Never commit a change that makes CI red on `main`.
