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

## Run 5: make it fun (done)

Driven by the first real play session of 0.3: too easy, not fun, and the
perk cards broke the flow enough to make the player want to quit.

- Perk cards replaced by perk gates: three panels across the road, steer
  through the one you want. No stop, ever.
- Threat from the first ten seconds: runner packs after every gate, bigger
  waves of softer zombies, brutes from the third gate of level 1, walkers
  that barely home so lining up is a skill, faster road.
- Dopamine: kill combos with a multiplier and a draining bar, wave-clear
  bonuses, PERFECT gates, slow-motion near misses, red danger pulse, a
  float for every bite.
- Gates meaner earlier: hidden panels and dilemmas from level 1, bigger
  subtractions, a few more multipliers. Gate farming 40% faster.
- Every level's opener wave is gentle, so a reset squad gets a foothold.

## Run 6: badass pass (done)

From the second play session: no control over the squad's shape, the
spitter was harmless, big squads looked the same as small ones, no
collectables, growth felt flat, no music.

- Formation control: drag up and down or tap the button; tight to wide.
- Spitter rebuilt: leads the squad, fast globs, a red landing ring to
  dodge, faster once hurt.
- Power-ups: purple gate panels (named or mystery) and road crates. Bomb,
  slow-mo, shield, frenzy. Bomb button with a count.
- Army visuals: flags and a ground glow at 25, 75, 150, 300; visible
  squad up to 60; rally ring, hop and chord on every real gain.
- Procedural music in three layers that crossfade with the state.
- Music toggle, formation and bomb buttons, power-up timers in the HUD.

## Run 7: the fork, and the gray screen (done)

- Branching lanes: once per level the road forks into RICH and SAFE
  routes for two gates, each with its own panels and crowd, a divider,
  a preview strip at the top, and a merge.
- Startup fix: 0.6 showed a gray screen on the phone after the splash
  because the three music loops were synthesised on the main thread before
  the first frame. Synthesis now runs on a worker thread and costs a
  third as much; the loops fade in when ready.

## Run 8: skill, pressure, and a run that teaches itself (done)

From the third play session: too easy, nothing to get good at.

- Focus fire: hold the road, every gun converges there, red laser.
- Dash: flick in the steer zone, short invulnerability, DODGED bonus.
- Hot panels: flashing panels count triple during the flash.
- Latchers: zombies that grab the front rank and eat until shot off.
- Firepower capped at forty soldiers; the count is health past that.
- Progressive unlocks with one-line hints: level 1 is plain, dash at 2,
  hot panels and latchers at 3, both-red gates at 4.

## Run 9: clingers, spray, bosses that fight back (done)

From the fourth play session: zombies did not stick, aiming had no point,
bosses were too easy.

- Clinging from level 1 for every walker and runner that reaches you;
  focus fire or dash is the only answer.
- Unfocused fire sprays; focus converges and hits harder.
- Boss lightning with warning rings, runner adds, enrage below half,
  spitter volleys, walker charge.

## Run 10: sums and lanes (done)

- Teal sum panels, applied left to right, tuned to sit close to the plain
  gain beside them. Two terms from level 2, three from level 5.
- The road widens from two lanes to five across the levels, with the
  curbs, lane lines and camera animating out. One panel per lane; forks
  and perk gates share the width.
- Extra lanes add reading, not free soldiers: one rival, the rest traps.

## Run 10.1: characters, pass 1 (done)

- Clingers can be tapped wherever they ride, and start with the dash.
- Settings with a CHARACTERS switch; the LOCKER with heroes, outfits,
  hats, weapon skins and backs paid in stars. The hero leads with a name
  tag and always escapes.
- Soldier model rebuilt with faces, hair, boots and dress-up slots.

## Run 10.2: characters, pass 2

- The hero cheers on level clear and idles on the title.
- Crew skins (match, rainbow, shadow) and a few more hats and backs.
- "You can afford something" nudge after a run; a star for the daily.
- Share text and the wipe screen lean on the hero.

## Run 11: difficulty modifiers and grades

- Hard and Nightmare modifiers with score and coin multipliers.
- Level grades (S to D) on the clear banner.
- Trade gates, bet gates, scout sacrifice.
- Flankers over the curbs; the horde behind you.
- Fifth phone feedback pass.

## Always

- Keep `scripts/core/` pure and tested.
- Any balance change is checked against the auto-player at 900, 3600 and
  7200 frames before it ships.
- Never commit a change that makes CI red on `main`.
- The editor binary is not the game. Every push is smoke-played as an
  exported build too (`scripts/ci/check_export.sh`).
