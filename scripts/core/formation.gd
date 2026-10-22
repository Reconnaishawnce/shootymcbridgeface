class_name Formation
extends RefCounted
## Pure layout of N soldiers into a tight blob behind the squad leader.
## Returns (x, z) offsets; index 0 is the centre, then concentric rings.

const SPACING := 0.55
## The blob is squashed sideways so a big squad still fits inside the lane.
const X_SCALE := 0.62
const Z_SCALE := 0.85


static func positions(n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	if n <= 0:
		return out
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
			out.append(Vector2(cos(a) * r * X_SCALE, sin(a) * r * Z_SCALE))
		ring += 1
	return out


## Half-width of the blob for [param n] soldiers, used to keep it in the lane.
static func half_width(n: int) -> float:
	var w := 0.0
	for p in positions(n):
		w = maxf(w, absf(p.x))
	return w
