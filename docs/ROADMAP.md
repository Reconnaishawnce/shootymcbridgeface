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

## Run 2: levels, bosses, feel (done)

- Levels of eight gates ending in a boss. Squad resets to one soldier at
  level start. Boss walks in, chews once it arrives, and has a swaying core
  that takes triple damage.
- Difficulty rebuilt around level and gate index; waves open gently on every
  level and ramp inside it. Boss health is seven seconds of a modelled squad.
- Juice: camera punch on gains, soldier spawn pop, cube bursts for kills,
  losses, gate steps and the boss, count bump, level banners, new-best flash.
- Sound: every effect synthesised in code at startup, no asset files. Sound
  toggle persisted.
- Pause button, auto-pause on losing focus or Android back, pause menu with
  resume, sound and quit.
- Smoke bot tracks the boss core and reports per-boss telemetry. Screenshot
  walkthrough covers boss, level clear, level two, paused.
- Deferred to run 3: endless mode as a selectable unlock (needs a mode
  picker on the title card).

## Run 3: perks and meta

- Mode picker on the title card: Levels (default) and Endless (unlocked by
  clearing level 3), the latter using the run 1 endless regulators.
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
