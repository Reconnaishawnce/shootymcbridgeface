# Design

## What this is

The gate-runner minigame from the mobile ads, built honestly. One lane, a
squad that grows and shrinks through arithmetic gates, a horde coming the
other way, and your aim as a resource you have to spend wisely.

## Pillars

1. **Every gate is a decision, not a sum.** If the right answer is always
   obvious, the game is a treadmill. Hidden values, shootable values,
   dilemmas where both sides hurt, and multipliers that only pay off at the
   right squad size all exist to make the player think for half a second.
2. **Aim is a resource.** Bullets that hit a panel grow it and are gone.
   Bullets that pass a gate kill zombies. You cannot do both at once, so
   every approach is a choice between growing now and surviving next.
3. **Readable at a glance.** Blue helps, red hurts, grey is unknown. Big
   numbers. The squad count is the biggest thing on screen. No clutter.
4. **Honest.** No ads, no energy, no gacha, no servers. Progress is local.
   Scores are shareable as text.
5. **Runs are short and replayable.** Sixty to ninety seconds for a good
   run. Death is fast, retry is one tap.

## Core loop (as of run 2)

- A run is a sequence of levels. A level is eight gates, a zombie wave
  after each, then a boss. The squad resets to one soldier at the start of
  every level, so growth is bounded per level and the boss is the bar.
- The world scrolls toward the squad at 9.5 to 14 m/s during gates and
  slows to 2.5 m/s for the boss. The squad stays at the origin and steers across
  a six-metre lane.
- A gate every 32 m. Each gate has one panel per lane: two lanes on
  level 1, three from the middle of level 2, four from the middle of
  level 4, five from the middle of level 7 (`Progression.lanes_for`). The
  squad's x position at the moment the gate reaches it picks the panel.
  From level 2 some panels are teal sums ("+3 x2") applied left to right;
  a sum next to a plain gain is tuned to land within 40% of it for the
  squad you have, so you have to work it out. Three-term sums from level
  5. Extra lanes hold one rival worth weighing and otherwise traps,
  losing sums and the odd power-up. The first gate of every
  level is a visible additive gain, a foothold for the fresh squad.
- Panels are additive (`+n`, `-n`) or multiplicative (`x2`, `x3`, `x0.5`).
  Additive values climb by one per step of bullet damage; multipliers climb
  by 0.5 per step and cost three times as much. A step costs the larger of
  a level floor and 70% of the squad's damage per second, so farming a gate
  yields about 1.4 steps per second of committed fire at any squad size.
- A zombie wave sits 26 m after each gate, 6 m before the next one. Waves
  are shielded by the gate in front of them until it passes, then exposed
  for about three seconds. Waves ramp mainly with the gate index inside the
  level, and only modestly with the level, because the squad restarts.
- Normal zombies have small health and eat one soldier. Brutes have health
  that scales with the squad (about a second of its full fire) and eat 8%
  of the squad with a floor of three.
- The boss appears 40 m after the last gate, engages at 30 m, walks in at
  2.2 m/s and then chews 12% of the squad every 0.45 s. Its core sways
  across 2.2 m and takes triple damage. Boss health is seven seconds of
  fire from a modelled squad of 100 + 20 per level.
- Clearing a level pays `150 x level + 5 x soldiers left`, and a quarter
  of the survivors carry over to the next level (never below the shop's
  starting squad). The run ends when the count hits zero.
- The third and sixth gate of a level is a perk gate: three purple panels
  across the lane, one perk each, drawn from a pool of nine and seeded by
  the run. You steer through the one you want at full speed. Nothing
  stops; the choice is a steering decision like any other gate. Perks
  stack to a cap and last the run. Rapid fire and big bullets change the
  guns; piercing lets a bullet survive a kill; gate whisperer cuts step
  cost; recruiter adds a soldier at every gate; thick skin, long sight,
  core sight and greed do what they say. Bullets pass through perk gates.
- The run teaches itself. Level 1 has no hidden panels, no dilemmas and
  no latchers: steer, pick, shoot. Each level after adds one tool or one
  threat with a one-line hint: dash (2), hot panels and latchers (3),
  both-red gates (4). Hard, but never two new things at once.
- Focus fire. Holding a finger on the road makes every bullet converge on
  that point, drawn as a red laser. It is how you kill a brute before it
  arrives, shoot a latcher off your own front rank, farm one panel while
  the squad is wide, or hold the boss core. The cost is the rest of the
  lane going unwatched.
- Dash. A hard sideways flick in the steer zone moves the squad 2.2 m in
  0.14 s with 0.4 s of invulnerability and a 1.1 s cooldown. A bite, a
  landing spit or a boss chew during those frames is a DODGED bonus. It
  turns the spitter's landing ring and the runner packs into timing.
- Hot panels. From level 3 every panel flashes white for 0.45 s of every
  2.2 s, each side out of phase. Hits during the flash count triple
  toward stepping the value. Rhythm, not just position.
- Clingers. From level 1, any walker or runner that reaches the squad
  clings to a flank slot (alternating sides, a little further back each)
  with doubled health and eats a soldier every 0.7 s until it is dealt
  with. Bullets cannot reach the squad's own flank, so there are exactly
  two answers: hold focus fire within 1.4 m of it, which pours 70% of
  squad DPS into it, or dash, which throws the first two off. Six can
  cling at once; the rest bite once and are spent. Purple latchers from
  level 3 are the same thing with more health, arriving on purpose.
- Spray. Unfocused rounds drift sideways by up to 1.6 m/s, so a target
  twenty metres out is hit by luck; focused rounds converge and deal 1.5x.
  That is the point of aiming.
- Bosses attack. Lightning: every 3.2 s (2 s enraged) the boss drops one
  to three red rings near the squad, biased to where it is heading; a
  second later a bolt lands and anyone inside loses 15% (floor three).
  Move or dash out; a dash through one is a DODGED. Adds: runners every
  6 s. Enrage below half health: an extra ring per volley, the spitter
  fires volleys of three across 3.2 m, the walker closes 60% faster.
- Firepower caps at forty soldiers' worth. Past that, more soldiers are
  more to lose, so waves and bosses stay dangerous to a big squad and the
  count reads as health.
- Formation is a control, not a fact. Drag up or down (or a button) to
  stretch the blob from tight (0.45x) to wide (1.8x, clamped so it fits
  the lane). Wide covers the lane so bullets catch runners from both
  sides and the squad's reach catches more bites; tight concentrates
  fire on one panel or the boss core and lets zombies slip past. The
  decision changes with every gate and wave.
- Power-ups. A gate can offer a named or mystery power-up against a
  visible gain (18% of gates after the opener; thieves turn a known one
  into a mystery). Two crates per level sit in the gap after random gates.
  Bomb (carry three): arcs 13 m ahead, kills everything within 5 m, deals
  three seconds of squad fire to brutes and tanks and more to the boss.
  Slow-mo: the road and everything on it runs at 45% for six seconds while
  your guns do not. Shield: six seconds where bites and spit bounce.
  Frenzy: double fire rate for six seconds. Timers stack from the end.
- The army looks like one. Every three-plus soldier gain cheers: a ring
  expands under the squad, the soldiers hop, a chord plays, the camera
  leans. At 25, 75, 150 and 300 the squad raises one, three, five flags
  in blue, gold, red, purple and a ground glow of the same colour.
- Music. Three synthesised loops in the same key (calm 100 BPM, tense
  118, boss 140) play at once and crossfade by state: calm for the early
  road, tense from level 3 or whenever the squad is in danger, boss for
  the boss. Nothing is loaded from disk.
- The spitter aims at where the squad will be, with a red ring marking
  the landing spot. Globs fly at 16 m/s, splash the squad's reach plus a
  metre, and come every 2.2 s, or every 1.3 s once the boss is below
  half health.
- The fork. At the fourth gate of every level the road splits for two
  gates with a divider down the middle. One route is RICH: two panels
  drawn from +6..+10 (+2 per level), x2 or x3, with a 30% chance one is
  hidden and half of those hidden panels a trap of -3..-6; the wave inside
  the fork is 1.6x with an extra brute or two. The other is SAFE: two
  visible +2..+4 panels and a 0.6x wave. Which side is which is random. A
  strip at the top shows both routes' panels and a danger rating from the
  moment the fork spawns, so the choice is planned, not guessed. The
  squad commits by being on a side when the divider arrives and is held
  to that half of the road until the merge 16 m after the second route
  gate. Bullets from either side can still shoot up either route's panel.
- Dopamine on a timer. Kills within 1.4 s chain into a combo; every five
  raises a score multiplier up to 4x, with a readout and a draining bar.
  A wave fully killed before any of it reaches you pays a wave-clear
  bonus. A panel shot up three or more steps and then walked through is
  a PERFECT. A bite that leaves you with four or fewer soldiers plays in
  slow motion for 0.6 s, and the screen edges pulse red while you are
  down to a handful.
- Threat from the start. Every gate is followed by a pack of runners
  (fast, thin, homing) 11 m later and a wave 26 m later. Waves are many
  bodies with little health, so mowing them is the fun; brutes appear
  from the third gate of level 1. Walkers barely steer toward you, so
  lining up the crowd is the player's job. Every level's opener wave is
  gentler because the squad has just reset.
- Every run pays coins: a quarter per kill, 25 per boss, 2 per gate,
  times the greed perk and the coin magnet upgrade. The shop sells eight
  permanent upgrades at a cost that grows 1.7x per level: recruits
  (start squad), firepower, gate bonus, armor, boss slayer, coin magnet,
  scout, and the shotgun squad.
- Shotguns fire three pellets in a fan per shot for 1.35x total damage.
  Better against crowds, same against gates.
- Bosses alternate by level. Odd: the walker, which closes in and chews
  12% of the squad every 0.45 s once it arrives. Even: the spitter, which
  holds 24 m out, sways its whole body across 3.6 m, carries 70% of the
  walker's health, and lobs a glob every 3 s at where the squad was when
  it fired; a landed glob takes 8%. Boss health also grows 6% per perk
  taken, so stacked runs still have to earn their boss kills.
- Thieves (from level 2, odd gates) spawn on the squad's side of the next
  gate and sprint toward it at 14 m/s; if one arrives it takes 2 off the
  better additive panel or a half step off a multiplier. A target that
  runs away is a different shot from a target that walks at you.
- Tanks (from level 3, every third gate) are slow, 2.5 m wide, carry six
  seconds of squad fire plus a squad-scaled soak, and eat 15% if they
  arrive. They stand between you and the gate: go round, or spend the
  bullets.
- Squads: rifles; shotguns fire three pellets in a fan for 1.35x total
  damage; medics do 0.85x damage, revive one soldier every three seconds
  and take 25% less from brutes and tanks.
- The daily uses one seed per UTC day, a blank upgrade set and rifles.
  Results for the last seven days are kept locally; the best of the day
  is the one that counts. The result line copies to the clipboard.
- Endless mode (300 trophies on the road) has no bosses and no reset.
  Levels tick every eight gates for difficulty and the HUD; the run 1
  regulators (multipliers vanish past 150 soldiers, halving gates, brute
  health scaling) keep it from exploding.

## Modes, grades and deals

`Modifiers` scales the threat (waves, health, boss, bites, an extra
strike) and the pay (score, coins, stars). The threat ramps in over the
first three levels (`Modifiers.ramp`) so a one-soldier opener on
nightmare is survivable. Hard opens at 600 trophies, nightmare at 1500
(older saves keep anything the old level rules had already opened); each
mode keeps its own bests under suffixed save keys. The daily is always
normal.

`Grades` turns a cleared level into a letter: 35% perfect gates, 40% of
the level's peak squad kept, 25% boss speed (six seconds is full marks,
twenty is none). S pays 600 points, down to nothing for a D.

Deals are amber panels in the extra lanes, at most one per gate and only
on four lanes or more. A trade is a cost now for a power-up now; the bot
weighs it by the cost alone. A bet changes nothing at the gate and is
resolved by the wave that follows: cleared with no bite doubles the
squad, a bite or a leak halves it.

A scout panel costs a few soldiers and reveals the next three gates
(those already on the road and those still to spawn) as soon as they
exist. It appears from level 2, when hidden panels start, on three lanes
or more, and like the other deals it gets cheaper when shot.

The weekly is the daily's bigger sibling: one seed per UTC week, played
on hard with no upgrades and rifles, its own results and share line, two
extra stars for a scoring run.

Flankers are runners spawned just outside the curbs beside the squad as a
gate passes, from level 4 on four-lane roads. The horde is a wall behind
the squad that creeps up while the road is stopped for a boss (0.65 m/s,
faster on hard and nightmare), eats 5% of the squad every 0.6 s once it
arrives, and falls back when the boss dies. It is the boss clock.

## The rubber band

`Difficulty.rubber_band(count, level, vehicles)` reads the squad (plus
twenty per vehicle) against `BAND_NEUTRAL` times the level's expected
squad and returns -0.2 to +0.5. `World._spec` scales wave count and
health by `band_wave`, `World._bite` scales heavy bites by `band_bite`
(0.6 of the wave effect) and boss health takes `band_boss` (half). It is
a nudge that keeps a strong run busy and gives a weak one slack; the
modifiers multiply on top. Compounding is capped at its sources:
`bet_win` adds at most `BET_WIN_CAP`, and a fork for a squad past
`BIG_SQUAD` swaps multipliers for flat gains of at most
`BIG_FORK_ADD_CAP`.

## Quests and the season

`Quests.for_day` draws three templates and targets from the day number,
so every player has the same three; `Quests.advance` folds a run's
numbers in (sums, or best-of for combo and level) and reports what was
completed; completed quests pay points once. `Season.advance` turns
points into tiers (100 each, 30 tiers over a 30-day season) and returns
the rewards newly reached: coins, stars every third tier, a locker item
every fifth from a pool that rotates with the season number. The game
applies rewards at the end of a run and shows them on the wipe screen.

## The trophy road and the rally

`Road` is pure and small. `trophies_for_run` pays 10 per level reached
plus a grade bonus per cleared level (S 15, A 10, B 5, C 2), times the
mode (hard 2, nightmare 3); endless pays half the level rate and no
grades. Trophies only go up. `Road.advance` walks the milestones crossed
(every 100) and returns their rewards: a fixed unlock at 300 / 600 /
900 / 1500 (endless, hard, weekly, nightmare), otherwise a locker item
from a pool, stars, or coins in a repeating pattern, with a checkpoint
every 500. `Game._feature_open` asks the road first and the old level
rule second, so an existing save loses nothing. The title shows the
count and the next milestone, the wipe screen the run's trophies and any
milestones crossed, and `Hud.show_road` lists what opens where and the
next dozen milestones.

`Revive` is the paid comeback: when the squad hits zero and second wind
has fired or was never bought, the tree pauses and a five-second card
offers `SOLDIERS` back for `price(uses_today)` stars (3, 5, 8 within a
UTC day, saved as {day, count}). Once a run, never for the bot, never in
the daily or weekly. Accepting mirrors second wind: soldiers, a shield,
`World.shake_off`. Declining, or the timer, ends the run.

## Diagnostics and bug reports

Phones fail in ways the headless bot never sees, so the game carries
its own black box. `Diag` (an autoload) keeps a ring of the last 200
events (`Report.line`), detects frames longer than half a second on the
wall clock and records them with the state and breadcrumb they happened
in, and writes a heartbeat file every three seconds and on every state
change or breadcrumb. The heartbeat carries `clean`: true once the app
is backgrounded or closing, false while it is in the foreground, so a
process that vanishes with `clean == false` was a crash or an ANR, not
the system reclaiming memory. On the next launch the previous heartbeat
becomes the "previous session" part of the report and, if it was a bad
exit, the title's next-thing line points at the report button.

`Report` is pure and tested: the report text (device, app, previous
session, stalls, engine error lines from the previous and current
`user://logs/godot.log`, a save summary, the event log) and the
`mailto:` link, cut from the front so the newest events survive a mail
app's body limit. `Diag.send` copies the text to the clipboard first,
so nothing is lost. File logging is on for every platform in
`project.godot` so release builds keep script errors.

Breadcrumbs mark the results path (`end_run:records`, `road`, `stats`,
`card`, `shown`) and the time `end_run` took is logged, because the
results screen is where phones have frozen. Two guards sit there too:
`Engine.time_scale` is forced to 1 in every state but RUNNING (slow
motion from the last bite or a hit-stop can otherwise outlive the run
and make every menu crawl), and the retry lockout runs on
`Time.get_ticks_msec`, not on scaled delta.

SAFE GRAPHICS turns off glow, fog, colour adjustment, shadows, MSAA and
the vignette (`Game._apply_graphics`), for drivers that glitch on the
extras; the report says whether it is on.

Startup on phones: `Game._warm_up` draws one of everything (every
zombie, boss and vehicle kind, soldiers, gates and panels, projectiles,
particles) plus every HUD text size (`Hud.warm_fonts`) under a loading
screen for a few frames, so shader and glyph compilation happens once
at boot instead of on the first boss. `Perf` is the frame-rate
watchdog: under 22 fps over five seconds turns SAFE GRAPHICS on once
per install and tells the player. A bad exit opens a one-tap crash
card on the next launch (`Hud.show_crash_card`).

QA: `--smoke-wipe-at=N` takes the bot's whole squad at frame N so the
results screen is reached whatever the balance; `--smoke-retry` makes the bot sit on the results for ninety frames,
assert the clock is back to normal, and play again; `check.sh` runs it
on a nightmare seed. `seed(run_seed)` in smoke mode makes a seed
replay. `scripts/ci/soak.sh` plays every mode and modifier across seeds
and fails on any script error.

## One look, one next thing

`Hud.make_theme` is the whole UI kit: one button style (dark glass,
rounded, accent when pressed), one panel style behind every card, one
scrollbar. `Hud.Icon` draws the coin and the star so no font glyph is
relied on. `Goals.next` is the single line on the title and the wipe
screen that says what to do next, in a fixed priority order (play, the
trophies that open endless or hard, an affordable upgrade, form a jeep,
try hard, a near milestone, open quests, the daily, save up, beat your
best), and `Goals.title_buttons` decides which
buttons a player has earned, so the first screen is PLAY and little
else. `Game._hitstop` freezes a frame on a boss kill and a vehicle
forming; the auto-player skips it.

## The convoy

`Convoy.SPECS` holds the vehicles: cost in soldiers, health, damage per
second, fire rate, the per-kind trick (pierce for the jeep, splash for
the tank), how many you may own and from which level. `Convoy.offer`
names the biggest affordable one for a squad of a given size and owned
set; `Difficulty.make_gate` swaps it for the gate's worst panel just over
half the time, never on the opener. Forming is a gate choice, so it is a
bet: fewer bodies now, a gun that stays.

`Vehicle` nodes ride in the squad's layout (tank ahead up the middle,
jeeps on the flanks), fire through the same world hit-test as soldiers
(jeep bullets, `Shell` bursts resolved by `World.explode_at`), and take
damage from the heavy hits (`Difficulty.VEHICLE_HIT_*`). They survive
`Squad.redeploy` (a new level) and die with `Squad.reset` (a new run).
A jeep's 50 DPS equals twenty capped soldiers, so the trade is even on
fire and ahead on accuracy, persistence and the level bonus. The road
answers: `World._spec` sizes waves as if each vehicle were
`CONVOY_SOLDIER_EQUIV` soldiers, and boss health grows by
`CONVOY_BOSS_HP_PER_VEHICLE` per vehicle.

The helicopter flies (`Convoy.flies`): ground hits skip it, lightning
does not. It aims itself at `World.pest_target` (thieves, then runners
and latchers) and pours `cling_dps` into the first clinger through
`World.heli_hit_latched`. The mech's laser is a stream of long red
bullets with pierce 3. Bullets and shells carry a `source`, and every
kill they make calls `Vehicle.note_kill`; `Convoy.rank_for` turns kills
into ranks (`RANK_KILLS`), each adding `RANK_DPS` and `RANK_HP` and a
full heal. Perks flagged `vehicle` are only offered when the squad owns
one.

## Honest road: the fork, formation width, the shop

The fork carries no words. `Difficulty.make_fork` builds two routes with
different threat levels (1 to 4); threat sets the wave multiplier
(`FORK_THREAT_WAVE`), the extra brutes and the quality of the panels.
`route_needs` turns the route's wave into a soldier count (total wave
health over four seconds of squad fire), shown on the sign and in the
HUD box, so the choice is a read. From level 3 a quarter of forks have
no gentle side.

Formation width is a real lever: `Squad.spray_mult` runs from 0.45
(tight) to 1.8 (wide) on the bullet spray, and the squad's reach, which
decides lightning, spit and horde hits and whether it fits a storm gap,
already follows the width. Tight focuses, wide covers.

The shop is priced so the first upgrade is about one good run and
maxing everything is about forty. Effects are big enough to notice
(`Meta.effect_text` shows now and next). Armor applies to every heavy
bite through `World._bite`. Second wind is one comeback per run.

## Fire modes and the bounty

Two plans, both real. `Squad.straight` is the fourth formation state:
every round spawns at the formation's centre x and flies with no spray,
`Bounty.STRAIGHT_DAMAGE_MULT` harder and with `STRAIGHT_PIERCE` extra
hits (`Squad._spawn_bullet`), the formation held tight. It drills a
brute, a tank, a boss core or a panel and leaves the flanks open; a
drag on the width ends it (`adjust_spread`), the button cycles into
and out of it. WIDE is the other plan: a fan that mows a crowd.

`Bounty.for_kind` pays coins per kill by kind (walkers and runners 1,
thieves and latchers 2, brutes 3, tanks 5); `Bounty.coins_for_run`
adds bosses and gates. `Game.bounty` grows on every kill and the HUD
counter under the level bumps with it (`Hud.set_bounty`); the run's
coins are the bounty times the greed, magnet and mode multipliers. The
old quarter-coin-per-kill is gone: a run pays about three times the
coins, and `Meta.CATALOG` prices are two and a half times higher, so an
upgrade still costs about one good run. The bot drills when a heavy or
the boss core is lined up and sprays otherwise, so both paths run in CI.

## Dodging, saws and going over the side

The complaint was fair: a glob or a bolt "dodged" still hit, because the
hit test used the whole formation's reach plus a metre. Now a glob hits
within `reach * 0.7 + Spit.SPLASH` of its landing spot and a bolt within
`reach * 0.8 + STRIKE_RADIUS * 0.4`, so the ring on the road is the
truth. Globs fly at 13 m/s, glow, trail beads, and drag a shadow across
the road (`Spit._shadow`) while the landing ring closes from 1.9x to 1x;
a strike's ring fills with a disc over `STRIKE_WARNING` (1.3 s).

`Saw` is a hazard, not a zombie: planned per level like crates
(`Difficulty.saws_for_level`, from `SAW_LEVEL`, two from
`SAW_TWO_LEVEL`, never on the opener or inside the fork), spawned
`SAW_OFFSET` past a gate, rolling at the road's speed plus its own and
wobbling across its lane. `World._move_saws` cuts zombies in its path
(they pay bounty) and, once per saw, tests the squad: a dash dodges, a
shield blocks, otherwise `saw_bite` (12%, floor 3) through the armour.
The bot steps round the nearest saw before anything else.

Deaths: `Squad._tumble` reparents a lost soldier to the world, freezes
its animation and tweens it up, out toward the nearest curb and down
past the bridge, spinning, over 1.1 s, at most `MAX_TUMBLING` at once.

## Perks you can read and feel

A perk gate panel carries three lines: the name, what it does
(`Perks.description`) and, once you hold one, "n of max held"
(`PerkGate.setup` takes the current stacks). Taking one banners
`Perks.pickup_text` (name, count, effect) and the HUD strip under the
stats shows `Perks.summary` for the rest of the run. Effects announce
themselves through `World.perk_felt`: `World._bite` applies thick skin
to every heavy bite and emits how many soldiers it saved, the recruiter
emits its soldier at each gate, and the bounty counter shows the greed
multiplier as kills land. The help page's PERKS section is generated
from the catalog.

## Supply: the bounty on the road

`GateMath.supply(cost, id, amount)` is a panel priced in coins
(`value` is minus the cost, `power` the power-up or "soldiers",
`amount` the soldiers). `Difficulty.make_supply` prices soldiers at
`SUPPLY_SOLDIER_COST` each (six, or an eighth of the squad, up to
`SUPPLY_SOLDIERS_MAX`) and power-ups from `SUPPLY_POWER_COST`, offered
from `SUPPLY_LEVEL` in the extra lanes with the other deals. The world
keeps `supply_funds` equal to the run's bounty (the game updates it on
every kill and purchase); on the gate it pays or refuses
(`supply_bought` / `supply_refused`), and the game takes the cost off
the bounty so the end-of-run coins are what is left. Gold on the panel,
"NEED n COINS" when short. The bot buys soldiers under sixty and a
power-up otherwise, when the bounty covers it.

## Veterans

`Veterans` (pure) is a roster of up to `MAX` named soldiers with a
trait each: `promote` after a boss (a fresh name, a random trait),
`roll_loss` on a heavy bite (`RISK`), and the multipliers the squad
reads (`damage_mult`, `bite_mult`, `coin_mult`, `medics`). The squad
owns it (`Squad.veterans`): `mark_veterans` dresses the front-rank
soldiers (behind the hero) with `Soldier.set_veteran` (a beret in the
trait colour; the name stays in banners and the pause menu, since three
tags on adjacent heads read as one smear) and only touches a soldier whose mark is
wrong, so the crowd's churn costs nothing; `lose_veteran` tumbles that
soldier over the side by name and lets the crowd close the gap.
`World._bite` reads the tough multiplier with the armour; the game
promotes in `_on_boss_killed` (a banner two seconds after the clear),
rolls losses in `_on_squad_bitten`, and multiplies the run's coins by
the lucky veterans at the end. Veterans do not carry over: a run's
story stays in the run.

## The learning round

Text on the road is kept to what the eye needs; teaching happens in
paused cards. `Lessons` (pure) holds the catalog, the order for the
LEARN page, `for_level` (what a new level introduces), `perk_body`
(the three perks on offer, with effects) and `due` (on, not yet seen
unless a learning round, and past the cooldown). `Game._check_lessons`
runs each frame of a run and looks at what is within reach: the next
gate's panel kinds, the next perk gate, the fork, the nearest saw, the
squad size and kill count; `_teach` pauses the tree, marks the lesson
seen and shows the card; `GOT IT` resumes. Bosses, the horde and new
levels teach from their own signals. A wipe closes any open card first.
LEARN starts a run with `_learning` set so every lesson is due again;
LESSONS in SETTINGS turns them off. The bot never sees a card.

HUD bands on the road, top to bottom: stats, power-up timers, the boss
bar or fork preview, the banner (0.23), the hint (0.37), floats rising
from 0.47, the combo (0.57), the squad, then the dash readiness and the
formation and bomb buttons. Nothing is placed in another band's space.

## The help page, records and the storm

`HelpText.sections()` is the in-game HOW TO PLAY page: short sections a
teenager can read, with every number pulled from the real constants.
Any mechanic change updates it in the same commit (see CLAUDE.md and the
test in tests/test_run13.gd).

`Stats` keeps lifetime numbers (sums, with best-of keys for combos and
levels) and `Achievements` watches them against thresholds, paying stars
once each. Both show on the RECORDS page; new achievements show on the
wipe screen.

The storm is the third boss. It holds back like the spitter and, instead
of rings near the squad, calls a line of bolts across the whole road
with one gap of `Difficulty.STORM_GAP`, every few seconds, two lines
when enraged. The squad has to find the gap and fit through it, so a
tight formation matters.

## Character mode

Off by default: the squad wears the classic military kit. On (Settings,
title or pause), the title gains a LOCKER. `Wardrobe` (pure, tested) holds
the catalog: heroes (a face, hair and one line each), outfits, hats,
weapon skins and backs, a star wallet, what is owned and what is worn.
Stars come from runs: one per boss, one per four perfect gates, one for
getting through three gates, endless pays one per eight gates. The
auto-player never earns or spends.

The hero is the front soldier, dressed from `Wardrobe.look()` with a name
tag; the rest wear `crew_look()`: the same outfit, hat, weapon and back
with their own random faces, unless the CREW tab says rainbow, shadow,
no hats or twins. The locker shows a big preview in front of
the camera above the card. On a wipe the hero "escaped": nobody dies in
character mode, which is the point for a younger player.

## Balance notes

The built-in auto-player (`++ --smoke`, add `--endless` for that mode)
picks the better panel, shoots whatever is close, tracks the boss core and
takes the first perk offered. It is a strong proxy for a practised human;
a newcomer lands well below it.

| Metric | Run 11 result (bot, no upgrades) |
|---|---|
| Normal: wipe level, four seeds | 6, 7, 7, 9 |
| Hard: wipe level, two seeds | 4, 5 |
| Nightmare: wipe level, three seeds | 2, 3, 3 |
| Endless: after 3 minutes | level 8, peak 1113 |

Seeds: `++ --smoke --smoke-seed=N`. One seed is noise; check four.

Regulators that keep a level in range: multipliers are 20% of good panels
and vanish once the squad passes 150 (sums lose their doubling terms at
the same point); a wider road spawns waves in a band that grows slower
than the road; halving gates appear on the bad side
from tier 2; brute health and wave size scale with the squad; and the
per-level reset caps compounding at eight gates.

## Twist backlog

Grouped by what they add. Starred items are the first to build.

### Make the gate choice strategic
- ★ Shootable gates (built).
- ★ Hidden values revealed by proximity or a bullet (built).
- Values that tick down while you hesitate, or flip when a zombie touches
  the panel.
- Kill combos, wave-clear and PERFECT bonuses (built in run 5).
- Dual-resource gates: one side grows the squad, the other grows fire rate.
- Trade-off gates: `-3 soldiers, +50% damage`.
- ★ Formation control: tight to wide, continuous (built in run 6).

### Make runs varied
- ★ Mid-run perk picks every third gate (built).
- ★ Branching lanes with a preview strip (built in run 7).
- ★ Zombie types that interact with gates: thieves and tanks (built).
- ★ Boss with a shootable weak point that multiplies damage (built).

### Keep people coming back
- ★ Levels with a boss and a squad reset (built).
- ★ Small meta upgrade shop paid with run coins (built, eight upgrades).
- ★ Daily seeded run with a shareable result (built).
- ★ Endless mode as an unlock (built).
- ★ Unlockable squad types: shotgunners and medics (built).

### Strange twists that could be the hook
- Play as the horde: gates grow your zombies, soldiers are the obstacle.
- Gate math that gets harder: `x2 then -5` vs `-5 then x2`, fractions.
- Named, persistent soldiers you can lose and rescue.
- Pass-and-play: two people alternate gate picks on one phone.

## Art direction (graphics pass 1)

Everything is still primitives built in code, so the look comes from
light and surface rather than models. `Game._build_scene` sets a
`ProceduralSkyMaterial` sky, a warm `DirectionalLight3D` key with
orthogonal shadows (toggle in Settings), a cool fill, filmic tonemapping
with slight contrast and saturation, glow with a threshold of 1.0 so
only `Mats.glow` materials (emission above 1) bloom, and thin fog.
`Mats.grainy` builds a noise texture once (FastNoiseLite, remapped into
[1 - strength, 1]) and lays it on triplanar in world units, so asphalt,
curb and dirt differ by colour, scale and strength. `World._build_scenery`
places a skyline, wrecks, rubble, trees and cracks from a fixed seed and
wraps them with the road. A canvas vignette sits under the HUD.

Pass 2 adds the ink line: `Mats.outline` is a cull-front, unshaded
shader that pushes vertices out along their normals, attached as
`next_pass` to a copy of a mesh's material by `Mats.ink`. It is on the
detailed soldiers, every zombie, the bosses, vehicles and gate frames,
and off the crowd so draw calls stay in budget. Zombies share the
soldiers' round language (egg torso, big head) so the cast reads as one
world; kinds differ by colour and one prop each. Panels are a frame, a
glossy faintly emissive face and a glowing top strip.

Pass 3 is `Fx`: one-shot `CPUParticles3D` emitters (blood, dust,
sparks, smoke) that free themselves, and a continuous dust trail under
ground vehicles. The auto-player skips the one-shots. Zombies die by
falling over (a tween on the body), tracers carry a translucent tail,
and the camera sits on a rig that sways with the steering so the framing
code is untouched. The HUD theme's default font is Lilita One (OFL).

## Art direction (original notes)

Flat-shaded low-poly primitives on purpose, but assembled into characters:
soldiers have running legs, a vest and chest plate, helmet and visor,
backpack, and two arms on a gun that recoils; zombies hunch forward with
arms out, red eyes, a shirt from a dull palette and shambling legs; brutes
add shoulder plates; the boss has legs, fists, a jaw, spikes and a ringed
core. The front of the squad gets the detailed build and the crowd behind
it a cheaper one, which keeps a 36-soldier squad near 400 draw calls.
Readability over fidelity: blue is yours, green is theirs, yellow is a
target.
