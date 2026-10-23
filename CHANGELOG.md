# Changelog

Versions are `MAJOR.MINOR.<CI run number>`. The first two parts come from
`VERSION`; the build number comes from GitHub Actions.

## 0.10 (run 10)

Sums you have to work out, and a road that widens to five lanes.

- Teal sum panels from level 2: "+3 x2", "x2 +3", "÷2 -4". They apply
  left to right, so "+3 x2" and "x2 +3" are different gates. A sum is
  tuned to land within 40% of the plain gain it sits beside, for the
  squad you have at that moment, so the better panel takes a second of
  thought. Three-term sums from level 5. Shooting a sum steps its first
  plus term; thieves knock it down the same way.
- The road widens: two lanes on level 1, three from the middle of level 2,
  four from the middle of level 4, five from the middle of level 7. Curbs
  slide out, the lane lines redraw, the camera pulls back and a "3 LANES"
  banner lands. Every gate has one panel per lane, forks and perk gates
  share the wider road.
- Extra lanes read, they do not pay: one extra panel is a rival worth
  weighing, the rest are traps, tempting sums that lose, and the odd
  power-up. Waves spawn across a band that grows slower than the road.
- Sums give a big squad no doubling terms, the same brake plain
  multipliers already had.
- Auto-player takes `--smoke-seed=N` for balance runs across seeds.
- Balance, bot with no upgrades, four seeds: wiped on levels 5, 6, 5 and 7
  at 2.4 to 3.9 minutes. Endless: level 8 at three minutes.

## 0.9 (run 9)

Clingers, spray, and bosses that fight back.

- Any walker or runner that reaches the squad now clings to a flank with
  doubled health and eats a soldier every 0.7 s until you hold focus fire
  on it or dash to shake two off. Six can cling at once. From level 1.
- Unfocused fire sprays sideways; focus fire converges and hits 1.5x.
  Aiming is now the difference between hitting a brute at range and not.
- Bosses: lightning rings near the squad with a one-second warning, then
  a bolt that takes 15%. Runner adds every six seconds. Below half health
  bosses enrage: an extra ring, faster strikes, spitter volleys of three,
  the walker closes 60% faster.
- Hints rewritten for the new rules.
- Balance, bot with no upgrades: squad at the boss on levels 1 to 5 was
  93, 49, 63, 58, 51, and each boss now costs it 7 to 15 soldiers to
  lightning; died on level 5 after 2.8 minutes; best combo 83, 20
  perfect gates. Endless: level 8 at three minutes, peak 498.

## 0.8 (run 8)

Skill, pressure, and a run that teaches itself.

- Two touch zones. Low near the squad: drag to steer and spread, flick to
  dash. The road above: hold to focus fire, with a red laser, every gun
  converging on the spot.
- Dash from level 2: 2.2 m in 0.14 s, 0.4 s invulnerable, 1.1 s cooldown.
  Dashing through a bite, a spit or the boss's chew pays DODGED +40.
- Hot panels from level 3: panels flash white and hits during the flash
  count triple toward stepping the value.
- Latchers from level 3: sturdy purple zombies that grab the front rank
  and eat a soldier every 0.7 s until shot off.
- Firepower capped at forty soldiers' worth; a big squad is health.
- Level 1 has no hidden panels or dilemmas. Each level start shows one
  teaching line. Keyboard: Q/E dash, click-hold to focus.
- Balance, bot with no upgrades: squad at the boss on levels 1 to 4 was
  79, 122, 168, 28; died at the level 5 fork after 2.6 minutes with the
  firepower cap biting from level 3 on; best combo 61, 9 perfect gates.
  Endless: level 7 at three minutes, peak 705. Levels 1 to 3 are the
  confidence builders; 4 is where it bites.

## 0.7.1 (gray screen)

- Fixed the gray screen after the splash, for real this time. The quit
  path added in v0.6.9 called a bare `free()` on the game node, which the
  editor binary parses but the release export template does not, so on
  phones the game script failed to load and the main scene ran with no
  script. Reproduced here by exporting a Linux build with the same script
  export settings and smoke-playing it. The quit path now uses
  `queue_free()` and clears the material cache on the following frame.
- CI now exports a Linux build with the same compressed-binary-token
  script export as the APK and smoke-plays it, so a script that only
  breaks in exported builds fails the build instead of shipping.
- The music-thread change from 0.7 stays; it was a real startup cost, just
  not the cause.

## 0.7 (run 7)

The fork, and the startup fix.

- Fixed: 0.6 sat on a gray screen after the splash on the phone. The
  three music loops were synthesised in GDScript on the main thread before
  the first frame could render. Synthesis now runs on a worker thread, at
  a lower rate with precomputed one-shots, and the loops fade in when
  they are ready. Startup is as light as 0.5.
- The fork: at the fourth gate of every level the road splits into a RICH
  route and a SAFE route for two gates, with a divider, its own panels and
  crowd on each side, route names at the mouth, a preview strip at the
  top showing both routes' numbers and danger, and a merge. Rich may hide
  a panel, and a hidden rich panel may be a trap.
- Also fixed on the way: the last gate of a level used to arrive during
  the boss fight at crawl speed and slip into the next level; the boss
  now engages only once every gate is behind you. Every level's opener
  gate has a mild other side at every level, not just level 1. The
  whole formation stays on its side of a fork divider.
- Balance, bot with no upgrades: squad at the boss on levels 1 to 6 was
  74, 358, 60, 86, 56, 20 (the 358 is a rich route with multipliers
  paying off); died at the level 6 boss after 3.4 minutes; best combo
  77, 13 perfect gates. Endless: level 8 at three minutes, peak 304, 148
  alive.

## 0.6 (run 6)

The badass pass, from the second play session.

- Formation control: drag up and down to spread or tighten the squad, or
  tap the bottom-right button to cycle tight, normal, wide. Clamped to
  the lane. Wide catches crowds; tight focuses a panel or the boss core.
- Spitter boss actually hurts: it leads your movement, globs fly fast,
  a red ring marks the landing spot, and it fires faster below half
  health. Splash is wider.
- Power-ups: purple gate panels offer a named or mystery power-up against
  a visible gain; two crates per level sit on the road. Bomb (lob with
  the bottom-left button, carry three), slow-mo, shield, frenzy. Timers
  shown under the stats. Thieves turn a known gate power-up into a
  mystery.
- The army looks like an army: visible squad up to 60, flags and a
  ground glow at 25, 75, 150 and 300 soldiers in rising colours, and a
  rally on every real gain: ring, hop, chord, camera lean.
- Procedural music: calm, tense and boss layers synthesised at startup
  and crossfaded by state. Music toggle in the pause menu.
- Keyboard: W/S or up/down for spread, F to cycle, B for bomb.
- Balance, bot with no upgrades: squad at the boss on levels 1 to 6 was
  55, 37, 36, 133, 59, 4; the spitters on levels 2 and 4 now cost it 8
  and 35 soldiers; died at the level 6 boss after 3.7 minutes; best
  combo 72, 14 perfect gates, 30 waves cleared, every bomb thrown.
  Endless: level 7, peak 272, wiped at 2.6 minutes.

## 0.5 (run 5)

The fun pass, from the first real play session: too easy, flow broken by
the perk cards, nothing at stake.

- Perk cards are gone. The third and sixth gate of each level is now a
  purple three-way perk gate you steer through at full speed.
- Runner packs after every gate: fast, thin, homing. Waves are bigger
  with softer zombies; brutes from the third gate of level 1; walkers
  barely steer toward you. Road 20% faster. Every level opener is gentle.
- Kill combos: kills within 1.4 s chain; every five raise the score
  multiplier up to 4x, with a readout and a draining bar. Wave-clear
  bonus for killing a whole wave before it arrives. PERFECT bonus for
  walking through a panel you shot up three steps.
- Slow motion when a bite leaves you with four or fewer. Red edge pulse
  while you are down to a handful or far below your level peak. Every
  bite shows its cost.
- Gates: hidden panels and dilemmas from level 1, subtractions to -4 on
  level 1, multipliers slightly more common, gate farming 40% faster.
- Boss model lowered to 70 + 15 per level to match the smaller squads
  that harder waves leave you with. A quarter of the survivors carry over
  into the next level instead of a hard reset to one.
- Balance, bot with no upgrades: squad at the boss on levels 1 to 6 was
  69, 100, 57, 242, 25, 29; died at the level 6 boss after four minutes;
  best combo 80, 23 perfect gates, 32 waves cleared. Endless: level 8 at
  three minutes, peak 590, combo 126. The earlier cut of this run killed
  the bot at level 2 and then level 3, which is how the runner timing bug
  and the survivor carry-over came about.

## 0.4 (run 4)

Daily run, copy-to-share, thieves and tanks, the spitter boss, medics.

- Daily: same seed for everyone per UTC day, no upgrades, rifles only.
  Daily card with the last seven days; best of the day counts. Copy
  result button on the daily card and on every game-over card.
- Thieves sprint away toward the next gate and knock its better panel
  down on arrival. Tanks are wide, slow bullet sponges with a scrap shield.
- Even-level boss is now the spitter: holds 24 m back, sways, lobs globs
  that land where you were. Odd levels keep the walker.
- Medic squad unlock in the shop: a revived soldier every three seconds,
  25% less from brutes and tanks, 0.85x damage, white vest with a cross.
  Squad button cycles through unlocked squads.
- Balance: recruiter capped at two stacks; boss health grows 6% per perk
  taken; spitter carries 70% health; spit takes 8% of the squad.
- Balance, bot with no upgrades, first perk offered: squad at the boss on
  levels 1 to 8 was 100, 118, 53, 42, 143, 134, 62, 63; boss fights ran
  9 to 27 s with the spitters the long ones; reached level 9 at six
  minutes with 17 soldiers. Endless: level 7 at three minutes, peak about
  350, 89 left. Daily (seeded): level 3 at 90 s.

## 0.3 (run 3)

Perks, coins and shop, endless mode, shotguns, and real characters.

- Title menu with Play, Endless (unlocks after clearing level 3), Shop and
  a squad picker. Game-over card shows coins earned and has a Menu button.
- Perk cards after the third and sixth gate of every level: nine perks,
  three offered, stacking to a cap, run-long. Keys 1 to 3 on desktop.
- Coins paid per run; shop with eight permanent upgrades: recruits,
  firepower, gate bonus, armor, boss slayer, coin magnet, scout, shotgun
  squad. Shotguns fire three pellets in a fan.
- Endless mode: no bosses, no squad reset, separate best score.
- Soldiers, zombies, brutes and the boss rebuilt as proper figures with
  legs, arms, helmets, visors, packs, red eyes, plates, spikes, fists and
  a ringed core. Guns recoil, legs run, zombies shamble.
- Save file now holds coins, upgrades, squad type and the endless best.
- Smoke bot takes perks and can run endless; screenshots cover the shop
  and perk cards.
- Balance, bot with no upgrades, taking the first perk offered: squad at
  the boss on levels 1 to 9 was 100, 215, 84, 334, 424, 98, 64, 55, 41;
  reached level 9 at six minutes with 18 soldiers left. Perks make the bot
  far stronger than in 0.2, so bosses on levels 4 and 5 fall fast and the
  wall is the level 6+ waves. Endless: level 7 at three minutes, peak
  squad about 650, still alive. Perk and shop balance is a run 4 item.

## 0.2 (run 2)

Levels, bosses, feel, and sound.

- Runs are now levels: eight gates, a wave after each, then a boss. The
  squad restarts at one soldier every level.
- Boss walks in during a slowed-down arena phase, chews the squad once it
  arrives, and has a swaying core that takes triple damage. Boss health bar
  in the HUD.
- Difficulty rebuilt around level and gate index. Level bonuses added to the
  score. Best level saved and shown on the title card.
- Juice: camera punch, soldier spawn pop, cube bursts for kills, losses,
  gate steps and the boss, count bump, level banners, new-best flash.
- Sound effects synthesised at startup; sound toggle in the pause menu.
- Pause button, auto-pause when the app loses focus or Android back is
  pressed, pause menu with resume, sound and quit.
- Smoke bot plays bosses and reports telemetry per boss; screenshot mode
  covers the boss, level clear, level two and the pause menu.

## 0.1 (run 1)

First playable build.

- Scrolling lane, gate pairs with additive and multiplicative panels.
- Shootable panels: bullet damage climbs the value, multipliers cost more.
- Hidden panels revealed by proximity or a hit.
- Zombie waves placed just ahead of each gate; brutes that scale with the
  squad and take a slice of it.
- Squad formation, auto-fire with a capped tracer rate, drag steering.
- Title, running and game-over screens, floating gate results, local best.
- Difficulty tiers by distance; multipliers fade for big squads; halving
  gates appear later so endless runs plateau.
- Headless unit tests, auto-player smoke test, CI that builds and signs an
  APK and publishes a GitHub Release for Obtainium.
