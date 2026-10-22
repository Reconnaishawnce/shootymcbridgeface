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

- **Drag** left or right to steer the squad. On desktop use arrow keys or A/D.
- **Tap** to start, and to retry after a wipe.
- Blue panels help, red panels hurt, grey panels are hidden until you get
  close or put a bullet into them.
- Your squad fires straight ahead automatically. Bullets that hit a gate
  panel raise its number, so lining up under a `-4` and shooting it into a
  `+2` is a real play. Bullets spent on a panel do not reach the zombies
  behind it. That trade-off is the whole game.
- Brutes take a slice of your squad when they reach you, not a nibble.
- Score is metres travelled plus ten per kill. Your best is saved locally.

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
| `scripts/core/` | Pure logic: gate arithmetic, difficulty curves, formation, save data |
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
