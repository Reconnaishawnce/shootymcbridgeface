class_name SaveData
extends RefCounted
## Persistent stats, wallet, upgrades and settings. One ConfigFile in user://.

const PATH := "user://save.cfg"
const STATS := "stats"
const SETTINGS := "settings"
const META := "meta"


static func _load() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	return cfg


static func _read(section: String, key: String, default):
	return _load().get_value(section, key, default)


static func _write(section: String, key: String, value) -> void:
	var cfg := _load()
	cfg.set_value(section, key, value)
	cfg.save(PATH)


static func load_best() -> int:
	return int(_read(STATS, "best_score", 0))


static func load_best_level() -> int:
	return int(_read(STATS, "best_level", 0))


static func load_best_endless() -> int:
	return int(_read(STATS, "best_endless", 0))


static func load_runs() -> int:
	return int(_read(STATS, "runs", 0))


static func load_sound_on() -> bool:
	return bool(_read(SETTINGS, "sound_on", true))


static func save_sound_on(on: bool) -> void:
	_write(SETTINGS, "sound_on", on)


static func load_music_on() -> bool:
	return bool(_read(SETTINGS, "music_on", true))


static func save_music_on(on: bool) -> void:
	_write(SETTINGS, "music_on", on)


static func load_squad_type() -> String:
	return str(_read(SETTINGS, "squad_type", "rifle"))


static func save_squad_type(type: String) -> void:
	_write(SETTINGS, "squad_type", type)


static func load_coins() -> int:
	return int(_read(META, "coins", 0))


static func save_coins(coins: int) -> void:
	_write(META, "coins", maxi(0, coins))


static func add_coins(amount: int) -> int:
	var total := load_coins() + amount
	save_coins(total)
	return total


static func load_upgrades() -> Dictionary:
	var v = _read(META, "upgrades", {})
	return v if v is Dictionary else {}


static func save_upgrades(levels: Dictionary) -> void:
	_write(META, "upgrades", levels)


static func load_daily() -> Dictionary:
	var v = _read(STATS, "daily", {})
	return v if v is Dictionary else {}


static func save_daily(results: Dictionary) -> void:
	_write(STATS, "daily", results)


## Record a finished run. Returns which records it broke.
static func record_run(score: int, level: int, endless: bool = false) -> Dictionary:
	var cfg := _load()
	var result := {"new_best_score": false, "new_best_level": false, "new_best_endless": false}
	if endless:
		var best_e := int(cfg.get_value(STATS, "best_endless", 0))
		result.new_best_endless = score > best_e
		cfg.set_value(STATS, "best_endless", maxi(best_e, score))
	else:
		var best := int(cfg.get_value(STATS, "best_score", 0))
		var best_level := int(cfg.get_value(STATS, "best_level", 0))
		result.new_best_score = score > best
		result.new_best_level = level > best_level
		cfg.set_value(STATS, "best_score", maxi(best, score))
		cfg.set_value(STATS, "best_level", maxi(best_level, level))
	cfg.set_value(STATS, "runs", int(cfg.get_value(STATS, "runs", 0)) + 1)
	cfg.save(PATH)
	return result


static func wipe() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
