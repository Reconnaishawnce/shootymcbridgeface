class_name SaveData
extends RefCounted
## Persistent stats and settings. Deliberately tiny: one ConfigFile in user://.

const PATH := "user://save.cfg"
const STATS := "stats"
const SETTINGS := "settings"


static func _load() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	return cfg


static func load_best() -> int:
	return int(_load().get_value(STATS, "best_score", 0))


static func load_best_level() -> int:
	return int(_load().get_value(STATS, "best_level", 0))


static func load_runs() -> int:
	return int(_load().get_value(STATS, "runs", 0))


static func load_sound_on() -> bool:
	return bool(_load().get_value(SETTINGS, "sound_on", true))


static func save_sound_on(on: bool) -> void:
	var cfg := _load()
	cfg.set_value(SETTINGS, "sound_on", on)
	cfg.save(PATH)


## Record a finished run. Returns which records it broke.
static func record_run(score: int, level: int) -> Dictionary:
	var cfg := _load()
	var best := int(cfg.get_value(STATS, "best_score", 0))
	var best_level := int(cfg.get_value(STATS, "best_level", 0))
	var result := {
		"new_best_score": score > best,
		"new_best_level": level > best_level,
	}
	cfg.set_value(STATS, "best_score", maxi(best, score))
	cfg.set_value(STATS, "best_level", maxi(best_level, level))
	cfg.set_value(STATS, "runs", int(cfg.get_value(STATS, "runs", 0)) + 1)
	cfg.save(PATH)
	return result


static func wipe() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
