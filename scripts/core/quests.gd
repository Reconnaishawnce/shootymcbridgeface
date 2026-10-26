class_name Quests
extends RefCounted
## Three quests a day, the same three for everyone, progress kept across
## the day's runs. Each one done pays season points. Pure: the game
## hands in a day number and a run's numbers.

const PER_DAY := 3
## Templates: a title with one number, the run stat it watches, the
## targets to pick from and the points each pays. "max" templates track
## the best single run instead of adding up.
const TEMPLATES := [
	{"id": "kills", "title": "Kill %d zombies", "key": "kills", "targets": [150, 300, 600], "points": [30, 50, 80]},
	{"id": "gates", "title": "Pass %d gates", "key": "gates", "targets": [15, 30, 50], "points": [30, 50, 70]},
	{"id": "perfect", "title": "Shoot %d perfect gates", "key": "perfect", "targets": [3, 6, 10], "points": [40, 60, 90]},
	{"id": "bosses", "title": "Kill %d bosses", "key": "bosses", "targets": [1, 3, 5], "points": [30, 60, 90]},
	{"id": "waves", "title": "Clear %d waves", "key": "waves", "targets": [8, 16, 30], "points": [30, 50, 80]},
	{"id": "vehicle", "title": "Form %d vehicle", "key": "vehicles", "targets": [1, 2], "points": [50, 80]},
	{"id": "bet", "title": "Win %d bet", "key": "bets_won", "targets": [1], "points": [60]},
	{"id": "daily", "title": "Play %d daily", "key": "dailies", "targets": [1], "points": [40]},
	{"id": "combo", "title": "Reach a %d combo", "key": "best_combo", "targets": [40, 80, 150], "points": [40, 60, 90], "max": true},
	{"id": "level", "title": "Reach level %d", "key": "best_level", "targets": [3, 5, 7], "points": [40, 70, 100], "max": true},
	{"id": "stars", "title": "Earn %d stars", "key": "stars_earned", "targets": [3, 6], "points": [40, 60]},
	{"id": "distance", "title": "Run %d m", "key": "distance", "targets": [1500, 3000, 6000], "points": [30, 50, 80]},
]


## Today's quests: PER_DAY distinct templates with a target each, seeded
## by the day so everyone gets the same set.
static func for_day(day: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = day * 7919 + 13
	var pool := TEMPLATES.duplicate()
	var out := []
	while out.size() < PER_DAY and not pool.is_empty():
		var t: Dictionary = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		var k := rng.randi_range(0, t.targets.size() - 1)
		var target := int(t.targets[k])
		out.append({
			"id": str(t.id), "key": str(t.key), "target": target, "points": int(t.points[k]),
			"title": str(t.title) % target, "max": bool(t.get("max", false)),
		})
	return out


static func blank(day: int) -> Dictionary:
	return {"day": day, "progress": {}, "done": []}


## Fold a run into the day's state. Returns the new state and the quests
## completed by this run.
static func advance(state: Dictionary, day: int, run: Dictionary) -> Dictionary:
	var st := state.duplicate(true)
	if int(st.get("day", -1)) != day:
		st = blank(day)
	var completed := []
	for q in for_day(day):
		var prev := int(st.progress.get(q.id, 0))
		var add := int(run.get(q.key, 0))
		var now := maxi(prev, add) if q.max else prev + add
		st.progress[q.id] = mini(now, int(q.target))
		if now >= int(q.target) and not st.done.has(q.id):
			st.done.append(q.id)
			completed.append(q)
	return {"state": st, "completed": completed}


static func points_for(completed: Array) -> int:
	var n := 0
	for q in completed:
		n += int(q.points)
	return n


## Rows for the quests page: title, progress, target, points, done.
static func rows(state: Dictionary, day: int) -> Array:
	var out := []
	var st := state if int(state.get("day", -1)) == day else blank(day)
	for q in for_day(day):
		out.append({
			"title": q.title, "progress": int(st.progress.get(q.id, 0)), "target": int(q.target),
			"points": int(q.points), "done": st.done.has(q.id),
		})
	return out
