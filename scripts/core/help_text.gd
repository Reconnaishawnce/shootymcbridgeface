class_name HelpText
extends RefCounted
## The in-game HOW TO PLAY page: how the game works, in plain words.
## Numbers are read from the real constants so the page cannot drift
## from the rules.
##
## RULE: any change to game mechanics updates this file in the same
## commit. See CLAUDE.md.
##
## 0.63: the page went from thirty-eight sections to sixteen, because the
## game went from thirty-three mechanics to a ladder of twelve. A section
## is a few short sentences; tests/test_run13.gd counts the words.

## The longest a section's body may be, in words.
const MAX_SECTION_WORDS := 110


static func sections() -> Array:
	var powers := []
	for id in Powerups.ORDER:
		powers.append("%s: %s" % [Powerups.title(id), Powerups.description(id)])
	var cards := []
	for id in Cards.ORDER:
		cards.append("%s: %s." % [Cards.title(id), Cards.description(id)])
	var combos := []
	for id in Cards.COMBO_ORDER:
		combos.append(Cards.combo_title(id))
	var pit := []
	for id in PitStop.ORDER:
		pit.append(PitStop.title(id))
	var places := []
	for id in Themes.ORDER:
		if Themes.rule(id) != "":
			places.append("%s: %s" % [Themes.title(id), Themes.rule(id)])
	var out := [
		{"title": "THE IDEA", "body":
			"You lead a squad down a bridge full of zombies. The road moves on its own and your soldiers shoot on their own. " +
			"You steer, pick gates that grow the squad, and beat the boss at the end of each level. " +
			"More soldiers means more bullets. Lose them all and the run is over."},
		{"title": "CONTROLS", "body":
			"DRAG left and right to move.\n" +
			"HOLD a finger on the road and every gun aims there.\n" +
			"TAP a zombie that has grabbed your squad to shoot it off, or SHAKE the phone to throw them all off (from level %d).\n" % Progression.CLING_LEVEL +
			"FLICK sideways to dash through danger (from level %d).\n" % Progression.DASH_LEVEL +
			"The button at the bottom left is your hero move. BOMB appears under it when you carry one."},
		{"title": "GATES", "body":
			"Every gate has one panel per lane. Walk through the one you want.\n" +
			"BLUE adds soldiers (+5) or, from level %d, multiplies them (x2).\n" % Progression.MUL_LEVEL +
			"RED takes soldiers away.\n" +
			"PURPLE gives a power-up, named on the panel (from level %d).\n" % Progression.POWER_PANEL_LEVEL +
			"OLIVE trades soldiers for a vehicle that fights beside you (from level %d).\n" % Progression.VEHICLE_LEVEL +
			"Your bullets push a panel's number up while you aim at it. Push one up %d steps before you walk through and it is a PERFECT." % Difficulty.PERFECT_STEPS},
		{"title": "LEVELS", "body":
			"A level is %d gates and a boss. Level 1 is slow on purpose: two lanes, plain numbers, and every bullet kills a zombie. " % Difficulty.GATES_PER_LEVEL +
			"Each level after that is a little faster, with faster bullets and more of them, and brings one new thing. " +
			"The road slows down for a gate worth thinking about (a multiplier or a power-up), then speeds up again."},
		{"title": "WHAT ARRIVES WHEN", "body":
			"Level %d: x2 gates, power-up boxes, big brutes.\n" % Progression.MUL_LEVEL +
			"Level %d: zombies that grab on, and the dash.\n" % Progression.CLING_LEVEL +
			"Level %d: the pit stop, and fast runners.\n" % Progression.PIT_LEVEL +
			"Level %d: saw blades.\n" % Progression.SAW_LEVEL +
			"Level %d: purple grabbers.\n" % Progression.LATCHER_LEVEL +
			"Level %d: walls.\n" % Progression.BARRICADE_LEVEL +
			"Level %d: thieves.\n" % Progression.THIEF_LEVEL +
			"Level %d: tanks.\n" % Progression.TANK_LEVEL +
			"Level %d: yellow splitters.\n" % Progression.SPLITTER_LEVEL +
			"Level %d: vehicles."  % Progression.VEHICLE_LEVEL},
		{"title": "ZOMBIES", "body":
			"A walker that reaches you takes a soldier. You cannot walk past them: one you do not shoot turns round and runs you down. " +
			"BRUTES and TANKS are the exception. They are big and slow and take a bite out of the whole squad, so step round them.\n" +
			"Purple ones grab on and keep eating: tap them or shake. Thieves run at the next gate and shrink its number. " +
			"Yellow splitters burst into %d runners when they die, so kill them far away." % Difficulty.SPLIT_INTO},
		{"title": "BOSSES", "body":
			"The first boss only walks at you. From level %d they throw things, and everything they throw can be dodged.\n" % Progression.BOSS_ATTACK_LEVEL +
			"GREEN and PURPLE globs: watch the shadow, step out of the red ring.\n" +
			"ORANGE BOMBS: a much bigger ring. Move early.\n" +
			"SAW BLADES roll down your lane: step aside.\n" +
			"LIGHTNING: a red ring fills, then the bolt lands. The STORM boss (from level %d) draws a line of bolts with one gap.\n" % Difficulty.STORM_BOSS_LEVEL +
			"Shoot the glowing core for x%d damage." % int(Boss.CORE_MULT)},
		{"title": "POWER-UPS", "body":
			"Boxes on the road (from level %d) and purple panels hand them out. A box with a ? is a surprise.\n" % Progression.CRATE_LEVEL +
			"\n".join(powers)},
		{"title": "PIT STOP", "body":
			"From level %d there is a pit stop once a level. A lit sign over the road says PIT STOP with an arrow: steer right, onto the yellow lane. " % Progression.PIT_LEVEL +
			"The road waits while you spend this run's coins on %s. What you buy lasts until the run ends." % ", ".join(pit).to_lower()},
		{"title": "BUILD CARDS", "body":
			"After every boss from the second, pick one of three cards. It is yours for the run. COMMON, RARE and EPIC say how often a card turns up.\n" +
			"\n".join(cards) + "\n" +
			"Some pairs make a COMBO: %s." % ", ".join(combos)},
		{"title": "GETTING HARDER", "body":
			"The road gets faster up to level 10 and keeps creeping up after. From level %d every bite also grows, every level, and armor never takes more than %d%% off one. " % [Difficulty.DANGER_FROM + 1, int(round((1.0 - Difficulty.MITIGATION_FLOOR) * 100.0))] +
			"Nobody is unbeatable: sooner or later the road wins, and how far you got is the score.\n" +
			"Stop steering (from level %d) and the zombies behind you catch up." % Difficulty.HANDS_OFF_HORDE_LEVEL},
		{"title": "PLACES", "body":
			"Levels change place: the sky, the light, the weather. From level %d each place also has a rule.\n" % Progression.THEME_RULE_LEVEL +
			"\n".join(places)},
		{"title": "COINS, STARS AND CHESTS", "body":
			"Every kill pays coins. Spend them in a run at the pit stop, or take what is left home to the SHOP for upgrades that last. " +
			"When an upgrade is MAXED, ENLIST keeps buying a little more of it, and each tier adds one whole soldier or one whole percent.\n" +
			"Stars come from bosses and achievements and buy looks and heroes in the LOCKER.\n" +
			"QUESTS, the TROPHY ROAD and the season pay in chests: QUEST CHEST, ROAD CHEST, GOLD CHEST. Open them from the home screen."},
		{"title": "HEROES AND SQUADS", "body":
			"The hero leads the squad and changes one rule. " + _heroes() + "\n" +
			"Squads have a hero move on the bottom-left button: RIFLES fire a %s, SHOTGUNS a %s, MEDICS a %s, SNIPERS a %s." % [Abilities.title("volley"), Abilities.title("shockwave"), Abilities.title("heal"), Abilities.title("longshot")]},
		{"title": "MODES", "body":
			"PLAY is a normal run through the levels. MODES on the home screen has the rest.\n" +
			"ENDLESS: no bosses, no end.\n" +
			"DAILY: one road a day, the same for everyone.\n" +
			"WEEKLY: a week-long road with its own twist.\n" +
			"BOSS RUSH: one gate, then a boss, again and again.\n" +
			"HARD and NIGHTMARE are tougher roads that pay more. They open on the TROPHY ROAD at %d and %d trophies.\n" % [int(Road.UNLOCKS["hard"]), int(Road.UNLOCKS["nightmare"])] +
			"Wiped out? Once a run you can RALLY: %d soldiers back for a few stars." % Revive.SOLDIERS},
		{"title": "IF IT FREEZES OR SLOWS DOWN", "body":
			"On the home screen or the pause menu, SHAKE the phone and a card asks what went wrong. REPORT A PROBLEM under MORE does the same. " +
			"In a run a shake throws zombies off instead.\n" +
			"With SEND REPORTS on in SETTINGS, freezes and slow stretches under %d frames a second report themselves, never with your name. " % int(Telemetry.SLOW_FPS) +
			"LOGGING in SETTINGS sends the game's FLIGHT RECORDER as you play, for a phone that keeps having trouble.\n" +
			"SETTINGS also has SOUND, MUSIC, HAPTICS, SHADOWS and SAFE GRAPHICS."},
	]
	return out


## One short line a hero, from the same text the locker shows.
static func _heroes() -> String:
	var lines := []
	for id in Heroes.ORDER:
		lines.append("%s: %s." % [Wardrobe.title(id), Heroes.short(id)])
	return " ".join(lines)
