class_name Abilities
extends RefCounted
## The hero's move: one ability per squad type, on a cooldown, fired by
## the HERO button or a tap on the squad. Rifles fire a VOLLEY, shotguns
## a SHOCKWAVE, medics a HEAL PULSE. The shop's HERO POWER shortens the
## wait and makes the move hit harder. Pure: the numbers and the rules;
## the game does the firing.

const CATALOG := {
	"volley": {"name": "VOLLEY", "desc": "Every soldier fires a burst dead ahead, hard and through the first thing it meets"},
	"shockwave": {"name": "SHOCKWAVE", "desc": "A ring bursts out of the squad: everything near it is hit hard and thrown back"},
	"heal": {"name": "HEAL PULSE", "desc": "Soldiers back on their feet and a shield for a moment"},
	"longshot": {"name": "LONGSHOT", "desc": "One beam down the lane, through everything in it"},
}
const BY_TYPE := {"rifle": "volley", "shotgun": "shockwave", "medic": "heal", "sniper": "longshot"}
## The longshot: everything within this half-width of the squad's line,
## ahead, takes this many seconds of the squad's fire.
const LONGSHOT_HALF_WIDTH := 1.1
const LONGSHOT_SECONDS := 4.0
const LONGSHOT_RANGE := 60.0
## Seconds between uses, and how much each HERO POWER level takes off.
const COOLDOWN_BASE := 20.0
const COOLDOWN_PER_LEVEL := 3.0
## How much more each level adds to the move's effect.
const POWER_PER_LEVEL := 0.25
## The volley: one shot per soldier (to a cap), at this damage each, as a
## multiple of a normal shot, piercing once.
const VOLLEY_MAX_SHOTS := 48
const VOLLEY_DAMAGE_MULT := 3.0
const VOLLEY_PIERCE := 1
## The shockwave: everything within this reaches takes this many seconds
## of the squad's fire and is pushed back.
const SHOCKWAVE_RADIUS := 7.0
const SHOCKWAVE_SECONDS := 2.5
const SHOCKWAVE_PUSH := 5.0
## The heal: this fraction of the squad (at least HEAL_MIN) and a shield.
const HEAL_FRACTION := 0.12
const HEAL_MIN := 5
const HEAL_SHIELD_SECONDS := 3.0
## A tap on the squad counts within this many canvas pixels, this fast.
const TAP_RADIUS_PX := 110.0
const TAP_SECONDS := 0.28


static func for_type(squad_type: String) -> String:
	return str(BY_TYPE.get(squad_type, "volley"))


static func title(id: String) -> String:
	return str(CATALOG[id]["name"])


static func description(id: String) -> String:
	return str(CATALOG[id]["desc"])


static func cooldown(level: int) -> float:
	return maxf(8.0, COOLDOWN_BASE - COOLDOWN_PER_LEVEL * float(level))


static func power(level: int) -> float:
	return 1.0 + POWER_PER_LEVEL * float(level)


## Whether the move may fire: it has been cooldown(level) since the last.
static func ready(now: float, last_used: float, level: int) -> bool:
	return now - last_used >= cooldown(level)


## 0 at the moment of use, 1 when ready again.
static func charge(now: float, last_used: float, level: int) -> float:
	return clampf((now - last_used) / cooldown(level), 0.0, 1.0)


static func volley_shots(count: int) -> int:
	return clampi(count, 1, VOLLEY_MAX_SHOTS)


static func shockwave_damage(squad_dps: float, level: int) -> float:
	return squad_dps * SHOCKWAVE_SECONDS * power(level)


static func shockwave_radius(level: int) -> float:
	return SHOCKWAVE_RADIUS * (1.0 + 0.1 * float(level))


static func longshot_damage(squad_dps: float, level: int) -> float:
	return squad_dps * LONGSHOT_SECONDS * power(level)


static func heal_amount(count: int, level: int) -> int:
	return maxi(HEAL_MIN, int(round(float(count) * HEAL_FRACTION * power(level))))


## A tap on the squad: close to it on screen, and quick.
static func is_hero_tap(distance_px: float, seconds: float, moved_px: float) -> bool:
	return distance_px <= TAP_RADIUS_PX and seconds <= TAP_SECONDS and moved_px < 24.0
