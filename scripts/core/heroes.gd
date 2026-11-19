class_name Heroes
extends RefCounted
## What each hero does. A hero is a face in the locker and also a way
## to play: one thing that is always on (the passive) and one thing the
## hero move does on top of its usual job (the twist). Pure: text and
## numbers. An unknown or empty id is "no hero" and changes nothing.

const CATALOG := {
	"max": {"passive": "NO ONE LEFT BEHIND", "short": "+3 soldiers each level", "twist": "REINFORCE"},
	"zuri": {"passive": "GATE SENSE", "short": "+1 soldier at gates", "twist": "COUNTDOWN"},
	"pip": {"passive": "UNDERDOG", "short": "+30% damage when small", "twist": "LOUD"},
	"luna": {"passive": "QUICK FEET", "short": "Dash 40% sooner", "twist": "GHOST STEP"},
	"kofi": {"passive": "STEADY", "short": "Clingers bite half as often", "twist": "CALM"},
	"ada": {"passive": "SUMS", "short": "+10% coins", "twist": "COMPOUND"},
	"rex": {"passive": "HARD TO MOVE", "short": "Heavy bites take 25% less", "twist": "SHOVE"},
	"mei": {"passive": "PERFECTIONIST", "short": "Perfect gates pay +2", "twist": "FLOW"},
}
const ORDER := ["max", "zuri", "pip", "luna", "kofi", "ada", "rex", "mei"]

const MAX_LEVEL_SOLDIERS := 3
const MAX_MOVE_SOLDIERS := 2
const ZURI_GATE_SOLDIERS := 1
const ZURI_GATE_SECONDS := 2.0
const PIP_DAMAGE_MULT := 1.3
const PIP_SQUAD := 12
const PIP_COOLDOWN_MULT := 0.75
const LUNA_DASH_MULT := 0.6
const LUNA_GHOST_SECONDS := 1.5
const KOFI_LATCH_MULT := 2.0
const KOFI_SLOW := 0.55
const KOFI_SLOW_SECONDS := 3.0
const ADA_COIN_MULT := 1.1
const ADA_POWER_PER := 0.06
const REX_BITE_MULT := 0.75
const REX_SHOVE_RADIUS := 6.0
const REX_SHOVE_PUSH := 5.0
const MEI_PERFECT_SOLDIERS := 2

## Modes a hero's power works in. The daily and the weekly are the same
## road for everyone, so everyone runs them plain.
const MODES := ["levels", "endless", "rush"]


static func known(id: String) -> bool:
	return CATALOG.has(id)


## The hero whose power is live: [param id] when characters are on and
## the mode allows it, otherwise "".
static func active(id: String, character_mode: bool, mode: String) -> String:
	return id if character_mode and known(id) and MODES.has(mode) else ""


static func passive_title(id: String) -> String:
	return str(CATALOG.get(id, {}).get("passive", ""))


static func twist_title(id: String) -> String:
	return str(CATALOG.get(id, {}).get("twist", ""))


## A few words for the locker button.
static func short(id: String) -> String:
	return str(CATALOG.get(id, {}).get("short", ""))


## What is always on, with the real numbers.
static func passive_text(id: String) -> String:
	match id:
		"max":
			return "%d soldiers join every time a level is cleared" % MAX_LEVEL_SOLDIERS
		"zuri":
			return "Every gate that adds soldiers adds %d more" % ZURI_GATE_SOLDIERS
		"pip":
			return "+%d%% damage while the squad is %d or fewer" % [int(round((PIP_DAMAGE_MULT - 1.0) * 100.0)), PIP_SQUAD]
		"luna":
			return "The dash is ready %d%% sooner" % int(round((1.0 - LUNA_DASH_MULT) * 100.0))
		"kofi":
			return "Clinging zombies bite half as often"
		"ada":
			return "+%d%% coins from every run" % int(round((ADA_COIN_MULT - 1.0) * 100.0))
		"rex":
			return "Brutes, bosses, saws and lightning take %d%% less" % int(round((1.0 - REX_BITE_MULT) * 100.0))
		"mei":
			return "A perfect gate pays %d extra soldiers" % MEI_PERFECT_SOLDIERS
	return ""


## What the hero move does on top of its usual job.
static func twist_text(id: String) -> String:
	match id:
		"max":
			return "The hero move also brings %d soldiers back" % MAX_MOVE_SOLDIERS
		"zuri":
			return "Every gate takes %d seconds off the hero move's wait" % int(ZURI_GATE_SECONDS)
		"pip":
			return "The hero move recharges %d%% faster" % int(round((1.0 - PIP_COOLDOWN_MULT) * 100.0))
		"luna":
			return "The hero move makes the squad untouchable for %.1f seconds" % LUNA_GHOST_SECONDS
		"kofi":
			return "The hero move slows every zombie by %d%% for %d seconds" % [int(round((1.0 - KOFI_SLOW) * 100.0)), int(KOFI_SLOW_SECONDS)]
		"ada":
			return "The hero move hits %d%% harder for every perk and card you hold" % int(round(ADA_POWER_PER * 100.0))
		"rex":
			return "The hero move shoves the front rows back"
		"mei":
			return "A perfect gate refills the hero move"
	return ""


# --- numbers the game reads ------------------------------------------------

static func level_soldiers(id: String) -> int:
	return MAX_LEVEL_SOLDIERS if id == "max" else 0


static func move_soldiers(id: String) -> int:
	return MAX_MOVE_SOLDIERS if id == "max" else 0


static func gate_soldiers(id: String) -> int:
	return ZURI_GATE_SOLDIERS if id == "zuri" else 0


## Seconds a passed gate takes off the hero move's wait.
static func gate_seconds(id: String) -> float:
	return ZURI_GATE_SECONDS if id == "zuri" else 0.0


static func damage_mult(id: String, squad_count: int) -> float:
	return PIP_DAMAGE_MULT if id == "pip" and squad_count <= PIP_SQUAD else 1.0


static func cooldown_mult(id: String) -> float:
	return PIP_COOLDOWN_MULT if id == "pip" else 1.0


static func dash_cooldown_mult(id: String) -> float:
	return LUNA_DASH_MULT if id == "luna" else 1.0


static func ghost_seconds(id: String) -> float:
	return LUNA_GHOST_SECONDS if id == "luna" else 0.0


static func latch_interval_mult(id: String) -> float:
	return KOFI_LATCH_MULT if id == "kofi" else 1.0


static func move_slows(id: String) -> bool:
	return id == "kofi"


static func coin_mult(id: String) -> float:
	return ADA_COIN_MULT if id == "ada" else 1.0


## The hero move's power multiplier from what the build holds.
static func move_power(id: String, perks_and_cards: int) -> float:
	return 1.0 + ADA_POWER_PER * float(maxi(0, perks_and_cards)) if id == "ada" else 1.0


static func bite_mult(id: String) -> float:
	return REX_BITE_MULT if id == "rex" else 1.0


static func move_shoves(id: String) -> bool:
	return id == "rex"


static func perfect_soldiers(id: String) -> int:
	return MEI_PERFECT_SOLDIERS if id == "mei" else 0


static func perfect_refills(id: String) -> bool:
	return id == "mei"
