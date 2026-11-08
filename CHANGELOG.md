# Changelog

Versions are `MAJOR.MINOR.<CI run number>`. The first two parts come from
`VERSION`; the build number comes from GitHub Actions.

## 0.52 (the stability build)

- Six reports from one Galaxy S23 Ultra all died two to five seconds
  after the home screen appeared, once before PLAY was even pressed,
  with no engine error. This build removes everything that happens in
  that window and could kill a process from outside GDScript, instead
  of testing one guess at a time on a player's phone:
  - The music loops are no longer built on a worker thread that handed
    them over a few seconds after boot. They are built one a frame
    under the loading screen, and the game has no other thread.
  - Phones are capped at 60 frames a second. A 120 Hz panel had the
    game doing every frame's work twice as often as any other phone.
  - The vibrate permission from 0.51 stays.
- The heartbeat is written once a second instead of every three, and
  the warm-up and each music loop leave a breadcrumb, so if anything
  is left the next report names the second and the step.
- Reports carry real memory numbers (the OS's, since the engine's
  counter is zero in release builds) and the frame cap.

## 0.51 (hotfix: the crash at the first gate)

- Fixed: 0.50 crashed at the first gate on Android. The new haptics
  vibrated without the VIBRATE permission in the export, and Android
  killed the app from the Java side with no GDScript error to report.
  The first two crash reports to reach the server (a Galaxy S23 Ultra,
  three seconds into a run, no errors, right after 0.50) pointed at
  it. The permission is in the export now, and a test fails the build
  if code vibrates without it, or talks to the network without
  INTERNET.
- Breadcrumbs through a run: the level, each gate, the boss and the
  hero move are marked, so a crash names where it was.
- The report's OS field was empty on Samsung; it falls back to the
  version alias. Confetti joins the shader warm-up.

## 0.50 (the feel pass)

- The phone buzzes with the game: a tap for a bite, a thump for a
  brute, a long one when the boss goes down, and shorter ones for
  gates, perfects, the hero move, walls, saws, pit buys and the wipe.
  HAPTICS in SETTINGS turns it off.
- Heavy kills land with a blink of stopped time and a nudge of the
  camera; the boss falls in slow motion under a flash and a shower of
  confetti.
- The music brightens as the combo climbs: a shimmering high layer
  rises with the multiplier and fades when the chain breaks.
- The results card counts the score up from zero with rising ticks and
  a chime when it lands; the squad cheers on a perfect and on its move.

## 0.49 (events, the weekly challenge, boss rush)

- Weekend events: on Saturdays and Sundays the whole road carries one
  event, named on the home screen and at the start of the run, the same
  for everyone: DOUBLE BOUNTY, a SAW STORM (two more saws a level, and
  faster) or FOG ON THE BRIDGE (a grey haze, panels show late). They
  rotate week to week.
- The weekly challenge: every weekly run of a week carries a twist
  (fog, a saw storm, elite waves or a fast road), named on the daily
  card and in the weekly board's header, so the board is a new contest
  every week.
- BOSS RUSH, a new mode at 1200 trophies on the road: one gate, then
  the boss, level after level, with thirty extra soldiers to start and
  its own best.

## 0.48 (the run meta: quest coins, the streak, the bar, the snipers)

- Quests pay coins as well as points: three coins per point, and 300
  more on a day with all three done. The quests page and the wipe card
  say so.
- A day STREAK: finish a run on consecutive days and every run's coins
  grow five percent per day, up to fifty; miss a day and it starts
  over. The home screen shows the streak under the wallet and asks for
  today's run while yesterday's streak still stands.
- A gold bar under the road line on the home screen fills toward the
  next milestone; the wipe card says how many trophies are left to it.
- The road's later milestones are filled in: the SNIPERS squad opens
  at 2000 trophies (the shop sells it too), and from 2500 every 500 is
  a named locker item to the end of the road.
- SNIPERS: a fourth squad that fires slowly, hits more than twice as
  hard, and goes through one more zombie with every shot, in dark green
  with long barrels. Their hero move is the LONGSHOT, one beam down the
  squad's line through everything in it, walls and the boss included.

## 0.47 (the hero move)

- Every squad has a move, on the HERO button above the bomb or a tap
  on the squad itself. Rifles fire a VOLLEY: one hard shot per soldier
  dead ahead, through the first thing it meets. Shotguns burst a
  SHOCKWAVE that hits everything near the squad for seconds of its
  fire and throws the survivors back. Medics send a HEAL PULSE that
  brings a slice of the squad back under a shield. Twenty seconds to
  recharge, with the button filling as it does.
- HERO POWER in the SHOP: three levels, each three seconds off the
  wait and a quarter more on the move.
- A lesson the first time the squad is big enough to matter, a HOW TO
  PLAY section, and the bot uses it.

## 0.46 (the turret, the wall, the splitter)

- The GOLD TURRET: a gun that rides the curb beside you, keeps
  pace, and fires on its own at whatever is nearest. Its fire is on top
  of the squad's and outside the squad's cap, so it is the one buy that
  makes a huge squad hit harder. The pit stop sells it (120 bounty,
  two at most) and gold supply panels offer it; it lasts the run and
  grows with the level.
- WALLS: from level 3 a barricade stands across half the road a little
  after a gate, two a level from level 6. Shoot it down before it
  arrives (about a second of your fire; a bar shows once it is hit) or
  steer onto the open half; run into it and it shatters and takes six
  percent of the squad.
- SPLITTERS: from level 4 a slow, bloated yellow-green zombie with
  twice the health bursts into three fast runners when it dies,
  wherever it dies. Kill it far away.
- Lessons for all three, HOW TO PLAY lines, the bot steers round walls
  and buys a turret first at the pit.

## 0.45 (bodies: chunkier, livelier, louder)

- Soldiers and zombies are chunkier: bigger heads on barrel bodies
  with no neck, thicker legs and arms, bigger boots and hands, a
  bigger gun with a stock, bigger glowing eyes and a wider jaw on the
  zombies. The silhouettes read from the far end of the road. Helmets
  wear the squad's colour (blue, orange or white by type): from above
  a squad is mostly helmets, and a blue squad should look blue.
- They move more: the run bobs and leans into each step with the head
  a beat behind; zombies roll their heads, swing harder when they run,
  squash and get knocked back a step when shot; the whole squad
  flinches when bitten.
- The muzzle flash is a four-point star with a white core, turned
  differently every shot; tracers are fatter with a longer streak.
- Confetti on a good gate, more on a rally, a shower on a PERFECT.

## 0.44 (colour: the bridge, the water, the red crowd)

- The world is a bridge over water. Girders under the deck, a concrete
  walkway outside each curb where the wrecks now stand, moving water
  below with foam on the crests, and a far shore the skyline and the
  dead trees stand on. The pit lane stands on a pier.
- The palette, in one place (`Palette`) with tests that hold the
  contrasts: a saturated blue deck, cream curbs, yellow lines, a hot
  red zombie family (brutes darker, runners orange, thieves yellow,
  tanks steel, latchers purple), brighter blue soldiers, panels that
  glow like lit signs, a deeper sky over a peach horizon, a stronger
  sun, a bluer fill, more saturation in the grade, and a thicker,
  darker ink line round everything.
- Fixed: gate panels showed as grey slabs with a coloured strip. Since
  0.34 the panel's dark frame had reached past its face toward the
  camera and hidden the colour, so BLUE and RED were only the strip.
  The frame sits behind the face now, and the face is unshaded, so a
  panel is a solid lit sign in its colour whatever the sky does.
- Zombie health bars only appear once a zombie has taken damage; a
  black bar over every healthy head was the heaviest thing on screen.

## 0.43 (reports that send themselves)

- Crash, freeze and slow-start reports go to the game's server on
  their own. After a session that died in the foreground, a single
  frozen frame of two seconds or more, or a start slow enough to
  switch safe graphics on, the game sends what it knows: phone model,
  OS, graphics chip, renderer, frame-time buckets and the worst
  frames, the event log, engine error lines, a save summary, where the
  game was. Under a random install id; never a name. One freeze report
  a run, six reports a session, ten a day per phone, 48 KB each, kept
  thirty days; offline, up to three wait in the save. SEND REPORTS in
  SETTINGS turns it off. The crash card and the home screen say when
  one has gone.
- SEND A BUG REPORT in SETTINGS uploads first and falls back to the
  mail app only when there is no server or no connection.
- The Worker grew `/report` and an admin page (`/reports?key=...&html=1`)
  behind a new `ADMIN_KEY` secret; see leaderboard/README.md. The
  Worker must be redeployed from the dashboard for the routes to exist.
- Performance: one-shot particle systems are capped at 36 alive at
  once, saws and the pit lane join the shader warm-up, and the smoke
  bot now prints the busiest the scene got (nodes, zombies, effects)
  and builds and signs a crash report headless, which check.sh
  requires.

## 0.42 (the balance pass: a huge squad is not a free ride)

- Measured with a new idle bot (`--smoke-idle`, `--smoke-idle-from=N`):
  before this build a squad left alone from level 6 in endless was
  still running thirteen levels later; in levels mode it died within
  two. Endless had nothing that scaled with the squad. Now: firepower
  grows past 40 soldiers with diminishing returns (500 shoot like 69)
  and crowds carry health to match, so they arrive as often against a
  big squad as a small one; multiplier panels cap at x2 for a mid
  squad and x1.5 for a big one, so random panels shrink a squad instead
  of holding it; the last gate of every endless level is an ELITE wave
  (three brutes or more, a tank, extra latchers) in place of the boss
  endless never had; latchers eat a slice of the squad per bite, not
  one soldier; the first saw of every level is thrown at where you
  stand; bosses are sized for the squad that meets them; and past level
  10 the road speeds up again while crowds keep growing. And hands
  matter: a few seconds with no touch and panels stop climbing (the
  squad's own fire had been shooting them to x5), while the horde
  behind closes in and eats until you steer again. Measured: before,
  three of four squads idled from level 6 in endless were still alive
  after six and a half minutes, at levels 18 to 20 with 180 to 390
  soldiers; after, every idle run ends in a wipe 40 to 70 seconds
  after the hands come off (from level 4 at level 5, from level 6 at
  level 8 or 9, from a peak of 500), while the bot that keeps playing
  reaches level 11 with 268 soldiers in the same time as before.
- The pit lane is painted yellow, ramps and all, with yellow arrows and
  PIT painted on the road for sixteen metres before the ramp and a lit
  strip where the lane leaves the road.
- NOTCH ROOM in SETTINGS: AUTO moves the soldier count, the level, the
  bounty, the pause button and the home screen's top chips down from
  under a camera cutout by what the phone reports; ON forces it for
  phones that do not report one; OFF for none.
- The soak script imports the project first, so it cannot hang on a
  fresh cache.

## 0.41 (a leaderboard that closes, a pit lane, a shop with pictures)

- Fixed: the LEADERBOARD page could not be dismissed. BACK showed the
  home screen under it and the next answer from the server drew the
  page over it again. Every card now goes through one hide list, BACK
  returns to the wipe card or the home screen it came from, a late
  answer cannot redraw a page that has closed, and the phone's back
  button closes any open page. The smoke bot checks this on every
  build.
- The pit stop is a pit lane. PIT LANE AHEAD flashes, the camera backs
  off and pans right, and a ramp with yellow chevrons peels off past a
  red-and-white pit wall to a garage with its door up, tyre stacks, a
  pump, floodlights, bunting and a crew that waves you in; a second
  ramp brings you back. The shoulder's wrecks clear for it. Parked at
  the garage, the gear is a sheet over the bottom of the screen with
  the garage and the crew still moving above it.
- The SHOP is a wall of tiles: a drawn picture of each upgrade that
  idles (bombs spark, the eye blinks, the heart beats), gold level
  pips, what it does now and next, the price, a glow on what you can
  afford, and a bounce when you buy. The pit stop uses the same tiles.

## 0.40 (the leaderboard up front, a real lay-by)

- LEADERBOARD sits on the home screen under the mode row, beside LEARN
  THE ROAD, with one line under it: who leads today's daily and where
  you stand (or an invitation to join). The wipe card after a daily or
  weekly run has a LEADERBOARD button.
- The pit stop is a real lay-by now. The curb drops beside it (curbs are
  ten-metre segments that scroll, so one can open) and a tarmac apron
  with cones runs off the right side of the road. While it is beside
  you the road's right edge is open: steer off onto the apron as it
  passes and the road waits. When you leave, the pit crew has cleared
  the road ahead: every zombie between you and the far spawn line is
  gone, unpaid. The edge closes behind you and anyone still off the
  road is brought back.

## 0.39 (the leaderboard)

- A leaderboard for the daily and the weekly, under MORE. Join under a
  name you pick; a finished daily or weekly run goes up signed, and the
  page shows today's and this week's top 50 with your rank. FORGET ME
  wipes your id and rows. Nothing else leaves the phone, and a build
  without a server (a local build) says so and sends nothing.
- The server is one Cloudflare Worker and one KV namespace, in
  `leaderboard/`, with its own tests (`node leaderboard/test.mjs`, run
  in CI). It checks a per-build signature, the period, and whether the
  game could have produced the numbers, rate-limits by address, keeps
  the best score per player per period, and can shadow a cheater.
  Setup is in `leaderboard/README.md`: two repository secrets and the
  Worker's URL.

## 0.38 (the pit stop, the economy, agro, a level again)

From the phone screenshots: an endless run to level 85 with a peak
squad of 34,616 and 83,876 coins in one sitting. The game had stopped
being a game long before that.

- Two kinds of money, said plainly. The BOUNTY is the run's money,
  spent on the road; COINS are the save's money. What is left of the
  bounty converts at the end: one for one up to 500, then with
  diminishing returns (84,000 bounty is about 5,400 coins, 1,000 is
  about 680). The daily and weekly still pay none.
- The bridge holds 500 soldiers. A squad cannot shoot a multiplier
  panel past x3 once it has 150 soldiers, or past x2 once it has 300,
  so x0.5 panels no longer become x5 for a thousand-strong column.
- The PIT STOP. From level 2 a gold bay sits on the right side of the
  road once a level, after the sixth gate. Steer onto it and the road
  waits while you spend the bounty on this run's gear: SHARPER ROUNDS
  (+12% damage, up to five), FASTER RIFLES (+12% fire rate, up to five),
  FLAK JACKETS (-10% on heavy bites, up to three), a BOMB (25), FIELD
  DRESSING (a tenth of the squad back on their feet). Prices climb per
  stack; nothing outlives the run. The bot pulls in when it has money.
- Bombs aim themselves at the boss or the nearest brute or tank in
  reach, the blast is a little wider, and the bomb button pulses when
  there is something worth throwing at.
- AGRO. A second wind or a rally now brings ten seconds of fury: double
  fire rate, double damage, nothing bites, the screen edges burn and the
  boss music plays. Then back to normal.
- The JEEP earns its twenty soldiers: 85 damage a second (was 50), 150
  health (was 90), through three zombies (was two).
- Stuck on a level? The results card gives one TIP picked from how the
  run ended (the boss you met, the bomb you never threw, the big squad
  that did not kill), and once a run RETRY LEVEL N starts that level
  again from its first gate with the squad you entered it with, perks,
  bounty and convoy intact. Levels mode only.
- Lessons and the help page cover the pit stop, the two currencies,
  agro and the retry.

## 0.37 (the Foreman)

- A fourth boss, every fourth level: THE FOREMAN. Hard hat, hi-vis
  vest, a saw in one hand. It hangs back and works the road: it hurls
  buzz saws down your lane every few seconds, aimed where you are
  heading, two at once when it is angry, and drops supply crates
  between you every seven seconds. No lightning. The fight is dodge,
  grab and shoot the core.
- The boss cycle is now walker, spitter, storm, foreman; the foreman
  carries 90% of a walker's health. The help page, the lessons and the
  bot cover it.

## 0.36 (veterans)

- Veterans. Beat a boss with anyone left and one survivor steps up with
  a name and a beret in their trait's colour, riding in the front ranks: DEADEYE (+8% damage for the whole squad), TOUGH (heavy
  bites take 8% less), FIELD MEDIC (a soldier comes back every 8
  seconds), LUCKY (+15% coins at the end). Up to three a run; they do
  not carry over.
- Losing one costs something you can see. Any heavy bite has a one in
  five chance to take a veteran with it: "ADA IS DOWN", and ADA goes
  over the side of the bridge by name.
- The pause menu lists the veterans beside the perks; RECORDS counts
  veterans made; a lesson explains them the first time one steps up.

## 0.35 (QA pass and the learning round)

- QA on the running screen. The formation button's long labels ran off
  the right edge of the screen; it now says TIGHT, NORMAL, WIDE or
  STRAIGHT only. The perk strip sat on top of the boss bar and the fork
  preview; it is gone from the road and lives in the pause menu. The
  level banner, the teaching hint, the floating gate text and the combo
  readout each have their own band now, so none lands on another: the
  banner at the top quarter, the hint under it, floats start below the
  hint and drift up into the gap, the combo sits above the squad.
  Perk panels show the perk's name only (and a small count for one you
  hold); what each does is taught, not printed on the gate. Supply
  panels put their price on a second line.
- The learning round. The first time something new appears on the road
  (a hidden panel, a sum, a deal, a supply panel, a vehicle panel, a
  perk gate with the three perks on offer, the fork, a saw, each boss,
  the horde, the dash, clingers, hot panels, fire modes once the squad
  is big enough, the bounty after the first kills) the road pauses and
  one short card explains it; GOT IT and play on. Each card shows once,
  ever, with a few seconds between cards so a busy gate does not stack
  them. LEARN on the home screen starts a learning round where every
  card shows again; LESSONS in SETTINGS turns them off. HOW TO PLAY
  stays as the long version.

## 0.34 (supply panels: spend the bounty on the road)

Turn 5 of the second feedback arc: the bounty is a currency you can
spend before the run ends, not just a score for the shop.

- GOLD panels are SUPPLY. From level 2, in the extra lanes, a gate may
  offer soldiers (six, or an eighth of the squad, at 7 coins each) or a
  power-up (shield 40, bomb 30, frenzy 40, slow-mo 35) for coins out of
  this run's bounty, paid at the gate. The counter under the level drops
  by the price. What you spend on the road you do not take home, so a
  wide, rich run can buy its way out of a bad patch and a careful one
  can bank it all for the shop.
- Not enough bounty and the panel does nothing but say so.
- The bot spends when it can: soldiers for a small squad, a power-up
  otherwise.

## 0.33 (gates that explain themselves)

Turn 4 of the second feedback arc: no more mystery perks.

- Every perk panel says what it does under its name, and how many of
  it you already hold ("1 of 2 held").
- Walking through one banners the name, the new count and the effect,
  and a strip under the stats lists every perk you carry for the rest
  of the run.
- Perks you can feel. THICK SKIN now softens every heavy bite (brutes,
  tanks, bosses, lightning, spit, saws, the horde), not just brutes, and
  banners how many soldiers it just saved each time. RECRUITER shows
  its extra soldier at every gate. GREED shows on the bounty counter as
  the run goes, not only at the end.
- ARMOR from the shop now covers tank bites too, so the shop's line
  about heavy bites is true everywhere.
- HOW TO PLAY has a PERKS section listing every perk, what it does and
  how many you can stack, read from the catalog so it cannot go stale.

## 0.32 (bosses you can dodge, buzz saws, soldiers over the side)

Turn 3 of the second feedback arc.

- Globs you can see coming. The spitter's globs are bigger and glow,
  trail a tail, fly a little slower, and cast a shadow on the road that
  shows where they are and how high. The red landing ring closes in as
  the glob comes down. Only the ring is wet: the splash is half a metre
  past it, not the whole formation's width, so stepping out of the ring
  is enough.
- Lightning that warns. The warning is 1.3 seconds, a disc fills the
  ring as the bolt comes, and the bolt only hits inside the ring.
- Buzz saws. From level 2 a toothed, hot-edged saw rolls down the
  bridge at you now and then (two a level from level 5), wobbling
  across its lane, a little faster than the road. Steer round it or dash
  through it; touching it takes a slice (12% of the squad, three at
  least, armour applies). It cuts zombies too. "SAW AHEAD" when one
  appears.
- Soldiers go over the side. A lost soldier is knocked up and out toward
  the nearest curb, spinning, and falls past the edge of the bridge.
- The bot steps round saws, and the help page explains all of it.

## 0.31 (fire modes and the bounty)

Turn 2 of the second feedback arc: two ways to shoot, and coins for
every kill, so wide-and-rich and narrow-and-sure are both real plans.

- STRAIGHT fire. The formation button now cycles TIGHT, NORMAL, WIDE
  and STRAIGHT. In STRAIGHT every round leaves from the middle of the
  squad and flies dead ahead, 25% harder and through one more body: the
  drill for a brute, a tank, a boss core or a panel in front of you,
  while the sides of the road go unwatched. A drag on the width ends it.
- The bounty. Every kill pays coins by kind: walkers and runners 1,
  thieves and latchers 2, brutes 3, tanks 5; bosses 25 and gates 2 as
  before. A coin counter under the level shows the run's bounty growing
  and bumps on every kill. The old quarter-coin-per-kill is gone, so a
  run pays about three times the coins it did; shop prices are up two
  and a half times to match, so the first upgrade is still about one
  good run.
- The formation button says what each mode is for: TIGHT focus, WIDE
  cover and coins, STRAIGHT drill.
- The bot plays both plans: it drills when a heavy or the boss core is
  lined up ahead and sprays otherwise. Seed 3, normal: 624 kills, 742
  bounty, level 5.

## 0.30 (runs on the slow phones: warm-up, watchdog, crash card)

The first turn of the second feedback arc. Phones were freezing or
crawling right after launch and settling later, which is what shader
and font compilation looks like on a phone's GPU driver: every material,
particle and text size is compiled the first time it is drawn.

- A loading screen. Under it the game draws one of everything for a few
  frames (every zombie kind, every boss, every vehicle, soldiers of each
  squad, a gate with every panel type, a perk gate, a route gate, a
  crate, a strike, a glob, a shell, a bomb, tracers, every particle) and
  every text size the HUD uses, then frees it all. The stutters that
  used to land on the first boss, the first vehicle and the first death
  now happen once, behind the loading screen.
- A frame-rate watchdog. If the game averages under 22 frames a second
  over five seconds, SAFE GRAPHICS switches itself on, once per install,
  with a note saying where to change it back. Low frame rates are logged
  for the report either way.
- After a crash, the next launch opens a card: THAT WAS A CRASH, with
  SEND THE REPORT (one tap into the mail app) or NOT NOW.
- Boot timings (scene build, warm-up) go into the report.

## 0.29 (diagnostics, bug reports, safe graphics)

- Bug reports by email. SETTINGS has a line for what happened and a
  REPORT A BUG BY EMAIL button. It opens the mail app with a report
  filled in (phone, Android version, GPU, app version, the last 200
  game events, any frames that stalled for half a second or more, how
  the previous session ended and where, error lines from the engine's
  own log of the previous session, a save summary) and copies the same
  text to the clipboard.
- A heartbeat. The game writes what it is doing every few seconds and on
  every change (title, running, paused, game over and each step of the
  results: records, road, stats, card). If it dies in the foreground,
  the next launch says so on the title screen and the report names the
  step. Going to the home screen is a clean exit, so the system killing
  a backgrounded app is not counted.
- The engine's log is kept on the phone (three sessions) so script
  errors from release builds reach the report.
- SAFE GRAPHICS in SETTINGS: no glow, fog, shadows, anti-aliasing or
  vignette, for phones whose drivers glitch on the extras.
- Two guards on the results screen: slow motion can never outlive the
  run (the clock is forced back to normal in every state but RUNNING and
  the reset is logged), and the tap-to-retry lockout runs on the wall
  clock, not on game time. If a phone was freezing on the results
  screen because the clock was left slow, that was the fix; the report
  will say if it ever happens again.
- QA: the bot can play through the results screen and restart
  (`--smoke-retry`); CI now does that on a nightmare seed. The bot's
  dice are seeded, so a seed replays. `scripts/ci/soak.sh` runs every
  mode and modifier across seeds and fails on any script error.

## 0.28 (home, road, rally)

- The home screen. No box. Title and a big PLAY in the middle, the modes
  in a row under it, coins and stars top-left with a "+" into the shop,
  SHOP and LOCKER top-right, MODE and squad bottom-left, "?" and SETTINGS
  bottom-right, the trophy line and the next thing to do bottom-centre.
  RECORDS, QUESTS and the ROAD live in a MORE drawer. New players still
  see PLAY and little else.
- The trophy road. Every run adds trophies and nothing takes them away:
  10 per level reached, a grade bonus (S 15, A 10, B 5, C 2), double on
  hard, triple on nightmare, half rate in endless. A milestone every 100
  pays coins, stars or a locker item; a checkpoint every 500. ENDLESS
  opens at 300, HARD at 600, the WEEKLY at 900, NIGHTMARE at 1500.
  Anything an older save already had by the old level rules stays open.
  A ROAD page shows what opens where and the track ahead; the title
  shows your count and the next milestone; the wipe screen shows what
  the run added.
- The rally. When the squad hits zero, once a run, a five-second offer:
  8 soldiers back, a shield, the clingers shaken off, for 3 stars, then
  5, then 8 within a day. Second wind from the shop is free and fires
  first. Never in the daily or the weekly.

## 0.27 (feedback pass: the road watches you)

- The rubber band. Every level expects a squad of a certain size. Run
  bigger and zombies come thicker and bite harder, up to half again as
  much; run smaller and they ease off, up to a fifth. Bosses follow at
  half strength. The convoy counts toward the read. Neutral sits a
  little under the expected squad, so a practised player stays busy and
  a struggling one gets slack. Modifiers stack on top.
- Squad compounding capped: a won bet pays at most 80 soldiers instead
  of doubling whatever you have, and past 150 soldiers the fork offers
  flat gains instead of x2 and x3. Peak squads on long bot runs fall
  from around twelve thousand to a few hundred; endless from eleven
  hundred to about five hundred.
- Bot with no upgrades, four seeds: wipes on levels 4, 5, 11 and 12,
  peak squads 157 to 667. The spread between seeds is wide; the middle
  is where it was.

## 0.26 (graphics pass 3: effects and motion)

- Particles on the Compatibility renderer: a splash when a zombie dies,
  dust when a soldier falls, sparks, dust and smoke when a shell bursts,
  smoke and sparks when a vehicle is wrecked, sparks on a boss core hit
  and a vehicle rank, and dust trailing behind jeeps and tanks.
- Zombies go over backwards when shot instead of sinking into the road.
- Tracers have a fainter tail behind the bright head.
- The camera rides a rig that drifts toward the squad and leans into a
  turn.
- A display font for every label and button: Lilita One, under the SIL
  Open Font License (assets/fonts/OFL.txt).

## 0.25 (graphics pass 2: people and things)

- An ink line round characters and things: an inverted-hull outline
  drawn as a second pass, on the front ranks of soldiers, every zombie,
  the bosses, the vehicles and the gate frames. The crowd behind the
  front ranks stays cheap.
- Zombies rebuilt in the same round style as the soldiers: hunched egg
  torsos with a torn patch, big heads with sunken glowing eyes, a slack
  jaw and a cap of hair, open hands, bare feet. Brutes wear pads and a
  belt, tanks carry a riveted scrap slab, thieves a sack, latchers
  claws. Hits squash them wide and short for a moment; bosses too.
- Gate panels have a dark bevelled frame, a glossy face that glows
  faintly in its own colour, and a bright strip along the top so a row
  of panels reads from far down the road.
- Vehicles get headlights and the ink line.

## 0.24 (graphics pass 1: light and world)

The first of three graphics passes. This one is the light and the world;
the next two are the people and the effects.

- A real sky (late afternoon, warm horizon, blue overhead) lights the
  scene; a warm key light casts shadows, a cool fill lifts the dark
  side. Filmic tonemapping, a touch of contrast and saturation, and
  glow on the things that give off light: bullets, muzzle flashes, the
  boss core, lamp heads, lit windows. Fog only takes the far distance.
- Surfaces have grain: asphalt, curbs and dirt are textured with noise
  laid on in world units, no art files. Asphalt is dark and cool, dirt
  is dirt.
- The world beyond the curbs: a ruined skyline far out with a few lit
  windows, wrecked cars, rubble and dead trees on the shoulders, cracks
  on the road, lamp posts with arms and glowing heads. All of it scrolls
  with the road.
- A soft vignette under the HUD. SHADOWS: ON/OFF in Settings for weaker
  phones.

## 0.23 (polish turn 6: balance and QA)

- The road answers the convoy: each vehicle counts as 20 soldiers when
  waves are sized and adds 12% to boss health, so a convoy is a trade,
  not a free win. Bot with no upgrades now wipes on levels 5, 5, 9 and
  10 across four seeds instead of riding out six minutes.
- Fixes from a review of turns 1 to 5: a second wind could be spent and
  the run end anyway when two bites landed in one frame (a wipe now
  fires once, on the way down); tank shells in the air after a wipe no
  longer burst, score or freeze the wipe screen in slow motion; players
  with saves older than the lifetime stats keep their title buttons;
  helicopter and mech turrets no longer jump on the first shot; season
  stars count in the records, and a season item you already own pays
  its price in stars instead of nothing; the wipe card fits the screen
  and collapses a long list of extras into one line; the shop scrolls;
  the locker tabs fit.

## 0.22 (polish turn 5: come back tomorrow)

- Three QUESTS a day, the same for everyone, progress kept across the
  day's runs: kill so many zombies, shoot so many perfect gates, form a
  vehicle, win a bet, reach a level, and so on. Each one done pays
  season points.
- A free SEASON track: thirty days, thirty tiers, a reward at every one.
  Coins, stars every third tier, a locker item every fifth, rotating
  with the season. Nothing to buy. The QUESTS page shows today's three,
  the tier bar and the whole track.
- The wipe screen lists quests completed and tiers reached; the title's
  next-goal line nags about open quests. QUESTS appears after the first
  run.

## 0.21 (polish turn 4: one game, one look)

- One theme for every screen: rounded dark-glass buttons with a warm
  pressed state, rounded panels behind every card, a styled scrollbar.
  Drawn coin and star icons instead of words.
- The title and the wipe screen name the next thing to do: play a run,
  reach level 3, an upgrade you can afford, form a jeep, try hard mode,
  the day's daily, save for the next upgrade, beat your best.
- The title unlocks gradually: a new player sees PLAY, HOW TO PLAY and
  SETTINGS. SHOP, RECORDS and ENDLESS arrive after the first run, DAILY
  after the second, MODE once hard is open, LOCKER with characters on.
- A frame of frozen time when a boss falls or a vehicle forms. The wipe
  screen lists at most three new achievements and points to RECORDS for
  the rest. The locker fits a phone screen edge to edge.

## 0.20 (polish turn 3: the convoy, part two)

The convoy grows up: two more vehicles, veteran ranks, convoy perks.

- HELICOPTER (120 soldiers, from level 3): hovers above the squad, picks
  its own targets (thieves first, then runners and latchers), chews on
  clingers from above, and nothing on the ground can touch it. Lightning
  can.
- MECH (250 soldiers, from level 4): walks out front burning a laser
  through three zombies at a time.
- Veteran ranks: 25, 75 and 150 kills earn a vehicle a rank, each one
  +15% fire and +20% health, healed to full, with a gold stripe and a
  banner. Kills by a vehicle's own bullets and shells count.
- Convoy perks on perk gates once you own a vehicle: PLATING (vehicles
  take 40% less) and OVERDRIVE (vehicles fire 30% faster, twice).
- Fixed in passing: a shell from a tank wrecked while the shell was in
  the air could not burst.

## 0.19 (polish turn 2: the convoy, part one)

Soldiers can become vehicles.

- Once the squad is big enough (1.6 times the price), a gate may offer
  an olive panel in place of its worst one: JEEP -20 or TANK -60. Walk
  through and that many soldiers climb aboard. Never on a level's
  opener, at most one per gate, and only while there is room: two jeeps,
  one tank (from level 2).
- A JEEP rides the flank with a mounted gun: fast, straight, through two
  zombies at a time, leaning toward whatever you are aiming at. A TANK
  leads up the middle firing shells that burst on the first thing in
  their path, hitting a crowd at once and the boss at half.
- Vehicles have health bars. Brutes, tanks, boss chews, the horde and
  lightning damage them; a wrecked one is gone with a bang. They ride on
  from level to level while the soldiers reset, and each one still
  rolling at the boss pays 100 points.
- RECORDS counts vehicles formed; two new achievements. The help page
  has a CONVOY section. The auto-player takes a vehicle when it can
  afford to keep enough bodies.

## 0.18 (polish turn 1: honest road)

The first of six turns taking the game from pieced-together to one
design. This one makes three hollow things real.

- The fork has no words. Each side has a sign: one to four skull marks
  for how heavy its wave is, and a number for roughly how many soldiers
  the route takes, worked out from the actual wave. The heavier side
  pays better panels. Sides vary, and from level 3 sometimes neither is
  gentle. The banner on committing says what you walked into, not a
  label.
- Formation width does something. TIGHT is a focused column: less than
  half the spray, bullets land where you point, the squad fits a storm
  gap and takes fewer lightning hits. WIDE is a fan: nearly double the
  spray, the outer soldiers cover the sides of the road. The button
  says so.
- The shop costs about four times more and every upgrade can be felt:
  recruits +2 soldiers per level, firepower +12%, gate bonus +2, armor
  -12% on every heavy bite (brutes, boss, spit, lightning, horde), coin
  magnet +20%. Two new ones: BOMB BELT (start every run with bombs) and
  SECOND WIND (once a run, a wipe becomes a comeback with 8 soldiers, a
  shield and the clingers shaken off). Every row shows what it does now
  and what the next level does.
- Auto-player reads the fork signs and takes `--smoke-upgrades` to play
  with everything maxed.

## 0.17 (run 13)

How to play, records, achievements, and the storm.

- HOW TO PLAY on the title and in the pause menu: a plain-words page on
  controls, panels and their colours, shooting panels, levels, zombies,
  bosses, power-ups, combos and grades, coins and the shop, stars and
  the locker, modes, squads and records. Its numbers are read from the
  game's own constants, and a test checks it names every power-up, mode
  and panel colour, so it cannot quietly go stale.
- RECORDS: lifetime numbers (runs, kills, bosses, gates, perfect gates,
  distance, best combo, best levels, S grades, bets, dailies, weeklies,
  coins and stars) and 26 achievements that each pay stars once. New
  ones show on the wipe screen.
- A third boss, THE STORM, on every third level: it hangs back and calls
  lightning in lines across the whole road with one gap. Enraged, a
  second line follows with a different gap. Walker, spitter, storm,
  round and round.
- The auto-player now looks for the safe spot in a volley instead of
  dashing blindly sideways.

## 0.16 (cleanup and QA)

No new features. A review pass over the whole game, and the bugs it found.

- Fixed: a dash late in one run left the next run invulnerable, and
  unable to dash, for as long as the first run had lasted. Run clocks
  now reset with the squad.
- Fixed: a bet rode on the wrong wave (two waves on, or a flanker pack).
  Bets now settle on the wave that follows the gate, both halves of it
  at a fork, and a pending bet dies with the level.
- Fixed: a daily run was being saved as the endless high score. Daily
  and weekly runs now only count toward the run total.
- Fixed: retrying after a run that widened the road played a "2 LANES"
  banner, a chime and a camera glide at the start of the next run.
- Fixed: boss adds on four- and five-lane roads could not reach a squad
  parked wide. Bullets still in the air after a wipe no longer score
  kills, grades or a boss clear over the wipe screen.
- Fixed: after a daily or weekly the title squad kept rifles while the
  button said shotguns or medics.
- Long HUD text wraps instead of running off a phone screen.
- First launch no longer logs an error for the save file it has not
  written yet. The title and wipe screens take one record each instead
  of a dozen positional arguments. Stale comments about two-panel gates
  updated. The auto-player takes a bet when it can afford to, so that
  path runs in CI, and logs how it went.

## 0.15 (run 12)

The weekly, scouts, and a hero with something to say.

- WEEKLY on the daily card: one road for everyone all week, on hard, no
  upgrades, rifles. Best of the week counts, pays two extra stars, and
  copies as its own share line.
- Scout panels, amber, from level 2 on three lanes or more: pay a few
  soldiers and the next three gates show every panel the moment they
  appear, hidden ones included. Shooting a scout panel makes it cheaper.
- In character mode the hero says their line as a run starts and shouts
  something fitting on each level clear, by grade.
- The locker preview turns when you drag it.
- Auto-player takes `--weekly`.

## 0.14 (run 11)

Modes, grades, deals, flankers and the horde.

- MODE on the title: NORMAL, HARD (reach level 3) and NIGHTMARE (reach
  level 4 on hard). Hard throws 35% more zombies with 25% more health,
  bosses at 1.4x, bites at 1.3x, an extra lightning bolt, for 1.5x score
  and coins and a bonus star. Nightmare: 1.6x waves, 1.35x health, 1.8x
  bosses, 1.45x bites, 2.5x score and coins, two bonus stars. The threat
  ramps in over the first three levels so level 1 is harder, not
  hopeless. Each mode keeps its own bests. The daily is always normal.
- Level grades S to D on the clear banner: perfect gates, soldiers kept,
  boss time. S pays 600, A 350, B 150, C 50. Grades show on the wipe
  screen and in the share text.
- Deals in the extra lanes, amber: trades from level 3 (pay 15 to 30% of
  the squad for a shield, bomb, frenzy or slow, now; shooting a trade
  makes it cheaper) and bets from level 4 (walk through, clear the next
  wave without a bite and the squad doubles; a bite or a leak halves it).
  One deal per gate at most, never on a road under four lanes.
- Flankers from level 4 on four-lane roads: runners that come over the
  curbs beside you when a gate passes.
- The horde behind: from level 4 (level 2 on hard, level 1 on nightmare)
  a wall of zombies creeps up while the road is stopped for a boss. Kill
  the boss in about twelve seconds or it starts eating. It falls back
  when the boss dies.
- Auto-player takes `--hard` and `--nightmare`; prints a grade per level.
- Balance, bot, no upgrades: normal wiped on levels 6, 7, 7, 9; hard on
  4 and 5; nightmare on 2, 3, 3.

## 0.13 (run 10.3)

Cuter characters.

- Soldiers rebuilt as round, big-headed little people: smooth spheres and
  capsules instead of boxes, soft wrapped lighting with a little sheen,
  big eyes with a catchlight, pink cheeks, a smile, rounded shoes, a belt
  with a buckle, stubby arms on a smaller gun. Hair, hats and backs
  resized to the new head. The locker preview is bigger.

## 0.12 (run 10.2)

Characters, pass 2.

- CREW tab in the locker: matching (default), rainbow tops, shadow greys,
  no hats, or twins of the hero. Two more hats (bunny ears, chef) and two
  more backs (a bobbing balloon, a turtle shell).
- The squad cheers on a level clear, when the hero steps out of the
  locker, and on the wipe screen in character mode. Buying or wearing
  something makes the locker preview jump.
- The daily pays one extra star. After a run, the wipe screen says when
  something in the locker has become affordable.

## 0.11 (run 10.1)

Characters, pass 1: people worth keeping alive. And clingers you can
actually fight.

- Fixed: zombies clinging to the squad's flanks could not be shot. They
  ride beside the squad, deep in the steering zone, so "hold on it"
  never reached them. Now a touch anywhere within reach of a clinger aims
  at it and sticks until it dies. Clingers wear a pulsing red ring.
  Clinging starts on level 2 alongside the dash, so there is always a way
  to shake one.
- Settings (title screen and pause) with a CHARACTERS switch. On, the
  title gets a LOCKER: eight heroes with names and faces, eight outfits,
  eleven hats, six weapon skins, six backs (capes, wings, a jetpack).
  Items cost stars; stars come from bosses, perfect gates and finishing
  runs. The hero leads the squad with a name tag; the crew wear the same
  outfit, hat, weapon and back with their own faces. The hero always
  escapes: the wipe screen says who got out.
- Soldiers rebuilt: boots, belts, eyes, hair, chest plate, recoil. The
  classic kit is unchanged in spirit (helmet, visor, pack) with better
  bones under it.
- Level 1 hint teaches gates; level 2 teaches clingers and sums.
- Balance, bot with no upgrades, eight seeds: wiped on levels 2, 4, 4,
  5, 5, 7, 8, 9 (median 5).

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
