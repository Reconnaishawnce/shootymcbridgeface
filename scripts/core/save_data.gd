class_name SaveData
extends RefCounted
## Persistent stats. Deliberately tiny: one ConfigFile in user://.

const PATH := "user://save.cfg"
const SECTION := "stats"


static func load_best() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return 0
	return int(cfg.get_value(SECTION, "best_score", 0))


static func load_runs() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return 0
	return int(cfg.get_value(SECTION, "runs", 0))


## Record a finished run. Returns true when [param score] is a new best.
static func record_run(score: int) -> bool:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	var best := int(cfg.get_value(SECTION, "best_score", 0))
	var is_best := score > best
	cfg.set_value(SECTION, "best_score", maxi(best, score))
	cfg.set_value(SECTION, "runs", int(cfg.get_value(SECTION, "runs", 0)) + 1)
	cfg.save(PATH)
	return is_best


static func wipe() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
