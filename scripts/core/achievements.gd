class_name Achievements
extends RefCounted
## Lifetime goals that pay stars. Each one watches a Stats key against a
## threshold. Pure: the game passes the stats in and the done-list out.

const CATALOG := [
	{"id": "blood_100", "title": "FIRST BLOOD", "desc": "Kill 100 zombies", "key": "kills", "at": 100, "stars": 1},
	{"id": "blood_1k", "title": "MOWER", "desc": "Kill 1,000 zombies", "key": "kills", "at": 1000, "stars": 2},
	{"id": "blood_10k", "title": "HARVESTER", "desc": "Kill 10,000 zombies", "key": "kills", "at": 10000, "stars": 5},
	{"id": "boss_1", "title": "BIG GAME", "desc": "Kill a boss", "key": "bosses", "at": 1, "stars": 1},
	{"id": "boss_10", "title": "BOSS HUNTER", "desc": "Kill 10 bosses", "key": "bosses", "at": 10, "stars": 2},
	{"id": "boss_50", "title": "BOSS FARMER", "desc": "Kill 50 bosses", "key": "bosses", "at": 50, "stars": 4},
	{"id": "gates_100", "title": "GATEKEEPER", "desc": "Pass 100 gates", "key": "gates", "at": 100, "stars": 1},
	{"id": "gates_1k", "title": "ROAD WARRIOR", "desc": "Pass 1,000 gates", "key": "gates", "at": 1000, "stars": 3},
	{"id": "perfect_25", "title": "SHARPSHOOTER", "desc": "25 perfect gates", "key": "perfect", "at": 25, "stars": 2},
	{"id": "perfect_200", "title": "MARKSMAN", "desc": "200 perfect gates", "key": "perfect", "at": 200, "stars": 4},
	{"id": "dist_10k", "title": "MARATHON", "desc": "Run 10 km in total", "key": "distance", "at": 10000, "stars": 2},
	{"id": "combo_100", "title": "CHAIN GANG", "desc": "A 100 combo", "key": "best_combo", "at": 100, "stars": 2},
	{"id": "combo_250", "title": "UNSTOPPABLE", "desc": "A 250 combo", "key": "best_combo", "at": 250, "stars": 4},
	{"id": "level_5", "title": "HALFWAY", "desc": "Reach level 5", "key": "best_level", "at": 5, "stars": 2},
	{"id": "level_10", "title": "DOUBLE DIGITS", "desc": "Reach level 10", "key": "best_level", "at": 10, "stars": 5},
	{"id": "endless_8", "title": "NO END IN SIGHT", "desc": "Reach level 8 in endless", "key": "endless_level", "at": 8, "stars": 3},
	{"id": "bet_1", "title": "HIGH ROLLER", "desc": "Win a bet", "key": "bets_won", "at": 1, "stars": 1},
	{"id": "bet_10", "title": "HOUSE ALWAYS LOSES", "desc": "Win 10 bets", "key": "bets_won", "at": 10, "stars": 3},
	{"id": "s_1", "title": "GOLD STAR", "desc": "Earn an S grade", "key": "s_grades", "at": 1, "stars": 1},
	{"id": "s_10", "title": "STRAIGHT S", "desc": "Earn 10 S grades", "key": "s_grades", "at": 10, "stars": 4},
	{"id": "daily_1", "title": "EARLY BIRD", "desc": "Play a daily", "key": "dailies", "at": 1, "stars": 1},
	{"id": "daily_7", "title": "REGULAR", "desc": "Play 7 dailies", "key": "dailies", "at": 7, "stars": 3},
	{"id": "weekly_1", "title": "WEEKENDER", "desc": "Play a weekly", "key": "weeklies", "at": 1, "stars": 1},
	{"id": "hard_5", "title": "HARD CASE", "desc": "Kill 5 bosses on hard", "key": "hard_bosses", "at": 5, "stars": 3},
	{"id": "nightmare_3", "title": "SLEEPLESS", "desc": "Kill 3 bosses on nightmare", "key": "nightmare_bosses", "at": 3, "stars": 5},
	{"id": "escape_10", "title": "SURVIVOR", "desc": "Escape 10 times with a hero", "key": "escapes", "at": 10, "stars": 2},
	{"id": "vehicle_1", "title": "WHEELS", "desc": "Form a vehicle", "key": "vehicles", "at": 1, "stars": 1},
	{"id": "vehicle_20", "title": "MOTOR POOL", "desc": "Form 20 vehicles", "key": "vehicles", "at": 20, "stars": 3},
]


static func find(id: String) -> Dictionary:
	for a in CATALOG:
		if a.id == id:
			return a
	return {}


static func is_done(a: Dictionary, stats: Dictionary) -> bool:
	return int(stats.get(a.key, 0)) >= int(a.at)


## Ids earned by [param stats] that are not in [param done] yet.
static func newly_done(stats: Dictionary, done: Array) -> Array:
	var out := []
	for a in CATALOG:
		if not done.has(a.id) and is_done(a, stats):
			out.append(a.id)
	return out


static func stars_for(ids: Array) -> int:
	var n := 0
	for id in ids:
		n += int(find(id).get("stars", 0))
	return n


## Rows for the records page: title, description, stars, done, progress.
static func rows(stats: Dictionary, done: Array) -> Array:
	var out := []
	for a in CATALOG:
		out.append({
			"title": a.title, "desc": a.desc, "stars": a.stars,
			"done": done.has(a.id) or is_done(a, stats),
			"progress": mini(int(stats.get(a.key, 0)), int(a.at)), "at": a.at,
		})
	return out
