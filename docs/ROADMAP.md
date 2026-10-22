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

## Run 3: perks, meta, modes, characters (done)

- Title menu: Play, Endless (unlocked by clearing level 3), Shop, squad
  picker. Game-over card pays coins and has a Menu button.
- Perk picks after the third and sixth gate of each level: three cards
  from a pool of nine, seeded, stacking to a cap, run-long.
- Coins per run and a shop with eight permanent upgrades including the
  shotgun squad.
- Endless mode: no bosses, no reset, gates forever, separate best.
- Characters rebuilt from primitives: running soldiers with helmets,
  visors, packs and recoiling guns; hunched red-eyed zombies; plated
  brutes; a spiked, fisted boss with a ringed core. Detail falls off
  behind the front of the squad to keep draw calls down.
- Smoke bot takes perks and can run endless; screenshot walkthrough covers
  the shop and the perk cards.

## Run 4: daily, share, new enemies, second boss, medics (done)

- Daily seeded run: one seed per UTC day, no upgrades, rifles only, best
  of the day kept for a week, result line copies to the clipboard. Copy
  button on the game-over card for every mode.
- Thieves that sprint for the next gate and knock its value down; tanks
  that shield the gate behind them.
- Spitter boss on even levels: holds back, sways, lobs globs. Walker on
  odd levels.
- Medic squad: revives a soldier every three seconds, bites for less,
  does a little less damage.
- Balance: recruiter capped at two stacks; boss health grows 6% per perk;
  spitter carries 70% health; spit takes 8%.
- Deferred: branching lanes with a minimap. It needs split road geometry,
  a camera that follows the chosen side, and per-branch gate schedules,
  which is a run of its own. Android share sheet needs a plugin; the
  clipboard copy covers it for now.

## Run 5: branching lanes and polish

- Branching lanes: a fork gate splits the road for a stretch, each side
  with its own gates and waves, a minimap strip previewing both, merge at
  the end.
- Real models for soldiers and zombies if available, same classes.
- Play-as-the-horde mode prototype.
- Pass-and-play.
- Performance pass on low-end phones, battery check, 30 fps option.
- Phone feedback pass: steering sensitivity, perk balance, shop prices.

## Always

- Keep `scripts/core/` pure and tested.
- Any balance change is checked against the auto-player at 900, 3600 and
  7200 frames before it ships.
- Never commit a change that makes CI red on `main`.
