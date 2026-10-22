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

## Core loop (as built in run 1)

- The world scrolls toward the squad at 8 to 12 m/s. The squad stays at
  the origin and steers left or right across a six-metre lane.
- A gate every 32 m. Each gate is two panels. The squad's x position at
  the moment the gate reaches it picks the panel.
- Panels are additive (`+n`, `-n`) or multiplicative (`x2`, `x3`, `x0.5`).
  Additive values climb by one per step of bullet damage; multipliers climb
  by 0.5 per step and cost three times as much. A step costs the larger of
  a distance floor and 90% of the squad's damage per second, so farming a
  gate yields roughly one step per second of committed fire at any squad
  size.
- A zombie wave sits 26 m after each gate, which is 6 m before the next
  one. Waves are shielded by the gate in front of them until it passes,
  then exposed for about three seconds.
- Normal zombies have small health and eat one soldier. Brutes have health
  that scales with the squad (about a second of its full fire) and eat 8%
  of the squad with a floor of three.
- The run ends when the count hits zero. Score is metres plus ten per kill.

## Balance notes

The built-in auto-player (`++ --smoke`) picks the better panel and shoots
whatever is close. It is a decent proxy for a competent human. Targets:

| Metric | Run 1 result |
|---|---|
| Survives first wave with one or two soldiers | yes |
| Peak squad at 500 m | ~200 |
| Run length for the bot | ~70 s, ~670 m |
| Exponential blow-up | none (was 555 million before regulators) |

Regulators that stop an endless run exploding: multipliers are 20% of good
panels and vanish once the squad passes 150; halving gates appear on the
bad side from tier 2; brute health and wave size scale with the squad.
These are deliberately crude. Run 2 replaces endless growth with levels
and bosses, which is the proper fix.

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
- ★ Mid-run perk picks every few gates (ricochet, piercing, extra soldier
  per gate), the Vampire Survivors engine.
- Branching lanes with a tiny minimap.
- Zombie types that interact with gates: thieves that steal a bonus, tanks
  that block the lane so you cannot farm the gate behind them.
- Boss with a shootable weak point that multiplies damage.

### Keep people coming back
- ★ Levels with a boss and a squad reset, so growth is bounded per level
  and the boss sets the bar.
- ★ Small meta upgrade shop paid with run coins (starting squad, damage,
  gate bonus). About eight upgrades. No gacha.
- Daily seeded run with a shareable score code. The generator is already
  seeded, so this is cheap.
- Endless mode as a separate, post-levels option.
- Unlockable squad types: shotgunners, a medic that revives one per wave.

### Strange twists that could be the hook
- Play as the horde: gates grow your zombies, soldiers are the obstacle.
- Gate math that gets harder: `x2 then -5` vs `-5 then x2`, fractions.
- Named, persistent soldiers you can lose and rescue.
- Pass-and-play: two people alternate gate picks on one phone.

## Art direction

Flat-shaded low-poly primitives on purpose. Readability over fidelity. If
real models arrive later they replace primitives one class at a time
without touching the logic.
