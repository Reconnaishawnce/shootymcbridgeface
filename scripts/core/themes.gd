class_name Themes
extends RefCounted
## Every level has a theme: a look (sky, light, fog, water) and one rule
## that changes how the level plays. Seven of them cycle with the
## levels, so a run is a string of different places and not one road.
## Pure: which theme a level has, the knobs its rule turns (the same
## knobs events use), and the colours of its look.

const ORDER := ["day", "gold", "night", "storm", "fog", "works", "saws"]
## Seconds between lightning lines in a STORM FRONT, and before the first.
const STRIKE_INTERVAL := 6.0
const STRIKE_FIRST := 4.0

const CATALOG := {
	"day": {"name": "DAYBREAK", "rule": "", "mods": {}, "min_level": 1},
	"gold": {"name": "GOLD HOUR", "rule": "The road runs fast and every kill pays double.", "mods": {"speed_bonus": 1.5, "bounty_mult": 2.0}, "min_level": 2},
	"night": {"name": "NIGHT SHIFT", "rule": "They are faster in the dark. Kills pay half again.", "mods": {"pace_mult": 1.2, "bounty_mult": 1.5}, "min_level": 2},
	"storm": {"name": "STORM FRONT", "rule": "Lightning walks the road. Stand in the gap.", "mods": {"strikes": true}, "min_level": 3},
	"fog": {"name": "FOG BANK", "rule": "Panels show late and the far road is grey. Read fast.", "mods": {"fog": true, "reveal_penalty": 9.0}, "min_level": 2},
	"works": {"name": "ROADWORKS", "rule": "Two more walls across the road. Shoot through or steer round.", "mods": {"barricades_extra": 2}, "min_level": 3},
	"saws": {"name": "SAW MILL", "rule": "Two more saws, and faster. Keep moving.", "mods": {"saws_extra": 2, "saw_speed": 1.5}, "min_level": 2},
}

## The look of each theme. Colours for the sky, the two lights, the fog
## and the water; energies and angles for the lights; flags for the
## extras the game switches on (rain, the squad's lamp).
const LOOKS := {
	"day": {
		"sky_top": Color(0.08, 0.3, 0.72), "sky_horizon": Color(0.95, 0.74, 0.58), "ground_horizon": Color(0.25, 0.45, 0.6), "ground_bottom": Color(0.05, 0.12, 0.22),
		"sun": Color(1.0, 0.94, 0.8), "sun_energy": 1.5, "sun_pitch": -52.0, "sun_yaw": 34.0, "fill": Color(0.4, 0.6, 1.0), "fill_energy": 0.45, "ambient": 0.9,
		"fog": Color(0.72, 0.78, 0.9), "fog_density": 0.005, "fog_sky": 0.15, "exposure": 1.05,
		"water_deep": Color(0.04, 0.24, 0.45), "water_light": Color(0.12, 0.5, 0.72), "foam": Color(0.8, 0.93, 1.0),
		"lamps": 1.6, "rain": false, "headlight": false},
	"gold": {
		"sky_top": Color(0.24, 0.2, 0.52), "sky_horizon": Color(1.0, 0.55, 0.25), "ground_horizon": Color(0.55, 0.35, 0.3), "ground_bottom": Color(0.12, 0.08, 0.12),
		"sun": Color(1.0, 0.62, 0.3), "sun_energy": 1.75, "sun_pitch": -20.0, "sun_yaw": 62.0, "fill": Color(0.55, 0.4, 0.85), "fill_energy": 0.5, "ambient": 0.85,
		"fog": Color(1.0, 0.68, 0.48), "fog_density": 0.005, "fog_sky": 0.2, "exposure": 1.05,
		"water_deep": Color(0.2, 0.13, 0.3), "water_light": Color(0.95, 0.55, 0.3), "foam": Color(1.0, 0.9, 0.75),
		"lamps": 2.4, "rain": false, "headlight": false},
	"night": {
		"sky_top": Color(0.01, 0.02, 0.08), "sky_horizon": Color(0.08, 0.13, 0.3), "ground_horizon": Color(0.03, 0.06, 0.14), "ground_bottom": Color(0.0, 0.01, 0.03),
		"sun": Color(0.55, 0.68, 1.0), "sun_energy": 0.8, "sun_pitch": -60.0, "sun_yaw": -30.0, "fill": Color(0.25, 0.35, 0.8), "fill_energy": 0.3, "ambient": 0.6,
		"fog": Color(0.05, 0.08, 0.18), "fog_density": 0.012, "fog_sky": 0.1, "exposure": 1.12,
		"water_deep": Color(0.01, 0.04, 0.1), "water_light": Color(0.06, 0.16, 0.32), "foam": Color(0.5, 0.65, 0.9),
		"lamps": 4.5, "rain": false, "headlight": true},
	"storm": {
		"sky_top": Color(0.12, 0.14, 0.2), "sky_horizon": Color(0.38, 0.42, 0.48), "ground_horizon": Color(0.2, 0.24, 0.3), "ground_bottom": Color(0.05, 0.07, 0.1),
		"sun": Color(0.75, 0.8, 0.9), "sun_energy": 0.95, "sun_pitch": -50.0, "sun_yaw": 20.0, "fill": Color(0.4, 0.5, 0.7), "fill_energy": 0.4, "ambient": 0.75,
		"fog": Color(0.4, 0.45, 0.52), "fog_density": 0.014, "fog_sky": 0.4, "exposure": 1.05,
		"water_deep": Color(0.05, 0.1, 0.15), "water_light": Color(0.25, 0.35, 0.42), "foam": Color(0.85, 0.9, 0.95),
		"lamps": 3.0, "rain": true, "headlight": false},
	"fog": {
		"sky_top": Color(0.5, 0.55, 0.62), "sky_horizon": Color(0.75, 0.78, 0.82), "ground_horizon": Color(0.5, 0.55, 0.6), "ground_bottom": Color(0.2, 0.24, 0.28),
		"sun": Color(0.95, 0.95, 1.0), "sun_energy": 1.0, "sun_pitch": -52.0, "sun_yaw": 34.0, "fill": Color(0.6, 0.65, 0.75), "fill_energy": 0.5, "ambient": 1.0,
		"fog": Color(0.62, 0.66, 0.72), "fog_density": 0.028, "fog_sky": 0.6, "exposure": 1.05,
		"water_deep": Color(0.2, 0.3, 0.36), "water_light": Color(0.45, 0.55, 0.6), "foam": Color(0.85, 0.9, 0.92),
		"lamps": 3.0, "rain": false, "headlight": false},
	"works": {
		"sky_top": Color(0.2, 0.42, 0.75), "sky_horizon": Color(0.9, 0.8, 0.55), "ground_horizon": Color(0.5, 0.46, 0.34), "ground_bottom": Color(0.15, 0.13, 0.1),
		"sun": Color(1.0, 0.92, 0.7), "sun_energy": 1.6, "sun_pitch": -72.0, "sun_yaw": 10.0, "fill": Color(0.6, 0.6, 0.7), "fill_energy": 0.4, "ambient": 0.8,
		"fog": Color(0.9, 0.82, 0.62), "fog_density": 0.0035, "fog_sky": 0.2, "exposure": 1.0,
		"water_deep": Color(0.08, 0.28, 0.32), "water_light": Color(0.3, 0.6, 0.55), "foam": Color(0.9, 0.95, 0.85),
		"lamps": 1.6, "rain": false, "headlight": false},
	"saws": {
		"sky_top": Color(0.16, 0.12, 0.3), "sky_horizon": Color(0.95, 0.5, 0.42), "ground_horizon": Color(0.4, 0.22, 0.26), "ground_bottom": Color(0.08, 0.04, 0.07),
		"sun": Color(1.0, 0.74, 0.62), "sun_energy": 1.4, "sun_pitch": -28.0, "sun_yaw": -50.0, "fill": Color(0.45, 0.5, 0.95), "fill_energy": 0.6, "ambient": 0.8,
		"fog": Color(0.78, 0.45, 0.45), "fog_density": 0.005, "fog_sky": 0.2, "exposure": 1.05,
		"water_deep": Color(0.15, 0.04, 0.1), "water_light": Color(0.7, 0.25, 0.3), "foam": Color(1.0, 0.8, 0.8),
		"lamps": 2.4, "rain": false, "headlight": false},
}


## The theme of [param level]: the cycle, with a level too early for its
## theme's rule (no saws yet, no walls yet) falling back to daybreak.
static func for_level(level: int) -> String:
	if level <= 1:
		return "day"
	var id: String = ORDER[(level - 1) % ORDER.size()]
	return id if level >= int(CATALOG[id]["min_level"]) else "day"


static func title(id: String) -> String:
	return str(CATALOG.get(id, CATALOG["day"])["name"])


static func rule(id: String) -> String:
	return str(CATALOG.get(id, CATALOG["day"])["rule"])


## The knobs the theme turns: keys of Events.DEFAULT_MODS.
static func mods(id: String) -> Dictionary:
	return CATALOG.get(id, CATALOG["day"])["mods"]


static func look(id: String) -> Dictionary:
	return LOOKS.get(id, LOOKS["day"])


## The look partway from [param a] to [param b]: colours and numbers
## blend, flags take b's.
static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for k in b:
		var from = a.get(k, b[k])
		if b[k] is Color:
			out[k] = (from as Color).lerp(b[k], t)
		elif b[k] is bool:
			out[k] = b[k]
		else:
			out[k] = lerpf(float(from), float(b[k]), t)
	return out


## The banner at the start of a level: "LEVEL 3  ·  NIGHT SHIFT" and the
## rule under it. Daybreak has no rule and no second line.
static func banner(level: int, id: String) -> String:
	if rule(id) == "":
		return "LEVEL %d" % level
	return "LEVEL %d  ·  %s\n%s" % [level, title(id), rule(id)]
