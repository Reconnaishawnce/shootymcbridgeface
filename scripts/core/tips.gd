class_name Tips
extends RefCounted
## One tip for the wipe screen, picked from how the run ended. Pure.
## Context keys: level, in_boss (bool), boss_kind, count_at_boss, peak,
## kills, formation, bombs_left, had_vehicles, bites_heavy, straight_used.


static func for_wipe(c: Dictionary) -> String:
	var level := int(c.get("level", 1))
	if bool(c.get("in_boss", false)):
		match str(c.get("boss_kind", "walker")):
			"spitter":
				return "The spitter only hits inside the red ring. Watch the glob's shadow and step out before it lands."
			"storm":
				return "The storm leaves one gap in every line. Go TIGHT, find the gap, and dash through it."
			"foreman":
				return "The foreman's saws come down your lane. Dash sideways as they arrive, and grab the crates it drops."
		if int(c.get("count_at_boss", 0)) < 20:
			return "You met the boss with a small squad. Shoot the blue panels up before walking through, and hold STRAIGHT fire on the core."
		return "Hold a finger on the road to aim every gun at the boss's glowing core: it takes triple damage. Dash out of the red rings."
	if int(c.get("bombs_left", 0)) > 0:
		return "You died with a bomb in the belt. Throw it at a brute, a tank or the boss: it aims itself at the heaviest thing in reach."
	if int(c.get("peak", 1)) >= 60 and int(c.get("kills", 0)) < 150:
		return "A big squad is health, not firepower. Go WIDE to mow the crowd, and STRAIGHT when a brute lines up."
	if not bool(c.get("straight_used", false)) and level >= 2:
		return "Try STRAIGHT fire on the formation button: everything out of the middle, harder and through one more body."
	if not bool(c.get("had_vehicles", false)) and level >= 3:
		return "An olive JEEP panel turns twenty soldiers into a gun that rides with you from level to level."
	if int(c.get("bites_heavy", 0)) >= 4:
		return "Heavy bites are the killer. Dash through a brute as it reaches you, or buy FLAK JACKETS at the next pit stop."
	return "Shoot a red panel long enough and it turns blue. Bullets spent on panels never reach the zombies, so pick your moment."
