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
- The world scrolls toward the squad at 8 to 12 m/s during gates and slows
  to 2.5 m/s for the boss. The squad stays at the origin and steers across
  a six-metre lane.
- A gate every 32 m. Each gate is two panels. The squad's x position at
  the moment the gate reaches it picks the panel. The first gate of every
  level is a visible additive gain, a foothold for the fresh squad.
- Panels are additive (`+n`, `-n`) or multiplicative (`x2`, `x3`, `x0.5`).
  Additive values climb by one per step of bullet damage; multipliers climb
  by 0.5 per step and cost three times as much. A step costs the larger of
  a level floor and 90% of the squad's damage per second, so farming a gate
  yields roughly one step per second of committed fire at any squad size.
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
- Clearing a level pays `150 x level + 5 x soldiers left`. The run ends
  when the count hits zero.
- After the third and sixth gate of a level the game stops and offers
  three perk cards drawn from a pool of nine, seeded by the run. Perks
  stack to a cap and last the run. Rapid fire and big bullets change the
  guns; piercing lets a bullet survive a kill; gate whisperer cuts step
  cost; recruiter adds a soldier at every gate; thick skin, long sight,
  core sight and greed do what they say.
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
- Endless mode (unlocked by reaching level 4) has no bosses and no reset.
  Levels tick every eight gates for difficulty and the HUD; the run 1
  regulators (multipliers vanish past 150 soldiers, halving gates, brute
  health scaling) keep it from exploding.

## Balance notes

The built-in auto-player (`++ --smoke`, add `--endless` for that mode)
picks the better panel, shoots whatever is close, tracks the boss core and
takes the first perk offered. It is a strong proxy for a practised human;
a newcomer lands well below it.

| Metric | Run 4 result (bot, no upgrades) |
|---|---|
| Levels: squad at each boss, 1 to 8 | 100, 118, 53, 42, 143, 134, 62, 63 |
| Levels: after 6 minutes | level 9, 17 soldiers, still alive |
| Endless: after 3 minutes | level 7, peak ~350, 89 left |
| Daily: after 90 s | level 3, two bosses down |

Regulators that keep a level in range: multipliers are 20% of good panels
and vanish once the squad passes 150; halving gates appear on the bad side
from tier 2; brute health and wave size scale with the squad; and the
per-level reset caps compounding at eight gates.

## Twist backlog

Grouped by what they add. Starred items are the first to build.

### Make the gate choice strategic
- ★ Shootable gates (built).
- ★ Hidden values revealed by proximity or a bullet (built).
- Values that tick down while you hesitate, or flip when a zombie touches
  the panel.
- Dual-resource gates: one side grows the squad, the other grows fire rate.
- Trade-off gates: `-3 soldiers, +50% damage`.
- Formation choice: wide line, column, wedge, each with a cost.

### Make runs varied
- ★ Mid-run perk picks every third gate (built).
- Branching lanes with a tiny minimap.
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

## Art direction

Flat-shaded low-poly primitives on purpose, but assembled into characters:
soldiers have running legs, a vest and chest plate, helmet and visor,
backpack, and two arms on a gun that recoils; zombies hunch forward with
arms out, red eyes, a shirt from a dull palette and shambling legs; brutes
add shoulder plates; the boss has legs, fists, a jaw, spikes and a ringed
core. The front of the squad gets the detailed build and the crowd behind
it a cheaper one, which keeps a 36-soldier squad near 400 draw calls.
Readability over fidelity: blue is yours, green is theirs, yellow is a
target.
