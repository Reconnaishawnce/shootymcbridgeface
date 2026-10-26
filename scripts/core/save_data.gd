class_name SaveData
extends RefCounted
## Persistent stats, wallet, upgrades and settings. One ConfigFile in user://.

const PATH := "user://save.cfg"
const STATS := "stats"
const SETTINGS := "settings"
const META := "meta"


static func _load() -> ConfigFile:
	var cfg := ConfigFile.new()
	# A fresh install has no file yet; loading it would log an error.
	if FileAccess.file_exists(PATH):
		cfg.load(PATH)
	return cfg


static func _read(section: String, key: String, default):
	return _load().get_value(section, key, default)


static func _write(section: String, key: String, value) -> void:
	var cfg := _load()
	cfg.set_value(section, key, value)
	cfg.save(PATH)


static func load_best(modifier: String = "normal") -> int:
	return int(_read(STATS, "best_score" + Modifiers.key_suffix(modifier), 0))


static func load_best_level(modifier: String = "normal") -> int:
	return int(_read(STATS, "best_level" + Modifiers.key_suffix(modifier), 0))


static func load_best_endless(modifier: String = "normal") -> int:
	return int(_read(STATS, "best_endless" + Modifiers.key_suffix(modifier), 0))


static func load_modifier() -> String:
	var id := str(_read(SETTINGS, "modifier", "normal"))
	return id if Modifiers.TABLE.has(id) else "normal"


static func save_modifier(id: String) -> void:
	_write(SETTINGS, "modifier", id)


static func load_runs() -> int:
	return int(_read(STATS, "runs", 0))


static func load_sound_on() -> bool:
	return bool(_read(SETTINGS, "sound_on", true))


static func save_sound_on(on: bool) -> void:
	_write(SETTINGS, "sound_on", on)


static func load_shadows_on() -> bool:
	return bool(_read(SETTINGS, "shadows_on", true))


static func save_shadows_on(on: bool) -> void:
	_write(SETTINGS, "shadows_on", on)


static func load_music_on() -> bool:
	return bool(_read(SETTINGS, "music_on", true))


static func save_music_on(on: bool) -> void:
	_write(SETTINGS, "music_on", on)


static func load_squad_type() -> String:
	return str(_read(SETTINGS, "squad_type", "rifle"))


static func save_squad_type(type: String) -> void:
	_write(SETTINGS, "squad_type", type)


static func load_character_mode() -> bool:
	return bool(_read(SETTINGS, "character_mode", false))


static func save_character_mode(on: bool) -> void:
	_write(SETTINGS, "character_mode", on)


static func load_wardrobe() -> Dictionary:
	var v = _read(META, "wardrobe", {})
	return v if v is Dictionary else {}


static func save_wardrobe(d: Dictionary) -> void:
	_write(META, "wardrobe", d)


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


static func load_weekly() -> Dictionary:
	var v = _read(STATS, "weekly", {})
	return v if v is Dictionary else {}


static func save_weekly(results: Dictionary) -> void:
	_write(STATS, "weekly", results)


## Record a finished run. Returns which records it broke.
static func record_run(score: int, level: int, endless: bool = false, modifier: String = "normal") -> Dictionary:
	var cfg := _load()
	var sfx := Modifiers.key_suffix(modifier)
	var result := {"new_best_score": false, "new_best_level": false, "new_best_endless": false}
	if endless:
		var best_e := int(cfg.get_value(STATS, "best_endless" + sfx, 0))
		result.new_best_endless = score > best_e
		cfg.set_value(STATS, "best_endless" + sfx, maxi(best_e, score))
	else:
		var best := int(cfg.get_value(STATS, "best_score" + sfx, 0))
		var best_level := int(cfg.get_value(STATS, "best_level" + sfx, 0))
		result.new_best_score = score > best
		result.new_best_level = level > best_level
		cfg.set_value(STATS, "best_score" + sfx, maxi(best, score))
		cfg.set_value(STATS, "best_level" + sfx, maxi(best_level, level))
	cfg.set_value(STATS, "runs", int(cfg.get_value(STATS, "runs", 0)) + 1)
	cfg.save(PATH)
	return result


static func load_stats() -> Dictionary:
	var v = _read(STATS, "lifetime", {})
	return Stats.merge(Stats.blank(), v) if v is Dictionary else Stats.blank()


static func save_stats(d: Dictionary) -> void:
	_write(STATS, "lifetime", d)


static func load_quests() -> Dictionary:
	var v = _read(STATS, "quests", {})
	return v if v is Dictionary else {}


static func save_quests(d: Dictionary) -> void:
	_write(STATS, "quests", d)


static func load_season() -> Dictionary:
	var v = _read(STATS, "season", {})
	return v if v is Dictionary else {}


static func save_season(d: Dictionary) -> void:
	_write(STATS, "season", d)


static func load_achievements() -> Array:
	var v = _read(STATS, "achievements", [])
	return v if v is Array else []


static func save_achievements(ids: Array) -> void:
	_write(STATS, "achievements", ids)


## A daily or weekly counts as a run without touching any best.
static func count_run() -> void:
	var cfg := _load()
	cfg.set_value(STATS, "runs", int(cfg.get_value(STATS, "runs", 0)) + 1)
	cfg.save(PATH)


static func wipe() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
