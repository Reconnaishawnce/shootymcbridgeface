class_name Wardrobe
extends RefCounted
## Character mode: who leads the squad and what everyone wears. Pure
## logic: a catalog of heroes, outfits, hats, weapon skins and backs, a
## star wallet, what is owned and what is equipped. Stars come from runs
## (a star per boss, one per few perfect gates, one for showing up).
##
## When character mode is off the squad wears the classic military look
## and none of this shows; the stars still accrue so switching it on later
## has something to spend.

const CATEGORIES := ["hero", "outfit", "hat", "weapon", "back", "crew"]
const CATEGORY_TITLES := {"hero": "HEROES", "outfit": "OUTFITS", "hat": "HATS", "weapon": "WEAPONS", "back": "BACKS", "crew": "CREW"}

## Every item: category, display name, star cost (0 is free), and the
## look fields it sets. Heroes carry a face and a line.
const CATALOG := {
	# Heroes: skin tone, hair colour and style, and one line of attitude.
	"max": {"cat": "hero", "name": "MAX", "cost": 0, "skin": Color(0.93, 0.76, 0.6), "hair": Color(0.35, 0.22, 0.12), "hair_style": "short", "line": "Never leaves anyone behind."},
	"zuri": {"cat": "hero", "name": "ZURI", "cost": 0, "skin": Color(0.42, 0.28, 0.2), "hair": Color(0.08, 0.06, 0.05), "hair_style": "bun", "line": "Counts the gates before you do."},
	"pip": {"cat": "hero", "name": "PIP", "cost": 3, "skin": Color(0.98, 0.85, 0.72), "hair": Color(0.95, 0.55, 0.2), "hair_style": "spiky", "line": "Small, loud, fearless."},
	"luna": {"cat": "hero", "name": "LUNA", "cost": 4, "skin": Color(0.85, 0.68, 0.55), "hair": Color(0.3, 0.2, 0.55), "hair_style": "long", "line": "Dashes first, asks later."},
	"kofi": {"cat": "hero", "name": "KOFI", "cost": 5, "skin": Color(0.35, 0.22, 0.15), "hair": Color(0.05, 0.05, 0.05), "hair_style": "curly", "line": "Calm under a hundred zombies."},
	"ada": {"cat": "hero", "name": "ADA", "cost": 6, "skin": Color(0.75, 0.55, 0.4), "hair": Color(0.9, 0.85, 0.8), "hair_style": "mohawk", "line": "Does the sums in her head."},
	"rex": {"cat": "hero", "name": "REX", "cost": 8, "skin": Color(0.6, 0.42, 0.3), "hair": Color(0.2, 0.15, 0.12), "hair_style": "bald", "line": "Big, kind, hard to move."},
	"mei": {"cat": "hero", "name": "MEI", "cost": 10, "skin": Color(0.96, 0.82, 0.7), "hair": Color(0.1, 0.1, 0.12), "hair_style": "long", "line": "Perfect gates or nothing."},
	# Outfits: top and trousers.
	"ranger": {"cat": "outfit", "name": "RANGER", "cost": 0, "top": Color(0.22, 0.45, 0.85), "pants": Color(0.16, 0.18, 0.24)},
	"sunny": {"cat": "outfit", "name": "SUNNY", "cost": 2, "top": Color(1.0, 0.8, 0.2), "pants": Color(0.2, 0.4, 0.8)},
	"berry": {"cat": "outfit", "name": "BERRY", "cost": 3, "top": Color(0.85, 0.2, 0.5), "pants": Color(0.3, 0.1, 0.3)},
	"mint": {"cat": "outfit", "name": "MINT", "cost": 3, "top": Color(0.4, 0.9, 0.7), "pants": Color(0.15, 0.35, 0.3)},
	"lava": {"cat": "outfit", "name": "LAVA", "cost": 5, "top": Color(1.0, 0.35, 0.1), "pants": Color(0.15, 0.12, 0.12)},
	"ocean": {"cat": "outfit", "name": "OCEAN", "cost": 5, "top": Color(0.1, 0.6, 0.9), "pants": Color(0.05, 0.2, 0.4)},
	"galaxy": {"cat": "outfit", "name": "GALAXY", "cost": 8, "top": Color(0.35, 0.15, 0.7), "pants": Color(0.1, 0.05, 0.25)},
	"snow": {"cat": "outfit", "name": "SNOW", "cost": 8, "top": Color(0.95, 0.95, 0.97), "pants": Color(0.75, 0.8, 0.9)},
	# Hats.
	"helmet": {"cat": "hat", "name": "HELMET", "cost": 0},
	"cap": {"cat": "hat", "name": "CAP", "cost": 1},
	"beanie": {"cat": "hat", "name": "BEANIE", "cost": 2},
	"headband": {"cat": "hat", "name": "HEADBAND", "cost": 2},
	"cat": {"cat": "hat", "name": "CAT EARS", "cost": 4},
	"party": {"cat": "hat", "name": "PARTY HAT", "cost": 4},
	"viking": {"cat": "hat", "name": "VIKING", "cost": 6},
	"crown": {"cat": "hat", "name": "CROWN", "cost": 8},
	"wizard": {"cat": "hat", "name": "WIZARD", "cost": 8},
	"halo": {"cat": "hat", "name": "HALO", "cost": 10},
	"bunny": {"cat": "hat", "name": "BUNNY EARS", "cost": 5},
	"chef": {"cat": "hat", "name": "CHEF", "cost": 3},
	"none_hat": {"cat": "hat", "name": "NO HAT", "cost": 1},
	# Weapon skins.
	"standard": {"cat": "weapon", "name": "STANDARD", "cost": 0},
	"wood": {"cat": "weapon", "name": "WOOD", "cost": 2},
	"candy": {"cat": "weapon", "name": "CANDY", "cost": 4},
	"ice": {"cat": "weapon", "name": "ICE", "cost": 5},
	"neon": {"cat": "weapon", "name": "NEON", "cost": 7},
	"gold": {"cat": "weapon", "name": "GOLD", "cost": 10},
	# Backs.
	"pack": {"cat": "back", "name": "BACKPACK", "cost": 0},
	"none_back": {"cat": "back", "name": "NOTHING", "cost": 1},
	"cape_red": {"cat": "back", "name": "RED CAPE", "cost": 3},
	"cape_blue": {"cat": "back", "name": "BLUE CAPE", "cost": 3},
	"wings": {"cat": "back", "name": "WINGS", "cost": 6},
	"jetpack": {"cat": "back", "name": "JETPACK", "cost": 8},
	"balloon": {"cat": "back", "name": "BALLOON", "cost": 4},
	"shell": {"cat": "back", "name": "SHELL", "cost": 5},
	# Crew: how everyone behind the hero dresses.
	"match": {"cat": "crew", "name": "MATCHING", "cost": 0},
	"rainbow": {"cat": "crew", "name": "RAINBOW", "cost": 4},
	"shadow": {"cat": "crew", "name": "SHADOW", "cost": 6},
	"plain": {"cat": "crew", "name": "NO HATS", "cost": 2},
	"twins": {"cat": "crew", "name": "TWINS", "cost": 8},
}

const DEFAULTS := {"hero": "max", "outfit": "ranger", "hat": "helmet", "weapon": "standard", "back": "pack", "crew": "match"}

var stars := 0
var owned: Dictionary = {}
var equipped: Dictionary = DEFAULTS.duplicate()


func _init() -> void:
	for id in DEFAULTS.values():
		owned[id] = true
	owned["zuri"] = true


static func items_in(cat: String) -> Array:
	var out := []
	for id in CATALOG.keys():
		if CATALOG[id].cat == cat:
			out.append(id)
	out.sort_custom(func(a: String, b: String) -> bool:
		var ca: int = CATALOG[a].cost
		var cb: int = CATALOG[b].cost
		return ca < cb if ca != cb else a < b)
	return out


static func title(id: String) -> String:
	return str(CATALOG.get(id, {}).get("name", id.to_upper()))


static func cost(id: String) -> int:
	return int(CATALOG.get(id, {}).get("cost", 0))


static func category(id: String) -> String:
	return str(CATALOG.get(id, {}).get("cat", ""))


static func hero_line(id: String) -> String:
	return str(CATALOG.get(id, {}).get("line", ""))


func is_owned(id: String) -> bool:
	return owned.get(id, false)


func is_equipped(id: String) -> bool:
	return equipped.get(category(id), "") == id


func can_buy(id: String) -> bool:
	return CATALOG.has(id) and not is_owned(id) and stars >= cost(id)


## Buy and equip. Returns false if it cannot be afforded or is unknown.
func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	stars -= cost(id)
	owned[id] = true
	equip(id)
	return true


func equip(id: String) -> bool:
	if not is_owned(id):
		return false
	equipped[category(id)] = id
	return true


## Tap an item: equip it if owned, buy it if affordable. Returns what
## happened: "equipped", "bought" or "".
func tap(id: String) -> String:
	if is_owned(id):
		return "equipped" if equip(id) else ""
	return "bought" if buy(id) else ""


func hero_name() -> String:
	return title(equipped.get("hero", "max"))


## What the hero shouts on a level clear, by grade.
const CHEERS := {
	"S": ["FLAWLESS!", "NOBODY DOES IT BETTER", "THAT'S HOW IT'S DONE"],
	"A": ["NICE ONE!", "KEEP THAT UP", "THE SQUAD'S PROUD"],
	"B": ["WE'LL TAKE IT", "ONWARD!", "NOT BAD, NOT BAD"],
	"C": ["CLOSE ONE", "WE LIVE TO FIGHT", "PHEW"],
	"D": ["STILL STANDING", "THAT HURT", "NEXT ONE'S OURS"],
}


static func cheer_line(hero: String, grade: String, pick: int) -> String:
	var lines: Array = CHEERS.get(grade, CHEERS["B"])
	return "%s: %s" % [hero, lines[absi(pick) % lines.size()]]


## Stars a run pays: one per boss, one per four perfect gates, one for
## getting through a few gates at all. Endless pays by distance in gates;
## the daily pays one extra for showing up.
static func stars_for_run(bosses: int, perfect_gates: int, gates: int, endless: bool, daily: bool = false) -> int:
	var n := bosses + perfect_gates / 4
	if endless:
		n += gates / 8
	if gates >= 3:
		n += 1
		if daily:
			n += 1
	return n


## Something in the catalog is unowned and affordable right now.
func can_afford_something() -> bool:
	for id in CATALOG.keys():
		if can_buy(id):
			return true
	return false


## Everything a Soldier needs to dress the hero. Crew members get the
## same but without the face: see crew_look.
func look() -> Dictionary:
	var hero: Dictionary = CATALOG.get(equipped.get("hero", "max"), CATALOG["max"])
	var outfit: Dictionary = CATALOG.get(equipped.get("outfit", "ranger"), CATALOG["ranger"])
	return {
		"hero": true,
		"name": str(hero.name),
		"skin": hero.skin,
		"hair": hero.hair,
		"hair_style": str(hero.hair_style),
		"top": outfit.top,
		"pants": outfit.pants,
		"hat": _hat_id(),
		"weapon": str(equipped.get("weapon", "standard")),
		"back": _back_id(),
	}


## The rest of the squad: same outfit, hat, weapon and back, their own
## faces (the Soldier picks those). The crew style can change that:
## rainbow tops, shadow greys, no hats, or twins of the hero.
func crew_look() -> Dictionary:
	var l := look()
	var crew := str(equipped.get("crew", "match"))
	l.crew = crew
	match crew:
		"rainbow":
			l.erase("top")
			l.erase("skin")
			l.erase("hair")
			l.erase("hair_style")
			l.erase("name")
		"shadow":
			l.top = Color(0.2, 0.2, 0.24)
			l.pants = Color(0.12, 0.12, 0.15)
			l.erase("skin")
			l.erase("hair")
			l.erase("hair_style")
			l.erase("name")
		"plain":
			l.hat = "none"
			l.erase("skin")
			l.erase("hair")
			l.erase("hair_style")
			l.erase("name")
		"twins":
			l.erase("name")
		_:
			l.erase("skin")
			l.erase("hair")
			l.erase("hair_style")
			l.erase("name")
	l.hero = false
	return l


## The classic look: helmet, pack, vest by squad type. What the game
## shows with character mode off.
static func classic_look() -> Dictionary:
	return {"hero": false, "hat": "helmet", "weapon": "standard", "back": "pack", "hair_style": "none"}


func _hat_id() -> String:
	var id := str(equipped.get("hat", "helmet"))
	return "none" if id == "none_hat" else id


func _back_id() -> String:
	var id := str(equipped.get("back", "pack"))
	return "none" if id == "none_back" else id


func to_dict() -> Dictionary:
	return {"stars": stars, "owned": owned.keys(), "equipped": equipped.duplicate()}


func from_dict(d: Dictionary) -> void:
	stars = int(d.get("stars", 0))
	var ids = d.get("owned", [])
	if ids is Array:
		for id in ids:
			if CATALOG.has(str(id)):
				owned[str(id)] = true
	var eq = d.get("equipped", {})
	if eq is Dictionary:
		for cat in CATEGORIES:
			var id := str(eq.get(cat, ""))
			if CATALOG.has(id) and category(id) == cat and is_owned(id):
				equipped[cat] = id
