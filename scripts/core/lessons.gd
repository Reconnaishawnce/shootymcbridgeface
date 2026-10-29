class_name Lessons
extends RefCounted
## The learning round. Short lessons, one per mechanic, each shown once
## as a paused pop-up the first time the thing appears on the road, and
## again on demand from the LEARN button. Pure: the catalog, the order,
## and which lesson a situation calls for. The game decides when.

const CATALOG := {
	"basics": {"title": "STEER AND SHOOT",
		"body": "Drag low on the screen to steer. Your squad fires ahead on its own. Every gate has one panel per lane: walk through the one you want. Blue grows the squad, red shrinks it. Hold a finger on the road to aim every gun at that spot."},
	"shoot_panels": {"title": "SHOOT THE PANELS",
		"body": "Bullets that hit a panel push its number up. Shoot a -4 enough and it becomes a +2. But bullets spent on panels never reach the zombies behind them. That trade is the whole game."},
	"fire_modes": {"title": "FIRE MODES",
		"body": "The button at the bottom right cycles TIGHT, NORMAL, WIDE and STRAIGHT. Wide covers the road and kills more, so it earns more bounty. Straight sends everything out of the middle, harder and through one more body: the drill for what is in front of you."},
	"bounty": {"title": "THE BOUNTY",
		"body": "Every kill pays coins: walkers 1, thieves and latchers 2, brutes 3, tanks 5. The counter under your level is this run's bounty. At the end it becomes coins for the shop, unless you spend it on the road."},
	"hidden": {"title": "HIDDEN PANELS",
		"body": "Grey panels with a ? are hidden. Get close, or put a bullet in them, to see what they are."},
	"expr": {"title": "SUMS",
		"body": "Teal panels are sums, worked out left to right: +3 x2 is not the same as x2 +3. Do the maths for the squad you have right now, then steer."},
	"perk": {"title": "PERK GATE",
		"body": "Three purple panels, pick one, it lasts the run and stacks. No stopping: steer through the one you want."},
	"fork": {"title": "THE FORK",
		"body": "The road splits. Each side's sign shows skull marks for its wave and a number for roughly how many soldiers it takes. The heavier side pays better panels. Be on the side you want when the divider arrives."},
	"dash": {"title": "DASH",
		"body": "Flick hard sideways to dash: a short hop with a moment of safety. Dash out of a ring, through a bite for a DODGED bonus, or to shake clingers off."},
	"clinger": {"title": "CLINGERS",
		"body": "Zombies that reach you cling to your flanks and keep eating. Tap a clinger to shoot it off, or dash to shake a couple loose."},
	"hot": {"title": "HOT PANELS",
		"body": "Panels flash white now and then. Hits during the flash count triple toward pushing the number up. Rhythm, not just position."},
	"deal": {"title": "DEALS",
		"body": "Amber panels are deals. TRADE: pay soldiers now for a power-up now. BET: clear the next wave with no bites and the squad doubles; a bite halves it. SCOUTS: a few soldiers go ahead and the next gates show everything. Shoot a trade or scout panel to make it cheaper."},
	"supply": {"title": "SUPPLY",
		"body": "Gold panels sell soldiers or a power-up for coins out of this run's bounty, paid right at the gate. What you spend here you do not take home to the shop. Too little bounty and nothing happens."},
	"vehicle": {"title": "THE CONVOY",
		"body": "Olive panels turn soldiers into a vehicle: a JEEP for 20, a TANK for 60, bigger things later. It rides with you from level to level with its own gun and health bar, until something heavy wrecks it."},
	"saw": {"title": "SAWS",
		"body": "A buzz saw is rolling down the bridge at you. Steer round it or dash through it; touching it takes a slice of the squad. It cuts zombies too."},
	"boss_walker": {"title": "THE WALKER",
		"body": "The road slows and the boss marches in. Kill it before it arrives or it chews your squad. Its glowing core takes triple damage: track it. Red rings on the road are lightning: a disc fills, then the bolt lands. Only the ring is hit."},
	"boss_spitter": {"title": "THE SPITTER",
		"body": "It hangs back and lobs globs. Watch the shadow crossing the road and the red ring closing in on where it lands. Only the ring is wet: step out of it. Its core sways with its whole body."},
	"boss_storm": {"title": "THE STORM",
		"body": "It calls lightning in lines across the whole road with one gap. Find the gap and fit through it; a tight formation helps."},
	"boss_foreman": {"title": "THE FOREMAN",
		"body": "It hangs back and works the road: it hurls buzz saws down your lane, two when it is angry, and drops supply crates between you. Dodge the saws, grab the crates, shoot the core."},
	"horde": {"title": "THE HORDE",
		"body": "A wall of zombies creeps up behind you while the road is stopped for the boss. Kill the boss fast, or it starts eating."},
	"veterans": {"title": "VETERANS",
		"body": "A survivor of every boss steps up with a name, a beret and a trait the whole squad feels: DEADEYE hits harder, TOUGH softens heavy bites, a FIELD MEDIC brings soldiers back, LUCKY pays more at the end. Up to three a run. A heavy bite can take one with it, so keep them out of the brutes."},
	"rally": {"title": "RALLY",
		"body": "Squad at zero? Once a run you can buy a few soldiers back for stars, if you decide in five seconds. Not in the daily or weekly."},
}
## The order lessons are listed on the LEARN page.
const ORDER := ["basics", "shoot_panels", "fire_modes", "bounty", "hidden", "expr", "perk", "fork", "dash", "clinger", "hot", "deal", "supply", "vehicle", "saw", "boss_walker", "boss_spitter", "boss_storm", "boss_foreman", "horde", "veterans", "rally"]
## Seconds between two pop-ups, so a busy gate does not stack three.
const COOLDOWN := 4.0


static func title(id: String) -> String:
	return str(CATALOG[id]["title"])


static func body(id: String) -> String:
	return str(CATALOG[id]["body"])


## The perk lesson names the three perks on offer, with what they do.
static func perk_body(ids: Array) -> String:
	var lines := [body("perk"), ""]
	for id in ids:
		lines.append("%s: %s." % [Perks.title(id), Perks.description(id)])
	return "\n".join(lines)


## The boss lesson for a boss kind name ("walker", "spitter", "storm").
static func boss_lesson(kind_name: String) -> String:
	return "boss_" + kind_name


## Lessons a new level introduces, by the level number.
static func for_level(level: int) -> Array:
	var out := []
	if level == Progression.DASH_LEVEL:
		out.append("dash")
	if level == Progression.CLING_LEVEL:
		out.append("clinger")
	if level == Progression.HOT_LEVEL:
		out.append("hot")
	return out


## Whether a lesson should pop: on, not seen (or a learning round), and
## not inside the cooldown.
static func due(id: String, seen: Array, on: bool, learning: bool, since_last: float) -> bool:
	if not on or not CATALOG.has(id):
		return false
	if since_last < COOLDOWN:
		return false
	return learning or not seen.has(id)


static func mark_seen(seen: Array, id: String) -> Array:
	var out := seen.duplicate()
	if not out.has(id):
		out.append(id)
	return out
