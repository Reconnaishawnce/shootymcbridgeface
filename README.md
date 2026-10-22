# Shooty McBridgeface

An open-source Android "gate runner" shooter. Steer a squad down a road,
walk through one of two gates (`+3` or `x2`? `-5` or `x0.5`?), shoot the
numbers to grow them, and mow down the horde before it eats your soldiers.

No ads, no accounts, no servers, no timers. Just the actual game that the
mobile ads pretend to be.

Built with [Godot 4.4](https://godotengine.org) and GDScript. MIT licensed.

## Install on your phone with Obtainium

Every push to `main` builds a signed APK and publishes it as a GitHub
Release. [Obtainium](https://github.com/ImranR98/Obtainium) watches those
releases and updates the app in place.

1. Install Obtainium from F-Droid or its GitHub releases.
2. In Obtainium tap **Add App** and paste this repository URL:
   `https://github.com/Reconnaishawnce/shootymcbridgeface`
3. Leave the source as GitHub, tap **Add**, then **Install** on the latest
   release.

Each later push to `main` shows up in Obtainium as an update. Updates
install over the top of the old version because every build is signed with
the same key (see below).

## Play

- **Drag** left or right to steer the squad, **up and down** to spread or
  tighten the formation. Wide sweeps the lane and catches crowds; tight
  focuses fire on one gate panel or the boss core. The button at the
  bottom right cycles tight, normal and wide. On desktop: arrows or WASD,
  F to cycle, B to throw a bomb.
- **Power-ups** come from purple gate panels (soldiers now, or a tool for
  later) and from crates on the road. Named or a mystery `?`. Bomb: tap
  the button to lob it, clears the road ahead and hurts heavies and the
  boss, carry up to three. Slow-mo: the road crawls for six seconds.
  Shield: nothing bites for six seconds. Frenzy: double fire rate.
- A big gain makes the squad cheer with a ring and a chord. Past 25,
  75, 150 and 300 soldiers the squad raises flags and glows.
- A quiet procedural score sits under the run and builds from calm to
  tense to the boss. Music and sound toggle separately in the pause menu.
- **Tap** to retry after a wipe. The **II** button pauses; so does the
  Android back button or leaving the app.
- Blue panels help, red panels hurt, grey panels are hidden until you get
  close or put a bullet into them.
- Your squad fires straight ahead automatically. Bullets that hit a gate
  panel raise its number, so lining up under a `-4` and shooting it into a
  `+2` is a real play. Bullets spent on a panel do not reach the zombies
  behind it. That trade-off is the whole game.
- Brutes take a slice of your squad when they reach you, not a nibble.
- **Levels**: eight gates and a boss. Kill the boss before it reaches you;
  once it arrives it chews through the squad. Its glowing core sways side
  to side and takes triple damage, so track it. A quarter of your survivors
  march on into the next level; the rest of the squad is rebuilt from
  gates.
- **Perk gates**: the third and sixth gate of each level is a purple
  three-way gate. Steer through the perk you want at full speed. Perks
  last the run and stack: rapid fire, big bullets, piercing, gate
  whisperer, recruiter, thick skin, long sight, core sight, greed.
- **Combos**: kills within 1.4 s of each other chain. Every five kills in
  a chain raises the score multiplier, up to 4x. Clear a whole wave before
  any of it reaches you for a bonus. Shoot a gate panel up three steps
  and walk through it for a PERFECT.
- **Runners** are fast, thin and they find you. Walkers barely steer, so
  lining up the crowd is on you. When a bite leaves you with a handful,
  time slows for a beat.
- **Endless**: unlocked by clearing level 3. No bosses, no reset, gates
  forever, separate best score.
- **Daily**: the same gates for everyone on a given UTC day, no upgrades,
  rifles only. Your best of the day is kept for a week on the Daily card.
  Copy the one-line result to paste anywhere; the game-over card has a
  copy button too.
- **Bosses** alternate: odd levels get the walker that chews you once it
  arrives, even levels get the spitter that holds back and lobs globs at
  where you are heading. A red ring marks where each glob lands: step out
  of it.
- **Thieves** sprint away from you toward the next gate and knock its
  better panel down if they get there. **Tanks** are slow bullet sponges
  that shield the gate behind them.
- **Squads**: rifles (balanced), shotguns (three pellets, more damage),
  medics (less damage, a revived soldier every three seconds, brutes bite
  for less). The latter two are shop unlocks.
- **Coins and shop**: every run pays coins (kills, bosses, gates). The shop
  on the title screen sells nine permanent upgrades, including the shotgun
  and medic squads.
- Score is metres travelled plus ten per kill plus a bonus per level
  cleared. Best score, best level, endless best, coins and upgrades are
  saved locally.

## Develop

You need the Godot 4.4.1 editor or headless binary. Nothing else.

```sh
# Run the game on desktop (window is portrait, mouse emulates touch)
godot --path .

# Full local verification: import, unit tests, headless smoke-play
scripts/ci/check.sh /path/to/godot

# Just the unit tests
godot --headless --path . -s tests/run_tests.gd

# Simulate a longer run with the built-in auto-player (balance checks)
godot --headless --path . --fixed-fps 60 ++ --smoke --smoke-frames=3600
```

The whole scene is built in code (`scripts/game.gd`), so the project is
diff-friendly and does not depend on editor-saved scenes. Pure game logic
lives in `scripts/core/` and has no scene dependencies, which is what the
unit tests cover.

| Path | What |
|---|---|
| `scripts/core/` | Pure logic: gate arithmetic, difficulty curves, perks, upgrades, formation, save data |
| `scripts/` | Scene nodes: game controller, world, squad, gate, zombie, bullet, HUD |
| `tests/` | Headless unit tests and the runner |
| `scripts/ci/check.sh` | The exact verification CI runs |
| `docs/DESIGN.md` | Design pillars, mechanics, and the idea backlog |
| `docs/ROADMAP.md` | What each build run delivers |
| `.github/workflows/android.yml` | Build, test, export, release |

## Signing

The workflow signs releases with `android/dev.keystore`, which is committed
to this repository with a known password. That is deliberate: it lets
Obtainium update the app in place from day one with zero setup. The
trade-off is that anyone can sign an APK with the same key, so only ever
install builds from this repository's own Releases page.

To switch to a private key, add three repository secrets and the workflow
will use them instead:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 your.keystore` |
| `ANDROID_KEYSTORE_PASSWORD` | the keystore and key password |
| `ANDROID_KEY_ALIAS` | the key alias |

Changing the signing key means one manual uninstall and reinstall on each
phone, because Android will not update an app across different keys.

## License

MIT. See `LICENSE`.
