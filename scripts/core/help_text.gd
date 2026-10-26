class_name HelpText
extends RefCounted
## The in-game HELP page: how the game works, in plain words. Numbers are
## read from the real constants so the page cannot drift from the rules.
##
## RULE: any change to game mechanics updates this file in the same
## commit. See CLAUDE.md.


static func sections() -> Array:
	var hats := Wardrobe.items_in("hat").size()
	var heroes := Wardrobe.items_in("hero").size()
	return [
		{"title": "THE IDEA", "body":
			"You lead a squad of little soldiers down a road full of zombies. " +
			"The road scrolls on its own. You steer left and right, pick which gate panel to walk through, and aim your guns. " +
			"More soldiers means more bullets. Lose them all and the run is over."},
		{"title": "CONTROLS", "body":
			"Low on the screen, near the squad: drag left or right to steer, drag up or down to spread out or bunch up, and flick hard sideways to dash (from level %d). " % Progression.DASH_LEVEL +
			"Higher up, on the road: hold a finger there and every gun aims at that spot with a red laser. Lift to go back to firing straight ahead. " +
			"The button at the bottom right cycles TIGHT, NORMAL and WIDE. Tight is a focused column: bullets land where you point, the squad fits through gaps and takes fewer lightning hits. " +
			"Wide is a fan: the outer soldiers cover the sides of the road, but your fire is scattered. Tap a zombie that is clinging to your squad to shoot it off."},
		{"title": "GATES AND PANELS", "body":
			"Every gate is a row of panels, one per lane. You walk through exactly one.\n" +
			"BLUE panels add soldiers (+5) or multiply them (x2).\n" +
			"RED panels take soldiers away (-6) or halve them.\n" +
			"TEAL panels are sums like +3 x2, worked out left to right. +3 x2 is not the same as x2 +3. Do the maths, then pick.\n" +
			"PURPLE panels hand you a power-up.\n" +
			"AMBER panels are deals: a trade (pay soldiers now for a power-up now), a bet (double your squad if you clear the next wave with no bites, half if you do not), or scouts (pay a few soldiers and the next %d gates show every panel).\n" % GateMath.SCOUT_GATES +
			"OLIVE panels turn soldiers into a vehicle (see THE CONVOY).\n" +
			"GREY panels with a ? are hidden until you get close or shoot them."},
		{"title": "SHOOT THE PANELS", "body":
			"Your bullets hit the panels too. Every bit of fire steps a panel up: a +2 becomes a +3, a x2 becomes x2.5, a trade gets cheaper. " +
			"Shoot a panel up at least %d steps before you walk through it and you get a PERFECT worth %d points. " % [Difficulty.PERFECT_STEPS, Difficulty.PERFECT_BONUS] +
			"From level %d some panels flash white: hits during the flash count triple. " % Progression.HOT_LEVEL +
			"But bullets spent on panels are bullets not spent on zombies. That is the whole game."},
		{"title": "LEVELS", "body":
			"A level is %d gates and a boss. The road widens as you go, from two lanes up to %d, so later gates have more panels to read. " % [Difficulty.GATES_PER_LEVEL, Progression.MAX_LANES] +
			"The third and sixth gate of every level is a PERK gate: three purple panels, pick one, it lasts the run. " +
			"Once per level the road forks. Each side has a sign: red skull marks for how heavy its zombie wave is, and a number for roughly how many soldiers it takes. " +
			"The heavier side pays better panels. Read both and pick. " +
			"When you beat the boss, %d%% of your survivors carry over and the rest reset, so every level starts small and grows."
				% int(Difficulty.CARRY_OVER_FRACTION * 100.0)},
		{"title": "THE CONVOY", "body":
			"Soldiers can become vehicles. Once your squad is big enough, a gate offers an olive panel like JEEP -%d: walk through it and that many soldiers climb aboard. " % Convoy.cost("jeep") +
			"A JEEP (%d soldiers, up to %d) rides on your flank with a mounted gun: fast, straight, through two zombies at a time. " % [Convoy.cost("jeep"), int(Convoy.spec("jeep").max)] +
			"A TANK (%d soldiers, from level %d) leads up the middle firing shells that burst on a crowd. " % [Convoy.cost("tank"), int(Convoy.spec("tank").level)] +
			"Vehicles have their own health bar: brutes, boss chews and lightning damage them, and a wrecked one is gone. " +
			"But they stay with you from level to level while the soldiers reset, and each one still rolling at the boss pays %d points. Fewer bodies now, a convoy later." % Convoy.LEVEL_BONUS_PER_VEHICLE},
		{"title": "ZOMBIES", "body":
			"Walkers shamble at you. Runners are fast and thin and find you. Brutes are big, soak a lot of fire, and take a slice of the squad when they reach you. " +
			"Tanks are bullet sponges that shield whatever is behind them. Thieves sprint for the next gate and knock its number down, so shoot them first. " +
			"Purple latchers, and from level %d any walker or runner that reaches you, cling to your flanks and eat a soldier every so often until you tap them or dash. " % Progression.CLING_LEVEL +
			"On wide roads, flankers hop the curbs beside you. " +
			"Zombies that get past you without being killed break your wave streak."},
		{"title": "BOSSES", "body":
			"At the end of every level the road slows and the boss comes. The WALKER marches up and chews your squad once it arrives. " +
			"The SPITTER hangs back and lobs spit that you have to step out of. The STORM hangs back and calls lightning in lines across the whole road with one gap: find the gap. " +
			"All of them drop red rings that turn into lightning bolts, call runners, and get angrier below half health. " +
			"Hit the glowing yellow core for triple damage. Kill the boss fast: from level %d a horde creeps up behind you while the road is stopped, and eats if it arrives." % int(Modifiers.get_value("normal", "horde_level"))},
		{"title": "POWER-UPS", "body":
			"BOMB: tap the bomb button to throw one; big blast, kills most things in it.\n" +
			"SLOW-MO: the road and the zombies slow down for a while.\n" +
			"SHIELD: nothing bites you until it runs out.\n" +
			"FRENZY: your guns fire much faster.\n" +
			"MYSTERY: one of the above, you find out when you grab it.\n" +
			"They come from purple panels, from crates on the road, and from trades."},
		{"title": "COMBOS AND SCORE", "body":
			"Kills within %.1f seconds of each other chain into a combo. Every %d kills in a chain raises the multiplier, up to x%.0f. " % [Combo.WINDOW, Combo.STEP, Combo.MAX_MULT] +
			"Score is mostly distance, plus kills times the multiplier, PERFECT gates, cleared waves, and a bonus for each boss. " +
			"Every level you clear gets a GRADE from S to D for perfect gates, soldiers kept and how fast the boss went down. S pays %d points, down to nothing for a D." % Grades.bonus("S")},
		{"title": "COINS AND THE SHOP", "body":
			"Every run pays coins: one for every four kills, %d per boss, %d per gate. " % [25, 2] +
			"The SHOP sells permanent upgrades, and each one tells you what it does now and what the next level does: more soldiers at every level start, harder-hitting bullets, extra soldiers on every blue gate, armor against brutes, bosses and lightning, bombs at the start of a run, a SECOND WIND that turns one wipe per run into a comeback with %d soldiers, extra boss core damage, more coins, earlier hidden-panel reveals, and the shotgun and medic squads. " % Meta.SECOND_WIND_SOLDIERS +
			"Each upgrade costs more every time you buy it. The daily and the weekly pay no coins and use no upgrades."},
		{"title": "STARS AND THE LOCKER", "body":
			"Stars are the other currency. A run pays one star per boss, one per four perfect gates, and one for getting through at least three gates. " +
			"The daily pays one extra, the weekly two, and hard and nightmare pay bonus stars. Achievements pay stars too. " +
			"Turn CHARACTERS on in Settings and the LOCKER opens: %d heroes, outfits, %d hats, weapon skins, backs and crew styles, all bought with stars. " % [heroes, hats] +
			"Your hero leads the squad with a name tag, and always escapes."},
		{"title": "MODES", "body":
			"NORMAL is the road as it comes. HARD opens once you reach level %d: bigger waves, meaner bosses, 1.5x score and coins. " % Modifiers.HARD_UNLOCK_LEVEL +
			"NIGHTMARE opens once you reach level %d on hard: everything at once, 2.5x score and coins. Each mode keeps its own best.\n" % Modifiers.NIGHTMARE_UNLOCK_LEVEL +
			"ENDLESS opens once you clear level %d: no bosses, no reset, the road just keeps getting harder.\n" % Meta.ENDLESS_UNLOCK_LEVEL +
			"DAILY: the same road for everyone today, no upgrades, rifles only. Best of the day counts and you can copy your result to share.\n" +
			"WEEKLY: the same road for everyone all week, on hard, no upgrades."},
		{"title": "SQUADS", "body":
			"RIFLES are balanced. SHOTGUNS fire three pellets with more damage but shorter reach. MEDICS do a little less damage and slowly revive soldiers. " +
			"Only the front %d soldiers' worth of guns count toward firepower; past that, a bigger squad is extra health, not extra damage." % Progression.DPS_CAP_SOLDIERS},
		{"title": "RECORDS", "body":
			"The RECORDS page keeps your lifetime numbers and your achievements. Each achievement pays stars once, the moment you earn it."},
	]
