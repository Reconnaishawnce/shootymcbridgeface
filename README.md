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

- The screen has two zones. **Low, near the squad: drag** left or right to
  steer, up and down to spread or tighten the formation, and **flick** hard
  sideways to dash (from level 2). **The road above: hold** a finger on it
  and every gun converges on that spot with a red laser. Lift to go back
  to spraying ahead. The button at the bottom right cycles tight, normal,
  wide and STRAIGHT (every round out of the middle, dead ahead, harder
  and through one more body: the drill for what is in front of you). On desktop: arrows or WASD, Q/E to dash, click and hold the
  road to focus, F to cycle, B to throw a bomb.
- **Sums.** Teal panels like **+3 x2** are worked out left to right, so
  they are not the same as **x2 +3**. A sum sits close in value to the
  plain gain beside it for the squad you have right now. Think, then
  steer. Two terms from level 2, three from level 5.
- **Lanes.** The road starts at two lanes and widens to five as you go,
  one panel per lane. More lanes means more to read: one of the extras is
  worth weighing and the rest are traps.
- **The convoy.** Big enough squads get offered olive panels: JEEP -20,
  TANK -60, HELICOPTER -120, MECH -250. Soldiers climb aboard and the
  vehicle rides with you from level to level with its own gun and health
  bar, earning ranks from its kills, until something heavy wrecks it.
- **Quests and the season.** Three quests a day, the same for everyone,
  pay points up a free thirty-tier season track with coins, stars and
  locker items. Nothing to buy.
- **Learn as you go.** The first time something new appears, the road
  pauses and one short card explains it. LEARN on the home screen
  replays every lesson in a run; LESSONS in SETTINGS turns them off.
- **How to play.** The HOW TO PLAY button on the title (and in pause)
  explains everything below in plain words, with the real numbers.
- **Records.** Lifetime stats and achievements that pay stars once each.
- **The road watches you.** Run bigger than a level expects and the
  zombies come thicker and bite harder, up to half again; run smaller
  and they ease off. A nudge, not a wall.
- **Modes.** MODE on the title cycles NORMAL, HARD (600 trophies) and
  NIGHTMARE (1500 trophies). Harder modes throw more at you and
  pay more score, coins and stars. Each keeps its own bests.
- **Grades.** Every level you clear gets a letter, S to D, for perfect
  gates, soldiers kept and boss speed. Better letters pay more.
- **Deals.** Amber panels in the extra lanes. A trade costs soldiers now
  for a power-up now; shoot it to make it cheaper. A bet doubles the
  squad if you clear the next wave without a bite, and halves it if not.
  A scout panel sends a few soldiers ahead and the next three gates show
  every panel, hidden ones included.
- **The horde.** From level 4 a wall of zombies creeps up behind you
  while the road is stopped for a boss. Kill the boss fast or it eats.
  Flankers also come over the curbs on wide roads.
- **Characters.** Settings has a CHARACTERS switch. On, the title gets a
  LOCKER: pick a hero (each has a face and a name), an outfit, a hat, a
  weapon skin and something for their back, and decide how the crew
  behind them dresses. Stars pay for them: one per boss, one per four
  perfect gates, one for finishing a few gates, one more for the daily.
  The hero leads the squad with a name tag, and always escapes.
- **Clingers.** From level 2, any walker or runner that reaches you
  clings to the squad's flank and keeps eating until you tap it (a touch
  on a clinger aims at it, wherever it is on the screen) or dash to shake
  a couple off. Up to six can cling at once. Brutes and tanks still take
  a slice and go.
- **Aim matters.** Unfocused fire sprays in a cone, so anything at range
  gets hit by luck. Held focus converges every round on the spot and hits
  harder.
- **Saws.** From level 2 a buzz saw rolls down the bridge now and then.
  Steer round it or dash through it; touching it takes a slice.
- **Bosses fight back.** Red rings on the road warn of lightning for one
  second, then it lands; move or dash out. Bosses call runners every few
  seconds. Below half health they enrage: more rings, faster strikes, the
  spitter fires volleys of three and the walker charges.
- The game teaches itself one line at a time. Level 1 is steer, pick and
  shake off clingers. Level 2 adds the dash and the spitter. Level 3 adds
  flashing panels (hit them during the flash for triple steps) and the
  tougher purple latchers. From level 4 gates are often red on both sides.
- Firepower stops growing past forty soldiers. Beyond that, soldiers are
  health: a big squad is something to protect, not a win button.
- Dashing through a bite, a spit or the boss's chew pays a DODGED bonus.
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
- **The fork**: once per level the road splits for two gates. Each side
  has a sign with skull marks for its wave and a number for roughly how
  many soldiers it takes; the heavier side pays better panels, sometimes
  a hidden one that may be a trap. A strip at the top previews both
  routes' numbers before you commit. Be on the side you want when the
  divider arrives; the lane narrows to that side until the routes merge.
- **Levels**: eight gates and a boss. Kill the boss before it reaches you;
  once it arrives it chews through the squad. Its glowing core sways side
  to side and takes triple damage, so track it. A quarter of your survivors
  march on into the next level; the rest of the squad is rebuilt from
  gates.
- **Perk gates**: the third and sixth gate of each level is a purple
  three-way gate. Each panel says what the perk does and how many you
  hold; steer through the one you want at full speed. Perks last the
  run, stack, show in a strip under your stats, and tell you when they
  work (thick skin says what it saved, the recruiter shows its soldier).
- **Combos**: kills within 1.4 s of each other chain. Every five kills in
  a chain raises the score multiplier, up to 4x. Clear a whole wave before
  any of it reaches you for a bonus. Shoot a gate panel up three steps
  and walk through it for a PERFECT.
- **Runners** are fast, thin and they find you. Walkers barely steer, so
  lining up the crowd is on you. When a bite leaves you with a handful,
  time slows for a beat.
- **Slow phone?** The game lowers its own graphics once if it cannot
  hold the frame rate, and says so; SETTINGS turns it back.
- **Bug reports**: SETTINGS has REPORT A BUG BY EMAIL. It opens your mail
  app with the diagnostics filled in (phone, GPU, app version, the last
  game events, stalls, how the previous session ended, engine errors)
  and copies the same text to the clipboard. SAFE GRAPHICS in the same
  card turns off glow, fog, shadows and anti-aliasing for phones that
  glitch.
- **Endless**: opens at 300 trophies. No bosses, no reset, gates
  forever, separate best score.
- **The trophy road**: every run adds trophies (10 per level, more for
  good grades, double on hard, triple on nightmare) and nothing takes
  them away. A milestone every 100 pays; the modes open at fixed points
  on the ROAD page.
- **Rally**: squad at zero? Once a run, five seconds to buy 8 soldiers
  back for a few stars. Not in the daily or weekly.
- **Weekly**: on the daily card. One road for everyone all week, on hard,
  no upgrades. Best of the week counts and pays two extra stars.
- **Daily**: the same gates for everyone on a given UTC day, no upgrades,
  rifles only. Your best of the day is kept for a week on the Daily card.
  Copy the one-line result to paste anywhere; the game-over card has a
  copy button too.
- **Bosses** cycle: the walker that chews you once it arrives, the
  spitter that holds back and lobs globs at where you are heading (a red
  ring marks where each lands: step out of it), and the storm that calls
  lightning in lines across the road with one gap to find.
- **Thieves** sprint away from you toward the next gate and knock its
  better panel down if they get there. **Tanks** are slow bullet sponges
  that shield the gate behind them.
- **Squads**: rifles (balanced), shotguns (three pellets, more damage),
  medics (less damage, a revived soldier every three seconds, brutes bite
  for less). The latter two are shop unlocks.
- **Coins and shop**: every kill pays a bounty by kind (walkers 1, brutes
  3, tanks 5...), bosses 25, gates 2; a counter shows it growing. GOLD
  supply panels sell soldiers or a power-up for bounty right at the
  gate; what you spend there you do not take home. The shop
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
