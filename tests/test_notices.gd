extends TestCase
## 0.63: what the road says, what the bosses throw, and what a zombie
## does when you try to walk past it.


func test_silence_is_the_default() -> void:
	check(not Notices.shows(Notices.CHATTER, 0.0) and not Notices.shows(Notices.CHATTER, 1000.0), "chatter is never shown, however quiet it has been")
	check(Notices.shows(Notices.MUST, 0.0), "what must be read always is")
	check(not Notices.shows(Notices.NICE, Notices.NICE_GAP - 0.1), "a nice-to-know waits for a quiet moment")
	check(Notices.shows(Notices.NICE, Notices.NICE_GAP), "and then shows")
	check(Notices.banner_shows(Notices.MUST, 0.0, true), "a banner that must be read replaces another")
	check(not Notices.banner_shows(Notices.NICE, 100.0, true), "a lesser one does not push it off the screen")
	check(Notices.banner_shows(Notices.NICE, 100.0, false), "but shows once it is gone")
	check(not Notices.banner_shows(Notices.CHATTER, 100.0, false), "and chatter still never does")
	check_eq(Notices.words("PIT STOP AHEAD\nSTEER RIGHT"), 5, "words are counted across both lines")
	check_eq(Notices.words(""), 0, "nothing is no words")
	check(Notices.MAX_WORDS <= 8, "a line on the road is short")


## Bosses throw things you can watch and step round.
func test_what_bosses_throw() -> void:
	var seen := {}
	for n in range(Difficulty.LOB_CYCLE.size() * 3):
		var kind := Difficulty.lob_kind(n)
		seen[kind] = int(seen.get(kind, 0)) + 1
		check(Spit.COLORS.has(kind) and Difficulty.LOB_SPLASH.has(kind) and Difficulty.LOB_BITE_MULT.has(kind), "every lob has a colour, a reach and a bite: %s" % kind)
	check(seen.has("glob") and seen.has("purple") and seen.has("bomb"), "green globs, purple globs and bombs")
	check(int(seen["bomb"]) < int(seen["glob"]), "bombs are the rare one")
	check(float(Difficulty.LOB_SPLASH["bomb"]) > float(Difficulty.LOB_SPLASH["glob"]) * 2.0, "a bomb lands much wider than a glob")
	check(float(Difficulty.LOB_BITE_MULT["bomb"]) > 1.0, "and bites harder")
	check(float(Spit.SPEEDS["bomb"]) < float(Spit.SPEEDS["glob"]), "but flies slower: there is time to move")
	check(Spit.COLORS["glob"] != Spit.COLORS["purple"] and Spit.COLORS["purple"] != Spit.COLORS["bomb"], "three colours you can tell apart")
	check(Difficulty.LOB_INTERVAL_ENRAGED < Difficulty.LOB_INTERVAL, "an angry boss throws faster")
	check(not Difficulty.lob_is_saw(Difficulty.LOB_SAW_AT, false, 20), "a calm boss throws no saws")
	check(Difficulty.lob_is_saw(Difficulty.LOB_SAW_AT, true, Progression.SAW_LEVEL), "an angry one does")
	check(not Difficulty.lob_is_saw(Difficulty.LOB_SAW_AT, true, Progression.SAW_LEVEL - 1), "but not before saws exist")
	# A quarter less lightning than 0.62 (3.2 s and 2.0 s; the storm 3.4 and 2.4).
	check(Difficulty.STRIKE_INTERVAL >= 3.2 / 0.76 and Difficulty.STRIKE_INTERVAL_ENRAGED >= 2.0 / 0.76, "boss lightning lands a quarter less often")
	check(Difficulty.STORM_INTERVAL >= 3.4 / 0.76 and Difficulty.STORM_INTERVAL_ENRAGED >= 2.4 / 0.76, "and so do the storm's lines")
	check(Themes.STRIKE_INTERVAL >= 6.0 / 0.76, "and the storm front's")
	check(Difficulty.LOB_INTERVAL < Difficulty.STRIKE_INTERVAL, "there is more in the air than in the sky")
	var sp := Spit.new("bomb")
	check_eq(sp.kind, "bomb", "a bomb is a bomb")
	check_near(sp.splash, float(Difficulty.LOB_SPLASH["bomb"]), 0.0001, "with a bomb's reach")
	sp.free()
	var odd := Spit.new("nonsense")
	check_eq(odd.kind, "glob", "nonsense is a glob")
	odd.free()
	Mats.clear()


## What you do not shoot, bites.
func test_no_walking_past() -> void:
	check_near(Difficulty.lunge_mult(Difficulty.LUNGE_RANGE + 1.0), 1.0, 0.0001, "far away a zombie only drifts toward you")
	check(Difficulty.lunge_mult(Difficulty.LUNGE_RANGE - 0.5) >= 3.0, "close, it lunges")
	check(Difficulty.lunge_mult(0.0) >= 3.0, "all the way in")
	# A walker's sideways speed in the lunge, against how far a squad can
	# slide in the time the last metres take on level 1.
	var seconds := Difficulty.LUNGE_RANGE / (Difficulty.world_speed(1) + 1.6)
	check(1.0 * Difficulty.LUNGE_MULT * seconds >= 3.0, "a level 1 walker covers a lane's width in its lunge (%.1f m)" % (1.0 * Difficulty.LUNGE_MULT * seconds))
	check(Difficulty.CHASE_SPEED > 5.0 and Difficulty.CHASE_SECONDS >= 1.5, "one that is passed runs the squad down")
	check(Difficulty.CHASE_SPEED * Difficulty.CHASE_SECONDS > Progression.road_half(Progression.MAX_LANES) * 2.0, "wherever on the road the squad went")
	check(Difficulty.CHASE_BEHIND > 0.0 and Difficulty.CHASE_BEHIND < 2.0, "from just behind the front rank")


## Shaking the phone in a run throws clingers off; it is a lighter
## shake than the one that asks for the report card.
func test_shake_to_throw_off() -> void:
	var quick := Shake.quick()
	var hard := Shake.new()
	check(quick.jolts_needed < hard.jolts_needed and quick.cooldown < hard.cooldown, "the in-run shake is lighter and ready sooner")
	var jolt := Vector3(0.0, Shake.GRAVITY + Shake.JOLT + 2.0, 0.0)
	var still := Vector3(0.0, Shake.GRAVITY, 0.0)
	check(not quick.feed(still, 0.0), "a phone at rest is not a shake")
	check(not quick.feed(jolt, 0.1), "one jolt is not a shake")
	check(quick.feed(jolt, 0.3), "two jolts are")
	check(not hard.feed(jolt, 0.1) and not hard.feed(jolt, 0.3), "but not for the report card")
	check(not quick.feed(jolt, 0.5) and not quick.feed(jolt, 0.7), "and not again straight away")
	check(not quick.feed(jolt, 0.3 + Shake.QUICK_COOLDOWN + 0.05), "after the cooldown a first jolt")
	check(quick.feed(jolt, 0.3 + Shake.QUICK_COOLDOWN + 0.25), "and a second throw them off again")
	check(Progression.MAX_LATCHED > Progression.DASH_SHAKES_OFF, "a shake clears more than a dash does")
