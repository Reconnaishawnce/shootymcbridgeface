class_name Goals
extends RefCounted
## The one thing to do next, and which title buttons a player has earned.
## Pure: the game hands in a context dictionary.
##
## Context keys: runs, best_level, hard_best_level, coins, cheapest (name),
## cheapest_cost, vehicles, modifier, character_mode, affordable_item,
## daily_played, best_score, trophies, hard_open, trophies_to_next,
## quests_left.


static func next(c: Dictionary) -> String:
	var runs := int(c.get("runs", 0))
	var best_level := int(c.get("best_level", 0))
	if runs == 0:
		return "Play a run. Every level starts with one soldier."
	var trophies := int(c.get("trophies", 0))
	if c.has("trophies") and not bool(c.get("hard_open", false)):
		var target: int = Road.UNLOCKS["endless"] if trophies < int(Road.UNLOCKS["endless"]) else Road.UNLOCKS["hard"]
		return "%d trophies open %s on the ROAD (you have %d)." % [target, "ENDLESS" if target == int(Road.UNLOCKS["endless"]) else "HARD", trophies]
	if not c.has("trophies") and best_level < Modifiers.HARD_UNLOCK_LEVEL:
		return "Reach level %d to open ENDLESS and HARD (best so far: %d)." % [Modifiers.HARD_UNLOCK_LEVEL, maxi(best_level, 1)]
	var coins := int(c.get("coins", 0))
	var cheapest := str(c.get("cheapest", ""))
	var cost := int(c.get("cheapest_cost", 0))
	if cheapest != "" and coins >= cost and cost > 0:
		return "You can afford %s in the SHOP (%d coins)." % [cheapest, cost]
	if int(c.get("vehicles", 0)) == 0:
		return "Form a JEEP: reach %d soldiers and take the olive panel." % int(ceil(float(Convoy.cost("jeep")) * Convoy.OFFER_MARGIN))
	if bool(c.get("character_mode", false)) and bool(c.get("affordable_item", false)):
		return "Something new is waiting in the LOCKER."
	if str(c.get("modifier", "normal")) == "normal" and int(c.get("hard_best_level", 0)) < Modifiers.NIGHTMARE_UNLOCK_LEVEL:
		return "Try HARD mode: 1.5x score and coins, and it opens NIGHTMARE."
	var to_next := int(c.get("trophies_to_next", 0))
	if to_next > 0 and to_next <= 40:
		return "%d trophies to the next milestone on the ROAD." % to_next
	if int(c.get("quests_left", 0)) > 0:
		return "%d of today's QUESTS still open." % int(c.get("quests_left", 0))
	if not bool(c.get("daily_played", false)):
		return "Play today's DAILY: same road as everyone, best of the day counts."
	if cheapest != "" and cost > 0:
		return "Save for %s: %d of %d coins." % [cheapest, coins, cost]
	return "Beat your best: %d." % int(c.get("best_score", 0))


## Which title buttons show. New players see PLAY and little else; the
## rest arrives as it becomes useful.
static func title_buttons(runs: int, hard_unlocked: bool, character_mode: bool) -> Dictionary:
	return {
		"shop": runs >= 1,
		"daily": runs >= 2,
		"records": runs >= 1,
		"mode": hard_unlocked,
		"locker": character_mode,
		"endless": runs >= 1,
		"hints": runs >= 1,
		"quests": runs >= 1,
		"weekly": runs >= 2,
		"road": runs >= 1,
	}
