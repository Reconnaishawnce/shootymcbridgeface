class_name Formation
extends RefCounted
## Pure layout of N soldiers into a tight blob behind the squad leader.
## Returns (x, z) offsets; index 0 is the centre, then concentric rings.

const SPACING := 0.55
## The blob is squashed sideways so a big squad still fits inside the lane.
const X_SCALE := 0.62
const Z_SCALE := 0.85


## [param spread] stretches the blob sideways (and squashes it lengthways
## to keep the density) so the player can go wide to sweep the lane or
## tight to focus fire. 1.0 is the default blob.
const SPREAD_MIN := 0.45
const SPREAD_MAX := 1.8


static func positions(n: int, spread: float = 1.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	if n <= 0:
		return out
	var sx := X_SCALE * spread
	var sz := Z_SCALE / sqrt(spread)
	out.append(Vector2.ZERO)
	var ring := 1
	while out.size() < n:
		var slots := 6 * ring
		var r := SPACING * ring
		var phase := 0.5 * ring
		for i in range(slots):
			if out.size() >= n:
				break
			var a := TAU * float(i) / float(slots) + phase
			out.append(Vector2(cos(a) * r * sx, sin(a) * r * sz))
		ring += 1
	return out


## Half-width of the blob for [param n] soldiers, used to keep it in the lane.
static func half_width(n: int, spread: float = 1.0) -> float:
	var w := 0.0
	for p in positions(n, spread):
		w = maxf(w, absf(p.x))
	return w


## The widest spread that keeps [param n] soldiers inside [param lane_half].
static func max_spread_for(n: int, lane_half: float) -> float:
	var base := half_width(n, 1.0)
	if base <= 0.001:
		return SPREAD_MAX
	return clampf(lane_half / base, SPREAD_MIN, SPREAD_MAX)
