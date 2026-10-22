# Changelog

Versions are `MAJOR.MINOR.<CI run number>`. The first two parts come from
`VERSION`; the build number comes from GitHub Actions.

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
