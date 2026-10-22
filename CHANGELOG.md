# Changelog

Versions are `MAJOR.MINOR.<CI run number>`. The first two parts come from
`VERSION`; the build number comes from GitHub Actions.

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
